// diffusion.js — client for LOCAL Stable Diffusion image generation.
//
// Talks to our own server (/api/diffusion/*), which proxies to a local
// AUTOMATIC1111 img2img endpoint (default :7860) with the ControlNet extension.
//
// Design: SD can't invent coherent animation, so we drive each frame with a
// target POSE. `poses.js` builds an OpenPose skeleton for the action/frame; that
// skeleton is sent as a ControlNet control image while the source image supplies
// the character identity — SD generates the character INTO the pose. A fixed seed
// across the row keeps the character consistent. Transparent output is obtained
// by flood-filling SD's flat background from the edges.

import { removeBackground } from './bgremove.js';
import { renderPose } from './poses.js';

let cached = null;

export async function diffusionStatus() {
  if (cached) return cached;
  try {
    const r = await fetch('/api/diffusion/status');
    cached = await r.json();
  } catch (e) {
    cached = { available: false, error: String(e) };
  }
  return cached;
}

export function resetDiffusionStatus() {
  cached = null;
}

// Neutral backdrop to place the source character on for the init image.
const INIT_BG = '#8a8d99';

/**
 * Generate one frame: SD renders the source character into the action's pose
 * (ControlNet OpenPose).
 * @param {HTMLCanvasElement} source the (processed) source character
 * @param {number} w frame width
 * @param {number} h frame height
 * @param {string} action action name
 * @param {number} i frame index
 * @param {number} total total frames
 * @param {object} opts { transparent, bgColor, seed, denoise }
 * @returns {Promise<HTMLCanvasElement>} a w×h canvas
 */
export async function diffusionFrame(source, w, h, action, i, total, opts = {}) {
  // init image = the source character on a flat backdrop (identity reference)
  const init = document.createElement('canvas');
  init.width = w;
  init.height = h;
  const ictx = init.getContext('2d');
  ictx.fillStyle = opts.transparent ? INIT_BG : opts.bgColor || INIT_BG;
  ictx.fillRect(0, 0, w, h);
  ictx.imageSmoothingEnabled = false;
  ictx.drawImage(source, 0, 0);

  // control image = the OpenPose skeleton for this action/frame (rendered larger
  // for a crisp pose map; ControlNet resizes to the generation size)
  const skelH = 512;
  const skelW = Math.max(64, Math.round((512 * w) / h));
  const skeleton = renderPose(action, i, total, skelW, skelH);

  const r = await fetch('/api/diffusion/img2img', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      image: init.toDataURL('image/png'),
      controlImage: skeleton.toDataURL('image/png'),
      // higher-detail identity reference (falls back to the init on the server)
      reference: (opts.reference || source).toDataURL('image/png'),
      action,
      width: w,
      height: h,
      seed: opts.seed ?? 42, // same for every frame in the row → consistency
      ...(opts.denoise != null ? { denoise: opts.denoise } : {}),
    }),
  });
  if (!r.ok) throw new Error(`diffusion ${r.status}`);
  const data = await r.json();
  if (!data.image) throw new Error('diffusion: no image returned');

  const img = new Image();
  await new Promise((res, rej) => {
    img.onload = res;
    img.onerror = rej;
    img.src = data.image;
  });
  const out = document.createElement('canvas');
  out.width = w;
  out.height = h;
  const octx = out.getContext('2d');
  octx.imageSmoothingEnabled = false;
  octx.drawImage(img, 0, 0, w, h); // downscale SD's ~512px result to frame size

  // knock out SD's flat background from the edges for transparent output
  return opts.transparent ? removeBackground(out, 60) : out;
}
