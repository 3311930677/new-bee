"""Author twelve aftermath quests using the production staged quest protocol."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
maps_path = ROOT / 'data/main_world_maps.json'
maps_text = maps_path.read_text(encoding='utf-8')
maps = json.loads(maps_text)['maps']
changed = set()
quests = []

def step(mid, kind, name, at, art='post', clue='', choices=None, correct='', wrong='', completion=''):
    return dict(map=mid, kind=kind, name=name, at=at, art=art, clue=clue,
                choices=choices or {}, correct=correct, wrong=wrong, completion=completion)

def quest(qid, title, npc, city, chapter, category, intro, conclusion, steps, feedback, gold, exp):
    objectives = []
    for i, spec in enumerate(steps):
        mid = spec['map']
        eid = f'{qid}_step_{i+1}'
        objectives.append(dict(kind=spec['kind'], map=mid, target_entity=eid,
            text=spec['name'], choices=spec['choices'], correct=spec['correct'],
            clue=spec['clue'], wrong=spec['wrong'], completion=spec['completion'] or spec['clue']))
        maps[mid].setdefault('entities', {})[eid] = dict(kind=spec['kind'], quest=qid,
            name=spec['name'], art=spec['art'], at=spec['at'])
        clear = [spec['at'][0]-50, spec['at'][1]-65, 100, 110]
        if clear not in maps[mid].setdefault('clear_rects', []): maps[mid]['clear_rects'].append(clear)
        changed.add(mid)
    for i, (mid, art, name, at) in enumerate(feedback):
        maps[mid].setdefault('entities', {})[f'{qid}_feedback_{i}'] = dict(kind='feedback',quest=qid,art=art,name=name,at=at)
        changed.add(mid)
    quests.append(dict(id=qid, title=title, category=category, giver=npc, turn_in=npc,
        turn_in_map=city, map=steps[0]['map'], requires_story=f's{chapter:02}',
        clue=intro, objective=objectives[0], steps=objectives,
        objective_text=' → '.join(s['name'] for s in steps),
        reward=dict(gold=gold, exp=exp), discovery=qid,
        accept_dialogue=intro, progress_dialogue='现场记录可以逐项核对，错了还能重来。',
        ready_dialogue='你把沿路发生的事记全了？让我看看。', completion_dialogue=conclusion,
        world_feedback=conclusion, completion_flags={f'{qid}_done': True}))

quest('a1_secret_rubbing','碑上有旧补','npc_scribe','lorin_wilds',12,'秘闻',
    '碑上有三种刻向。先看岩纹、再看刀痕和缺口，把它们拼成一页，拓片不会因试错损坏。',
    '岩纹比刀痕更早，缺口又截断了补刻。碑曾被人修过，我们终于有了能复看的证据。',[
    step('stele_cavern','inspect','岩纹拓片',[380,960],'salt_marks',completion='岩纹贯穿整片，属于最早的一层。'),
    step('stele_cavern','inspect','刀痕拓片',[580,880],'salt_marks',completion='刀痕横过岩纹，是后来补刻。'),
    step('stele_cavern','inspect','缺口拓片',[380,830],'salt_marks',completion='缺口切断刀痕，说明破损发生在补刻之后。'),
    step('stele_cavern','align','拼合残页',[580,950],'salt_marks','三片的交叠关系已记清。按先后排出修碑的证据。',
        {'layers':'岩纹 → 刀痕 → 缺口','reverse':'缺口 → 岩纹 → 刀痕'},'layers','缺口截断刀痕，不可能比刀痕更早。拓片仍可重排。')],
    [('stele_cavern','salt_marks','留下的拓印台',[370,1020])],145,70)

quest('a1_trade_bridge','楔住归桥','npc_smith','lorin_wilds',12,'商旅',
    '古道桥板两头都松了。看清承重点，用我留在桥边的楔件选一侧修稳；另一侧仍能绕行。',
    '桥上的新楔件留住了归路。以后走到这里，会认得是哪一侧先修好。',[
    step('maple_road','inspect','西桥承重点',[380,735],'post',completion='西梁干燥，适合嵌楔；背风绕行仍可走。'),
    step('maple_road','inspect','东桥承重点',[580,665],'post',completion='东梁靠岸，同样能修；两种修法都能保住通行。'),
    step('maple_road','repair','嵌入桥楔',[480,595],'post','楔件已经备好。选择先修的一侧，两侧报酬相同，步行绕路始终可用。',
        {'west':'先稳西侧桥板','east':'先稳东侧桥板'})],
    [('maple_road','post','新楔归桥',[420,590])],150,65)

quest('a1_rel_watch','画在图上的巡路','npc_guard','lorin_wilds',12,'关系',
    '去断碑坡巡两处瞭望点。辨清兽影和守影脚迹，再画一条可以绕开的巡路，不必再打一遍。',
    '兽迹压在泥里，守影只留冷灰。巡逻图已换了，新来的巡界人可以照着走。',[
    step('broken_slope','inspect','泥中的兽迹',[390,935],'tracks',completion='泥痕有爪尖，足印连着觅食路线。'),
    step('broken_slope','inspect','冷灰守影迹',[570,690],'tracks',completion='灰上没有脚掌压痕，守影停在残碑旁。'),
    step('broken_slope','mark','绘制背风巡路',[480,790],'post','兽影沿湿泥游走，守影贴着残碑。背风石脊可以避开两者。',
        {'ridge':'沿背风石脊画线','mud':'沿湿泥脚迹画线'},'ridge','湿泥正是兽影觅食的路。可以擦掉重画。')],
    [('broken_slope','post','新巡逻路标',[410,790])],140,65)

quest('a2_secret_tide_clock','水痕里的旧时刻','npc_harbormaster','shenyuan_port',20,'秘闻',
    '账页写着三次开闸，却没有时刻。去潮滩比对高痕、低痕和回潮线，把旧闸序记回来。',
    '港务厅按你的记录挂出潮线图。盐渠与堤道都能通行，原先的供货选择仍然有效。',[
    step('tideflat','inspect','高水痕',[390,970],'salt_marks',completion='高痕盖过旧栈桥脚：上闸当时未泄水。'),
    step('tideflat','inspect','低水痕',[570,790],'salt_marks',completion='低痕露出桥脚：旧渠曾先放水。'),
    step('tideflat','inspect','回潮线',[390,610],'salt_marks',completion='回潮线留在货箱外侧：侧闸是在泄水后才放行。'),
    step('tideflat','align','编排闸门时序',[570,900],'post','高痕、低痕、回潮线分别见证了闭闸、泄水与侧闸放行。',
        {'drain':'闭闸 → 旧渠泄水 → 侧闸放行','rush':'闭闸 → 侧闸放行 → 泄水'},'drain','桥脚只有泄水后才露出，侧闸不能先于泄水放行。')],
    [('shenyuan_port','salt_marks','港务潮线图',[365,610])],240,120)

quest('a2_trade_weight','货签之外的盐数','npc_port_trader','shenyuan_port',20,'商旅',
    '货签的盐数和港仓实货不合。检查两张货签、秤砣和实货，再决定先补仓还是先告知商队。',
    '账页多写了一袋，实货却没少人的份。两条供货路随后都恢复，告示也写清了差额从何而来。',[
    step('old_salt_road','inspect','出港货签',[390,910],'salt_marks',completion='出港签写着三袋，承运人盖了旧印。'),
    step('old_salt_road','inspect','到仓货签',[570,805],'salt_marks',completion='到仓签写着四袋，后补的一笔未过秤。'),
    step('old_salt_road','inspect','秤砣与实货',[390,650],'salt_cart',completion='秤砣刻度正常，车上是三袋；差额来自到仓签。'),
    step('old_salt_road','switch','处理账签差额',[570,715],'post','实货三袋，差的是账签。先补港仓或先告知商队都不改变报酬，两路随后都恢复。',
        {'warehouse':'先补港仓记录','caravan':'先通知承运商队'})],
    [('shenyuan_port','salt_marks','有来源的盐价告示',[585,850])],250,115)

quest('a2_eco_driftwood','给巢边留一条路','npc_port_keeper','shenyuan_port',20,'生态',
    '潮滩的两块漂木堵住鸟巢回岸的安全线。先看巢位，搬开挡木，再沿浅痕送一块回岸。',
    '巢边的浅线清出来了，漂木留在岸侧。修路也能给不会说话的邻居留一条归路。',[
    step('tideflat','inspect','巢位与浅痕',[580,1000],'return_tidebud',completion='巢在高处，回岸的浅痕绕过两块漂木。'),
    step('tideflat','repair','搬开第一块漂木',[390,900],'post',completion='漂木挪向空岸，不碰巢边植株。'),
    step('tideflat','repair','搬开第二块漂木',[580,740],'post',completion='浅痕连通，幼鸟可以沿岸侧走。'),
    step('tideflat','escort','沿浅线送木回岸',[390,1060],'post',completion='漂木停在岸边，为后来观察的人留下参照。')],
    [('tideflat','return_tidebud','未受扰动的巢边',[580,990])],230,110)

quest('a3_secret_airshaft','让矿井重新呼吸','npc_frost_miner','frost_post',28,'秘闻',
    '旧炉息记录还有用。到矿道核对南北风口，调好双风轮，再把最后一队矿工领出烟线。',
    '南井进风、西口排烟，最后一队人也出来了。轮岗簿添上名字，烟道不再遮住回路。',[
    step('rift_mine_road','inspect','南井清风记录',[390,870],'mine_vent',completion='南井空气清，北侧残烟要由西口排走。'),
    step('rift_mine_road','align','调整南井风轮',[570,800],'mine_vent','南井引清风能把矿工等候区与烟道分开。',{'south':'引入南井清风','north':'把北井烟送回'},'south','北井烟会回到等候区，风轮可再调。'),
    step('rift_mine_road','align','调整西口风轮',[390,650],'mine_vent','清风已经进入，必须有出口。翻车记录记的是西口。',{'west':'向西口排烟','east':'封住西口'},'west','封住出口会积烟，打开西口再试。'),
    step('rift_mine_road','escort','领矿工走安全线',[570,1010],'post',completion='矿工带着姓名牌回到霜关，最后一段烟线留在身后。')],
    [('frost_post','salt_marks','获救矿工轮岗簿',[400,830])],340,180)

quest('a3_trade_switch','两车都要到','npc_frost_envoy','frost_post',28,'商旅',
    '铁料和药包都在矿道等候。先读两份货单，再选谁先发车；先后只影响停靠回应，两车最终都到。',
    '两车都已抵达。先后留下的是调度记录，没有任何一队的需要被永久丢下。',[
    step('rift_mine_road','inspect','铁料货单',[570,910],'mine_cart',completion='铁料修轨，工坊等着换梁。'),
    step('rift_mine_road','inspect','药包货单',[390,760],'salt_cart',completion='药包给守岗人换药，不能长久停在风口。'),
    step('rift_mine_road','switch','拨动双车道岔',[570,620],'mine_cart','两辆车都能到。选择先行的一车，只影响停车位置与回应，报酬相同。',{'iron':'铁料先行','medicine':'药包先行'}),
    step('rift_mine_road','escort','为后一车让道',[390,1010],'mine_cart',completion='另一辆车也顺着空轨出发，两份货单都盖上了到达印。')],
    [('frost_post','mine_cart','两车到站记录',[560,960])],350,175)

quest('a3_rel_snowwatch','有人接的夜岗','npc_frost_guard','frost_post',28,'关系',
    '沿栈道三处岗火走一圈，看清迎风和背风的位置。回程给轮岗图选一条安排，可以绕开敌影。',
    '轮岗图已经改好，背风灯也亮了。有人守夜，也有人知道下一班什么时候会来。',[
    step('frost_boardwalk','inspect','南岗火',[390,970],'return_lamp',completion='南岗火迎风，守夜人需要换班。'),
    step('frost_boardwalk','inspect','中岗火',[580,790],'return_lamp',completion='中岗背风，可以停留交接。'),
    step('frost_boardwalk','inspect','北岗火',[390,580],'return_lamp',completion='北岗看得远，沿石脊回中岗不经过兽影。'),
    step('frost_boardwalk','mark','补记轮岗安排',[580,1000],'post','三处岗火都记好了。增一班守夜或沿背风路换岗都可照看整条路，报酬等值。',{'shift':'增一班守夜','shelter':'沿背风路换岗'})],
    [('frost_boardwalk','return_lamp','轮岗背风灯',[580,770])],330,170)

quest('a4_secret_oralbook','三城口述','npc_scribe','lorin_wilds',36,'秘闻',
    '碑心的余纹已经读过。这次请你听三城亲历者说归路，记人的记忆，而不是再拓三道碑纹。',
    '有人记得名字，有人记得货船，有人记得接班的灯。三份记忆合成一页，归路篇结案，八碑长线仍待追索。',[
    step('lorin_wilds','listen','听城门旧识讲归路',[570,1080],'post',completion='老赵记得的是终于能叫出名字的人。'),
    step('shenyuan_port','listen','听港口旧识讲归路',[390,990],'post',completion='老鹭记得船回港时，第一声重新听见的潮钟。'),
    step('frost_post','listen','听霜关旧识讲归路',[570,1080],'post',completion='岑雪记得有人接岗，火没有在夜里熄掉。')],
    [('lorin_wilds','salt_marks','三城口述册',[590,685])],300,0)

quest('a4_rel_nighttable','归来的一桌','npc_port_worker','shenyuan_port',36,'关系',
    '请边城、港口、霜关各一位旧识来短聚。顺序由你选，三段故事都会留在桌边，不再寄一次信。',
    '桌边三段故事都讲完了。先听谁是自己的选择，后来的人仍能翻到每一段。',[
    step('lorin_wilds','listen','邀请边城旧识',[390,1060],'post',completion='边城旧识答应带一盏灯来。'),
    step('shenyuan_port','listen','邀请港口旧识',[570,990],'post',completion='港口旧识答应带修缆绳的旧结来。'),
    step('frost_post','listen','邀请霜关旧识',[390,1080],'post',completion='霜关旧识答应带轮岗簿来。'),
    step('lorin_wilds','mark','选择桌边先讲的故事',[480,1000],'return_lamp','三位旧识都在。先听一段，然后让另外两段也讲完；先后不改变奖励。',{'border':'先听边城的灯','port':'先听港口的绳结','frost':'先听霜关的轮岗簿'}),
    step('lorin_wilds','listen','听完桌边三段故事',[580,1000],'post',completion='灯、绳结和轮岗簿摆在同一张桌上，三段故事都收进册页。')],
    [('lorin_wilds','post','三城小聚留桌',[580,990])],300,0)

quest('a4_eco_returnpath','不采走的复苏','npc_port_keeper','shenyuan_port',36,'生态',
    '回访潮芽和雪线花的恢复地点。这次只看足迹与土层，不采样；选一处放不伤植株的观察标记。',
    '潮芽扎稳了根，雪线花下的土层也回温。记录留在路边，植株留在原处。',[
    step('tideflat','inspect','观察潮芽根际',[390,1020],'return_tidebud',completion='根际土层湿润，新足迹绕开了幼芽。'),
    step('frost_boardwalk','inspect','观察雪线花土层',[570,920],'return_snowflower',completion='花下土层回温，旧脚迹留在石脊而非根边。'),
    step('tideflat','mark','设立轻触观察标记',[580,1040],'post','把标记设在空岸石面，或背风木桩；两处都不触碰植株，报酬等值。',{'stone':'在空岸石面标记','wood':'在背风木桩标记'})],
    [('tideflat','post','复苏观察标记',[580,1020])],300,0)

side_path = ROOT / 'data/side_quests.json'
side = json.loads(side_path.read_text(encoding='utf-8'))
ids = {q['id'] for q in quests}
side['quests'] = [q for q in side['quests'] if q['id'] not in ids] + quests
side['comment'] = '四幕各九条，共36条。新增余波采用steps顺序目标；实体与分支幂等保存，交付仍走原side事务。'
side_path.write_text(json.dumps(side, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
# Patch map objects from the end to retain the rest of the hand-authored data.
patches = []
for mid in changed:
    key = '    ' + json.dumps(mid) + ': '
    start = maps_text.index(key) + len(key)
    _, length = json.JSONDecoder().raw_decode(maps_text[start:])
    replacement = json.dumps(maps[mid], ensure_ascii=False, indent=2).replace('\n', '\n    ')
    patches.append((start, length, replacement))
for start, length, replacement in sorted(patches, reverse=True):
    maps_text = maps_text[:start] + replacement + maps_text[start+length:]
maps_path.write_text(maps_text, encoding='utf-8')
print(f'AUTHORED {len(quests)} quests, {len(changed)} maps')
