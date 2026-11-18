"""Verify an actual isolated Godot authority process and signed private RPC."""
import argparse
import hashlib
import hmac
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import time
import uuid

from build_room import build
from dev import LOCAL, SERVER, worker_environment
from verify_clients import player_snapshot


class RPC:
    def __init__(self, port, secret, manifest):
        self.port, self.secret, self.manifest = port, secret.encode(), manifest

    def frame(self, method, args):
        body = json.dumps({"method": method, "args": args, "content_version": self.manifest["content_version"], "ruleset_version": self.manifest["ruleset_version"]}, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        nonce, timestamp = str(uuid.uuid4()), int(time.time())
        signed = f"{timestamp}|{nonce}|{body}".encode()
        return {"body": body, "nonce": nonce, "issued_at": timestamp, "signature": hmac.new(self.secret, signed, hashlib.sha256).hexdigest()}

    def exchange(self, frame):
        with socket.create_connection(("127.0.0.1", self.port), timeout=4) as conn:
            conn.sendall(json.dumps(frame, ensure_ascii=False).encode() + b"\n")
            raw = conn.makefile("rb").readline(2 * 1024 * 1024 + 1)
        if not raw:
            return None
        if len(raw) > 2 * 1024 * 1024:
            raise RuntimeError("room response exceeded limit")
        reply = json.loads(raw)
        if reply["nonce"] != frame["nonce"]:
            raise RuntimeError("response nonce mismatch")
        expected = hmac.new(self.secret, (reply["nonce"] + "|" + reply["body"]).encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, reply["signature"]):
            raise RuntimeError("response authentication failed")
        return json.loads(reply["body"])

    def call(self, method, args=None):
        result = self.exchange(self.frame(method, args or {}))
        if result is None:
            raise RuntimeError("signed request unexpectedly rejected")
        return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    project, manifest = build(args.godot)
    folder = LOCAL / "verification" / ("room_" + uuid.uuid4().hex)
    folder.mkdir(parents=True)
    secret = secrets.token_hex(32)
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    rpc = RPC(port, secret, manifest)
    before = player_snapshot()
    env = worker_environment(os.environ | {"APPDATA": str(folder / "userdata"), "LOCALAPPDATA": str(folder / "userdata"), "YUANZHENG_ROOM_SECRET": secret})
    checks = []
    report = {"scope": "isolated shared BattleSim + private signed RPC; not public multiplayer acceptance", "manifest": manifest}
    log = (folder / "room.log").open("wb")
    process = None

    def check(condition, name):
        checks.append({"name": name, "passed": bool(condition)})
        if not condition:
            raise RuntimeError(name)

    try:
        for tag, variable in (("database", "YUANZHENG_DATABASE_URL"), ("management", "YUANZHENG_ADMIN_TOKEN")):
            invalid = subprocess.run([str(args.godot.resolve()), "--headless", "--path", str(project), "--script", "res://RoomHost.gd", "--", f"--port={port}"],
                env=env | {variable: "forbidden-test-context"}, capture_output=True, text=True, encoding="utf-8", timeout=15, creationflags=subprocess.CREATE_NO_WINDOW)
            (folder / ("forbidden-" + tag + ".log")).write_text(invalid.stdout + invalid.stderr, encoding="utf-8")
            check(invalid.returncode == 1 and "ROOM_START_FAILED forbidden persistence or management credentials" in invalid.stderr and "forbidden-test-context" not in invalid.stdout + invalid.stderr,
                  "authority refuses inherited " + tag + " credentials without logging their values")
        process = subprocess.Popen([str(args.godot.resolve()), "--headless", "--path", str(project), "--script", "res://RoomHost.gd", "--", f"--port={port}"], env=env, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        deadline = time.monotonic() + 30
        while True:
            if process.poll() is not None:
                raise RuntimeError("Authority process exited before ready")
            try:
                ping = rpc.call("ping")
                check(ping.get("ok") and ping.get("content_version") == manifest["content_version"], "private worker starts with exact content version")
                break
            except (OSError, RuntimeError):
                if time.monotonic() > deadline:
                    raise
                time.sleep(0.1)
        checker = SERVER / "bin" / "authoritycheck.exe"
        if not checker.exists():
            raise RuntimeError("Build the Go authoritycheck binary with dev.py build first")
        checked = subprocess.run([str(checker), "--address", f"127.0.0.1:{port}", "--content-version", manifest["content_version"], "--ruleset-version", manifest["ruleset_version"]], env=env, capture_output=True, text=True, encoding="utf-8", timeout=15)
        (folder / "go-authority-check.json").write_text(checked.stdout, encoding="utf-8")
        go_health = json.loads(checked.stdout) if checked.returncode == 0 else {}
        check(checked.returncode == 0 and go_health.get("ok") and go_health.get("content_version") == manifest["content_version"], "production Go RPC client authenticates a real Godot process")
        report["go_health"] = go_health
        invalid = rpc.frame("ping", {})
        invalid["signature"] = "0" * 64
        check(rpc.exchange(invalid) is None, "unauthenticated private request rejected")
        replay = rpc.frame("ping", {})
        check(rpc.exchange(replay).get("ok") and rpc.exchange(replay) is None, "replayed private nonce rejected")
        battle_id = str(uuid.uuid4())
        config = {"battle_id": battle_id, "role_id": "zs", "monster_id": "mon_wolf", "level": 1, "seed": 414233}
        started = rpc.call("battle.start", config)
        check(started.get("ok") and started["state"]["tick"] == 0, "shared BattleSim starts only on authority process")
        state = started["state"]
        until = time.monotonic() + 6
        while state["tick"] < 65 and time.monotonic() < until:
            time.sleep(0.15)
            state = rpc.call("battle.snapshot", {"battle_id": battle_id})["state"]
        check(state["tick"] >= 65, "authority advances by its own monotonic clock")
        action = {"action": "attack"}
        first = rpc.call("battle.command", {"battle_id": battle_id, "sequence": 1, "action": action})
        check(first.get("ok") and first.get("accepted"), "authority validates and executes manual attack")
        duplicate = rpc.call("battle.command", {"battle_id": battle_id, "sequence": 1, "action": action})
        check(duplicate == first, "duplicate command returns original receipt without a second attack")
        conflict = rpc.call("battle.command", {"battle_id": battle_id, "sequence": 1, "action": {"action": "flee"}})
        check(conflict.get("error") == "sequence_conflict", "same sequence cannot change action")
        out_of_order = rpc.call("battle.command", {"battle_id": battle_id, "sequence": 4, "action": action})
        check(out_of_order.get("error") == "sequence_out_of_order", "out of order input rejected")
        bad_skill = rpc.call("battle.command", {"battle_id": battle_id, "sequence": 2, "action": {"action": "skill", "skill_id": "gm_kill_all"}})
        check(bad_skill.get("ok") and not bad_skill.get("accepted"), "unowned skill cannot execute")
        escaped = rpc.call("battle.command", {"battle_id": battle_id, "sequence": 3, "action": {"action": "flee"}})
        final = rpc.call("battle.snapshot", {"battle_id": battle_id})
        check(escaped.get("accepted") and final["state"]["finished"] and final["state"]["result"] == "flee", "authority controls final battle result")
        reproduced = rpc.call("battle.replay", {"battle_id": battle_id, "inputs": final["inputs"], "target_tick": final["state"]["tick"]})
        check(reproduced.get("ok") and reproduced["state"]["state_hash"] == final["state"]["state_hash"], "seed and exact input log reproduce final authority state")
        check(rpc.call("battle.release", {"battle_id": battle_id}).get("released"), "finished simulation can be explicitly released")
        journal_config = config | {"battle_id": str(uuid.uuid4()), "inputs": [], "target_tick": 60}
        checkpoint = rpc.call("battle.sync", journal_config)
        check(checkpoint.get("ok") and checkpoint["state"]["tick"] == 60, "persistent journal uses gateway clock without autonomous advancement")
        journal_config |= {"confirmed_sequence": 0, "confirmed_tick": 60, "expected_state_hash": checkpoint["state"]["state_hash"]}
        provisional = rpc.call("battle.sync", journal_config | {"inputs": [{"sequence": 1, "tick": 60, "action": {"action": "flee"}}]})
        check(provisional.get("ok") and provisional["state"]["result"] == "flee", "provisional command executes before database outcome is known")
        rolled_back = rpc.call("battle.sync", journal_config)
        check(rolled_back.get("ok") and not rolled_back["state"]["finished"] and rolled_back["state"]["state_hash"] == checkpoint["state"]["state_hash"], "rolled back command is removed by rebuilding committed checkpoint")
        advanced = rpc.call("battle.sync", journal_config | {"target_tick": 90})
        restored = rpc.call("battle.sync", journal_config)
        check(advanced.get("ok") and restored.get("ok") and restored["state"]["state_hash"] == checkpoint["state"]["state_hash"], "uncommitted clock advancement also rolls back exactly")
        committed = rpc.call("battle.sync", journal_config | {"inputs": [{"sequence": 1, "tick": 60, "action": {"action": "attack"}}]})
        confirmed = journal_config | {"inputs": committed["inputs"], "confirmed_sequence": 1, "expected_state_hash": committed["state"]["state_hash"]}
        # Force a cache miss, like a fresh worker, without changing seed or journal.
        rebuilt = rpc.call("battle.sync", confirmed | {"battle_id": str(uuid.uuid4())})
        check(rebuilt.get("ok") and rebuilt["state"]["state_hash"] == committed["state"]["state_hash"], "cache miss rebuilds committed actions and validates state hash")
        tampered = dict(committed["inputs"][0])
        tampered["accepted"] = not tampered["accepted"]
        denied = rpc.call("battle.sync", confirmed | {"battle_id": str(uuid.uuid4()), "inputs": [tampered]})
        check(not denied.get("ok") and denied.get("error") == "journal_diverged", "committed input outcome cannot silently change during recovery")
        denied = rpc.call("battle.sync", confirmed | {"battle_id": str(uuid.uuid4()), "expected_state_hash": "0" * 64})
        check(not denied.get("ok") and denied.get("error") == "checkpoint_diverged", "divergent committed checkpoint fails closed")
        move = {"map_id": "lorin_wilds", "from_x": 600, "from_y": 1520, "x": 600, "y": 1540, "elapsed": 0.2, "speed": 192}
        check(rpc.call("world.validate_move", move).get("ok"), "shared world validates an ordinary city movement")
        check(rpc.call("world.validate_move", move | {"y": 1900}).get("error") == "invalid_speed", "shared world rejects a client teleport")
        loadout_id = str(uuid.uuid4())
        loadout_battle = rpc.call("battle.start", config | {"battle_id": loadout_id, "monster_id": "mon_treant", "loadout": {"attack": 10, "defense": 6, "health": 50, "potions": 3, "active_pet": "pet_rockturtle"}})
        loadout_units = loadout_battle.get("state", {}).get("units", [])
        check(loadout_battle.get("ok") and loadout_battle["state"].get("potions") == 3
              and any(u.get("template_id") == "pet_rockturtle" and u.get("side") == "ally" for u in loadout_units),
              "authority accepts valid equipment, potions and pet_rockturtle loadout")
        check(rpc.call("battle.command", {"battle_id": loadout_id, "sequence": 1, "action": {"action": "flee"}}).get("accepted"),
              "loadout simulation can flee before release")
        check(rpc.call("battle.release", {"battle_id": loadout_id}).get("released"), "loadout simulation can be released")
        invalid_loadout = rpc.call("battle.start", config | {"battle_id": str(uuid.uuid4()), "loadout": {"active_pet": "pet_illegal"}})
        check(not invalid_loadout.get("ok"), "authority rejects unapproved companion loadout")
        coop_id = str(uuid.uuid4())
        coop_cfg = {
            "battle_id": coop_id,
            "monster_id": "mon_stele_warden",
            "seed": 515253,
            "downed_window_ticks": 450,
            "coop_scaling": {"hp_mult": 2.35, "atk_mult": 1.12, "def_mult": 1.1, "extra_adds": 1, "add_monster_id": "mon_ghost"},
            "members": [
                {"character_id": "char-zs", "name": "破军", "role_id": "zs", "level": 8, "loadout": {"attack": 10, "defense": 6, "health": 50, "potions": 3, "active_pet": "pet_rockturtle"}},
                {"character_id": "char-ck", "name": "穿杨", "role_id": "ck", "level": 8, "loadout": {"attack": 10, "potions": 3}},
                {"character_id": "char-fs", "name": "霜语", "role_id": "fs", "level": 8, "loadout": {"attack": 11, "potions": 3}},
                {"character_id": "char-fz", "name": "晨星", "role_id": "fz", "level": 8, "loadout": {"attack": 9, "health": 30, "potions": 3}},
            ],
            "inputs": [
                {"sequence": 1, "tick": 65, "action": {"character_id": "char-zs", "action": "attack"}},
                {"sequence": 2, "tick": 70, "action": {"character_id": "char-ck", "action": "attack"}},
                {"sequence": 3, "tick": 75, "action": {"character_id": "char-fs", "action": "attack"}},
                {"sequence": 4, "tick": 80, "action": {"character_id": "char-fz", "action": "safe_defend", "enabled": True}},
            ],
            "target_tick": 90,
        }
        coop_sync = rpc.call("battle.sync", coop_cfg)
        coop_units = coop_sync.get("state", {}).get("units", [])
        coop_members = coop_sync.get("state", {}).get("coop_members", {})
        check(
            coop_sync.get("ok")
            and len(coop_members) == 4
            and sum(1 for u in coop_units if u.get("kind") == "role" and u.get("side") == "ally") == 4
            and sum(1 for u in coop_units if u.get("side") == "enemy") == 2
            and coop_members.get("char-zs", {}).get("actions") == 1
            and coop_members.get("char-fz", {}).get("safe_defend") is True,
            "authority simulates 4-class co-op party with scaled enemies and per-member actions",
        )
        report |= {"passed": True, "final_state_hash": final["state"]["state_hash"], "ticks": final["state"]["tick"], "inputs": final["inputs"], "coop_members_tested": len(coop_members)}
    except Exception as error:
        report |= {"passed": False, "error": str(error)}
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        log.close()
        text = (folder / "room.log").read_text(encoding="utf-8", errors="replace")
        script_errors = [line for line in text.splitlines() if any(marker in line for marker in ("SCRIPT ERROR", "Parse Error", "Compile Error"))]
        report |= {"checks": checks, "player_data_unchanged": player_snapshot() == before, "script_errors": script_errors, "log": str(folder / "room.log")}
        report["passed"] = bool(report.get("passed")) and all(c["passed"] for c in checks) and report["player_data_unchanged"] and not script_errors
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
