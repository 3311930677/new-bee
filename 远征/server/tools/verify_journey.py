"""Exercise the full town journey through two actual Godot clients and HTTPS."""
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


CHARACTER_SUMMARY = """
SELECT c.role_id,p.story_step,w.gold,c.experience,
       (SELECT count(*) FROM quest_events q WHERE q.character_id=c.id),
       (SELECT count(*) FROM inventory_items i WHERE i.character_id=c.id AND quantity>0),
       (SELECT count(*) FROM inventory_items i WHERE i.character_id=c.id AND equipped_slot IS NOT NULL),
       (SELECT quantity FROM inventory_items i WHERE i.character_id=c.id AND template_id='itm_potion_hp_s'),
       (SELECT count(*) FROM inventory_ledger i WHERE i.character_id=c.id AND operation='grant'),
       (SELECT count(*) FROM inventory_ledger i WHERE i.character_id=c.id AND operation='consume'),
       (SELECT count(*) FROM inventory_ledger i WHERE i.character_id=c.id AND operation='equip'),
       (SELECT count(*) FROM battles b WHERE b.character_id=c.id AND result='victory' AND acknowledged_at IS NOT NULL)
FROM characters c JOIN character_progress p ON p.character_id=c.id JOIN wallets w ON w.character_id=c.id
ORDER BY c.role_id
"""

EXPECTED_CHARACTERS = ["fz|complete|125|15|8|4|3|2|4|1|3|2", "zs|complete|125|15|8|4|3|2|4|1|3|2"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    run_id = uuid.uuid4().hex
    folder = LOCAL / "verification" / ("journey_" + run_id)
    barriers = folder / "barriers"
    barriers.mkdir(parents=True)
    recovery = DatabaseRecovery(folder)
    tls = recovery.create_tls()
    stack = LocalStack(args.godot, folder, tls_directory=tls, migration_mode="check", require_restricted_database=True)
    before = player_snapshot()
    fingerprint = source_fingerprint()
    report = {
        "run_id": run_id,
        "scope": "two native Godot clients, distinct roles, real town journey, owned items, pet battle, re-login and offline restore",
        "online_sources_sha256": fingerprint,
        "gateway_binary_sha256": hashlib.sha256((SERVER / "bin/gateway.exe").read_bytes()).hexdigest(),
        "manifest": stack.manifest,
        "transport": "https-validating-debug-ca",
    }
    clients, logs, checks = {}, [], []
    private = recovery.private + [stack.env["YUANZHENG_ROOM_SECRET"]]

    def check(condition, words):
        checks.append({"name": words, "passed": bool(condition)})
        if not condition:
            raise RuntimeError(words)

    try:
        recovery.provision(stack)
        stack.start()
        for tag in ("a", "b"):
            userdata = folder / ("client-" + tag)
            userdata.mkdir()
            password = secrets.token_hex(20)
            private.append(password)
            extra = {
                "APPDATA": str(userdata),
                "LOCALAPPDATA": str(userdata),
                "YUANZHENG_TEST_URL": stack.url,
                "YUANZHENG_TEST_CA": str(tls / "ca-cert.pem"),
                "YUANZHENG_TEST_USERNAME": "journey_" + run_id[:14] + tag,
                "YUANZHENG_TEST_PASSWORD": password,
                "YUANZHENG_TEST_NICKNAME": ("边城甲" if tag == "a" else "边城乙") + run_id[:5],
                "YUANZHENG_JOURNEY_TAG": tag,
                "YUANZHENG_JOURNEY_BARRIER": str(barriers),
            }
            flags = ["--headless"]
            if args.capture and tag == "a":
                flags = []
                extra["YUANZHENG_JOURNEY_CAPTURE"] = str(folder)
            output = (folder / ("client-" + tag + ".log")).open("wb")
            logs.append(output)
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = subprocess.SW_HIDE
            clients[tag] = subprocess.Popen(
                [str(args.godot.resolve()), *flags, "--path", str(SERVER.parent), "--resolution", "480x800",
                 "--audio-driver", "Dummy", "res://tools/VerifyOnlineJourney.tscn"],
                env=stack.client_environment(extra), stdout=output, stderr=subprocess.STDOUT, startupinfo=startup,
            )
        deadline = time.monotonic() + 210
        while any(process.poll() is None for process in clients.values()) and time.monotonic() < deadline:
            if any(process.poll() not in (None, 0) for process in clients.values()):
                break
            if any("Parse Error:" in (folder / ("client-" + tag + ".log")).read_text(encoding="utf8", errors="replace")
                   for tag in clients):
                break
            time.sleep(0.15)
        report["client_exit_codes"] = {tag: process.poll() for tag, process in clients.items()}
        for tag, code in report["client_exit_codes"].items():
            output = (folder / ("client-" + tag + ".log")).read_text(encoding="utf8", errors="replace")
            clean = not any(marker in output for marker in ("SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR:", "ONLINE_JOURNEY_FAIL"))
            check(code == 0 and clean and re.search(r"(?m)^ONLINE_JOURNEY_OK\s*$", output), "native journey completed by client " + tag)
        report["clients"] = [json.loads((barriers / ("finished-" + tag)).read_text(encoding="utf8")) for tag in ("a", "b")]
        characters = stack.sql(CHARACTER_SUMMARY).splitlines()
        check(characters == EXPECTED_CHARACTERS, "each owner has eight quest events, correct gear, two medicines, one real consumption and two victories")
        counts = stack.sql("""SELECT (SELECT count(*) FROM accounts),(SELECT count(DISTINCT room_id) FROM room_leases),
                             (SELECT count(*) FROM sessions WHERE revoked_at IS NULL)""").split("|")
        check(counts == ["2", "1", "0"], "independent SQL confirms two accounts, one town and no active sessions")
        report["characters"] = characters
        report["session_counts"] = counts
        if args.capture:
            captures = ("journey-supplies.png", "journey-companion.png", "journey-coop-entry.png")
            check(all((folder / name).is_file() for name in captures), "three real 480x800 journey screenshots exist")
        stack.stop("gateway")
        backup = folder / "backup-private"
        manifest = recovery.command("backup", folder=backup)
        (folder / "backup-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf8")
        recovery.databases.append(recovery.target)
        restored = recovery.command("restore", database=recovery.target, folder=backup)
        (folder / "restore-report.json").write_text(json.dumps(restored, indent=2), encoding="utf8")
        restored_characters = recovery.sql(recovery.target, CHARACTER_SUMMARY).splitlines()
        tables = {row["name"]: row["rows"] for row in manifest["tables"]}
        check(restored.get("ready_for_review") and len(restored["tables_matched_before_session_invalidation"]) == 34
              and tables.get("inventory_ledger") == 16 and tables.get("quest_events") == 16 and restored_characters == characters,
              "new database restore preserves both actual inventories and completed quest history")
        report["database_restore"] = {
            "tables_matched": len(restored["tables_matched_before_session_invalidation"]),
            "restored_characters": restored_characters,
            "inventory_history_rows": tables["inventory_ledger"],
            "quest_history_rows": tables["quest_events"],
        }
        report["passed"] = True
    except Exception as error:
        report.update({"passed": False, "error": str(error)})
    finally:
        for process in clients.values():
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)
        for output in logs:
            output.close()
        cleanup_errors = []
        for name, cleanup in (("service stack", stack.close), ("disposable databases", recovery.close)):
            try:
                cleanup()
            except Exception as error:
                cleanup_errors.append(name + ": " + type(error).__name__)
        worker_errors = [line for path in folder.glob("worker-*.log")
                         for line in path.read_text(encoding="utf8", errors="replace").splitlines()
                         if any(token in line for token in ("SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR:"))]
        logs_text = "\n".join(path.read_text(encoding="utf8", errors="replace") for path in folder.glob("*.log"))
        report.update({
            "checks": checks,
            "offline_actions": recovery.events,
            "cleanup_errors": cleanup_errors,
            "worker_errors": worker_errors,
            "private_values_in_logs": any(value in logs_text for value in private) or bool(re.search(r"YZR-[A-Za-z0-9_-]{43}|postgres(?:ql)?://", logs_text)),
            "player_data_unchanged": player_snapshot() == before,
            "online_sources_unchanged": source_fingerprint() == fingerprint,
        })
        report["passed"] = (bool(report["passed"]) and not cleanup_errors and not worker_errors and not report["private_values_in_logs"]
                            and report["player_data_unchanged"] and report["online_sources_unchanged"])
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf8")
    print(json.dumps({"report": str(folder / "report.json"), **report}, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
