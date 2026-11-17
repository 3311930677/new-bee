"""Two real validating-TLS Godot identity pages and a restricted DB runtime."""
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    run_id = uuid.uuid4().hex
    folder = LOCAL / "verification" / ("identity_" + run_id)
    folder.mkdir(parents=True)
    barrier = folder / "barriers"
    barrier.mkdir()
    recovery = DatabaseRecovery(folder)
    tls = recovery.create_tls()
    stack = LocalStack(args.godot, folder, tls_directory=tls, migration_mode="check", require_restricted_database=True)
    before, fingerprint = player_snapshot(), source_fingerprint()
    report = {"run_id": run_id, "scope": "real desktop TLS identity UI, local custom-avatar fallback, restricted PostgreSQL runtime, two clients seeing server-owned identity; not mobile/WAN/L1 social acceptance",
              "online_sources_sha256": fingerprint, "gateway_binary_sha256": hashlib.sha256((SERVER / "bin/gateway.exe").read_bytes()).hexdigest(),
              "transport": "https-validating-debug-ca"}
    clients, logs, checks, private = {}, [], [], []

    def check(condition, words):
        checks.append({"name": words, "passed": bool(condition)})
        if not condition:
            raise RuntimeError(words)

    try:
        recovery.provision(stack)
        stack.start()
        report["manifest"] = stack.manifest
        private += recovery.private + [stack.env["YUANZHENG_ROOM_SECRET"]]
        for tag in ("a", "b"):
            userdata = folder / ("client-" + tag)
            userdata.mkdir()
            password = secrets.token_hex(20)
            private.append(password)
            extra = {"APPDATA": str(userdata), "LOCALAPPDATA": str(userdata), "YUANZHENG_TEST_URL": stack.url,
                     "YUANZHENG_TEST_CA": str(tls / "ca-cert.pem"), "YUANZHENG_TEST_USERNAME": "identity_" + run_id[:14] + tag,
                     "YUANZHENG_TEST_PASSWORD": password, "YUANZHENG_TEST_NICKNAME": ("同行甲" if tag == "a" else "同行乙") + run_id[:5],
                     "YUANZHENG_IDENTITY_TAG": tag, "YUANZHENG_IDENTITY_BARRIER": str(barrier)}
            flags = ["--headless"]
            if args.capture and tag == "a":
                flags = []
                extra["YUANZHENG_IDENTITY_CAPTURE"] = str(folder)
            log = (folder / ("client-" + tag + ".log")).open("wb")
            logs.append(log)
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = subprocess.SW_HIDE
            clients[tag] = subprocess.Popen([str(args.godot.resolve()), *flags, "--path", str(SERVER.parent), "--resolution", "480x800", "--audio-driver", "Dummy", "res://tools/VerifyOnlineIdentity.tscn"],
                                            env=stack.client_environment(extra), stdout=log, stderr=subprocess.STDOUT, startupinfo=startup)
        deadline = time.monotonic() + 180
        while any(process.poll() is None for process in clients.values()) and time.monotonic() < deadline:
            time.sleep(.15)
        report["client_exit_codes"] = {}
        for tag, process in clients.items():
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
            report["client_exit_codes"][tag] = process.returncode
            output = (folder / ("client-" + tag + ".log")).read_text(encoding="utf8", errors="replace")
            errors = [line for line in output.splitlines() if any(pattern in line for pattern in ("SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR:", "ONLINE_IDENTITY_FAIL"))]
            check(process.returncode == 0 and re.search(r"(?m)^ONLINE_IDENTITY_OK\s*$", output) is not None and not errors, "real client " + tag + " completes identity UI and other-player profile")
        counts = stack.sql("SELECT (SELECT count(*) FROM accounts),(SELECT count(*) FROM characters WHERE deleted_at IS NULL),(SELECT count(*) FROM wallets WHERE gold=100),(SELECT count(*) FROM wallet_ledger),(SELECT count(*) FROM sessions WHERE revoked_at IS NULL),(SELECT count(*) FROM room_leases l JOIN sessions s ON s.id=l.session_id WHERE s.revoked_at IS NULL)").split("|")
        check(counts == ["2", "2", "2", "2", "0", "0"], "independent SQL confirms two restored characters, starter ledgers and no active sessions/leases")
        identities = stack.sql("SELECT role_id,gender_id,avatar_id FROM characters ORDER BY role_id").splitlines()
        check(identities == ["ck|male|role_fz", "zs|female|role_fs"], "independent SQL confirms gender and portrait remain separate from profession")
        check(all((barrier / ("finished-" + tag)).is_file() for tag in ("a", "b")), "both real clients complete reciprocal profile inspection")
        captures = ["identity-create.png", "identity-profiles.png"]
        if args.capture:
            check(all((folder / name).is_file() for name in captures), "actual 480x800 creation and profile captures exist")
        report |= {"passed": True, "database_counts": counts, "database_identities": identities,
                   "offline_actions": recovery.events, "clients": [json.loads((barrier / ("finished-" + tag)).read_text(encoding="utf8")) for tag in ("a", "b")]}
    except Exception as error:
        report |= {"passed": False, "error": str(error)}
    finally:
        for process in clients.values():
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)
        for log in logs:
            log.close()
        stack.close()
        recovery.close()
        report["worker_errors"] = [line for path in folder.glob("worker-*.log") for line in path.read_text(encoding="utf8", errors="replace").splitlines() if any(pattern in line for pattern in ("SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR:"))]
        report["private_values_in_logs"] = any(value in path.read_text(encoding="utf8", errors="replace") for path in folder.glob("*.log") for value in private)
        report["recovery_code_in_logs"] = any(re.search(r"YZR-[A-Za-z0-9_-]{43}", path.read_text(encoding="utf8", errors="replace")) for path in folder.glob("*.log"))
        report["checks"] = checks
        report["player_data_unchanged"] = player_snapshot() == before
        report["online_sources_unchanged"] = source_fingerprint() == fingerprint
        report["passed"] = bool(report.get("passed")) and not report["worker_errors"] and not report["private_values_in_logs"] and not report["recovery_code_in_logs"] and report["player_data_unchanged"] and report["online_sources_unchanged"]
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf8")
    print(json.dumps({"report": str(folder / "report.json"), **report}, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
