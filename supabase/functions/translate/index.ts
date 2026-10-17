// 무로바: 사용자 글 자동 번역 (한국어 → 중국어 간체)
// 화면이 중국어일 때, 보이는 글 중 아직 번역이 없는 것만 모아서 보내요.
// 1) 저장해 둔 번역(public.translations)이 있으면 그걸 돌려주고
// 2) 없는 것만 DeepL로 번역한 뒤 저장해요. 같은 글은 두 번 번역하지 않아요.
// 비밀값: DEEPL_API_KEY (Supabase 대시보드 → Edge Functions → Secrets)
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const MAX_TEXTS = 60;        // 한 번에 받는 글 수
const MAX_LEN = 2000;        // 글 하나 최대 길이 (질문·답변 최대 길이와 같아요)
const MAX_TOTAL = 30000;     // 한 번에 번역하는 총 글자 수
const HANGUL = /[가-힣]/;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

async function sha256(s: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method" }, 405);

  let texts: unknown;
  try { ({ texts } = await req.json()); } catch { return json({ error: "bad-json" }, 400); }
  if (!Array.isArray(texts)) return json({ error: "texts" }, 400);

  // 한글이 들어 있는 글만 번역해요 (중국어로 쓴 글은 그대로)
  const wanted = Array.from(new Set(
    texts.filter((t): t is string => typeof t === "string")
      .map((t) => t.trim())
      .filter((t) => t && t.length <= MAX_LEN && HANGUL.test(t)),
  )).slice(0, MAX_TEXTS);
  if (!wanted.length) return json({ translations: {} });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const hashes = await Promise.all(wanted.map(sha256));
  const byHash = new Map(hashes.map((h, i) => [h, wanted[i]]));
  const out: Record<string, string> = {};

  const { data: cached, error: readErr } = await db.from("translations")
    .select("src_hash, text").eq("lang", "zh").in("src_hash", hashes);
  if (readErr) return json({ error: "cache-read" }, 500);
  for (const row of cached ?? []) {
    const src = byHash.get(row.src_hash);
    if (src) out[src] = row.text;
  }

  // 저장된 번역이 없는 글만 DeepL로
  const missing: { hash: string; src: string }[] = [];
  let total = 0;
  for (const [hash, src] of byHash) {
    if (out[src] !== undefined) continue;
    if (total + src.length > MAX_TOTAL) break;
    total += src.length;
    missing.push({ hash, src });
  }
  if (!missing.length) return json({ translations: out });

  const key = Deno.env.get("DEEPL_API_KEY");
  if (!key) return json({ translations: out, error: "no-key" });
  const host = key.endsWith(":fx") ? "https://api-free.deepl.com" : "https://api.deepl.com";
  const res = await fetch(`${host}/v2/translate`, {
    method: "POST",
    headers: { "Authorization": `DeepL-Auth-Key ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ text: missing.map((m) => m.src), source_lang: "KO", target_lang: "ZH-HANS" }),
  });
  if (!res.ok) {
    console.error("deepl", res.status, await res.text());
    return json({ translations: out, error: "deepl-" + res.status });
  }
  const data = await res.json();
  const rows = missing.map((m, i) => ({ src_hash: m.hash, lang: "zh", src: m.src, text: data.translations?.[i]?.text ?? "" }))
    .filter((r) => r.text);
  for (const r of rows) out[r.src] = r.text;
  if (rows.length) {
    const { error } = await db.from("translations").upsert(rows, { onConflict: "src_hash,lang" });
    if (error) console.error("cache-write", error.message);
  }
  return json({ translations: out });
});
