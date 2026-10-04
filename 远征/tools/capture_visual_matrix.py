"""Reproduce the 256 scene/state captures with the locally installed Godot.

Uses isolated ShotRunner saves; neither imports nor changes the real player save.
Usage: python tools/capture_visual_matrix.py --godot <console.exe>
"""
from pathlib import Path
import argparse
import json
import os
import re
import shlex
import subprocess
from capture_checks import capture_ok, failures

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / 'shots/all_scenes_20261001'
OUTPUT = PROJECT / 'shots/visual_refresh_20261001/final'

def cases():
    result = []
    for batch in range(1, 5):
        name = '_batch.sh' if batch == 1 else f'_batch{batch}.sh'
        script = (SOURCE / name).read_text(encoding='utf-8').replace('\\\n', ' ')
        def expand(match):
            variable, values, body = match.groups()
            return '\n'.join(body.replace(f'${variable}', value) for value in shlex.split(values))
        script = re.sub(r'for (\w+) in (.*?); do\s*\n(.*?)\ndone', expand, script, flags=re.S)
        for line in script.splitlines():
            if not line.strip().startswith('shot '):
                continue
            words = shlex.split(line.strip())
            scene, image = words[1:3]
            frame = words[3] if len(words) > 3 and words[3].isdigit() else '45'
            options = words[4:] if len(words) > 3 and words[3].isdigit() else words[3:]
            result.append(dict(scene=scene, image=image, frames=frame, options=options,
                               size='480x1067' if batch == 4 else '480x800', source=batch > 1))
    return result

def main():
    global OUTPUT
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--only', default='')
    parser.add_argument('--output', default=str(OUTPUT))
    parser.add_argument('--extras', action='store_true', help='Include new named pages and long-help captures')
    args = parser.parse_args()
    OUTPUT = Path(args.output).resolve()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    (PROJECT / 'tools/_logs').mkdir(parents=True, exist_ok=True)
    if os.name == 'nt':
        for key, folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
            runtime = PROJECT / 'Godot/ui_refinement_runtime' / folder
            runtime.mkdir(parents=True, exist_ok=True)
            env[key] = str(runtime)
    matrix = cases()
    assert len(matrix) == 256, len(matrix)
    if args.extras:
        for size in ['480x800', '480x1067']:
            for scene in ['settings_profile', 'title_intro', 'title_intro_party', 'title_intro_journey', 'reading_help', 'reading_help2']:
                matrix.append(dict(scene=scene, image=scene, frames='45', options=[], size=size, source=False))
        for scene in ['load', 'title', 'title_settings', 'login', 'createrole']:
            matrix.append(dict(scene=scene, image=scene, frames='45', options=[], size='480x1067', source=False))
    (OUTPUT / 'manifest.json').write_text(json.dumps(matrix, ensure_ascii=False, indent=2), encoding='utf-8')
    if args.only:
        selected = set(args.only.split(','))
        matrix = [item for item in matrix if item['scene'] in selected]
    if any(item['source'] for item in matrix):
        fixture = subprocess.run([args.godot, '--headless', '--path', str(PROJECT),
                                  'res://tools/VisualSourceFixture.tscn'], env=env,
                                 capture_output=True, timeout=60,
                                 creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        fixture_log = (fixture.stdout+fixture.stderr).decode('utf-8',errors='replace')
        (OUTPUT/'source_fixture.log').write_text(fixture_log,encoding='utf-8')
        if fixture.returncode or 'VISUAL_SOURCE_FIXTURE_OK' not in fixture_log or failures(fixture_log):
            raise RuntimeError(fixture_log)
    results = []
    if args.only and (OUTPUT / 'results.json').exists():
        results = json.loads((OUTPUT / 'results.json').read_text(encoding='utf-8'))
    refreshed = []
    for index, item in enumerate(matrix, 1):
        folder = OUTPUT / ('long_480x1067' if item['size'] == '480x1067' else '')
        folder.mkdir(parents=True, exist_ok=True)
        image = folder / (item['image'] + '.png')
        log = folder / (item['image'] + '.log')
        command = [args.godot, '--path', str(PROJECT), '--position', '-4000,-4000',
                   '--log-file', str(log), 'res://tools/OffscreenShotRunner.tscn', '--',
                   '--scene=' + item['scene'], '--size=' + item['size'],
                   '--frames=' + item['frames'], '--out=' + str(image), *item['options']]
        if item['source']:
            command.append('--source-save=res://tools/_logs/visual_fixture/source.json')
        try:
            run = subprocess.run(command, env=env, capture_output=True, timeout=120,
                                 creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            output = (run.stdout + run.stderr).decode('utf-8', errors='replace')
            passed = capture_ok(run.returncode, output, image)
        except subprocess.TimeoutExpired:
            passed, output = False, 'CAPTURE_TIMEOUT'
        log.write_text(output, encoding='utf-8')
        row = dict(**item, passed=passed, path=str(image))
        results = [previous for previous in results
                   if (previous['size'], previous['image']) != (item['size'], item['image'])]
        results.append(row)
        refreshed.append(row)
        print(f"{'OK' if passed else 'FAIL'} {index}/{len(matrix)} {item['size']} {item['image']}", flush=True)
        (OUTPUT / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    failed = [row for row in refreshed if not row['passed']]
    print(f"CAPTURE_MATRIX {len(refreshed)-len(failed)}/{len(refreshed)}", flush=True)
    raise SystemExit(bool(failed))

if __name__ == '__main__':
    main()
