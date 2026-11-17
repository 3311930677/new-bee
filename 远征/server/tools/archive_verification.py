"""Archive verified non-secret evidence; refuse incomplete or failed result sets."""
import argparse
import json
from pathlib import Path
import re
import shutil

from dev import SERVER, ROOT, LOCAL, completed_go_tests


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--clients", required=True)
    parser.add_argument("--room", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{32}", args.clients) or not re.fullmatch(r"room_[0-9a-f]{32}", args.room):
        raise RuntimeError("Expected generated verification run IDs")
    source = LOCAL / "verification"
    clients = json.loads((source / args.clients / "report.json").read_text(encoding="utf-8"))
    room = json.loads((source / args.room / "report.json").read_text(encoding="utf-8"))
    tests = completed_go_tests(source / "go-integration.jsonl")
    if not clients.get("passed") or not clients.get("player_data_unchanged") or len(clients.get("clients", [])) != 2 or not all(c["passed"] for c in clients["clients"]):
        raise RuntimeError("Two-client evidence incomplete or failed")
    if not room.get("passed") or not room.get("player_data_unchanged") or len(room.get("checks", [])) < 14 or not all(c["passed"] for c in room["checks"]):
        raise RuntimeError("Authority evidence incomplete or failed")
    target = ROOT / "reports" / "online_20261116"
    if target.exists():
        raise RuntimeError("Preserve existing evidence; destination already exists")
    target.mkdir(parents=True)
    for src, dest in [
        (source / args.clients / "report.json", "clients-report.json"),
        (source / args.clients / "client_a.png", "online-character-480x800.png"),
        (source / args.room / "report.json", "authority-report.json"),
        (source / args.room / "go-authority-check.json", "go-authority-health.json"),
        (source / "go-integration.jsonl", "go-integration.jsonl"),
        (SERVER.parent / "tools/_logs/online_affected_20261116/VerifyNav.log", "navigation-fixed.log"),
        (SERVER.parent / "tools/_logs/online_perf_exclusive_20261116/VerifyPerf.log", "performance-unresolved.log"),
    ]:
        if not src.is_file():
            raise RuntimeError(f"Evidence missing: {src}")
        shutil.copy2(src, target / dest)
    # The existing runner keeps each case log but does not persist its console summary.
    # Preserve those exact logs; do not fabricate process exit records from OK tokens.
    runner = (SERVER.parent / "tools/run_regression.ps1").read_text(encoding="utf-8")
    cases = re.findall(r'@\{\s*N\s*=\s*"([A-Za-z0-9_]+)"', runner)
    original_logs = SERVER.parent / "tools/_logs/online_full_20261116"
    archived_logs = target / "regression-first-run"
    archived_logs.mkdir(exist_ok=True)
    for name in cases:
        source_log = original_logs / (name + ".log")
        if not source_log.is_file():
            raise RuntimeError(f"Full regression case log missing: {name}")
        shutil.copy2(source_log, archived_logs / source_log.name)
    summary = {
        "date": "2026-11-16", "goal_status": "active", "L0_complete": False,
        "go_top_level_tests_passed": len(tests), "go_tests": tests,
        "two_real_clients_passed": True, "authority_checks_passed": len(room["checks"]),
        "player_data_unchanged": True, "content_version": room["manifest"]["content_version"],
        "full_regression": {"observed_console_passed": 77, "observed_console_total": 79, "observed_exit_code": 1, "archived_case_logs": len(cases), "navigation_fixed_and_retested": True, "performance_still_failing": True, "note": "Console outcome observed during execution; runner does not store per-case process exit records."},
        "limits": ["authority probe ends by retreat and verifies replay; no victory reward transaction yet", "no two-client shared city yet", "no real-device or WAN acceptance", "L1-L6 and full L0 gates still pending", "the historical release-check label means explicit release only; no database settlement was exercised"],
    }
    (target / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
