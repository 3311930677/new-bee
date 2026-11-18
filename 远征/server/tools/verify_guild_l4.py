"""Verify L4 Remaining Co-op (ore_vein), 2nd World Boss (shenyuan_port), Guilds (warehouse non-tradeable guard, permissions, decor, audit logs, leave cooldown), and 46-table DB restore."""
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
    folder = LOCAL / "verification" / ("guild_l4_" + run)
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
        "scope": "L4 two native Godot clients: shenyuan_port 2nd world boss, ore_vein co-op puzzle, guild lifecycle/permissions/decor/non-tradeable warehouse/audit/leave cooldown + 46-table backup/restore",
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
                "YUANZHENG_TEST_USERNAME": "l4_" + run[:14] + tag,
                "YUANZHENG_TEST_PASSWORD": password,
                "YUANZHENG_TEST_NICKNAME": ("星火团长" if tag == "a" else "守望执事") + run[:4],
                "YUANZHENG_L4_PLAYER": tag,
                "YUANZHENG_L4_BARRIER": str(barriers),
            }
            flags = ["--headless"]
            if tag == "a" and args.capture:
                flags = []
                env["YUANZHENG_L4_CAPTURE"] = str(folder)
            with (folder / f"client-{tag}.log").open("wb") as output:
                startup = subprocess.STARTUPINFO()
                startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startup.wShowWindow = subprocess.SW_HIDE
                clients[tag] = subprocess.Popen(
                    [str(args.godot.resolve()), *flags, "--path", str(GAME), "--resolution", "480x800",
                     "--max-fps", "60", "--audio-driver", "Dummy", "res://tools/VerifyOnlineGuild.tscn"],
                    stdout=output, stderr=subprocess.STDOUT, startupinfo=startup, env=stack.client_environment(env),
                )

        seeded = False
        deadline = time.monotonic() + 180
        while any(process.poll() is None for process in clients.values()):
            if not seeded and (barriers / "joined-a").is_file() and (barriers / "joined-b").is_file():
                alpha = json.loads((barriers / "joined-a").read_text(encoding="utf8"))
                char_a = alpha["id"]
                grain_uid = str(uuid.uuid4())
                timber_uid = str(uuid.uuid4())
                recovery.sql(
                    recovery.database,
                    f"UPDATE characters SET level=5 WHERE id IN ('{char_a}','{json.loads((barriers / 'joined-b').read_text(encoding='utf8'))['id']}');"
                    f"UPDATE character_progress SET story_step='complete';"
                    f"INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,bound,source_transaction,properties) "
                    f"VALUES('{grain_uid}','{char_a}','mat_grain',2,false,'l4_e2e_seed','{{}}'::jsonb),"
                    f"('{timber_uid}','{char_a}','mat_guild_timber',5,true,'l4_e2e_seed','{{\"origin\":\"coop\"}}'::jsonb);"
                    f"INSERT INTO inventory_ledger(id,character_id,item_uid,transaction_id,operation,delta,quantity_after,equipped_slot) "
                    f"VALUES(gen_random_uuid(),'{char_a}','{grain_uid}','l4_e2e_seed','grant',2,2,NULL),"
                    f"(gen_random_uuid(),'{char_a}','{timber_uid}','l4_e2e_seed','grant',5,5,NULL);",
                )
                (barriers / "seeded").write_text(json.dumps({"grain_uid": grain_uid, "timber_uid": timber_uid}), encoding="utf8")
                seeded = True
            if time.monotonic() >= deadline or any(process.poll() not in (0, None) for process in clients.values()):
                raise RuntimeError("a native L4 client did not finish; inspect its log")
            if any(re.search(r"Parse Error|Compile Error|ONLINE_GUILD_FAIL",
                             (folder / f"client-{tag}.log").read_text(encoding="utf8", errors="replace")) for tag in clients):
                raise RuntimeError("native L4 client reported an error")
            time.sleep(0.1)

        for tag in clients:
            log = (folder / f"client-{tag}.log").read_text(encoding="utf8")
            if not re.search(r"(?m)^ONLINE_GUILD_OK\s*$", log) or re.search(r"ERROR:|Parse Error|Compile Error", log) or any(v in log for v in private):
                raise RuntimeError(f"native client {tag} failed clean completion or leaked secrets")

        if args.capture:
            for png in ("shenyuan-boss.png", "guild-hall.png"):
                if not (folder / png).is_file():
                    raise RuntimeError(f"{png} screenshot missing")

        report["db_counts"] = stack.sql(
            "SELECT (SELECT count(*) FROM guilds WHERE member_cap>30),"
            "(SELECT count(*) FROM guild_members),"
            "(SELECT count(*) FROM guild_audit_logs),"
            "(SELECT count(*) FROM guild_member_cooldowns),"
            "(SELECT count(*) FROM world_boss_events WHERE map_id='shenyuan_port')"
        ).split("|")
        if report["db_counts"][0] != "1" or report["db_counts"][1] != "1" or int(report["db_counts"][2]) < 5 or report["db_counts"][3] != "1" or report["db_counts"][4] != "1":
            raise RuntimeError(f"unexpected L4 DB counts: {report['db_counts']}")

        backup = folder / "backup-private"
        manifest = recovery.command("backup", folder=backup)
        (folder / "backup-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf8")
        recovery.databases.append(recovery.target)
        restored = recovery.command("restore", database=recovery.target, folder=backup)
        (folder / "restore-report.json").write_text(json.dumps(restored, indent=2), encoding="utf8")
        if len(manifest.get("tables", [])) != 46 or len(restored.get("tables_matched_before_session_invalidation", [])) != 46:
            raise RuntimeError(f"expected 46 tables in backup/restore, got {len(manifest.get('tables', []))}")
        report["tables_matched"] = 46
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
