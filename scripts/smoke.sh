#!/usr/bin/env bash
# UniCom backend smoke test — exercises the live API contract end-to-end.
#
# Usage:
#   BASE=http://localhost:3000 ./scripts/smoke.sh
#
# With optional keys in backend .env (R2 / GROQ / CLOUDFLARE_AI_*), the voice
# steps below additionally exercise real STT/MT/TTS. Without them the run
# still validates the demo-tier paths honestly (STT reports configured-off).
set -euo pipefail

BASE="${BASE:-http://localhost:3000}"
U="smoke_$(date +%s)"
JAR="$(mktemp)"
JAR2="$(mktemp)"

say() { printf "\n\033[1;36m▶ %s\033[0m\n" "$1"; }
say "Health: $BASE/api/health"
curl -fsS "$BASE/api/health" | head -c 200; echo

say "Register A ($U) + B (peer)"
curl -fsS -c "$JAR" -H 'content-type: application/json' \
  -d "{\"username\":\"$U\",\"displayName\":\"Smoke A\",\"password\":\"password-123\"}" \
  "$BASE/api/auth/register" >/dev/null
U2="${U}_peer"
curl -fsS -c "$JAR2" -H 'content-type: application/json' \
  -d "{\"username\":\"$U2\",\"displayName\":\"Smoke B\",\"password\":\"password-123\"}" \
  "$BASE/api/auth/register" >/dev/null

say "Login session check (/api/me) + contacts"
curl -fsS -b "$JAR" "$BASE/api/me" | head -c 200; echo
# Make the peer speak Spanish so per-recipient routing is observable.
curl -fsS -X PATCH -b "$JAR2" -H 'content-type: application/json' \
  -d '{"preferredLanguage":"es","speechLanguage":"es"}' "$BASE/api/me" >/dev/null
curl -fsS -b "$JAR" "$BASE/api/contacts" | head -c 200; echo

say "Open direct conversation A↔B"
PEER_ID="$(curl -fsS -b "$JAR" "$BASE/api/contacts" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print([c['id'] for c in d['contacts'] if c['username'] == '$U2'][0])
")"
CID="$(curl -fsS -b "$JAR" -H 'content-type: application/json' \
  -d "{\"memberIds\":[\"$PEER_ID\"]}" \
  "$BASE/api/conversations" | python3 -c "import sys,json;print(json.load(sys.stdin)['conversation_id'])")"
echo "conversation: $CID"

say "Send text → per-recipient translations (B reads in B's language, A in A's)"
curl -fsS -b "$JAR" -H 'content-type: application/json' \
  -d '{"type":"text","text":"Good morning","sourceLanguage":"en","clientId":"smoke-1"}' \
  "$BASE/api/conversations/$CID/messages" | head -c 200; echo
sleep 3
curl -fsS -b "$JAR" "$BASE/api/conversations/$CID/messages" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for m in d['messages'][-1:]:
    print('text:', m['originalText'])
    print('viewer.translation:', m['viewer']['translation'])
"

say "Voice upload + pipeline status (STT runs only with STT keys configured)"
MAX=262144
python3 - "$MAX" > /tmp/unicom_silence.b64 <<'PY'
import base64, sys, wave, struct, math, io
buf = io.BytesIO()
w = wave.open(buf, 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000)
for i in range(8000):
    w.writeframesraw(struct.pack('<h', int(600 * math.sin(2 * math.pi * 220 * i / 8000))))
w.close()
print(base64.b64encode(buf.getvalue()).decode())
PY
ASSET="$(curl -fsS -b "$JAR" -H 'content-type: application/json' \
  -d "{\"base64\":\"$(cat /tmp/unicom_silence.b64)\",\"mimeType\":\"audio/wav\",\"durationMs\":1000}" \
  "$BASE/api/media" | python3 -c "import sys,json;print(json.load(sys.stdin)['asset_id'])")"
echo "asset: $ASSET"
curl -fsS -b "$JAR" -H 'content-type: application/json' \
  -d "{\"type\":\"voice\",\"mediaAssetId\":\"$ASSET\",\"sourceLanguage\":\"en\",\"clientId\":\"smoke-voice-1\"}" \
  "$BASE/api/conversations/$CID/messages" | head -c 160; echo
sleep 4
curl -fsS -b "$JAR" "$BASE/api/conversations/$CID/messages" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for m in reversed(d['messages']):
    if m['type']=='voice':
        print('voice job:', m['viewer']['voiceJob'])
        print('transcript:', (m['originalText'] or '')[:80])
        break
"

say "Presigned media URL (R2 configured → 200 JSON, else demo bytes)"
curl -sS -b "$JAR" -o /dev/null -w "GET /api/media/$ASSET → %{http_code} (%{content_type})\n" "$BASE/api/media/$ASSET"

say "Done ✓"
