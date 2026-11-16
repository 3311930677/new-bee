"""Run the real private Godot worker and Go gateway with one shared version/key."""
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import time
import urllib.request
import uuid

from build_room import build
from dev import SERVER, PG, config, environment
from verify_room import RPC


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


class LocalStack:
    def __init__(self, godot: Path, folder: Path, *, isolated_test=False):
        self.godot, self.folder = godot.resolve(), folder.resolve()
        self.folder.mkdir(parents=True, exist_ok=True)
        self.project, self.manifest = build(self.godot)
        self.env = environment()
        self.env |= {"YUANZHENG_ROOM_SECRET": secrets.token_hex(32),
                     "APPDATA": str(self.folder / "server-userdata"),
                     "LOCALAPPDATA": str(self.folder / "server-userdata")}
        self.worker_port, self.gateway_port = free_port(), free_port()
        while self.worker_port == self.gateway_port:
            self.gateway_port = free_port()
        self.url = f"http://127.0.0.1:{self.gateway_port}"
        self.rpc = RPC(self.worker_port, self.env["YUANZHENG_ROOM_SECRET"], self.manifest)
        self.schema = "world_" + uuid.uuid4().hex if isolated_test else None
        self.processes, self.logs = {}, []
        self.schema_created = False
        cfg = config()
        self.pg_env = self.env | {"PGPASSWORD": cfg["password"], "PGCLIENTENCODING": "UTF8"}
        self.psql = [str(PG / "psql.exe"), "-h", "127.0.0.1", "-p", str(cfg["port"]),
                     "-U", "yuanzheng", "-d", "yuanzheng_test" if isolated_test else "yuanzheng_dev",
                     "-v", "ON_ERROR_STOP=1", "-Atc"]
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

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
        self.start_worker()
        self.start_gateway()
        return self

    def spawn(self, name, command):
        log = (self.folder / f"{name}-{len(self.logs)}.log").open("wb")
        self.logs.append(log)
        self.processes[name] = subprocess.Popen([str(v) for v in command], cwd=SERVER, env=self.env,
                                                stdout=log, stderr=subprocess.STDOUT,
                                                creationflags=subprocess.CREATE_NO_WINDOW)

    def ready(self, name, probe):
        deadline = time.monotonic() + 45
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
                              "--script", "res://RoomHost.gd", "--", f"--port={self.worker_port}"])
        self.ready("worker", lambda: self.rpc.call("ping").get("ok"))

    def start_gateway(self):
        self.spawn("gateway", [SERVER / "bin/gateway.exe", "--game-root", SERVER.parent,
                               "--listen", f"127.0.0.1:{self.gateway_port}",
                               "--authority-address", f"127.0.0.1:{self.worker_port}"])

        def probe():
            with self.opener.open(self.url + "/healthz", timeout=2) as response:
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
        for name in ("gateway", "worker"):
            self.stop(name)
        for log in self.logs:
            log.close()
        if self.schema_created:
            if not re.fullmatch(r"world_[0-9a-f]{32}", self.schema):
                raise RuntimeError("Unsafe generated test schema")
            self.schema_created = False
            self.sql(f'DROP SCHEMA "{self.schema}" CASCADE')
