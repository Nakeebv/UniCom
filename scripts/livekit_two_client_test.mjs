/**
 * UniCom call integration test — proves two authorized clients join the SAME
 * LiveKit room (signaling-level). Run against the live API:
 *
 *   LIVEKIT_URL=… LIVEKIT_API_KEY=… LIVEKIT_API_SECRET=… \
 *   BASE=https://localhost:3000 node scripts/livekit_two_client_test.mjs
 *
 * Steps: register two users → share a conversation → invite (video) →
 * accept → mint both participant tokens → open two WebSockets to LiveKit →
 * assert: both joins carry the room name AND each stream reveals the other
 * participant's identity. Tokens must be fresh (5-min TTL).
 *
 * NOTE: this proves signaling-level room joining. Full media transport
 * (ICE/DTLS audio+video) requires two real WebRTC engines — browser or the
 * installed app — and can only be confirmed on physical devices.
 */
import fs from 'fs';
import crypto from 'crypto';

const BASE = process.env.BASE || 'http://localhost:3000';
const envs = Object.fromEntries(
  fs.readFileSync(new URL('../.env', import.meta.url), 'utf8')
    .split('\n').filter(l => l.includes('=') && !l.startsWith('#'))
    .map(l => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]));
const roomFromToken = (t) => {
  const p = t.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
  return JSON.parse(Buffer.from(p, 'base64').toString()).video.room;
};
const b64u = (x) => Buffer.from(x).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//, '_');

// 1) two users
const ts = Date.now();
for (const [u, n] of [['ict_a', 'Int A'], ['ict_b', 'Int B']]) {
  const r = await fetch(`${BASE}/api/auth/register`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ username: u, displayName: n, password: 'Passw0rd1', email: `${u}@test.local` }) });
  if (![200, 201, 409].includes(r.status)) throw new Error(`register ${u}: ${r.status}`);
}
const login = async (u) => {
  const r = await fetch(`${BASE}/api/auth/login`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ username: u, password: 'Passw0rd1' }) });
  return r.headers.get('set-cookie').split(';')[0];
};
const cookieA = await login('ict_a');
const cookieB = await login('ict_b');
const get = async (cookie, path) => (await fetch(`${BASE}${path}`, { headers: { cookie } })).json();
const post = async (cookie, path, body) => (await fetch(`${BASE}${path}`, { method: 'POST', headers: { cookie, 'content-type': 'application/json' }, body: JSON.stringify(body) })).json();

// 2) shared conversation + invite + accept
const contacts = await get(cookieA, '/api/contacts');
const bId = contacts.contacts.find(c => c.username === 'ict_b').id;
await post(cookieA, '/api/conversations', { memberIds: [bId] });
const call = await post(cookieA, '/api/calls', { calleeId: bId, callType: 'audio' });
console.log('invite:', call.call_id, '| room:', call.room);
await post(cookieB, `/api/calls/${call.call_id}/accept`, {});
const tokens = {
  a: await post(cookieA, '/api/calls/token', { callId: call.call_id }),
  b: await post(cookieB, '/api/calls/token', { callId: call.call_id }),
};

// 3) two signaling clients → same room, mutual presence
const host = tokens.a.url.replace(/^wss:\/\//, '');
const room = roomFromToken(tokens.a.token);
const idA = tokens.a.identity, idB = tokens.b.identity;
function connect(token, watchFor) {
  return new Promise((resolve) => {
    const ws = new WebSocket(`wss://${host}/rtc?access_token=${encodeURIComponent(token)}&auto_subscribe=1&sdk=js&version=0.1`);
    ws.binaryType = 'arraybuffer';
    const res = { open: false, sawRoom: false, sawPeer: false };
    ws.onopen = () => { res.open = true; };
    ws.onmessage = (ev) => {
      const buf = ev.data instanceof ArrayBuffer ? ev.data : null;
      if (!buf) return;
      const bytes = new Uint8Array(buf);
      const scan = (needle, hay) => {
        search: for (let i = 0; i <= hay.length - needle.length; i++) {
          for (let j = 0; j < needle.length; j++) if (hay[i + j] !== needle[j]) continue search;
          return true;
        }
        return false;
      };
      if (scan(new TextEncoder().encode(room), bytes)) res.sawRoom = true;
      if (watchFor && scan(new TextEncoder().encode(watchFor), bytes)) res.sawPeer = true;
    };
    setTimeout(() => resolve({ ws, res }), 5000);
  });
}
const rA = await connect(tokens.a.token, idB);
await new Promise(r => setTimeout(r, 1500));
const [rB] = [await connect(tokens.b.token, idA)];
await new Promise(r => setTimeout(r, 2500));
rA.ws.close(); rB.ws.close();

console.log(`A: open=${rA.res.open} roomInJoin=${rA.res.sawRoom} sawB=${rA.res.sawPeer}`);
console.log(`B: open=${rB.res.open} roomInJoin=${rB.res.sawRoom} sawA=${rB.res.sawPeer}`);
const pass = rA.res.open && rB.res.open && rA.res.sawRoom && rB.res.sawRoom && rA.res.sawPeer && rB.res.sawPeer;
console.log(pass ? '✅ TWO-CLIENT SAME-ROOM JOIN PROVEN' : '❌ join proof failed');
process.exit(pass ? 0 : 1);
