'use strict';
const fs=require('fs');
const vm=require('vm');
const assert=require('assert');

// Stable Lock protects secure student notification plumbing and staff new-order attention.
require('./student-notifications-smoke.js');
require('./staff-order-attention-smoke.js');

global.window={};
window.window=window;
window.current={role:'admin',id:'admin'};
window.addEventListener=()=>{};
window.db={
  settings:{teacher_profit_percent:50,library_profit_percent:30,delegate_profit_percent:30},
  booklets:[{id:'B1',teacher_id:'T1',teacher_share_percent:50,library_share_percent:30}],
  orders:[],ledger:[],settlements:[],withdrawals:[],
  accounts:{teachers:[],libraries:[],couriers:[]},couriers:[]
};

vm.runInThisContext(fs.readFileSync('core/finance-runtime.js','utf8'),{filename:'core/finance-runtime.js'});
assert(window.AlinFinance,'finance runtime did not install');

const order={id:'O1',kind:'booklet',item_id:'B1',total:6000,delivery_fee:2000,courier_fee:1500,fulfillment_type:'home_delivery',courier_id:'C1'};
const rawSplit=window.AlinFinance.shares(order);
assert.strictEqual(rawSplit.delivery,'delegate');
assert.strictEqual(rawSplit.deliveryFee,2000);
assert.strictEqual(rawSplit.merchandise,4000);
assert.strictEqual(rawSplit.teacher,2000);
assert.strictEqual(rawSplit.library,0);

// Apply exactly the compatibility block currently used by production.
const config=fs.readFileSync('alin-config.js','utf8');
const match=config.match(/\/\* ALIN v4\.3\.0 courier-fee compatibility\. \*\/([\s\S]*?)\/\* ALIN v4\.3\.0 delivery pricing UI bridge\. \*\//);
assert(match,'courier fee production compatibility block missing');
vm.runInThisContext(match[1],{filename:'alin-config-courier-fee-compat.js'});

returnAfterMicrotask().then(()=>{
  const split=window.AlinFinance.shares(order);
  assert.strictEqual(split.delivery,'delegate');
  assert.strictEqual(split.deliveryFee,2000);
  assert.strictEqual(split.delegate,1500,'persisted courier_fee must remain authoritative');
  assert.strictEqual(split.admin,2500);
  assert.strictEqual(split.debt,4500);

  const libraryOrder={id:'O2',kind:'booklet',item_id:'B1',total:4000,delivery_fee:0,fulfillment_type:'library',library_id:'L1'};
  const lib=window.AlinFinance.shares(libraryOrder);
  assert.strictEqual(lib.delivery,'library');
  assert.strictEqual(lib.teacher,2000);
  assert.strictEqual(lib.library,1200);
  assert.strictEqual(lib.delegate,0);
  assert.strictEqual(lib.admin,800);

  const teacherFix=fs.readFileSync('modules/teacher/order-delivery-label-fix.js','utf8');
  assert(teacherFix.includes("fulfillment==='home_delivery'"));
  assert(teacherFix.includes("deliveryType==='courier'"));
  assert(teacherFix.includes('التوصيل: مندوب'));
  assert(teacherFix.includes('الاستلام: مكتبة'));

  const build=fs.readFileSync('scripts/build-runtime.py','utf8');
  assert(build.includes("'modules/admin/finance-settlement-ui.js'"));
  assert(build.includes("'modules/admin/courier-hub.js'"));
  assert(build.includes("'modules/admin/delivery-pricing.js'"));

  console.log('ALIN CURRENT STABLE SMOKE PASSED');
}).catch(error=>{console.error(error);process.exit(1)});

function returnAfterMicrotask(){return new Promise(resolve=>setImmediate(resolve));}
