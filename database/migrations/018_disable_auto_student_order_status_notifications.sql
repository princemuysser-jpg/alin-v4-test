-- ALIN v4.2 Stable Lock — disable automatic order-status notifications to students.
-- Students continue to check order status using their order tracking code.
-- Manual/targeted notifications remain available.

drop trigger if exists trg_order_status_student_notification on public.orders;
drop function if exists public.alin_order_status_student_notification();
