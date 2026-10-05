// sprite-sheet-generator — local server
//
// Zero-dependency Node HTTP server. It does two things:
//   1. Serves the static single-page app from ./public
//   2. Proxies quality-check requests to a LOCAL LLM (Ollama at :11434)
//
// Everything runs on localhost. No hosted/paid APIs are ever contacted.
// If Ollama isn't running or has no vision model, the app still works fully —
// the frontend falls back to computed image metrics for the quality checks.

import { createServer } from 'node:http';
import { readFile, stat, writeFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIR = join(__dirname, 'public');
const PORT = process.env.PORT || 5173;
const OLLAMA = process.env.OLLAMA_HOST || 'http://localhost:11434';
// Local Stable Diffusion (AUTOMATIC1111 / Forge / SD.Next) img2img backend.
const SD = process.env.SD_HOST || 'http://localhost:7860';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
};

function readBody(req, limitBytes = 25 * 1024 * 1024) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > limitBytes) {
        reject(new Error('payload too large'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function sendJSON(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  res.end(body);
}

// --- Local LLM (Ollama) helpers -------------------------------------------

async function ollamaTags() {
  const r = await fetch(`${OLLAMA}/api/tags`, { signal: AbortSignal.timeout(2500) });
  if (!r.ok) throw new Error(`ollama tags ${r.status}`);
  return r.json();
}

// Pick an installed vision-capable model, if any.
function pickVisionModel(tags) {
  const names = (tags?.models || []).map((m) => m.name);
  const prefer = ['llama3.2-vision', 'llava', 'bakllava', 'moondream', 'minicpm-v', 'qwen2.5vl', 'gemma3'];
  for (const p of prefer) {
    const hit = names.find((n) => n.toLowerCase().startsWith(p));
    if (hit) return hit;
  }
  // Any model with "vision" / "vl" in the name as a last resort.
  return names.find((n) => /vision|vl|llava|moondream/i.test(n)) || null;
}

// --- Routes ----------------------------------------------------------------

// GET /api/llm/status -> which local model (if any) is available for checks
async function handleLlmStatus(res) {
  try {
    const tags = await ollamaTags();
    const model = pickVisionModel(tags);
    sendJSON(res, 200, {
      available: !!model,
      model,
      models: (tags?.models || []).map((m) => m.name),
      host: OLLAMA,
    });
  } catch (e) {
    sendJSON(res, 200, { available: false, model: null, models: [], host: OLLAMA, error: String(e.message || e) });
  }
}

// POST /api/llm/check { model, action, frameCount, images: [dataURL,...] }
// Asks a local vision model to sanity-check the generated animation row.
async function handleLlmCheck(req, res) {
  let payload;
  try {
    payload = JSON.parse(await readBody(req));
  } catch {
    return sendJSON(res, 400, { error: 'bad json' });
  }
  const { model, action, frameCount } = payload;
  const images = (payload.images || []).map((d) => String(d).replace(/^data:image\/\w+;base64,/, ''));
  if (!model || !images.length) return sendJSON(res, 400, { error: 'model and images required' });

  const prompt =
    `This image is a contact sheet: ${frameCount} sequential animation frames for a game sprite, ` +
    `laid out left-to-right, performing the action "${action}". ` +
    `Assess it as one animation row of a sprite sheet. Reply with STRICT JSON only, no prose, shaped as:\n` +
    `{"positioning": 0-100, "visual": 0-100, "accuracy": 0-100, "notes": "one short sentence"}\n` +
    `"positioning" = how consistent the character's placement/registration is across frames. ` +
    `"visual" = how consistent the art style/colors are. ` +
    `"accuracy" = how well the frames depict the "${action}" action.`;

  try {
    const r = await fetch(`${OLLAMA}/api/generate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        model,
        prompt,
        images, // Ollama accepts base64 images on /api/generate for vision models
        stream: false,
        format: 'json',
        options: { temperature: 0, num_ctx: 4096 },
      }),
      signal: AbortSignal.timeout(120000),
    });
    if (!r.ok) return sendJSON(res, 502, { error: `ollama ${r.status}` });
    const data = await r.json();
    let parsed = null;
    try {
      parsed = JSON.parse(data.response);
    } catch {
      /* fall through */
    }
    sendJSON(res, 200, { ok: true, model, result: parsed, raw: parsed ? undefined : data.response });
  } catch (e) {
    sendJSON(res, 502, { error: String(e.message || e) });
  }
}

// --- Local diffusion (Stable Diffusion img2img) ----------------------------

// GET /api/diffusion/status -> is a local SD backend reachable?
async function handleDiffusionStatus(res) {
  try {
    const r = await fetch(`${SD}/sdapi/v1/options`, { signal: AbortSignal.timeout(2000) });
    if (!r.ok) throw new Error(`sd ${r.status}`);
    let model = null;
    try {
      const opts = await r.json();
      model = opts.sd_model_checkpoint || null;
    } catch { /* options body optional */ }
    sendJSON(res, 200, { available: true, host: SD, backend: 'a1111', model });
  } catch (e) {
    sendJSON(res, 200, { available: false, host: SD, error: String(e.message || e) });
  }
}

// Prompt for pose-conditioned generation. ControlNet supplies the pose, the init
// image supplies the character identity, and the prompt reinforces style + a flat
// background (so the client can key it out for transparent output).
function diffusionPrompt(action) {
  return {
    // "pixelsprite" is the trigger word for the pixel-art sprite checkpoint
    prompt:
      `pixelsprite, 2D game character sprite performing "${action}", full body, ` +
      `single isolated character, centered, plain solid flat background`,
    negative_prompt:
      `photo, realistic, 3d render, blurry, low quality, jpeg artifacts, deformed, ` +
      `extra limbs, extra people, multiple characters, text, watermark, signature, ` +
      `cropped, border, frame, busy background, scenery`,
  };
}

// The ControlNet extension lists models with a hash suffix; look them up by regex.
let cnModelList;
async function cnModels() {
  if (cnModelList !== undefined) return cnModelList;
  try {
    const r = await fetch(`${SD}/controlnet/model_list`, { signal: AbortSignal.timeout(4000) });
    if (!r.ok) throw new Error(`cn ${r.status}`);
    cnModelList = (await r.json()).model_list || [];
  } catch {
    cnModelList = [];
  }
  return cnModelList;
}
const cnFind = async (re) => (await cnModels()).find((m) => re.test(m)) || null;

const genSize = (w, h) => {
  // SD 1.5 mushes at sprite dimensions — generate at a 512-class resolution
  // (long edge ~512, /8-aligned, aspect preserved); the client downscales.
  const long = Math.max(w || 512, h || 512);
  const s = long < 512 ? 512 / long : 1;
  const round8 = (n) => Math.max(64, Math.round((n * s) / 8) * 8);
  return { gw: round8(w || 512), gh: round8(h || 512) };
};

// POST /api/diffusion/img2img
//   { image, controlImage?, reference?, action, width, height, seed?, denoise? }
// With a controlImage we run txt2img + two ControlNet units — OpenPose (pose) and
// IP-Adapter (identity, from `reference`) — so the pose comes from the skeleton and
// the character from the reference. Falls back to OpenPose-only img2img, then to a
// low-denoise img2img polish, depending on which models are installed.
async function handleDiffusionImg2img(req, res) {
  let payload;
  try {
    payload = JSON.parse(await readBody(req));
  } catch {
    return sendJSON(res, 400, { error: 'bad json' });
  }
  const strip = (d) => String(d || '').replace(/^data:image\/\w+;base64,/, '');
  const { action, width, height } = payload;
  const initImage = strip(payload.image);
  if (!initImage) return sendJSON(res, 400, { error: 'image required' });
  const controlImage = strip(payload.controlImage);
  const reference = strip(payload.reference) || initImage;
  const seed = typeof payload.seed === 'number' ? payload.seed : 42;
  const { gw, gh } = genSize(width, height);
  const { prompt, negative_prompt } = diffusionPrompt(action);

  const openposeModel = controlImage ? await cnFind(/openpose/i) : null;
  const ipAdapterModel = controlImage ? await cnFind(/ip[-_]?adapter_sd15/i) : null;

  try {
    let endpoint, body;
    if (controlImage && openposeModel && ipAdapterModel) {
      // The proper "same character, new pose": txt2img with OpenPose (pose) +
      // IP-Adapter (identity from the reference). No init to fight the pose, so
      // ControlNet fully restages the body while IP-Adapter holds the character.
      endpoint = '/sdapi/v1/txt2img';
      body = {
        prompt,
        negative_prompt,
        steps: 26,
        cfg_scale: 7,
        sampler_name: 'DPM++ 2M Karras',
        width: gw,
        height: gh,
        seed,
        alwayson_scripts: {
          controlnet: {
            args: [
              {
                enabled: true, // REQUIRED — units default to disabled via the API
                image: controlImage,
                module: 'none', // skeleton IS the pose map
                model: openposeModel,
                weight: 1.25,
                resize_mode: 'Just Resize',
                control_mode: 'ControlNet is more important',
                pixel_perfect: true,
              },
              {
                enabled: true,
                image: reference,
                module: 'ip-adapter_clip_sd15', // encodes the character's appearance
                model: ipAdapterModel,
                weight: 1.1,
                resize_mode: 'Crop and Resize',
                control_mode: 'Balanced',
                pixel_perfect: true,
              },
            ],
          },
        },
      };
    } else if (controlImage && openposeModel) {
      // fallback (no IP-Adapter): OpenPose-only img2img from the source
      const denoise = typeof payload.denoise === 'number' ? payload.denoise : 0.65;
      endpoint = '/sdapi/v1/img2img';
      body = {
        init_images: [reference],
        prompt,
        negative_prompt,
        denoising_strength: denoise,
        steps: 26,
        cfg_scale: 7,
        sampler_name: 'DPM++ 2M Karras',
        width: gw,
        height: gh,
        seed,
        resize_mode: 0,
        alwayson_scripts: {
          controlnet: {
            args: [{
              enabled: true,
              image: controlImage,
              module: 'none',
              model: openposeModel,
              weight: 1.2,
              resize_mode: 'Just Resize',
              control_mode: 'ControlNet is more important',
              pixel_perfect: true,
            }],
          },
        },
      };
    } else {
      // no pose control: low-denoise polish of the provided frame
      const denoise = typeof payload.denoise === 'number' ? payload.denoise : 0.35;
      endpoint = '/sdapi/v1/img2img';
      body = {
        init_images: [initImage],
        prompt,
        negative_prompt,
        denoising_strength: denoise,
        steps: 24,
        cfg_scale: 7,
        sampler_name: 'Euler a',
        width: gw,
        height: gh,
        seed,
        resize_mode: 0,
      };
    }

    const r = await fetch(`${SD}${endpoint}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(300000),
    });
    if (!r.ok) return sendJSON(res, 502, { error: `sd ${r.status}` });
    const data = await r.json();
    const b64 = data.images && data.images[0];
    if (!b64) return sendJSON(res, 502, { error: 'sd returned no image' });
    sendJSON(res, 200, { image: `data:image/png;base64,${b64}` });
  } catch (e) {
    sendJSON(res, 502, { error: String(e.message || e) });
  }
}

// --- Static file serving ---------------------------------------------------

async function serveStatic(req, res) {
  let urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (urlPath === '/') urlPath = '/index.html';
  // Prevent path traversal.
  const safe = normalize(urlPath).replace(/^(\.\.[/\\])+/, '');
  const filePath = join(PUBLIC_DIR, safe);
  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    return res.end('forbidden');
  }
  try {
    const info = await stat(filePath);
    if (info.isDirectory()) throw new Error('is dir');
    const data = await readFile(filePath);
    res.writeHead(200, { 'content-type': MIME[extname(filePath)] || 'application/octet-stream' });
    res.end(data);
  } catch {
    res.writeHead(404, { 'content-type': 'text/plain' });
    res.end('not found');
  }
}

const server = createServer(async (req, res) => {
  const { pathname } = new URL(req.url, 'http://x');
  try {
    // Local trial export only; animation generation is unchanged.
    if (pathname === '/__local/export' && req.method === 'POST') {
      if (req.headers.origin !== `http://127.0.0.1:${PORT}`) return sendJSON(res, 403, {error: 'origin'});
      const encoded = await readBody(req, 2 * 1024 * 1024);
      const png = Buffer.from(encoded, 'base64');
      if (png.length < 8 || png.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') return sendJSON(res, 400, {error: 'png'});
      await writeFile(join(__dirname, '../sprite-sheet-test/pojun_walk_transform_8.png'), png);
      return sendJSON(res, 200, {saved: true});
    }
    if (pathname === '/api/llm/status' && req.method === 'GET') return await handleLlmStatus(res);
    if (pathname === '/api/llm/check' && req.method === 'POST') return await handleLlmCheck(req, res);
    if (pathname === '/api/diffusion/status' && req.method === 'GET') return await handleDiffusionStatus(res);
    if (pathname === '/api/diffusion/img2img' && req.method === 'POST') return await handleDiffusionImg2img(req, res);
    return await serveStatic(req, res);
  } catch (e) {
    sendJSON(res, 500, { error: String(e.message || e) });
  }
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`\n  sprite-sheet-generator running at  http://localhost:${PORT}`);
  console.log(`  local diffusion (SD img2img) at    ${SD}   (default engine)`);
  console.log(`  local LLM (Ollama) expected at     ${OLLAMA}`);
  console.log(`  (the app works fully even if both are offline)\n`);
});
