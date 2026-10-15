# 将求解出的 NPC 与访客站位写入 data/main_world_maps.json（只替换这两个字段，其余文本不动）。
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
solved = json.loads(sys.argv[2])
t = path.read_text(encoding='utf-8')

guests = [solved.pop('__guest0'), solved.pop('__guest1')]

# city_npc_positions 是多行对象：定位其开括号，按括号配对找到闭括号。
key = '"city_npc_positions": {'
start = t.index(key)
open_pos = start + len(key) - 1
depth = 0
i = open_pos
while True:
    c = t[i]
    if c == '{':
        depth += 1
    elif c == '}':
        depth -= 1
        if depth == 0:
            close_pos = i
            break
    i += 1
line_start = t.rfind('\n', 0, start) + 1
indent = t[line_start:start]
inner = indent + '  '
lines = ['{']
items = list(solved.items())
for n, (k, v) in enumerate(items):
    comma = ',' if n < len(items) - 1 else ''
    lines.append(f'{inner}"{k}": [{v[0]}, {v[1]}]{comma}')
lines.append(indent + '}')
t = t[:open_pos] + '\n'.join(lines) + t[close_pos + 1:]

# city_guest_positions 是单行数组：整行正则替换（.* 不跨行，贪婪匹配到该行最后一个 ]）。
import re
t, n = re.subn(r'"city_guest_positions": \[.*\]', lambda m: '"city_guest_positions": ' + json.dumps(guests), t, count=1)
assert n == 1, 'guest line'

path.write_text(t, encoding='utf-8', newline='\n')
d = json.loads(t)['maps']['lorin_wilds']
for k, v in solved.items():
    assert d['city_npc_positions'][k] == v, k
assert d['city_guest_positions'] == guests
print('NPC_V4B_APPLIED', len(solved), 'npcs,', len(guests), 'guests')
