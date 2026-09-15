#!/usr/bin/env python3
"""Clean AI-cutout sprite sheets: hard alpha, pocket removal, edge decontamination.

Pixel-art cutout pipeline (per 远征/docs/开发规范.md §4.2):
small pixel sprites must keep hard dark-brown outlines, so alpha is binarized
and the light-gray checkerboard halo is re-colored from interior neighbors
instead of being softened.

Usage: python tools/clean_sprite_edges.py <file.png> [<file.png> ...]
"""

from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

from PIL import Image

ALPHA_KEEP = 128        # alpha >= keep -> opaque; below -> transparent
NEUTRAL_MIN = 150       # light gray checkerboard tone floor
NEUTRAL_RANGE = 14      # channel spread tolerated for "neutral gray"


def _is_neutral(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    return min(r, g, b) >= NEUTRAL_MIN and max(r, g, b) - min(r, g, b) <= NEUTRAL_RANGE


def _neighbors(x: int, y: int, w: int, h: int):
    if x:
        yield x - 1, y
    if x + 1 < w:
        yield x + 1, y
    if y:
        yield x, y - 1
    if y + 1 < h:
        yield x, y + 1


def binarize_alpha(px, w: int, h: int) -> None:
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= ALPHA_KEEP else 0)


def flood_neutral_from_transparent(px, w: int, h: int) -> int:
    """Remove light-neutral pixels connected to transparent areas.

    Phase 1 seeds from the image border; phase 2 repeats from every cleared
    pixel so checkerboard pockets enclosed by the character are also caught
    once any gap opens. Iterates to a fixed point.
    """
    cleared = 0
    queue: deque[tuple[int, int]] = deque()
    seen = bytearray(w * h)

    def try_enqueue(x: int, y: int) -> None:
        i = y * w + x
        if seen[i]:
            return
        r, g, b, a = px[x, y]
        if a == 0:
            seen[i] = 1
            queue.append((x, y))
        elif _is_neutral((r, g, b)):
            seen[i] = 1
            queue.append((x, y))

    for x in range(w):
        try_enqueue(x, 0)
        try_enqueue(x, h - 1)
    for y in range(h):
        try_enqueue(0, y)
        try_enqueue(w - 1, y)

    while queue:
        x, y = queue.popleft()
        r, g, b, a = px[x, y]
        if a != 0:
            px[x, y] = (r, g, b, 0)
            cleared += 1
        for nx, ny in _neighbors(x, y, w, h):
            try_enqueue(nx, ny)
    return cleared


def erode_isolated_neutral(px, w: int, h: int) -> int:
    """Remove neutral pixels whose opaque neighborhood is mostly transparent/
    neutral — leftover checker specks fully enclosed by the sprite."""
    removed = 0
    changed = True
    while changed:
        changed = False
        kill: list[tuple[int, int]] = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0 or not _is_neutral((r, g, b)):
                    continue
                solid = 0
                for nx, ny in _neighbors(x, y, w, h):
                    nr, ng, nb, na = px[nx, ny]
                    if na != 0 and not _is_neutral((nr, ng, nb)):
                        solid += 1
                if solid <= 1:      # no real sprite contact -> speck
                    kill.append((x, y))
        for x, y in kill:
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)
            removed += 1
            changed = True
    return removed


def decontaminate_edges(px, w: int, h: int) -> int:
    """Re-color opaque edge pixels (touching transparency) from their
    non-edge opaque neighbors — kills the white/gray halo without eating
    legitimately light sprite parts (their neighbors share the same color)."""
    edge: list[tuple[int, int]] = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            if any(px[nx, ny][3] == 0 for nx, ny in _neighbors(x, y, w, h)):
                edge.append((x, y))
    edge_set = set(edge)
    fixed = 0
    for x, y in edge:
        r, g, b, a = px[x, y]
        acc = [0, 0, 0]
        n = 0
        for nx, ny in _neighbors(x, y, w, h):
            if (nx, ny) in edge_set or px[nx, ny][3] == 0:
                continue
            nr, ng, nb, _ = px[nx, ny]
            acc[0] += nr
            acc[1] += ng
            acc[2] += nb
            n += 1
        if n == 0:
            continue
        interior = (acc[0] // n, acc[1] // n, acc[2] // n)
        # only repaint when the edge pixel is much lighter than the interior
        # (halo), keep it when it is genuinely light sprite content
        if sum((r, g, b)) - sum(interior) > 90:
            px[x, y] = (interior[0], interior[1], interior[2], 255)
            fixed += 1
    return fixed


def clean(path: Path) -> None:
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    binarize_alpha(px, w, h)
    flooded = flood_neutral_from_transparent(px, w, h)
    eroded = erode_isolated_neutral(px, w, h)
    repainted = decontaminate_edges(px, w, h)
    im.save(path)
    print(f"{path.name}: flood={flooded} pocket={eroded} halo_repaint={repainted}")


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for arg in sys.argv[1:]:
        clean(Path(arg))


if __name__ == "__main__":
    main()
