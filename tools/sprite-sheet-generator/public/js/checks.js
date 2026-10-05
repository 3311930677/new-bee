// checks.js — quality checks for a generated animation row.
//
// The three scores mirror the design's checklist and are computed from the
// actual generated pixels (not faked):
//   • positioning — how stable the character's registration is across frames
//   • visual      — how consistent the art (color/shape) stays frame-to-frame
//   • accuracy    — whether the frames actually depict motion for the action
// When a local vision model is available, its grades are blended in.

import { llmCheckRow } from './llm.js';

function frameData(canvas) {
  const ctx = canvas.getContext('2d');
  return ctx.getImageData(0, 0, canvas.width, canvas.height).data;
}

// alpha-weighted centroid + opaque pixel count
function centroid(data, w, h) {
  let sx = 0, sy = 0, n = 0;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const a = data[(y * w + x) * 4 + 3];
      if (a > 24) {
        sx += x;
        sy += y;
        n++;
      }
    }
  }
  return n ? { cx: sx / n, cy: sy / n, n } : { cx: w / 2, cy: h / 2, n: 0 };
}

function std(values) {
  if (values.length < 2) return 0;
  const m = values.reduce((a, b) => a + b, 0) / values.length;
  const v = values.reduce((a, b) => a + (b - m) * (b - m), 0) / values.length;
  return Math.sqrt(v);
}

function clamp(n, lo = 0, hi = 100) {
  return Math.max(lo, Math.min(hi, n));
}

// mean per-pixel color difference between two frames over their opaque union.
// This is "motion energy" — how much the picture changes frame to frame.
function frameDiff(a, b, w, h) {
  let sum = 0, n = 0;
  for (let i = 0; i < w * h; i++) {
    const j = i * 4;
    if (a[j + 3] > 24 || b[j + 3] > 24) {
      sum += Math.abs(a[j] - b[j]) + Math.abs(a[j + 1] - b[j + 1]) + Math.abs(a[j + 2] - b[j + 2]);
      n++;
    }
  }
  return n ? sum / (n * 3) : 0;
}

// average color of a frame's opaque pixels — a proxy for its palette/style
function avgColor(data, w, h) {
  let r = 0, g = 0, b = 0, n = 0;
  for (let i = 0; i < w * h; i++) {
    const j = i * 4;
    if (data[j + 3] > 24) {
      r += data[j];
      g += data[j + 1];
      b += data[j + 2];
      n++;
    }
  }
  return n ? [r / n, g / n, b / n] : [0, 0, 0];
}

/** Compute pixel-based scores for a row of frame canvases. */
export function computeScores(frames) {
  const w = frames[0].width;
  const h = frames[0].height;
  const datas = frames.map(frameData);
  const cents = datas.map((d) => centroid(d, w, h));

  // POSITIONING: the character should stay registered — mostly a horizontal
  // drift check (vertical motion like a jump is intentional, not a defect).
  const driftX = std(cents.map((c) => c.cx)) / w;
  const driftY = std(cents.map((c) => c.cy)) / h;
  const positioning = clamp(100 - driftX * 320 - driftY * 90);

  // VISUAL: art style consistency = how stable the palette stays. Same sprite
  // being transformed keeps a near-constant average color, so motion doesn't
  // wrongly count against it.
  const colors = datas.map((d) => avgColor(d, w, h));
  const cR = std(colors.map((c) => c[0]));
  const cG = std(colors.map((c) => c[1]));
  const cB = std(colors.map((c) => c[2]));
  const paletteDrift = (cR + cG + cB) / 3;
  const visual = clamp(100 - paletteDrift * 2.4);

  // ACCURACY: the row must actually *depict motion*. Reward frame-to-frame
  // change; a static (no-motion) row reads as not depicting the action.
  let diffSum = 0;
  for (let i = 1; i < datas.length; i++) diffSum += frameDiff(datas[i - 1], datas[i], w, h);
  const motion = datas.length > 1 ? diffSum / (datas.length - 1) : 0;
  const accuracy = frames.length <= 1 ? 70 : clamp(52 + motion * 3.4);

  return {
    positioning: Math.round(positioning),
    visual: Math.round(visual),
    accuracy: Math.round(accuracy),
  };
}

// evenly sample up to `max` frames for the vision model
function sampleFrames(frames, max = 8) {
  if (frames.length <= max) return frames;
  const out = [];
  for (let i = 0; i < max; i++) out.push(frames[Math.round((i * (frames.length - 1)) / (max - 1))]);
  return out;
}

// Compose sampled frames into ONE horizontal contact-sheet PNG. Sending a
// single image (instead of many) keeps us within small vision models' context
// windows while still showing the whole animation.
function contactSheet(frames) {
  const sample = sampleFrames(frames);
  const w = sample[0].width;
  const h = sample[0].height;
  const gap = 2;
  const c = document.createElement('canvas');
  c.width = sample.length * w + (sample.length - 1) * gap;
  c.height = h;
  const ctx = c.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  ctx.fillStyle = '#20222e'; // neutral backdrop so transparent sprites are visible
  ctx.fillRect(0, 0, c.width, c.height);
  sample.forEach((f, i) => ctx.drawImage(f, i * (w + gap), 0));
  return c.toDataURL('image/png');
}

// Vision models are inconsistent about scale: some answer 0-100, some 0-1,
// some as strings. Coerce to a 0-100 number set; return null if unusable.
function normalizeGrades(g) {
  if (!g) return null;
  const nums = ['positioning', 'visual', 'accuracy'].map((k) => Number(g[k]));
  if (nums.some((n) => !isFinite(n))) return null;
  // if every score is <= 1, the model used a 0-1 fraction scale
  const scale = nums.every((n) => n <= 1) ? 100 : 1;
  return {
    positioning: clamp(nums[0] * scale),
    visual: clamp(nums[1] * scale),
    accuracy: clamp(nums[2] * scale),
    notes: g.notes,
  };
}

/**
 * Run checks for one action. Returns { positioning, visual, accuracy, overall,
 * passed, notes, usedLLM }.
 */
export async function runChecks(frames, action, llm) {
  const computed = computeScores(frames);
  let final = { ...computed };
  let notes = '';
  let usedLLM = false;

  if (llm?.available && llm.model) {
    const imgs = [contactSheet(frames)]; // one contact-sheet image
    const graded = normalizeGrades(await llmCheckRow(llm.model, action, frames.length, imgs));
    if (graded) {
      // computed pixel metrics lead; the vision model is a lighter verification
      // nudge (small local models grade erratically, so don't let them dominate)
      const mix = (c, g) => Math.round(c * 0.7 + g * 0.3);
      final = {
        positioning: mix(computed.positioning, graded.positioning),
        visual: mix(computed.visual, graded.visual),
        accuracy: mix(computed.accuracy, graded.accuracy),
      };
      notes = (graded.notes || '').toString().slice(0, 140);
      usedLLM = true;
    }
  }

  const overall = Math.round((final.positioning + final.visual + final.accuracy) / 3);
  return { ...final, overall, passed: overall >= 70, notes, usedLLM };
}
