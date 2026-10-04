import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
path = root / 'data/lore.json'
data = json.loads(path.read_text(encoding='utf-8'))
data['world']['premise'] = '昭元界有八座镇界碑，锁着地脉之下的「渊」。天倾纪十一年，林海碑首先失声，王城随后遭灾。如今是十七年，六年来的断路仍困住三城。你先调查昭元到沉渊港、霜关的往返线索，修稳归路碑；八碑的源头与王城旧账仍是未解的长线。'
data['timeline'] = [{'year': 11, 'event': '林海碑失声、王城遭灾，三城往返逐渐中断。'}, {'year': 17, 'event': '玩家抵达昭元，沿证词、货签与轮岗记录调查归路碑。'}]
for page in data['prologue']:
    if page['title'] == '天倾之夜':
        page['lines'] = ['天倾纪十一年，林海碑先失了声。随后王城燃起火，师门在乱夜里失散。', '如今是十七年。六年来的断路，让寄出的信和归来的人都越来越少。', '半卷《远征图志》留下八碑的长线谜题；眼下先找回三城间仍能走的路。']
    elif page['title'] == '留下的三个人':
        page['lines'] = ['铁匠石头从灰里扒出一座还能用的炉子；游商云游推着车进来。', '阿豆是留在兽栏照看辨路动物的送信人。他把旧信钉在门柱上：「这些信还寄不到，可我想让路回来。」', '有人留下做炉、有人成路上的见证，营地才有了可以回来的名字。']
    elif page['title'] == '启程':
        page['lines'] = ['先到昭元找闻叔，听城门的证词，再循枫林古道上的足迹出行。', '碑片、港口货签和霜关来信会把三城连成一条调查线；先修稳归路碑。', '图志里的八个回境可以用来历练。它们是危险的投影，不等于八座真实界碑已被修复。']
data['goals']['after_all'] = '八回境已遍历，可重访练招。归路主线另按三城与碑心记录推进；八碑长线仍待追索。'
data['goals']['next_hint'] = '出征 → 选「%s」→ 完成回境历练，揭开下一页投影；不推进归路主线。'
data['goals']['locked_hint'] = '前一页回境尚未完成，这一页推不开；主世界道路按归路任务独立开放。'
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
test = root / 'tools/VerifyLore.gd'
text = test.read_text(encoding='utf-8').replace('G.main_goal', 'G.trial_goal')
text = text.replace('j_end.contains("王城")', 'j_end.contains("仍未解开") and not j_end.contains("八碑归位")')
text = text.replace('全通关目标应收束到王城', '回境全通仍保留八碑未解状态')
if 'var campaign_before :=' not in text:
    text = text.replace('\tG.on_world_cleared("forest")', '\tvar campaign_before := G.main_goal_short()\n\tG.on_world_cleared("forest")\n\t_check(G.main_goal_short() == campaign_before, "回境通关不冒充归路主线推进")')
test.write_text(text, encoding='utf-8')
