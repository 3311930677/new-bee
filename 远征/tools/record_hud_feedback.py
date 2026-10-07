"""Record actual animated HUD frames and verify motion settles correctly."""
import argparse
import os
from pathlib import Path
import subprocess
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    root = PROJECT / 'shots/hud_hierarchy_20261006'
    env = os.environ.copy()
    for key, folder in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')]:
        env[key] = str(PROJECT / 'Godot/ui_refinement_runtime' / folder)
    run = subprocess.run([args.godot, '--path', str(PROJECT), '--position', '-4000,-4000',
                          'res://tools/RecordHUDFeedback.tscn', '--', '--out=' + str(root / 'motion_frames')],
                         capture_output=True, env=env, timeout=90,
                         creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    log = (run.stdout + run.stderr).decode('utf-8', errors='replace')
    (root / 'feedback.log').write_text(log, encoding='utf-8')
    if run.returncode or 'HUD_FEEDBACK_OK frames=56' not in log or 'SCRIPT ERROR' in log or 'HUD_FEEDBACK_FAIL' in log:
        print(log)
        raise SystemExit(1)
    frames = [Image.open(root / 'motion_frames' / f'{i:03}.png').convert('RGB') for i in range(56)]
    # Shared palette avoids per-frame colour flicker in the preview.
    palette = frames[-1].quantize(colors=128)
    images = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    images[0].save(root / 'feedback.gif', save_all=True, append_images=images[1:], duration=65, loop=0,
                   optimize=False, disposal=2)
    page = root / 'index.html'
    if page.exists():
        html = page.read_text(encoding='utf-8')
        if '<!-- HUD_FEEDBACK_PREVIEW -->' not in html:
            html = html.replace('<h2>长屏检查', '<!-- HUD_FEEDBACK_PREVIEW --><h2>事件动效</h2><p>实际游戏录制：进入地点、金币连续入账与支出、经验增加、任务更新。</p><img src="feedback.gif" alt="HUD 事件动效" style="width:480px;max-width:100%;height:auto"><h2>长屏检查')
            page.write_text(html, encoding='utf-8')
    print('HUD_FEEDBACK_OK frames=56')


if __name__ == '__main__':
    main()
