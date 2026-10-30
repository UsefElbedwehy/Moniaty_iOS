-- Bride details, part 3: phone numbers.
--
-- * Her contact number is always the number she signed in with (profiles.phone). It is not a
--   field she can edit any more.
-- * She can add one extra number (`extra_phone`), a Saudi mobile stored as +9665XXXXXXXX.
-- * Both follow the same privacy rule as her name: her booking's provider sees them only once
--   the payment is confirmed.
-- * The old free `phone` column is no longer written; a number saved there that differs from
--   the login number moves to `extra_phone`.

alter table public.bride_details
  add column extra_phone text check (extra_phone is null or extra_phone ~ '^\+9665[0-9]{8}$');

update public.bride_details d
set extra_phone = d.phone
from public.profiles p
where p.id = d.profile_id and d.phone is not null and d.phone is distinct from p.phone and d.extra_phone is null;
update public.bride_details set phone = null where phone is not null;

create or replace function public.bride_details_json(p_profile uuid, p_reveal boolean) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when d.profile_id is null and bb.wedding_date is null then null else jsonb_build_object(
    'full_name', case when p_reveal then d.full_name end,
    'age', d.age,
    'nationality', d.nationality,
    'phone', case when p_reveal then pr.phone end,
    'extra_phone', case when p_reveal then d.extra_phone end,
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
  left join profiles pr on pr.id = me.id
  left join bride_details d on d.profile_id = me.id
  left join bride_budgets bb on bb.profile_id = me.id
  left join cities c on c.id = d.city_id;
$$;

-- Same fields as before, with the extra number in place of the editable phone.
drop function public.set_my_bride_details(text, int, text, text, text, text, text, text, text, date, text, text, int, text);

create function public.set_my_bride_details(
  p_full_name text default null, p_age int default null, p_nationality text default null,
  p_extra_phone text default null, p_skin_type text default null, p_skin_tone text default null,
  p_hair_type text default null, p_hair_length text default null, p_allergies text default null,
  p_wedding_date date default null, p_city_id text default null, p_venue text default null,
  p_guest_count int default null, p_notes text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_bride();
  v_name text := nullif(trim(coalesce(p_full_name, '')), '');
  v_nationality text := nullif(trim(coalesce(p_nationality, '')), '');
  v_digits text := regexp_replace(coalesce(p_extra_phone, ''), '[^0-9]', '', 'g');
  v_extra text;
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
    v_extra := '+966' || v_digits;
    -- The login number is already shown; don't keep it twice.
    if v_extra = (select phone from profiles where id = v_uid) then v_extra := null; end if;
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
  insert into bride_details (profile_id, full_name, age, nationality, extra_phone, skin_type, skin_tone, hair_type,
                             hair_length, allergies, wedding_date, city_id, venue, guest_count, notes)
  values (v_uid, v_name, p_age, v_nationality, v_extra, nullif(p_skin_type, ''), nullif(p_skin_tone, ''),
          nullif(p_hair_type, ''), nullif(p_hair_length, ''), v_allergies, p_wedding_date, v_city, v_venue,
          p_guest_count, v_notes)
  on conflict (profile_id) do update set full_name = excluded.full_name, age = excluded.age,
    nationality = excluded.nationality, extra_phone = excluded.extra_phone, skin_type = excluded.skin_type,
    skin_tone = excluded.skin_tone, hair_type = excluded.hair_type, hair_length = excluded.hair_length,
    allergies = excluded.allergies, wedding_date = excluded.wedding_date, city_id = excluded.city_id,
    venue = excluded.venue, guest_count = excluded.guest_count, notes = excluded.notes;
  update bride_budgets set wedding_date = p_wedding_date, updated_at = now()
  where profile_id = v_uid and wedding_date is distinct from p_wedding_date;
  return bride_details_json(v_uid, true);
end;
$$;

revoke all on function
  public.set_my_bride_details(text, int, text, text, text, text, text, text, text, date, text, text, int, text)
from public, anon;
grant execute on function
  public.set_my_bride_details(text, int, text, text, text, text, text, text, text, date, text, text, int, text)
to authenticated;
