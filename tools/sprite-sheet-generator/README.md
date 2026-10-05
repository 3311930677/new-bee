# 🧑‍🎨 sprite-sheet-generator

**Turn a single source image into a full, multi-action sprite sheet — entirely on your own machine.**

Upload one character image, name the actions you want (Idle, Walk, Sword Swing, Jump…) and how many frames each should have, and the app synthesizes one animation row per action, previews each one animated, runs a quality check on every row, and lets you download the finished sheet as a transparent PNG.

Everything runs **locally** — a zero-dependency Node server, on-device frame generation in the browser, and a **local LLM (Ollama)** for the quality checks. No hosted APIs, no keys, no per-image cost.

![The full app after generating a sprite sheet](docs/images/hero.png)

---

## ✨ Features

- 🖼️ **One source image → many animations.** One row per action, each with its own frame count.
- 🎨 **Two local generation engines.** A local **diffusion** model (Stable Diffusion img2img) by default for the best quality, with an instant **on-device motion-transform** engine as a fully-offline fallback / second option.
- 🎞️ **Live animated previews** for every action, with a global FPS slider.
- ✅ **Automatic quality checks** after each row — positioning, visual consistency, and action accuracy — computed from the real pixels and *verified by a local vision LLM* when one is available.
- 🪟 **Transparent background by default**, with a solid-color fallback and one-click **source background removal**.
- 📐 **Auto-scales very large sources** down to a sensible sprite-frame size, so frames stay viewable and the sheet stays lean.
- 📥 **Download PNG** of the full sheet, plus an expandable full-sheet viewer below the fold.
- 🔌 **100% local & offline-capable.** Zero npm dependencies. Both the diffusion backend and the LLM are optional — the app degrades gracefully without them.

---

## 📦 Installation

**Requirement:** [Node.js](https://nodejs.org) **≥ 18**. That's it — the app has **no npm dependencies**.

```bash
git clone https://github.com/Aelof3/sprite-sheet-generator.git
cd sprite-sheet-generator
npm start                 # or: node server.js
```

Then open **http://localhost:5173**.

```bash
PORT=8080 node server.js  # run on a different port
npm run dev               # auto-restart while developing (node --watch)
```

### Optional: enable the local diffusion engine (default, best quality)

The default generation engine is a **local Stable Diffusion img2img** backend
(any AUTOMATIC1111-compatible server: [A1111](https://github.com/AUTOMATIC1111/stable-diffusion-webui),
[Forge](https://github.com/lllyasviel/stable-diffusion-webui-forge), SD.Next).

This repo includes a helper that sets up and launches a local A1111 instance in a
`stable-diffusion-webui/` subfolder (which is gitignored — it's multi-GB and
per-machine):

```bash
# one-time:
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
# add a SD 1.5 .safetensors checkpoint to stable-diffusion-webui/models/Stable-diffusion/
./start-sd.sh            # first run builds a venv + installs Torch (several minutes)
#                          then serves the img2img API at http://localhost:7860
```

`start-sd.sh` bakes in the tweaks a fresh A1111 needs today on Apple Silicon: it
uses Python 3.10, pins an installable Torch, constrains `setuptools<81` (so
CLIP's legacy build works), and — because Stability AI **deleted** the upstream
`Stability-AI/stablediffusion` dependency repo — points at the maintained
[`w-e-w/stablediffusion`](https://github.com/w-e-w/stablediffusion) fork (the fix
documented in [A1111 issue #17309](https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/17309)).

The app auto-detects the backend (a green "Local Stable Diffusion detected" hint
appears under **Generation engine**). Point at a different host with
`SD_HOST=http://host:7860 node server.js`.

> **Heads-up on speed:** local diffusion is *slow* — each frame is a full img2img
> generation (and every row is then analyzed for quality). Frames are generated
> at a ~512px resolution and downscaled to your sprite size (SD 1.5 produces mush
> at raw sprite dimensions), so expect seconds-to-minutes per frame on CPU/MPS.
> This is expected; the progress bar tracks each frame.

**No diffusion backend? No problem.** The app automatically falls back to the
on-device **Motion transform** engine (which you can also pick manually) — it
needs nothing installed and runs fully offline.

### Optional: enable local-LLM verification

The app works fully without it, but a local vision model adds an AI "second opinion" to each quality check. It uses [Ollama](https://ollama.com):

```bash
ollama serve                 # start the local LLM host (http://localhost:11434)
ollama pull moondream        # small, fast vision model (~1.7 GB)
#   alternatives: llava, llama3.2-vision, minicpm-v — the app auto-detects one
```

A status strip at the top of the page tells you which mode is active:

- 🟢 *Local LLM connected — quality checks verified by `moondream` (Ollama, on-device).*
- 🟠 *No local vision model detected — using on-device pixel metrics.*

Point at a non-default Ollama host with `OLLAMA_HOST=http://host:11434 node server.js`.

---

## 🚀 Usage

### 1. Add a source image

Drag & drop (or click to browse) a single character image — PNG or JPG. The app reads its dimensions; **every generated frame keeps these exact dimensions.** Very large images are automatically scaled down to a sensible sprite-frame size (you'll see e.g. `1024 × 1536 px → 85 × 128 px`) so frames stay viewable.

![Source image panel](docs/images/01-source.png)

### 2. Define actions / animations

List the actions you want, each with a frame count. Rows are **editable, deletable, and drag-to-reorder** — the sheet is generated top-to-bottom in this order. Add new actions with the **Add Action** form.

![Actions / animations panel](docs/images/02-actions.png)

### 3. Choose output options

- **Generation engine** — **Diffusion (local)** by default (uses your local Stable Diffusion; the hint shows when it's detected), or **Motion transform** for the instant on-device engine. If diffusion is selected but no backend is running, it falls back to motion transform automatically.
- **Transparent Background** (default ON) — turn off to bake in a solid background color.
- **Remove source background** — flood-fills transparency inward from the image edges (great for sprites on a flat backdrop).
- **Preview speed** — frames-per-second for the animated previews, retimed live.

![Output options panel](docs/images/03-options.png)

Then hit **Generate Sprite Sheet**. A progress bar tracks each frame and each check.

### 4. Review the generated preview

Each action is shown **animated on the left** (play/pause + scrub) next to its **row of frames** on a transparent checkerboard. The header shows the frame size, total frame count, and a **Download PNG** button.

![Generated sprite sheet preview](docs/images/04-preview.png)

### 5. Read the quality checks

As soon as each action finishes generating, a quality card appears scoring three things — **positioning consistency**, **visual consistency**, and **action accuracy** — with an overall percentage. When a local LLM is connected, cards are additionally marked *verified by local LLM*. A summary confirms when the whole sheet is ready.

![Quality checks panel](docs/images/05-checks.png)

### 6. Grab the full sheet

Expand **Full sprite sheet** below the fold to see the entire composited sheet (one row per action), then **Download PNG**.

![Full sprite sheet viewer](docs/images/06-fullsheet.png)

---

## 🧠 How it works (fully local, no paid APIs)

- **The motion model always poses the frames.** `public/js/generator.js` matches the action name to a **motion model** — `idle, walk, run, jump, fall, swing/attack, punch, cast, spin, crouch, hurt, death, wave` — and transforms your source image on a `<canvas>` (bob, sway, squash/stretch, rotation sweeps, weapon arcs, magic glows). This is what makes the character actually *perform the action*, frame by frame. Frames keep the (auto-scaled) source dimensions.
- **The two engines differ in how each posed frame is rendered:**
  - **Diffusion (default).** SD 1.5 can't invent coherent animation from a prompt, so we don't ask it to — instead it runs a **low-denoise img2img render pass over the already-posed frame** (`server.js` → `SD_HOST`, default `:7860`). A **fixed seed across the whole row** keeps the character consistent, and the posed frame's own **alpha silhouette masks** the result (clean edges, no background artifacts). Generation happens at ~512px and is downscaled to the frame size. Best quality; needs a local SD backend (`./start-sd.sh`). Falls back to the posed frame if a call fails.
  - **Motion transform (second option).** Uses the posed frame directly — instant, fully offline, nothing to install.
- **Quality checks** (`public/js/checks.js`) are computed from the actual generated pixels: centroid stability (positioning), palette/color stability (visual), and frame-to-frame motion energy (accuracy). When a local vision model is present, the app composites the row into a single contact-sheet image, sends it to Ollama, and blends the model's grade in as a verification nudge.
- **The server** (`server.js`) is a zero-dependency Node HTTP server that serves the app and proxies `/api/diffusion/*` to Stable Diffusion and `/api/llm/*` to Ollama. Nothing else leaves your machine.

---

## 🗂️ Project structure

```
server.js                zero-dep Node server: serves the app + proxies /api/diffusion/* and /api/llm/*
start-sd.sh              sets up + launches the local Stable Diffusion (A1111) backend on :7860
public/index.html        the UI (matches the design in main-design.jpg)
public/styles.css        light/dark theme + layout
public/js/app.js         state + orchestration (upload, actions, generate, download)
public/js/generator.js   on-device per-action frame synthesis (motion-transform engine)
public/js/diffusion.js   local Stable Diffusion img2img client (default engine)
public/js/checks.js      quality checks (pixel metrics + optional local-LLM verify)
public/js/preview.js     animated preview players (shared FPS clock)
public/js/bgremove.js    flood-fill background removal
public/js/llm.js         local-LLM (Ollama) client
docs/images/             screenshots used in this README
TODO.md                  original project spec + future ideas
CLAUDE.md                architecture notes for contributors
```

## ⚙️ Configuration

| Env var       | Default                  | Description                              |
| ------------- | ------------------------ | ---------------------------------------- |
| `PORT`        | `5173`                   | Port the web app listens on              |
| `SD_HOST`     | `http://localhost:7860`  | Local Stable Diffusion (img2img) backend |
| `OLLAMA_HOST` | `http://localhost:11434` | Local Ollama host for LLM checks         |

---

*Design reference: `main-design.jpg`.*
