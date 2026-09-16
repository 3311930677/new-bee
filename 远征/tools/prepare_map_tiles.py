"""Make 48px tileable copies of the 24 base ground tiles from the first 100 assets."""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "image" / "map" / "tileset" / "base"
QA = ROOT / "image" / "map" / "tileset" / "qa"
SOURCES = (ROOT / "image" / "generated_001_050" / "source",
           ROOT / "image" / "generated_001_100" / "source")
TILES = [
    "001_tile_forest_1.png", "002_tile_forest_2.png", "003_tile_forest_3.png",
    "004_tile_snow_1.png", "005_tile_snow_2.png", "006_tile_snow_3.png",
    "007_tile_volcano_1.png", "008_tile_volcano_2.png", "009_tile_volcano_3.png",
    "010_tile_tomb_1.png", "011_tile_tomb_2.png", "012_tile_tomb_3.png",
    "013_tile_desert_1.png", "014_tile_desert_2.png", "015_tile_desert_3.png",
    "016_tile_glacier_1.png", "017_tile_glacier_2.png", "018_tile_glacier_3.png",
    "019_tile_abyss_1.png", "020_tile_abyss_2.png", "021_tile_abyss_3.png",
    "022_tile_castle_1.png", "023_tile_castle_2.png", "024_tile_castle_3.png",
]


def make_seamless(tile: Image.Image, blend: int = 6) -> Image.Image:
    """Keep the center texture and make opposite border pixels meet exactly."""
    px = tile.load()
    width, height = tile.size
    for distance in range(blend):
        weight = distance / max(1, blend - 1)
        for y in range(height):
            left, right = px[distance, y], px[width - 1 - distance, y]
            average = tuple(round((left[c] + right[c]) / 2) for c in range(3))
            target = tuple(round(average[c] * (1 - weight) + left[c] * weight) for c in range(3))
            target_r = tuple(round(average[c] * (1 - weight) + right[c] * weight) for c in range(3))
            px[distance, y] = (*target, 255)
            px[width - 1 - distance, y] = (*target_r, 255)
    for distance in range(blend):
        weight = distance / max(1, blend - 1)
        for x in range(width):
            top, bottom = px[x, distance], px[x, height - 1 - distance]
            average = tuple(round((top[c] + bottom[c]) / 2) for c in range(3))
            target = tuple(round(average[c] * (1 - weight) + top[c] * weight) for c in range(3))
            target_b = tuple(round(average[c] * (1 - weight) + bottom[c] * weight) for c in range(3))
            px[x, distance] = (*target, 255)
            px[x, height - 1 - distance] = (*target_b, 255)
    return tile


def edge_mismatch(tile: Image.Image) -> tuple[int, int]:
    px = tile.load()
    return (sum(px[0, y] != px[tile.width - 1, y] for y in range(tile.height)),
            sum(px[x, 0] != px[x, tile.height - 1] for x in range(tile.width)))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    manifest = {"size": [48, 48], "source_count": 24, "edge_rule": "left=right and top=bottom", "tiles": []}
    qa_names = {"010_tile_tomb_1.png", "011_tile_tomb_2.png", "012_tile_tomb_3.png"}
    qa = Image.new("RGB", (48 * 9, 48 * 3), (20, 22, 24))
    draw = ImageDraw.Draw(qa)
    qa_col = 0
    for name in TILES:
        source = next((directory / name for directory in SOURCES if (directory / name).exists()), None)
        if source is None:
            raise FileNotFoundError(name)
        tile = Image.open(source).convert("RGB").resize((48, 48), Image.Resampling.NEAREST).convert("RGBA")
        tile = make_seamless(tile)
        output = OUT / name
        tile.save(output)
        lr, tb = edge_mismatch(tile)
        manifest["tiles"].append({"name": name, "output": str(output.relative_to(ROOT)).replace("\\", "/"),
                                  "source": str(source.relative_to(ROOT)).replace("\\", "/"),
                                  "left_right_mismatch": lr, "top_bottom_mismatch": tb})
        if name in qa_names:
            for row in range(3):
                for col in range(3):
                    qa.paste(tile.convert("RGB"), (qa_col * 144 + col * 48, row * 48))
            draw.text((qa_col * 144 + 3, 3), name[:3], fill="white")
            qa_col += 1
    qa.save(QA / "tomb_3x3_preview.png")
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"MAP_TILES_OK: {len(TILES)} normalized 48x48 copies; all opposite edges match exactly")


if __name__ == "__main__":
    main()
