"""Capture representative game UI states with isolated runtime data."""
from pathlib import Path
import argparse
import json
import os
import subprocess
from capture_checks import capture_ok

PROJECT = Path(__file__).resolve().parents[1]
CASES = [
    ('home', []), ('bag', []), ('bag_full', []), ('settings', []),
    ('settings_profile', []), ('settings2', []), ('quests', []),
    ('city_guests', []), ('city_notice', []), ('city_shop', []),
    ('city_build_panel', []), ('city_built_panel', ['--building=gate']),
    ('city_built_panel', ['--building=archive']), ('main_world', []),
    ('main_world_battle_commands', []), ('main_world_battle_skills', []),
    ('battle', []), ('forge_enhance', []), ('forge_gem', []),
    ('equip', []), ('growth', []), ('skillbook', []), ('worlds', []),
    ('codex', []), ('deploy', []), ('arena', []), ('gacha', []),
    ('mount', []), ('titles', []), ('trade_warden_dialog', []),
    ('title', []), ('createrole', []),
    ('pet_raise', []),
    ('login', ['--fresh', '--avatar=fox']), ('avatar', ['--avatar=cat']),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', default=str(PROJECT / 'shots/crafted_game_20261004'))
    parser.add_argument('--only', default='')
    parser.add_argument('--sizes', default='480x800,480x1067')
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    (PROJECT / 'tools/_logs').mkdir(parents=True, exist_ok=True)
    if os.name == 'nt':
        for key, folder in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')]:
            runtime = PROJECT / 'Godot/ui_refinement_runtime' / folder
            runtime.mkdir(parents=True, exist_ok=True)
            env[key] = str(runtime)
    selected = set(args.only.split(',')) if args.only else set()
    results_path = output / 'results.json'
    results = json.loads(results_path.read_text(encoding='utf-8')) if results_path.exists() else []
    refreshed = []
    for size in args.sizes.split(','):
        folder = output / size
        folder.mkdir(parents=True, exist_ok=True)
        for scene, options in CASES:
            if selected and scene not in selected:
                continue
            name = next((o.removeprefix('--building=') for o in options if o.startswith('--building=')), scene)
            image = folder / (name + '.png')
            command = [args.godot, '--path', str(PROJECT), '--position', '-4000,-4000',
                       'res://tools/OffscreenShotRunner.tscn', '--', '--scene=' + scene,
                       '--size=' + size, '--frames=60', '--out=' + str(image), *options]
            try:
                run = subprocess.run(command, env=env, capture_output=True, timeout=90,
                                     creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
                log = (run.stdout + run.stderr).decode('utf-8', errors='replace')
                passed = capture_ok(run.returncode, log, image)
            except subprocess.TimeoutExpired:
                log, passed = 'CAPTURE_TIMEOUT', False
            (folder / (name + '.log')).write_text(log, encoding='utf-8')
            row = dict(size=size, scene=scene, name=name, passed=passed, path=str(image))
            results = [r for r in results if (r['size'], r['name']) != (size, name)]
            results.append(row)
            refreshed.append(row)
            results_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
            print(('OK' if passed else 'FAIL'), size, name, flush=True)
            if not passed:
                print(log, flush=True)
    raise SystemExit(0 if all(r['passed'] for r in refreshed) else 1)


if __name__ == '__main__':
    main()
