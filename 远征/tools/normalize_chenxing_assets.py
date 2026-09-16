"""Normalize the revised Chenxing idle strip and icon into project-size PNGs."""
from __future__ import annotations

from pathlib import Path
from PIL import Image

from normalize_sprite_sheet import remove_connected_checkerboard

ROOT = Path(__file__).resolve().parents[1]
ROLE = ROOT / "image" / "role" / "fz"
SOURCE = ROLE / "source"


def pack_idle(source: Path, output: Path) -> None:
    image = remove_connected_checkerboard(Image.open(source), neutral_floor=100)
    frames = []
    for col in range(4):
        cell = image.crop((round(col * image.width / 4), 0,
                           round((col + 1) * image.width / 4), image.height))
        bbox = cell.getchannel("A").getbbox()
        if bbox is None:
            raise ValueError(f"empty idle frame {col}")
        frames.append(cell.crop(bbox))
    scale = min(112 / max(frame.height for frame in frames),
                116 / max(frame.width for frame in frames))
    sheet = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
    for col, frame in enumerate(frames):
        size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
        frame = frame.resize(size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        canvas.alpha_composite(frame, ((128 - frame.width) // 2, 120 - frame.height))
        sheet.alpha_composite(canvas, (col * 128, 0))
    sheet.save(output)


def pack_icon(source: Path, output: Path) -> None:
    image = remove_connected_checkerboard(Image.open(source), neutral_floor=100)
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("empty Chenxing icon")
    content = image.crop(bbox)
    scale = min(112 / content.height, 112 / content.width)
    content = content.resize((round(content.width * scale), round(content.height * scale)), Image.Resampling.NEAREST)
    icon = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    icon.alpha_composite(content, ((128 - content.width) // 2, (128 - content.height) // 2))
    icon.save(output)


if __name__ == "__main__":
    pack_idle(SOURCE / "chenxing_idle_reference_v2.png", ROLE / "chenxing_idle.png")
    pack_icon(SOURCE / "chenxing_icon_reference_v2.png", ROLE / "chenxing_icon.png")
    print("CHENXING_ASSETS_OK: idle 4x128x128 and icon 128x128")
