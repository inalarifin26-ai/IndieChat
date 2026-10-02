/**
 * Optional real-model replies for agent chats, via the Anthropic Messages
 * API. Entirely opt-in: with no ANTHROPIC_API_KEY set, isConfigured()
 * returns false and callers fall back to the scripted scope engine
 * (lib/agentScope.js) exactly as before — nothing breaks without a key.
 *
 * The model is told, in the system prompt, exactly which workflow steps the
 * Orchestrator defined for this agent and instructed to refuse anything
 * outside them — the same boundary the scripted engine enforces, just
 * phrased by the model instead of a template. This is prompt-level
 * enforcement, not a hard guarantee; lib/agentScope.js's keyword check
 * remains the deterministic fallback and is cheap enough to also log
 * alongside the model's answer for comparison (see routes/agents.js).
 */

const API_URL = 'https://api.anthropic.com/v1/messages';
const MODEL = process.env.ANTHROPIC_MODEL || 'claude-haiku-4-5-20251001';
const MAX_TOKENS = 300;

function isConfigured() {
  return !!process.env.ANTHROPIC_API_KEY;
}

function systemPrompt(agent, steps) {
  const stepList = steps.length ? steps.map((s, i) => `${i + 1}. ${s}`).join('\n') : '(no workflow defined yet)';
  return [
    `You are "${agent.name}", an AI agent inside the Indie personal agentic messaging platform.`,
    `Your role: ${agent.role || 'general assistant'}.`,
    '',
    'The Orchestrator — not you — defines what you are allowed to do. Your workflow, exactly as defined, is:',
    stepList,
    '',
    'Rules:',
    '- Only act on, or discuss doing, things that are clearly covered by the workflow above.',
    '- If the user asks for anything outside it, say plainly that it is outside your workflow and suggest they ask the Orchestrator to update it. Do not attempt the task anyway.',
    '- Keep replies short and conversational (2-4 sentences), like a chat message, not a report.',
    '- Never claim to have taken a real external action (publishing, sending, purchasing) — you can only describe what you would do; approvals and execution happen through the workflow engine, not this chat.',
  ].join('\n');
}

function toAnthropicMessages(history) {
  // Anthropic requires alternating user/assistant turns starting with user;
  // collapse our richer message kinds down to plain text for context.
  const msgs = [];
  for (const m of history) {
    if (m.deleted) continue;
    const role = m.sender === 'user' ? 'user' : 'assistant';
    const text = m.text || (m.kind === 'card' ? '[sent a result card]' : m.kind === 'file' ? '[sent a file]' : '');
    if (!text) continue;
    if (msgs.length && msgs[msgs.length - 1].role === role) {
      msgs[msgs.length - 1].content += `\n${text}`;
    } else {
      msgs.push({ role, content: text });
    }
  }
  if (msgs.length && msgs[0].role !== 'user') msgs.shift();
  return msgs;
}

/**
 * @returns {Promise<string>} the model's reply text.
 * @throws if not configured, the request fails, or the response is malformed.
 */
async function generateReply({ agent, steps, history }) {
  if (!isConfigured()) throw new Error('ANTHROPIC_API_KEY is not set');
  const res = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': process.env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: systemPrompt(agent, steps),
      messages: toAnthropicMessages(history),
    }),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Anthropic API ${res.status}: ${body.slice(0, 200)}`);
  }
  const data = await res.json();
  const text = (data.content || []).filter((b) => b.type === 'text').map((b) => b.text).join('\n').trim();
  if (!text) throw new Error('Anthropic API returned no text content');
  return text;
}

module.exports = { isConfigured, generateReply, systemPrompt, toAnthropicMessages, MODEL };
