-- Deliver staff notifications to only their intended account.
-- Previous OR (role=... OR account_id=...) exposed individual courier notifications to all couriers.
DO $$
declare
  names text[] := array[
    'alin_business_notifications',
    'alin_business_notification_unread_count',
    'alin_business_notification_mark_read',
    'alin_business_notifications_mark_all'
  ];
  fn text;
  definition text;
  source_fragment text := '(n.role=''all'' or n.role=v_role or n.account_id=v_account)';
  target_fragment text := '(n.role=''all'' or (n.role=v_role and n.account_id is null) or (n.role=v_role and n.account_id=v_account))';
begin
  foreach fn in array names loop
    select pg_get_functiondef(p.oid) into definition
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=fn;
    if definition is null or strpos(definition,source_fragment)=0 then
      raise exception 'Cannot safely update notification function %: expected predicate not found',fn;
    end if;
    execute replace(definition,source_fragment,target_fragment);
  end loop;
end
$$;
