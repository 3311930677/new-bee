"""Read-only checks of final logs/assets; writes only the durable evidence manifest."""
import json,re,hashlib,subprocess
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parent.parent
logs=root/'tools/_logs'
shots=root/'shots/frost_art_20261001'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
terminal=(logs/'frost_art_final.log').read_text(encoding='utf-8-sig')
assert 'ALL GREEN  (44 cases' in terminal
assert len(re.findall(r'^PASS\s+',terminal,re.M)) == 44
assert not re.search(r'^FAIL\s+',terminal,re.M)
cases=re.findall(r'N = "([^"]+)";\s*K = "[^"]+";\s*T = "([^"]+)"', (root/'tools/run_regression.ps1').read_text(encoding='ascii'))
assert len(cases) == 44
for name,token in cases:
    own=(logs/'frost_art_final'/f'{name}.log').read_text(encoding='utf-8-sig')
    assert re.search(r'^'+token+r'\b',own,re.M),name
    assert not re.search(r'SCRIPT ERROR|Parse Error|FAIL:|_FAIL\b',own),name
selftest=(logs/'frost_art_selftest.log').read_text(encoding='utf-8-sig')
assert 'RUNNER SELFTEST GREEN (11 fault-injection checks)' in selftest
assert len(re.findall(r'^PASS\s+',selftest,re.M)) == 11
roles=[]
for rid,group in [('zs','zs_fs'),('fz','ck_fz')]:
    directory=logs/f'frost_art_final_{rid}'
    source=logs/f'p08e4_budget_{group}'/f'save_playthrough_{rid}_a.json'
    a=directory/f'save_playthrough_{rid}_a.json'; b=directory/f'save_playthrough_{rid}_b.json'
    assert a.read_bytes() == b.read_bytes(),rid
    la=(directory/f'playthrough_{rid}_a.log').read_text(encoding='utf-8-sig')
    lb=(directory/f'playthrough_{rid}_b.log').read_text(encoding='utf-8-sig')
    assert re.search(r'^PLAY_A_OK\b',la,re.M) and re.search(r'^PLAY_B_OK\b',lb,re.M)
    assert re.search(r'^PLAY_OK\b',lb,re.M)
    assert 'sha256='+digest(source) in la
    assert not re.search(r'SCRIPT ERROR|Parse Error|PLAY_BAD|FAIL:',la+lb)
    sa=json.loads(re.search(r'^PLAY_A_STATE (.+)$',la,re.M).group(1))
    sb=json.loads(re.search(r'^PLAY_B_STATE (.+)$',lb,re.M).group(1))
    assert sa == sb and sa['brazier_choice'] == 'shield'
    assert len(sa['third_side']) == 6 and all(q['status']=='done' for q in sa['third_side'].values())
    assert 'side_choice shield real_click=true' in la
    original,final=read(source),read(a)
    for key in ['inventory','equip','skills','pets','pet_stat','mounts','story']:
        assert original['prog'].get(key) == final['prog'].get(key),(rid,key)
    roles.append({'role':rid,'source_sha256':digest(source),'save_a_sha256':digest(a),'save_b_sha256':digest(b),'state_a':sa,'state_b':sb,'old_investments_unchanged':True})
assets=read(root/'data/frost_city_art.json')
assert len(assets['npcs'])==3 and len(assets['props'])==4
for row in list(assets['npcs'].values())+list(assets['props'].values()):
    p=root/row['path'].removeprefix('res://')
    assert digest(p)==row['sha256']
    with Image.open(p) as im:
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
for row in assets['npcs'].values():
    assert len(row['frames'])==4
    for f in row['frames']:
        _,_,w,h=f['region']; mx,my,mw,mh=f['margin']
        assert [w+mw,h+mh] == row['canvas']
        assert my+h == row['canvas'][1]
        assert abs(mx+f['foot_x']-row['canvas'][0]/2)<0.01
assert not subprocess.check_output(['git','diff','d1b6c2a','--','data/main_world_maps.json','data/frost_post.json','data/story_quests.json','data/side_quests.json','image/role','src/world/WalkActor.gd','src/world/FirstActWeaponVisual.gd'],cwd=root)
frames=[]
for p in sorted(shots.glob('*.png')):
    height=1067 if '480x1067' in p.name else 800
    with Image.open(p) as im: assert im.size==(480,height),p.name
    log=(logs/f'final_{p.stem}.log').read_text(encoding='utf-8-sig')
    assert 'SHOT_SAVED res://shots/frost_art_20261001/'+p.name in log
    assert not re.search(r'SCRIPT ERROR|Parse Error|SHOT_SAVE_FAILED',log)
    frames.append({'file':p.name,'size':[480,height],'sha256':digest(p),'staged_layout':True})
assert len(frames)==20
real=Path(r'C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\远征\save.json')
real_sha=digest(real)
assert real_sha.upper()=='C5D29EE55C033619C4F5232D55A6C4F186D40ADD556DB61EE0D776B9FDA2660C'
manifest={'unit':'P08-E6','baseline_commit':'d1b6c2a','formal_cases':44,'runner_fault_checks':11,'assets':assets,'screenshots':frames,'roles':roles,'real_save_sha256':real_sha,'hero_redraw_deferred':True,'geometry_and_story_tables_unchanged':True,'limits':['screenshots are staged compositions, not unlock or natural-play proof','two-role real-input route covers the six existing Frost Post side quests and shield choice; coal is covered by formal state/save tests','NPC soles and heights are validated against the actual source pixels and native AtlasTexture margins','whole S0-S7 goal remains active; fourth act and full art set remain','issue 43 exit-only resource/RID diagnostics remain; Android performance is not claimed']}
(shots/'acceptance.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('FROST_ART_ACCEPT_OK 44 cases / 11 selftests / 2 roles A+B / 20 shots / real save unchanged')
