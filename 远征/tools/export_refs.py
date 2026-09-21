"""Export embedded PNG atlases from the unpacked original game as local references.

The original .pwd/.dl containers generally hold one indexed-color PNG atlas after
a short binary header. Some .aef files also embed PNG data, while other .aef
files are animation/assembly records and contain no PNG. This script deliberately
calls the extracted images *atlases*: animation parts must still be composed from
the corresponding AEF records before they can be treated as finished frames.

Copyright note: output is for local visual reference only and must not be shipped
with the remake.
"""

from __future__ import annotations

import argparse
import json
import struct
from io import BytesIO
from pathlib import Path

from PIL import Image


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_ranges(data: bytes) -> list[tuple[int, int]]:
    """Return exact [start, end) ranges for every valid embedded PNG."""
    ranges: list[tuple[int, int]] = []
    search_from = 0
    while True:
        start = data.find(PNG_SIGNATURE, search_from)
        if start < 0:
            break
        cursor = start + len(PNG_SIGNATURE)
        try:
            while cursor + 12 <= len(data):
                length = struct.unpack_from(">I", data, cursor)[0]
                chunk_type = data[cursor + 4 : cursor + 8]
                cursor += 12 + length
                if cursor > len(data):
                    raise ValueError("PNG chunk exceeds container")
                if chunk_type == b"IEND":
                    ranges.append((start, cursor))
                    search_from = cursor
                    break
            else:
                raise ValueError("PNG has no IEND chunk")
        except ValueError:
            search_from = start + len(PNG_SIGNATURE)
    return ranges


def visible_color_count(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    colors = {pixel for pixel in rgba.get_flattened_data() if pixel[3] != 0}
    return len(colors)


def export_container(
    source: Path,
    source_root: Path,
    native_root: Path,
    zoom_root: Path,
    zoom: int,
) -> list[dict[str, object]]:
    data = source.read_bytes()
    relative = source.relative_to(source_root)
    records: list[dict[str, object]] = []
    for index, (start, end) in enumerate(png_ranges(data)):
        image = Image.open(BytesIO(data[start:end])).convert("RGBA")
        stem = relative.name.replace(".", "_")
        relative_dir = relative.parent
        native_path = native_root / relative_dir / f"{stem}__atlas{index:03d}.png"
        zoom_path = zoom_root / relative_dir / f"{stem}__atlas{index:03d}_x{zoom}.png"
        native_path.parent.mkdir(parents=True, exist_ok=True)
        zoom_path.parent.mkdir(parents=True, exist_ok=True)
        image.save(native_path)
        image.resize(
            (image.width * zoom, image.height * zoom), Image.Resampling.NEAREST
        ).save(zoom_path)
        alpha = image.getchannel("A")
        records.append(
            {
                "source": relative.as_posix(),
                "atlas_index": index,
                "container_offset": start,
                "native": native_path.relative_to(native_root.parent).as_posix(),
                "zoom": zoom_path.relative_to(native_root.parent).as_posix(),
                "width": image.width,
                "height": image.height,
                "visible_colors": visible_color_count(image),
                "alpha_levels": len(set(alpha.get_flattened_data())),
            }
        )
    return records


def main() -> None:
    script = Path(__file__).resolve()
    project_root = script.parents[1]
    workspace_root = project_root.parent
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        type=Path,
        default=workspace_root / "apk_xajh" / "xaqd_tree" / "gwy" / "wm1",
    )
    parser.add_argument(
        "--output", type=Path, default=project_root / "assets_regen" / "refs"
    )
    parser.add_argument("--zoom", type=int, default=8)
    args = parser.parse_args()

    source_root = args.source.resolve()
    output_root = args.output.resolve()
    native_root = output_root / "native"
    zoom_root = output_root / "zoom"
    records: list[dict[str, object]] = []
    scanned = 0
    for source in sorted(path for path in source_root.rglob("*") if path.is_file()):
        if source.suffix.lower() not in {".pwd", ".dl", ".aef"}:
            continue
        scanned += 1
        records.extend(
            export_container(source, source_root, native_root, zoom_root, args.zoom)
        )

    output_root.mkdir(parents=True, exist_ok=True)
    manifest = {
        "source_root": str(source_root),
        "local_reference_only": True,
        "note": (
            "Extracted PNGs are atlases or standalone images, not guaranteed "
            "animation frames. Compose AEF records before frame-level use."
        ),
        "containers_scanned": scanned,
        "atlases_exported": len(records),
        "zoom": args.zoom,
        "items": records,
    }
    (output_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(
        f"REF_EXPORT_OK: scanned={scanned} atlases={len(records)} "
        f"output={output_root}"
    )


if __name__ == "__main__":
    main()
