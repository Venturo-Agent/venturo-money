// ════════════════════════════════════════════════════════════════════
// 漫途記帳 · Supabase 連線設定
// 由 envsubst 從 ~/.config/venturo/secrets.env 注入、不 hardcode
// 部署時跑：envsubst < config.template.js > config.js
// ════════════════════════════════════════════════════════════════════

window.LEDGER_CONFIG = {
  SUPABASE_URL: '${NEXT_PUBLIC_SUPABASE_URL}',
  SUPABASE_ANON_KEY: '${NEXT_PUBLIC_SUPABASE_ANON_KEY}',
  // 之後 deploy 改成真實 domain
  APP_NAME: '漫途 · 記帳',
  APP_VERSION: 'v2.0',
};
