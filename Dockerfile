# 漫途記帳 · 靜態 + envsubst 注入 Supabase token
FROM nginx:alpine

RUN apk add --no-cache gettext

WORKDIR /usr/share/nginx/html
COPY index.html ./
COPY manifest.json ./
COPY sw.js ./
COPY favicon.ico ./
COPY icons/ ./icons/
COPY config.template.js /tmp/config.template.js
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
