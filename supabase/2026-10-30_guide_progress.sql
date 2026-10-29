-- 무로바: 알바 시작 가이드 "내 진행 상황" 기록 (로그인한 회원만, 본인 것만 보고 쓰기)
-- 2026-10-30 서버(Supabase)에 적용 완료. 기록용 파일이에요.

create table if not exists public.guide_progress (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  step smallint not null check (step between 1 and 5),
  done_at timestamptz not null default now(),
  primary key (user_id, step)
);
alter table public.guide_progress enable row level security;
create policy "guide_progress_select_own" on public.guide_progress for select to authenticated using (user_id = (select auth.uid()));
create policy "guide_progress_insert_own" on public.guide_progress for insert to authenticated with check (user_id = (select auth.uid()));
create policy "guide_progress_delete_own" on public.guide_progress for delete to authenticated using (user_id = (select auth.uid()));
revoke all on public.guide_progress from anon;
grant select, insert, delete on public.guide_progress to authenticated;
