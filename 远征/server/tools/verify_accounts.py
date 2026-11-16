"""Real Godot account UI against Go/PostgreSQL; no private server env in client."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import uuid

from dev import LOCAL, SERVER
from local_stack import LocalStack
from verify_clients import player_snapshot
from verify_world import source_fingerprint


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    folder = LOCAL / "verification" / ("accounts_" + uuid.uuid4().hex)
    folder.mkdir(parents=True)
    stack = LocalStack(args.godot, folder, isolated_test=True, with_world=False)
    before, fingerprint = player_snapshot(), source_fingerprint()
    report = {"scope": "real desktop account UI, deletion/recovery, nickname alternatives and saved recovery-code password reset; not email, mobile or public deployment acceptance", "online_sources_sha256": fingerprint,
              "gateway_binary_sha256": hashlib.sha256((SERVER / "bin/gateway.exe").read_bytes()).hexdigest()}
    process = None
    log = (folder / "client.log").open("wb")
    try:
        stack.start()
        userdata = folder / "client-userdata"
        userdata.mkdir()
        env = stack.client_environment({"APPDATA": str(userdata), "LOCALAPPDATA": str(userdata),
                                        "YUANZHENG_TEST_URL": stack.url,
                                        "YUANZHENG_TEST_USERNAME": "accounts_" + uuid.uuid4().hex[:16],
                                        "YUANZHENG_TEST_PASSWORD": secrets.token_hex(20),
                                        "YUANZHENG_TEST_NEXT_PASSWORD": secrets.token_hex(20)})
        flags = ["--headless"]
        if args.capture:
            flags = []
            env["YUANZHENG_ACCOUNTS_CAPTURE"] = str(folder)
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = subprocess.SW_HIDE
        process = subprocess.Popen([str(args.godot.resolve()), *flags, "--path", str(SERVER.parent),
                                    "--resolution", "480x800", "--audio-driver", "Dummy",
                                    "res://tools/VerifyOnlineAccounts.tscn"], env=env,
                                   stdout=log, stderr=subprocess.STDOUT, startupinfo=startup)
        try:
            code = process.wait(timeout=240)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code = -1
        text = (folder / "client.log").read_text(encoding="utf-8", errors="replace")
        errors = [line for line in text.splitlines() if any(marker in line for marker in ("SCRIPT ERROR", "Parse Error", "Compile Error", "ONLINE_ACCOUNTS_FAIL", "ERROR:"))]
        counts = stack.sql("SELECT (SELECT count(*) FROM accounts),(SELECT count(*) FROM characters WHERE deleted_at IS NULL),(SELECT count(*) FROM wallets WHERE gold=100),(SELECT count(*) FROM wallet_ledger),(SELECT count(*) FROM security_notifications),(SELECT count(*) FROM security_notifications WHERE acknowledged_at IS NULL),(SELECT count(*) FROM sessions WHERE revoked_at IS NULL)").split("|")
        secret_in_log = any(re.search(r"YZR-[A-Za-z0-9_-]{43}", path.read_text(encoding="utf-8", errors="replace"))
                            for path in folder.glob("*.log"))
        captures = ["recovery-code-masked", "character-management", "character-recovery", "password-recovered-masked"]
        captured = not args.capture or all((folder / (name + ".png")).exists() for name in captures)
        report |= {"exit_code": code, "errors": errors, "database_counts": counts,
                   "expected_counts": ["1", "1", "1", "1", "2", "0", "0"],
                   "recovery_code_in_logs": secret_in_log, "requested_captures_exist": captured,
                   "passed": code == 0 and re.search(r"(?m)^ONLINE_ACCOUNTS_OK\s*$", text) is not None and not errors and counts == ["1", "1", "1", "1", "2", "0", "0"] and not secret_in_log and captured,
                   "manifest": stack.manifest}
    except Exception as error:
        report |= {"passed": False, "error": str(error)}
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        log.close()
        stack.close()
        report["player_data_unchanged"] = player_snapshot() == before
        report["online_sources_unchanged"] = source_fingerprint() == fingerprint
        report["passed"] = bool(report.get("passed")) and report["player_data_unchanged"] and report["online_sources_unchanged"]
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"report": str(folder / "report.json"), **report}, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
