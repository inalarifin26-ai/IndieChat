/**
 * Server-side scope check. An agent may only act inside the workflow steps
 * the Orchestrator defined for it. Anything else is refused and the user is
 * pointed back to the Orchestrator (spec: Orchestrator defines the workflow,
 * the agent only executes it).
 */
function evaluate(agent, steps, text) {
  const lower = String(text || '').toLowerCase();
  if (/status|progress|update|kabar/.test(lower)) {
    return { kind: 'status', text: `Current status: ${agent.current_activity}.` };
  }
  const words = lower.split(/[^a-z0-9]+/).filter((w) => w.length > 3);
  let hit = null;
  for (const step of steps) {
    const sl = step.toLowerCase();
    for (const w of words) {
      if (!hit && sl.includes(w)) hit = step;
    }
  }
  if (hit) {
    return {
      kind: 'in_scope',
      hit,
      text: `On it — that is part of my workflow ("${hit}"). I will report back here when it is done.`,
    };
  }
  return {
    kind: 'out_of_scope',
    text: `That is outside my workflow, so I can't do it. I can only: ${steps.join('; ')}. To change what I do, ask the Orchestrator.`,
    payload: { cta: 'ask_orchestrator' },
  };
}

function resultCard(hit) {
  return {
    title: `Task update — ${hit}`,
    metrics: [['Workflow step', 'Completed'], ['Saved to', 'Vault']],
    insights: ['Result stored in your Personal Vault', 'Nothing outside my workflow was touched'],
  };
}

module.exports = { evaluate, resultCard };
