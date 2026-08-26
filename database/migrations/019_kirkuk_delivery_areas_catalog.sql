-- ALIN — Kirkuk delivery areas catalog
-- Adds missing Kirkuk city areas without changing any existing area's pricing or assignments.

with wanted(name, seq) as (
  values
    ('القادسية الأولى',1),
    ('القادسية الثانية',2),
    ('الحرية',3),
    ('الإسكان',4),
    ('عرفة',5),
    ('رحيم اوه',6),
    ('آزادي',7),
    ('الشورجة',8),
    ('قورية',9),
    ('المصلى',10),
    ('بريادي',11),
    ('أحمد آغا',12),
    ('شاطرلو',13),
    ('إمام قاسم',14),
    ('تبه',15),
    ('الماس',16),
    ('القلعة',17),
    ('تسعين القديمة',18),
    ('تسعين الجديدة',19),
    ('ساحة الطيران',20),
    ('حمزه لي',21),
    ('الحديديين',22),
    ('بكلر',23),
    ('خان خورما',24),
    ('صاري كهيه',25),
    ('الواسطي',26),
    ('غرناطة',27),
    ('دوميز',28),
    ('جنوب دوميز',29),
    ('واحد آذار',30),
    ('واحد حزيران',31),
    ('النصر',32),
    ('العسكري',33),
    ('العروبة',34),
    ('النور',35),
    ('المنتوجات',36),
    ('الشهداء',37),
    ('الوحدة',38),
    ('الأسرى والمفقودين',39),
    ('المعلمين',40),
    ('الضباط',41),
    ('الخضراء',42),
    ('البعث',43),
    ('بنجا علي',44),
    ('الممدودة',45),
    ('طريق بغداد',46),
    ('حي عدن',47),
    ('النداء',48),
    ('حي 55',49),
    ('حي 58',50),
    ('شوراو',51),
    ('رزكاري',52),
    ('الصالحية الأولى',53),
    ('الصالحية الثانية',54),
    ('شارع القدس',55),
    ('الكرامة',56),
    ('حي الشرطة',57)
), current_max as (
  select coalesce(max(sort_order),0) as max_sort from public.delivery_areas
), missing as (
  select w.name, w.seq,
         row_number() over (order by w.seq) as add_order
  from wanted w
  where not exists (
    select 1
    from public.delivery_areas d
    where lower(regexp_replace(regexp_replace(d.name,'[أإآ]','ا','g'),'\s+',' ','g'))
        = lower(regexp_replace(regexp_replace(w.name,'[أإآ]','ا','g'),'\s+',' ','g'))
  )
)
insert into public.delivery_areas
  (id, name, city, delivery_fee, courier_fee, status, active, sort_order)
select
  'A' || replace(extensions.gen_random_uuid()::text,'-',''),
  m.name,
  'كركوك',
  2000,
  1500,
  'active',
  true,
  cm.max_sort + m.add_order
from missing m
cross join current_max cm;
