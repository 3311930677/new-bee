# 定点改写 data/main_world_maps.json 中两张图的布局字段；其余文本保持原样，避免整文件重排。
import json
import re
import sys
from pathlib import Path

NUM = re.compile(r'-?[0-9][0-9.eE+-]*|true|false|null')
BACKSLASH = chr(92)


def skip_ws(t, k):
    while t[k] in ' \t\r\n':
        k += 1
    return k


def value_end(t, k):
    c = t[k]
    if c in '[{':
        depth = 0
        in_str = False
        while True:
            ch = t[k]
            if in_str:
                if ch == BACKSLASH:
                    k += 2
                    continue
                if ch == '"':
                    in_str = False
            elif ch == '"':
                in_str = True
            elif ch in '[{':
                depth += 1
            elif ch in ']}':
                depth -= 1
                if depth == 0:
                    return k + 1
            k += 1
    if c == '"':
        k += 1
        while t[k] != '"':
            k += 2 if t[k] == BACKSLASH else 1
        return k + 1
    return NUM.match(t, k).end()


def obj_spans(t, k):
    out = {}
    k = skip_ws(t, k + 1)
    while True:
        while t[k] == ',':
            k = skip_ws(t, k + 1)
        if t[k] == '}':
            return out
        key_pos = k
        ke = t.index('"', k + 1)
        key = t[k + 1:ke]
        k = skip_ws(t, ke + 1)
        assert t[k] == ':', key
        k = skip_ws(t, k + 1)
        ve = value_end(t, k)
        out[key] = (key_pos, k, ve)
        k = skip_ws(t, ve)


def arr_spans(t, k):
    out = []
    k = skip_ws(t, k + 1)
    while True:
        while t[k] == ',':
            k = skip_ws(t, k + 1)
        if t[k] == ']':
            return out
        ve = value_end(t, k)
        out.append((k, ve))
        k = skip_ws(t, ve)


def locate(t, path):
    pos = skip_ws(t, 0)
    key_pos = None
    for step in path:
        if isinstance(step, int):
            pos, _ = arr_spans(t, pos)[step]
            key_pos = None
        else:
            key_pos, pos, _ = obj_spans(t, pos)[step]
    return pos, value_end(t, pos), key_pos


def line_indent(t, p):
    ls = t.rfind('\n', 0, p) + 1
    return t[ls:p]


def set_value(t, path, new):
    vs, ve, _ = locate(t, path)
    return t[:vs] + new + t[ve:]


def set_map(t, path, d):
    vs, ve, kp = locate(t, path)
    indent = line_indent(t, kp)
    inner = indent + '  '
    items = list(d.items())
    lines = ['{']
    for i, (k, v) in enumerate(items):
        comma = ',' if i < len(items) - 1 else ''
        lines.append(f'{inner}"{k}": {json.dumps(v)}{comma}')
    lines.append(indent + '}')
    return t[:vs] + '\n'.join(lines) + t[ve:]


def insert_before(t, path_obj, before_key, key, new_json):
    pos, _, _ = locate(t, path_obj)
    kp = obj_spans(t, pos)[before_key][0]
    indent = line_indent(t, kp)
    return t[:kp] + f'"{key}": {new_json},\n{indent}' + t[kp:]


path = Path(sys.argv[1])
t = path.read_text(encoding='utf-8')
LOR = ['maps', 'lorin_wilds']
MAP = ['maps', 'maple_road']

# ---- 昭元边城：layout v4，城门北移，议事厅居南端，建筑与NPC按工地/功能重排 ----
t = set_value(t, LOR + ['layout_version'], '4')
t = set_value(t, LOR + ['spawn'], '[480, 860]')
t = set_value(t, LOR + ['spawn_points', 'from_maple_road'], '[480, 300]')
t = set_value(t, LOR + ['exits', 0, 'at'], '[480, 220]')
t = set_value(t, LOR + ['exit'], '[480, 220]')
t = set_map(t, LOR + ['city_building_positions'], {
    'hall': [480, 1060], 'gate': [480, 120], 'archive': [290, 1000], 'kennel': [706, 780],
    'barracks': [670, 300], 'storehouse': [300, 500], 'shrine': [670, 1000],
    'stable': [290, 300], 'forge': [660, 500],
})
t = set_map(t, LOR + ['city_npc_positions'], {
    'npc_steward': [420, 950], 'npc_scribe': [380, 1040], 'npc_mentor': [580, 380],
    'npc_stablemaster': [380, 330], 'npc_keeper': [615, 790], 'npc_smith': [580, 560],
    'npc_guard': [560, 200], 'npc_warden': [600, 700], 'npc_child': [430, 730],
})
t = set_value(t, LOR + ['city_guest_positions'], '[[430, 420], [530, 420]]')
t = insert_before(t, LOR, 'city_building_positions', 'city_passable', '["gate"]')
t = insert_before(t, LOR, 'city_building_positions', 'plazas', '[[330, 560, 300, 220]]')
LOR_ENTITY = {
    'a4_secret_oralbook_step_1': [400, 200],
    'a4_secret_oralbook_feedback_0': [200, 1100],
    'a4_rel_nighttable_step_1': [480, 560],
    'a4_rel_nighttable_step_4': [300, 730],
    'a4_rel_nighttable_step_5': [440, 800],
    'a4_rel_nighttable_feedback_0': [370, 770],
}
for eid, at in LOR_ENTITY.items():
    t = set_value(t, LOR + ['entities', eid, 'at'], json.dumps(at))
t = set_value(t, LOR + ['clear_rects'], json.dumps([[x - 50, y - 55, 100, 110] for x, y in LOR_ENTITY.values()]))

# ---- 枫林古道：layout v3，枫溪横贯，石桥段为唯一通道；修桥点随桥移到河岸 ----
t = set_value(t, MAP + ['layout_version'], '3')
t = insert_before(t, MAP, 'flat_routes', 'river', '{"y": 578, "half": 16, "crossing": [440, 560]}')
MAP_ENTITY = {
    'a1_trade_bridge_step_1': [452, 628],
    'a1_trade_bridge_step_2': [548, 628],
    'a1_trade_bridge_step_3': [500, 578],
    'a1_trade_bridge_feedback_0': [500, 530],
}
for eid, at in MAP_ENTITY.items():
    t = set_value(t, MAP + ['entities', eid, 'at'], json.dumps(at))

path.write_text(t, encoding='utf-8', newline='\n')

# 回读校验：整文件仍是合法 JSON，且关键值与预期一致。
d = json.loads(t)['maps']
lor = d['lorin_wilds']
mp = d['maple_road']
assert lor['layout_version'] == 4 and lor['spawn'] == [480, 860] and lor['exits'][0]['at'] == [480, 220]
assert lor['city_building_positions']['gate'] == [480, 120] and len(lor['city_building_positions']) == 9
assert len(lor['city_npc_positions']) == 9 and lor['city_passable'] == ['gate'] and lor['plazas'] == [[330, 560, 300, 220]]
assert mp['layout_version'] == 3 and mp['river']['crossing'] == [440, 560]
for eid, at in LOR_ENTITY.items():
    assert lor['entities'][eid]['at'] == at, eid
for eid, at in MAP_ENTITY.items():
    assert mp['entities'][eid]['at'] == at, eid
print('LAYOUT_V4_APPLIED ok')
