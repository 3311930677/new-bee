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
    parser.add_argument("--validation-prefix", default="")
    parser.add_argument("--console-encoding", choices=("utf-8-sig", "gb18030"), default="utf-8-sig")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9]{8}", args.date):
        raise RuntimeError("Expected YYYYMMDD run label")
    if args.tag and not re.fullmatch(r"[a-z0-9_-]{1,40}", args.tag):
        raise RuntimeError("Expected a short verification tag")
    if args.validation_prefix and not re.fullmatch(r"[a-z0-9_-]{1,40}", args.validation_prefix):
        raise RuntimeError("Expected a short validation prefix")
    label = args.date + ("_" + args.tag if args.tag else "")
    base = GAME / "tools/_logs"
    console_path = base / f"online_full_console_{label}.log"
    result_path = base / f"online_full_result_{label}.json"
    log_folder = base / f"online_full_{label}"
    metadata = json.loads(result_path.read_text(encoding="utf-8-sig"))
    console = console_path.read_text(encoding=args.console_encoding, errors="strict")
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
    fatal_patterns = ("SCRIPT ERROR", "Parse Error", "Compile Error", "USER ERROR", "FATAL ERROR",
                      "Assertion failed", "ERROR:", "FAIL:", "MISS:", "_FAIL")
    diagnostic_cases = []
    for name in expected:
        lines = (log_folder / f"{name}.log").read_text(encoding="utf-8-sig").splitlines()
        host = shutdown = 0
        for line in lines:
            text = line.strip()
            if text == "ERROR: Failed to read the root certificate store.":
                host += 1
            elif "were leaked at exit" in text or "resources still in use at exit" in text:
                shutdown += 1
            elif any(pattern in text for pattern in fatal_patterns):
                raise RuntimeError("Unexpected error pattern in completed case: " + name)
        diagnostic_cases.append({"case": name, "host_certificate_store_lines": host, "engine_shutdown_lines": shutdown})
    host_cases = sum(item["host_certificate_store_lines"] > 0 for item in diagnostic_cases)
    host_lines = sum(item["host_certificate_store_lines"] for item in diagnostic_cases)
    shutdown_cases = sum(item["engine_shutdown_lines"] > 0 for item in diagnostic_cases)
    shutdown_lines = sum(item["engine_shutdown_lines"] for item in diagnostic_cases)
    used_runner = log_folder / "runner-used.ps1.snapshot"
    if used_runner.is_file():
        files.append((used_runner, Path("run_regression-used.ps1.snapshot")))
    files.append((GAME / "tools/run_regression.ps1", Path("run_regression-current.ps1.snapshot")))
    validation = {}
    if args.validation_prefix:
        prefix = args.validation_prefix
        for name, token in (("runner-selftest", "RUNNER SELFTEST GREEN"), ("certificate-context", "ALL GREEN")):
            log = base / f"{prefix}-{name}.log"
            result = base / f"{prefix}-{name}-result.json"
            details = json.loads(result.read_text(encoding="utf-8-sig"))
            output = log.read_text(encoding=args.console_encoding)
            if details.get("exit_code") != 0 or token not in output or re.search(r"(?m)^FAIL\s", output):
                raise RuntimeError("Supplementary verification failed: " + name)
            if name == "certificate-context" and "Failed to read the root certificate store" in output:
                raise RuntimeError("Normal certificate context is unavailable")
            files.extend(((log, Path("validation") / log.name), (result, Path("validation") / result.name)))
            validation[name] = details
        for path in (base / (prefix + "-certificate-context")).glob("*.log"):
            text = path.read_text(encoding="utf-8-sig")
            if "Failed to read the root certificate store" in text:
                raise RuntimeError("Normal certificate context case still has a host diagnostic")
            files.append((path, Path("validation/certificate-context") / path.name))
        files.append((GAME / "tools/selftest_regression.ps1", Path("validation/selftest_regression.ps1.snapshot")))
    for source, _ in files:
        if not source.is_file():
            raise RuntimeError(f"Case evidence missing: {source}")
    target.mkdir(parents=True)
    for source, relative in files:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    (target / "full-regression-console-utf8.log").write_bytes(console.encode("utf-8"))
    summary = {"expected_cases": len(expected), "passed_cases": len(passed), "exit_code": metadata["exit_code"],
               "started_at_utc": metadata["started_at_utc"], "finished_at_utc": metadata["finished_at_utc"],
               "load_screen_sha256": hashlib.sha256((GAME / "src/ui/LoadScreen.gd").read_bytes()).hexdigest(),
               "performance_thresholds_changed": False, "goal_status": "active", "L0_complete": False,
               "raw_console_encoding": args.console_encoding,
               "engine_shutdown_diagnostics": {"cases": shutdown_cases, "lines": shutdown_lines, "tracked_issue": 43},
               "host_certificate_store_diagnostics": {"cases": host_cases, "lines": host_lines, "scope": "exact preexisting sandbox allowance; real TLS verified separately"},
               "original_console_diagnostic_notes": [line for line in console.splitlines() if line.startswith("NOTE:")],
               "validation": validation,
               "scope": "strict full singleplayer regression; online end-to-end evidence is archived separately"}
    (target / "diagnostics-audit.json").write_text(json.dumps({"verdict_rules_changed": False, "cases": diagnostic_cases}, ensure_ascii=False, indent=2), encoding="utf-8")
    (target / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
