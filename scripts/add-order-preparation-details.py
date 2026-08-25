#!/usr/bin/env python3
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
ORDERS=ROOT/'modules/admin/orders.js'
CSS=ROOT/'styles/alin-shared.css'
CONFIG=ROOT/'alin-config.js'
PAGES=[ROOT/'store-desktop.html',ROOT/'store-mobile.html',ROOT/'store-tablet.html']
TOKEN='4.2.0-stable-order-prep-details-20260825-1445'

text=ORDERS.read_text(encoding='utf-8')

old="  const products=()=>arr(dbx().products);\n"
new="""  const products=()=>arr(dbx().products);
  const booklets=()=>arr(dbx().booklets);
  const teachers=()=>arr(dbx().accounts?.teachers);
  function bookletForOrder(o){
    if(String(o?.kind||o?.item_kind||o?.item_type||'').toLowerCase()!=='booklet')return null;
    const id=o?.item_id||o?.booklet_id||o?.item?.id||'';
    return booklets().find(book=>String(book.id)===String(id))||null;
  }
  function teacherName(id,fallback='غير محدد'){
    if(!id)return fallback;
    const row=teachers().find(teacher=>String(teacher.id)===String(id));
    return row?.name||row?.display_name||row?.username||fallback;
  }
  function bookletPrep(o){
    const book=bookletForOrder(o);if(!book&&String(o?.kind||'').toLowerCase()!=='booklet')return null;
    const teacherId=book?.teacher_id||o?.teacher_id||o?.item?.teacher_id||'';
    return {
      subject:String(book?.subject||o?.subject||o?.item?.subject||'غير محددة').trim()||'غير محددة',
      term:String(book?.term||o?.term||o?.chapter||o?.item?.term||'غير محدد').trim()||'غير محدد',
      teacher:teacherName(teacherId,String(o?.teacher_name||o?.item?.teacher_name||'غير محدد').trim()||'غير محدد'),
      qty:Math.max(1,Number(o?.qty||o?.quantity||1)||1)
    };
  }
"""
if 'function bookletPrep(o)' not in text:
    if old not in text: raise SystemExit('products anchor missing')
    text=text.replace(old,new,1)

old="""      const d=orderDate(o),hay=[o.order_number,o.id,o.title,o.student_name,o.student_phone,libraryName(o.library_id||o.pickup_library_id),courierName(o.courier_id||o.delegate_id),o.delivery_area,o.delivery_landmark,o.product_variant_code,o.product_variant_name].join(' ').toLowerCase();
"""
new="""      const d=orderDate(o),prep=bookletPrep(o),hay=[o.order_number,o.id,o.title,o.student_name,o.student_phone,libraryName(o.library_id||o.pickup_library_id),courierName(o.courier_id||o.delegate_id),o.delivery_area,o.delivery_landmark,o.product_variant_code,o.product_variant_name,prep?.subject,prep?.term,prep?.teacher].join(' ').toLowerCase();
"""
if old in text:text=text.replace(old,new,1)
elif 'prep?.subject,prep?.term,prep?.teacher' not in text:raise SystemExit('filtered haystack anchor missing')

old="""    const st=statusOf(o),late=overdue(o),m=orderMeta(o.id),assigned=o.courier_id||o.delegate_id;
"""
new="""    const st=statusOf(o),late=overdue(o),m=orderMeta(o.id),prep=bookletPrep(o),assigned=o.courier_id||o.delegate_id;
"""
if old in text:text=text.replace(old,new,1)
elif 'm=orderMeta(o.id),prep=bookletPrep(o),assigned=' not in text:raise SystemExit('orderCard state anchor missing')

old="""</small></div><div class=\"admin-order-v126-meta\">"""
new="""</small>${prep?`<div class=\"admin-order-v126-prep\" aria-label=\"بيانات التجهيز\"><span><small>المادة</small><b>${esc(prep.subject)}</b></span><span><small>الفصل</small><b>${esc(prep.term)}</b></span><span><small>الأستاذ</small><b>${esc(prep.teacher)}</b></span><span><small>النسخ</small><b>${prep.qty}</b></span></div>`:''}</div><div class=\"admin-order-v126-meta\">"""
if 'aria-label="بيانات التجهيز"' not in text:
    if old not in text:raise SystemExit('order card main/meta anchor missing')
    text=text.replace(old,new,1)

old="""    const o=orders().find(x=>String(x.id)===String(id));if(!o)return;const m=orderMeta(id),matches=homeDelivery(o)?matchingCouriers(o.delivery_area):couriers(),assigned=String(o.courier_id||o.delegate_id||'');
"""
new="""    const o=orders().find(x=>String(x.id)===String(id));if(!o)return;const m=orderMeta(id),prep=bookletPrep(o),matches=homeDelivery(o)?matchingCouriers(o.delivery_area):couriers(),assigned=String(o.courier_id||o.delegate_id||'');
"""
if old in text:text=text.replace(old,new,1)
elif 'const m=orderMeta(id),prep=bookletPrep(o),matches=' not in text:raise SystemExit('details state anchor missing')

old="""<div><small>العنصر</small><b>${esc(o.title||'—')}</b></div>${variantLabel(o)?"""
new="""<div><small>العنصر</small><b>${esc(o.title||'—')}</b></div>${prep?`<div class=\"v126-prep-detail\"><small>المادة</small><b>${esc(prep.subject)}</b></div><div class=\"v126-prep-detail\"><small>الفصل</small><b>${esc(prep.term)}</b></div><div class=\"v126-prep-detail\"><small>الأستاذ</small><b>${esc(prep.teacher)}</b></div>`:''}${variantLabel(o)?"""
if 'class="v126-prep-detail"><small>المادة' not in text:
    if old not in text:raise SystemExit('details item anchor missing')
    text=text.replace(old,new,1)

ORDERS.write_text(text,encoding='utf-8')

css=CSS.read_text(encoding='utf-8')
marker='/* ALIN v4.2 Stable Lock — booklet preparation data inside admin orders. */'
if marker not in css:
    css += '''\n\n/* ALIN v4.2 Stable Lock — booklet preparation data inside admin orders. */
.admin-order-v126-prep{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:7px;margin-top:9px;padding:8px;border:1px solid color-mix(in srgb,var(--ao-gold) 38%,var(--ao-border));border-radius:12px;background:color-mix(in srgb,var(--ao-gold) 8%,var(--ao-surface));box-sizing:border-box}
.admin-order-v126-prep>span{min-width:0;display:grid;gap:2px;padding:6px 8px;border-radius:9px;background:var(--ao-surface);border:1px solid var(--ao-border)}
.admin-order-v126-prep small{color:var(--ao-muted);font-size:10px;font-weight:700}.admin-order-v126-prep b{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:var(--ao-ink);font-size:12px}
.v126-prep-detail{border-color:color-mix(in srgb,var(--ao-gold) 42%,var(--ao-border))!important;background:color-mix(in srgb,var(--ao-gold) 7%,var(--ao-surface))!important}
@media(max-width:760px){.admin-order-v126-prep{grid-template-columns:repeat(2,minmax(0,1fr));gap:6px}.admin-order-v126-prep b{white-space:normal;line-height:1.4}}
'''
    CSS.write_text(css,encoding='utf-8')

cfg=CONFIG.read_text(encoding='utf-8')
cfg,count=re.subn(r"assetVersion:'[^']+'",f"assetVersion:'{TOKEN}'",cfg,count=1)
if count!=1:raise SystemExit('assetVersion anchor missing')
CONFIG.write_text(cfg,encoding='utf-8')
for page in PAGES:
    data=page.read_text(encoding='utf-8')
    data=re.sub(r'\?v=[A-Za-z0-9._:-]+',f'?v={TOKEN}',data)
    page.write_text(data,encoding='utf-8')

print('admin order preparation details added; cache',TOKEN)
