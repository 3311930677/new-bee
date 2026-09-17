#!/usr/bin/env python3
"""Pack generated 201-333 masters into exact-size, direct-use assets."""

from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "docs" / "2026-09-15-图片提示词总库.md"
PACKAGE = ROOT / "image" / "generated_201_333"
SOURCE = PACKAGE / "source"
READY = PACKAGE / "ready"
QA = PACKAGE / "qa"


def parse_jobs() -> list[dict]:
    text = LIBRARY.read_text(encoding="utf-8")
    rx = re.compile(r"(?ms)^\*\*(\d{3})\.\s+([^*]+)\*\*.*?^```text\r?\n(.*?)\r?\n```")
    jobs: list[dict] = []
    for match in rx.finditer(text):
        number = int(match.group(1))
        if not 201 <= number <= 333:
            continue
        prompt = match.group(3).strip()
        dims = re.search(r"规格[：:]\s*(\d+)×(\d+)", prompt)
        frames_match = re.search(r"(?:横向sprite sheet排布|排布)(\d+)帧", prompt)
        if frames_match:
            frames = int(frames_match.group(1))
            frame_dims = re.search(r"每帧(?:为一整张|)(\d+)×(\d+)", prompt)
            if not frame_dims:
                frame_dims = re.search(r"每帧(\d+)×(\d+)", prompt)
            width = int(frame_dims.group(1)) if frame_dims else 192
            height = int(frame_dims.group(2)) if frame_dims else 192
            kind = "fx"
        elif dims:
            width, height = int(dims.group(1)), int(dims.group(2))
            if 201 <= number <= 212:
                kind = "skill"
            elif 213 <= number <= 220:
                kind = "node"
            elif 221 <= number <= 224:
                kind = "frame"
            elif 225 <= number <= 231:
                kind = "small_icon"
            elif 232 <= number <= 234 or 243 <= number <= 248 or 254 <= number <= 257 or 301 <= number <= 306:
                kind = "ui"
            elif 235 <= number <= 238:
                kind = "card"
            elif 241 <= number <= 242 or 258 <= number <= 300:
                kind = "small_icon"
            elif 249 <= number <= 253:
                kind = "badge"
            elif 307 <= number <= 312:
                kind = "slot"
            elif 313 <= number <= 315:
                kind = "npc"
            elif 316 <= number <= 327:
                kind = "mount"
            else:
                kind = "brand"
            frames = 1
        else:
            raise RuntimeError(f"missing dimensions for {number}")
        jobs.append({"number": number, "id": match.group(2).strip(), "prompt": prompt, "kind": kind, "width": width, "height": height, "frames": frames})
    if [job["number"] for job in jobs] != list(range(201, 334)):
        raise RuntimeError("prompt library does not contain the complete 201-333 range")
    return jobs


def hard_alpha(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    image.putalpha(image.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
    return image


def non_black_bbox(image: Image.Image, threshold: int = 18):
    rgba = hard_alpha(image)
    alpha = rgba.getchannel("A")
    gray = rgba.convert("RGB").convert("L").point(lambda value: 255 if value > threshold else 0)
    # Multiplication preserves only pixels that are both visible and non-black.
    mask = Image.eval(Image.merge("RGB", (alpha, alpha, alpha)), lambda value: value)
    mask = alpha.copy()
    mask = Image.composite(mask, Image.new("L", rgba.size, 0), gray)
    return mask.getbbox()


def contained(image: Image.Image, size: tuple[int, int], margin: int = 4, bottom: bool = False) -> Image.Image:
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
    resized = hard_alpha(crop.resize(target, Image.Resampling.LANCZOS))
    x = (size[0] - target[0]) // 2
    y = size[1] - margin - target[1] if bottom else (size[1] - target[1]) // 2
    canvas.alpha_composite(resized, (x, max(0, y)))
    return canvas


def opaque_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = image.convert("RGBA")
    bg = Image.new("RGBA", rgba.size, (42, 31, 28, 255))
    bg.alpha_composite(rgba)
    return bg.convert("RGB").resize(size, Image.Resampling.LANCZOS).convert("RGBA")


def static_asset(source_path: Path, job: dict) -> Image.Image:
    source = hard_alpha(Image.open(source_path))
    # The market logo is an overlay asset; keep its transparent canvas even
    # though the other brand/marketing assets are full-bleed opaque artwork.
    if job["kind"] in {"ui", "card", "brand", "skill"} and job["number"] != 330:
        return opaque_resize(source, (job["width"], job["height"]))
    bottom = job["kind"] == "mount" or "底部接地阴影" in job["prompt"]
    ready = contained(source, (job["width"], job["height"]), 4, bottom=bottom)
    if job["kind"] == "frame":
        # Card rarity frames are overlays: force the central card area hollow.
        pixels = ready.load()
        left, top = 8, 8
        right, bottom_edge = ready.width - 8, ready.height - 8
        for y in range(top, max(top, bottom_edge)):
            for x in range(left, max(left, right)):
                r, g, b, _ = pixels[x, y]
                pixels[x, y] = (r, g, b, 0)
    return ready


def sheet_asset(source_path: Path, job: dict) -> Image.Image:
    source = hard_alpha(Image.open(source_path))
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
        output.alpha_composite(contained(frame, cell_size, 5), (index * cell_size[0], 0))
    return output


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
    label_h, gap = 32, 12
    rows = (len(images) + columns - 1) // columns
    sheet = checkerboard((columns * (thumb[0] + gap) + gap, rows * (thumb[1] + label_h + gap) + gap))
    draw = ImageDraw.Draw(sheet)
    text_font = font()
    for index, (job, image) in enumerate(images):
        col, row = index % columns, index // columns
        x, y = gap + col * (thumb[0] + gap), gap + row * (thumb[1] + label_h + gap)
        preview = image.convert("RGBA")
        preview.thumbnail(thumb, Image.Resampling.NEAREST)
        px, py = x + (thumb[0] - preview.width) // 2, y + (thumb[1] - preview.height) // 2
        sheet.paste(preview, (px, py), preview)
        draw.text((x, y + thumb[1] + 2), f"{job['number']} {job['id'][:22]}", fill=(242, 244, 248), font=text_font)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


def main() -> None:
    jobs = parse_jobs()
    for directory in (READY / "icons", READY / "ui", READY / "cards", READY / "fx", READY / "maps", READY / "npcs", READY / "mounts", QA):
        directory.mkdir(parents=True, exist_ok=True)
    groups: dict[str, list[tuple[dict, Image.Image]]] = {}
    manifest = []
    for job in jobs:
        source_path = SOURCE / f"{job['number']:03d}_{job['id']}.png"
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        ready = sheet_asset(source_path, job) if job["kind"] == "fx" else static_asset(source_path, job)
        if job["kind"] in {"ui", "brand"}:
            folder = "ui"
        elif job["kind"] in {"card", "frame"}:
            folder = "cards"
        elif job["kind"] in {"mount"}:
            folder = "mounts"
        elif job["kind"] in {"npc"}:
            folder = "npcs"
        elif job["kind"] == "fx":
            folder = "fx"
        elif job["kind"] in {"node", "skill", "small_icon", "badge", "slot"}:
            folder = "icons"
        else:
            folder = "maps"
        relative = Path("ready") / folder / f"{job['id']}.png"
        target = PACKAGE / relative
        ready.save(target)
        record = dict(job)
        record.update({"source": str(Path("source") / source_path.name).replace("\\", "/"), "ready": str(relative).replace("\\", "/"), "status": "ready"})
        manifest.append(record)
        groups.setdefault(job["kind"], []).append((job, ready))

    (PACKAGE / "jobs.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    make_contact_sheet(sum((groups.get(k, []) for k in ("skill", "node", "small_icon", "badge", "slot")), []), QA / "contact_sheet_icons.png", 10, (96, 96))
    make_contact_sheet(groups.get("fx", []), QA / "contact_sheet_fx.png", 4, (360, 150))
    make_contact_sheet(sum((groups.get(k, []) for k in ("frame", "card")), []), QA / "contact_sheet_cards.png", 8, (120, 150))
    make_contact_sheet(groups.get("ui", []) + groups.get("brand", []), QA / "contact_sheet_ui.png", 5, (220, 180))
    make_contact_sheet(groups.get("mount", []), QA / "contact_sheet_mounts.png", 6, (160, 160))
    make_contact_sheet(groups.get("npc", []), QA / "contact_sheet_npcs.png", 3, (180, 180))

    readme = "# 201–333 图片素材\n\n"
    readme += "按 `docs/2026-09-15-图片提示词总库.md` 的 201–333 号生成，共 133 张；前 001–200 不重复生成。\n\n"
    readme += "## 可直接使用目录\n\n"
    readme += "- `ready/icons/`：技能、节点、状态、货币、宝石、物品、槽位与段位图标，按提示词规格输出。\n"
    readme += "- `ready/ui/`：面板、卡池界面、横幅、启动图与品牌图，按提示词精确画布输出。\n"
    readme += "- `ready/cards/`：卡框/卡背；卡框中心已清空为透明，便于叠加卡面。\n"
    readme += "- `ready/fx/`：抽卡、坐骑召唤等横向等宽帧条，按 `jobs.json` 的 `frames` 与单帧尺寸切图。\n"
    readme += "- `ready/maps/`：地图节点徽记。\n"
    readme += "- `ready/npcs/`：透明半身 NPC；`ready/mounts/`：透明侧向坐骑，鞍位平坦并保留接地锚点。\n"
    readme += "- `source/`：原始生成母稿；`qa/`：分类验收总览。\n\n"
    readme += "所有 ready PNG 均已硬化 alpha、按提示词精确画布化；透明素材四边保留安全边，UI/卡背类保持不透明。Godot 导入时使用 Nearest、关闭 mipmaps。\n"
    (PACKAGE / "README.md").write_text(readme, encoding="utf-8")
    print(json.dumps({"generated": len(manifest), "ready": len(manifest), "package": str(PACKAGE), "qa": str(QA)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
