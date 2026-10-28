-- "My preparations" (تجهيزاتي): the bride's own checklist of what she is preparing for the
-- wedding (dress fitting, invitations, henna night…), each item with an optional note.
--
-- * Private to the bride: only she reads or writes her items, always through the RPCs below.
--   Admins don't see them (personal planning, not marketplace data).
-- * Every write returns the whole list, so the apps simply show what comes back.
-- * Deleting the account (or the profile) removes the items.

create table public.bride_preparations (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 120),
  note text check (note is null or char_length(note) <= 1000),
  is_done boolean not null default false,
  done_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index bride_preparations_profile_idx on public.bride_preparations (profile_id, created_at);
create trigger bride_preparations_touch before update on public.bride_preparations
  for each row execute function public.touch_updated_at();

alter table public.bride_preparations enable row level security;
create policy bride_preparations_read on public.bride_preparations for select to authenticated
  using (profile_id = auth.uid());
revoke insert, update, delete on public.bride_preparations from anon, authenticated;

-- The caller, who must be a bride with a live account.
create function public.require_bride() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not exists (select 1 from profiles where id = v_uid and role = 'bride' and deleted_at is null) then
    raise exception 'bride account required' using errcode = '42501';
  end if;
  return v_uid;
end;
$$;

-- Open items first (oldest first, the order she added them), then the done ones (latest first).
create function public.get_my_preparations() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', p.id, 'title', p.title, 'note', p.note, 'is_done', p.is_done,
           'created_at', p.created_at)
         order by p.is_done, case when p.is_done then p.done_at end desc nulls last, p.created_at), '[]'::jsonb)
  from bride_preparations p
  where p.profile_id = auth.uid();
$$;

-- Adds an item (no p_id) or edits one of hers.
create function public.save_my_preparation(p_title text, p_note text default null, p_id uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_bride();
  v_title text := trim(coalesce(p_title, ''));
  v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if char_length(v_title) not between 1 and 120 then raise exception 'invalid title' using errcode = '22023'; end if;
  if char_length(v_note) > 1000 then raise exception 'note too long' using errcode = '22023'; end if;
  if p_id is null then
    if (select count(*) from bride_preparations where profile_id = v_uid) >= 300 then
      raise exception 'too many items' using errcode = '22023';
    end if;
    insert into bride_preparations (profile_id, title, note) values (v_uid, v_title, v_note);
  else
    update bride_preparations set title = v_title, note = v_note where id = p_id and profile_id = v_uid;
    if not found then raise exception 'not found' using errcode = 'P0002'; end if;
  end if;
  return get_my_preparations();
end;
$$;

create function public.set_my_preparation_done(p_id uuid, p_done boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_bride();
begin
  update bride_preparations
  set is_done = coalesce(p_done, false), done_at = case when coalesce(p_done, false) then now() end
  where id = p_id and profile_id = v_uid;
  return get_my_preparations();
end;
$$;

create function public.delete_my_preparation(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_bride();
begin
  delete from bride_preparations where id = p_id and profile_id = v_uid;
  return get_my_preparations();
end;
$$;

-- In-app account deletion keeps the profile row (anonymised), so the cascade doesn't fire;
-- remove her checklist when the profile is marked deleted.
create function public.bride_preparations_on_profile_deleted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from bride_preparations where profile_id = new.id;
  return new;
end;
$$;
create trigger profiles_delete_preparations after update of deleted_at on public.profiles
  for each row when (new.deleted_at is not null and old.deleted_at is null)
  execute function public.bride_preparations_on_profile_deleted();

revoke all on function public.require_bride(), public.get_my_preparations(),
  public.save_my_preparation(text, text, uuid), public.set_my_preparation_done(uuid, boolean),
  public.delete_my_preparation(uuid), public.bride_preparations_on_profile_deleted()
from public, anon;
grant execute on function public.get_my_preparations(),
  public.save_my_preparation(text, text, uuid), public.set_my_preparation_done(uuid, boolean),
  public.delete_my_preparation(uuid)
to authenticated;
