"""Retain terminal regression, replay, PNG and SHA256 evidence for P09-B."""
from pathlib import Path
import hashlib
import json
import shutil

project = Path(__file__).resolve().parents[1]
logs = project / 'tools/_logs'
shots = project / 'shots/fourth_front_20261002'
groups = [
    ('zs,fs', 'fourth_front_verified_zs_fs_20261002', 'p08e4_budget_zs_fs'),
    ('ck,fz', 'fourth_front_verified_ck_fz_20261002', 'p08e4_budget_ck_fz'),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def text(path):
    return path.read_text(encoding='utf-8-sig')


full = logs / 'fourth_front_accept_full_runner_20261002.log'
assert 'ALL GREEN  (46 cases' in text(full), 'Full regression has not completed successfully'
assert 'real player save' in text(full) and 'unchanged by this run' in text(full)
captures = json.loads(text(shots / 'captures.json'))
assert len(captures) == 8 and all(row['passed'] and row['exit_code'] == 0 for row in captures)
selftest = logs / 'fourth_front_selftest_runner_20261002.log'
assert 'RUNNER SELFTEST GREEN (11 fault-injection checks)' in text(selftest), 'Runner selftest has not passed'

roles = []
paths = [full, selftest]
for ids, folder, source_folder in groups:
    runner = logs / (folder.replace('20261002', 'runner_20261002') + '.log')
    assert 'PLAYTHROUGH_ALL_OK (2 roles' in text(runner), folder
    paths.append(runner)
    for role in ids.split(','):
        a, b = [logs / folder / f'save_playthrough_{role}_{phase}.json' for phase in ['a', 'b']]
        la, lb = [logs / folder / f'playthrough_{role}_{phase}.log' for phase in ['a', 'b']]
        source = logs / source_folder / f'save_playthrough_{role}_a.json'
        assert sha(a) == sha(b), role + ': persisted A/B bytes differ'
        states = []
        for phase, log in [('A', la), ('B', lb)]:
            states.append(next(line.split(' ', 1)[1] for line in text(log).splitlines()
                               if line.startswith('PLAY_' + phase + '_STATE ')))
        assert states[0] == states[1], role + ': complete serialized A/B state differs'
        assert 'play_source sha256=' + sha(source).lower() in text(la).lower(), role + ': source changed'
        current = json.loads(text(a))
        assert len(current['prog']['story']['done']) == 32 and current['items']['stele_key'] == 1
        roles.append(dict(role=role, complete_state_equal=True, save_bytes_equal=True,
                          save_sha256=sha(a), source_sha256=sha(source),
                          level=current['prog']['level'], gold=current['wallet']['gold'],
                          preparation=current['prog']['flags']['act4_preparation']))
        paths.extend([a, b, la, lb])

evidence = shots / 'evidence'
evidence.mkdir(exist_ok=True)
for path in paths:
    relative = path.relative_to(logs)
    dest = evidence / relative
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, dest)
full_cases = logs / 'fourth_front_accept_full_20261002'
assert len(list(full_cases.glob('*.log'))) == 46
shutil.copytree(full_cases, evidence / full_cases.name, dirs_exist_ok=True)

files = [
    'data/story_quests.json', 'data/main_world_maps.json', 'data/campaign_growth.json',
    'src/autoload/G.gd', 'src/city/CityScene.gd', 'src/explore/MapScene.gd',
    'src/explore/ThirdActGround.gd', 'tools/VerifyFourthFront.gd',
    'tools/PlaythroughFourthFront.gd', 'tools/VerifyThirdSide.gd',
    'tools/VerifyStory.gd', 'tools/VerifyCampaignGrowth.gd', 'tools/ShotRunner.gd',
    'tools/PlaythroughMainWorld.gd', 'tools/run_regression.ps1', 'tools/run_playthrough.ps1',
    'image/main_world/abyss_ring_ground_reference_v1.png',
]
hashes = {name: sha(project / name) for name in files}
hashes.update({str(path.relative_to(project)).replace('\\', '/'): sha(path)
               for path in shots.glob('*.png')})
real = Path.home() / 'AppData/Roaming/Godot/app_userdata/远征/save.json'
real_hash = sha(real)
expected = 'BA8054B3D2F46D21D5CFE70E6EF5EFCADCC817A8267FF67FC7522379E2805BE7'
assert real_hash == expected, 'Real player save was modified'
manifest = dict(checkpoint='P09-B', save_version=6, story_steps=32, side_quests=18,
                bosses=6, maps=15, full_regression=dict(cases=46, terminal='ALL GREEN', exit_code=0,
                resource_diagnostics_cases=32, resource_diagnostics_lines=77, tracked_issue=43),
                runner_selftest_cases=11, captures=8, roles=roles,
                real_save_sha256=real_hash, runtime_and_png_sha256=hashes,
                limits=['Automated real input is not human 30–45 minute timing or Android touch QA',
                        'Fourth-act rear half, ending, remaining S5/S6/S7 scope are not complete',
                        'Shutdown RID/resource diagnostics still occur'])
(shots / 'acceptance.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('FOURTH_FRONT_ACCEPTANCE_OK 46 cases / 4 roles / 8 PNG / real save unchanged')
