"""Archive verified L0-H town journey, supervision recovery, and strict full regression."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import urllib.parse

GAME = Path(__file__).resolve().parents[1]
ROOT = GAME.parent
sys.path.insert(0, str(GAME / "server/tools"))
from dev import LOCAL, SERVER, completed_go_tests, config
from verify_world import source_fingerprint

SECRET_REGEX = re.compile(
    rb"YZR-[A-Za-z0-9_-]{43}|postgres(?:ql)?://|-----BEGIN (?:RSA )?PRIVATE KEY-----"
)


def collect_private_values(run_dirs):
    private = []
    try:
        pw = config().get("password", "")
        if pw:
            private.append(pw)
    except Exception:
        pass
    for folder in run_dirs:
        cred_root = folder / "credentials-private"
        if not cred_root.is_dir():
            continue
        for role in ("authority", "gateway"):
            role_dir = cred_root / role
            if not role_dir.is_dir():
                continue
            for path in role_dir.glob("*"):
                if not path.is_file():
                    continue
                value = path.read_text(encoding="utf-8", errors="ignore").strip()
                if value:
                    private.append(value)
                if path.name == "database-url":
                    parsed = urllib.parse.urlsplit(value).password
                    if parsed:
                        private.append(urllib.parse.unquote(parsed))
    return [v for v in set(private) if len(v) >= 4]


def scan_no_secrets(files, private_values):
    for src, rel in files:
        if not src.is_file():
            raise RuntimeError(f"Required evidence missing: {src} ({rel.as_posix()})")
        if src.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        data = src.read_bytes()
        for val in private_values:
            if val.encode("utf-8") in data:
                raise RuntimeError(f"Private value leaked in {src} ({rel.as_posix()})")
        if SECRET_REGEX.search(data):
            raise RuntimeError(f"Secret pattern matched in {src} ({rel.as_posix()})")


def archive_regression(date_str, label, target_dir):
    base = GAME / "tools/_logs"
    console_path = base / f"{label}_console.log"
    result_path = base / f"{label}_result.json"
    log_folder = base / label
    metadata = json.loads(result_path.read_text(encoding="utf-8-sig"))
    console = console_path.read_text(encoding="utf-8", errors="strict")
    runner = (GAME / "tools/run_regression.ps1").read_text(encoding="utf-8")
    expected = re.findall(r'@\{\s*N\s*=\s*"([A-Za-z0-9_]+)"', runner)
    passed = re.findall(r"(?m)^PASS  ([A-Za-z0-9_]+)\r?$", console)
    if (
        metadata.get("exit_code") != 0
        or metadata.get("expected_cases") != len(expected)
        or len(passed) != len(expected)
        or set(passed) != set(expected)
        or "ALL GREEN" not in console
        or re.search(r"(?m)^FAIL\s", console)
    ):
        raise RuntimeError("Strict full regression did not complete successfully")
    if (
        not metadata.get("runner_unchanged")
        or not metadata.get("load_screen_unchanged")
        or hashlib.sha256((GAME / "tools/run_regression.ps1").read_bytes()).hexdigest()
        != metadata.get("runner_sha256")
        or hashlib.sha256((GAME / "src/ui/LoadScreen.gd").read_bytes()).hexdigest()
        != metadata.get("load_screen_sha256")
    ):
        raise RuntimeError("Runner or loading source changed since the completed run")

    if target_dir.exists():
        raise RuntimeError(f"Preserve existing evidence: {target_dir}")

    files = [
        (console_path, Path("full-regression-console.log")),
        (result_path, Path("full-regression-result.json")),
        (GAME / "src/ui/LoadScreen.gd", Path("LoadScreen.gd.snapshot")),
        (GAME / "tools/run_regression.ps1", Path("run_regression-current.ps1.snapshot")),
        (GAME / "tools/VerifySecondAct.gd", Path("VerifySecondAct-used.gd.snapshot")),
    ]
    fatal_patterns = (
        "SCRIPT ERROR",
        "Parse Error",
        "Compile Error",
        "USER ERROR",
        "FATAL ERROR",
        "Assertion failed",
        "ERROR:",
        "FAIL:",
        "MISS:",
        "_FAIL",
    )
    diagnostic_cases = []
    for name in expected:
        case_log = log_folder / f"{name}.log"
        files.append((case_log, Path("cases") / f"{name}.log"))
        lines = case_log.read_text(encoding="utf-8-sig", errors="replace").splitlines()
        host = shutdown = 0
        for line in lines:
            text = line.strip()
            if text == "ERROR: Failed to read the root certificate store.":
                host += 1
            elif "were leaked at exit" in text or "resources still in use at exit" in text:
                shutdown += 1
            elif any(pattern in text for pattern in fatal_patterns):
                raise RuntimeError(f"Unexpected error pattern in completed case {name}: {text}")
        diagnostic_cases.append(
            {
                "case": name,
                "host_certificate_store_lines": host,
                "engine_shutdown_lines": shutdown,
            }
        )

    scan_no_secrets(files, [])
    target_dir.mkdir(parents=True)
    for src, rel in files:
        dst = target_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    host_cases = sum(item["host_certificate_store_lines"] > 0 for item in diagnostic_cases)
    host_lines = sum(item["host_certificate_store_lines"] for item in diagnostic_cases)
    shutdown_cases = sum(item["engine_shutdown_lines"] > 0 for item in diagnostic_cases)
    shutdown_lines = sum(item["engine_shutdown_lines"] for item in diagnostic_cases)
    summary = {
        "expected_cases": len(expected),
        "passed_cases": len(passed),
        "exit_code": metadata["exit_code"],
        "started_at_utc": metadata["started_at_utc"],
        "finished_at_utc": metadata["finished_at_utc"],
        "online_sources_sha256": metadata.get("online_sources_sha256"),
        "load_screen_sha256": metadata.get("load_screen_sha256"),
        "second_act_sha256": metadata.get("second_act_sha256"),
        "performance_thresholds_changed": False,
        "goal_status": "active",
        "L0_complete": False,
        "raw_console_encoding": metadata.get("console_encoding", "UTF-8"),
        "engine_shutdown_diagnostics": {
            "cases": shutdown_cases,
            "lines": shutdown_lines,
            "tracked_issue": 43,
        },
        "host_certificate_store_diagnostics": {
            "cases": host_cases,
            "lines": host_lines,
        },
        "original_console_diagnostic_notes": [
            line for line in console.splitlines() if line.startswith("NOTE:")
        ],
        "scope": "strict full singleplayer regression for L0-H final sources; performance thresholds unchanged",
    }
    (target_dir / "diagnostics-audit.json").write_text(
        json.dumps({"verdict_rules_changed": False, "cases": diagnostic_cases}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (target_dir / "verification.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return summary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True)
    parser.add_argument("--journey", required=True)
    parser.add_argument("--world", required=True)
    parser.add_argument("--room", required=True)
    parser.add_argument("--go-jsonl", required=True)
    parser.add_argument("--regression-label", required=True)
    parser.add_argument("--failed-run", action="append", default=[])
    args = parser.parse_args()

    if not re.fullmatch(r"[0-9]{8}", args.date):
        raise RuntimeError("Expected YYYYMMDD date")

    source = LOCAL / "verification"
    fingerprint = source_fingerprint()
    host_hash = hashlib.sha256((SERVER / "bin/servicehost.exe").read_bytes()).hexdigest()
    gateway_hash = hashlib.sha256((SERVER / "bin/gateway.exe").read_bytes()).hexdigest()

    journey_folder = source / args.journey
    world_folder = source / args.world
    room_folder = source / args.room
    go_jsonl = source / args.go_jsonl

    journey = json.loads((journey_folder / "report.json").read_text(encoding="utf-8"))
    world = json.loads((world_folder / "report.json").read_text(encoding="utf-8"))
    room = json.loads((room_folder / "report.json").read_text(encoding="utf-8"))
    go_tests = completed_go_tests(go_jsonl)

    if len(go_tests) != 57:
        raise RuntimeError(f"Expected 57 Go tests, got {len(go_tests)}")
    if not room.get("passed") or len(room.get("checks", [])) != 29 or not room.get("player_data_unchanged"):
        raise RuntimeError("Room verification evidence incomplete")
    if (
        not journey.get("passed")
        or journey.get("online_sources_sha256") != fingerprint
        or not journey.get("online_sources_unchanged")
        or not journey.get("player_data_unchanged")
        or len(journey.get("checks", [])) != 6
    ):
        raise RuntimeError("Journey verification evidence incomplete")
    if (
        not world.get("passed")
        or world.get("online_sources_sha256") != fingerprint
        or not world.get("online_sources_unchanged")
        or not world.get("player_data_unchanged")
        or world.get("gateway_binary_sha256") != gateway_hash
        or world.get("supervision", {}).get("host_binary_sha256") != host_hash
        or len(world.get("checks", [])) != 12
    ):
        raise RuntimeError("World supervision verification evidence incomplete")

    report_root = ROOT / "reports" / f"online_{args.date}"
    reg_summary = archive_regression(
        args.date, args.regression_label, report_root / "journey-regression"
    )

    files = [
        (go_jsonl, Path("go-integration.jsonl")),
        (room_folder / "report.json", Path("room/report.json")),
        (room_folder / "room.log", Path("room/room.log")),
        (room_folder / "forbidden-database.log", Path("room/forbidden-database.log")),
        (room_folder / "forbidden-management.log", Path("room/forbidden-management.log")),
        (room_folder / "go-authority-check.json", Path("room/go-authority-check.json")),
    ]

    for rel_prefix, run_dir, extra_files in (
        (
            Path("journey"),
            journey_folder,
            [
                "report.json",
                "certificate-generation.log",
                "backup-manifest.json",
                "restore-report.json",
                "journey-supplies.png",
                "journey-companion.png",
                "journey-coop-entry.png",
            ],
        ),
        (
            Path("world"),
            world_folder,
            [
                "report.json",
                "certificate-generation.log",
                "backup-manifest.json",
                "restore-report.json",
                "world-a.png",
                "battle-a.png",
                "result-a.png",
            ],
        ),
    ):
        for name in extra_files:
            files.append((run_dir / name, rel_prefix / name))
        for pattern in ("client-*.log", "gateway-*.log", "worker-*.log", "supervisor-*.log", "dbops-*.log"):
            for path in sorted(run_dir.glob(pattern)):
                files.append((path, rel_prefix / path.name))

    preserved_failures = []
    run_dirs = [journey_folder, world_folder, room_folder]
    for failed in args.failed_run:
        fdir = source / failed
        run_dirs.append(fdir)
        freport = json.loads((fdir / "report.json").read_text(encoding="utf-8"))
        if freport.get("passed"):
            raise RuntimeError(f"Expected preserved failure {failed} to have passed=false")
        preserved_failures.append(
            {
                "run": failed,
                "passed": False,
                "error": freport.get("error"),
                "online_sources_sha256": freport.get("online_sources_sha256"),
            }
        )
        for name in ("report.json", "certificate-generation.log"):
            if (fdir / name).is_file():
                files.append((fdir / name, Path("failed-runs") / failed / name))
        for pattern in ("client-*.log", "gateway-*.log", "worker-*.log", "supervisor-*.log", "dbops-*.log"):
            for path in sorted(fdir.glob(pattern)):
                files.append((path, Path("failed-runs") / failed / path.name))

    private_values = collect_private_values(run_dirs)
    scan_no_secrets(files, private_values)

    target = report_root / "town-journey"
    if target.exists():
        raise RuntimeError(f"Preserve existing evidence: {target}")
    target.mkdir(parents=True)
    evidence_hashes = {}
    for src, rel in files:
        dst = target / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        evidence_hashes[rel.as_posix()] = hashlib.sha256(dst.read_bytes()).hexdigest()

    verification = {
        "passed": True,
        "batch": "L0-H",
        "online_sources_sha256": fingerprint,
        "gateway_binary_sha256": gateway_hash,
        "servicehost_binary_sha256": host_hash,
        "go_passed": len(go_tests),
        "go_tests": go_tests,
        "room_run": args.room,
        "room_checks": len(room.get("checks", [])),
        "journey_run": args.journey,
        "journey_checks": len(journey.get("checks", [])),
        "world_run": args.world,
        "world_checks": len(world.get("checks", [])),
        "full_regression": "../journey-regression/verification.json",
        "full_regression_summary": {
            "expected_cases": reg_summary["expected_cases"],
            "passed_cases": reg_summary["passed_cases"],
            "exit_code": reg_summary["exit_code"],
            "engine_shutdown_diagnostics": reg_summary["engine_shutdown_diagnostics"],
        },
        "preserved_failures": preserved_failures,
        "evidence_sha256": evidence_hashes,
        "goal_status": "active",
        "L0_complete": False,
        "scope": "L0-H online inventory, equipment slots, battle consumables, pet_rockturtle companion, 8-step Lorin Wilds journey, migration 005, supervision & DB recovery, and 79-case singleplayer regression on identical final sources",
    }
    (target / "verification.json").write_text(
        json.dumps(verification, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(
        json.dumps(
            {
                "town_journey": str(target),
                "journey_regression": str(report_root / "journey-regression"),
                "go_passed": len(go_tests),
                "room_checks": len(room.get("checks", [])),
                "journey_checks": len(journey.get("checks", [])),
                "world_checks": len(world.get("checks", [])),
                "regression_passed": reg_summary["passed_cases"],
                "preserved_failures": len(preserved_failures),
                "files_copied": len(files),
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
