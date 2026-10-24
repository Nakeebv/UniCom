#!/usr/bin/env bash
# One-shot bootstrap: API + tunnel + current preview URLs.
cd "$(dirname "$0")/.."
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
npx drizzle-kit push 2>/dev/null | tail -1
if ! curl -fsS --max-time 4 http://localhost:3000/api/health >/dev/null 2>&1; then
  echo "starting api…"; nohup npm run dev > /tmp/unicom_api.log 2>&1 & for i in $(seq 1 20); do curl -fsS --max-time 3 http://localhost:3000/api/health >/dev/null 2>&1 && break; sleep 2; done
fi
if ! pgrep -f "cloudflared tunnel --url http://localhost:3000" >/dev/null 2>&1; then
  echo "starting tunnel…"; nohup ~/bin/cloudflared tunnel --url http://localhost:3000 > /tmp/cfd.log 2>&1 &
  sleep 8
fi
URL=$(grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" /tmp/cfd.log | tail -1)
echo "API:  http://localhost:3000"
echo "WEB:  ${URL:-<tunnel starting — rerun ./scripts/up.sh>}/flutter/index.html"
echo "APK:  ${URL:-}/downloads/index.html"
