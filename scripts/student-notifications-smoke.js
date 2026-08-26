'use strict';
const fs=require('fs');
const assert=require('assert');

const store=fs.readFileSync('store/notifications.js','utf8');
const admin=fs.readFileSync('modules/admin/notifications.js','utf8');
const setupMigration=fs.readFileSync('database/migrations/017_student_order_notifications.sql','utf8');
const disableMigration=fs.readFileSync('database/migrations/018_disable_auto_student_order_status_notifications.sql','utf8');

assert(!store.includes("const context=()=>({role:'student',id:''})"),'student notification context must never use a blank id');
assert(store.includes('alin_student_notifications'),'secure student notification fetch RPC missing');
assert(store.includes('alin_student_notification_mark_read'),'secure student notification read RPC missing');
assert(store.includes('alin_student_notifications_mark_all'),'secure student mark-all RPC missing');
assert(store.includes('auth()?.current?.()'),'store notifications must resolve the signed-in student');

assert(admin.includes('alin_admin_student_customers'),'admin notifications must load registered students securely');
assert(admin.includes("...tagged(state.students,'student')"),'registered students must appear in target list');
assert(admin.includes('targetAccount?(userRole(targetAccount)||selectedRole):selectedRole'),'specific target must control recipient role');

assert(setupMigration.includes('create table if not exists public.student_notification_reads'),'student read state must use its own table');
assert(setupMigration.includes('references public.student_profiles(id)'),'student read table must be bound to student profiles');
assert(setupMigration.includes('alter table public.student_notification_reads enable row level security'),'student read table must have RLS enabled');
assert(setupMigration.includes('revoke all on table public.student_notification_reads from anon,authenticated'),'student read table must not be directly exposed');
assert(!setupMigration.includes('public.notification_reads'),'student RPCs must not write staff notification_reads');
assert(setupMigration.includes('alin_student_session_id(p_token,p_device)'),'student notification RPCs must validate token + device');
assert(setupMigration.includes('n.account_id=v_student'),'private rows must be scoped to the signed-in student');
assert(!setupMigration.includes('grant select on public.notifications to anon'),'private notifications must not be opened to anonymous table reads');

assert(disableMigration.includes('drop trigger if exists trg_order_status_student_notification on public.orders'),'automatic order-status trigger must be removed');
assert(disableMigration.includes('drop function if exists public.alin_order_status_student_notification()'),'automatic order-status function must be removed');
assert(!disableMigration.includes('create trigger'),'disable migration must never recreate an automatic status trigger');

console.log('ALIN STUDENT NOTIFICATIONS SMOKE PASSED — AUTO ORDER STATUS SEND DISABLED');
