-- 무로바: 후기의 "이 일에 필요한 한국어 수준"을 질문 3개로 판정
-- 2026-10-17 서버(Supabase)에 적용 완료. 기록용 파일이에요. (기존 후기는 그대로 남아요)

-- 1) 질문 3개의 답과 최종 수준 칸
alter table public.reviews
  add column if not exists customer_talk text check (customer_talk in ('none','fixed','free')),
  add column if not exists phone_required boolean,
  add column if not exists coworker_talk boolean,
  add column if not exists required_level text check (required_level in ('beginner','intermediate','advanced')),
  add column if not exists level_overridden boolean not null default false;

-- 2) 예전 방식(korean)으로 쓴 후기는 새 기준에 맞춰 수준을 채워요
--    거의 안 씀·기본 인사 가능 → 초급, 손님 응대 가능 → 중급
update public.reviews set required_level = case korean
    when '손님 응대 가능' then 'intermediate'
    else 'beginner' end
  where required_level is null;

-- 3) 새 후기는 korean 칸을 안 써요
alter table public.reviews alter column korean drop not null;

-- 4) 쓰기·읽기 권한
grant insert (customer_talk, phone_required, coworker_talk, required_level, level_overridden) on public.reviews to authenticated;
grant select (customer_talk, phone_required, coworker_talk, required_level, level_overridden) on public.reviews to authenticated;

-- 5) 화면용 목록에 새 칸 추가 (기존 칸 순서는 그대로, 새 칸은 맨 뒤에)
create or replace view public.review_feed with (security_invoker = false) as
select r.id,
  case when r.anonymous then null else r.author_id end as author_id,
  r.industry, r.shop_name, r.months, r.days, r.time_of_day, r.korean,
  r.good, r.hard, r.note, r.tip, r.views, r.likes, r.created_at,
  case when r.anonymous then '익명' else p.nickname end as author_name,
  case when r.anonymous then null else p.univ end as author_univ,
  case when r.anonymous then null else p.year end as author_year,
  case when r.anonymous then null else p.stay end as author_stay,
  r.anonymous,
  coalesce(r.author_id = (select auth.uid()), false) as is_mine,
  r.customer_talk, r.phone_required, r.coworker_talk, r.required_level, r.level_overridden
from public.reviews r
join public.profiles p on p.id = r.author_id;

grant select on public.review_feed to anon, authenticated;
