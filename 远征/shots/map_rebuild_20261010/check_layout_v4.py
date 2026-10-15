# 昭元边城 v4 / 枫林古道 v3 的可达性检查：用与 MapScene 相同的碰撞口径做网格 BFS。
# 口径：建筑取 _Building 的底座矩形（宽 0.8w、y 位于 0.2h..0.5h）；玩家半径 12；河道阻挡，石桥段可走；修桥木栏按状态开合。
import json
import sys
from collections import deque

CFG = json.load(open(sys.argv[1], encoding='utf-8'))['maps']
CITY = json.load(open(sys.argv[2], encoding='utf-8'))
R = 12.0
STEP = 4.0
failures = []


def check(ok, text):
    if not ok:
        failures.append(text)
    print(('PASS ' if ok else 'FAIL ') + text)


def cut(spans, a, b):
    out = []
    for s0, s1 in spans:
        if b <= s0 or a >= s1:
            out.append((s0, s1))
            continue
        if a > s0:
            out.append((s0, a))
        if b < s1:
            out.append((b, s1))
    return out


def town_blocks(cfg):
    passable = set(cfg.get('city_passable', []))
    sizes = {b['id']: b['size'] for b in CITY['buildings']}
    out = []
    for bid, at in cfg['city_building_positions'].items():
        if bid in passable:
            continue
        w = sizes[bid][0] * 48.0
        h = sizes[bid][1] * 48.0
        out.append((at[0] - w * .4, at[1] + h * .2, at[0] + w * .4, at[1] + h * .5, bid))
    return out


def maple_blocks(cfg, open_w, open_e, lanes_closed):
    river = cfg['river']
    y = float(river['y'])
    spans = [(0.0, float(river['crossing'][0])), (float(river['crossing'][1]), float(cfg['map_cols']) * 48.0)]
    if open_w:
        spans = cut(spans, 355.0, 405.0)
    if open_e:
        spans = cut(spans, 595.0, 645.0)
    out = [(s0, y - 22.0, s1, y + 22.0, 'river') for s0, s1 in spans]
    if lanes_closed:
        out += [(320.0, 548.0, 440.0, 608.0, 'lane_w'), (560.0, 548.0, 680.0, 608.0, 'lane_e')]
    return out


def grid(W, H, blocks):
    nx, ny = int(W // STEP), int(H // STEP)
    walk = [[True] * nx for _ in range(ny)]
    for gy in range(ny):
        for gx in range(nx):
            x = gx * STEP + STEP / 2
            y = gy * STEP + STEP / 2
            ok = R <= x <= W - R and R <= y <= H - R
            if ok:
                for x0, y0, x1, y1, _ in blocks:
                    if x0 - R < x < x1 + R and y0 - R < y < y1 + R:
                        ok = False
                        break
            walk[gy][gx] = ok
    return walk


def reach(walk, start):
    ny, nx = len(walk), len(walk[0])
    sx, sy = int(start[0] // STEP), int(start[1] // STEP)
    seen = set()
    if not walk[sy][sx]:
        # 起点落在阻挡里时，取最近的可走格作为起点（与读档吸附口径一致）。
        best = None
        for gy in range(ny):
            for gx in range(nx):
                if walk[gy][gx]:
                    d = (gx - sx) ** 2 + (gy - sy) ** 2
                    if best is None or d < best[0]:
                        best = (d, gx, gy)
        sx, sy = best[1], best[2]
    q = deque([(sx, sy)])
    seen.add((sx, sy))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx2, ny2 = x + dx, y + dy
            if 0 <= nx2 < nx and 0 <= ny2 < ny and walk[ny2][nx2] and (nx2, ny2) not in seen:
                seen.add((nx2, ny2))
                q.append((nx2, ny2))
    return seen


def cell_centers(cells):
    return [(gx * STEP + STEP / 2, gy * STEP + STEP / 2) for gx, gy in cells]


def near_reachable(points, reached, at, radius):
    for x, y in points:
        if (x - at[0]) ** 2 + (y - at[1]) ** 2 <= radius * radius:
            return True
    return False


def exit_rect(row):
    sx, sy = row['at'][0], row['at'][1]
    if sy < 180:
        sy = 240
    return (sx - 52, sy - 84, sx - 52 + 104, sy - 84 + 88)


def rect_hits(points, r):
    return any(r[0] <= x <= r[0] + r[2] and r[1] <= y <= r[1] + r[3] for x, y in points)


def run_map(map_id, blocks, label):
    cfg = CFG[map_id]
    W = float(cfg['map_cols']) * 48.0
    H = float(cfg['map_rows']) * 48.0
    walk = grid(W, H, blocks)
    spawn = cfg['spawn']
    reached = reach(walk, spawn)
    pts = cell_centers(reached)
    check(len(reached) > 0 and walk[int(spawn[1] // STEP)][int(spawn[0] // STEP)], f'{label} 出生点可走')
    for name, at in cfg.get('spawn_points', {}).items():
        check(near_reachable(pts, reached, at, 2 * STEP), f'{label} 到达点 {name} 可达')
    for row in cfg.get('exits', []):
        rx, ry, rw, rh = exit_rect(row)
        hit = any(rx <= x <= rx + rw and ry <= y <= ry + rh for x, y in pts)
        check(hit, f'{label} 出口 {row["id"]} 触发区可达')
    for eid, row in cfg.get('entities', {}).items():
        check(near_reachable(pts, reached, row['at'], 40.0), f'{label} 实体 {eid} 40px 内可交互可达')
        at = row['at']
        inside = [b[4] for b in blocks if b[0] < at[0] < b[2] and b[1] < at[1] < b[3]]
        check(not inside, f'{label} 实体 {eid} 不落在阻挡内' + (f' ({inside})' if inside else ''))
    return reached, pts


def check_npcs_and_buildings(cfg, blocks):
    for name, at in cfg.get('city_npc_positions', {}).items():
        inside = [b[4] for b in blocks if b[0] <= at[0] <= b[2] and b[1] <= at[1] <= b[3]]
        check(not inside, f'NPC {name} 不站在建筑底座内' + (f' ({inside})' if inside else ''))
    for i, a in enumerate(blocks):
        for b in blocks[i + 1:]:
            overlap = a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]
            check(not overlap, f'建筑底座不重叠 {a[4]} / {b[4]}')
    for name, at in cfg.get('city_building_positions', {}).items():
        check(0 <= at[0] <= 960 and 0 <= at[1] <= 1248, f'建筑 {name} 位于地图内')


if __name__ == '__main__':
    lor = CFG['lorin_wilds']
    blocks = town_blocks(lor)
    check_npcs_and_buildings(lor, blocks)
    run_map('lorin_wilds', blocks, '边城')
    mp = CFG['maple_road']
    # 河道状态：未修桥（只有石桥段可走）、西侧修复、东侧修复，并检查修桥后木栏收起时的开口。
    for label, ow, oe, lanes in [('枫林·未修桥', False, False, False), ('枫林·西侧修复', True, False, True),
                                 ('枫林·东侧修复', False, True, True)]:
        blocks_m = maple_blocks(mp, ow, oe, lanes)
        run_map('maple_road', blocks_m, label)
    print('CHECK_DONE failures=%d' % len(failures))
    sys.exit(1 if failures else 0)
