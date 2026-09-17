#!/usr/bin/env python3
"""Pack generated 101-200 masters into direct-use Godot assets.

The built-in image generator intentionally produces large masters.  This
script keeps those masters untouched in image/generated_101_200/source and
creates exact-size, hard-alpha, fixed-cell outputs in image/generated_101_200/ready.
It also writes a prompt/index manifest and visual QA contact sheets.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "docs" / "2026-09-15-图片提示词总库.md"
PACKAGE = ROOT / "image" / "generated_101_200"
SOURCE = PACKAGE / "source"
READY = PACKAGE / "ready"
QA = PACKAGE / "qa"


def parse_jobs() -> list[dict]:
    text = LIBRARY.read_text(encoding="utf-8")
    rx = re.compile(r"(?ms)^\*\*(\d{3})\.\s+([^*]+)\*\*.*?^```text\r?\n(.*?)\r?\n```")
    jobs: list[dict] = []
    for match in rx.finditer(text):
        number = int(match.group(1))
        if 101 <= number <= 200:
            prompt = match.group(3).strip()
            dims = re.search(r"规格[：:]\s*(\d+)×(\d+)像素", prompt)
            frames = re.search(r"横向sprite sheet排布(\d+)帧", prompt)
            if dims:
                kind = "map" if number <= 142 else "status" if number <= 184 else "skill"
                width, height = int(dims.group(1)), int(dims.group(2))
            else:
                kind = "fx" if number <= 167 else "sfx"
                width = 240 if kind == "fx" else 128
                height = width
            jobs.append(
                {
                    "number": number,
                    "id": match.group(2).strip(),
                    "prompt": prompt,
                    "kind": kind,
                    "width": width,
                    "height": height,
                    "frames": int(frames.group(1)) if frames else 1,
                }
            )
    if [job["number"] for job in jobs] != list(range(101, 201)):
        raise RuntimeError("prompt library does not contain the complete 101-200 range")
    return jobs


def hard_alpha(image: Image.Image) -> Image.Image:
    """Remove soft AI alpha edges while retaining the RGB artwork."""
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    image.putalpha(alpha)
    return image


def non_black_bbox(image: Image.Image, threshold: int = 18):
    """Find effect pixels on a black or transparent background."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    mask = Image.new("L", rgba.size, 0)
    mp = mask.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a >= 128 and max(r, g, b) > threshold:
                mp[x, y] = 255
    return mask.getbbox()


def contained(image: Image.Image, size: tuple[int, int], margin: int, *, bottom: bool = False) -> Image.Image:
    """Place a cropped sprite into an exact canvas with nearest-safe bounds."""
    image = hard_alpha(image)
    bbox = image.getbbox()
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    if not bbox:
        return canvas
    crop = image.crop(bbox)
    inner_w = max(1, size[0] - margin * 2)
    inner_h = max(1, size[1] - margin * 2)
    scale = min(inner_w / crop.width, inner_h / crop.height)
    target = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    resized = crop.resize(target, Image.Resampling.LANCZOS)
    resized = hard_alpha(resized)
    x = (size[0] - target[0]) // 2
    y = size[1] - margin - target[1] if bottom else (size[1] - target[1]) // 2
    canvas.alpha_composite(resized, (x, max(0, y)))
    return canvas


def map_asset(source_path: Path, job: dict) -> Image.Image:
    image = hard_alpha(Image.open(source_path))
    # AI masters normally have alpha already.  Only remove black pixels when
    # the outer canvas is opaque black, so dark-brown outlines are preserved.
    alpha_values = list(image.getchannel("A").getdata())
    if alpha_values and min(alpha_values) >= 255:
        image = image.convert("RGB").convert("RGBA")
        bbox = non_black_bbox(image)
        if bbox:
            image = image.crop(bbox)
    bottom = any(token in job["prompt"] for token in ("底部接地阴影", "下半埋沙"))
    return contained(image, (job["width"], job["height"]), 4, bottom=bottom)


def sheet_asset(source_path: Path, job: dict) -> Image.Image:
    source = hard_alpha(Image.open(source_path))
    # Split the generated master by the requested count.  The generator's
    # horizontal sheets have equal visual cells even when the master pixels
    # are larger than the requested runtime cell.
    frames = job["frames"]
    cell_size = (job["width"], job["height"])
    output = Image.new("RGBA", (cell_size[0] * frames, cell_size[1]), (0, 0, 0, 0))
    for index in range(frames):
        left = round(index * source.width / frames)
        right = round((index + 1) * source.width / frames)
        frame = source.crop((left, 0, right, source.height))
        bbox = non_black_bbox(frame)
        if bbox:
            frame = frame.crop(bbox)
        cell = contained(frame, cell_size, 8 if job["kind"] == "fx" else 5)
        output.alpha_composite(cell, (index * cell_size[0], 0))
    return output


def icon_asset(source_path: Path, job: dict) -> Image.Image:
    image = hard_alpha(Image.open(source_path))
    # Icon masters may carry a transparent or black outer field.  Keep the
    # requested frame and remove only empty outer pixels before fitting.
    bbox = image.getbbox() or non_black_bbox(image)
    if bbox:
        image = image.crop(bbox)
    return contained(image, (job["width"], job["height"]), 1)


def font() -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    except OSError:
        return ImageFont.load_default()


def checkerboard(size: tuple[int, int], tile: int = 12) -> Image.Image:
    canvas = Image.new("RGB", size, (38, 43, 53))
    draw = ImageDraw.Draw(canvas)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if ((x // tile) + (y // tile)) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(55, 61, 73))
    return canvas


def make_contact_sheet(images: list[tuple[dict, Image.Image]], output: Path, columns: int, thumb: tuple[int, int]) -> None:
    label_h = 34
    gap = 12
    rows = (len(images) + columns - 1) // columns
    sheet = checkerboard((columns * (thumb[0] + gap) + gap, rows * (thumb[1] + label_h + gap) + gap))
    draw = ImageDraw.Draw(sheet)
    text_font = font()
    for index, (job, image) in enumerate(images):
        col = index % columns
        row = index // columns
        x = gap + col * (thumb[0] + gap)
        y = gap + row * (thumb[1] + label_h + gap)
        preview = image.convert("RGBA")
        preview.thumbnail(thumb, Image.Resampling.NEAREST)
        px = x + (thumb[0] - preview.width) // 2
        py = y + (thumb[1] - preview.height) // 2
        sheet.paste(preview, (px, py), preview)
        draw.text((x, y + thumb[1] + 3), f"{job['number']} {job['id'][:22]}", fill=(242, 244, 248), font=text_font)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


def main() -> None:
    jobs = parse_jobs()
    for directory in (READY / "map", READY / "fx", READY / "status", READY / "skill", QA):
        directory.mkdir(parents=True, exist_ok=True)

    manifest = []
    created: list[tuple[dict, Image.Image]] = []
    by_kind: dict[str, list[tuple[dict, Image.Image]]] = {"map": [], "fx": [], "sfx": [], "status": [], "skill": []}
    for job in jobs:
        source_path = SOURCE / f"{job['number']:03d}_{job['id']}.png"
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        if job["kind"] == "map":
            ready = map_asset(source_path, job)
            relative = Path("ready") / "map" / f"{job['id']}.png"
            target = PACKAGE / relative
        elif job["kind"] in ("fx", "sfx"):
            ready = sheet_asset(source_path, job)
            relative = Path("ready") / "fx" / f"{job['id']}.png"
            target = PACKAGE / relative
        else:
            ready = icon_asset(source_path, job)
            folder = "status" if job["kind"] == "status" else "skill"
            relative = Path("ready") / folder / f"{job['id']}.png"
            target = PACKAGE / relative
        ready.save(target)
        record = dict(job)
        record.update({"source": str(Path("source") / source_path.name).replace("\\", "/"), "ready": str(relative).replace("\\", "/"), "status": "ready"})
        manifest.append(record)
        by_kind.setdefault(job["kind"], []).append((job, ready))
        created.append((job, ready))

    (PACKAGE / "jobs.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    make_contact_sheet(by_kind["map"], QA / "contact_sheet_map.png", 8, (160, 160))
    make_contact_sheet(by_kind["fx"], QA / "contact_sheet_fx.png", 4, (360, 120))
    make_contact_sheet(by_kind["sfx"], QA / "contact_sheet_sfx.png", 4, (260, 130))
    make_contact_sheet(by_kind["status"] + by_kind["skill"], QA / "contact_sheet_icons.png", 8, (96, 96))
    # A compact first/middle/last-frame sheet makes frame drift visible without
    # requiring an editor or a running game.
    frame_checks: list[tuple[dict, Image.Image]] = []
    for job, image in by_kind["fx"] + by_kind["sfx"]:
        cell_w = job["width"]
        frames = job["frames"]
        selected = [0, frames // 2, frames - 1]
        strip = Image.new("RGBA", (cell_w * 3, job["height"]), (0, 0, 0, 0))
        for position, frame_index in enumerate(selected):
            strip.alpha_composite(image.crop((frame_index * cell_w, 0, (frame_index + 1) * cell_w, job["height"])), (position * cell_w, 0))
        frame_checks.append((job, strip))
    make_contact_sheet(frame_checks, QA / "contact_sheet_frame_checks.png", 4, (360, 160))

    readme = "# 101–200 图片素材\n\n"
    readme += "按 `docs/2026-09-15-图片提示词总库.md` 的 101–200 号生成，共 100 张；100 号未重复生成。\n\n"
    readme += "## 目录\n\n"
    readme += "- `source/`：内置 imagegen 返回的原始母稿，保留原始比例，便于追溯。\n"
    readme += "- `ready/map/`：101–142，精确画布、硬 alpha、统一居中/接地或悬浮锚点，可直接放到地图层。\n"
    readme += "- `ready/fx/`：143–167，240×240 等宽帧格的横向条带，按 `frames` 列切图。\n"
    readme += "- `ready/fx/`：185–192，128×128 等宽帧格的横向条带，按 `frames` 列切图。\n"
    readme += "- `ready/status/`：168–184，32×32 状态图标。\n"
    readme += "- `ready/skill/`：193–200，64×64 技能图标。\n"
    readme += "- `qa/`：按类别的验收总览和首/中/尾帧检查图。\n\n"
    readme += "## Godot 使用约定\n\n"
    readme += "地图精灵使用 ready/map 中的无文字 PNG；角色/怪物节点锚点放在脚底或提示词指定的悬浮中心。fx 与 sfx 条带按 jobs.json 的 `frames` 等分切块，ready 版本为透明 alpha，适合直接叠加；source 母稿保留生成器原始结果。导入时使用 Nearest、关闭 mipmaps。\n\n"
    readme += "## 验收\n\n"
    readme += "脚本已检查 101–200 每个编号均有 source 与 ready，ready 图像按提示词尺寸生成；接地类保留底部安全边，悬浮类垂直居中；特效条带按指定帧数等宽切分。详细字段见 jobs.json。\n"
    (PACKAGE / "README.md").write_text(readme, encoding="utf-8")
    print(json.dumps({"generated": len(created), "ready": len(manifest), "package": str(PACKAGE), "qa": str(QA)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
