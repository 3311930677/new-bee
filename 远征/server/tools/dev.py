"""Workspace-local PostgreSQL and Go commands; never touches a system database."""
import argparse
import json
import os
import re
from pathlib import Path
import secrets
import socket
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

SERVER = Path(__file__).resolve().parents[1]
ROOT = SERVER.parents[1]
RUNTIME = ROOT / "tools" / "online-runtime"
LOCAL = SERVER / ".local"
PG = RUNTIME / "pgsql" / "bin"
GO = RUNTIME / "go" / "bin" / "go.exe"
PORT = 55432


def command(args, *, env=None, check=True, logfile=None):
    result = subprocess.run([str(a) for a in args], cwd=SERVER, env=env, check=False,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace",
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
    if result.stdout:
        print(result.stdout, end="", flush=True)
    if logfile:
        logfile.parent.mkdir(parents=True, exist_ok=True)
        logfile.write_text(result.stdout, encoding="utf-8")
    if check and result.returncode:
        raise subprocess.CalledProcessError(result.returncode, result.args)
    return result


def config():
    path = LOCAL / "config.json"
    if not path.exists():
        raise RuntimeError("Run dev.py init first")
    return json.loads(path.read_text(encoding="utf-8"))


def provision():
    if not (PG / "initdb.exe").exists():
        raise RuntimeError("Portable PostgreSQL missing; run bootstrap_runtime.py")
    LOCAL.mkdir(parents=True, exist_ok=True)
    cfg_path = LOCAL / "config.json"
    if not cfg_path.exists():
        cfg_path.write_text(json.dumps({"password": secrets.token_hex(24), "port": PORT}), encoding="utf-8")
    cfg = config()
    data = LOCAL / "pgdata"
    if not (data / "PG_VERSION").exists():
        pw = LOCAL / "init-password.txt"
        pw.write_text(cfg["password"], encoding="utf-8")
        try:
            command([PG / "initdb.exe", "-D", data, "-U", "yuanzheng", "--encoding=UTF8", "--locale=C", "--auth=scram-sha-256", "--pwfile", pw])
        finally:
            pw.unlink(missing_ok=True)
    status = command([PG / "pg_ctl.exe", "status", "-D", data], check=False)
    if status.returncode != 0:
        with socket.socket() as probe:
            if probe.connect_ex(("127.0.0.1", cfg["port"])) == 0:
                raise RuntimeError("Dedicated database port is occupied; existing service was not changed")
        command([PG / "pg_ctl.exe", "start", "-D", data, "-l", LOCAL / "postgres.log", "-o", f"-h 127.0.0.1 -p {cfg['port']}", "-w"])
    env = os.environ | {"PGPASSWORD": cfg["password"], "PGCLIENTENCODING": "UTF8"}
    for name in ("yuanzheng_dev", "yuanzheng_test"):
        exists = subprocess.run([str(PG / "psql.exe"), "-h", "127.0.0.1", "-p", str(cfg["port"]), "-U", "yuanzheng", "-d", "postgres", "-Atc", f"SELECT 1 FROM pg_database WHERE datname='{name}'"], env=env, capture_output=True, text=True, check=True)
        if exists.stdout.strip() != "1":
            command([PG / "createdb.exe", "-h", "127.0.0.1", "-p", str(cfg["port"]), "-U", "yuanzheng", name], env=env)
    print(f"Local PostgreSQL ready on 127.0.0.1:{cfg['port']}; credentials remain in ignored .local/config.json", flush=True)


def environment(proxy=None):
    cfg = config()
    env = os.environ.copy()
    for kind, name in (("DATABASE", "yuanzheng_dev"), ("TEST_DATABASE", "yuanzheng_test")):
        env[f"YUANZHENG_{kind}_URL"] = f"postgres://yuanzheng:{cfg['password']}@127.0.0.1:{cfg['port']}/{name}?sslmode=disable"
    env["GOPATH"] = str(RUNTIME / "gopath")
    env["GOCACHE"] = str(RUNTIME / "gocache")
    env["GOTOOLCHAIN"] = "local"
    if proxy:
        env |= {"HTTP_PROXY": proxy, "HTTPS_PROXY": proxy, "ALL_PROXY": proxy}
    # Loopback is always local; external dependency downloads still use the configured proxy.
    env["NO_PROXY"] = ",".join(filter(None, [env.get("NO_PROXY", ""), "127.0.0.1", "localhost", "::1"]))
    return env


def client_environment(base, extra):
    # Test clients receive only their own account credentials and endpoint.
    # Database URLs, worker MAC keys and future server-only settings stay private.
    public = {key: value for key, value in base.items()
              if not key.startswith("YUANZHENG_") and key != "PGPASSWORD"}
    private = {"YUANZHENG_DATABASE_URL", "YUANZHENG_TEST_DATABASE_URL", "YUANZHENG_ROOM_SECRET", "YUANZHENG_ADMIN_TOKEN", "YUANZHENG_TLS_KEY", "PGPASSWORD",
               "YUANZHENG_DBADMIN_URL", "YUANZHENG_MIGRATION_DATABASE_URL", "YUANZHENG_BACKUP_DATABASE_URL",
               "YUANZHENG_MIGRATOR_PASSWORD", "YUANZHENG_RUNTIME_PASSWORD", "YUANZHENG_BACKUP_PASSWORD"}
    if private.intersection(extra):
        raise RuntimeError("Server-only environment cannot be passed to a client")
    return public | extra


def completed_go_tests(path):
    events = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.startswith("{")]
    module = re.search(r"(?m)^module\s+(\S+)", (SERVER / "go.mod").read_text(encoding="utf-8")).group(1)
    expected = {module + "/" + path.parent.relative_to(SERVER).as_posix() + "::" + name
                for directory in ("cmd", "internal") for path in (SERVER / directory).rglob("*_test.go")
                for name in re.findall(r"(?m)^func (Test[A-Za-z0-9_]+)\(", path.read_text(encoding="utf-8"))}
    passed = {e["Package"] + "::" + e["Test"] for e in events
              if e["Action"] == "pass" and e.get("Test") and "/" not in e["Test"]}
    if not expected or passed != expected or any(e["Action"] == "fail" for e in events):
        raise RuntimeError(f"Incomplete Go test evidence: {len(passed)}/{len(expected)} package-qualified tests completed")
    return sorted(passed)


def worker_environment(base):
    public = {key: value for key, value in base.items()
              if not key.startswith("YUANZHENG_") and key != "PGPASSWORD"}
    # The worker signs simulation responses; it never owns DB or admin access.
    return public | {"YUANZHENG_ROOM_SECRET": base.get("YUANZHENG_ROOM_SECRET", "")}


def gateway_environment(base):
    # Offline migration/backup credentials and the test superuser URL never
    # belong in a running gateway, even when its own URL is restricted.
    allowed = {"YUANZHENG_DATABASE_URL", "YUANZHENG_ROOM_SECRET", "YUANZHENG_ADMIN_TOKEN"}
    return {key: value for key, value in base.items()
            if (not key.startswith("YUANZHENG_") or key in allowed) and not key.upper().startswith("PG")}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["init", "stop", "status", "deps", "test", "build", "run"])
    parser.add_argument("--proxy", default=None)
    args = parser.parse_args()
    if args.action == "init":
        provision()
        return
    if args.action in ("stop", "status"):
        command([PG / "pg_ctl.exe", args.action, "-D", LOCAL / "pgdata"])
        return
    env = environment(args.proxy)
    if args.action == "deps":
        command([GO, "mod", "tidy"], env=env)
    elif args.action == "test":
        path = LOCAL / "verification" / "go-integration.jsonl"
        command([GO, "test", "-p=1", "-timeout=35m", "./...", "-count=1", "-v", "-json"], env=env, logfile=path)
        completed_go_tests(path)
    elif args.action == "build":
        (SERVER / "bin").mkdir(exist_ok=True)
        command([GO, "build", "-trimpath", "-o", "bin/gateway.exe", "./cmd/gateway"], env=env)
        command([GO, "build", "-trimpath", "-o", "bin/authoritycheck.exe", "./cmd/authoritycheck"], env=env)
        command([GO, "build", "-trimpath", "-o", "bin/devcert.exe", "./cmd/devcert"], env=env)
        command([GO, "build", "-trimpath", "-o", "bin/dbops.exe", "./cmd/dbops"], env=env)
        command([GO, "build", "-trimpath", "-o", "bin/servicehost.exe", "./cmd/servicehost"], env=env)
    elif args.action == "run":
        command([SERVER / "bin" / "gateway.exe", "--game-root", SERVER.parent], env=env)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
