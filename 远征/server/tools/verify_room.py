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
from dev import LOCAL, SERVER
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
    env = os.environ | {"APPDATA": str(folder / "userdata"), "LOCALAPPDATA": str(folder / "userdata"), "YUANZHENG_ROOM_SECRET": secret}
    checks = []
    report = {"scope": "isolated shared BattleSim + private signed RPC; not public multiplayer acceptance", "manifest": manifest}
    log = (folder / "room.log").open("wb")
    process = None

    def check(condition, name):
        checks.append({"name": name, "passed": bool(condition)})
        if not condition:
            raise RuntimeError(name)

    try:
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
        report |= {"passed": True, "final_state_hash": final["state"]["state_hash"], "ticks": final["state"]["tick"], "inputs": final["inputs"]}
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
