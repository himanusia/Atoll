#!/usr/bin/env node
/**
 * txnote — Atoll plugin for local meeting transcription (no summarization).
 *
 * Surfaces:
 *   - Atoll Live Activity while recording: title + elapsed time + live word count
 *   - local control panel at http://127.0.0.1:8899 (start/stop, model, live transcript)
 *   - optional Atoll notch tab that renders the panel as web content
 *
 * Engine: `tx` CLI (~/.hermes/bin/tx) -> txrec (CoreAudio tap) + mlx-whisper.
 */
'use strict';

const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const http = require('node:http');
const { spawn, execFile } = require('node:child_process');

const HOME = process.env.HOME;
// SDK: local dependency of this extension (npm i), fallback to the copy Hermes ships.
let SDK;
try {
  SDK = require.resolve('@ebullioscopic/atoll-js');
} catch {
  SDK = path.join(HOME, '.hermes/plugins/hermes-atoll/node_modules/@ebullioscopic/atoll-js');
}
const {
  AtollClient, createLiveActivity, AtollLiveActivityPriority, AtollColors,
  symbolIcon, systemFont, monospacedDigitFont,
} = require(SDK);

const BUNDLE = process.env.TX_ATOLL_BUNDLE || 'dev.hima.notch-plugins';
const TX = process.env.TX_BIN || path.join(HOME, '.hermes/bin/tx');
const STATE_FILE = path.join(HOME, '.hermes/state/txrec.json');
const CONFIG_FILE = path.join(HOME, '.hermes/txnote/config.json');
const PORT = Number(process.env.TX_PORT || 8899);
const ACTIVITY_ID = 'txnote-recording';
const EXPERIENCE_ID = 'txnote-panel';

const log = (...a) => console.log(`[${new Date().toISOString()}]`, ...a);

// ---------------------------------------------------------------- state

function readJson(p, fallback = null) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return fallback; }
}

function recorderState() {
  const s = readJson(STATE_FILE);
  if (!s || !s.pid) return { recording: false };
  try { process.kill(s.pid, 0); } catch { return { recording: false }; }
  return { recording: true, pid: s.pid, dir: s.dir, started: s.started, source: s.source };
}

function elapsedSeconds(startedIso) {
  const t = Date.parse(startedIso || '');
  if (!Number.isFinite(t)) return 0;
  return Math.max(0, Math.round((Date.now() - t) / 1000));
}

function fmtClock(sec) {
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
  return h > 0
    ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
    : `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function transcriptInfo(dir) {
  if (!dir) return { words: 0, last: '', text: '' };
  const p = path.join(dir, 'transcript.txt');
  let text = '';
  try { text = fs.readFileSync(p, 'utf8').trim(); } catch { /* not yet */ }
  const words = text ? text.split(/\s+/).length : 0;
  const parts = text.split(/(?<=[.!?])\s+/).filter(Boolean);
  const last = parts.length ? parts[parts.length - 1] : '';
  return { words, last: last.slice(0, 220), text };
}

function snapshot() {
  const rec = recorderState();
  const cfg = readJson(CONFIG_FILE, { model: 'large-v3', language: 'id' });
  const t = rec.recording ? transcriptInfo(rec.dir) : { words: 0, last: '', text: '' };
  return {
    recording: rec.recording,
    dir: rec.dir || null,
    elapsed: rec.recording ? elapsedSeconds(rec.started) : 0,
    clock: rec.recording ? fmtClock(elapsedSeconds(rec.started)) : '00:00',
    source: rec.source || null,
    model: cfg.model, language: cfg.language,
    words: t.words, last: t.last,
  };
}

// ---------------------------------------------------------------- engine control

function txRun(args, cb) {
  execFile(TX, args, { timeout: 120000 }, (err, stdout, stderr) => {
    if (err) log('tx', args.join(' '), 'failed:', (stderr || err.message).slice(0, 300));
    cb?.(err, stdout, stderr);
  });
}

function startRecording() {
  return new Promise((resolve) => {
    txRun(['start', '--global', '--chunk', '20'], () => resolve(snapshot()));
  });
}

function stopRecording() {
  return new Promise((resolve) => {
    txRun(['stop'], () => resolve(snapshot()));
  });
}

let stopping = false;
async function toggle() {
  const s = snapshot();
  if (s.recording) {
    if (stopping) return s;
    stopping = true;
    try { return await stopRecording(); } finally { stopping = false; }
  }
  return startRecording();
}

// keep the transcript warm while recording (cached per chunk, cheap on repeat)
let processing = false;
function tickProcess() {
  const s = snapshot();
  if (!s.recording || !s.dir || processing) return;
  processing = true;
  execFile(TX, ['process', s.dir], { timeout: 180000 }, (err) => {
    processing = false;
    if (err) log('process tick failed:', err.message);
  });
}

// ---------------------------------------------------------------- http panel

const PAGE = `<!doctype html><html><head><meta charset="utf-8">
<title>txnote</title><style>
 :root{color-scheme:dark}
 *{box-sizing:border-box}
 body{margin:0;font:13px/1.45 -apple-system,system-ui,sans-serif;background:#0b0b0d;color:#e9e9ee;padding:12px}
 .row{display:flex;align-items:center;gap:10px}
 .dot{width:9px;height:9px;border-radius:50%;background:#4b4b55}
 .dot.rec{background:#ff3b30;box-shadow:0 0 8px #ff3b30}
 .clock{font-variant-numeric:tabular-nums;font-weight:600;letter-spacing:.03em}
 .muted{color:#8a8a95}
 .btn{border:0;border-radius:8px;padding:9px 14px;font-weight:600;font-size:13px;cursor:pointer}
 .start{background:#ff3b30;color:#fff}
 .stop{background:#2c2c31;color:#fff}
 .meta{font-size:11px;color:#8a8a95;margin-top:6px}
 #last{margin-top:10px;padding:9px 10px;border-radius:8px;background:#141418;color:#c9c9d2;min-height:38px;font-size:12px}
 select{background:#1a1a1f;color:#e9e9ee;border:1px solid #2a2a30;border-radius:6px;padding:5px 6px;font-size:12px}
</style></head><body>
<div class="row">
  <span class="dot" id="dot"></span>
  <span class="clock" id="clock">00:00</span>
  <span class="muted" id="src"></span>
  <span style="flex:1"></span>
  <button class="btn start" id="btn">● REC</button>
</div>
<div class="meta">
  <span id="model"></span> · <span id="lang"></span> · <span id="words">0</span> kata
  · <select id="msel">
    <option value="large-v3">large-v3</option>
    <option value="large-v3-turbo">turbo</option>
    <option value="small">small</option>
  </select>
</div>
<div id="last">—</div>
<script>
let busy=false;
async function refresh(){
  try{
    const s = await (await fetch('/state')).json();
    document.getElementById('dot').className = 'dot'+(s.recording?' rec':'');
    document.getElementById('clock').textContent = s.clock;
    document.getElementById('src').textContent = s.recording ? (s.source||'') : 'idle';
    document.getElementById('model').textContent = s.model;
    document.getElementById('lang').textContent = s.language;
    document.getElementById('words').textContent = s.words;
    document.getElementById('last').textContent = s.last || '—';
    const b = document.getElementById('btn');
    b.textContent = s.recording ? '■ STOP' : '● REC';
    b.className = 'btn '+(s.recording?'stop':'start');
    document.getElementById('msel').value = s.model;
  }catch(e){}
}
document.getElementById('btn').onclick = async () => {
  if(busy) return; busy=true;
  try{ await fetch('/toggle',{method:'POST'}); }catch(e){}
  busy=false; refresh();
};
document.getElementById('msel').onchange = async (e) => {
  await fetch('/model',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({model:e.target.value})});
  refresh();
};
refresh(); setInterval(refresh, 1500);
</script></body></html>`;

function startHttp() {
  const server = http.createServer((req, res) => {
    const url = req.url.split('?')[0];
    const send = (code, body, type = 'application/json') => {
      res.writeHead(code, { 'content-type': type, 'cache-control': 'no-store' });
      res.end(body);
    };
    if (url === '/' || url === '/index.html') return send(200, PAGE, 'text/html; charset=utf-8');
    if (url === '/state') return send(200, JSON.stringify(snapshot()));
    if (url === '/toggle') {
      toggle().then((s) => send(200, JSON.stringify(s))).catch((e) => send(500, JSON.stringify({ error: String(e) })));
      return;
    }
    if (url === '/model') {
      let body = '';
      req.on('data', (c) => { body += c; });
      req.on('end', () => {
        try {
          const { model } = JSON.parse(body || '{}');
          const cfg = readJson(CONFIG_FILE, {});
          cfg.model = model;
          fs.writeFileSync(CONFIG_FILE, JSON.stringify(cfg, null, 2) + '\n');
          send(200, JSON.stringify(snapshot()));
        } catch (e) { send(400, JSON.stringify({ error: String(e) })); }
      });
      return;
    }
    send(404, JSON.stringify({ error: 'not found' }));
  });
  server.on('error', (e) => log('http error:', e.message));
  server.listen(PORT, '127.0.0.1', () => log(`panel: http://127.0.0.1:${PORT}`));
}

// ---------------------------------------------------------------- atoll surfaces

let client = null;
let presented = false;

async function connectAtoll() {
  client = new AtollClient({ bundleIdentifier: BUNDLE });
  await client.connect();
  const ok = await client.checkAuthorization().catch(() => false) || await client.requestAuthorization();
  if (!ok) throw new Error('Atoll authorization refused');
  log('atoll connected, authorized');
}

function activity(s) {
  return createLiveActivity({
    id: ACTIVITY_ID,
    bundleIdentifier: BUNDLE,
    title: 'Transkrip',
    subtitle: s.words ? `${s.words} kata` : 'merekam',
    leadingIcon: symbolIcon('waveform'),
    trailingContent: { type: 'text', text: s.clock, font: monospacedDigitFont(13) },
    priority: AtollLiveActivityPriority.High,
    accentColor: AtollColors.accent,
    allowsMusicCoexistence: true,
  });
}

async function pushActivity() {
  if (!client) return;
  const s = snapshot();
  try {
    if (s.recording) {
      if (!presented) { await client.presentLiveActivity(activity(s)); presented = true; log('activity presented'); }
      else await client.updateLiveActivity(activity(s));
    } else if (presented) {
      await client.dismissLiveActivity(ACTIVITY_ID);
      presented = false;
      log('activity dismissed');
    }
  } catch (e) {
    log('activity push failed:', e.message);
    if (/not authorized|authorization/i.test(e.message)) { presented = false; }
  }
}

async function presentPanel() {
  try {
    await client.presentNotchExperience({
      id: EXPERIENCE_ID,
      bundleIdentifier: BUNDLE,
      priority: AtollLiveActivityPriority.Normal,
      accentColor: AtollColors.accent,
      tab: {
        title: 'Transkrip',
        iconSymbolName: 'waveform',
        sections: [],
        allowWebInteraction: true,
        preferredHeight: 170,
        webContent: {
          html: PAGE,
          preferredHeight: 150,
          isTransparent: true,
          allowLocalhostRequests: true,
          allowRemoteRequests: false,
        },
      },
    });
    log('notch panel presented');
  } catch (e) {
    log('notch panel unavailable:', e.message);
  }
}

// ---------------------------------------------------------------- main

(async () => {
  startHttp();
  await connectAtoll();
  await pushActivity();
  await presentPanel().catch(() => {});

  setInterval(pushActivity, 5000);
  setInterval(tickProcess, 9000);
  process.on('SIGINT', async () => {
    try { await client?.dismissLiveActivity(ACTIVITY_ID); } catch {}
    process.exit(0);
  });
})().catch((e) => { log('FATAL:', e.message); process.exit(1); });
