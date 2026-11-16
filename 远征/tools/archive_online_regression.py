"""Archive a completed strict regression run with its actual process outcome."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

GAME = Path(__file__).resolve().parents[1]
ROOT = GAME.parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True)
    parser.add_argument("--tag", default="")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9]{8}", args.date):
        raise RuntimeError("Expected YYYYMMDD run label")
    if args.tag and not re.fullmatch(r"[a-z0-9_-]{1,40}", args.tag):
        raise RuntimeError("Expected a short verification tag")
    label = args.date + ("_" + args.tag if args.tag else "")
    base = GAME / "tools/_logs"
    console_path = base / f"online_full_console_{label}.log"
    result_path = base / f"online_full_result_{label}.json"
    log_folder = base / f"online_full_{label}"
    metadata = json.loads(result_path.read_text(encoding="utf-8-sig"))
    console = console_path.read_text(encoding="utf-8-sig", errors="strict")
    runner = (GAME / "tools/run_regression.ps1").read_text(encoding="utf-8")
    expected = re.findall(r'@\{\s*N\s*=\s*"([A-Za-z0-9_]+)"', runner)
    passed = re.findall(r"(?m)^PASS  ([A-Za-z0-9_]+)\r?$", console)
    if (metadata["exit_code"] != 0 or metadata["expected_cases"] != len(expected)
            or len(passed) != len(expected) or set(passed) != set(expected)
            or "ALL GREEN" not in console or re.search(r"(?m)^FAIL\s", console)):
        raise RuntimeError("Strict full regression did not complete successfully")
    target = ROOT / "reports" / ("online_" + args.date)
    if args.tag:
        target = target / args.tag
    if target.exists():
        raise RuntimeError("Preserve existing evidence; choose a different run label")
    files = [(console_path, Path("full-regression-console.log")),
             (result_path, Path("full-regression-result.json")),
             (GAME / "src/ui/LoadScreen.gd", Path("LoadScreen.gd.snapshot"))]
    for name in expected:
        files.append((log_folder / f"{name}.log", Path("cases") / f"{name}.log"))
    for source, _ in files:
        if not source.is_file():
            raise RuntimeError(f"Case evidence missing: {source}")
    target.mkdir(parents=True)
    for source, relative in files:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    summary = {"expected_cases": len(expected), "passed_cases": len(passed), "exit_code": metadata["exit_code"],
               "started_at_utc": metadata["started_at_utc"], "finished_at_utc": metadata["finished_at_utc"],
               "load_screen_sha256": hashlib.sha256((GAME / "src/ui/LoadScreen.gd").read_bytes()).hexdigest(),
               "performance_thresholds_changed": False, "goal_status": "active", "L0_complete": False,
               "engine_shutdown_diagnostics": [line for line in console.splitlines() if line.startswith("NOTE:")],
               "scope": "strict singleplayer regression after texture warmup fix; online end-to-end evidence is archived separately"}
    (target / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
