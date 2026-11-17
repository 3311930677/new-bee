"""Archive the L0 identity UI, compatible migration and real battle recheck."""
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
    parser.add_argument("--identity", required=True)
    parser.add_argument("--world", required=True)
    parser.add_argument("--date", required=True)
    parser.add_argument("--go-prefix", default="identity-go-final")
    parser.add_argument("--regression-tag", default="identity-regression")
    args = parser.parse_args()
    if (not re.fullmatch(r"identity_[0-9a-f]{32}", args.identity) or not re.fullmatch(r"world_[0-9a-f]{32}", args.world)
            or not re.fullmatch(r"[0-9]{8}", args.date) or not re.fullmatch(r"[a-z0-9_-]{1,40}", args.go_prefix)
            or not re.fullmatch(r"[a-z0-9_-]{1,40}", args.regression_tag)):
        raise RuntimeError("Expected generated run IDs, date and a short Go evidence prefix")
    source = LOCAL / "verification"
    identity_folder, world_folder = source / args.identity, source / args.world
    identity = json.loads((identity_folder / "report.json").read_text(encoding="utf8"))
    world = json.loads((world_folder / "report.json").read_text(encoding="utf8"))
    fingerprint = source_fingerprint()
    binary = hashlib.sha256((SERVER / "bin/gateway.exe").read_bytes()).hexdigest()
    for report in (identity, world):
        if (not report.get("passed") or not report.get("player_data_unchanged") or not report.get("online_sources_unchanged")
                or report.get("online_sources_sha256") != fingerprint or report.get("gateway_binary_sha256") != binary
                or report.get("transport") != "https-validating-debug-ca" or report.get("worker_errors")):
            raise RuntimeError("Failed, stale or mismatched real-client evidence")
    if (identity.get("client_exit_codes") != {"a": 0, "b": 0} or identity.get("database_counts") != ["2", "2", "2", "2", "0", "0"]
            or identity.get("database_identities") != ["ck|male|role_fz", "zs|female|role_fs"]
            or identity.get("private_values_in_logs") or identity.get("recovery_code_in_logs")):
        raise RuntimeError("Identity, asset or privacy evidence incomplete")
    recovery = world.get("database_recovery", {})
    if (world.get("injected_database_failures") != 2 or world.get("final_database_counts") != ["2", "2", "2", "2", "2", "2", "0"]
            or not recovery.get("passed") or recovery.get("tables_matched") != 17
            or identity["manifest"]["source_sha256"] != world["manifest"]["source_sha256"]):
        raise RuntimeError("Real authority, atomic-reward and database-recovery recheck incomplete")
    go_path = source / (args.go_prefix + ".jsonl")
    tests = completed_go_tests(go_path)
    go_result = json.loads((source / (args.go_prefix + "-result.json")).read_text(encoding="utf8"))
    if (go_result.get("exit_code") != 0 or go_result.get("completed_tests") != tests
            or go_result.get("online_sources_sha256") != fingerprint or not go_result.get("online_sources_unchanged")):
        raise RuntimeError("Full Go suite does not match current sources")
    regression = ROOT / "reports" / ("online_" + args.date) / args.regression_tag
    singleplayer = json.loads((regression / "verification.json").read_text(encoding="utf8"))
    if singleplayer.get("exit_code") != 0 or singleplayer.get("passed_cases") != 79 or singleplayer.get("expected_cases") != 79:
        raise RuntimeError("Full singleplayer regression incomplete")
    files = [(go_path, Path("go-integration.jsonl")),
             (source / (args.go_prefix + "-result.json"), Path("go-result.json")),
             (source / (args.go_prefix + "-console.log"), Path("go-console.log"))]
    for folder_name, label in (("identity-second-act-probe", "normal-1"),
                               ("identity-second-act-probe-normal-2", "normal-2"),
                               ("identity-second-act-probe-controlled", "controlled-one-hz")):
        folder = source / folder_name
        probe = json.loads((folder / "report.json").read_text(encoding="utf8"))
        output = (folder / "console.log").read_text(encoding="utf8")
        samples = probe.get("samples", [])
        if (probe.get("exit_code") != 0 or not probe.get("original_source_unchanged") or not probe.get("player_data_unchanged")
                or re.search(r"(?m)^SECOND_ACT_OK\s*$", output) is None
                or any(value in output for value in ("SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR:", "SECOND_ACT_FAIL"))
                or len(samples) != 2 or samples[0].get("phase") != "after_two_process_frames"
                or samples[1].get("phase") != "after_physics_frame" or samples[1].get("status") != "ready" or not samples[1].get("seen")):
            raise RuntimeError("Isolated test-timing diagnostic incomplete")
        if label == "controlled-one-hz" and (probe.get("controlled_physics_rate") != 1
                or samples[0].get("physics_now") != samples[0].get("physics_before")
                or samples[0].get("seen") or samples[0].get("status") != "active"
                or samples[1].get("physics_now", 0) <= samples[0].get("physics_now", 0)):
            raise RuntimeError("Controlled timing diagnostic does not demonstrate the missing physics update")
        for filename, output in (("report.json", "report.json"), ("console.log", "console.log"), ("probe.gd", "probe.gd.snapshot")):
            files.append((folder / filename, Path("test-timing") / label / output))
    for folder, label, names in (
        (identity_folder, "identity", ("report.json", "certificate-generation.log", "identity-create.png", "identity-profiles.png")),
        (world_folder, "world", ("report.json", "certificate-generation.log", "backup-manifest.json", "restore-report.json", "world-a.png", "battle-a.png", "result-a.png")),
    ):
        files.extend((folder / name, Path(label) / name) for name in names)
        for pattern in ("client-*.log", "gateway-*.log", "worker-*.log", "dbops-*.log"):
            files.extend((path, Path(label) / path.name) for path in sorted(folder.glob(pattern)))
    secret = config()["password"].encode()
    for path, _ in files:
        if not path.is_file():
            raise RuntimeError("Required evidence missing")
        if path.suffix == ".png":
            continue
        data = path.read_bytes()
        if secret in data or re.search(rb"YZR-[A-Za-z0-9_-]{43}|postgres(?:ql)?://|-----BEGIN (?:RSA )?PRIVATE KEY-----", data):
            raise RuntimeError("Private material present; archive withheld")
    target = ROOT / "reports" / ("online_" + args.date) / "character-identity"
    if target.exists():
        raise RuntimeError("Preserve existing evidence; choose a new destination")
    target.mkdir(parents=True)
    hashes = {}
    for path, relative in files:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
        hashes[relative.as_posix()] = hashlib.sha256(destination.read_bytes()).hexdigest()
    result = {"identity_run": args.identity, "world_run": args.world, "passed": True, "go_passed": len(tests), "go_test_cases": tests,
              "identity_checks": len(identity["checks"]), "world_checks": len(world["checks"]), "gateway_binary_sha256": binary,
              "online_sources_sha256": fingerprint, "shared_authority_sources_sha256": identity["manifest"]["source_sha256"],
              "full_regression": "../" + args.regression_tag + "/verification.json", "evidence_sha256": hashes,
              "preserved_first_regression": "../identity-regression-first/verification.json",
              "test_wait_fix": "one actual physics frame then process frame before original observation/delivery assertions; controlled one-Hz diagnostics are not production settings",
              "goal_status": "active", "L0_complete": False,
              "scope": "worktree validation: optional creation-time gender/approved portrait, legacy migration/receipt compatibility, two real reciprocal profile pages and battle/recovery recheck",
              "limitations": ["local custom pictures are not uploaded or approved for online use", "no mobile/WAN/public deployment/capacity acceptance",
                              "read-only public profile view is not L1 friends/chat/party delivery", "existing shutdown diagnostics and intermittent transport/startup failures remain separately tracked",
                              "full L0 through L6 delivery remains open"]}
    (target / "verification.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf8")
    print(json.dumps({"target": str(target), "go_passed": len(tests), "identity_checks": len(identity["checks"]), "world_checks": len(world["checks"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
