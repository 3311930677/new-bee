# 为昭元边城 v4 的 NPC 与访客求解不冲突的站位：
# 1) 离任何建筑矩形边缘 >= T（T=78 = NPC_R 52 + BUILD_R 26，使站在 NPC 旁边时不会触发建筑）；
# 2) 彼此相距 >= 72；3) 不压中轴街道（|x-480| >= 52）与北门出口触发区；4) 离出生点与到达点有余量。
import json
import math
import sys

CFG_PATH = sys.argv[1]
CITY_PATH = sys.argv[2]
d = json.load(open(CFG_PATH, encoding='utf-8'))['maps']['lorin_wilds']
city = json.load(open(CITY_PATH, encoding='utf-8'))
sizes = {b['id']: b['size'] for b in city['buildings']}
bpos = {k: tuple(v) for k, v in d['city_building_positions'].items()}
rects = {k: (v[0] - sizes[k][0] * 24.0, v[1] - sizes[k][1] * 24.0,
             v[0] + sizes[k][0] * 24.0, v[1] + sizes[k][1] * 24.0) for k, v in bpos.items()}
EXIT = (428, 136, 532, 224)
SPAWN = (480, 860)
FROM_MAPLE = (480, 300)


def edge(p, r):
    dx = max(r[0] - p[0], 0.0, p[0] - r[2])
    dy = max(r[1] - p[1], 0.0, p[1] - r[3])
    return math.hypot(dx, dy)


def ok(p, placed, T):
    x, y = p
    if not (110 <= x <= 850 and 150 <= y <= 1180):
        return False
    if abs(x - 480) < 52:
        return False
    if EXIT[0] - 20 <= x <= EXIT[2] + 20 and EXIT[1] - 20 <= y <= EXIT[3] + 20:
        return False
    if math.dist(p, SPAWN) < 110 or math.dist(p, FROM_MAPLE) < 60:
        return False
    for r in rects.values():
        if edge(p, r) < T:
            return False
    for q in placed:
        if math.dist(p, q) < 72:
            return False
    return True


# 目标站位：贴近所属建筑、不压街道。顺序按约束紧张程度排列。
homes = [
    ('npc_steward', (380, 900)),
    ('npc_scribe', (290, 1110)),
    ('npc_guard', (330, 190)),
    ('npc_stablemaster', (120, 330)),
    ('npc_mentor', (560, 400)),
    ('npc_smith', (590, 600)),
    ('npc_keeper', (600, 800)),
    ('npc_warden', (600, 650)),
    ('npc_child', (420, 700)),
]
guests_home = [(400, 660), (560, 660)]


def search(home, placed, T):
    best = None
    for dy in range(-260, 261, 6):
        for dx in range(-260, 261, 6):
            p = (home[0] + dx, home[1] + dy)
            if not ok(p, placed, T):
                continue
            dist = math.hypot(dx, dy)
            if best is None or dist < best[0]:
                best = (dist, p)
    return best


def solve(T):
    placed = []
    out = {}
    for npc, home in homes:
        hit = search(home, placed, T)
        if hit is None:
            return None, npc
        out[npc] = [int(round(hit[1][0] / 2.0) * 2), int(round(hit[1][1] / 2.0) * 2)]
        placed.append(out[npc])
    for i, home in enumerate(guests_home):
        hit = search(home, placed, T)
        if hit is None:
            return None, 'guest%d' % i
        out['__guest%d' % i] = [int(round(hit[1][0] / 2.0) * 2), int(round(hit[1][1] / 2.0) * 2)]
        placed.append(out['__guest%d' % i])
    return out, None


for T in (78, 58):
    out, failed = solve(T)
    if out is not None:
        print('SOLVED T=%d' % T)
        print(json.dumps(out, ensure_ascii=False))
        break
    print('infeasible at T=%d: %s' % (T, failed))
else:
    sys.exit(1)
