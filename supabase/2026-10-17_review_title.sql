-- 무로바: 후기 제목 (선택, 60자 이내)
-- 2026-10-17 서버(Supabase)에 적용 완료. 기록용 파일이에요. (기존 후기는 제목 없음으로 그대로 남아요)

alter table public.reviews
  add column if not exists title text check (char_length(title) <= 60);

grant insert (title) on public.reviews to authenticated;
grant select (title) on public.reviews to authenticated;

-- 화면용 후기 목록에 제목 칸 추가 (기존 칸 순서는 그대로, 새 칸은 맨 뒤에)
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
  r.customer_talk, r.phone_required, r.coworker_talk, r.required_level, r.level_overridden,
  r.title
from public.reviews r
join public.profiles p on p.id = r.author_id;

grant select on public.review_feed to anon, authenticated;
