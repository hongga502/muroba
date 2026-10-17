-- 무로바: 사용자 글 자동 번역(한국어 → 중국어) 저장소
-- 2026-10-17 서버(Supabase)에 적용 완료. 기록용 파일이에요.
-- 번역은 서버 함수 translate(supabase/functions/translate)가 DeepL로 하고, 결과를 여기 저장해서 같은 글은 다시 번역하지 않아요.

create table if not exists public.translations (
  src_hash   text not null,            -- 원문 SHA-256
  lang       text not null check (lang in ('zh')),
  src        text not null,
  text       text not null,
  created_at timestamptz not null default now(),
  primary key (src_hash, lang)
);

-- 화면에서 직접 읽고 쓰지 못하게 막아요 (서버 함수만 서비스 키로 써요)
alter table public.translations enable row level security;
revoke all on public.translations from anon, authenticated;
