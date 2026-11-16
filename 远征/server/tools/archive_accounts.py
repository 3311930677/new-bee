"""Archive successful account-management and revalidated world evidence once."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

from dev import LOCAL, ROOT, SERVER
from verify_world import source_fingerprint


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--accounts", required=True)
    parser.add_argument("--world", required=True)
    parser.add_argument("--date", required=True)
    args = parser.parse_args()
    if (not re.fullmatch(r"accounts_[0-9a-f]{32}", args.accounts)
            or not re.fullmatch(r"world_[0-9a-f]{32}", args.world)
            or not re.fullmatch(r"[0-9]{8}", args.date)):
        raise RuntimeError("Expected generated verification IDs and YYYYMMDD")
    source = LOCAL / "verification"
    accounts_dir, world_dir = source / args.accounts, source / args.world
    accounts = json.loads((accounts_dir / "report.json").read_text(encoding="utf-8"))
    world = json.loads((world_dir / "report.json").read_text(encoding="utf-8"))
    fingerprint = source_fingerprint()
    for report in (accounts, world):
        if (not report.get("passed") or not report.get("online_sources_unchanged")
                or not report.get("player_data_unchanged")
                or report.get("online_sources_sha256") != fingerprint):
            raise RuntimeError("Failed, stale or changed-source verification evidence")
    if accounts.get("recovery_code_in_logs") or accounts.get("exit_code") != 0:
        raise RuntimeError("Account client failed or exposed a recovery code")
    if world.get("worker_errors") or world.get("injected_database_failures") != 2:
        raise RuntimeError("World recovery did not observe both injected failures")
    if accounts["gateway_binary_sha256"] != world["gateway_binary_sha256"]:
        raise RuntimeError("Clients did not verify the same gateway build")
    events = [json.loads(line) for line in (source / "go-integration.jsonl").read_text(encoding="utf-8").splitlines() if line.startswith("{")]
    passed = {e["Test"] for e in events if e["Action"] == "pass" and e.get("Test") and "/" not in e["Test"]}
    expected = {name for path in (SERVER / "internal").rglob("*_test.go")
                for name in re.findall(r"(?m)^func (Test[A-Za-z0-9_]+)\(", path.read_text(encoding="utf-8"))}
    if passed != expected or any(e["Action"] == "fail" for e in events):
        raise RuntimeError("Incomplete Go test evidence")
    regression = ROOT / "reports" / ("online_" + args.date) / "account-regression"
    singleplayer = json.loads((regression / "verification.json").read_text(encoding="utf-8"))
    if singleplayer.get("passed_cases") != singleplayer.get("expected_cases") or singleplayer.get("exit_code") != 0:
        raise RuntimeError("Full regression evidence missing or failed")
    files = [(source / "go-integration.jsonl", Path("go-integration.jsonl"))]
    for folder, label in ((accounts_dir, "accounts"), (world_dir, "world")):
        files.append((folder / "report.json", Path(label) / "report.json"))
        files.extend((path, Path(label) / path.name) for path in folder.glob("*.log"))
        files.extend((path, Path(label) / path.name) for path in folder.glob("*.png"))
    # Archive only reports, logs and masked screenshots: never test user data,
    # environment, credentials, barriers or recovery codes.
    for path, _ in files:
        if path.suffix != ".png" and re.search(rb"YZR-[A-Za-z0-9_-]{43}", path.read_bytes()):
            raise RuntimeError("Recovery code detected in evidence")
    target = ROOT / "reports" / ("online_" + args.date) / "account-management"
    if target.exists():
        raise RuntimeError("Preserve existing evidence; destination already exists")
    target.mkdir(parents=True)
    hashes = {}
    for path, relative in files:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
        hashes[relative.as_posix()] = hashlib.sha256(destination.read_bytes()).hexdigest()
    summary = {"accounts_run": args.accounts, "world_run": args.world,
               "go_passed": len(passed), "go_top_level_tests": sorted(passed),
               "online_sources_sha256": fingerprint,
               "gateway_binary_sha256": accounts["gateway_binary_sha256"],
               "full_regression": "../account-regression/verification.json",
               "evidence_sha256": hashes, "goal_status": "active", "L0_complete": False,
               "limitations": ["desktop loopback only; no mobile/WAN acceptance",
                               "security notifications are in-app, without an independent delivery channel",
                               "no prediction/AOI, cooperative combat, trading, guilds or PvP",
                               "workspace validation; unrelated preexisting changes remain unstaged"]}
    (target / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in summary.items() if key != "evidence_sha256"}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
