begin;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table if not exists private.public_submission_rate_limits(
  scope text not null, subject_hash text not null,
  window_started_at timestamptz not null default now(),
  request_count integer not null default 0 check(request_count>=0),
  updated_at timestamptz not null default now(),
  primary key(scope,subject_hash)
);
revoke all on private.public_submission_rate_limits from public,anon,authenticated;
create or replace function private.alin_rate_limit_consume(p_scope text,p_subject text,p_limit integer,p_window_seconds integer)
returns jsonb language plpgsql security definer set search_path=private,public,extensions,pg_temp as $$
declare v_scope text:=lower(btrim(coalesce(p_scope,''))); v_hash text; v_row private.public_submission_rate_limits%rowtype; v_now timestamptz:=now(); v_retry integer:=0;
begin
 if v_scope='' or coalesce(p_subject,'')='' then raise exception 'rate limit key is empty'; end if;
 if p_limit<1 or p_limit>1000 or p_window_seconds<60 or p_window_seconds>604800 then raise exception 'invalid rate limit'; end if;
 v_hash:=public.alin_login_guard_key(p_subject); perform pg_advisory_xact_lock(hashtextextended(v_scope||':'||v_hash,0));
 select * into v_row from private.public_submission_rate_limits where scope=v_scope and subject_hash=v_hash for update;
 if not found then insert into private.public_submission_rate_limits values(v_scope,v_hash,v_now,1,v_now); return jsonb_build_object('allowed',true,'remaining',p_limit-1,'retry_after_seconds',0); end if;
 if v_row.window_started_at+make_interval(secs=>p_window_seconds)<=v_now then update private.public_submission_rate_limits set window_started_at=v_now,request_count=1,updated_at=v_now where scope=v_scope and subject_hash=v_hash; return jsonb_build_object('allowed',true,'remaining',p_limit-1,'retry_after_seconds',0); end if;
 if v_row.request_count>=p_limit then v_retry:=greatest(1,ceil(extract(epoch from ((v_row.window_started_at+make_interval(secs=>p_window_seconds))-v_now)))::integer); return jsonb_build_object('allowed',false,'remaining',0,'retry_after_seconds',v_retry); end if;
 update private.public_submission_rate_limits set request_count=request_count+1,updated_at=v_now where scope=v_scope and subject_hash=v_hash;
 return jsonb_build_object('allowed',true,'remaining',greatest(0,p_limit-(v_row.request_count+1)),'retry_after_seconds',0);
end$$;
revoke execute on function private.alin_rate_limit_consume(text,text,integer,integer) from public,anon,authenticated;
create unique index if not exists product_reviews_active_contact_item_uniq on public.product_reviews(kind,item_id,student_contact) where student_contact is not null and status in('pending','approved');
create unique index if not exists stock_alerts_pending_contact_item_uniq on public.stock_alerts(kind,item_id,contact) where contact is not null and status='pending';

create or replace function public.alin_public_submit_review(p_kind text,p_item_id text,p_contact text,p_rating integer,p_comment text,p_ip text)
returns jsonb language plpgsql security definer set search_path=public,private,extensions,pg_temp as $$
declare v_kind text:=lower(btrim(coalesce(p_kind,''))); v_item text:=btrim(coalesce(p_item_id,'')); v_contact text:=regexp_replace(coalesce(p_contact,''),'[^0-9]','','g'); v_comment text:=btrim(coalesce(p_comment,'')); v_ip text:=lower(btrim(coalesce(p_ip,'unknown'))); v_exists boolean:=false; v_limit jsonb; v_id text;
begin
 if v_kind not in('booklet','product','stationery','gift','deal') or v_item='' then return jsonb_build_object('ok',false,'code','invalid_item','message','المنتج غير صالح للتقييم.'); end if;
 if length(v_contact)<8 or length(v_contact)>15 then return jsonb_build_object('ok',false,'code','invalid_contact','message','اكتب رقم هاتف صحيح.'); end if;
 if p_rating is null or p_rating<1 or p_rating>5 then return jsonb_build_object('ok',false,'code','invalid_rating','message','اختر تقييماً من 1 إلى 5 نجوم.'); end if;
 if length(v_comment)<3 or length(v_comment)>800 then return jsonb_build_object('ok',false,'code','invalid_comment','message','اكتب تعليقاً من 3 إلى 800 حرف.'); end if;
 if v_kind='booklet' then select exists(select 1 from public.booklets where id=v_item and deleted_at is null and status='published' and publish_status='published') into v_exists; else select exists(select 1 from public.products where id=v_item and deleted_at is null and status='published' and type=v_kind) into v_exists; end if;
 if not v_exists then return jsonb_build_object('ok',false,'code','not_found','message','هذا المنتج غير متاح حالياً.'); end if;
 select id into v_id from public.product_reviews where kind=v_kind and item_id=v_item and student_contact=v_contact and status in('pending','approved') order by created_at desc limit 1;
 if v_id is not null then return jsonb_build_object('ok',true,'deduplicated',true,'id',v_id,'message','تم استلام تقييمك مسبقاً.'); end if;
 v_limit:=private.alin_rate_limit_consume('review:ip',v_ip,8,3600); if coalesce((v_limit->>'allowed')::boolean,false)=false then return jsonb_build_object('ok',false,'code','rate_limited','retry_after_seconds',(v_limit->>'retry_after_seconds')::integer,'message','تم الوصول إلى حد إرسال التقييمات مؤقتاً. حاول لاحقاً.'); end if;
 v_limit:=private.alin_rate_limit_consume('review:contact',v_contact,4,86400); if coalesce((v_limit->>'allowed')::boolean,false)=false then return jsonb_build_object('ok',false,'code','rate_limited','retry_after_seconds',(v_limit->>'retry_after_seconds')::integer,'message','تم الوصول إلى الحد اليومي للتقييمات لهذا الرقم.'); end if;
 begin insert into public.product_reviews(kind,item_id,student_contact,rating,comment,status) values(v_kind,v_item,v_contact,p_rating,v_comment,'pending') returning id into v_id; exception when unique_violation then select id into v_id from public.product_reviews where kind=v_kind and item_id=v_item and student_contact=v_contact and status in('pending','approved') order by created_at desc limit 1; return jsonb_build_object('ok',true,'deduplicated',true,'id',v_id,'message','تم استلام تقييمك مسبقاً.'); end;
 return jsonb_build_object('ok',true,'deduplicated',false,'id',v_id,'message','تم إرسال تقييمك للمراجعة قبل النشر.');
end$$;

create or replace function public.alin_public_submit_stock_alert(p_kind text,p_item_id text,p_contact text,p_ip text)
returns jsonb language plpgsql security definer set search_path=public,private,extensions,pg_temp as $$
declare v_kind text:=lower(btrim(coalesce(p_kind,''))); v_item text:=btrim(coalesce(p_item_id,'')); v_contact text:=regexp_replace(coalesce(p_contact,''),'[^0-9]','','g'); v_ip text:=lower(btrim(coalesce(p_ip,'unknown'))); v_exists boolean:=false; v_out boolean:=false; v_limit jsonb; v_id text;
begin
 if v_kind not in('product','stationery','gift','deal') or v_item='' then return jsonb_build_object('ok',false,'code','invalid_item','message','هذا المنتج لا يدعم تنبيه المخزون.'); end if;
 if length(v_contact)<8 or length(v_contact)>15 then return jsonb_build_object('ok',false,'code','invalid_contact','message','اكتب رقم هاتف صحيح.'); end if;
 select exists(select 1 from public.products where id=v_item and deleted_at is null and status='published' and type=v_kind),coalesce((select stock<=0 from public.products where id=v_item and deleted_at is null and status='published' and type=v_kind),false) into v_exists,v_out;
 if not v_exists then return jsonb_build_object('ok',false,'code','not_found','message','هذا المنتج غير متاح حالياً.'); end if; if not v_out then return jsonb_build_object('ok',false,'code','in_stock','message','المنتج متوفر حالياً ولا يحتاج تنبيه مخزون.'); end if;
 select id into v_id from public.stock_alerts where kind=v_kind and item_id=v_item and contact=v_contact and status='pending' order by created_at desc limit 1; if v_id is not null then return jsonb_build_object('ok',true,'deduplicated',true,'id',v_id,'message','طلب التنبيه مسجل مسبقاً.'); end if;
 v_limit:=private.alin_rate_limit_consume('stock_alert:ip',v_ip,20,3600); if coalesce((v_limit->>'allowed')::boolean,false)=false then return jsonb_build_object('ok',false,'code','rate_limited','retry_after_seconds',(v_limit->>'retry_after_seconds')::integer,'message','تم الوصول إلى حد طلبات التنبيه مؤقتاً. حاول لاحقاً.'); end if;
 v_limit:=private.alin_rate_limit_consume('stock_alert:contact',v_contact,12,86400); if coalesce((v_limit->>'allowed')::boolean,false)=false then return jsonb_build_object('ok',false,'code','rate_limited','retry_after_seconds',(v_limit->>'retry_after_seconds')::integer,'message','تم الوصول إلى الحد اليومي لتنبيهات هذا الرقم.'); end if;
 begin insert into public.stock_alerts(kind,item_id,contact,status) values(v_kind,v_item,v_contact,'pending') returning id into v_id; exception when unique_violation then select id into v_id from public.stock_alerts where kind=v_kind and item_id=v_item and contact=v_contact and status='pending' order by created_at desc limit 1; return jsonb_build_object('ok',true,'deduplicated',true,'id',v_id,'message','طلب التنبيه مسجل مسبقاً.'); end;
 return jsonb_build_object('ok',true,'deduplicated',false,'id',v_id,'message','تم تسجيل طلب التنبيه.');
end$$;

drop policy if exists reviews_public_insert on public.product_reviews;
drop policy if exists alerts_public_insert on public.stock_alerts;
revoke insert,delete,truncate,references,trigger on public.product_reviews from anon;
revoke insert,delete,truncate,references,trigger on public.stock_alerts from anon;
revoke insert,truncate,references,trigger on public.product_reviews from authenticated;
revoke insert,truncate,references,trigger on public.stock_alerts from authenticated;
revoke execute on function public.alin_public_submit_review(text,text,text,integer,text,text) from public,anon,authenticated;
revoke execute on function public.alin_public_submit_stock_alert(text,text,text,text) from public,anon,authenticated;
grant execute on function public.alin_public_submit_review(text,text,text,integer,text,text) to service_role;
grant execute on function public.alin_public_submit_stock_alert(text,text,text,text) to service_role;
commit;
