"""Run the real private Godot worker and Go gateway with one shared version/key."""
import os
import json
from pathlib import Path
import re
import secrets
import socket
import ssl
import subprocess
import time
import urllib.request
import urllib.parse
import uuid

from build_room import build
from dev import SERVER, PG, config, environment, client_environment, worker_environment, gateway_environment
from verify_room import RPC


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


class LocalStack:
    def __init__(self, godot: Path, folder: Path, *, isolated_test=False, with_world=True,
                 tls_directory=None, with_admin=False, database_proxy_port=None,
                 migration_mode="auto", require_restricted_database=False):
        if migration_mode not in ("auto", "check") or (require_restricted_database and migration_mode != "check"):
            raise RuntimeError("Restricted runtime requires a separately migrated database")
        self.migration_mode = migration_mode
        self.require_restricted_database = require_restricted_database
        self.godot, self.folder = godot.resolve(), folder.resolve()
        self.folder.mkdir(parents=True, exist_ok=True)
        self.with_world = with_world
        self.tls_directory = Path(tls_directory).resolve() if tls_directory else None
        self.tls_certificate = "server-cert.pem"
        self.database_proxy_port = database_proxy_port
        self.project, self.manifest = build(self.godot) if with_world else (None, {})
        self.env = environment()
        self.env |= {"YUANZHENG_ROOM_SECRET": secrets.token_hex(32),
                     "APPDATA": str(self.folder / "server-userdata"),
                     "LOCALAPPDATA": str(self.folder / "server-userdata")}
        self.worker_port, self.gateway_port = free_port(), free_port()
        while self.worker_port == self.gateway_port:
            self.gateway_port = free_port()
        self.admin_port = free_port() if with_admin else None
        while self.admin_port in (self.worker_port, self.gateway_port):
            self.admin_port = free_port()
        if with_admin:
            self.env["YUANZHENG_ADMIN_TOKEN"] = secrets.token_hex(32)
        self.url = f"{'https' if self.tls_directory else 'http'}://127.0.0.1:{self.gateway_port}"
        self.admin_url = f"http://127.0.0.1:{self.admin_port}" if with_admin else None
        self.rpc = RPC(self.worker_port, self.env["YUANZHENG_ROOM_SECRET"], self.manifest) if with_world else None
        self.schema = "world_" + uuid.uuid4().hex if isolated_test else None
        self.processes, self.logs = {}, []
        self.schema_created = False
        cfg = config()
        self.pg_env = self.env | {"PGPASSWORD": cfg["password"], "PGCLIENTENCODING": "UTF8"}
        self.psql = [str(PG / "psql.exe"), "-h", "127.0.0.1", "-p", str(cfg["port"]),
                     "-U", "yuanzheng", "-d", "yuanzheng_test" if isolated_test else "yuanzheng_dev",
                     "-v", "ON_ERROR_STOP=1", "-Atc"]
        handlers = [urllib.request.ProxyHandler({})]
        if self.tls_directory:
            context = ssl.create_default_context(cafile=str(self.tls_directory / "ca-cert.pem"))
            handlers.append(urllib.request.HTTPSHandler(context=context))
        self.opener = urllib.request.build_opener(*handlers)

    def sql(self, statement):
        # Only callers' fixed SQL and generated UUID identifiers are used here.
        prefix = f'SET search_path TO "{self.schema}"; ' if self.schema_created else ""
        result = subprocess.run(self.psql + [prefix + statement], env=self.pg_env,
                                capture_output=True, text=True, encoding="utf-8", check=True,
                                creationflags=subprocess.CREATE_NO_WINDOW)
        return result.stdout.strip().removeprefix("SET\n").strip()

    def start(self):
        if self.schema:
            self.sql(f'CREATE SCHEMA "{self.schema}"')
            self.schema_created = True
            self.env["YUANZHENG_DATABASE_URL"] = self.env["YUANZHENG_TEST_DATABASE_URL"] + "&search_path=" + self.schema
        if self.database_proxy_port is not None:
            if not 1024 <= self.database_proxy_port <= 65535:
                raise RuntimeError("Test database proxy port must be unprivileged")
            address = urllib.parse.urlsplit(self.env["YUANZHENG_DATABASE_URL"])
            userinfo = address.netloc.rsplit("@", 1)[0]
            self.env["YUANZHENG_DATABASE_URL"] = urllib.parse.urlunsplit((address.scheme, userinfo + f"@127.0.0.1:{self.database_proxy_port}", address.path, address.query, ""))
        if self.with_world:
            self.start_worker()
        self.start_gateway()
        if not self.with_world:
            with self.opener.open(self.url + "/v1/manifest", timeout=5) as response:
                self.manifest = json.load(response)["data"]
        return self

    def client_environment(self, extra):
        return client_environment(self.env, extra)

    def spawn(self, name, command, *, env=None):
        log = (self.folder / f"{name}-{len(self.logs)}.log").open("wb")
        self.logs.append(log)
        self.processes[name] = subprocess.Popen([str(v) for v in command], cwd=SERVER, env=self.env if env is None else env,
                                                stdout=log, stderr=subprocess.STDOUT,
                                                creationflags=subprocess.CREATE_NO_WINDOW)

    def ready(self, name, probe):
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            if self.processes[name].poll() is not None:
                raise RuntimeError(f"{name} exited before ready; inspect generated log")
            try:
                if probe():
                    return
            except (OSError, RuntimeError, ValueError):
                pass
            time.sleep(0.1)
        raise RuntimeError(f"{name} readiness timed out")

    def start_worker(self):
        self.spawn("worker", [self.godot, "--headless", "--path", self.project,
                              "--script", "res://RoomHost.gd", "--", f"--port={self.worker_port}"], env=worker_environment(self.env))
        self.ready("worker", lambda: self.rpc.call("ping").get("ok"))

    def start_gateway(self, *, require_ready=True):
        if not require_ready and not (self.admin_url and self.tls_directory):
            raise RuntimeError("Liveness-only startup is reserved for explicit TLS negative fixtures")
        arguments = [SERVER / "bin/gateway.exe", "--game-root", SERVER.parent,
                     "--listen", f"127.0.0.1:{self.gateway_port}", "--migration-mode", self.migration_mode]
        if self.require_restricted_database:
            arguments += ["--require-restricted-database"]
        if self.with_world:
            arguments += ["--authority-address", f"127.0.0.1:{self.worker_port}"]
        if self.tls_directory:
            arguments += ["--tls-cert", self.tls_directory / self.tls_certificate,
                          "--tls-key", self.tls_directory / "server-key.pem"]
        if self.admin_url:
            arguments += ["--admin-listen", f"127.0.0.1:{self.admin_port}"]
        self.spawn("gateway", arguments, env=gateway_environment(self.env))

        def probe():
            url = self.admin_url or self.url
            request = urllib.request.Request(url + ("/readyz" if require_ready else "/livez"))
            if self.admin_url:
                request.add_header("Authorization", "Bearer " + self.env["YUANZHENG_ADMIN_TOKEN"])
            with self.opener.open(request, timeout=3) as response:
                return response.status == 200
        self.ready("gateway", probe)

    def stop(self, name):
        process = self.processes.pop(name, None)
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)

    def close(self):
        stop_errors = []
        for name in ("gateway", "worker"):
            try:
                self.stop(name)
            except Exception as error:
                stop_errors.append(f"{name}: {error}")
        for log in self.logs:
            log.close()
        if self.schema_created:
            if not re.fullmatch(r"world_[0-9a-f]{32}", self.schema):
                raise RuntimeError("Unsafe generated test schema")
            self.schema_created = False
            self.sql(f'DROP SCHEMA "{self.schema}" CASCADE')
        if stop_errors:
            raise RuntimeError("; ".join(stop_errors))
