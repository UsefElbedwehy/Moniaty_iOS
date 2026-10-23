-- =============================================================================================
-- Munyati — fix: get_service returned hidden services to signed-out callers.
--
-- `not (public or provider_id = auth.uid())` is null when auth.uid() is null, and plpgsql's `if`
-- treats null as false, so a paused service, or one from a pending, suspended or lapsed
-- provider, was returned to anyone holding its id. Same function otherwise (videos included).
-- =============================================================================================

create or replace function public.get_service(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_service services%rowtype;
begin
  select * into v_service from services where id = p_id;
  -- coalesce: for a signed-out caller auth.uid() is null, and a bare comparison would make the
  -- whole test null, which `if` treats as false, so hidden services were returned.
  if not found or not (service_is_public(v_service) or coalesce(v_service.provider_id = auth.uid(), false)) then
    return null;
  end if;
  return service_card(v_service) || jsonb_build_object(
    'description', v_service.description,
    'duration_minutes', v_service.duration_minutes,
    'at_customer_location', v_service.at_customer_location,
    'image_urls', to_jsonb(v_service.image_urls),
    'videos', v_service.videos,
    'provider', provider_summary(v_service.provider_id),
    'store', case when v_service.store_id is not null then store_summary(v_service.store_id) end,
    'more_from_provider', coalesce((
      select jsonb_agg(service_card(s) order by s.created_at desc)
      from (select * from services s where s.provider_id = v_service.provider_id and s.id <> v_service.id
              and service_is_public(s) order by s.created_at desc limit 6) s), '[]'::jsonb));
end;
$$;
