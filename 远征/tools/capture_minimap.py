"""Inspect the map widget in real city, field, expanded and expedition scenes."""
import argparse
import json
import os
from pathlib import Path
import subprocess
from PIL import Image
from capture_checks import capture_ok

PROJECT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', default='shots/minimap_20261006')
    args = parser.parse_args()
    root = PROJECT / args.output
    env = os.environ.copy()
    if os.name == 'nt':
        for key, folder in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')]:
            runtime = PROJECT / 'Godot/ui_refinement_runtime' / folder
            runtime.mkdir(parents=True, exist_ok=True)
            env[key] = str(runtime)
    results = []
    for size in ['480x800', '480x1067']:
        folder = root / 'after' / size
        folder.mkdir(parents=True, exist_ok=True)
        for case in ['world_hud_city', 'world_hud_field', 'world_minimap_expanded', 'world_minimap_field_expanded', 'map']:
            path = folder / (case + '.png')
            # Refresh every scene so comparison files always refer to the current code.
            command = [args.godot, '--path', str(PROJECT), '--position', '-4000,-4000',
                       'res://tools/OffscreenShotRunner.tscn', '--', '--scene=' + case,
                       '--size=' + size, '--frames=60', '--out=' + str(path)]
            run = subprocess.run(command, env=env, capture_output=True, timeout=90,
                                 creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            log = (run.stdout + run.stderr).decode('utf-8', errors='replace')
            path.with_suffix('.log').write_text(log, encoding='utf-8')
            passed = capture_ok(run.returncode, log, path)
            print(('OK' if passed else 'FAIL'), size, case, flush=True)
            if not passed:
                print(log[:3000], flush=True)
                raise SystemExit(1)
            results.append({'scene': case, 'size': size, 'passed': passed, 'path': str(path)})
    (root / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    report = {'screenshots': len(results), 'text_nodes': 0, 'nonlinear_text': [], 'compact_art': [], 'short_text_boxes': []}
    for row in results:
        data = json.loads(Path(row['path']).with_suffix('.text.json').read_text(encoding='utf-8'))
        report['text_nodes'] += len(data['text_nodes'])
        for key in ['nonlinear_text', 'compact_art', 'short_text_boxes']:
            report[key].extend(data[key])
    (root / 'text_audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    for phase in ['before', 'after']:
        source = root / 'before/480x800_world_hud_field.png' if phase == 'before' else root / 'after/480x800/world_hud_field.png'
        with Image.open(source) as image:
            image.crop((350, 8, 475, 156)).save(root / (phase + '_detail.png'))
    with Image.open(root / 'after/480x800/world_hud_field.png') as image:
        image.crop((0, 0, 480, 206)).save(root / 'hud_detail.png')
    html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>远征 · 舆图精修</title>
<style>*{box-sizing:border-box}body{margin:0;background:#152228;color:#ece2ce;font:15px/1.7 system-ui,sans-serif}main{max-width:1050px;margin:auto;padding:34px 24px}h1{font-size:28px;margin:0 0 12px}h2{font-size:19px;margin:0 0 12px}p{color:#bcc8c6}a{color:#dfc18a}.comparison{display:flex;gap:32px;margin:30px 0}.comparison img{width:250px;max-width:100%;height:auto;image-rendering:pixelated;border:1px solid #6c6650;border-radius:7px}.cards{display:grid;grid-template-columns:repeat(4,1fr);gap:18px}.cards img{width:100%;height:auto;border-radius:6px}summary{cursor:pointer}details img{width:240px;max-width:48%;vertical-align:top;margin:18px 14px 0 0}@media(max-width:650px){.cards{grid-template-columns:repeat(2,1fr)}.comparison{gap:20px}.comparison article{width:50%}main{padding:24px 16px}}</style>
<main><h1>远征 · 随身舆图</h1><p>小图以导航为主：道路改为淡细线，突出玩家金箭与可通行出口，只提示最近的支线目标。视野框、普通敌影和采集点移到展开图，保留细铜框与北向罗针。</p>
<section class="comparison"><article><h2>修改前</h2><img src="before_detail.png"></article><article><h2>修改后</h2><img src="after_detail.png"></article></section>
<section class="cards">'''
    for case, label in [('world_hud_city', '边城'), ('world_hud_field', '古道'), ('world_minimap_expanded', '边城大地图'), ('world_minimap_field_expanded', '古道大地图')]:
        html += f'<article><h2>{label}</h2><a href="after/480x800/{case}.png"><img src="after/480x800/{case}.png"></a></article>'
    html += '''</section><details><summary>长屏与历练场景</summary><a href="after/480x1067/world_hud_city.png"><img src="after/480x1067/world_hud_city.png"></a><a href="after/480x800/map.png"><img src="after/480x800/map.png"></a></details>
<p>截图均由实际 Godot 游戏生成。<a href="text_audit.json">查看文字检查</a></p></main></html>'''
    (root / 'index.html').write_text(html, encoding='utf-8')
    print('AUDIT', {k: len(v) if isinstance(v, list) else v for k, v in report.items()}, flush=True)
    raise SystemExit(1 if any(report[k] for k in ['nonlinear_text', 'compact_art', 'short_text_boxes']) else 0)


if __name__ == '__main__':
    main()
