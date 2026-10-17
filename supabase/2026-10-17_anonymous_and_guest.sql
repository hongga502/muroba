-- 무로바: 익명 글 · '기타' 직접 입력 · 로그인 없이 둘러보기
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여 넣고 Run 을 누르면 돼요. (기존 글·회원 정보는 그대로예요)

-- 1) 익명 여부 칸 (기존 글은 실명 그대로)
alter table public.reviews   add column if not exists anonymous boolean not null default false;
alter table public.questions add column if not exists anonymous boolean not null default false;
alter table public.answers   add column if not exists anonymous boolean not null default false;
grant insert (anonymous) on public.reviews, public.questions, public.answers to authenticated;

-- 2) 업종 '기타'를 고르고 직접 적은 내용 허용 (1~20자)
alter table public.reviews drop constraint if exists reviews_industry_check;
alter table public.reviews add constraint reviews_industry_check
  check (char_length(btrim(industry)) between 1 and 20);

-- 3) 작성자 id는 표에서 직접 못 읽게 (익명 글 작성자가 드러나지 않도록)
revoke select on public.reviews, public.questions, public.answers from authenticated, anon;
grant select (id, industry, shop_name, months, days, time_of_day, korean, good, hard, note, tip, views, likes, created_at, anonymous) on public.reviews to authenticated;
grant select (id, cat, title, body, views, resolved_answer_id, resolved_at, created_at, anonymous) on public.questions to authenticated;
grant select (id, question_id, body, likes, created_at, anonymous) on public.answers to authenticated;

-- 4) 화면용 목록: 익명 글은 작성자를 가리고 "내 글인지"만 알려 줘요. 로그인 안 한 사람도 읽을 수 있어요.
drop view if exists public.review_feed;
create view public.review_feed with (security_invoker = false) as
select r.id,
  case when r.anonymous then null else r.author_id end as author_id,
  r.industry, r.shop_name, r.months, r.days, r.time_of_day, r.korean,
  r.good, r.hard, r.note, r.tip, r.views, r.likes, r.created_at,
  case when r.anonymous then '익명' else p.nickname end as author_name,
  case when r.anonymous then null else p.univ end as author_univ,
  case when r.anonymous then null else p.year end as author_year,
  case when r.anonymous then null else p.stay end as author_stay,
  r.anonymous,
  coalesce(r.author_id = (select auth.uid()), false) as is_mine
from public.reviews r
join public.profiles p on p.id = r.author_id;

drop view if exists public.question_feed;
create view public.question_feed with (security_invoker = false) as
select q.id,
  case when q.anonymous then null else q.author_id end as author_id,
  q.cat, q.title, q.body, q.views, q.resolved_answer_id, q.resolved_at, q.created_at,
  case when q.anonymous then '익명' else p.nickname end as author_name,
  case when q.anonymous then null else p.univ end as author_univ,
  case when q.anonymous then null else p.year end as author_year,
  case when q.anonymous then null else p.stay end as author_stay,
  q.anonymous,
  coalesce(q.author_id = (select auth.uid()), false) as is_mine,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id,
      'author_id', case when a.anonymous then null else a.author_id end,
      'body', a.body, 'likes', a.likes, 'created_at', a.created_at,
      'author_name', case when a.anonymous then '익명' else ap.nickname end,
      'author_univ', case when a.anonymous then null else ap.univ end,
      'author_year', case when a.anonymous then null else ap.year end,
      'author_stay', case when a.anonymous then null else ap.stay end,
      'anonymous', a.anonymous,
      'is_mine', coalesce(a.author_id = (select auth.uid()), false)
    ) order by a.created_at)
    from public.answers a
    join public.profiles ap on ap.id = a.author_id
    where a.question_id = q.id
  ), '[]'::jsonb) as answers
from public.questions q
join public.profiles p on p.id = q.author_id;

revoke all on public.review_feed, public.question_feed from anon, authenticated;
grant select on public.review_feed, public.question_feed to anon, authenticated;
