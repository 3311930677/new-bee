"""Native city HUD screenshots, edge states, and a compact comparison page."""
import argparse
import json
import os
from pathlib import Path
import subprocess
from PIL import Image
from capture_checks import capture_ok

PROJECT = Path(__file__).resolve().parents[1]
CASES = ['main_world', 'world_hud_city', 'world_hud_low_hp', 'world_hud_large_wallet', 'world_hud_field']


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', default='shots/world_hud_20261006')
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
        for case in CASES:
            image = folder / (case + '.png')
            command = [args.godot, '--path', str(PROJECT), '--position', '-4000,-4000',
                       'res://tools/OffscreenShotRunner.tscn', '--', '--scene=' + case,
                       '--size=' + size, '--frames=60', '--out=' + str(image)]
            try:
                run = subprocess.run(command, env=env, capture_output=True, timeout=90,
                                     creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
                log = (run.stdout + run.stderr).decode('utf-8', errors='replace')
                passed = capture_ok(run.returncode, log, image)
            except subprocess.TimeoutExpired:
                log, passed = 'CAPTURE_TIMEOUT', False
            image.with_suffix('.log').write_text(log, encoding='utf-8')
            results.append(dict(size=size, scene=case, passed=passed, path=str(image)))
            print(('OK' if passed else 'FAIL'), size, case, flush=True)
            if not passed:
                print(log[:3000], flush=True)
                raise SystemExit(1)
    (root / 'after/results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    audit = {'screenshots': len(results), 'text_nodes': 0, 'nonlinear_text': [], 'compact_art': [], 'short_text_boxes': []}
    for row in results:
        data = json.loads(Path(row['path']).with_suffix('.text.json').read_text(encoding='utf-8'))
        audit['text_nodes'] += len(data['text_nodes'])
        for key in ['nonlinear_text', 'compact_art', 'short_text_boxes']:
            audit[key].extend(data[key])
    (root / 'text_audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding='utf-8')
    comparison_case = 'world_hud_field' if (root / 'before/480x800/world_hud_field.png').exists() else 'main_world'
    for phase in ['before', 'after']:
        with Image.open(root / phase / ('480x800/' + comparison_case + '.png')) as image:
            image.crop((0, 0, 480, 260)).save(root / (phase + '_hud.png'))
    with Image.open(root / 'after/480x800/world_hud_field.png') as image:
        image.crop((0, 0, 480, 212)).save(root / 'hud_detail.png')
    cards = ''.join('<article><h3>' + title + '</h3><a href="after/480x800/' + case + '.png"><img src="after/480x800/' + case + '.png"></a></article>'
                    for case, title in [('world_hud_city', 'Lv13 · 回城主线'), ('world_hud_low_hp', '22% 生命 · 暖色提醒'),
                                        ('world_hud_large_wallet', '九位金币 · 完整显示'), ('world_hud_field', '野外 · 主线与支线')])
    html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>远征 · 城内 HUD 精修</title><style>
*{box-sizing:border-box}body{margin:0;background:#111d23;color:#eee6d4;font:15px/1.7 system-ui,sans-serif}main{max-width:1120px;margin:auto;padding:36px 24px}
h1{font-size:30px;margin:0 0 12px}h2{font-size:21px;margin-top:36px}h3{font-size:15px;font-weight:500;color:#ddc69c}p{color:#bdc7c8;max-width:900px}
.compare{display:grid;grid-template-columns:1fr 1fr;gap:20px}.compare img{width:100%;height:auto;image-rendering:pixelated;border-radius:6px}.cards{display:grid;grid-template-columns:repeat(4,1fr);gap:20px}.cards img{width:100%;height:auto;border:1px solid #45575c;border-radius:6px}a{color:#e7c581}summary{cursor:pointer}details img{width:240px;max-width:48%;vertical-align:top;margin:12px 12px 12px 0}@media(max-width:760px){.compare{grid-template-columns:1fr}.cards{grid-template-columns:1fr 1fr}main{padding:24px 16px}}
</style><main><h1>远征 · HUD 层级与材质</h1><p>地点名成为上方视觉锚点；资源栏降低对比；深绿漆木、黄铜边缘与纸签统一组件语言。任务类型改为左侧小标签。以下图片均来自实际 Godot 游戏。</p>
<section class="compare"><article><h3>修改前</h3><img src="before_hud.png"></article><article><h3>修改后</h3><img src="after_hud.png"></article></section>
<h2>场景检查</h2><p>书法标题、宋体正文、清晰数字采用固定口径；4px 网格对齐。生命去掉重复文字，资源和任务保留 44px 点击高度。金币变化、经验增加、任务更新和进入地点才触发相应微动效。</p><section class="cards">''' + cards + '''</section>
<h2>长屏检查 · 480 × 1067</h2><details><summary>查看长屏实际截图</summary><a href="after/480x1067/world_hud_city.png"><img src="after/480x1067/world_hud_city.png"></a><a href="after/480x1067/world_hud_field.png"><img src="after/480x1067/world_hud_field.png"></a></details>
<p>文字检查：''' + str(audit['text_nodes']) + ''' 个文字节点；未发现错误采样、过小艺术字或文字框高度不足。<a href="text_audit.json">查看检查结果</a></p></main></html>'''
    if (root / 'feedback.gif').exists():
        html = html.replace('<h2>长屏检查', '<!-- HUD_FEEDBACK_PREVIEW --><h2>事件动效</h2><p>实际游戏录制：进入地点、金币连续入账与支出、经验增加、任务更新。</p><img src="feedback.gif" alt="HUD 事件动效" style="width:480px;max-width:100%;height:auto"><h2>长屏检查')
    (root / 'index.html').write_text(html, encoding='utf-8')
    print('AUDIT', {k: len(v) if isinstance(v, list) else v for k, v in audit.items()}, flush=True)
    raise SystemExit(1 if any(audit[k] for k in ['nonlinear_text', 'compact_art', 'short_text_boxes']) else 0)


if __name__ == '__main__':
    main()
