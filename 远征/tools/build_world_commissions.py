"""Author the twelve reusable world errands without changing legacy quest IDs."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def step(name, map_id, at, art='post', kind='inspect', **kw):
    return dict(name=name, map=map_id, at=at, art=art, kind=kind, **kw)

rows = []
def add(qid, region, title, desc, steps, gold, exp):
    for i, s in enumerate(steps): s['id'] = f'{qid}_{i+1}'
    rows.append(dict(id=qid, region=region, title=title, desc=desc, minutes='约 3—6 分钟',
                     steps=steps, reward=dict(gold=gold, exp=exp)))

add('wc_sign', 'zhaoyuan', '路标勘定', '闻叔：雨后路痕会变。依次核对树根、坡石、岔口，把三处实地记录带回。', [
    step('树根路痕', 'maple_road', [420,920], 'tracks'),
    step('坡石擦痕', 'maple_road', [520,750], 'tracks'),
    step('岔口旧箭', 'broken_slope', [480,870], 'post')], 75,35)
add('wc_watch', 'zhaoyuan', '巡界夜岗', '老赵：先到路北的岗牌报到，再驱散靠近岗火的一头狼。撤退可以重来。', [
    step('夜岗签到牌', 'maple_road', [480,800]),
    step('岗火附近的狼', 'maple_road', [480,610], 'tracks', 'defeat', enemy='mon_wolf')], 85,40)
add('wc_bridge', 'zhaoyuan', '桥板修补', '石头：检查松动的桥脚，用两块强化石压紧旧桥板。材料到现场才扣，放弃不扣剩余材料。', [
    step('桥脚裂缝', 'broken_slope', [480,820], 'tracks'),
    step('松动桥板', 'broken_slope', [480,670], 'post', 'repair', costs={'item:enhance_stone':2})], 115,35)
add('wc_turtle', 'zhaoyuan', '岩龟寻路', '闻叔：不必捕捉岩龟。沿脚印确认它走进了安全的石窝。', [
    step('圆爪脚印', 'broken_slope', [420,920], 'tracks'),
    step('石屑脚印', 'broken_slope', [520,750], 'tracks'),
    step('岩龟石窝', 'broken_slope', [480,570], 'root', 'escort')], 70,30)
add('wc_tide', 'shenyuan', '潮线观测', '沈澜：从岸脚到浅滩记三处水线，别把单次浪头当成潮位。', [
    step('岸脚水线', 'tideflat', [270,640], 'tide_mark'),
    step('桥柱水线', 'tideflat', [480,540], 'tide_mark'),
    step('浅滩水线', 'tideflat', [640,410], 'tide_mark')], 105,55)
add('wc_rope', 'shenyuan', '缆绳加固', '老鹭：先看缆痕，再选受力点。顺着受力方向系紧，误选会解释原因，不损耗材料。', [
    step('缆柱磨痕', 'shenyuan_port', [390,600], 'tracks'),
    step('松缆受力点', 'shenyuan_port', [560,520], 'post', 'align',
         clue='缆痕向岸侧压深，水侧木柱已裂。应把受力移到哪一侧？',
         choices={'shore':'加固岸侧石柱', 'water':'系回水侧裂柱'}, correct='shore',
         wrong='裂柱承担不了涨潮拉力；岸侧石柱的磨痕才是稳定受力点。')], 110,50)
add('wc_salt', 'shenyuan', '盐账对盘', '陆七：对照市集报价和两张货签，按实记账；不需要购买或出售货物。', [
    step('今日盐价牌', 'shenyuan_port', [350,620], 'post', clue='牌上是市集当日公示价，不是旧账单。'),
    step('旧盐道入货签', 'old_salt_road', [390,580], 'post'),
    step('港口出货签', 'shenyuan_port', [570,460], 'post')], 100,50)
add('wc_escort', 'shenyuan', '短程押运', '沈澜：货物不收保证金。可走旧盐道绕行，或走浅滩近路；报酬相同，需亲到交货点。', [
    step('待押货签', 'shenyuan_port', [460,580], 'salt_cart', 'align',
         clue='旧盐道较长但路面干燥；浅滩较短，有潮兽游荡。两路报酬相同。',
         choices={'road':'沿旧盐道绕行', 'tide':'沿浅滩近路'}),
    step('押运交货点', 'old_salt_road', [480,380], 'salt_cart', 'escort',
         routes={'road':{'map':'old_salt_road','at':[480,380]},'tide':{'map':'tideflat','at':[570,340]}})], 120,60)
add('wc_furnace', 'frost', '炉息巡查', '陶铎：入口听炉息、风口查堵物、最后排清烟道。不是矿脉主线的第二份钥匙。', [
    step('入口炉息', 'rift_mine_road', [310,650], 'mine_vent', 'listen'),
    step('风口堵物', 'rift_mine_road', [490,530], 'mine_vent'),
    step('烟道清理', 'rift_mine_road', [600,390], 'mine_vent', 'repair')], 140,75)
add('wc_switch', 'frost', '矿车让道', '陶铎：核对货签后把空车推向空轨，不要动矿脉主闸。错误道岔可以退回再选。', [
    step('空矿车货签', 'rift_mine_road', [350,650], 'mine_cart'),
    step('矿车让道岔', 'rift_mine_road', [510,510], 'mine_cart', 'switch',
         clue='南轨工人还在装货；北轨空着，出口仍有灯。', choices={'north':'让空车走北轨','south':'让空车走南轨'},
         correct='north', wrong='南轨仍有人装货，不能把空车推向作业的人。')], 145,70)
add('wc_snow', 'frost', '雪线踏勘', '岑雪：辨出冰裂、兽迹与人迹，最后把巡线牌放在人迹旁。', [
    step('雪边冰裂', 'frost_boardwalk', [440,910], 'tracks'),
    step('坡侧兽迹', 'frost_boardwalk', [530,730], 'tracks'),
    step('岗口人迹', 'frost_boardwalk', [480,550], 'tracks', 'mark')], 135,65)
add('wc_supply', 'frost', '轮岗补给', '宁砚：到补给箱登记，再把箱子送到外岗火。只交这次配发的补给，不扣玩家药剂。', [
    step('轮岗补给箱', 'frost_post', [420,880], 'post'),
    step('外岗补给火', 'frost_boardwalk', [480,760], 'frost_brazier', 'escort')], 140,70)

(ROOT/'data/world_commissions.json').write_text(json.dumps({'version':1,'templates':rows}, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
# These clearings also keep event destinations reachable under procedural decorations.
path=ROOT/'data/main_world_maps.json'
text=path.read_text(encoding='utf-8'); data=json.loads(text)
for mid,m in data['maps'].items():
    points=[s['at'] for q in rows for s in q['steps'] if s['map']==mid]
    points += [r['at'] for q in rows for s in q['steps'] for r in s.get('routes',{}).values() if r['map']==mid]
    for p in points:
        rect=[p[0]-65,p[1]-60,130,120]
        if rect not in m.setdefault('clear_rects',[]): m['clear_rects'].append(rect)
# Preserve unrelated map formatting: replace only changed map objects.
decoder=json.JSONDecoder(); offset=text.index('{',text.index('"maps"'))+1
replacements=[]
for mid,m in data['maps'].items():
    while text[offset].isspace() or text[offset]==',': offset+=1
    _,offset=decoder.raw_decode(text,offset)
    while text[offset].isspace() or text[offset]==':': offset+=1
    original,end=decoder.raw_decode(text,offset)
    if original!=m: replacements.append((offset,end,json.dumps(m,ensure_ascii=False,indent=4)))
    offset=end
for a,b,replacement in reversed(replacements): text=text[:a]+replacement+text[b:]
path.write_text(text,encoding='utf-8')
print('WORLD_COMMISSION_DATA_OK templates=12')
