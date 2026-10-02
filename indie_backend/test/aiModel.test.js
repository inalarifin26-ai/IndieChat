// aiModel: prompt construction (pure) and the real-model-reply integration,
// with fetch mocked — no real network/API key needed to run these.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

const aiModel = require('../src/lib/aiModel');

test('isConfigured() reflects ANTHROPIC_API_KEY presence', () => {
  const prev = process.env.ANTHROPIC_API_KEY;
  delete process.env.ANTHROPIC_API_KEY;
  assert.strictEqual(aiModel.isConfigured(), false);
  process.env.ANTHROPIC_API_KEY = 'test-key';
  assert.strictEqual(aiModel.isConfigured(), true);
  if (prev === undefined) delete process.env.ANTHROPIC_API_KEY;
  else process.env.ANTHROPIC_API_KEY = prev;
});

test('systemPrompt lists the workflow and instructs refusal outside it', () => {
  const p = aiModel.systemPrompt({ name: 'Research Agent', role: 'Market research' }, ['Search public web data', 'Summarize findings']);
  assert.match(p, /Research Agent/);
  assert.match(p, /1\. Search public web data/);
  assert.match(p, /2\. Summarize findings/);
  assert.match(p, /outside your workflow/);
  assert.match(p, /Orchestrator/);
});

test('systemPrompt handles an agent with no workflow yet', () => {
  const p = aiModel.systemPrompt({ name: 'New Agent', role: '' }, []);
  assert.match(p, /no workflow defined yet/);
});

test('toAnthropicMessages collapses kinds to text, merges consecutive same-role turns, and starts with user', () => {
  const history = [
    { sender: 'agent', kind: 'text', text: 'leading assistant turn should be dropped' },
    { sender: 'user', kind: 'text', text: 'hello' },
    { sender: 'user', kind: 'file', text: '', kindPayload: null },
    { sender: 'agent', kind: 'text', text: 'hi there' },
    { sender: 'agent', kind: 'card', text: '' },
    { sender: 'user', kind: 'text', text: 'ok', deleted: false },
    { sender: 'user', kind: 'text', text: 'deleted one', deleted: true },
  ];
  history[2].kind = 'file'; // force the [sent a file] placeholder path
  const msgs = aiModel.toAnthropicMessages(history);
  assert.strictEqual(msgs[0].role, 'user', 'must start with a user turn');
  assert.strictEqual(msgs[0].content, 'hello\n[sent a file]');
  assert.strictEqual(msgs[1].role, 'assistant');
  assert.strictEqual(msgs[1].content, 'hi there\n[sent a result card]');
  assert.strictEqual(msgs[2].content, 'ok');
  assert.strictEqual(msgs.length, 3, 'deleted message excluded');
});

test('generateReply throws clearly when not configured', async () => {
  const prev = process.env.ANTHROPIC_API_KEY;
  delete process.env.ANTHROPIC_API_KEY;
  await assert.rejects(() => aiModel.generateReply({ agent: { name: 'X', role: '' }, steps: [], history: [] }), /ANTHROPIC_API_KEY/);
  if (prev !== undefined) process.env.ANTHROPIC_API_KEY = prev;
});

test('generateReply calls the real Anthropic endpoint shape and extracts text (fetch mocked)', async () => {
  const prevKey = process.env.ANTHROPIC_API_KEY;
  process.env.ANTHROPIC_API_KEY = 'test-key-123';
  const realFetch = global.fetch;
  let captured;
  global.fetch = async (url, opts) => {
    captured = { url, opts };
    return {
      ok: true,
      json: async () => ({ content: [{ type: 'text', text: 'Hello from the model!' }] }),
    };
  };
  try {
    const reply = await aiModel.generateReply({
      agent: { name: 'Research Agent', role: 'Market research' },
      steps: ['Search public web data'],
      history: [{ sender: 'user', kind: 'text', text: 'what can you do?' }],
    });
    assert.strictEqual(reply, 'Hello from the model!');
    assert.strictEqual(captured.url, 'https://api.anthropic.com/v1/messages');
    assert.strictEqual(captured.opts.headers['x-api-key'], 'test-key-123');
    const body = JSON.parse(captured.opts.body);
    assert.match(body.system, /Research Agent/);
    assert.deepStrictEqual(body.messages, [{ role: 'user', content: 'what can you do?' }]);
  } finally {
    global.fetch = realFetch;
    if (prevKey === undefined) delete process.env.ANTHROPIC_API_KEY;
    else process.env.ANTHROPIC_API_KEY = prevKey;
  }
});

test('generateReply throws on a non-OK response', async () => {
  process.env.ANTHROPIC_API_KEY = 'test-key-123';
  const realFetch = global.fetch;
  global.fetch = async () => ({ ok: false, status: 401, text: async () => '{"error":"unauthorized"}' });
  try {
    await assert.rejects(() => aiModel.generateReply({ agent: { name: 'X', role: '' }, steps: [], history: [] }), /401/);
  } finally {
    global.fetch = realFetch;
    delete process.env.ANTHROPIC_API_KEY;
  }
});

// ---- Route-level integration: the agent chat endpoint uses the live model
// when configured, and silently falls back to the scripted engine if the
// model call fails. ----

process.env.DB_PATH = path.join(__dirname, '.tmp-aimodel.db');
if (fs.existsSync(process.env.DB_PATH)) fs.rmSync(process.env.DB_PATH);
process.env.JWT_SECRET = 'test-secret';

const express = require('express');
const app = express();
app.use(express.json());
app.use('/auth', require('../src/routes/auth'));
app.use('/agents', require('../src/routes/agents'));

let server, base;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function api(method, url, token, body) {
  const res = await fetch(base + url, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null;
  try { json = await res.json(); } catch {}
  return { status: res.status, body: json };
}

test.before(async () => {
  await new Promise((r) => { server = app.listen(0, () => { base = `http://localhost:${server.address().port}`; r(); }); });
});
test.after(async () => {
  await new Promise((r) => server.close(r));
  for (const f of ['', '-wal', '-shm']) { try { fs.rmSync(process.env.DB_PATH + f); } catch {} }
});

test('agent chat uses the live model reply when ANTHROPIC_API_KEY is set', async () => {
  const reg = await api('POST', '/auth/register', null, { credential: 'live-model-test', seedDemo: true });
  const t = reg.body.token;
  const agents = (await api('GET', '/agents', t)).body;
  const research = agents.find((a) => a.name === 'Research Agent');

  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (typeof url === 'string' && url.includes('anthropic.com')) {
      return { ok: true, json: async () => ({ content: [{ type: 'text', text: 'Live model says hi, within my workflow.' }] }) };
    }
    return realFetch(url, opts);
  };
  process.env.ANTHROPIC_API_KEY = 'test-key-live';
  try {
    await api('POST', `/agents/${research.id}/messages`, t, { text: 'what are you up to?' });
    await sleep(1000);
    const msgs = (await api('GET', `/agents/${research.id}/messages`, t)).body;
    assert.ok(msgs.some((m) => m.text === 'Live model says hi, within my workflow.'));
  } finally {
    global.fetch = realFetch;
    delete process.env.ANTHROPIC_API_KEY;
  }
});

test('agent chat falls back to the scripted engine when the model call fails', async () => {
  const reg = await api('POST', '/auth/register', null, { credential: 'fallback-test', seedDemo: true });
  const t = reg.body.token;
  const agents = (await api('GET', '/agents', t)).body;
  const research = agents.find((a) => a.name === 'Research Agent');

  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (typeof url === 'string' && url.includes('anthropic.com')) throw new Error('simulated network failure');
    return realFetch(url, opts);
  };
  process.env.ANTHROPIC_API_KEY = 'test-key-fails';
  try {
    const sent = await api('POST', `/agents/${research.id}/messages`, t, { text: 'order me a pizza' });
    assert.strictEqual(sent.body.scope, 'out_of_scope', 'the deterministic scope verdict is unaffected by model success/failure');
    await sleep(1000);
    const msgs = (await api('GET', `/agents/${research.id}/messages`, t)).body;
    assert.ok(msgs.some((m) => m.text.includes('outside my workflow')), 'falls back to the scripted refusal');
  } finally {
    global.fetch = realFetch;
    delete process.env.ANTHROPIC_API_KEY;
  }
});

test('agent chat still works with no ANTHROPIC_API_KEY at all (default/offline mode)', async () => {
  delete process.env.ANTHROPIC_API_KEY;
  const reg = await api('POST', '/auth/register', null, { credential: 'no-key-test', seedDemo: true });
  const t = reg.body.token;
  const agents = (await api('GET', '/agents', t)).body;
  const research = agents.find((a) => a.name === 'Research Agent');
  await api('POST', `/agents/${research.id}/messages`, t, { text: 'please search public web data' });
  await sleep(1000);
  const msgs = (await api('GET', `/agents/${research.id}/messages`, t)).body;
  assert.ok(msgs.some((m) => m.text.includes('part of my workflow')));
});
