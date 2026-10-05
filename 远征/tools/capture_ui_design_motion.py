from pathlib import Path
import os, subprocess, sys
from capture_checks import failures
root=Path(__file__).resolve().parents[1]
output=root/'shots/ui_design_blocks_20261005'
env=os.environ.copy()
for key,part in [('APPDATA','roaming'),('LOCALAPPDATA','local')]: env[key]=str(root/'Godot/ui_refinement_runtime'/part)
engine='D:/new-bee/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
mode=sys.argv[1]
if mode=='tests':
 for scene,token in [('VerifyInventoryUI','INVENTORY_UI_OK'),('VerifyUIText','UI_TEXT_OK'),('VerifySummonUI','SUMMON_UI_OK')]:
  command=[engine,'--headless','--path',str(root),'res://tools/'+scene+'.tscn']
  run=subprocess.run(command,env=env,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW,timeout=120)
  log=(run.stdout+run.stderr).decode('utf-8',errors='replace')
  (output/'verification'/('direct_'+scene+'.log')).write_text(log,encoding='utf-8')
  ok=run.returncode==0 and token in log and not failures(log)
  print('PASS' if ok else 'FAIL',scene,flush=True)
  if not ok: print(log); raise SystemExit(1)
else:
 for kind in ([mode] if mode in ['finesse','readability'] else ['finesse','readability']):
  folder=output/'motion'/kind
  folder.mkdir(parents=True,exist_ok=True)
  command=[engine,'--path',str(root),'--position','-4000,-4000','res://tools/MotionPreviewRunner.tscn','--','--mode='+kind,'--out='+str(folder)]
  run=subprocess.run(command,env=env,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW,timeout=180)
  log=(run.stdout+run.stderr).decode('utf-8',errors='replace')
  (folder/'capture.log').write_text(log,encoding='utf-8')
  ok=run.returncode==0 and 'MOTION_PREVIEW_OK '+kind in log and not failures(log)
  print('PASS' if ok else 'FAIL',kind,flush=True)
  if not ok: print(log); raise SystemExit(1)
