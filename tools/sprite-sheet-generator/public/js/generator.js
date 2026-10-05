// generator.js — on-device procedural sprite frame synthesis.
//
// Given one source image and an action name + frame count, we synthesize a row
// of animation frames by applying an action-specific motion model (bob, sway,
// squash/stretch, rotation sweeps, arcs, glows...) to the source sprite on a
// <canvas>. Runs entirely in the browser — no network, no paid APIs.

const TAU = Math.PI * 2;

// Map a free-text action name to a motion preset key via fuzzy keyword match.
function presetKeyFor(name) {
  const n = (name || '').toLowerCase();
  const has = (...k) => k.some((w) => n.includes(w));
  if (has('idle', 'stand', 'breath', 'wait')) return 'idle';
  if (has('run', 'sprint', 'dash')) return 'run';
  if (has('walk', 'move', 'step')) return 'walk';
  if (has('jump', 'leap', 'hop')) return 'jump';
  if (has('fall', 'drop')) return 'fall';
  if (has('sword', 'swing', 'slash', 'attack', 'melee', 'strike', 'chop')) return 'swing';
  if (has('punch', 'jab', 'thrust')) return 'punch';
  if (has('cast', 'magic', 'spell', 'charge')) return 'cast';
  if (has('spin', 'roll', 'flip')) return 'spin';
  if (has('crouch', 'duck', 'sneak')) return 'crouch';
  if (has('hurt', 'hit', 'damage', 'ow')) return 'hurt';
  if (has('die', 'death', 'defeat', 'ko')) return 'death';
  if (has('wave', 'cheer', 'taunt', 'celebrate')) return 'wave';
  return 'default';
}

// Each preset returns per-frame transform params for phase p in [0,1).
// { ox, oy, rot, sx, sy, skx, anchor, alpha, overlay }
const PRESETS = {
  idle: (p) => ({ oy: Math.sin(p * TAU) * 1.5, sy: 1 + Math.sin(p * TAU) * 0.02, anchor: 'feet' }),
  crouch: (p) => ({ sy: 1 - 0.18 * (0.5 - 0.5 * Math.cos(p * TAU)), anchor: 'feet' }),
  walk: (p) => ({
    ox: Math.sin(p * TAU) * 2,
    oy: -Math.abs(Math.sin(p * TAU * 2)) * 2.5,
    rot: Math.sin(p * TAU) * 0.03,
    skx: Math.sin(p * TAU) * 0.05,
    anchor: 'feet',
  }),
  run: (p) => ({
    ox: Math.sin(p * TAU) * 3,
    oy: -Math.abs(Math.sin(p * TAU * 2)) * 5,
    rot: 0.12 + Math.sin(p * TAU) * 0.04,
    skx: -0.08 + Math.sin(p * TAU) * 0.06,
    anchor: 'feet',
  }),
  jump: (p) => {
    // one-shot arc: crouch -> launch -> apex -> land
    const arc = -Math.sin(p * Math.PI) * 26;
    const squash = p < 0.12 || p > 0.9 ? 0.85 : 1.06;
    return { oy: arc, sx: 2 - squash, sy: squash, anchor: 'feet' };
  },
  fall: (p) => ({ oy: p * 10, rot: p * 0.15, sy: 1 + p * 0.06, anchor: 'feet' }),
  swing: (p) => {
    // wind-up then sweep the whole sprite through an arc
    const eased = p < 0.3 ? -0.25 * (p / 0.3) : 0.9 * ((p - 0.3) / 0.7) - 0.25;
    return {
      rot: eased * 0.5,
      ox: eased * 6,
      anchor: 'center',
      overlay: (ctx, w, h) => {
        if (p < 0.3) return;
        const a = (p - 0.3) / 0.7;
        ctx.save();
        ctx.globalAlpha = 0.55 * (1 - Math.abs(a - 0.5) * 1.4);
        ctx.strokeStyle = '#dbeafe';
        ctx.lineWidth = Math.max(1.5, w * 0.03);
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.5, w * 0.42, -Math.PI * 0.55, -Math.PI * 0.55 + a * Math.PI * 1.1);
        ctx.stroke();
        ctx.restore();
      },
    };
  },
  punch: (p) => {
    const thrust = Math.sin(p * Math.PI);
    return { ox: thrust * 7, skx: -thrust * 0.06, anchor: 'center' };
  },
  cast: (p) => ({
    oy: Math.sin(p * TAU) * 1.2,
    sy: 1 + Math.sin(p * TAU) * 0.03,
    anchor: 'feet',
    overlay: (ctx, w, h) => {
      const g = ctx.createRadialGradient(w / 2, h / 2, 2, w / 2, h / 2, w * 0.5);
      const pulse = 0.15 + 0.2 * (0.5 + 0.5 * Math.sin(p * TAU));
      g.addColorStop(0, `rgba(139,92,246,${pulse})`);
      g.addColorStop(1, 'rgba(139,92,246,0)');
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, w, h);
      ctx.restore();
    },
  }),
  spin: (p) => ({ rot: p * TAU, anchor: 'center' }),
  hurt: (p) => {
    const shake = Math.sin(p * TAU * 3) * 3 * (1 - p);
    return {
      ox: shake,
      rot: shake * 0.02,
      anchor: 'center',
      overlay: (ctx, w, h) => {
        ctx.save();
        ctx.globalCompositeOperation = 'source-atop';
        ctx.fillStyle = `rgba(239,68,68,${0.5 * (1 - p)})`;
        ctx.fillRect(0, 0, w, h);
        ctx.restore();
      },
    };
  },
  death: (p) => ({ rot: p * (Math.PI / 2), oy: p * 8, alpha: 1 - p * 0.55, anchor: 'feet' }),
  wave: (p) => ({ rot: Math.sin(p * TAU * 2) * 0.06, oy: Math.sin(p * TAU) * 1.5, anchor: 'feet' }),
  default: (p) => ({ oy: Math.sin(p * TAU) * 2, sy: 1 + Math.sin(p * TAU) * 0.02, anchor: 'feet' }),
};

// One-shot actions play start->end; looping actions wrap seamlessly.
const ONE_SHOT = new Set(['jump', 'fall', 'swing', 'punch', 'death']);

function phaseFor(preset, i, total) {
  if (total <= 1) return 0;
  return ONE_SHOT.has(preset) ? i / (total - 1) : i / total;
}

/**
 * Render a single frame canvas for an action.
 * @param {HTMLCanvasElement|ImageBitmap} src source (already sized W×H)
 * @param {number} w frame width
 * @param {number} h frame height
 * @param {string} actionName
 * @param {number} i frame index
 * @param {number} total total frames
 */
export function renderFrame(src, w, h, actionName, i, total) {
  const key = presetKeyFor(actionName);
  const p = phaseFor(key, i, total);
  const t = PRESETS[key](p) || {};
  const { ox = 0, oy = 0, rot = 0, sx = 1, sy = 1, skx = 0, anchor = 'center', alpha = 1, overlay } = t;

  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const ctx = c.getContext('2d');
  ctx.imageSmoothingEnabled = false;

  ctx.save();
  ctx.globalAlpha = alpha;
  if (anchor === 'feet') {
    // pivot at bottom-center so squash/stretch keeps the feet planted
    ctx.translate(w / 2 + ox, h + oy);
    ctx.rotate(rot);
    ctx.transform(sx, 0, skx, sy, 0, 0);
    ctx.drawImage(src, -w / 2, -h);
  } else {
    ctx.translate(w / 2 + ox, h / 2 + oy);
    ctx.rotate(rot);
    ctx.transform(sx, 0, skx, sy, 0, 0);
    ctx.drawImage(src, -w / 2, -h / 2);
  }
  ctx.restore();

  if (overlay) overlay(ctx, w, h, p);
  return c;
}

/** Render every frame of an action row. Returns array of canvases. */
export function renderAction(src, w, h, actionName, total) {
  const frames = [];
  for (let i = 0; i < total; i++) frames.push(renderFrame(src, w, h, actionName, i, total));
  return frames;
}

export { presetKeyFor };
