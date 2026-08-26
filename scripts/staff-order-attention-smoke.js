'use strict';
const fs=require('fs');
const assert=require('assert');

const source=fs.readFileSync('modules/core/order-attention.js','utf8');
const css=fs.readFileSync('styles/alin-order-attention.css','utf8');
const build=fs.readFileSync('scripts/build-runtime.py','utf8');

assert(source.includes("['admin','library','courier']"),'staff order attention must cover admin, library and courier');
assert(source.includes("window.query('orders'"),'staff order attention must have a lightweight orders-only network fallback');
assert(source.includes('POLL_MS=6000'),'orders-only fallback cadence must stay lightweight');
assert(source.includes('alin:data-refreshed'),'orders fallback must refresh the visible staff page');
assert(source.includes('alin:new-order-bell'),'staff attention must integrate with the existing realtime bell');
assert(source.includes('alin_order_attention_read_v1'),'opened order state must persist per staff account');
assert(source.includes('#adminPage [data-admin-tab="orders"]'),'admin orders badge target missing');
assert(source.includes('libraryV116OrdersBadge'),'library orders badge target missing');
assert(source.includes('courierCurrentBadge'),'courier orders badge target missing');
assert(source.includes('window.AlinLibraryV116.render()'),'library view must rerender when new order data arrives');
assert(source.includes('[data-library-tab],[data-courier-tab]'),'library/courier navigation must immediately restore unread badge counts');
assert(source.includes('markRead'),'opening an order must clear its new marker');
assert(source.includes('alin-order-attention.css'),'order attention stylesheet loader missing');
assert(css.includes('.alin-order-attention-new'),'new-order visual marker missing');
assert(css.includes('.alin-order-attention-unread'),'unopened-order visual treatment missing');
assert(build.includes("'modules/core/order-attention.js'"),'order attention source must ship in role runtime');

console.log('ALIN STAFF ORDER ATTENTION SMOKE PASSED');
