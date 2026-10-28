"""Local isolated Godot verification runner; no player save is used."""
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
PROJECT=ROOT/'远征'
ENGINE=ROOT/'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
env=os.environ.copy()
env.update(APPDATA=str(ROOT/'godot_test_appdata'),LOCALAPPDATA=str(ROOT/'godot_test_appdata'),PYTHONIOENCODING='utf-8')
mode=sys.argv[1] if len(sys.argv)>1 else 'prototype'
args=[str(ENGINE),'--path',str(PROJECT),'--audio-driver','Dummy']
if '--verbose' in sys.argv:args+=['--verbose']
if mode=='import':args+=['--headless','--editor','--import','--quit']
elif mode=='export_audit':args+=['--headless','--export-debug','Android Deep Audit',str(ROOT/'reports/full_issue_fix_20261024/Yuanzheng-fullfix-audit.apk')]
elif mode=='export_android':args+=['--headless','--export-debug','Android',str(ROOT/'reports/full_issue_fix_20261024/Yuanzheng-fullfix.apk')]
elif mode=='prototype':args+=['res://tools/VerifyIntegratedMount.tscn','--','--prototype','--capture']
elif mode=='mount':args+=['res://tools/VerifyIntegratedMount.tscn','--','--capture']
else:
    args+=['res://tools/'+mode+'.tscn']
    if '--headless' in sys.argv:args.insert(1,'--headless')
    if '--capture' in sys.argv:args+=['--','--capture']
log=PROJECT/'tools/_logs'/('fullfix_'+mode+'.log')
with log.open('w',encoding='utf-8') as stream:result=subprocess.run(args,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=600 if mode.startswith('export') else 300)
lines=log.read_text(encoding='utf-8',errors='replace').splitlines()
print('EXIT',result.returncode,'LOG',log)
for line in lines:
    if any(key in line for key in ['ERROR','FAIL','_OK','leaked','resources still']):print(line)
sys.exit(result.returncode)
