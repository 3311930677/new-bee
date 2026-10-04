import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
path = root / 'data/fishing.json'
data = json.loads(path.read_text(encoding='utf-8'))
clues = {
    'fish_salt_spring':'盐泉鲫伏在桥下背阴处。等浮标越过碎石的回水，再在绿色区域收竿。',
    'fish_port_pier':'港湾银鳞沿栈桥绳影游动。涨潮水线靠近旧钉时，留意浮标的绿色区域。',
    'fish_tide_pool':'潮纹鳞藏在浅池波纹之间。看清退潮留下的细涟漪，再在绿色区域收竿。',
    'fish_frost_pool':'霜鳍鳟藏在冰缘暗水。看缓流，等浮标进入绿色区域再收竿。',
}
if not any(row['id']=='fish_frost_pool' for row in data['spots']):
    data['spots'].append({'id':'fish_frost_pool','map':'frost_post','name':'霜关冰缘池','item':'fish_frost','fish_name':'霜鳍鳟'})
for row in data['spots']:
    row['environment_hint']=clues[row['id']]
    row['king_cycle']=3
    row['king_phase']={'fish_salt_spring':1,'fish_port_pier':2,'fish_tide_pool':0,'fish_frost_pool':0}[row['id']]
    row['king_hint']={'fish_salt_spring':'桥影拉长，盐泉鱼王靠近回水。绿色区间收窄，看准浮标再收竿。',
                      'fish_port_pier':'潮线漫过旧钉，银鳞鱼王沿绳影游来。绿色区间收窄，看准浮标再收竿。',
                      'fish_tide_pool':'浅池三圈涟漪相叠，潮纹鱼王现身。绿色区间收窄，看准浮标再收竿。',
                      'fish_frost_pool':'冰缘出现长涟漪，霜鳍鱼王游过暗水。绿色区间收窄，看准浮标再收竿。'}[row['id']]
path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
path=root / 'data/main_world_maps.json'
maps=json.loads(path.read_text(encoding='utf-8'))
maps['maps']['frost_post']['entities']['fish_frost_pool']={'kind':'fishing','quest':'','art':'fishing','name':'冰缘暗水 · 垂钓','at':[200,1080]}
path.write_text(json.dumps(maps, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print('FISHING_REGIONS_READY 4')
