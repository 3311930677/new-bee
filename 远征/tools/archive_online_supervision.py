"""Archive verified role supervision without credentials, states or DB dumps."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import urllib.parse

GAME = Path(__file__).resolve().parents[1]
ROOT = GAME.parent
sys.path.insert(0, str(GAME / 'server/tools'))
from dev import LOCAL, SERVER, completed_go_tests, config
from verify_world import source_fingerprint


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--world', required=True)
    parser.add_argument('--date', required=True)
    parser.add_argument('--failed-world', action='append', default=[])
    args = parser.parse_args()
    runs = [args.world, *args.failed_world]
    if not re.fullmatch(r'[0-9]{8}', args.date) or len(runs) != len(set(runs)) or any(not re.fullmatch(r'world_[0-9a-f]{32}', name) for name in runs):
        raise RuntimeError('Expected unique generated run names and date')
    source = LOCAL / 'verification'
    fingerprint = source_fingerprint()
    world_folder = source / args.world
    world = json.loads((world_folder / 'report.json').read_text(encoding='utf8'))
    supervision = world.get('supervision', {})
    recovery = world.get('database_recovery', {})
    host_hash = hashlib.sha256((SERVER / 'bin/servicehost.exe').read_bytes()).hexdigest()
    gateway_hash = hashlib.sha256((SERVER / 'bin/gateway.exe').read_bytes()).hexdigest()
    if (not world.get('passed') or not world.get('online_sources_unchanged') or not world.get('player_data_unchanged') or world.get('worker_errors')
            or world.get('online_sources_sha256') != fingerprint or world.get('gateway_binary_sha256') != gateway_hash
            or supervision.get('host_binary_sha256') != host_hash or world.get('transport') != 'https-validating-debug-ca'
            or len(world.get('checks', [])) != 12 or not all(item.get('passed') for item in world['checks'])
            or world.get('injected_database_failures') != 2 or world.get('final_database_counts') != ['2','2','2','2','2','2','0']
            or not recovery.get('passed') or recovery.get('tables_matched') != 17 or recovery.get('gateway_restricted_starts') != 4):
        raise RuntimeError('Current real supervision/battle/recovery evidence is incomplete')
    events = supervision.get('events', [])
    if (len(events) != 3 or [event.get('kind') for event in events] != ['host_death','hang','exit']
            or not events[0].get('child_reaped') or events[1].get('suspended_threads', 0) < 1
            or not events[1].get('gateway_dependency_failure_without_restart')
            or any(not event.get('host_pid_unchanged') or event['generation_after'] != event['generation_before']+1 for event in events[1:])):
        raise RuntimeError('Native process ownership or automatic child recovery proof missing')
    stops = supervision.get('planned_stops', [])
    if len(stops) != 4 or any(item.get('exit_code') != 0 or item.get('phase') != 'stopped' or item.get('child_pid') != 0 for item in stops):
        raise RuntimeError('Planned stop proof missing')
    go = json.loads((source / 'supervision-go-final-result.json').read_text(encoding='utf8'))
    tests = completed_go_tests(source / 'supervision-go-final.jsonl')
    if go.get('exit_code') != 0 or go.get('online_sources_sha256') != fingerprint or not go.get('online_sources_unchanged') or go.get('completed_tests') != tests:
        raise RuntimeError('Complete Go suite does not match current sources')
    preflight = json.loads((source / 'supervision-preflight-result.json').read_text(encoding='utf8'))
    if (preflight.get('linux_cross_build_exit_code') != 0 or preflight.get('smoke_exit_code') != 0 or preflight.get('unexpected_smoke_errors')
            or not preflight.get('player_data_unchanged') or not preflight.get('online_sources_unchanged') or preflight.get('online_sources_sha256') != fingerprint):
        raise RuntimeError('Matching cross-build or isolated main startup proof missing')
    regression = ROOT / 'reports' / ('online_' + args.date) / 'supervision-regression'
    singleplayer = json.loads((regression / 'verification.json').read_text(encoding='utf8'))
    if singleplayer.get('exit_code') != 0 or singleplayer.get('passed_cases') != 79 or singleplayer.get('expected_cases') != 79:
        raise RuntimeError('Strict complete singleplayer regression is missing')
    files = [(source / 'supervision-go-final.jsonl', Path('go-integration.jsonl')),
             (source / 'supervision-go-final-result.json', Path('go-result.json')),
             (source / 'supervision-preflight-result.json', Path('preflight-result.json')),
             (source / 'supervision-linux-build.log', Path('linux-build.log')),
             (source / 'supervision-main-smoke.log', Path('main-smoke.log'))]
    failed_regression = ROOT/'reports/online_20261117/supervision-regression-first/verification.json'
    first = json.loads(failed_regression.read_text(encoding='utf8'))
    if first.get('passed') or first.get('exit_code') == 0 or first.get('passed_cases') != 78 or first.get('failed_cases') != ['VerifyPerf']:
        raise RuntimeError('Original failed full regression is not preserved')
    diagnostic_folder = source/'supervision-perf-probe-2'
    diagnostic = json.loads((diagnostic_folder/'report.json').read_text(encoding='utf8'))
    if (not diagnostic.get('original_test_unchanged') or not diagnostic.get('player_data_unchanged')
            or diagnostic.get('sample_count_fixed_before_run') != 2 or len(diagnostic.get('samples',[])) != 2
            or diagnostic.get('source_sha256') != hashlib.sha256((GAME/'tools/VerifyPerf.gd').read_bytes()).hexdigest()):
        raise RuntimeError('Current fixed-count performance diagnosis is missing')
    files.extend((diagnostic_folder/name,Path('performance-diagnostic')/output) for name,output in
                 [('report.json','report.json'),('sample-1.log','sample-1.log'),('sample-2.log','sample-2.log'),('probe.gd','probe.gd.snapshot')])
    failures = []
    private = [config()['password']]
    for name in runs:
        folder = source / name
        report = json.loads((folder / 'report.json').read_text(encoding='utf8'))
        label = Path('world') if name == args.world else Path('failed-worlds') / name
        if name != args.world:
            if report.get('passed') or not report.get('player_data_unchanged'):
                raise RuntimeError('Preserved failure does not have the declared scope')
            failures.append({'run':name,'passed':False,'error':report.get('error'),'online_sources_sha256':report.get('online_sources_sha256')})
        names = ['report.json','certificate-generation.log']
        if name == args.world:
            names += ['backup-manifest.json','restore-report.json','world-a.png','battle-a.png','result-a.png']
        files.extend((folder / item, label / item) for item in names)
        for pattern in ('client-*.log','gateway-*.log','worker-*.log','supervisor-*.log','dbops-*.log'):
            files.extend((path,label / path.name) for path in sorted(folder.glob(pattern)))
        for role in ('authority','gateway'):
            for path in (folder/'credentials-private'/role).glob('*'):
                if not path.is_file():
                    continue
                value = path.read_text(encoding='utf8').strip()
                private.append(value)
                if path.name == 'database-url':
                    password = urllib.parse.urlsplit(value).password
                    if password:
                        private.append(urllib.parse.unquote(password))
    for path in sorted((SERVER/'deploy/systemd').glob('*')):
        if path.is_file():
            files.append((path,Path('deployment-templates')/path.name))
    for path,destination in files:
        if not path.is_file():
            raise RuntimeError('Required evidence missing: ' + destination.as_posix())
        if path.suffix == '.png':
            continue
        data = path.read_bytes()
        if any(value.encode() in data for value in private if value) or re.search(rb'YZR-[A-Za-z0-9_-]{43}|postgres(?:ql)?://|-----BEGIN (?:RSA )?PRIVATE KEY-----',data):
            raise RuntimeError('Private material found; archive withheld')
    target = ROOT/'reports'/('online_'+args.date)/'service-supervision'
    if target.exists():
        raise RuntimeError('Preserve existing evidence; choose another destination')
    target.mkdir(parents=True)
    hashes = {}
    for path,destination in files:
        output = target/destination
        output.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(path,output)
        hashes[destination.as_posix()] = hashlib.sha256(output.read_bytes()).hexdigest()
    result = {'passed':True,'world_run':args.world,'go_passed':len(tests),'go_tests':tests,'world_checks':len(world['checks']),
              'online_sources_sha256':fingerprint,'gateway_binary_sha256':gateway_hash,'servicehost_binary_sha256':host_hash,
              'shared_authority_sources_sha256':world['manifest']['source_sha256'],'supervision_events':events,
              'planned_stop_count':len(stops),'full_regression':'../supervision-regression/verification.json',
              'preserved_first_regression':'../../online_20261117/supervision-regression-first/verification.json',
              'performance_diagnostic_scope':'two predeclared isolated copies with unchanged assertions; does not explain or erase the original 234 ms failure',
              'preserved_failures':failures,'evidence_sha256':hashes,'goal_status':'active','L0_complete':False,
              'production_os_identity_accepted':False,'linux_runtime_accepted':False,'public_deployment_accepted':False,
              'scope':'worktree native Windows role-host recovery, actual hung/killed children, owned-child cleanup, two real TLS clients and atomic reward/new-database restore',
              'limitations':['no server is provisioned yet','foreground Windows development ACL acknowledgement is not OS identity isolation',
                             'Linux binaries only cross-compiled; systemd units and identities still require target-host execution',
                             'explicit verifier restart of a dead host is not OS service-manager restart proof',
                             'mobile/WAN/capacity/production backups and full L0-L6 delivery remain open']}
    (target/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({'target':str(target),'go_passed':len(tests),'world_checks':len(world['checks']),'preserved_failures':len(failures)},ensure_ascii=False))


if __name__ == '__main__':
    main()
