-- ALIN — allow a library to read only its own book-supplier ledger rows.
begin;

drop policy if exists ledger_read on public.ledger;
create policy ledger_read on public.ledger
for select to authenticated
using (
  public.alin_is_finance_staff()
  or teacher_id=public.alin_current_account_id()
  or library_id=public.alin_current_account_id()
  or delegate_id=public.alin_current_account_id()
  or courier_id=public.alin_current_account_id()
  or (
    supplier_type='library'
    and supplier_id=public.alin_current_account_id()
  )
);

commit;
