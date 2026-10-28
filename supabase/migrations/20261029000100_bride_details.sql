-- "Bride details" (تفاصيل العروس): what a bride fills once in Profile so providers know the
-- event before accepting: the wedding date and city, the venue, how many guests, and notes.
--
-- * Only she reads or writes her row, through the RPCs below.
-- * The provider of each of her bookings sees the details on that booking (`get_booking`).
--   Never on demo bookings, and never anyone else.
-- * The wedding date is one date: it is the same one the budget stores. Saving either side
--   updates the other.
-- * Deleting the account removes the row.

create table public.bride_details (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  wedding_date date,
  city_id text references public.cities(id) on delete set null,
  venue text check (venue is null or char_length(venue) <= 120),
  guest_count int check (guest_count is null or guest_count between 1 and 10000),
  notes text check (notes is null or char_length(notes) <= 1000),
  updated_at timestamptz not null default now()
);
create trigger bride_details_touch before update on public.bride_details
  for each row execute function public.touch_updated_at();

alter table public.bride_details enable row level security;
create policy bride_details_read on public.bride_details for select to authenticated
  using (profile_id = auth.uid());
revoke insert, update, delete on public.bride_details from anon, authenticated;

-- A bride's details as the apps show them (null when she has none). The date falls back to the
-- budget's, for brides who set it there before this existed.
create function public.bride_details_json(p_profile uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when d.profile_id is null and bb.wedding_date is null then null else jsonb_build_object(
    'wedding_date', coalesce(d.wedding_date, bb.wedding_date),
    'city_id', d.city_id,
    'city_name_ar', c.name_ar,
    'city_name_en', c.name_en,
    'venue', d.venue,
    'guest_count', d.guest_count,
    'notes', d.notes) end
  from (select p_profile as id) me
  left join bride_details d on d.profile_id = me.id
  left join bride_budgets bb on bb.profile_id = me.id
  left join cities c on c.id = d.city_id;
$$;

create function public.get_my_bride_details() returns jsonb
language sql stable security definer set search_path = public as $$
  select bride_details_json(auth.uid());
$$;

-- Replaces all her details (an empty field clears it).
create function public.set_my_bride_details(
  p_wedding_date date default null, p_city_id text default null, p_venue text default null,
  p_guest_count int default null, p_notes text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_bride();
  v_city text := nullif(trim(coalesce(p_city_id, '')), '');
  v_venue text := nullif(trim(coalesce(p_venue, '')), '');
  v_notes text := nullif(trim(coalesce(p_notes, '')), '');
begin
  if v_city is not null and not exists (select 1 from cities where id = v_city) then
    raise exception 'unknown city' using errcode = '22023';
  end if;
  if char_length(v_venue) > 120 or char_length(v_notes) > 1000 then
    raise exception 'too long' using errcode = '22023';
  end if;
  if p_guest_count is not null and p_guest_count not between 1 and 10000 then
    raise exception 'invalid guest count' using errcode = '22023';
  end if;
  insert into bride_details (profile_id, wedding_date, city_id, venue, guest_count, notes)
  values (v_uid, p_wedding_date, v_city, v_venue, p_guest_count, v_notes)
  on conflict (profile_id) do update set wedding_date = excluded.wedding_date, city_id = excluded.city_id,
    venue = excluded.venue, guest_count = excluded.guest_count, notes = excluded.notes;
  -- One wedding date: keep the budget's in step.
  update bride_budgets set wedding_date = p_wedding_date, updated_at = now()
  where profile_id = v_uid and wedding_date is distinct from p_wedding_date;
  return bride_details_json(v_uid);
end;
$$;

-- …and the other way: a date set with the budget becomes her details' date.
create function public.bride_budgets_sync_wedding_date() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into bride_details (profile_id, wedding_date) values (new.profile_id, new.wedding_date)
  on conflict (profile_id) do update set wedding_date = excluded.wedding_date
  where bride_details.wedding_date is distinct from excluded.wedding_date;
  return new;
end;
$$;
create trigger bride_budgets_wedding_date after insert or update of wedding_date on public.bride_budgets
  for each row execute function public.bride_budgets_sync_wedding_date();

-- In-app account deletion keeps the (anonymised) profile, so the cascade doesn't fire.
create function public.bride_details_on_profile_deleted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from bride_details where profile_id = new.id;
  return new;
end;
$$;
create trigger profiles_delete_bride_details after update of deleted_at on public.profiles
  for each row when (new.deleted_at is not null and old.deleted_at is null)
  execute function public.bride_details_on_profile_deleted();

-- The booking as before, plus the bride's details for the booking's provider.
create or replace function public.get_booking(p_booking uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select booking_detail_json(b, case when b.bride_id = auth.uid() then 'bride' else 'provider' end)
         || jsonb_build_object('bride_details',
              case when b.provider_id = auth.uid() and b.bride_id is not null and not b.is_demo
                   then bride_details_json(b.bride_id) end)
  from bookings b
  where b.id = p_booking and (b.bride_id = auth.uid() or b.provider_id = auth.uid()) and b.archived_at is null;
$$;

revoke all on function public.bride_details_json(uuid), public.get_my_bride_details(),
  public.set_my_bride_details(date, text, text, int, text), public.bride_budgets_sync_wedding_date(),
  public.bride_details_on_profile_deleted()
from public, anon;
grant execute on function public.get_my_bride_details(), public.set_my_bride_details(date, text, text, int, text)
to authenticated;
