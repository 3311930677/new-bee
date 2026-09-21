"""原版 UI/地图 PNG -> AI 参考图库 assets_regen/refs/ui（仅本地参照，不进游戏 assets）。

与 export_refs.py 的分工：
  * export_refs.py 处理 .pwd/.dl/.aef 容器里的内嵌 PNG（精灵图集）
  * 本脚本处理原生 PNG（ui/ map/ pk/），统一 nearest 放大 2x 便于 AI 看图

输出被 .gitignore 排除（assets_regen/refs/），不会进仓库。
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def export_dir(src_root: Path, out_root: Path, zoom: int) -> tuple[list, list]:
    records: list[dict[str, object]] = []
    skipped: list[str] = []
    for sub in ("ui", "map", "pk"):
        base = src_root / sub
        if not base.is_dir():
            continue
        for src in sorted(p for p in base.rglob("*.png") if p.is_file()):
            # 解包树里混着非 PNG 载荷（加密/自定义格式）：跳过并登记，别让整批导出中断
            try:
                img = Image.open(src)
                img.load()
            except Exception:
                skipped.append(src.relative_to(src_root).as_posix())
                continue
            if img.mode == "P":
                img = img.convert("RGBA")
            big = img.resize((img.width * zoom, img.height * zoom), Image.Resampling.NEAREST)
            out = out_root / src.relative_to(src_root)
            out.parent.mkdir(parents=True, exist_ok=True)
            big.save(out)
            records.append(
                {
                    "source": src.relative_to(src_root).as_posix(),
                    "native": f"{img.width}x{img.height}",
                    "zoom": out.relative_to(out_root).as_posix(),
                }
            )
    return records, skipped


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
    parser.add_argument("--output", type=Path, default=project_root / "assets_regen" / "refs" / "ui")
    parser.add_argument("--zoom", type=int, default=2)
    args = parser.parse_args()

    src_root = args.source.resolve()
    out_root = args.output.resolve()
    if not src_root.is_dir():
        print(f"REF_UI_SKIP: 源目录不存在 {src_root}")
        return
    out_root.mkdir(parents=True, exist_ok=True)
    records, skipped = export_dir(src_root, out_root, args.zoom)
    (out_root / "manifest.json").write_text(
        json.dumps(
            {
                "source_root": str(src_root),
                "local_reference_only": True,
                "zoom": args.zoom,
                "count": len(records),
                "skipped_non_png": skipped,
                "items": records,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"REF_UI_EXPORT_OK: count={len(records)} output={out_root}")


if __name__ == "__main__":
    main()
