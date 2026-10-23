-- Database webhooks without the dashboard: a trigger function that POSTs the inserted row to an
-- edge function in the same shape as Supabase Database Webhooks ({type, table, schema, record}).
-- The triggers themselves carry the webhook secrets, so they are created per project, not here
-- (see supabase/README.md, "Webhooks"):
--   create trigger notifications_send_push after insert on public.notifications
--     for each row execute function private.post_webhook('<functions url>/send-push', '<PUSH_WEBHOOK_SECRET>');
--   create trigger sms_outbox_send_sms after insert on public.sms_outbox
--     for each row execute function private.post_webhook('<functions url>/send-sms', '<SMS_WEBHOOK_SECRET>');

create extension if not exists pg_net;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.post_webhook() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- tg_argv[0]: function URL, tg_argv[1]: value of the x-webhook-secret header.
  perform net.http_post(
    url := tg_argv[0],
    body := jsonb_build_object('type', tg_op, 'table', tg_table_name, 'schema', tg_table_schema,
                               'record', to_jsonb(new), 'old_record', null),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', tg_argv[1]),
    timeout_milliseconds := 5000
  );
  return new;
end;
$$;
revoke all on function private.post_webhook() from public, anon, authenticated;
