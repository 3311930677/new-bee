"""Archive this vertical slice without rewriting the preceding account-only evidence."""
import argparse
import json
from pathlib import Path
import re
import shutil

from dev import SERVER, ROOT, LOCAL, completed_go_tests


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--world", required=True)
    parser.add_argument("--room", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"world_[0-9a-f]{32}", args.world) or not re.fullmatch(r"room_[0-9a-f]{32}", args.room):
        raise RuntimeError("Expected generated verification IDs")
    source = LOCAL / "verification"
    world_dir, room_dir = source / args.world, source / args.room
    world = json.loads((world_dir / "report.json").read_text(encoding="utf-8"))
    room = json.loads((room_dir / "report.json").read_text(encoding="utf-8"))
    if not world.get("passed") or not world.get("online_sources_unchanged") or not world.get("player_data_unchanged") or world.get("worker_errors"):
        raise RuntimeError("World evidence incomplete or failed")
    if not room.get("passed") or not room.get("player_data_unchanged") or len(room.get("checks", [])) < 23:
        raise RuntimeError("Private authority evidence incomplete or failed")
    passed = completed_go_tests(source / "go-integration.jsonl")
    target = ROOT / "reports/online_20261116/world"
    if target.exists():
        raise RuntimeError("Evidence destination already exists; preserve previous snapshots")
    files = [(world_dir / "report.json", "world-report.json"), (room_dir / "report.json", "authority-report.json"),
             (source / "go-integration.jsonl", "go-integration.jsonl")]
    for tag in ("a", "b"):
        files.append((world_dir / f"client-{tag}.log", f"client-{tag}.log"))
    for path in world_dir.glob("worker-*.log"):
        files.append((path, path.name))
    for name in ("world", "battle", "result"):
        files.append((world_dir / f"{name}-a.png", f"{name}-480x800.png"))
    for case in ("VerifyOnlineBoundary", "VerifyNav"):
        files.append((SERVER.parent / "tools/_logs/online_world_affected_20261116" / f"{case}.log", f"{case}.log"))
    files.append((SERVER.parent / "tools/_logs/online_world_affected_console.log", "affected-regression-console.log"))
    for path, _ in files:
        if not path.is_file():
            raise RuntimeError(f"Evidence missing: {path}")
    console = files[-1][0].read_text(encoding="utf-8", errors="replace")
    if "ALL GREEN" not in console or re.search(r"(?m)^FAIL\s", console):
        raise RuntimeError("Affected regression did not complete successfully")
    target.mkdir(parents=True)
    for source_path, name in files:
        shutil.copy2(source_path, target / name)
    summary = {"world_run": args.world, "room_run": args.room, "go_top_level_tests": sorted(passed),
               "go_passed": len(passed), "authority_checks": len(room["checks"]),
               "two_real_clients_world_battle_reward_restart_passed": True,
               "offline_data_unchanged": True, "goal_status": "active", "L0_complete": False,
               "limitations": ["desktop loopback only; no mobile/WAN acceptance", "HTTP snapshots without prediction/interpolation/AOI", "no teams, cooperation, trading, guilds or PvP", "full singleplayer regression is archived separately; no release or push claimed by this tool"]}
    (target / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
