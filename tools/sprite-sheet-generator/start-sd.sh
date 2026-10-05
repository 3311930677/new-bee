#!/usr/bin/env bash
#
# Start the local Stable Diffusion (AUTOMATIC1111) backend that powers the
# default diffusion generation engine. Serves an img2img API at :7860.
#
# The stable-diffusion-webui/ folder is large and set up per-machine, so it is
# gitignored — this committed script captures the environment tweaks needed to
# launch (and first-time install) it on Apple Silicon / macOS.
#
#   ./start-sd.sh
#
# One-time setup (if you haven't already):
#   git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
#   # drop a SD 1.5 .safetensors into stable-diffusion-webui/models/Stable-diffusion/
#   ./start-sd.sh   # first run builds the venv + installs Torch (several minutes)

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)/stable-diffusion-webui"
if [ ! -f "$DIR/webui.sh" ]; then
  echo "error: $DIR/webui.sh not found — clone AUTOMATIC1111/stable-diffusion-webui there first." >&2
  exit 1
fi
cd "$DIR"

# A1111 supports Python 3.10/3.11 (not 3.12+); this repo's default machine has 3.10.
export python_cmd="${python_cmd:-python3.10}"

# Keep CPU-side work modest so the laptop runs cooler. The heavy GPU (MPS) work is
# throttled separately by the app's "Gentle mode" cooldown between frames.
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-2}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-2}"

# Newer setuptools (>=81) dropped pkg_resources, which CLIP's legacy setup.py
# imports — constrain build-time setuptools so first-run installs succeed.
CONSTRAINTS="$(mktemp)"
printf 'setuptools<81\nwheel\n' > "$CONSTRAINTS"
export PIP_CONSTRAINT="$CONSTRAINTS"

# Upstream Stability-AI/stablediffusion was deleted (404); use the fork maintained
# by w-e-w (an AUTOMATIC1111 maintainer), per A1111 issue #17309.
export STABLE_DIFFUSION_REPO="${STABLE_DIFFUSION_REPO:-https://github.com/w-e-w/stablediffusion.git}"

# A1111 v1.10.1's macOS env pins torch==2.3.1, which has no wheel on recent macOS;
# pin the last installable pair (idempotent).
if [ -f webui-macos-env.sh ]; then
  sed -i '' 's/torch==2.3.1 torchvision==0.18.1/torch==2.2.2 torchvision==0.17.2/' webui-macos-env.sh || true
fi

exec ./webui.sh --api --nowebui --port 7860 --skip-torch-cuda-test "$@"
