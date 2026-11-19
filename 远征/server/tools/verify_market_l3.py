"""Verify L3 Market M0-M3 (NPC floor, commodity partial consignment, unbound equipment consignment, payouts, face-to-face trade + confirm reset, anomaly alert, and 54-table DB restore)."""
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
    folder = LOCAL / "verification" / ("market_l3_" + run)
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
        "scope": "L3 two native Godot clients: NPC floor buy, M1 partial consignment + cancel return, self-trade alert, M2 unbound equipment consignment, M3 friend face-to-face exchange + reconfirm reset + 54-table backup/restore",
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
                "YUANZHENG_TEST_USERNAME": "l3_" + run[:14] + tag,
                "YUANZHENG_TEST_PASSWORD": password,
                "YUANZHENG_TEST_NICKNAME": ("商贾甲" if tag == "a" else "旅伴乙") + run[:4],
                "YUANZHENG_L3_PLAYER": tag,
                "YUANZHENG_L3_BARRIER": str(barriers),
            }
            flags = ["--headless"]
            if tag == "a" and args.capture:
                flags = []
                env["YUANZHENG_L3_CAPTURE"] = str(folder)
            with (folder / f"client-{tag}.log").open("wb") as output:
                startup = subprocess.STARTUPINFO()
                startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startup.wShowWindow = subprocess.SW_HIDE
                clients[tag] = subprocess.Popen(
                    [str(args.godot.resolve()), *flags, "--path", str(GAME), "--resolution", "480x800",
                     "--max-fps", "60", "--audio-driver", "Dummy", "res://tools/VerifyOnlineMarket.tscn"],
                    stdout=output, stderr=subprocess.STDOUT, startupinfo=startup, env=stack.client_environment(env),
                )

        seeded = False
        deadline = time.monotonic() + 180
        while any(process.poll() is None for process in clients.values()):
            if not seeded and (barriers / "joined-a").is_file() and (barriers / "joined-b").is_file():
                alpha = json.loads((barriers / "joined-a").read_text(encoding="utf8"))
                char_a = alpha["id"]
                sword_uid = str(uuid.uuid4())
                recovery.sql(
                    recovery.database,
                    f"INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,bound,source_transaction,properties) "
                    f"VALUES('{sword_uid}','{char_a}','tpl_sword_forged',1,false,'l3_e2e_seed','{{\"affix\":\"破甲+3\",\"enhance\":2}}'::jsonb);"
                    f"INSERT INTO inventory_ledger(id,character_id,item_uid,transaction_id,operation,delta,quantity_after,equipped_slot) "
                    f"VALUES(gen_random_uuid(),'{char_a}','{sword_uid}','l3_e2e_seed','grant',1,1,NULL);",
                )
                (barriers / "seeded").write_text(json.dumps({"sword_uid": sword_uid}), encoding="utf8")
                seeded = True
            if time.monotonic() >= deadline or any(process.poll() not in (0, None) for process in clients.values()):
                raise RuntimeError("a native L3 client did not finish; inspect its log")
            if any(re.search(r"Parse Error|Compile Error|ONLINE_MARKET_FAIL",
                             (folder / f"client-{tag}.log").read_text(encoding="utf8", errors="replace")) for tag in clients):
                raise RuntimeError("native L3 client reported an error")
            time.sleep(0.1)

        for tag in clients:
            log = (folder / f"client-{tag}.log").read_text(encoding="utf8")
            if not re.search(r"(?m)^ONLINE_MARKET_OK\s*$", log) or re.search(r"ERROR:|Parse Error|Compile Error", log) or any(v in log for v in private):
                raise RuntimeError(f"native client {tag} failed clean completion or leaked secrets")

        if args.capture:
            for png in ("market-board.png", "face-trade.png"):
                if not (folder / png).is_file():
                    raise RuntimeError(f"{png} screenshot missing")

        report["db_counts"] = stack.sql(
            "SELECT (SELECT count(*) FROM market_orders WHERE status='filled'),"
            "(SELECT count(*) FROM market_fills),"
            "(SELECT count(*) FROM market_payouts WHERE status='claimed'),"
            "(SELECT count(*) FROM trade_sessions WHERE status='completed'),"
            "(SELECT count(*) FROM economy_alerts WHERE alert_type='self_trade_attempt')"
        ).split("|")
        if report["db_counts"] != ["1", "2", "3", "1", "1"]:
            raise RuntimeError(f"unexpected L3 DB counts: {report['db_counts']}")

        backup = folder / "backup-private"
        manifest = recovery.command("backup", folder=backup)
        (folder / "backup-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf8")
        recovery.databases.append(recovery.target)
        restored = recovery.command("restore", database=recovery.target, folder=backup)
        (folder / "restore-report.json").write_text(json.dumps(restored, indent=2), encoding="utf8")
        if len(manifest.get("tables", [])) != 54 or len(restored.get("tables_matched_before_session_invalidation", [])) != 54:
            raise RuntimeError(f"expected 54 tables in backup/restore, got {len(manifest.get('tables', []))}")
        report["tables_matched"] = 54
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
        if stack is not None:
            try:
                stack.close()
            except Exception as error:
                cleanup_errors.append("stack: " + type(error).__name__)
        try:
            recovery.close()
        except Exception as error:
            cleanup_errors.append("databases: " + type(error).__name__)
        report["cleanup_errors"] = cleanup_errors
        report["failures"] = failures
        report["player_data_unchanged"] = player_snapshot() == before
        report["online_sources_unchanged"] = source_fingerprint() == fingerprint
        report["client_exit_codes"] = {tag: proc.returncode for tag, proc in clients.items()}
        report["passed"] = (
            bool(report.get("passed"))
            and not failures
            and not cleanup_errors
            and report["player_data_unchanged"]
            and report["online_sources_unchanged"]
            and all(code == 0 for code in report["client_exit_codes"].values())
        )
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf8")
        print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
