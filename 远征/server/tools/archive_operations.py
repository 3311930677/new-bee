"""Archive verified operational, HTTPS world and full regression evidence once."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

from dev import LOCAL, ROOT, SERVER, completed_go_tests
from verify_world import source_fingerprint


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--operations", required=True)
    parser.add_argument("--world", required=True)
    parser.add_argument("--room", required=True)
    parser.add_argument("--error-before", required=True)
    parser.add_argument("--error-after", required=True)
    parser.add_argument("--date", required=True)
    args = parser.parse_args()
    if (not re.fullmatch(r"operations_[0-9a-f]{32}", args.operations)
            or not re.fullmatch(r"world_[0-9a-f]{32}", args.world)
            or not re.fullmatch(r"room_[0-9a-f]{32}", args.room)
            or not re.fullmatch(r"fault_responses_[0-9a-f]{32}", args.error_before)
            or not re.fullmatch(r"fault_responses_[0-9a-f]{32}", args.error_after)
            or not re.fullmatch(r"[0-9]{8}", args.date)):
        raise RuntimeError("Expected generated run IDs and YYYYMMDD")
    source = LOCAL / "verification"
    operations_dir, world_dir = source / args.operations, source / args.world
    room_dir = source / args.room
    operations = json.loads((operations_dir / "report.json").read_text(encoding="utf-8"))
    world = json.loads((world_dir / "report.json").read_text(encoding="utf-8"))
    room = json.loads((room_dir / "report.json").read_text(encoding="utf-8"))
    before_dir, after_dir = source / args.error_before, source / args.error_after
    before = json.loads((before_dir / "probe.json").read_text(encoding="utf-8"))
    after = json.loads((after_dir / "probe.json").read_text(encoding="utf-8"))
    if not room.get("passed") or not room.get("player_data_unchanged") or len(room.get("checks", [])) < 25:
        raise RuntimeError("Private authority regression incomplete or failed")
    fingerprint = source_fingerprint()
    for report in (operations, world):
        if (not report.get("passed") or not report.get("player_data_unchanged")
                or not report.get("online_sources_unchanged") or report.get("online_sources_sha256") != fingerprint
                or report.get("worker_errors")):
            raise RuntimeError("Failed, stale or changed-source evidence")
    if operations.get("secret_values_in_logs") or len(operations.get("tls_cases", [])) != 5:
        raise RuntimeError("Incomplete certificate or secret-isolation evidence")
    if (world.get("transport") != "https-validating-debug-ca" or world.get("injected_database_failures") != 2
            or world["gateway_binary_sha256"] != operations["gateway_binary_sha256"]):
        raise RuntimeError("World did not verify the same gateway over validating HTTPS")
    if room["manifest"]["source_sha256"] != world["manifest"]["source_sha256"]:
        raise RuntimeError("Private authority sources differ between verifiers")
    if (before.get("attempts") != 40 or before.get("outcomes", {}).get("RemoteDisconnected", 0) <= 0
            or after.get("attempts") != 40 or after.get("outcomes") != {"http_500": 40}
            or before.get("partial_roles") != "0" or after.get("partial_roles") != "0"
            or after.get("gateway_binary_sha256") != operations["gateway_binary_sha256"]
            or before.get("gateway_binary_sha256") == after.get("gateway_binary_sha256")):
        raise RuntimeError("Error response comparison does not prove the observed regression and fix")
    cases = completed_go_tests(source / "go-integration.jsonl")
    regression = ROOT / "reports" / ("online_" + args.date) / "operations-regression"
    singleplayer = json.loads((regression / "verification.json").read_text(encoding="utf-8"))
    if singleplayer.get("exit_code") != 0 or singleplayer.get("passed_cases") != singleplayer.get("expected_cases"):
        raise RuntimeError("Full singleplayer regression incomplete")
    files = [(source / "go-integration.jsonl", Path("go-integration.jsonl"))]
    for folder, label in ((before_dir, "before"), (after_dir, "after")):
        files.append((folder / "probe.json", Path("error-response-control") / (label + ".json")))
        files.extend((path, Path("error-response-control") / (label + "-" + path.name)) for path in folder.glob("gateway-*.log"))
    files.append((LOCAL / "probe_fault_responses.py", Path("error-response-control/probe.py.snapshot")))
    for name in ("report.json", "room.log", "go-authority-check.json", "forbidden-database.log", "forbidden-management.log"):
        files.append((room_dir / name, Path("authority") / name))
    for name in ("report.json", "certificate-generation.log", "promtool-metrics.log", "promtool-config.log", "prometheus.log"):
        files.append((operations_dir / name, Path("operations") / name))
    for mode in ("valid", "default-untrusted", "wrong-ca", "wrong-name", "expired"):
        files.append((operations_dir / ("tls-" + mode + ".log"), Path("operations") / ("tls-" + mode + ".log")))
    for label in ("healthy", "worker-down", "database-down", "expired-certificate", "recovered"):
        files.append((operations_dir / ("metrics-" + label + ".txt"), Path("operations") / ("metrics-" + label + ".txt")))
    for folder, label in ((operations_dir, "operations"), (world_dir, "world")):
        files.extend((path, Path(label) / path.name) for prefix in ("gateway-", "worker-") for path in folder.glob(prefix + "*.log"))
    files.append((world_dir / "report.json", Path("world/report.json")))
    for tag in ("a", "b"):
        files.append((world_dir / ("client-" + tag + ".log"), Path("world") / ("client-" + tag + ".log")))
    for name in ("world-a.png", "battle-a.png", "result-a.png"):
        files.append((world_dir / name, Path("world") / name))
    for path, _ in files:
        if not path.is_file():
            raise RuntimeError("Required evidence missing: " + str(path))
        if path.suffix != ".png" and re.search(rb"YZR-[A-Za-z0-9_-]{43}", path.read_bytes()):
            raise RuntimeError("Recovery code present in evidence")
    target = ROOT / "reports" / ("online_" + args.date) / "operations"
    if target.exists():
        raise RuntimeError("Preserve existing evidence; destination already exists")
    target.mkdir(parents=True)
    hashes = {}
    for path, relative in files:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
        hashes[relative.as_posix()] = hashlib.sha256(destination.read_bytes()).hexdigest()
    summary = {"operations_run": args.operations, "https_world_run": args.world, "room_run": args.room,
               "go_passed": len(cases), "go_test_cases": cases,
               "operation_checks": len(operations["checks"]), "tls_cases": operations["tls_cases"],
               "private_authority_checks": len(room["checks"]),
               "error_response_control": {"before": args.error_before, "after": args.error_after,
                                           "before_outcomes": before["outcomes"], "after_outcomes": after["outcomes"]},
               "gateway_binary_sha256": operations["gateway_binary_sha256"], "online_sources_sha256": fingerprint,
               "full_regression": "../operations-regression/verification.json", "evidence_sha256": hashes,
               "goal_status": "active", "L0_complete": False,
               "limitations": ["desktop loopback with a disposable CA; no installed system root or public certificate deployment",
                               "real local Prometheus alert state; no external operator notification delivery",
                               "preexisting intermittent client transport timeout remains under investigation",
                               "no mobile/WAN/capacity, cooperative combat, economy, guild or PvP acceptance",
                               "workspace validation with unrelated existing changes preserved"]}
    (target / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in summary.items() if key != "evidence_sha256"}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
