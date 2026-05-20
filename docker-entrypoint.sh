#!/bin/sh
# 啟動時用 Coolify 注入的 env var 生成 config.js
# 必要環境變數：NEXT_PUBLIC_SUPABASE_URL、NEXT_PUBLIC_SUPABASE_ANON_KEY

set -e

if [ -z "$NEXT_PUBLIC_SUPABASE_URL" ] || [ -z "$NEXT_PUBLIC_SUPABASE_ANON_KEY" ]; then
  echo "FATAL: NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY missing" >&2
  exit 1
fi

envsubst < /tmp/config.template.js > /usr/share/nginx/html/config.js

echo "config.js generated, starting nginx..."
exec nginx -g 'daemon off;'
