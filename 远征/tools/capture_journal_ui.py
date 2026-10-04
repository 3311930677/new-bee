"""Capture the registration card, avatar picker and building notes with isolated saves."""
from pathlib import Path
import argparse
import json
import os
import subprocess

PROJECT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', default=str(PROJECT / 'shots/ui_refinement_20261003/crafted_v2'))
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    if os.name == 'nt':
        for key, folder in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')]:
            runtime = PROJECT / 'Godot/ui_refinement_runtime' / folder
            runtime.mkdir(parents=True, exist_ok=True)
            env[key] = str(runtime)
    cases = [
        ('login', 'login', ['--fresh', '--avatar=fox']),
        ('avatar', 'avatar', ['--avatar=cat']),
        ('city_built_panel', 'gate', ['--building=gate']),
        ('city_built_panel', 'archive', ['--building=archive']),
    ]
    results = []
    for size in ['480x800', '480x1067']:
        folder = output / size
        folder.mkdir(parents=True, exist_ok=True)
        for scene, name, options in cases:
            image = folder / (name + '.png')
            command = [args.godot, '--path', str(PROJECT), '--position', '-4000,-4000',
                       'res://tools/OffscreenShotRunner.tscn', '--', '--scene=' + scene,
                       '--size=' + size, '--frames=60', '--out=' + str(image), *options]
            run = subprocess.run(command, env=env, capture_output=True, timeout=90,
                                 creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            log = (run.stdout + run.stderr).decode('utf-8', errors='replace')
            (folder / (name + '.log')).write_text(log, encoding='utf-8')
            passed = run.returncode == 0 and 'SHOT_SAVED' in log and 'SCRIPT ERROR' not in log
            results.append(dict(size=size, scene=name, passed=passed, path=str(image)))
            print(('OK' if passed else 'FAIL'), size, name, flush=True)
            if not passed:
                print(log, flush=True)
            (output / 'results.json').write_text(
                json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    raise SystemExit(0 if all(item['passed'] for item in results) else 1)


if __name__ == '__main__':
    main()
