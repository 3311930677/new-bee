"""Apply the authored mine-room data while preserving unrelated map formatting."""
import json
from pathlib import Path

path = Path(__file__).resolve().parents[1] / 'data/main_world_maps.json'
text = path.read_text(encoding='utf-8')
start = text.index('    "rift_mine_vault": {') + len('    "rift_mine_vault": ')
row, length = json.JSONDecoder().raw_decode(text[start:])
row['rooms'] = {
    'record': {'gate_at': [480, 785], 'open_flag': 'act3_mine_clue', 'hint': '先读翻车记录，核对东烟西风'},
    'rescue': {'gate_at': [480, 475], 'open_flag': 'act3_mine_switch', 'hint': '调稳双风轮，让矿车带人撤离'},
}
for clear in [[275, 500, 410, 280], [300, 800, 360, 340]]:
    if clear not in row['clear_rects']: row['clear_rects'].append(clear)
row['entities']['act3_mine_wheel']['at'] = [340, 680]
row['entities']['act3_mine_second_wheel'] = {
    'kind': 'puzzle_choice', 'art': 'mine_vent', 'name': '回风风轮', 'at': [620, 590],
    'requires_story': 's24', 'requires_flags': ['act3_mine_rooms_v1', 'act3_mine_wind'],
    'flag': 'act3_mine_second_wind',
    'clue': '西侧排风已开，但北轨仍有回烟。记录背面写着：南井引入清风，北井留给矿工。',
    'choices': {'south': '从南井引入清风', 'north': '从北井引入清风'}, 'correct': 'south',
    'wrong': '北井风压把烟送回等候区。先由南井引清风，再拨北轨，仍可重调。',
    'completion': '两座风轮形成通风，烟从北侧轨面散去。矿工举灯示意可以发车。',
}
row['entities']['act3_mine_switch']['at'] = [480, 535]
row['entities']['act3_mine_switch']['completion'] = '矿车把等候的矿工带到安全停靠点，入口留下三顶工帽。械卫的过热声再也不被烟道盖住。'
text = text[:start] + json.dumps(row, ensure_ascii=False, indent=2).replace('\n', '\n    ') + text[start + length:]
path.write_text(text, encoding='utf-8')
