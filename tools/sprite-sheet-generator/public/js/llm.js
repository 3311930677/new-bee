// llm.js — thin client for the LOCAL LLM (Ollama), proxied by our server.
// All calls go to our own origin (/api/llm/*), which forwards to localhost:11434.

let cachedStatus = null;

export async function llmStatus() {
  if (cachedStatus) return cachedStatus;
  try {
    const r = await fetch('/api/llm/status');
    cachedStatus = await r.json();
  } catch (e) {
    cachedStatus = { available: false, model: null, error: String(e) };
  }
  return cachedStatus;
}

/**
 * Ask the local vision model to grade an animation row.
 * @param {string} model model name from llmStatus()
 * @param {string} action action name
 * @param {number} frameCount
 * @param {string[]} images data-URL PNGs (a sampled subset of frames)
 * @returns {Promise<{positioning:number,visual:number,accuracy:number,notes?:string}|null>}
 */
export async function llmCheckRow(model, action, frameCount, images) {
  try {
    const r = await fetch('/api/llm/check', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ model, action, frameCount, images }),
    });
    if (!r.ok) return null;
    const data = await r.json();
    return data.result || null;
  } catch {
    return null;
  }
}
