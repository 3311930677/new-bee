"""Run the position stream through the live gateway and two Godot clients."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import secrets
import subprocess
import time
import uuid

from database_recovery import DatabaseRecovery
from dev import LOCAL, SERVER
from local_stack import LocalStack
from verify_clients import player_snapshot
from verify_world import source_fingerprint

GAME = SERVER.parent
GATEWAY = SERVER / "bin/gateway.exe"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    run = uuid.uuid4().hex
    folder = LOCAL / "verification" / ("positions_" + run)
    barriers = folder / "barriers"
    barriers.mkdir(parents=True)
    tls = DatabaseRecovery(folder).create_tls()
    stack = LocalStack(args.godot, folder, isolated_test=True, tls_directory=tls)
    before = player_snapshot()
    fingerprint = source_fingerprint()
    report = {"run_id": run, "online_sources_sha256": fingerprint, "transport": "https-validating-debug-ca",
              "gateway_binary_sha256": hashlib.sha256(GATEWAY.read_bytes()).hexdigest(),
              "scope": "two native Godot clients, rendering, input prediction, AOI exit and return, logout"}
    clients, failures = {}, []
    private = []
    try:
        stack.start()
        for tag in ("a", "b"):
            userdata = folder / ("client-" + tag)
            userdata.mkdir()
            password = secrets.token_hex(20)
            private.append(password)
            env = {
                "APPDATA": str(userdata), "LOCALAPPDATA": str(userdata),
                "YUANZHENG_TEST_URL": stack.url, "YUANZHENG_TEST_CA": str(tls / "ca-cert.pem"),
                "YUANZHENG_TEST_USERNAME": "positions_" + run[:14] + tag, "YUANZHENG_TEST_PASSWORD": password,
                "YUANZHENG_TEST_NICKNAME": ("近游甲" if tag == "a" else "近游乙") + run[:5],
                "YUANZHENG_POSITION_PLAYER": tag, "YUANZHENG_POSITION_BARRIER": str(barriers),
            }
            flags = ["--headless"]
            if tag == "a" and args.capture:
                flags = []
                env["YUANZHENG_POSITION_CAPTURE"] = str(folder)
            with (folder / f"client-{tag}.log").open("wb") as output:
                startup = subprocess.STARTUPINFO()
                startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startup.wShowWindow = subprocess.SW_HIDE
                clients[tag] = subprocess.Popen(
                    [str(args.godot.resolve()), *flags, "--path", str(GAME), "--resolution", "480x800",
                     "--max-fps", "60", "--audio-driver", "Dummy", "res://tools/VerifyOnlinePositions.tscn"],
                    stdout=output, stderr=subprocess.STDOUT, startupinfo=startup, env=stack.client_environment(env),
                )
        deadline = time.monotonic() + 160
        while any(process.poll() is None for process in clients.values()):
            if time.monotonic() >= deadline or any(process.poll() not in (0, None) for process in clients.values()):
                raise RuntimeError("a native position client did not finish; inspect its log")
            if any(re.search(r"Parse Error|Compile Error|ONLINE_POSITIONS_FAIL",
                             (folder / f"client-{tag}.log").read_text(encoding="utf8", errors="replace")) for tag in clients):
                raise RuntimeError("native position client reported an error")
            time.sleep(0.1)
        for tag in clients:
            log = (folder / f"client-{tag}.log").read_text(encoding="utf8")
            if (not re.search(r"(?m)^ONLINE_POSITIONS_OK\s*$", log) or re.search(r"ERROR:|Parse Error|Compile Error", log)
                    or any(value in log for value in private)):
                raise RuntimeError("native client did not complete cleanly")
        report["world_observations"] = {name: json.loads((barriers / name).read_text(encoding="utf8"))
                                        for name in ("observed-a", "observed-b", "away", "hidden", "returned", "logged-out")}
        report["database_counts"] = stack.sql(
            "SELECT (SELECT count(*) FROM accounts),(SELECT count(*) FROM room_instances),"
            "(SELECT count(*) FROM sessions WHERE revoked_at IS NULL)").split("|")
        if report["database_counts"] != ["2", "1", "0"]:
            raise RuntimeError("native room, identity or logout evidence mismatch")
        if args.capture and not (folder / "position-together.png").is_file():
            raise RuntimeError("real screen capture is missing")
    except (OSError, ValueError, RuntimeError) as error:
        failures.append(str(error))
    finally:
        for tag, process in clients.items():
            if process.poll() is None:
                try:
                    process.kill()
                    process.wait(timeout=10)
                except (OSError, subprocess.TimeoutExpired):
                    failures.append("cleanup failed for owned client " + tag)
        try:
            stack.close()
        except Exception as error:
            failures.append("isolated stack cleanup: " + type(error).__name__)
        report["client_exit_codes"] = {tag: process.returncode for tag, process in clients.items()}
        report["player_data_unchanged"] = player_snapshot() == before
        report["online_sources_unchanged"] = source_fingerprint() == fingerprint
        report["errors"] = failures
        report["passed"] = (not failures and report["client_exit_codes"] == {"a": 0, "b": 0}
                            and report["player_data_unchanged"] and report["online_sources_unchanged"])
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
