-- 무로바: 회원가입 때 위챗 아이디 필수 입력 (운영진만 열람)
-- 2026-10-28 서버(Supabase)에 적용 완료. 기록용 파일이에요.
-- 이 날짜 전에 가입한 회원은 위챗 아이디가 비어 있어요.

-- 1) 위챗 아이디를 따로 보관하는 표
--    RLS를 켜고 정책을 하나도 두지 않았고, 앱 사용자(anon·authenticated) 권한도 모두 뺐어요.
--    → 다른 회원은 물론 본인 화면에서도 읽을 수 없고, Supabase 관리 화면(운영진)에서만 보여요.
create table if not exists public.profile_contact (
  id uuid primary key references public.profiles(id) on delete cascade,   -- 탈퇴하면 같이 지워져요
  wechat_id text not null check (wechat_id ~ '^[a-zA-Z][a-zA-Z0-9_-]{5,19}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profile_contact enable row level security;
revoke all on public.profile_contact from anon, authenticated;

-- 2) handle_new_user: 가입할 때 wechat_id가 없거나 형식이 틀리면 가입을 막고,
--    맞으면 profile_contact에 저장해요. (나머지 내용은 이전과 같아요)
--    전체 함수 내용은 Supabase의 마이그레이션 기록 "wechat_id_required_signup"에 있어요.


-- ===== 운영진용: 후기 작성자의 위챗 아이디 찾기 =====
-- Supabase 관리 화면 → SQL Editor에 붙여 넣고 실행하세요. (익명 글도 작성자가 나와요)
-- 맨 아래 where 줄에서 후기 id나 가게 이름으로 좁힐 수 있어요.
--
-- select r.id as review_id, r.created_at, r.industry, r.shop_name, r.anonymous,
--        p.nickname, u.email, c.wechat_id
-- from public.reviews r
-- join public.profiles p on p.id = r.author_id
-- join auth.users u on u.id = r.author_id
-- left join public.profile_contact c on c.id = r.author_id
-- -- where r.id = '여기에 후기 id' 또는  where r.shop_name like '%가게이름%'
-- order by r.created_at desc;
--
-- 질문·답변은 위 쿼리에서 public.reviews를 public.questions 또는 public.answers로 바꾸면 돼요
-- (shop_name·industry 칸은 지워 주세요).
