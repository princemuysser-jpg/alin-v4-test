'use strict';
const fs=require('fs');
const assert=require('assert');

const store=fs.readFileSync('store/notifications.js','utf8');
const admin=fs.readFileSync('modules/admin/notifications.js','utf8');
const migration=fs.readFileSync('database/migrations/017_student_order_notifications.sql','utf8');

assert(!store.includes("const context=()=>({role:'student',id:''})"),'student notification context must never use a blank id');
assert(store.includes("alin_student_notifications"),'secure student notification fetch RPC missing');
assert(store.includes("alin_student_notification_mark_read"),'secure student notification read RPC missing');
assert(store.includes("alin_student_notifications_mark_all"),'secure student mark-all RPC missing');
assert(store.includes("data-order-code"),'order notification must expose tracking action');
assert(store.includes("openOrderTracking"),'order notification tracking handler missing');
assert(store.includes("auth()?.current?.()"),'store notifications must resolve the signed-in student');

assert(admin.includes("alin_admin_student_customers"),'admin notifications must load registered students securely');
assert(admin.includes("...tagged(state.students,'student')"),'registered students must appear in target list');
assert(admin.includes("targetAccount?(userRole(targetAccount)||selectedRole):selectedRole"),'specific target must control recipient role');

assert(migration.includes('alin_student_session_id(p_token,p_device)'),'student notification RPCs must validate token + device');
assert(migration.includes('n.account_id=v_student'),'private rows must be scoped to the signed-in student');
assert(migration.includes('trg_order_status_student_notification'),'order status notification trigger missing');
assert(migration.includes("new.student_id"),'order notification must target order.student_id');
assert(migration.includes("'order:'||v_code"),'order notification must carry tracking link');
assert(!migration.includes('grant select on public.notifications to anon'),'private notifications must not be opened to anonymous table reads');

console.log('ALIN STUDENT ORDER NOTIFICATIONS SMOKE PASSED');
