#!/usr/bin/env bash
# UniCom keepalive daemon (LaunchAgent entry point).
# Ensures the Next API and the test tunnel stay up; logs to /tmp.
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

is_up() { curl -fsS --max-time 4 "http://localhost:3000/api/health" >/dev/null 2>&1; }

while true; do
  if ! is_up; then
    echo "[$(date)] api down → (re)starting" >> /tmp/unicom_daemon.log
    pkill -f "next dev" 2>/dev/null
    nohup npm run dev >> /tmp/unicom_api.log 2>&1 &
    # give it up to 30s
    for _ in $(seq 1 15); do sleep 2; is_up && break; done
  fi
  if ! pgrep -f "cloudflared tunnel --url http://localhost:3000" >/dev/null 2>&1; then
    echo "[$(date)] tunnel down → starting" >> /tmp/unicom_daemon.log
    nohup ~/bin/cloudflared tunnel --url http://localhost:3000 >> /tmp/cfd.log 2>&1 &
  fi
  sleep 30
done
