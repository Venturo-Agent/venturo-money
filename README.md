# 漫途記帳 · Venturo Money

漫途公司內部記帳工具 — 個人 + 公司雙模式、Supabase 雲端同步、PWA-ready。

- **Live**: https://money.venturo.tw
- **Stack**: Vanilla HTML/CSS/JS + Supabase JS SDK
- **DB**: Supabase project `aawrgygqgemgqssflfrx`、schema `ledger`
- **Deploy**: Coolify on Vultr、nginx 靜態容器

## 本機開發

```bash
# 1. 從 secrets 生成 config.js
source ~/.config/venturo/secrets.env
envsubst < config.template.js > config.js

# 2. 啟動 local server（Supabase auth 在 file:// 跑不起來）
python3 -m http.server 8080
# 或
npx serve .
```

## 部署

走 git push → Coolify auto deploy。
Coolify 需設兩個 env：
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

容器啟動時 entrypoint 跑 envsubst 把這兩個值注入 config.js。

## Schema

見 `supabase/migrations/20260520200000_create_ledger_schema.sql`
- `ledger.categories` — 分類（系統預設 + 用戶自訂）
- `ledger.records` — 記帳主表
- RLS by `user_id`（owner only）
