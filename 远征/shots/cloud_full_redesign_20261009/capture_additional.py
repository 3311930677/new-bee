from pathlib import Path
import subprocess, os, json
root=Path(__file__).resolve().parents[3]
project=root/'远征'
out=Path(__file__).parent
env=os.environ.copy()
env['APPDATA']=str(project/'Godot/ui_refinement_runtime')
engine=root/'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
scenes=['home','growth','equip','bag','main_world_battle_commands','main_world_battle_skills','worlds','deploy_plain','login','load','createrole','codex','settings','title_intro']
results=[]
for scene in scenes:
    log=out/(scene+'.log')
    with log.open('w',encoding='utf-8') as stream:
        result=subprocess.run([str(engine),'--path',str(project),'--position','80,80','res://tools/ShotRunner.tscn','--','--scene='+scene,'--out=res://shots/cloud_full_redesign_20261009/'+scene+'.png'],env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=45,creationflags=subprocess.CREATE_NO_WINDOW)
    text=log.read_text(encoding='utf-8',errors='replace')
    ok=result.returncode==0 and 'SHOT_SAVED' in text and 'SCRIPT ERROR' not in text and (out/(scene+'.png')).exists()
    results.append({'scene':scene,'ok':ok,'exit_code':result.returncode,'source_date':'2026-10-09'})
    print(scene, 'OK' if ok else 'FAILED',flush=True)
(out/'capture_manifest.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
raise SystemExit(0 if all(r['ok'] for r in results) else 1)
