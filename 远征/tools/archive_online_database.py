"""Archive the restricted-role, real logical-restore drill without private dumps."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

GAME = Path(__file__).resolve().parents[1]
ROOT = GAME.parent
sys.path.insert(0, str(GAME / "server/tools"))

from dev import LOCAL, SERVER, completed_go_tests, config
from verify_world import source_fingerprint


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--world", required=True)
    parser.add_argument("--date", required=True)
    parser.add_argument("--go-prefix", default="dbops-go-guarded")
    args = parser.parse_args()
    if (not re.fullmatch(r"world_[0-9a-f]{32}", args.world) or not re.fullmatch(r"[0-9]{8}", args.date)
            or not re.fullmatch(r"[a-z0-9_-]{1,40}", args.go_prefix)):
        raise RuntimeError("Expected generated world ID and YYYYMMDD")
    source = LOCAL / "verification"
    folder = source / args.world
    world = json.loads((folder / "report.json").read_text(encoding="utf-8"))
    drill = world.get("database_recovery", {})
    fingerprint = source_fingerprint()
    binary = hashlib.sha256((SERVER / "bin/gateway.exe").read_bytes()).hexdigest()
    dbops_binary = hashlib.sha256((SERVER / "bin/dbops.exe").read_bytes()).hexdigest()
    if (not world.get("passed") or not world.get("player_data_unchanged") or not world.get("online_sources_unchanged")
            or world.get("online_sources_sha256") != fingerprint or world.get("worker_errors")
            or world.get("transport") != "https-validating-debug-ca" or world.get("injected_database_failures") != 2
            or world.get("gateway_binary_sha256") != binary):
        raise RuntimeError("Real validating HTTPS world evidence is failed, stale or incomplete")
    if (not drill.get("passed") or drill.get("tables_matched") != 17 or drill.get("revoked_sessions") != 2
            or drill.get("expired_leases") != 2 or drill.get("gateway_restricted_starts") != 3
            or drill.get("dbops_binary_sha256") != dbops_binary or not drill.get("post_backup_source_audit_retained")
            or not drill.get("post_backup_audit_absent_from_restored_snapshot")):
        raise RuntimeError("Actual database-role/restore drill incomplete")
    actions = drill["offline_actions"]
    expected_rejections = {"gateway-reject-offline-credential", "gateway-reject-owner-role", "gateway-reject-future-schema"}
    if not expected_rejections.issubset({x["action"] for x in actions if x["exit_code"] != 0 and not x["expected_success"]}):
        raise RuntimeError("Real unsafe gateway startup rejections are missing")
    go_path = source / (args.go_prefix + ".jsonl")
    cases = completed_go_tests(go_path)
    go_result = json.loads((source / (args.go_prefix + "-result.json")).read_text(encoding="utf-8"))
    if (go_result.get("exit_code") != 0 or go_result.get("completed_tests") != cases
            or go_result.get("online_sources_sha256") != fingerprint or not go_result.get("online_sources_unchanged")):
        raise RuntimeError("Full Go suite did not return a verified successful process result")
    regression_folder = ROOT / "reports" / ("online_" + args.date) / "database-regression"
    regression = json.loads((regression_folder / "verification.json").read_text(encoding="utf-8"))
    if regression.get("exit_code") != 0 or regression.get("passed_cases") != 79 or regression.get("expected_cases") != 79:
        raise RuntimeError("Strict full singleplayer regression incomplete")
    files = [(go_path, Path("go-integration.jsonl")),
             (source / (args.go_prefix + "-result.json"), Path("go-result.json")),
             (source / (args.go_prefix + "-console.log"), Path("go-console.log"))]
    names = ("report.json", "client-a.log", "client-b.log", "backup-manifest.json", "restore-report.json", "certificate-generation.log",
             "world-a.png", "battle-a.png", "result-a.png")
    files.extend((folder / name, Path("world") / name) for name in names)
    for pattern in ("gateway-*.log", "worker-*.log", "dbops-*.log"):
        files.extend((path, Path("world") / path.name) for path in sorted(folder.glob(pattern)))
    secret = config()["password"].encode()
    for path, _ in files:
        if not path.is_file():
            raise RuntimeError("Required evidence missing")
        if path.suffix == ".png":
            continue
        data = path.read_bytes()
        if secret in data or re.search(rb"YZR-[A-Za-z0-9_-]{43}|postgres(?:ql)?://|-----BEGIN (?:RSA )?PRIVATE KEY-----", data):
            raise RuntimeError("Private value pattern present; evidence was withheld")
    target = ROOT / "reports" / ("online_" + args.date) / "database-recovery"
    if target.exists():
        raise RuntimeError("Preserve existing evidence; destination already exists")
    target.mkdir(parents=True)
    hashes = {}
    for path, relative in files:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
        hashes[relative.as_posix()] = hashlib.sha256(destination.read_bytes()).hexdigest()
    summary = {"world_run": args.world, "passed": True, "go_passed": len(cases), "go_test_cases": cases,
               "go_exit_code": go_result["exit_code"], "world_checks": len(world["checks"]), "database_recovery": drill,
               "online_sources_sha256": fingerprint, "gateway_binary_sha256": binary, "dbops_binary_sha256": dbops_binary,
               "full_regression": "../database-regression/verification.json", "evidence_sha256": hashes,
               "private_artifacts_excluded": ["database.dump", "TLS private keys", "server connection URLs", "role passwords", "client credentials", "barrier files"],
               "goal_status": "active", "L0_complete": False,
               "scope": "worktree validation of restricted DB runtime and logical restore; desktop loopback with disposable CA",
               "limitations": ["no public deployment or live production endpoint switch", "no OS service identity/NTFS permission acceptance",
                               "no encrypted offsite retention, WAL archiving or point-in-time recovery", "no mobile/WAN/capacity acceptance",
                               "preexisting client transport timeouts and engine shutdown diagnostics remain separately tracked",
                               "L0 through L6 delivery scope remains open"]}
    (target / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"target": str(target), "go_passed": len(cases), "world_checks": len(world["checks"]), "tables_matched": drill["tables_matched"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
