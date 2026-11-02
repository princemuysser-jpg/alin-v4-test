-- Show a student's name only to the teacher who owns the purchased booklet.
-- Keep every existing view column in its original position; append student_name.
-- No student phone, GPS, address or other sensitive fields are exposed.
CREATE OR REPLACE VIEW public.alin_teacher_orders AS
SELECT o.id, o.order_number, o.kind, o.item_id, o.title, o.qty,
       o.unit_price, o.discount, o.total, o.status, o.teacher_profit,
       o.created_at, o.updated_at, b.teacher_id,
       o.student_name
FROM public.orders o
JOIN public.booklets b ON o.kind = 'booklet' AND b.id = o.item_id
WHERE b.teacher_id = public.alin_current_account_id()
  AND public.alin_current_role() = 'teacher';

COMMENT ON COLUMN public.alin_teacher_orders.student_name IS
  'Name entered for this teacher’s own booklet order; not a payment receipt.';
REVOKE ALL ON public.alin_teacher_orders FROM anon;
GRANT SELECT ON public.alin_teacher_orders TO authenticated;
