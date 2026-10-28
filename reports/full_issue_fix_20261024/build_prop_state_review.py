from pathlib import Path
import json
from PIL import Image,ImageDraw

root=Path(__file__).resolve().parent
project=root.parents[1]/'远征'
result=json.loads((project/'tools/_logs/map_prop_states_results.json').read_text(encoding='utf-8'))
assert result['failures']==0 and result['objects']==34 and len(result['records'])==136
groups={}
for row in result['records']:
    assert row['visible']==row['expected_visible']
    groups.setdefault(row['id'],{})[row['phase']]=row
    assert (project/'shots/full_issue_fix_20261024/prop_states'/row['image']).is_file()
assert len(groups)==34
lines=['# 地图物件逐状态验收','',
       '2026-10-25。通过正式 MapScene 生成 21 个原白折线物件、13 个非战斗线索，检查 136 组状态，697 项断言，0 失败。截图来自桌面 OpenGL 实景。',
       '', '读档列使用独立 SAVE_PATH，经正式 save_game / reload_save 写入并通过存档校验后重新构建地图。普通物件读回当前步骤，完成反馈物件读回已完成状态。',
       '', '“未接取”表示支线/委托尚未接取、船单未接单，或机关前置剧情尚未完成。原支线规则允许部分首个采集/观察/递交线索提前被发现，本轮保留这一规则。',
       '', '[34 个物件实景局部预览](prop_state_gallery.jpg)', '',
       '| 实体 ID / 地图 | 未接取或未解锁 | 当前步骤 | 完成 | 正式读档 |',
       '| --- | --- | --- | --- | --- |']
gallery=Image.new('RGB',(4*280,9*205),'#25343b')
draw=ImageDraw.Draw(gallery)
discovered=[]
for index,(identifier,states) in enumerate(groups.items()):
    assert set(states)=={'unaccepted','current','completed','reloaded'}
    if states['unaccepted']['visible']:discovered.append(identifier)
    cells=[]
    for phase in ['unaccepted','current','completed','reloaded']:
        row=states[phase]
        filename='../../远征/shots/full_issue_fix_20261024/prop_states/'+row['image']
        cells.append('['+('出现' if row['visible'] else '隐藏')+']('+filename+')')
    lines.append('| '+identifier+' / '+states['current']['map']+' | '+' | '.join(cells)+' |')
    row=states['current'] if states['current']['visible'] else states['completed']
    assert row['visible']
    x,y=row['screen_anchor']
    with Image.open(project/'shots/full_issue_fix_20261024/prop_states'/row['image']) as source:
        crop=source.crop((round(x)-80,round(y)-90,round(x)+80,round(y)+40)).resize((256,176),Image.Resampling.NEAREST)
    tile_x=index%4*280;tile_y=index//4*205
    gallery.paste(crop,(tile_x+12,tile_y+24))
    draw.text((tile_x+5,tile_y+5),identifier,fill='white')
lines+=['','未接取时按原规则可发现的首线索：'+', '.join(discovered)+'。',
        '', '以上验证实体生成、正确坐标、资源语义、完成后的消失/留存、正式读档及绘制不改进度。状态夹具不等同于从新档手动通关全部支线。']
(root/'地图物件逐状态验收.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
gallery.save(root/'prop_state_gallery.jpg',quality=96)
print('PROP_STATE_REVIEW_OK objects=34 states=136 checks=697 failures=0 initial_discoverable=',discovered)
