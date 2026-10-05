// poses.js — procedural OpenPose skeletons per action, for ControlNet.
//
// SD can't invent coherent animation from a prompt, so we drive each frame with
// a target POSE. This module builds an 18-keypoint (COCO) skeleton for each
// action/frame via simple forward kinematics, then renders it in the standard
// OpenPose style (colored bones + joints on black) that ControlNet-openpose
// expects. SD then generates the character INTO that pose.

import { presetKeyFor } from './generator.js';

const D2R = Math.PI / 180;
// step from a point at an angle (deg; 0 = +x/right, 90 = +y/down) and length
const step = (b, a, len) => ({ x: b.x + Math.cos(a * D2R) * len, y: b.y + Math.sin(a * D2R) * len });

// normalized segment lengths (relative to frame height)
const L = { torso: 0.24, head: 0.10, uarm: 0.115, farm: 0.115, thigh: 0.185, shin: 0.185 };

// COCO-18 keypoint order + the canonical OpenPose limb pairs and colors.
// idx: 0 nose,1 neck,2 Rsho,3 Relb,4 Rwri,5 Lsho,6 Lelb,7 Lwri,8 Rhip,9 Rknee,
//      10 Rank,11 Lhip,12 Lknee,13 Lank,14 Reye,15 Leye,16 Rear,17 Lear
const LIMBS = [
  [1, 2], [1, 5], [2, 3], [3, 4], [5, 6], [6, 7], [1, 8], [8, 9], [9, 10],
  [1, 11], [11, 12], [12, 13], [1, 0], [0, 14], [14, 16], [0, 15], [15, 17],
];
const COLORS = [
  [255, 0, 0], [255, 85, 0], [255, 170, 0], [255, 255, 0], [170, 255, 0], [85, 255, 0],
  [0, 255, 0], [0, 255, 85], [0, 255, 170], [0, 255, 255], [0, 170, 255], [0, 85, 255],
  [0, 0, 255], [85, 0, 255], [170, 0, 255], [255, 0, 255], [255, 0, 170], [255, 0, 85],
];

// assemble the 18 keypoints from a rig spec
function assemble(spec) {
  const {
    pelvis, lean = 0, headTilt = 0, narrow = 1, face = 0,
    rua, rfa, lua, lfa, rth, rsh, lth, lsh,
  } = spec;
  const shW = 0.085 * narrow;
  const hipW = 0.05 * narrow;
  const neck = step(pelvis, -90 + lean, L.torso);
  const nose = step(neck, -90 + headTilt, L.head);
  const rsho = { x: neck.x - shW, y: neck.y + 0.015 };
  const lsho = { x: neck.x + shW, y: neck.y + 0.015 };
  const rhip = { x: pelvis.x - hipW, y: pelvis.y };
  const lhip = { x: pelvis.x + hipW, y: pelvis.y };
  const relb = step(rsho, rua, L.uarm), rwri = step(relb, rfa, L.farm);
  const lelb = step(lsho, lua, L.uarm), lwri = step(lelb, lfa, L.farm);
  const rkne = step(rhip, rth, L.thigh), rank = step(rkne, rsh, L.shin);
  const lkne = step(lhip, lth, L.thigh), lank = step(lkne, lsh, L.shin);
  // face features nudged toward the facing direction
  const fx = face * 0.02;
  const reye = { x: nose.x + fx - 0.015, y: nose.y - 0.006 };
  const leye = { x: nose.x + fx + 0.015, y: nose.y - 0.006 };
  const rear = { x: nose.x + fx - 0.032, y: nose.y };
  const lear = { x: nose.x + fx + 0.032, y: nose.y };
  return [nose, neck, rsho, relb, rwri, lsho, lelb, lwri, rhip, rkne, rank, lhip, lkne, lank, reye, leye, rear, lear];
}

const TAU = Math.PI * 2;
const ONE_SHOT = new Set(['jump', 'fall', 'swing', 'punch', 'death']);
const phaseOf = (key, i, total) => (total <= 1 ? 0 : ONE_SHOT.has(key) ? i / (total - 1) : i / total);

// --- per-action rigs -------------------------------------------------------

function idleRig(p) {
  const breath = Math.sin(p * TAU);
  return assemble({
    pelvis: { x: 0.5, y: 0.55 - breath * 0.004 },
    rua: 96, rfa: 94, lua: 84, lfa: 86,
    rth: 93, rsh: 91, lth: 87, lsh: 89,
  });
}

function walkRig(p, ampl = 1) {
  const s = Math.sin(p * TAU);
  const A = 48 * ampl; // stride amplitude (deg) — larger = clearer walk
  const bob = Math.abs(Math.sin(p * TAU)) * 0.025;
  const kneeBend = (leadSin) => 8 + 48 * (0.5 - 0.5 * leadSin); // bend the trailing leg
  const rth = 90 - A * s, lth = 90 + A * s;
  return assemble({
    pelvis: { x: 0.5, y: 0.55 - bob },
    lean: 12, headTilt: 40, narrow: 0.4, face: 1,
    // arms counter-swing the legs, elbows bent
    rua: 98 + 40 * s, rfa: 98 + 40 * s + 22,
    lua: 82 - 40 * s, lfa: 82 - 40 * s - 22,
    rth, rsh: rth + kneeBend(s),
    lth, lsh: lth + kneeBend(-s),
  });
}

function swingRig(p) {
  // right arm draws the sword up-and-back, then slashes down-forward
  let rua, rfa;
  if (p < 0.35) {
    const t = p / 0.35;
    rua = 90 - 205 * t; // 90 (down) -> -115 (up/back)
    rfa = rua - 18;
  } else {
    const a = (p - 0.35) / 0.65;
    rua = -115 + 170 * a; // -> ~55 (down-forward)
    rfa = rua + 12;
  }
  return assemble({
    pelvis: { x: 0.5, y: 0.55 }, lean: 8 + p * 6, headTilt: 30, narrow: 0.62, face: 1,
    rua, rfa,
    lua: 60, lfa: 100, // left arm braces across the body
    rth: 104, rsh: 96, // back foot
    lth: 78, lsh: 96, // front foot planted
  });
}

function jumpRig(p) {
  let py, th, sh, arm;
  if (p < 0.3) {
    const c = p / 0.3; // crouch
    py = 0.55 + 0.09 * c;
    th = 90 + 34 * c;
    sh = 90 - 30 * c;
    arm = 100 + 25 * c; // arms drawn back/down
  } else if (p < 0.62) {
    const e = (p - 0.3) / 0.32; // explosive extend
    py = 0.64 - 0.2 * e;
    th = 124 - 40 * e;
    sh = 60 + 32 * e;
    arm = 125 - 205 * e; // swing arms up overhead
  } else {
    const a = (p - 0.62) / 0.38; // airborne, slight tuck
    py = 0.44 - 0.05 * a;
    th = 84 + 20 * a;
    sh = 92 - 10 * a;
    arm = -80;
  }
  return assemble({
    pelvis: { x: 0.5, y: py }, narrow: 0.7,
    rua: arm, rfa: arm, lua: arm, lfa: arm,
    rth: th, rsh: sh, lth: th, lsh: sh,
  });
}

// map an action to a keypoint set for frame i of total
export function poseKeypoints(action, i, total) {
  const key = presetKeyFor(action);
  const p = phaseOf(key, i, total);
  if (key === 'walk') return walkRig(p, 1);
  if (key === 'run') return walkRig(p, 1.5);
  if (key === 'swing' || key === 'punch') return swingRig(p);
  if (key === 'jump' || key === 'fall') return jumpRig(p);
  return idleRig(p); // idle, crouch, cast, spin, hurt, death, wave, default
}

// render the skeleton in OpenPose style onto a black canvas
export function renderPose(action, i, total, w, h) {
  const kps = poseKeypoints(action, i, total);
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const ctx = c.getContext('2d');
  ctx.fillStyle = '#000';
  ctx.fillRect(0, 0, w, h);
  const P = (k) => (k ? { x: k.x * w, y: k.y * h } : null);
  const stick = Math.max(2, Math.round(w * 0.02));

  // bones as rotated filled ellipses (OpenPose style)
  LIMBS.forEach(([a, b], li) => {
    const p1 = P(kps[a]), p2 = P(kps[b]);
    if (!p1 || !p2) return;
    const mx = (p1.x + p2.x) / 2, my = (p1.y + p2.y) / 2;
    const len = Math.hypot(p2.x - p1.x, p2.y - p1.y);
    const ang = Math.atan2(p2.y - p1.y, p2.x - p1.x);
    const [r, g, bl] = COLORS[li % COLORS.length];
    ctx.save();
    ctx.translate(mx, my);
    ctx.rotate(ang);
    ctx.fillStyle = `rgb(${r},${g},${bl})`;
    ctx.beginPath();
    ctx.ellipse(0, 0, len / 2, stick / 2, 0, 0, TAU);
    ctx.fill();
    ctx.restore();
  });
  // joints as filled circles
  kps.forEach((k, idx) => {
    const p = P(k);
    if (!p) return;
    const [r, g, bl] = COLORS[idx % COLORS.length];
    ctx.fillStyle = `rgb(${r},${g},${bl})`;
    ctx.beginPath();
    ctx.arc(p.x, p.y, stick * 0.7, 0, TAU);
    ctx.fill();
  });
  return c;
}
