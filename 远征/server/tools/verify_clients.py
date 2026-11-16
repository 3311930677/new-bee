"""Real gateway + PostgreSQL + two isolated Godot clients; no mocked API."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import time
import urllib.request
import uuid

from dev import SERVER, ROOT, LOCAL, PG, environment, client_environment


def player_snapshot():
    root = Path(os.environ["APPDATA"]) / "Godot" / "app_userdata"
    result = {}
    if root.exists():
        for path in root.rglob("*"):
            if path.is_file() and not (path.parent.name == "logs" and path.name.startswith("godot")):
                result[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    run_id = uuid.uuid4().hex
    folder = LOCAL / "verification" / run_id
    folder.mkdir(parents=True)
    schema = "e2e_" + run_id
    env = environment()
    from dev import config
    cfg = config()
    pg_env = env | {"PGPASSWORD": cfg["password"]}
    psql = [str(PG / "psql.exe"), "-h", "127.0.0.1", "-p", str(cfg["port"]), "-U", "yuanzheng", "-d", "yuanzheng_test", "-v", "ON_ERROR_STOP=1", "-Atc"]
    subprocess.run(psql + [f"CREATE SCHEMA {schema}"], env=pg_env, check=True, capture_output=True)
    env["YUANZHENG_DATABASE_URL"] = env["YUANZHENG_TEST_DATABASE_URL"] + "&search_path=" + schema
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    url = f"http://127.0.0.1:{port}"
    before = player_snapshot()
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))  # Explicit loopback-only HTTP.
    outcomes = []
    gateway_log = (folder / "gateway.log").open("wb")
    gateway = None
    report = {"run_id": run_id, "schema": schema, "scope": "L0-A real accounts and characters; not map or battle acceptance"}
    try:
        gateway = subprocess.Popen([str(SERVER / "bin" / "gateway.exe"), "--game-root", str(SERVER.parent), "--listen", f"127.0.0.1:{port}"], cwd=SERVER, env=env, stdout=gateway_log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        deadline = time.monotonic() + 120
        while True:
            if gateway.poll() is not None:
                raise RuntimeError("Gateway exited before ready; inspect gateway.log")
            try:
                with opener.open(url + "/healthz", timeout=2) as response:
                    if response.status == 200:
                        break
            except Exception:
                if time.monotonic() >= deadline:
                    raise RuntimeError("Gateway readiness timed out")
                time.sleep(0.2)

        def client(index):
            tag = "a" if index == 0 else "b"
            local = folder / ("client_" + tag)
            local.mkdir()
            nickname = ("联测甲" if index == 0 else "联测乙") + run_id[:7]
            client_env = client_environment(env, {"APPDATA": str(local), "LOCALAPPDATA": str(local), "YUANZHENG_TEST_URL": url, "YUANZHENG_TEST_USERNAME": "test_" + run_id[:16] + tag, "YUANZHENG_TEST_PASSWORD": secrets.token_hex(24), "YUANZHENG_TEST_NICKNAME": nickname, "YUANZHENG_TEST_ROLE": "zs" if index == 0 else "fz"})
            flags = []
            capture = folder / ("client_" + tag + ".png")
            if args.capture and index == 0:
                client_env["YUANZHENG_CAPTURE_PATH"] = str(capture)
            else:
                flags.append("--headless")
            command = [str(args.godot.resolve()), *flags, "--path", str(SERVER.parent), "--resolution", "480x800", "--audio-driver", "Dummy", "res://tools/VerifyOnlineHttp.tscn"]
            log = folder / ("client_" + tag + ".log")
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = subprocess.SW_HIDE
            started = time.monotonic()
            with log.open("wb") as out:
                proc = subprocess.Popen(command, env=client_env, cwd=ROOT, stdout=out, stderr=subprocess.STDOUT, startupinfo=startup)
                try:
                    code = proc.wait(timeout=150)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
                    code = -1
            text = log.read_text(encoding="utf-8", errors="replace")
            errors = re.findall(r"(?m)^.*(?:SCRIPT ERROR|Parse Error|Compile Error|FAIL:|ONLINE_HTTP_FAIL).*$", text)
            passed = code == 0 and re.search(r"(?m)^ONLINE_HTTP_OK\s*$", text) is not None and not errors
            if args.capture and index == 0:
                passed = passed and capture.exists()
            return {"client": tag, "passed": passed, "exit_code": code, "elapsed_seconds": round(time.monotonic() - started, 2), "errors": errors, "log": str(log), "capture": str(capture) if capture.exists() else None}

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = list(pool.map(client, range(2)))
        result = subprocess.run(psql + [f"SELECT (SELECT count(*) FROM {schema}.accounts), (SELECT count(*) FROM {schema}.characters), (SELECT count(*) FROM {schema}.wallets WHERE gold=100), (SELECT count(*) FROM {schema}.wallet_ledger WHERE delta=100), (SELECT count(*) FROM {schema}.sessions WHERE revoked_at IS NULL)"], env=pg_env, capture_output=True, text=True, check=True)
        counts = [int(value) for value in result.stdout.strip().split("|")]
        report |= {"clients": outcomes, "database_counts": counts, "expected_counts": [2, 2, 2, 2, 0]}
        report["passed"] = all(o["passed"] for o in outcomes) and counts == [2, 2, 2, 2, 0]
    except Exception as error:
        report |= {"passed": False, "error": str(error), "clients": outcomes}
    finally:
        if gateway is not None and gateway.poll() is None:
            gateway.terminate()
            gateway.wait(timeout=10)
        gateway_log.close()
        # Generated schema is the only database object removed.
        if not re.fullmatch(r"e2e_[0-9a-f]{32}", schema):
            raise RuntimeError("Unsafe cleanup schema")
        subprocess.run(psql + [f"DROP SCHEMA {schema} CASCADE"], env=pg_env, check=True, capture_output=True)
        report["player_data_unchanged"] = player_snapshot() == before
        report["passed"] = bool(report.get("passed")) and report["player_data_unchanged"]
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
