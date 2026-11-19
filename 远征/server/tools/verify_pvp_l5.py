"""Verify L5 1v1, 2v2, and 3v3 PvP Arena (sparring, independent ranked + random fill, 6-role RoomHost BattleSim, timeout default action, reconnect rating protection, replay, season/honor shop, and 54-table DB restore)."""
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
    folder = LOCAL / "verification" / ("pvp_l5_" + run)
    barriers = folder / "barriers"
    barriers.mkdir(parents=True)
    before = player_snapshot()
    fingerprint = source_fingerprint()
    recovery = DatabaseRecovery(folder)
    tls = recovery.create_tls()
    stack = None
    clients, failures, private = {}, [], []
    tags = ("a", "b", "c", "d", "e", "f")
    names = {"a": "甲锐", "b": "乙炎", "c": "丙影", "d": "丁盾", "e": "戊剑", "f": "己岚"}
    report = {
        "run_id": run,
        "online_sources_sha256": fingerprint,
        "gateway_binary_sha256": hashlib.sha256(GATEWAY.read_bytes()).hexdigest(),
        "transport": "https-validating-debug-ca",
        "scope": "L5 six native Godot clients: 1v1 sparring + ranked, 2v2 premade vs random-fill + timeout_default + reconnect rating protection, 3v3 6-role + pet RoomHost simulation + cold replay + season/honor shop + 54-table backup/restore",
    }

    try:
        stack = LocalStack(
            args.godot, folder, tls_directory=tls,
            require_restricted_database=True, migration_mode="check",
        )
        recovery.provision(stack)
        stack.start()
        report["manifest"] = stack.manifest
        for tag in tags:
            userdata = folder / ("client-" + tag)
            userdata.mkdir()
            password = secrets.token_hex(20)
            private.append(password)
            env = {
                "APPDATA": str(userdata), "LOCALAPPDATA": str(userdata),
                "YUANZHENG_TEST_URL": stack.url, "YUANZHENG_TEST_CA": str(tls / "ca-cert.pem"),
                "YUANZHENG_TEST_USERNAME": "l5_" + run[:14] + tag,
                "YUANZHENG_TEST_PASSWORD": password,
                "YUANZHENG_TEST_NICKNAME": names[tag] + run[:4],
                "YUANZHENG_L5_PLAYER": tag,
                "YUANZHENG_L5_BARRIER": str(barriers),
            }
            flags = ["--headless"]
            if tag == "a" and args.capture:
                flags = []
                env["YUANZHENG_L5_CAPTURE"] = str(folder)
            with (folder / f"client-{tag}.log").open("wb") as output:
                startup = subprocess.STARTUPINFO()
                startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startup.wShowWindow = subprocess.SW_HIDE
                clients[tag] = subprocess.Popen(
                    [str(args.godot.resolve()), *flags, "--path", str(GAME), "--resolution", "480x800",
                     "--max-fps", "60", "--audio-driver", "Dummy", "res://tools/VerifyOnlinePvp.tscn"],
                    stdout=output, stderr=subprocess.STDOUT, startupinfo=startup, env=stack.client_environment(env),
                )

        seeded = False
        deadline = time.monotonic() + 240
        while any(process.poll() is None for process in clients.values()):
            if not seeded and all((barriers / f"joined-{tag}").is_file() for tag in tags):
                ids = {tag: json.loads((barriers / f"joined-{tag}").read_text(encoding="utf8"))["id"] for tag in tags}
                ca, cb = (ids["a"], ids["b"]) if ids["a"] < ids["b"] else (ids["b"], ids["a"])
                pet_inserts = []
                ledger_inserts = []
                for tag in ("a", "b"):
                    puid = str(uuid.uuid4())
                    cid = ids[tag]
                    pet_inserts.append(f"('{puid}','{cid}','pet_rockturtle',1,'companion',true,'l5_e2e_seed','{{}}'::jsonb)")
                    ledger_inserts.append(f"(gen_random_uuid(),'{cid}','{puid}','l5_e2e_seed_g','grant',1,1,NULL)")
                    ledger_inserts.append(f"(gen_random_uuid(),'{cid}','{puid}','l5_e2e_seed_e','equip',0,1,'companion')")
                recovery.sql(
                    recovery.database,
                    f"INSERT INTO friendships(character_a,character_b) VALUES('{ca}','{cb}') ON CONFLICT DO NOTHING;"
                    f"INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,equipped_slot,bound,source_transaction,properties) VALUES {','.join(pet_inserts)};"
                    f"INSERT INTO inventory_ledger(id,character_id,item_uid,transaction_id,operation,delta,quantity_after,equipped_slot) VALUES {','.join(ledger_inserts)};",
                )
                (barriers / "seeded").write_text(json.dumps(ids), encoding="utf8")
                seeded = True
            if time.monotonic() >= deadline or any(process.poll() not in (0, None) for process in clients.values()):
                raise RuntimeError("a native L5 client did not finish; inspect its log")
            if any(re.search(r"Parse Error|Compile Error|ONLINE_PVP_FAIL",
                             (folder / f"client-{tag}.log").read_text(encoding="utf8", errors="replace")) for tag in clients):
                raise RuntimeError("native L5 client reported an error")
            time.sleep(0.1)

        for tag in clients:
            log = (folder / f"client-{tag}.log").read_text(encoding="utf8")
            if not re.search(r"(?m)^ONLINE_PVP_OK\s*$", log) or re.search(r"ERROR:|Parse Error|Compile Error", log) or any(v in log for v in private):
                raise RuntimeError(f"native client {tag} failed clean completion or leaked secrets")

        if args.capture:
            for png in ("pvp-3v3-match.png", "pvp-replay.png"):
                if not (folder / png).is_file():
                    raise RuntimeError(f"{png} screenshot missing")

        report["db_counts"] = stack.sql(
            "SELECT (SELECT count(*) FROM pvp_matches WHERE status='completed'),"
            "(SELECT count(*) FROM pvp_ratings WHERE wins>0 AND mode='1v1'),"
            "(SELECT count(*) FROM pvp_ratings WHERE wins>0 AND mode='2v2'),"
            "(SELECT count(*) FROM pvp_ratings WHERE wins>0 AND mode='3v3'),"
            "(SELECT coalesce(sum(timeout_defaults_applied),0) FROM pvp_matches),"
            "(SELECT count(*) FROM pvp_honor_ledger)"
        ).split("|")
        if int(report["db_counts"][0]) < 4 or report["db_counts"][1] != "1" or int(report["db_counts"][2]) < 2 or int(report["db_counts"][3]) < 3 or int(report["db_counts"][4]) < 1 or int(report["db_counts"][5]) < 4:
            raise RuntimeError(f"unexpected L5 DB counts: {report['db_counts']}")

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
        report["client_exit_codes"] = {tag: p.returncode for tag, p in clients.items()}
        report["passed"] = (
            bool(report.get("passed"))
            and not failures
            and not cleanup_errors
            and report["player_data_unchanged"]
            and report["online_sources_unchanged"]
            and all(code == 0 for code in report["client_exit_codes"].values())
        )
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
