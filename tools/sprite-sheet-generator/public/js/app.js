// app.js — application state + orchestration.

import { renderFrame, renderAction, presetKeyFor } from './generator.js';
import { removeBackground } from './bgremove.js';
import { runChecks } from './checks.js';
import { PreviewPlayer, clearPlayers, setFps } from './preview.js';
import { llmStatus } from './llm.js';
import { diffusionStatus, diffusionFrame } from './diffusion.js';

// Very large sources are scaled down to this longest-edge (in px) so frames
// stay a sensible sprite size — big frames overflow the preview and bloat the
// sheet. Frame dimensions then equal these scaled-down working dimensions.
const MAX_FRAME_DIM = 128;

// ---------- state ----------
const state = {
  source: null, // { raw, processed, w, h, name, originalW, originalH, scaled }
  actions: [
    { id: uid(), name: 'Idle', frames: 4 },
    { id: uid(), name: 'Walk', frames: 6 },
    { id: uid(), name: 'Sword Swing', frames: 8 },
    { id: uid(), name: 'Jump', frames: 5 },
  ],
  transparent: true,
  bgColor: '#1e2030',
  removeBg: false,
  fps: 8,
  engine: 'diffusion', // 'diffusion' (default, local SD) | 'transform' (on-device)
  cooldownMs: 12000, // rest between diffusion frames so the GPU/laptop stays cool
  diffusion: { available: false },
  llm: { available: false, model: null },
  rows: null, // [{ action, frames }]
};

function uid() {
  return 'a' + Math.floor(performance.now() * 1000).toString(36) + Math.floor(performance.now() % 1000);
}

// ---------- DOM refs ----------
const $ = (id) => document.getElementById(id);
const els = {
  dropzone: $('dropzone'), fileInput: $('fileInput'),
  dzEmpty: $('dropzoneEmpty'), dzFilled: $('dropzoneFilled'),
  srcImg: $('srcImg'), srcName: $('srcName'), srcDims: $('srcDims'),
  actionsBody: $('actionsBody'), actionCount: $('actionCount'),
  addForm: $('addActionForm'), newName: $('newActionName'), newFrames: $('newActionFrames'),
  transparentToggle: $('transparentToggle'), transparentState: $('transparentState'),
  bgColorRow: $('bgColorRow'), bgColor: $('bgColor'),
  removeBgToggle: $('removeBgToggle'), removeBgState: $('removeBgState'),
  fpsRange: $('fpsRange'), fpsVal: $('fpsVal'),
  cooldownRange: $('cooldownRange'), cooldownVal: $('cooldownVal'),
  frameSizeText: $('frameSizeText'), frameSizeChip: $('frameSizeChip'), sheetFramesChip: $('sheetFramesChip'),
  generateBtn: $('generateBtn'), downloadBtn: $('downloadBtn'),
  previewEmpty: $('previewEmpty'), previewGrid: $('previewGrid'),
  playersCol: $('playersCol'), rowsCol: $('rowsCol'),
  checksBody: $('checksBody'), checksSummary: $('checksSummary'),
  summaryTitle: $('summaryTitle'), summarySub: $('summarySub'),
  fullSheet: $('fullSheet'), fullSheetToggle: $('fullSheetToggle'), fullSheetChevron: $('fullSheetChevron'),
  fullSheetBody: $('fullSheetBody'), fullSheetCanvas: $('fullSheetCanvas'),
  globalProgress: $('globalProgress'), progressFill: $('progressFill'), progressPct: $('progressPct'), progressLabel: $('progressLabel'),
  llmDot: $('llmDot'), llmStatusText: $('llmStatusText'),
  engineSelect: $('engineSelect'), engineHint: $('engineHint'),
  themeToggle: $('themeToggle'), docsBtn: $('docsBtn'), githubBtn: $('githubBtn'),
};

// ---------- helpers ----------
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const nextFrame = () => new Promise((r) => requestAnimationFrame(() => r()));

function displayScale(h) {
  return Math.max(1, Math.min(4, Math.round(88 / h) || 1));
}

function scaledCanvas(frame, scale) {
  const c = document.createElement('canvas');
  c.width = frame.width * scale;
  c.height = frame.height * scale;
  const ctx = c.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(frame, 0, 0, c.width, c.height);
  return c;
}

// ---------- source image ----------
function processSource() {
  if (!state.source) return;
  const { raw } = state.source;
  const processed = state.removeBg ? removeBackground(raw) : raw;
  state.source.processed = processed;
  els.srcImg.src = processed.toDataURL('image/png');
}

async function loadFile(file) {
  if (!file || !file.type.startsWith('image/')) return;
  const url = URL.createObjectURL(file);
  const img = new Image();
  await new Promise((res, rej) => {
    img.onload = res;
    img.onerror = rej;
    img.src = url;
  });
  const ow = img.naturalWidth;
  const oh = img.naturalHeight;

  // scale very large sources down to a sensible sprite-frame size
  const factor = Math.min(1, MAX_FRAME_DIM / Math.max(ow, oh));
  const w = Math.max(1, Math.round(ow * factor));
  const h = Math.max(1, Math.round(oh * factor));

  const raw = document.createElement('canvas');
  raw.width = w;
  raw.height = h;
  const ctx = raw.getContext('2d');
  ctx.imageSmoothingEnabled = factor < 1; // smooth only when downscaling
  ctx.drawImage(img, 0, 0, w, h);

  // keep a higher-detail copy (capped ~512 long edge) for diffusion to use as an
  // identity reference — the tiny frame-size source loses too much of the character
  const refFactor = Math.min(1, 512 / Math.max(ow, oh));
  const full = document.createElement('canvas');
  full.width = Math.max(1, Math.round(ow * refFactor));
  full.height = Math.max(1, Math.round(oh * refFactor));
  const fctx = full.getContext('2d');
  fctx.imageSmoothingEnabled = refFactor < 1;
  fctx.drawImage(img, 0, 0, full.width, full.height);
  URL.revokeObjectURL(url);

  state.source = { raw, processed: raw, full, w, h, name: file.name, originalW: ow, originalH: oh, scaled: factor < 1 };
  processSource();

  els.dzEmpty.hidden = true;
  els.dzFilled.hidden = false;
  els.srcName.textContent = file.name;
  updateSourceUI();
  updateGenerateEnabled();
}

// reflect source (and scaling) in the source card, frame-size note, and chip
function updateSourceUI() {
  const s = state.source;
  if (!s) return;
  const frameDims = `${s.w} × ${s.h} px`;
  els.srcDims.textContent = s.scaled ? `${s.originalW} × ${s.originalH} px → ${frameDims}` : frameDims;
  els.frameSizeText.textContent = s.scaled ? `${frameDims} (scaled down from ${s.originalW} × ${s.originalH})` : frameDims;
  els.frameSizeChip.textContent = `Frame size: ${frameDims}`;
}

// ---------- actions table ----------
function renderActions() {
  els.actionsBody.innerHTML = '';
  state.actions.forEach((a, idx) => {
    const row = document.createElement('div');
    row.className = 'action-row';
    row.draggable = true;
    row.dataset.id = a.id;
    row.innerHTML = `
      <span class="c-handle" title="Drag to reorder">⋮⋮</span>
      <span class="c-num">${idx + 1}</span>
      <span class="c-name"><input type="text" value="${escapeAttr(a.name)}" aria-label="Action name" /></span>
      <span class="c-frames"><input type="number" min="1" max="24" value="${a.frames}" aria-label="Frame count" /></span>
      <span class="c-del"><button class="del-btn" title="Remove" aria-label="Remove action">🗑</button></span>`;
    const [nameIn, framesIn] = row.querySelectorAll('input');
    nameIn.addEventListener('input', () => { a.name = nameIn.value; });
    framesIn.addEventListener('input', () => { a.frames = clampInt(framesIn.value, 1, 24); });
    framesIn.addEventListener('blur', () => { framesIn.value = a.frames; });
    row.querySelector('.del-btn').addEventListener('click', () => {
      state.actions = state.actions.filter((x) => x.id !== a.id);
      renderActions();
      updateGenerateEnabled();
    });
    attachDrag(row, a.id);
    els.actionsBody.appendChild(row);
  });
  els.actionCount.textContent = `${state.actions.length} action${state.actions.length === 1 ? '' : 's'}`;
}

let dragId = null;
function attachDrag(row, id) {
  row.addEventListener('dragstart', () => { dragId = id; row.classList.add('dragging'); });
  row.addEventListener('dragend', () => { dragId = null; row.classList.remove('dragging'); document.querySelectorAll('.action-row').forEach((r) => r.classList.remove('drag-over')); });
  row.addEventListener('dragover', (e) => { e.preventDefault(); row.classList.add('drag-over'); });
  row.addEventListener('dragleave', () => row.classList.remove('drag-over'));
  row.addEventListener('drop', (e) => {
    e.preventDefault();
    row.classList.remove('drag-over');
    if (dragId == null || dragId === id) return;
    const from = state.actions.findIndex((a) => a.id === dragId);
    const to = state.actions.findIndex((a) => a.id === id);
    const [moved] = state.actions.splice(from, 1);
    state.actions.splice(to, 0, moved);
    renderActions();
  });
}

function escapeAttr(s) {
  return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
}
function clampInt(v, lo, hi) {
  const n = parseInt(v, 10);
  if (isNaN(n)) return lo;
  return Math.max(lo, Math.min(hi, n));
}

// ---------- generate enablement ----------
function updateGenerateEnabled() {
  const ok = state.source && state.actions.length > 0;
  els.generateBtn.disabled = !ok;
  const total = state.actions.reduce((s, a) => s + a.frames, 0);
  els.sheetFramesChip.textContent = `Sheet: ${total} frame${total === 1 ? '' : 's'}`;
}

// ---------- generation flow ----------
let generating = false;
async function generate() {
  if (generating || !state.source) return;
  generating = true;
  els.generateBtn.disabled = true;
  els.downloadBtn.disabled = true;
  els.previewEmpty.hidden = true;
  els.previewGrid.hidden = false;
  els.playersCol.innerHTML = '';
  els.rowsCol.innerHTML = '';
  els.checksBody.innerHTML = '';
  els.checksSummary.hidden = true;
  els.fullSheet.hidden = true;
  clearPlayers();

  const { w, h } = state.source;
  const scale = displayScale(h);
  const totalFrames = state.actions.reduce((s, a) => s + a.frames, 0);
  let done = 0;
  showProgress(true);

  // decide the active engine for this run (fall back if diffusion is offline)
  const useDiffusion = state.engine === 'diffusion' && state.diffusion.available;
  const engineLabel = useDiffusion ? 'diffusion' : 'transform';
  if (state.engine === 'diffusion' && !state.diffusion.available) {
    setEngineHint('Diffusion backend offline — generating with motion transform.', 'off');
  }

  state.rows = [];
  const checkResults = [];

  for (let ai = 0; ai < state.actions.length; ai++) {
    const action = state.actions[ai];
    setProgress(done / totalFrames, `Generating “${action.name}” — 0/${action.frames}`);

    const rowEl = buildSheetRow(ai, action, action.frames);
    const rowFrames = [];

    for (let i = 0; i < action.frames; i++) {
      const frame = await generateFrame(action, i, action.frames, useDiffusion);
      rowFrames.push(frame);
      revealSheetFrame(rowEl, frame, scale);
      done++;
      const lastFrameOverall = ai === state.actions.length - 1 && i === action.frames - 1;
      setProgress(done / totalFrames, `Generating “${action.name}” — ${i + 1}/${action.frames} (${engineLabel})`);
      await nextFrame();
      if (!useDiffusion) {
        await wait(45); // pacing for the fast on-device engine
      } else if (state.cooldownMs > 0 && !lastFrameOverall) {
        // let the GPU rest between diffusion frames so the machine stays cool
        setProgress(done / totalFrames, `Cooling down ${Math.round(state.cooldownMs / 1000)}s (gentle mode)…`);
        await wait(state.cooldownMs);
      }
    }

    state.rows.push({ action, frames: rowFrames });
    buildPlayerCard(ai, action, rowFrames);

    // per-spec: run the quality check as soon as the action is complete
    const pendingCard = buildCheckCard(ai, action, 'running');
    setProgress(done / totalFrames, `Checking “${action.name}”…`);
    const result = await runChecks(rowFrames, action.name, state.llm);
    checkResults.push(result);
    fillCheckCard(pendingCard, ai, action, result);
    await nextFrame();
  }

  renderSummary(checkResults);
  composeFullSheet();
  els.downloadBtn.disabled = false;
  els.fullSheet.hidden = false;
  showProgress(false);
  els.generateBtn.disabled = false;
  generating = false;
}

// Produce one frame. With diffusion on, SD generates the source character INTO
// the action's pose via ControlNet OpenPose (see diffusion.js + poses.js), with a
// fixed seed for consistency. The 'transform' engine (and any diffusion failure)
// uses the on-device motion transform so a sheet is always produced.
let diffusionFellBack = false;
async function generateFrame(action, i, total, useDiffusion) {
  const { processed, w, h } = state.source;
  if (useDiffusion) {
    try {
      return await diffusionFrame(processed, w, h, action.name, i, total, {
        transparent: state.transparent,
        bgColor: state.bgColor,
        reference: state.source.full, // higher-detail identity reference
        seed: 42, // constant across the whole sheet for character consistency
      });
    } catch (e) {
      if (!diffusionFellBack) {
        diffusionFellBack = true;
        setEngineHint('A diffusion frame failed — falling back to motion transform.', 'off');
      }
    }
  }
  return renderFrame(processed, w, h, action.name, i, total);
}

// ---------- preview + sheet DOM ----------
function buildPlayerCard(idx, action, frames) {
  const card = document.createElement('div');
  card.className = 'player';
  card.innerHTML = `
    <div class="player-stage"><canvas></canvas></div>
    <div class="player-caption">${escapeHtml(action.name)} <span>(Preview)</span></div>
    <div class="player-controls">
      <button class="p-play" title="Play/pause">⏸</button>
      <input class="player-scrub" type="range" min="0" value="0" />
    </div>`;
  els.playersCol.appendChild(card);
  const canvas = card.querySelector('canvas');
  const scrub = card.querySelector('.player-scrub');
  const play = card.querySelector('.p-play');
  new PreviewPlayer(frames, canvas, scrub, play);
}

function buildSheetRow(idx, action, frameCount) {
  const wrap = document.createElement('div');
  wrap.className = 'sheet-row';
  const preset = presetKeyFor(action.name);
  wrap.innerHTML = `
    <p class="sheet-row-label">${idx + 1}. ${escapeHtml(action.name)} <span>— ${frameCount} frames · ${preset}</span></p>
    <div class="sheet-row-frames ${state.transparent ? '' : 'solid'}" style="--frame-bg:${state.bgColor}"></div>`;
  els.rowsCol.appendChild(wrap);
  return wrap.querySelector('.sheet-row-frames');
}

function revealSheetFrame(rowEl, frame, scale) {
  const cell = document.createElement('div');
  cell.className = 'sheet-frame';
  cell.appendChild(scaledCanvas(frame, scale));
  rowEl.appendChild(cell);
}

// ---------- checks DOM ----------
function buildCheckCard(idx, action, status) {
  const card = document.createElement('div');
  card.className = 'check-card pending';
  card.innerHTML = `
    <div class="check-card-head">
      <span class="check-card-title">${idx + 1}. ${escapeHtml(action.name)} <span>(${action.frames} frames)</span></span>
      <span class="badge running">Running…</span>
    </div>
    <div class="check-line"><span class="tick pending">◌</span> Positioning consistency</div>
    <div class="check-line"><span class="tick pending">◌</span> Visual consistency</div>
    <div class="check-line"><span class="tick pending">◌</span> Action accuracy</div>
    <div class="check-progress"><div class="check-progress-fill" style="width:0%"></div></div>
    <div class="check-pct">—</div>`;
  els.checksBody.appendChild(card);
  return card;
}

function fillCheckCard(card, idx, action, r) {
  card.classList.remove('pending');
  const badge = card.querySelector('.badge');
  badge.classList.remove('running');
  if (r.passed) {
    badge.classList.add('pass');
    badge.textContent = '✓ Passed';
  } else {
    badge.classList.add('warn');
    badge.textContent = '⚠ Review';
  }
  const lines = card.querySelectorAll('.check-line');
  const setLine = (el, score, label) => {
    const tick = el.querySelector('.tick');
    const ok = score >= 70;
    tick.className = 'tick' + (ok ? '' : ' warn');
    tick.textContent = ok ? '✓' : '⚠';
    el.childNodes[el.childNodes.length - 1].textContent = ` ${label} — ${score}%`;
  };
  setLine(lines[0], r.positioning, 'Positioning consistency');
  setLine(lines[1], r.visual, 'Visual consistency');
  setLine(lines[2], r.accuracy, 'Action accuracy');
  card.querySelector('.check-progress-fill').style.width = `${r.overall}%`;
  card.querySelector('.check-pct').textContent = `${r.overall}%${r.usedLLM ? ' · verified by local LLM' : ''}`;
  if (r.notes) {
    const n = document.createElement('div');
    n.className = 'check-notes';
    n.textContent = '“' + r.notes + '”';
    card.appendChild(n);
  }
}

function renderSummary(results) {
  const allPass = results.length > 0 && results.every((r) => r.passed);
  els.checksSummary.hidden = false;
  els.checksSummary.classList.toggle('warn', !allPass);
  if (allPass) {
    els.summaryTitle.textContent = 'All checks passed';
    els.summarySub.textContent = 'Sprite sheet is ready to use!';
    els.checksSummary.querySelector('.summary-icon').textContent = '✔';
  } else {
    const n = results.filter((r) => !r.passed).length;
    els.summaryTitle.textContent = `${n} action${n === 1 ? '' : 's'} to review`;
    els.summarySub.textContent = 'Some rows scored below 70% — tweak and regenerate.';
    els.checksSummary.querySelector('.summary-icon').textContent = '!';
  }
}

// ---------- full sheet compositing / download ----------
function composeSheetCanvas() {
  if (!state.rows) return null;
  const { w, h } = state.source;
  const cols = Math.max(...state.rows.map((r) => r.frames.length));
  const canvas = document.createElement('canvas');
  canvas.width = cols * w;
  canvas.height = state.rows.length * h;
  const ctx = canvas.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  if (!state.transparent) {
    ctx.fillStyle = state.bgColor;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }
  state.rows.forEach((row, r) => {
    row.frames.forEach((frame, c) => ctx.drawImage(frame, c * w, r * h));
  });
  return canvas;
}

function composeFullSheet() {
  const sheet = composeSheetCanvas();
  if (!sheet) return;
  const { w, h } = state.source;
  const scale = Math.max(1, Math.min(4, Math.floor(720 / sheet.width) || 1));
  const disp = els.fullSheetCanvas;
  disp.width = sheet.width * scale;
  disp.height = sheet.height * scale;
  const ctx = disp.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(sheet, 0, 0, disp.width, disp.height);
}

function downloadSheet() {
  const sheet = composeSheetCanvas();
  if (!sheet) return;
  sheet.toBlob((blob) => {
    const localReader = new FileReader();
    localReader.onload = () => fetch('/__local/export', {
      method: 'POST', body: String(localReader.result).split(',')[1],
      headers: {'Content-Type': 'text/plain'}
    }).then(r => { if (!r.ok) throw new Error('Local save failed'); });
    localReader.readAsDataURL(blob);
    const a = document.createElement('a');
    const base = (state.source.name || 'sprite').replace(/\.[^.]+$/, '');
    a.href = URL.createObjectURL(blob);
    a.download = `${base}-spritesheet.png`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }, 'image/png');
}

// ---------- progress ----------
function showProgress(on) {
  els.globalProgress.hidden = !on;
}
function setProgress(frac, label) {
  const pct = Math.round(frac * 100);
  els.progressFill.style.width = `${pct}%`;
  els.progressPct.textContent = `${pct}%`;
  if (label) els.progressLabel.textContent = label;
}

// ---------- misc utils ----------
function escapeHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// ---------- event wiring ----------
function wireEvents() {
  // dropzone
  els.dropzone.addEventListener('click', () => els.fileInput.click());
  els.dropzone.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') els.fileInput.click(); });
  els.fileInput.addEventListener('change', (e) => loadFile(e.target.files[0]));
  ['dragenter', 'dragover'].forEach((ev) => els.dropzone.addEventListener(ev, (e) => { e.preventDefault(); els.dropzone.classList.add('drag'); }));
  ['dragleave', 'drop'].forEach((ev) => els.dropzone.addEventListener(ev, (e) => { e.preventDefault(); els.dropzone.classList.remove('drag'); }));
  els.dropzone.addEventListener('drop', (e) => loadFile(e.dataTransfer.files[0]));

  // add action
  els.addForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const name = els.newName.value.trim() || 'Action';
    const frames = clampInt(els.newFrames.value, 1, 24);
    state.actions.push({ id: uid(), name, frames });
    els.newName.value = '';
    els.newFrames.value = '4';
    renderActions();
    updateGenerateEnabled();
  });

  // output options
  els.transparentToggle.addEventListener('change', () => {
    state.transparent = els.transparentToggle.checked;
    els.transparentState.textContent = state.transparent ? 'ON' : 'OFF';
    els.bgColorRow.hidden = state.transparent;
    applyRowBackgrounds();
  });
  els.bgColor.addEventListener('input', () => { state.bgColor = els.bgColor.value; applyRowBackgrounds(); });
  els.removeBgToggle.addEventListener('change', () => {
    state.removeBg = els.removeBgToggle.checked;
    els.removeBgState.textContent = state.removeBg ? 'ON' : 'OFF';
    processSource();
  });
  els.fpsRange.addEventListener('input', () => {
    state.fps = Number(els.fpsRange.value);
    els.fpsVal.textContent = `${state.fps} fps`;
    setFps(state.fps);
  });
  els.cooldownRange.addEventListener('input', () => {
    state.cooldownMs = Number(els.cooldownRange.value) * 1000;
    els.cooldownVal.textContent = `${els.cooldownRange.value}s`;
  });
  els.engineSelect.addEventListener('change', () => {
    state.engine = els.engineSelect.value;
    diffusionFellBack = false;
    refreshEngineHint();
  });

  els.generateBtn.addEventListener('click', generate);
  els.downloadBtn.addEventListener('click', downloadSheet);

  // full sheet toggle
  els.fullSheetToggle.addEventListener('click', () => {
    const open = els.fullSheetBody.hidden;
    els.fullSheetBody.hidden = !open;
    els.fullSheetChevron.textContent = open ? '▾' : '▸';
  });

  // theme
  els.themeToggle.addEventListener('click', () => {
    const root = document.documentElement;
    const dark = root.getAttribute('data-theme') === 'dark';
    root.setAttribute('data-theme', dark ? 'light' : 'dark');
    els.themeToggle.textContent = dark ? '🌙' : '☀️';
  });
  els.docsBtn.addEventListener('click', () => window.open('https://github.com', '_blank'));
  els.githubBtn.addEventListener('click', () => window.open('https://github.com', '_blank'));
}

function applyRowBackgrounds() {
  document.querySelectorAll('.sheet-row-frames').forEach((el) => {
    el.classList.toggle('solid', !state.transparent);
    el.style.setProperty('--frame-bg', state.bgColor);
  });
  if (state.rows) composeFullSheet();
}

// ---------- LLM status ----------
async function initLlm() {
  const s = await llmStatus();
  state.llm = s;
  if (s.available) {
    els.llmDot.className = 'llm-dot on';
    els.llmStatusText.textContent = `Local LLM connected — quality checks verified by ${s.model} (Ollama, on-device).`;
  } else {
    els.llmDot.className = 'llm-dot off';
    els.llmStatusText.textContent = 'No local vision model detected — using on-device pixel metrics for checks. Run `ollama pull moondream` to enable LLM verification.';
  }
}

// ---------- engine (diffusion) status ----------
function setEngineHint(text, tone) {
  els.engineHint.textContent = text;
  els.engineHint.style.color = tone === 'on' ? 'var(--green-text)' : tone === 'off' ? '#d97706' : 'var(--muted)';
}

// hint reflects the current engine choice + whether local diffusion is up
function refreshEngineHint() {
  if (state.engine === 'transform') {
    setEngineHint('On-device motion transform — instant, fully offline.', 'muted');
  } else if (state.diffusion.available) {
    const m = state.diffusion.model ? ` (${String(state.diffusion.model).split(/[\\/]/).pop()})` : '';
    setEngineHint(`Local Stable Diffusion detected${m} — best quality.`, 'on');
  } else {
    setEngineHint('No local diffusion backend at :7860 — will fall back to motion transform. See README.', 'off');
  }
}

async function initDiffusion() {
  state.diffusion = await diffusionStatus();
  refreshEngineHint();
}

// ---------- boot ----------
function boot() {
  renderActions();
  updateGenerateEnabled();
  wireEvents();
  setFps(state.fps);
  els.engineSelect.value = state.engine;
  initLlm();
  initDiffusion();
}

boot();
