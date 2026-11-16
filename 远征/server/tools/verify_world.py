"""Two real Godot clients + Go + PostgreSQL + Godot authority, with crash recovery."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import time
import uuid

from dev import LOCAL, SERVER
from local_stack import LocalStack
from verify_clients import player_snapshot


def source_fingerprint():
    paths = []
    for directory in (SERVER / "cmd", SERVER / "internal", SERVER / "room", SERVER / "tools", SERVER.parent / "src/online"):
        paths.extend(path for path in directory.rglob("*") if path.suffix in (".go", ".sql", ".gd", ".py", ".godot"))
    paths.extend((SERVER.parent / "src/ui").glob("Online*.*"))
    paths.extend((SERVER.parent / "tools").glob("VerifyOnline*.*"))
    digest = hashlib.sha256()
    for path in sorted(set(p for p in paths if p.suffix != ".uid")):
        digest.update(path.relative_to(SERVER.parent).as_posix().encode() + b"\0" + path.read_bytes())
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    run_id = uuid.uuid4().hex
    folder = LOCAL / "verification" / ("world_" + run_id)
    folder.mkdir(parents=True)
    barrier = folder / "barriers"
    barrier.mkdir()
    stack = LocalStack(args.godot, folder, isolated_test=True)
    before = player_snapshot()
    clients, logs = {}, []
    checks = []
    fingerprint = source_fingerprint()
    report = {"run_id": run_id, "scope": "L0 desktop two-client same town, authority combat, atomic rewards and restart recovery; not mobile/WAN/PvP acceptance", "manifest": stack.manifest,
              "online_sources_sha256": fingerprint,
              "gateway_binary_sha256": hashlib.sha256((SERVER / "bin/gateway.exe").read_bytes()).hexdigest()}

    def check(condition, name):
        checks.append({"name": name, "passed": bool(condition)})
        if not condition:
            raise RuntimeError(name)

    def wait_markers(names, seconds=150):
        deadline = time.monotonic() + seconds
        while not all((barrier / name).exists() for name in names):
            if any(proc.poll() is not None for proc in clients.values()):
                raise RuntimeError("A real client exited before the recovery barrier; inspect client logs")
            if time.monotonic() > deadline:
                raise RuntimeError("Recovery barrier timed out: " + ",".join(names))
            time.sleep(0.1)

    try:
        stack.start()
        for tag in ("a", "b"):
            userdata = folder / ("client-" + tag)
            userdata.mkdir()
            env = stack.env | {"APPDATA": str(userdata), "LOCALAPPDATA": str(userdata),
                               "YUANZHENG_TEST_URL": stack.url,
                               "YUANZHENG_TEST_USERNAME": "world_" + run_id[:16] + tag,
                               "YUANZHENG_TEST_PASSWORD": secrets.token_hex(20),
                               "YUANZHENG_TEST_NICKNAME": ("同行甲" if tag == "a" else "同行乙") + run_id[:5],
                               "YUANZHENG_WORLD_TAG": tag, "YUANZHENG_WORLD_BARRIER": str(barrier)}
            flags = ["--headless"]
            if args.capture and tag == "a":
                flags = []
                env["YUANZHENG_WORLD_CAPTURE"] = str(folder)
            log = (folder / f"client-{tag}.log").open("wb")
            logs.append(log)
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = subprocess.SW_HIDE
            clients[tag] = subprocess.Popen([str(args.godot.resolve()), *flags, "--path", str(SERVER.parent),
                                             "--resolution", "480x800", "--audio-driver", "Dummy",
                                             "res://tools/VerifyOnlineWorld.tscn"], env=env,
                                            stdout=log, stderr=subprocess.STDOUT, startupinfo=startup)
        wait_markers(["battle-a", "battle-b"], 90)
        room_counts = stack.sql("SELECT count(DISTINCT room_id),count(*) FROM room_leases").split("|")
        check(room_counts == ["1", "2"], "two real clients hold exclusive leases in one town")
        stack.sql("CREATE FUNCTION reject_world_reward() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.reason='battle_reward' THEN RAISE EXCEPTION 'injected award interruption'; END IF; RETURN NEW; END $$; CREATE TRIGGER reject_world_reward BEFORE INSERT ON wallet_ledger FOR EACH ROW EXECUTE FUNCTION reject_world_reward(); UPDATE battles SET started_at=now()")
        (barrier / "combat-start").write_text("ready", encoding="utf-8")
        wait_markers(["fault-a", "fault-b"])
        counts = stack.sql("SELECT (SELECT count(*) FROM battle_results),(SELECT count(*) FROM battle_reward_claims),(SELECT count(*) FROM wallet_ledger WHERE reason='battle_reward'),(SELECT sum(gold) FROM wallets),(SELECT count(*) FROM battle_inputs WHERE accepted IS NULL)").split("|")
        check(counts == ["0", "0", "0", "200", "0"], "failed real victory transactions leave no partial reward, claim or input")
        report["fault_database_counts"] = counts
        previous_epoch = stack.rpc.call("ping")["epoch"]
        stack.stop("gateway")
        stack.stop("worker")
        stack.start_worker()
        stack.start_gateway()
        check(previous_epoch != stack.rpc.call("ping")["epoch"], "gateway and real authority process restart before reward retry")
        stack.sql("DROP TRIGGER reject_world_reward ON wallet_ledger")
        (barrier / "repair-complete").write_text("ready", encoding="utf-8")
        for tag, process in clients.items():
            try:
                code = process.wait(timeout=150)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                code = -1
            text = (folder / f"client-{tag}.log").read_text(encoding="utf-8", errors="replace")
            errors = [line for line in text.splitlines() if any(marker in line for marker in ("SCRIPT ERROR", "Parse Error", "Compile Error", "ONLINE_WORLD_FAIL", "ERROR:"))]
            check(code == 0 and re.search(r"(?m)^ONLINE_WORLD_OK\s*$", text) is not None and not errors,
                  f"client {tag} completes real movement, combat, reward retry and reconnect")
        final = stack.sql("SELECT (SELECT count(*) FROM accounts),(SELECT count(*) FROM wallets WHERE gold=110),(SELECT count(*) FROM battle_results WHERE result='victory' AND gold=10 AND experience=5),(SELECT count(*) FROM wallet_ledger WHERE reason='battle_reward'),(SELECT count(*) FROM battle_reward_claims),(SELECT count(*) FROM battles WHERE acknowledged_at IS NOT NULL),(SELECT count(*) FROM sessions WHERE revoked_at IS NULL)").split("|")
        check(final == ["2", "2", "2", "2", "2", "2", "0"], "database independently confirms two victories, exactly one reward each and revoked sessions")
        report |= {"passed": True, "final_database_counts": final,
                   "clients": [json.loads((barrier / f"finished-{tag}").read_text(encoding="utf-8")) for tag in ("a", "b")]}
        if args.capture:
            check(all((folder / f"{name}-a.png").exists() for name in ("world", "battle", "result")), "actual 480x800 world, battle and result screenshots exist")
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
        report["worker_errors"] = [line for path in folder.glob("worker-*.log")
                                   for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
                                   if any(marker in line for marker in ("SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR:"))]
        report["player_data_unchanged"] = player_snapshot() == before
        report["checks"] = checks
        report["online_sources_unchanged"] = source_fingerprint() == fingerprint
        report["passed"] = bool(report.get("passed")) and all(c["passed"] for c in checks) and report["player_data_unchanged"] and report["online_sources_unchanged"] and not report["worker_errors"]
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"report": str(folder / "report.json"), **report}, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
