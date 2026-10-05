// preview.js — animated per-action preview players.
//
// Each player draws its action's frames onto a canvas, cycling at the global
// FPS. A shared clock keeps every preview in step and lets the FPS slider
// retime them live. Players can be paused/scrubbed individually.

const players = new Set();
let fps = 8;
let rafId = null;
let lastT = 0;
let acc = 0;

function tick(now) {
  if (!lastT) lastT = now;
  const dt = now - lastT;
  lastT = now;
  acc += dt;
  const step = 1000 / fps;
  if (acc >= step) {
    const advance = Math.floor(acc / step);
    acc -= advance * step;
    for (const p of players) {
      if (p.playing) {
        p.index = (p.index + advance) % p.frames.length;
        p.draw();
      }
    }
  }
  rafId = requestAnimationFrame(tick);
}

function ensureClock() {
  if (rafId == null) {
    lastT = 0;
    acc = 0;
    rafId = requestAnimationFrame(tick);
  }
}

export function setFps(v) {
  fps = Math.max(1, Math.min(24, v));
}

export function clearPlayers() {
  players.clear();
}

export class PreviewPlayer {
  constructor(frames, canvas, scrub, playBtn) {
    this.frames = frames;
    this.canvas = canvas;
    this.scrub = scrub;
    this.playBtn = playBtn;
    this.index = 0;
    this.playing = true;

    const f = frames[0];
    // fit within the stage while preserving aspect and crispness
    const maxH = 104;
    const scale = Math.max(1, Math.min(3, Math.floor(maxH / f.height) || 1));
    canvas.width = f.width * scale;
    canvas.height = f.height * scale;
    this.ctx = canvas.getContext('2d');
    this.ctx.imageSmoothingEnabled = false;
    this.scale = scale;

    scrub.max = String(frames.length - 1);
    scrub.addEventListener('input', () => {
      this.playing = false;
      this.updatePlayBtn();
      this.index = Number(scrub.value);
      this.draw();
    });
    playBtn.addEventListener('click', () => this.toggle());

    players.add(this);
    ensureClock();
    this.draw();
  }

  updatePlayBtn() {
    this.playBtn.textContent = this.playing ? '⏸' : '▶';
  }

  toggle() {
    this.playing = !this.playing;
    this.updatePlayBtn();
  }

  draw() {
    const f = this.frames[this.index];
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    this.ctx.drawImage(f, 0, 0, this.canvas.width, this.canvas.height);
    this.scrub.value = String(this.index);
    this.updatePlayBtn();
  }
}
