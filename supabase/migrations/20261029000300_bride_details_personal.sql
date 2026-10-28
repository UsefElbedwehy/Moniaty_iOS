-- Bride details, part 2: details about the bride herself, above the wedding ones. Every field is
-- optional.
--
-- * Name, age, nationality and a contact phone; skin type and tone, hair type and length;
--   allergies or anything providers must know.
-- * Privacy, as for `bride_name` on bookings (§4.8): her booking's provider sees the name and
--   phone only once the payment is confirmed. Everything else shows from the request on.
-- * The phone, when given, must be a Saudi mobile; it is stored as +9665XXXXXXXX.

alter table public.bride_details
  add column full_name text check (full_name is null or char_length(full_name) <= 80),
  add column age int check (age is null or age between 16 and 70),
  add column nationality text check (nationality is null or char_length(nationality) <= 40),
  add column phone text check (phone is null or phone ~ '^\+9665[0-9]{8}$'),
  add column skin_type text check (skin_type is null or skin_type in ('normal', 'dry', 'oily', 'combination', 'sensitive')),
  add column skin_tone text check (skin_tone is null or skin_tone in ('light', 'medium', 'tan', 'deep')),
  add column hair_type text check (hair_type is null or hair_type in ('straight', 'wavy', 'curly')),
  add column hair_length text check (hair_length is null or hair_length in ('short', 'medium', 'long')),
  add column allergies text check (allergies is null or char_length(allergies) <= 500);

-- p_reveal: false hides the name and phone (a provider before the payment is confirmed).
create function public.bride_details_json(p_profile uuid, p_reveal boolean) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when d.profile_id is null and bb.wedding_date is null then null else jsonb_build_object(
    'full_name', case when p_reveal then d.full_name end,
    'age', d.age,
    'nationality', d.nationality,
    'phone', case when p_reveal then d.phone end,
    'skin_type', d.skin_type,
    'skin_tone', d.skin_tone,
    'hair_type', d.hair_type,
    'hair_length', d.hair_length,
    'allergies', d.allergies,
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

-- The one-argument form (her own view) shows everything.
create or replace function public.bride_details_json(p_profile uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select bride_details_json(p_profile, true);
$$;

-- Saving takes every field (one left out is cleared). The old five-field form is replaced so
-- PostgREST has one function to call.
drop function public.set_my_bride_details(date, text, text, int, text);

create function public.set_my_bride_details(
  p_full_name text default null, p_age int default null, p_nationality text default null,
  p_phone text default null, p_skin_type text default null, p_skin_tone text default null,
  p_hair_type text default null, p_hair_length text default null, p_allergies text default null,
  p_wedding_date date default null, p_city_id text default null, p_venue text default null,
  p_guest_count int default null, p_notes text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_bride();
  v_name text := nullif(trim(coalesce(p_full_name, '')), '');
  v_nationality text := nullif(trim(coalesce(p_nationality, '')), '');
  v_digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  v_phone text;
  v_allergies text := nullif(trim(coalesce(p_allergies, '')), '');
  v_city text := nullif(trim(coalesce(p_city_id, '')), '');
  v_venue text := nullif(trim(coalesce(p_venue, '')), '');
  v_notes text := nullif(trim(coalesce(p_notes, '')), '');
begin
  -- 05XXXXXXXX, 5XXXXXXXX, 9665XXXXXXXX or 009665XXXXXXXX → +9665XXXXXXXX.
  if v_digits <> '' then
    v_digits := regexp_replace(v_digits, '^(00)?966', '');
    v_digits := regexp_replace(v_digits, '^0', '');
    if v_digits !~ '^5[0-9]{8}$' then raise exception 'invalid phone' using errcode = '22023'; end if;
    v_phone := '+966' || v_digits;
  end if;
  if v_city is not null and not exists (select 1 from cities where id = v_city) then
    raise exception 'unknown city' using errcode = '22023';
  end if;
  if char_length(v_name) > 80 or char_length(v_nationality) > 40 or char_length(v_allergies) > 500
     or char_length(v_venue) > 120 or char_length(v_notes) > 1000 then
    raise exception 'too long' using errcode = '22023';
  end if;
  if p_age is not null and p_age not between 16 and 70 then raise exception 'invalid age' using errcode = '22023'; end if;
  if p_guest_count is not null and p_guest_count not between 1 and 10000 then
    raise exception 'invalid guest count' using errcode = '22023';
  end if;
  -- The choice fields are checked by the table (an unknown value fails with 23514).
  insert into bride_details (profile_id, full_name, age, nationality, phone, skin_type, skin_tone, hair_type,
                             hair_length, allergies, wedding_date, city_id, venue, guest_count, notes)
  values (v_uid, v_name, p_age, v_nationality, v_phone, nullif(p_skin_type, ''), nullif(p_skin_tone, ''),
          nullif(p_hair_type, ''), nullif(p_hair_length, ''), v_allergies, p_wedding_date, v_city, v_venue,
          p_guest_count, v_notes)
  on conflict (profile_id) do update set full_name = excluded.full_name, age = excluded.age,
    nationality = excluded.nationality, phone = excluded.phone, skin_type = excluded.skin_type,
    skin_tone = excluded.skin_tone, hair_type = excluded.hair_type, hair_length = excluded.hair_length,
    allergies = excluded.allergies, wedding_date = excluded.wedding_date, city_id = excluded.city_id,
    venue = excluded.venue, guest_count = excluded.guest_count, notes = excluded.notes;
  update bride_budgets set wedding_date = p_wedding_date, updated_at = now()
  where profile_id = v_uid and wedding_date is distinct from p_wedding_date;
  return bride_details_json(v_uid, true);
end;
$$;

-- The provider sees her name and phone once the payment is confirmed, like `bride_name`.
create or replace function public.get_booking(p_booking uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select booking_detail_json(b, case when b.bride_id = auth.uid() then 'bride' else 'provider' end)
         || jsonb_build_object('bride_details',
              case when b.provider_id = auth.uid() and b.bride_id is not null and not b.is_demo
                   then bride_details_json(b.bride_id, b.status in ('payment_confirmed', 'completed', 'disputed')) end)
  from bookings b
  where b.id = p_booking and (b.bride_id = auth.uid() or b.provider_id = auth.uid()) and b.archived_at is null;
$$;

revoke all on function public.bride_details_json(uuid, boolean),
  public.set_my_bride_details(text, int, text, text, text, text, text, text, text, date, text, text, int, text)
from public, anon;
grant execute on function
  public.set_my_bride_details(text, int, text, text, text, text, text, text, text, date, text, text, int, text)
to authenticated;
