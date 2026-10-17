-- 무로바: 알바 시작 가이드의 단계(1~5)를 질문에 붙이기
-- 2026-10-17 서버(Supabase)에 적용 완료. 기록용 파일이에요. (기존 질문은 단계 없음으로 그대로 남아요)

-- 1) 가이드 단계 칸 (가이드에서 "이 부분이 헷갈려요"로 들어와 쓴 질문만 값이 있어요)
alter table public.questions
  add column if not exists guide_step smallint check (guide_step between 1 and 5);

grant insert (guide_step) on public.questions to authenticated;
grant select (guide_step) on public.questions to authenticated;

-- 2) 화면용 질문 목록에 단계 칸 추가 (기존 칸 순서는 그대로, 새 칸은 맨 뒤에)
create or replace view public.question_feed with (security_invoker = false) as
select q.id,
  case when q.anonymous then null else q.author_id end as author_id,
  q.cat, q.title, q.body, q.views, q.resolved_answer_id, q.resolved_at, q.created_at,
  case when q.anonymous then '익명' else p.nickname end as author_name,
  case when q.anonymous then null else p.univ end as author_univ,
  case when q.anonymous then null else p.year end as author_year,
  case when q.anonymous then null else p.stay end as author_stay,
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
  ), '[]'::jsonb) as answers,
  q.anonymous,
  coalesce(q.author_id = (select auth.uid()), false) as is_mine,
  q.guide_step
from public.questions q
join public.profiles p on p.id = q.author_id;

grant select on public.question_feed to anon, authenticated;
