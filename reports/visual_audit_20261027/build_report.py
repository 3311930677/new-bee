from pathlib import Path
import json,hashlib,difflib,re
from PIL import Image,ImageDraw,ImageFont
base=Path(r'D:/new-bee')
report=base/'reports/visual_audit_20261027'
shots=base/'远征/shots/visual_audit_20261027'
assert 'ALL GREEN  (78 cases' in (report/'regression_final_complete_summary.log').read_text(encoding='utf-8-sig')
# Final artifact generation is intentionally gated on completed rendering runs.
for name,marker in [('acceptance_final.log','CURRENT_VISUAL_OK checks=304 failures=0'),('visual_polish_map_final.log','VISUAL_POLISH checks=199 failures=0'),('responsive_final.log','RESPONSIVE_CAPTURE_OK shots=132 overruns=0'),('full_final.log','CURRENT_VISUAL_AUDIT_OK')]:
    assert marker in (report/name).read_text(encoding='utf-8-sig'),name
last_source_edit=max(p.stat().st_mtime for p in (base/'远征/src').rglob('*.gd'))
assert all((report/name).stat().st_mtime>=last_source_edit for name in ['acceptance_final.log','visual_polish_map_final.log','responsive_final.log','full_final.log'])
geometry=json.loads((shots/'final/geometry.json').read_text(encoding='utf-8'))
acceptance=json.loads((shots/'acceptance/results.json').read_text(encoding='utf-8'))
polish=json.loads((shots/'polish/results.json').read_text(encoding='utf-8'))
full=json.loads((shots/'final_full/audit_report.json').read_text(encoding='utf-8'))
assert not acceptance['failures'] and not polish['failures'] and not full['errors']
assert all(not n['overrun'] for page in geometry for n in page['nodes'])
changes=[];diff=[];source_hashes={}
for old in sorted((report/'before/src').rglob('*')):
    if not old.is_file():continue
    rel=old.relative_to(report/'before/src')
    current=base/'远征/src'/rel
    if not current.exists():continue
    a=old.read_text(encoding='utf-8-sig');b=current.read_text(encoding='utf-8-sig')
    if a!=b:
        name=rel.as_posix();changes.append(name)
        diff.extend(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile='before/src/'+name,tofile='after/src/'+name))
        source_hashes[name]=hashlib.sha256(current.read_bytes()).hexdigest()
(report/'changed_source.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2),encoding='utf-8')
(report/'incremental_source.diff').write_text(''.join(diff),encoding='utf-8')
summary={
 'engine':'Godot 4.7.2.stable.official.ed1daf0bf','renderer':'OpenGL Compatibility / AMD Radeon 780M',
 'source_files_changed':len(changes),'source_sha256':source_hashes,
 'regression':{'cases':78,'passed':78,'log':'regression_final_complete_summary.log','note':'Complete suite run after all product changes.'},
 'performance_lines':[line for line in (report/'regression_final_complete/VerifyPerf.log').read_text(encoding='utf-8-sig').splitlines() if line.startswith('PERF ')],
 'visual_checks':acceptance['checks']+polish['checks'],'visual_failures':0,
 'responsive':{'screenshots':len(geometry),'visible_rectangles':sum(len(p['nodes']) for p in geometry),'overruns':0,'sizes':[[320,640],[480,640],[480,800],[480,1067]]},
 'full_capture':{'screenshots':len(list((shots/'final_full').glob('*.png'))),'steps':len(full['steps']),'errors':full['errors'],'battle_result':full.get('battle_sim_result',''),'battle_result_late':full.get('battle_sim_result_late','')},
 'scope':'Actual Windows GPU rendering at phone viewport sizes; no physical Android device validation.',
 'known_engine_exit_diagnostics':'Original runner issue #43: shutdown resource diagnostics. See final runner summary for exact count. Graphical fixtures also emit exit-time resource warnings; not visual assertion failures.',
}
(report/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
font=ImageFont.truetype(r'C:/Windows/Fonts/msyh.ttc',22)
small=ImageFont.truetype(r'C:/Windows/Fonts/msyh.ttc',18)
canvas=Image.new('RGB',(1280,1440),'#17171d');d=ImageDraw.Draw(canvas)
for x,y,key,title in [(0,0,'home','主城：入口完整显示'),(640,0,'quests','任务：窄屏文字重排'),(0,720,'CreateRole','创角：昵称与角色完整可见'),(640,720,'companion','伙伴：纸页居中适配')]:
    d.text((x+10,y+6),title,font=font,fill='#ead6ad')
    d.text((x+10,y+42),'修复前',font=small,fill='#aaa5a5')
    d.text((x+330,y+42),'修复后',font=small,fill='#94ceb0')
    for dx,folder in [(0,'responsive_before'),(320,'final')]:
        im=Image.open(shots/folder/f'320x640_{key}.png').convert('RGB')
        canvas.paste(im.resize((320,640),Image.Resampling.LANCZOS),(x+dx,y+72))
canvas.save(report/'comparison.jpg',quality=94)
# A browsable contact sheet for all final phone views.
thumbs=[]
for page in geometry:
    path=shots/'final'/(page['shot']+'.png')
    im=Image.open(path).convert('RGB');im.thumbnail((150,334))
    tile=Image.new('RGB',(170,370),'#17171d');td=ImageDraw.Draw(tile)
    td.text((4,4),page['shot'][:28],font=ImageFont.truetype(r'C:/Windows/Fonts/msyh.ttc',10),fill='#ead6ad')
    tile.paste(im,((170-im.width)//2,28));thumbs.append(tile)
sheet=Image.new('RGB',(170*11,370*12),'#17171d')
for i,tile in enumerate(thumbs):sheet.paste(tile,((i%11)*170,(i//11)*370))
sheet.save(report/'all_final_views.jpg',quality=88)
print(json.dumps({k:v for k,v in summary.items() if k!='source_sha256'},ensure_ascii=False,indent=2))
