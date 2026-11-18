"""Real per-role service hosts for the Windows closed-environment drill.

Production OS identities are deliberately not inferred from these foreground
processes. All credentials/config/state are private run artifacts, not reports.
"""
import json
from pathlib import Path
import shutil
import subprocess
import time
import urllib.error
import urllib.request

from dev import SERVER, client_environment
from local_stack import LocalStack
from owned_windows_process import OwnedProcess


class SupervisedStack(LocalStack):
    def __init__(self, godot, folder, *, tls_directory):
        super().__init__(godot, folder, tls_directory=tls_directory, with_admin=True,
                         migration_mode='check', require_restricted_database=True)
        if not tls_directory:
            raise RuntimeError('Supervised verifier requires validating TLS')
        self.host = SERVER / 'bin/servicehost.exe'
        if not self.host.is_file():
            raise RuntimeError('Build the role service host before verifying')
        self.states = {name: self.folder / ('state-' + name) for name in ('gateway', 'worker')}
        self.executables = {'gateway': SERVER / 'bin/gateway.exe', 'worker': self.godot}
        self.content = self.folder / 'gateway-content'
        (self.content / 'data').mkdir(parents=True)
        for source in sorted((SERVER.parent / 'data').glob('*.json')):
            shutil.copy2(source, self.content / 'data' / source.name)
        self.child_copies, self.supervision_events = {}, []
        self.planned_stops = []

    def state(self, name):
        path = self.states[name] / 'status.json'
        try:
            status = json.loads(path.read_text(encoding='utf8'))
        except (OSError, ValueError):
            return {}
        process = self.processes.get(name)
        if process is None or process.poll() is not None or status.get('supervisor_pid') != process.pid:
            return {}
        return status

    def write_configuration(self, name):
        role = 'authority' if name == 'worker' else 'gateway'
        credentials = self.folder / 'credentials-private' / role
        credentials.mkdir(parents=True, exist_ok=True, mode=0o700)
        values = {'room-secret': self.env['YUANZHENG_ROOM_SECRET']}
        if name == 'gateway':
            values.update({'database-url': self.env['YUANZHENG_DATABASE_URL'], 'admin-token': self.env['YUANZHENG_ADMIN_TOKEN']})
        for key, value in values.items():
            path = credentials / key
            path.write_text(value, encoding='utf8')
            path.chmod(0o600)
        configuration = {'version': 1, 'kind': role, 'executable': str(self.executables[name]),
                         'game_root': str(self.project if name == 'worker' else self.content),
                         'state_directory': str(self.states[name]), 'listen': f'127.0.0.1:{self.worker_port if name == "worker" else self.gateway_port}',
                         'content_version': self.manifest['content_version'], 'ruleset_version': self.manifest['ruleset_version'],
                         'policy': {'probe_interval_ms': 250, 'probe_timeout_ms': 1000, 'failure_threshold': 2, 'liveness_grace_ms': 5000,
                                    'startup_timeout_sec': 120, 'stop_timeout_sec': 10, 'restart_window_sec': 300,
                                    'restart_burst': 5, 'backoff_initial_ms': 2000, 'backoff_maximum_ms': 8000}}
        if name == 'gateway':
            configuration.update({'authority_address': f'127.0.0.1:{self.worker_port}', 'admin_listen': f'127.0.0.1:{self.admin_port}',
                                  'tls_certificate': str(self.tls_directory / self.tls_certificate), 'tls_private_key': str(self.tls_directory / 'server-key.pem')})
        path = self.folder / (role + '-host-config.json')
        path.write_text(json.dumps(configuration, indent=2), encoding='utf8')
        return path, credentials

    def start_role(self, name):
        path, credentials = self.write_configuration(name)
        log = (self.folder / f'supervisor-{name}-{len(self.logs)}.log').open('wb')
        self.logs.append(log)
        command = [str(self.host), '--config', str(path), '--credentials-directory', str(credentials), '--development-acl']
        self.processes[name] = subprocess.Popen(command, cwd=SERVER, env=client_environment(self.env, {}),
                                                stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        self.ready(name, lambda: bool(self.state(name).get('ready')))
        self.sync_logs()

    def start_worker(self):
        self.start_role('worker')

    def start_gateway(self, *, require_ready=True):
        if not require_ready:
            raise RuntimeError('Negative TLS fixtures use the direct stack')
        self.start_role('gateway')

    def sync_logs(self):
        for name, directory in self.states.items():
            for source in sorted(directory.glob('child-*.log')):
                if source not in self.child_copies:
                    self.child_copies[source] = self.folder / f'{name}-{len(self.child_copies)}.log'
                shutil.copyfile(source, self.child_copies[source])

    def stop(self, name):
        process = self.processes.get(name)
        if process is not None and process.poll() is None:
            try:
                result = subprocess.run([str(self.host), '--request-stop', str(self.states[name])], cwd=SERVER,
                                        env=client_environment(self.env, {}), capture_output=True, timeout=15,
                                        creationflags=subprocess.CREATE_NO_WINDOW)
                if result.returncode:
                    raise RuntimeError(f'Private supervised stop request exited {result.returncode}')
            except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
                process.kill()
                process.wait(timeout=10)
                raise RuntimeError('Private supervised stop request failed') from error
            try:
                code = process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
                raise RuntimeError('Role host failed to stop its owned child')
            status = json.loads((self.states[name] / 'status.json').read_text(encoding='utf8'))
            if code != 0 or status.get('phase') != 'stopped' or status.get('child_pid') != 0:
                raise RuntimeError('Planned stop was not terminal and clean')
            self.planned_stops.append({'role': name, 'exit_code': code, 'phase': status['phase'], 'child_pid': status['child_pid']})
        self.processes.pop(name, None)
        self.sync_logs()

    def hard_host_recovery(self, name):
        status = self.state(name)
        process = self.processes[name]
        with OwnedProcess(status['child_pid'], process.pid, self.executables[name]) as child:
            process.kill()
            process.wait(timeout=10)
            if not child.wait(5):
                raise RuntimeError('Supervisor death left its owned child alive')
        self.processes.pop(name)
        self.start_role(name)
        current = self.state(name)
        event = {'kind': 'host_death', 'role': name, 'child_reaped': True, 'host_manager_restart': 'verifier explicit restart; OS service-manager restart not accepted here',
                 'old_child_pid': status['child_pid'], 'new_child_pid': current['child_pid']}
        self.supervision_events.append(event)
        return event

    def fault_child(self, name, kind):
        previous = self.state(name)
        process = self.processes[name]
        with OwnedProcess(previous['child_pid'], process.pid, self.executables[name]) as child:
            started = time.monotonic()
            threads = 0
            if kind == 'hang':
                threads = child.suspend()
            elif kind == 'exit':
                child.terminate()
            else:
                raise RuntimeError('Unknown owned-process fault')
            gateway_before = self.state('gateway')
            dependency_observed = False
            deadline = time.monotonic() + 40
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise RuntimeError('Role supervisor exited instead of recovering its child')
                current = self.state(name)
                if name == 'worker' and not dependency_observed:
                    request = urllib.request.Request(self.admin_url + '/readyz', headers={'Authorization': 'Bearer ' + self.env['YUANZHENG_ADMIN_TOKEN']})
                    try:
                        with self.opener.open(request, timeout=3) as response:
                            code = response.status
                    except urllib.error.HTTPError as error:
                        code = error.code
                    except OSError:
                        code = 0
                    live_request = urllib.request.Request(self.admin_url + '/livez', headers={'Authorization': 'Bearer ' + self.env['YUANZHENG_ADMIN_TOKEN']})
                    try:
                        with self.opener.open(live_request, timeout=3) as response:
                            live = response.status == 200
                    except OSError:
                        live = False
                    gateway = self.state('gateway')
                    dependency_observed = code == 503 and live and gateway.get('child_pid') == gateway_before.get('child_pid') and gateway.get('generation') == gateway_before.get('generation')
                if current.get('generation', 0) > previous['generation'] and current.get('child_pid') and current.get('ready'):
                    if not child.wait(5):
                        raise RuntimeError('Replaced child still has a live original process handle')
                    if current['generation'] != previous['generation'] + 1:
                        raise RuntimeError('Fault drill observed an unexpected extra restart')
                    event = {'kind': kind, 'role': name, 'old_child_pid': previous['child_pid'], 'new_child_pid': current['child_pid'],
                             'host_pid_unchanged': process.pid == current['supervisor_pid'], 'generation_before': previous['generation'],
                             'generation_after': current['generation'], 'suspended_threads': threads,
                             'gateway_dependency_failure_without_restart': dependency_observed if name == 'worker' else None,
                             'recovery_seconds': round(time.monotonic() - started, 3)}
                    if name == 'worker' and not dependency_observed:
                        raise RuntimeError('Gateway readiness/dependency isolation was not observed')
                    self.supervision_events.append(event)
                    self.sync_logs()
                    return event
                time.sleep(.05)
            raise RuntimeError('Owned child did not recover within the watchdog drill deadline')

    def close(self):
        try:
            super().close()
        finally:
            self.sync_logs()
