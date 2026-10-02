"""Capture the production fourth-act slice using isolated ShotRunner saves."""
from pathlib import Path
import argparse
import json
import subprocess

project = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--output', default='shots/fourth_front_20261002')
args = parser.parse_args()
output = project / args.output
output.mkdir(parents=True, exist_ok=True)
results = []
for size in ['480x800', '480x1067']:
    for scene in ['fourth_ring', 'fourth_regions', 'fourth_preparation', 'fourth_battle']:
        name = scene + '_' + size
        png, log = output / (name + '.png'), output / (name + '.log')
        command = [args.godot, '--path', str(project), '--position', '-4000,-4000',
                   '--log-file', str(log), 'res://tools/OffscreenShotRunner.tscn', '--',
                   '--scene=' + scene, '--size=' + size, '--out=' + str(png)]
        run = subprocess.run(command, capture_output=True, timeout=180)
        text = (run.stdout + run.stderr).decode('utf-8', errors='replace')
        log.write_text(text, encoding='utf-8')
        passed = run.returncode == 0 and 'SHOT_SAVED' in text and not any(
            bad in text for bad in ['SCRIPT ERROR', 'Parse Error', 'SHOT_FOURTH_', 'SHOT_SAVE_FAILED'])
        results.append(dict(scene=scene, size=size, path=str(png), passed=passed,
                            exit_code=run.returncode, exit_diagnostics='leaked' in text))
        print(('PASS ' if passed else 'FAIL ') + name, flush=True)
(output / 'captures.json').write_bytes((json.dumps(results, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
print('FOURTH_CAPTURE %d/%d' % (sum(row['passed'] for row in results), len(results)))
raise SystemExit(0 if all(row['passed'] for row in results) else 1)
