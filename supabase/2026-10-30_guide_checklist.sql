-- 무로바: 가이드 3단계 "준비 서류 체크리스트" 체크 저장 (로그인한 회원만, 본인 것만)
-- 2026-10-30 서버(Supabase)에 적용 완료. 기록용 파일이에요. item에는 서류 이름(한국어)이 들어가요.

create table if not exists public.guide_checklist (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  item text not null check (char_length(item) between 1 and 100),
  checked_at timestamptz not null default now(),
  primary key (user_id, item)
);
alter table public.guide_checklist enable row level security;
create policy "guide_checklist_select_own" on public.guide_checklist for select to authenticated using (user_id = (select auth.uid()));
create policy "guide_checklist_insert_own" on public.guide_checklist for insert to authenticated with check (user_id = (select auth.uid()));
create policy "guide_checklist_delete_own" on public.guide_checklist for delete to authenticated using (user_id = (select auth.uid()));
revoke all on public.guide_checklist from anon;
grant select, insert, delete on public.guide_checklist to authenticated;
