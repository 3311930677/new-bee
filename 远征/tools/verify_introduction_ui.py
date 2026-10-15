"""Run isolated visual and navigation checks without touching player saves."""
from pathlib import Path
import argparse
import json
import os
import subprocess
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / 'shots/introduction_20261015'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--full-regression', action='store_true')
    args = parser.parse_args()
    env = os.environ.copy()
    for key, subdir in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')]:
        runtime = PROJECT / 'Godot/introduction_runtime' / subdir
        runtime.mkdir(parents=True, exist_ok=True)
        env[key] = str(runtime)
    runs = [
        ('import', ['--headless', '--editor', '--import', '--quit'], None),
        ('verify', ['--position', '-3000,-3000', 'res://tools/VerifyIntroduction.tscn'], 'FAILURES 0'),
        ('navigation', ['--headless', 'res://tools/VerifyNav.tscn'], 'NAV_OK'),
    ]
    if args.full_regression:
        runs.append(('entry', ['--position', '-3000,-3000', 'res://tools/VerifyRound1UI.tscn'], 'ROUND1_UI_OK'))
    results = []
    for name, flags, marker in runs:
        result = subprocess.run([args.godot, '--path', str(PROJECT), *flags], env=env,
                                capture_output=True, timeout=180,
                                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        log = (result.stdout + result.stderr).decode('utf-8', errors='replace')
        (OUT / (name + '.log')).write_text(log, encoding='utf-8')
        ok = result.returncode == 0 and 'SCRIPT ERROR' not in log and (marker is None or marker in log)
        results.append({'name': name, 'passed': ok, 'exit_code': result.returncode})
        print(name, 'OK' if ok else 'FAIL', flush=True)
        if not ok:
            print(log[-6000:], flush=True)
    for height in [800, 1067]:
        montage = Image.new('RGB', (1488, height + 32), '#080d14')
        for index, name in enumerate(['world', 'travelers', 'route']):
            montage.paste(Image.open(OUT / (name + '_%d.png' % height)).convert('RGB'), (index * 496, 16))
        montage.save(OUT / ('overview_%d.png' % height))
    (OUT / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    raise SystemExit(0 if all(item['passed'] for item in results) else 1)

if __name__ == '__main__':
    main()
