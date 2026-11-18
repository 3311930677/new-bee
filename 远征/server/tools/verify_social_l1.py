"""Verify L1-C friends, block, report, chat, and real parties with two Godot clients and 28-table DB restore."""
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
    folder = LOCAL / "verification" / ("social_l1_" + run)
    barriers = folder / "barriers"
    barriers.mkdir(parents=True)
    before = player_snapshot()
    fingerprint = source_fingerprint()
    recovery = DatabaseRecovery(folder)
    tls = recovery.create_tls()
    stack = None
    clients, failures, private = {}, [], []
    report = {
        "run_id": run,
        "online_sources_sha256": fingerprint,
        "gateway_binary_sha256": hashlib.sha256(GATEWAY.read_bytes()).hexdigest(),
        "transport": "https-validating-debug-ca",
        "scope": "L1-C two native Godot clients, friends, block, report, party/room chat, real party lifecycle, and 28-table backup/restore",
    }

    try:
        stack = LocalStack(
            args.godot, folder, tls_directory=tls,
            require_restricted_database=True, migration_mode="check",
        )
        recovery.provision(stack)
        stack.start()
        report["manifest"] = stack.manifest
        for tag in ("a", "b"):
            userdata = folder / ("client-" + tag)
            userdata.mkdir()
            password = secrets.token_hex(20)
            private.append(password)
            env = {
                "APPDATA": str(userdata), "LOCALAPPDATA": str(userdata),
                "YUANZHENG_TEST_URL": stack.url, "YUANZHENG_TEST_CA": str(tls / "ca-cert.pem"),
                "YUANZHENG_TEST_USERNAME": "l1c_" + run[:14] + tag,
                "YUANZHENG_TEST_PASSWORD": password,
                "YUANZHENG_TEST_NICKNAME": ("队长甲" if tag == "a" else "队友乙") + run[:4],
                "YUANZHENG_L1C_PLAYER": tag,
                "YUANZHENG_L1C_BARRIER": str(barriers),
            }
            flags = ["--headless"]
            if tag == "a" and args.capture:
                flags = []
                env["YUANZHENG_L1C_CAPTURE"] = str(folder)
            with (folder / f"client-{tag}.log").open("wb") as output:
                startup = subprocess.STARTUPINFO()
                startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startup.wShowWindow = subprocess.SW_HIDE
                clients[tag] = subprocess.Popen(
                    [str(args.godot.resolve()), *flags, "--path", str(GAME), "--resolution", "480x800",
                     "--max-fps", "60", "--audio-driver", "Dummy", "res://tools/VerifyOnlineSocial.tscn"],
                    stdout=output, stderr=subprocess.STDOUT, startupinfo=startup, env=stack.client_environment(env),
                )

        deadline = time.monotonic() + 180
        while any(process.poll() is None for process in clients.values()):
            if time.monotonic() >= deadline or any(process.poll() not in (0, None) for process in clients.values()):
                raise RuntimeError("a native L1-C client did not finish; inspect its log")
            if any(re.search(r"Parse Error|Compile Error|ONLINE_SOCIAL_FAIL",
                             (folder / f"client-{tag}.log").read_text(encoding="utf8", errors="replace")) for tag in clients):
                raise RuntimeError("native L1-C client reported an error")
            time.sleep(0.1)

        for tag in clients:
            log = (folder / f"client-{tag}.log").read_text(encoding="utf8")
            if not re.search(r"(?m)^ONLINE_SOCIAL_OK\s*$", log) or re.search(r"ERROR:|Parse Error|Compile Error", log) or any(v in log for v in private):
                raise RuntimeError(f"native client {tag} failed clean completion or leaked secrets")

        if args.capture and not (folder / "social-party.png").is_file():
            raise RuntimeError("social-party screenshot missing")

        report["db_counts"] = stack.sql(
            "SELECT (SELECT count(*) FROM parties),(SELECT count(*) FROM party_members),"
            "(SELECT count(*) FROM friendships),(SELECT count(*) FROM player_blocks),"
            "(SELECT count(*) FROM player_reports),(SELECT count(*) FROM chat_messages)"
        ).split("|")
        if report["db_counts"] != ["1", "2", "0", "1", "1", "2"]:
            raise RuntimeError(f"unexpected social DB counts: {report['db_counts']}")

        backup = folder / "backup-private"
        manifest = recovery.command("backup", folder=backup)
        (folder / "backup-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf8")
        recovery.databases.append(recovery.target)
        restored = recovery.command("restore", database=recovery.target, folder=backup)
        (folder / "restore-report.json").write_text(json.dumps(restored, indent=2), encoding="utf8")
        if len(manifest.get("tables", [])) != 28 or len(restored.get("tables_matched_before_session_invalidation", [])) != 28:
            raise RuntimeError(f"expected 28 tables in backup/restore, got {len(manifest.get('tables', []))}")
        report["tables_matched"] = 28
        report["passed"] = True
    except Exception as error:
        failures.append(str(error))
        report["passed"] = False
    finally:
        for tag, process in clients.items():
            if process.poll() is None:
                try:
                    process.kill()
                    process.wait(timeout=10)
                except (OSError, subprocess.TimeoutExpired):
                    failures.append("cleanup failed for client " + tag)
        cleanup_errors = []
        if stack:
            try:
                stack.close()
            except Exception as error:
                cleanup_errors.append("stack: " + type(error).__name__)
        try:
            recovery.close()
        except Exception as error:
            cleanup_errors.append("databases: " + type(error).__name__)
        report["cleanup_errors"] = cleanup_errors
        report["client_exit_codes"] = {tag: p.returncode for tag, p in clients.items()}
        report["player_data_unchanged"] = player_snapshot() == before
        report["online_sources_unchanged"] = source_fingerprint() == fingerprint
        report["errors"] = failures
        report["passed"] = (
            bool(report.get("passed")) and not failures and not cleanup_errors
            and report["client_exit_codes"] == {"a": 0, "b": 0}
            and report["player_data_unchanged"] and report["online_sources_unchanged"]
        )
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf8")
    print(json.dumps({"report": str(folder / "report.json"), **report}, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
