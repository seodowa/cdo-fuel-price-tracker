revoke all on
  public.province, public.city, public.barangay, public.brand, public.fuel_category,
  public.fuel_product, public.profile, public.admin_log
from anon, authenticated;

grant select on
  public.province, public.city, public.barangay, public.brand, public.fuel_category, public.fuel_product
to anon, authenticated;

grant insert, update, delete on
  public.province, public.city, public.barangay, public.brand, public.fuel_category, public.fuel_product
to authenticated;

grant select, update (banned_at) on public.profile to authenticated;
grant select on public.admin_log to authenticated;

create policy admin_write on public.province for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy admin_write on public.city for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy admin_write on public.barangay for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy admin_write on public.brand for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy admin_write on public.fuel_category for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy admin_write on public.fuel_product for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));

create policy admin_update on public.profile for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));

create policy admin_read on public.admin_log for select to authenticated using ((select private.is_admin()));

create function private.log_reference_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    insert into public.admin_log (admin_id, action, target_table, target_id)
    values (
      auth.uid(),
      case tg_op when 'INSERT' then 'create' when 'UPDATE' then 'update' else 'delete' end,
      tg_table_name,
      case tg_op when 'DELETE' then old.id else new.id end::text);
  end if;
  return null;
end;
$$;

create function private.log_ban_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    insert into public.admin_log (admin_id, action, target_table, target_id)
    values (auth.uid(), case when new.banned_at is null then 'unban' else 'ban' end, 'profile', new.id::text);
  end if;
  return null;
end;
$$;

create trigger log_change after insert or update or delete on public.province
  for each row execute function private.log_reference_change();
create trigger log_change after insert or update or delete on public.city
  for each row execute function private.log_reference_change();
create trigger log_change after insert or update or delete on public.barangay
  for each row execute function private.log_reference_change();
create trigger log_change after insert or update or delete on public.brand
  for each row execute function private.log_reference_change();
create trigger log_change after insert or update or delete on public.fuel_category
  for each row execute function private.log_reference_change();
create trigger log_change after insert or update or delete on public.fuel_product
  for each row execute function private.log_reference_change();

create trigger log_ban_change after update of banned_at on public.profile
  for each row when (old.banned_at is distinct from new.banned_at)
  execute function private.log_ban_change();

revoke execute on all functions in schema private from public;
grant execute on function private.is_admin() to authenticated;
