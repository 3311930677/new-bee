"""Derive quieter battle backdrops from the shipped regional illustrations.

Keeps the skyline and landmarks intact, then suppresses high-frequency ground
patches where combatants stand. Source images are never modified.
"""
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "image" / "generated_001_100" / "source"
OUTPUT = ROOT / "image" / "battle" / "art_v2"
THEMES = {
    "snow": "071_bg_battle_snowfield.png",
    "volcano": "072_bg_battle_volcano.png",
    "tomb": "073_bg_battle_tomb.png",
    "desert": "074_bg_battle_desert.png",
    "glacier": "075_bg_battle_glacier.png",
    "abyss": "076_bg_battle_abyss.png",
    "castle": "077_bg_battle_castle.png",
}


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def refine(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGB")
    width, height = image.size

    # Two spatial scales remove random tiles without flattening broad terrain
    # shading. The lower half is deliberately quieter than the distant scenery.
    median = image.filter(ImageFilter.MedianFilter(9))
    soft = median.filter(ImageFilter.GaussianBlur(radius=5.0))
    broad = image.filter(ImageFilter.GaussianBlur(radius=22.0))
    ground = Image.blend(soft, broad, 0.32)
    ground = ImageEnhance.Color(ground).enhance(0.90)
    ground = ImageEnhance.Contrast(ground).enhance(0.91)

    mask = Image.new("L", (width, height))
    mask.putdata([
        round(238 * smoothstep(0.34, 0.55, y / max(1, height - 1)))
        for y in range(height)
        for _ in range(width)
    ])
    result = Image.composite(ground, image, mask)

    # A very mild, deterministic centre shade separates silhouettes and health
    # bars from the ground without adding texture or hiding the regional palette.
    shade = Image.new("RGB", (width, height), (22, 17, 16))
    shade_mask = Image.new("L", (width, height))
    shade_mask.putdata([
        round(15 * smoothstep(0.40, 0.64, y / max(1, height - 1)))
        for y in range(height)
        for _ in range(width)
    ])
    result = Image.composite(shade, result, shade_mask)
    result.save(destination, optimize=True)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for theme, filename in THEMES.items():
        destination = OUTPUT / f"{theme}_clearing.png"
        refine(SOURCE / filename, destination)
        print(f"REFINED {theme}: {destination.name}")


if __name__ == "__main__":
    main()
