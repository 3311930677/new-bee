"""Apply a restrained, reproducible pixel grid to runtime PNG artwork.

Pillow is the open-source processing engine. Original PNGs remain recoverable
from Git; this script only changes tracked runtime art, never source/QA masters.
Run without --apply to make comparison sheets and a JSON audit first.
"""

from __future__ import annotations

import argparse
import io
import json
import subprocess
from collections import Counter
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat


ROOT = Path(__file__).resolve().parents[1]
IMAGE_ROOT = ROOT / "image"
AUDIT_ROOT = ROOT.parent / "pixel_audit"
# Keep the pre-filter originals stable even after the generated PNGs are committed.
SOURCE_REV = "fd7cefde640944a0f2aaf507de5ad78d38505302"
GENERATED = (
    "generated_001_100", "generated_101_200", "generated_201_333",
    "generated_334_341", "generated_342_353", "generated_362_xajh",
)
DIRECT = {"background", "fourth_act", "main_world", "map_proc", "mounts", "role", "third_act"}
SAMPLES = (
    "main_world/lorin_wilds_reference_v6.png",
    "main_world/shenyuan_port_ground_reference_v2.png",
    "role/zs/pojun_walk_4dir.png",
    "generated_362_xajh/ready/monster/mon_ghost.png",
    "generated_201_333/ready/npcs/npc_steward_portrait.png",
    "mounts/first_horse_zs.png",
    "main_world/mon_lost_beast.png",
    "generated_342_353/ready/city_buildings/city_archive.png",
    "generated_362_xajh/ready/bg/world_snow.png",
    "generated_001_100/source/063_deco_bg_clouds.png",
    "background/home.png",
)


def original_image(path: Path) -> Image.Image:
    return Image.open(io.BytesIO(original_bytes(path)))


def original_bytes(path: Path) -> bytes:
    relative = path.relative_to(ROOT.parent).as_posix()
    result = subprocess.run(
        ["git", "show", f"{SOURCE_REV}:{relative}"],
        cwd=ROOT.parent, capture_output=True, check=True
    )
    return result.stdout


def source_key(path: Path) -> str:
    name = path.name
    return name[name.find("_") + 1 :] if "_" in name else name


def inventory() -> tuple[list[Path], list[dict[str, str]]]:
    chosen: list[Path] = []
    excluded: list[dict[str, str]] = []
    ready_names: set[str] = set()
    for batch in GENERATED:
        ready_names.update(p.name for p in (IMAGE_ROOT / batch / "ready").rglob("*.png"))

    for path in sorted(IMAGE_ROOT.rglob("*.png")):
        parts = path.relative_to(IMAGE_ROOT).parts
        top = parts[0]
        reason = ""
        if top in DIRECT:
            if top == "role" and "walk_4dir_review" in parts:
                reason = "animation review sheet"
        elif top in GENERATED:
            if len(parts) > 1 and parts[1] == "ready":
                pass
            elif len(parts) > 1 and parts[1] == "source":
                if source_key(path) in ready_names:
                    reason = "source master with runtime ready version"
            else:
                reason = "QA or overview"
        else:
            reason = "inactive source or old tileset"
        if top == "ui":
            reason = "lettering needs full-resolution edges"
        if reason:
            excluded.append({"path": path.relative_to(ROOT).as_posix(), "reason": reason})
        else:
            chosen.append(path)
    return chosen, excluded


def settings(path: Path, image: Image.Image) -> tuple[int, int] | None:
    width, height = image.size
    if path.relative_to(IMAGE_ROOT).parts[0] == "role":
        return None  # Validated frame registration and tiny face details.
    if min(width, height) <= 256:
        return None  # Already screen-resolution pixel art; 2x2 smears details.
    if min(width, height) <= 512:
        return 2, 192
    return 2, 256


def pixelize(source: Image.Image, cell: int, colors: int) -> Image.Image:
    rgba = source.convert("RGBA")
    width, height = rgba.size
    # Pad on the right/bottom only, preserving every atlas/frame coordinate.
    padded = Image.new("RGBA", ((width + cell - 1) // cell * cell,
                                (height + cell - 1) // cell * cell))
    padded.paste(rgba, (0, 0))
    small = padded.resize((padded.width // cell, padded.height // cell), Image.Resampling.BOX)
    rgb = small.convert("RGB").quantize(
        colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    ).convert("RGB")
    alpha = rgba.getchannel("A")
    result = rgb.convert("RGBA")
    result = result.resize(padded.size, Image.Resampling.NEAREST).crop((0, 0, width, height))
    # A sprite's alpha bounds are gameplay geometry (anchors, hit silhouettes).
    # Leave them bit-exact rather than losing wisps/feet to a block threshold.
    result.putalpha(alpha)
    return result


def display_error(source: Image.Image, result: Image.Image) -> float:
    screen_long_edge = 800 if source.height > source.width else 480
    scale = min(1.0, screen_long_edge / max(source.size))
    size = (max(1, round(source.width * scale)), max(1, round(source.height * scale)))
    matte = Image.new("RGBA", source.size, "#242633")
    before = Image.alpha_composite(matte, source.convert("RGBA")).convert("RGB")
    after = Image.alpha_composite(matte, result.convert("RGBA")).convert("RGB")
    before = before.resize(size, Image.Resampling.LANCZOS)
    after = after.resize(size, Image.Resampling.LANCZOS)
    return sum(ImageStat.Stat(ImageChops.difference(before, after)).mean) / 3


def make_samples(paths: list[Path]) -> list[str]:
    AUDIT_ROOT.mkdir(parents=True, exist_ok=True)
    created = []
    for relative in SAMPLES:
        path = IMAGE_ROOT / relative
        if path not in paths:
            continue
        with original_image(path) as source:
            policy = settings(path, source)
            if policy is None:
                continue
            result = pixelize(source, *policy)
            rejected = display_error(source, result) > 8.0
            result.save(AUDIT_ROOT / (path.stem + "_pixel.png"))
            scale = min(1.0, 420 / max(source.size))
            thumb_size = (max(1, round(source.width * scale)), max(1, round(source.height * scale)))
            left = source.convert("RGBA").resize(thumb_size, Image.Resampling.LANCZOS)
            right = result.resize(thumb_size, Image.Resampling.LANCZOS)
            panel = Image.new("RGB", (thumb_size[0] * 2 + 24, thumb_size[1] + 44), "#252734")
            panel.paste(left, (8, 32), left)
            panel.paste(right, (thumb_size[0] + 16, 32), right)
            draw = ImageDraw.Draw(panel)
            draw.text((8, 9), "ORIGINAL", fill="#faf6e9")
            draw.text((thumb_size[0] + 16, 9),
                      "REJECTED: DETAIL LOSS" if rejected else "PIXEL GRID",
                      fill="#f1a5a5" if rejected else "#faf6e9")
            output = AUDIT_ROOT / (path.stem + "_compare.png")
            panel.save(output)
            created.append(str(output))
    return created


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="overwrite tracked runtime PNGs")
    args = parser.parse_args()
    chosen, excluded = inventory()
    counts = Counter()
    changed = []
    pixelized = []
    rejected = []
    for path in chosen:
        with Image.open(path) as image:
            policy = settings(path, image)
            current = image.convert("RGBA") if policy is not None and args.apply else None
        if policy is None:
            counts["already_small"] += 1
            continue
        counts["eligible"] += 1
        if not args.apply:
            continue
        original = original_bytes(path)
        with Image.open(io.BytesIO(original)) as source:
            output = pixelize(source, *policy)
            error = display_error(source, output)
            if source.convert("RGBA").tobytes() != output.tobytes() and error <= 8.0:
                pixelized.append(path.relative_to(ROOT).as_posix())
        if error > 8.0:
            rejected.append({"path": path.relative_to(ROOT).as_posix(),
                             "display_mae": round(error, 2)})
            if path.read_bytes() != original:
                temporary = path.with_name(path.stem + ".pixel-tmp.png")
                try:
                    temporary.write_bytes(original)
                    temporary.replace(path)
                finally:
                    temporary.unlink(missing_ok=True)
                changed.append(path.relative_to(ROOT).as_posix())
            continue
        if current.tobytes() == output.tobytes():
            counts["already_aligned"] += 1
            continue
        if args.apply:
            temporary = path.with_name(path.stem + ".pixel-tmp.png")
            try:
                output.save(temporary, optimize=True)
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)
            changed.append(path.relative_to(ROOT).as_posix())
    samples = make_samples(chosen)
    report = {
        "source_revision": SOURCE_REV,
        "engine": "Pillow BOX downsample, palette quantization without dither, nearest grid reconstruction",
        "policy": "2 source pixels per logical pixel; 192/256 colors by dimensions; unchanged output dimensions and alpha; display MAE <= 8",
        "counts": dict(counts), "pixelized": pixelized,
        "changed_this_run": changed, "quality_rejected": rejected,
        "excluded": excluded, "samples": samples,
    }
    AUDIT_ROOT.mkdir(parents=True, exist_ok=True)
    (AUDIT_ROOT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"PIXEL_AUDIT_OK selected={len(chosen)} eligible={counts['eligible']} "
          f"small={counts['already_small']} changed={len(changed)} "
          f"quality_rejected={len(rejected)} excluded={len(excluded)}")
    for sample in samples:
        print(sample)


if __name__ == "__main__":
    main()
