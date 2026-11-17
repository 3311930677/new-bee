"""Real TLS clients, protected monitoring and isolated dependency outages."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

from database_fault_proxy import DatabaseFaultProxy
from dev import LOCAL, RUNTIME, SERVER, client_environment, completed_go_tests, config
from local_stack import LocalStack, free_port
from verify_clients import player_snapshot
from verify_world import source_fingerprint

MONITORING = RUNTIME / "prometheus-3.16.0"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    folder = LOCAL / "verification" / ("operations_" + uuid.uuid4().hex)
    folder.mkdir(parents=True)
    checks, private_values = [], []
    before, fingerprint = player_snapshot(), source_fingerprint()
    report = {"scope": "desktop loopback TLS verification, real dependency outages, private metrics and actual Prometheus alerts; not public deployment, delivery to an operator, mobile or capacity acceptance",
              "online_sources_sha256": fingerprint, "go_test_cases": completed_go_tests(LOCAL / "verification/go-integration.jsonl")}
    stack = proxy = prometheus = None
    prometheus_log = None

    def check(condition, message):
        checks.append({"name": message, "passed": bool(condition)})
        if not condition:
            raise RuntimeError(message)

    def wait_for(predicate, message, seconds=35):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                if predicate():
                    check(True, message)
                    return
            except (OSError, ValueError, KeyError):
                pass
            if prometheus is not None and prometheus.poll() is not None:
                raise RuntimeError("Monitoring process exited before verification completed")
            time.sleep(0.25)
        check(False, message)

    def request(method, path, payload=None, *, token=None, admin=False):
        url = (stack.admin_url if admin else stack.url) + path
        headers = {"Content-Type": "application/json", "X-Content-Version": stack.manifest["content_version"]}
        credential = stack.env["YUANZHENG_ADMIN_TOKEN"] if admin and token is None else token
        if credential:
            headers["Authorization"] = "Bearer " + credential
        if payload is not None:
            body = json.dumps(payload, ensure_ascii=False).encode()
        else:
            body = None
        outgoing = urllib.request.Request(url, body, headers, method=method)
        try:
            response = stack.opener.open(outgoing, timeout=20)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.status, response.read().decode("utf-8")

    def command(path, payload, key, token):
        outgoing = urllib.request.Request(stack.url + path, json.dumps(payload).encode(),
            {"Content-Type": "application/json", "X-Content-Version": stack.manifest["content_version"],
             "Authorization": "Bearer " + token, "Idempotency-Key": key}, method="POST")
        try:
            response = stack.opener.open(outgoing, timeout=20)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.status, json.load(response)

    def metrics(label):
        status, text = request("GET", "/metrics", admin=True)
        check(status == 200, "protected metrics respond during " + label)
        check("\r" not in text and text.endswith("\n"), "live metrics retain the required LF wire format during " + label)
        (folder / ("metrics-" + label + ".txt")).write_bytes(text.encode("utf-8"))
        values = {match.group(1): float(match.group(2)) for match in re.finditer(r"(?m)^([a-zA-Z_:][a-zA-Z0-9_:]*) ([^\s]+)$", text)}
        return text, values

    def run_tls_case(mode, ca_name=None):
        userdata = folder / ("client-" + mode)
        userdata.mkdir()
        extra = {"APPDATA": str(userdata), "LOCALAPPDATA": str(userdata),
                 "YUANZHENG_TEST_URL": stack.url, "YUANZHENG_TLS_CASE": mode}
        if ca_name:
            extra["YUANZHENG_TEST_CA"] = str(folder / "tls" / ca_name)
        if mode == "valid":
            password = secrets.token_hex(20)
            private_values.append(password)
            extra |= {"YUANZHENG_TEST_USERNAME": "tls_" + uuid.uuid4().hex[:16],
                      "YUANZHENG_TEST_PASSWORD": password,
                      "YUANZHENG_TEST_NICKNAME": "护证旅人" + uuid.uuid4().hex[:8]}
        env = stack.client_environment(extra)
        log_path = folder / ("tls-" + mode + ".log")
        with log_path.open("wb") as log:
            process = subprocess.Popen([str(args.godot.resolve()), "--headless", "--path", str(SERVER.parent),
                "--audio-driver", "Dummy", "res://tools/VerifyOnlineTLS.tscn"], env=env,
                stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                code = process.wait(timeout=100)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                code = -1
        text = log_path.read_text(encoding="utf-8", errors="replace")
        fatal = [line for line in text.splitlines() if any(value in line for value in ("SCRIPT ERROR", "Parse Error", "Compile Error", "ONLINE_TLS_FAIL"))]
        engine_errors = [line for line in text.splitlines() if line.startswith("ERROR:")]
        unexpected = engine_errors if mode == "valid" else [line for line in engine_errors if not line.startswith("ERROR: TLS handshake error:")]
        check(code == 0 and re.search(r"(?m)^ONLINE_TLS_OK\s*$", text) is not None and not fatal and not unexpected,
              "real Godot validates TLS case " + mode)
        if mode != "valid":
            check(f"ONLINE_TLS_REJECTED case={mode} transport=5" in text, "invalid certificate is rejected before credentials in " + mode)
        report.setdefault("tls_cases", []).append({"case": mode, "exit_code": code, "expected_tls_error_lines": len(engine_errors) if mode != "valid" else 0})

    try:
        check((MONITORING / "provenance.json").is_file(), "verified official Prometheus runtime is available")
        for executable in ("gateway.exe", "devcert.exe"):
            check((SERVER / "bin" / executable).is_file(), "built runtime available: " + executable)
        report["gateway_binary_sha256"] = hashlib.sha256((SERVER / "bin/gateway.exe").read_bytes()).hexdigest()
        generated = subprocess.run([str(SERVER / "bin/devcert.exe"), "--out", str(folder / "tls"), "--negative-fixtures"],
                                   capture_output=True, text=True, encoding="utf-8", creationflags=subprocess.CREATE_NO_WINDOW)
        (folder / "certificate-generation.log").write_text(generated.stdout + generated.stderr, encoding="utf-8")
        check(generated.returncode == 0, "disposable certificates generated without installing a system root")
        report["certificate_manifest"] = json.loads(generated.stdout)
        proxy = DatabaseFaultProxy(config()["port"])
        stack = LocalStack(args.godot, folder, isolated_test=True, tls_directory=folder / "tls",
                           with_admin=True, database_proxy_port=proxy.port)
        private_values += [stack.env["YUANZHENG_ROOM_SECRET"], stack.env["YUANZHENG_ADMIN_TOKEN"], config()["password"]]
        stack.start()
        report["manifest"] = stack.manifest
        for path in ("/readyz", "/healthz", "/livez"):
            check(request("GET", path)[0] == 200, "actual HTTPS gateway exposes " + path)
        check(request("GET", "/metrics")[0] == 404, "public game listener does not expose metrics")
        for token in ("", "incorrect-token"):
            check(request("GET", "/metrics", token=token, admin=True)[0] == 401, "admin rejects missing or wrong management token")
        run_tls_case("valid", "ca-cert.pem")
        run_tls_case("default-untrusted")
        run_tls_case("wrong-ca", "untrusted-ca.pem")
        password = secrets.token_hex(20)
        private_values.append(password)
        status, text = request("POST", "/v1/auth/register", {"username": "ops_" + uuid.uuid4().hex[:16], "password": password})
        check(status == 201, "actual TLS API creates the operational test account")
        credentials = json.loads(text)["data"]
        token = credentials["access_token"]
        private_values += [token, credentials["refresh_token"], credentials["recovery_code"]]
        check(request("GET", "/metrics", token=token, admin=True)[0] == 401, "game access token cannot read management metrics")
        status, created = command("/v1/characters", {"nickname": "守望旅人" + uuid.uuid4().hex[:8], "role_id": "zs", "appearance_id": "default"}, "ops-create-role-001", token)
        check(status == 201, "operational test creates authoritative assets")
        character = created["data"]["character"]["id"]
        check(command("/v1/characters/" + character + "/select", {}, "ops-select-role-001", token)[0] == 200, "operational test selects its own role")
        status, joined = command("/v1/rooms/join", {}, "ops-join-room-001", token)
        check(status == 200, "operational test obtains a live lease")
        lease = joined["data"]["lease"]
        private_values.append(lease["lease_token"])
        for step in range(8):
            time.sleep(0.16)
            status, moved = command("/v1/rooms/move", {"lease_token": lease["lease_token"], "generation": lease["generation"],
                "sequence": lease["move_sequence"] + 1, "x": lease["x"], "y": lease["y"] + 22}, "ops-move-" + str(step), token)
            check(status == 200, "authority approves actual movement step " + str(step))
            lease = moved["data"]["lease"]
        status, battle = command("/v1/battles", {"encounter_id": "training_wolf"}, "ops-start-battle-001", token)
        check(status == 201, "real Godot authority creates the operational battle")
        battle_id = battle["data"]["battle"]["id"]
        initial, values = metrics("healthy")
        check(values.get("yuanzheng_ready") == 1 and values.get("yuanzheng_active_sessions") == 1 and values.get("yuanzheng_active_room_leases") == 1 and values.get("yuanzheng_active_battles") == 1,
              "private gauges match real online session, lease and battle")
        check(0 < values.get("yuanzheng_tls_certificate_expiry_seconds", 0) <= 172800, "TLS certificate validity is observable without exposing the private key")
        # Text-mode stdin on Windows changes LF to CRLF, which is not the
        # exposition received over HTTP. Validate the original UTF-8 bytes.
        validated = subprocess.run([str(MONITORING / "promtool.exe"), "check", "metrics"], input=initial.encode("utf-8"),
                                   capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)
        (folder / "promtool-metrics.log").write_bytes(validated.stdout + validated.stderr)
        check(validated.returncode == 0, "official promtool accepts the live metrics exposition")
        private_file = folder / "admin-token"
        private_file.write_text(stack.env["YUANZHENG_ADMIN_TOKEN"], encoding="utf-8")
        rules_source = SERVER / "deploy/monitoring/alerts.yml"
        rules = folder / "test-alerts.yml"
        rules.write_text(rules_source.read_text(encoding="utf-8").replace("for: 1m", "for: 1s"), encoding="utf-8")
        prometheus_config = folder / "prometheus.yml"
        prometheus_config.write_text("global:\n  scrape_interval: 4s\n  evaluation_interval: 1s\nrule_files:\n  - " + json.dumps(rules.as_posix(), ensure_ascii=False) +
            "\nscrape_configs:\n  - job_name: yuanzheng\n    scrape_timeout: 3s\n    static_configs:\n      - targets: [\"127.0.0.1:" + str(stack.admin_port) + "\"]\n    authorization:\n      type: Bearer\n      credentials_file: " + json.dumps(private_file.as_posix(), ensure_ascii=False) + "\n", encoding="utf-8")
        validated = subprocess.run([str(MONITORING / "promtool.exe"), "check", "config", str(prometheus_config)],
                                   capture_output=True, text=True, encoding="utf-8", creationflags=subprocess.CREATE_NO_WINDOW)
        (folder / "promtool-config.log").write_text(validated.stdout + validated.stderr, encoding="utf-8")
        check(validated.returncode == 0, "official promtool validates monitoring configuration and alert rules")
        port = free_port()
        monitoring_url = f"http://127.0.0.1:{port}"
        prometheus_log = (folder / "prometheus.log").open("wb")
        prometheus = subprocess.Popen([str(MONITORING / "prometheus.exe"), "--config.file=" + str(prometheus_config),
            "--web.listen-address=127.0.0.1:" + str(port), "--storage.tsdb.path=" + str(folder / "monitoring-data"), "--log.level=warn"],
            env=client_environment(stack.env, {}), stdout=prometheus_log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        def query(expression):
            with opener.open(monitoring_url + "/api/v1/query?" + urllib.parse.urlencode({"query": expression}), timeout=5) as response:
                return json.load(response)["data"]["result"]
        def value(expression, expected):
            result = query(expression)
            return len(result) == 1 and float(result[0]["value"][1]) == expected
        def alert_firing():
            return bool(query('ALERTS{alertname="YuanzhengDependenciesUnavailable",alertstate="firing"}'))
        wait_for(lambda: value('up{job="yuanzheng"}', 1) and value('yuanzheng_ready{job="yuanzheng"}', 1), "real Prometheus scrapes the protected gateway")
        previous_epoch = stack.rpc.call("ping")["epoch"]
        stack.stop("worker")
        check(request("GET", "/readyz")[0] == 503 and request("GET", "/livez")[0] == 200 and request("GET", "/healthz")[0] == 200,
              "worker outage changes readiness without confusing database health or liveness")
        _, failed = metrics("worker-down")
        check(failed.get("yuanzheng_authority_up") == 0 and failed.get("yuanzheng_database_up") == 1, "worker outage is classified independently in live metrics")
        wait_for(alert_firing, "real dependency alert fires for the stopped authority")
        report["worker_alert_firing"] = query('ALERTS{alertname="YuanzhengDependenciesUnavailable",alertstate="firing"}')
        stack.start_worker()
        check(previous_epoch != stack.rpc.call("ping")["epoch"], "the restarted authority has a new real process epoch")
        wait_for(lambda: request("GET", "/readyz")[0] == 200, "readiness recovers after authority restart")
        status, state = request("GET", "/v1/battles/active", token=token)
        check(status == 200 and json.loads(state)["data"]["battle"]["id"] == battle_id, "persisted battle recovers after authority restart")
        status, result = command("/v1/battles/" + battle_id + "/commands", {"action": "flee"}, "ops-flee-battle-001", token)
        check(status == 200 and result["data"]["battle"]["result"] == "flee", "operational battle can conclude through the real authority")
        wait_for(lambda: not alert_firing() and value('yuanzheng_ready{job="yuanzheng"}', 1), "dependency alert resolves after authority recovery")
        proxy.pause()
        check(request("GET", "/readyz")[0] == 503 and request("GET", "/livez")[0] == 200, "isolated database traffic outage preserves process liveness")
        _, failed = metrics("database-down")
        check(failed.get("yuanzheng_database_up") == 0 and failed.get("yuanzheng_authority_up") == 1 and "yuanzheng_active_sessions" not in failed,
              "database outage omits unknown state gauges and keeps authority classification")
        started = time.monotonic()
        payload = {"nickname": "重连旅人" + uuid.uuid4().hex[:8], "role_id": "fs", "appearance_id": "default"}
        failure_statuses = {}
        for _ in range(40):
            status, failure = command("/v1/characters", payload, "ops-outage-create-001", token)
            check(status in (500, 503) and "error" in failure, "database outage returns a complete failure without confirming a new role")
            failure_statuses[str(status)] = failure_statuses.get(str(status), 0) + 1
        report["database_fault_response_statuses"] = failure_statuses
        report["database_fault_request_ms"] = round((time.monotonic()-started)*1000)
        check(stack.sql("SELECT count(*) FROM characters") == "2", "independent database query confirms no partial role during the isolated outage")
        wait_for(alert_firing, "real dependency alert fires for the isolated database outage")
        report["database_alert_firing"] = query('ALERTS{alertname="YuanzhengDependenciesUnavailable",alertstate="firing"}')
        proxy.resume()
        wait_for(lambda: request("GET", "/readyz")[0] == 200, "database connectivity and readiness recover")
        status, recovered = command("/v1/characters", payload, "ops-outage-create-001", token)
        again_status, repeated = command("/v1/characters", payload, "ops-outage-create-001", token)
        check(status == 201 and again_status == 201 and recovered["data"]["character"]["id"] == repeated["data"]["character"]["id"], "original request creates one role after database recovery and replays one receipt")
        wait_for(lambda: not alert_firing() and value('yuanzheng_ready{job="yuanzheng"}', 1), "dependency alert resolves after database recovery")
        check(command("/v1/battles/" + battle_id + "/acknowledge", {}, "ops-ack-battle-001", token)[0] == 200, "operational result is acknowledged without reward replay")
        check(request("POST", "/v1/auth/logout", {}, token=token)[0] == 200, "operational session is revoked")
        for mode, certificate in (("wrong-name", "wrong-name-cert.pem"), ("expired", "expired-cert.pem")):
            stack.stop("gateway")
            stack.tls_certificate = certificate
            stack.start_gateway(require_ready=False)
            run_tls_case(mode, "ca-cert.pem")
            if mode == "expired":
                _, expired = metrics("expired-certificate")
                check(expired.get("yuanzheng_tls_certificate_valid") == 0 and expired.get("yuanzheng_ready") == 0 and expired.get("yuanzheng_tls_certificate_expiry_seconds", 0) < 0,
                      "expired TLS certificate also removes service readiness and is visible to monitoring")
        stack.stop("gateway")
        stack.tls_certificate = "server-cert.pem"
        stack.start_gateway()
        _, final_metrics = metrics("recovered")
        check(final_metrics.get("yuanzheng_ready") == 1 and final_metrics.get("yuanzheng_active_sessions") == 0 and final_metrics.get("yuanzheng_active_room_leases") == 0 and final_metrics.get("yuanzheng_active_battles") == 0 and final_metrics.get("yuanzheng_unacknowledged_results") == 0,
              "fully recovered metrics show no stale sessions, leases, active battles or pending results")
        final = stack.sql("SELECT (SELECT count(*) FROM accounts),(SELECT count(*) FROM characters),(SELECT count(*) FROM wallets WHERE gold=100),(SELECT count(*) FROM wallet_ledger),(SELECT count(*) FROM sessions WHERE revoked_at IS NULL),(SELECT count(*) FROM battle_results),(SELECT count(*) FROM battles WHERE acknowledged_at IS NOT NULL)").split("|")
        check(final == ["2", "3", "3", "3", "0", "1", "1"], "database independently confirms exact accounts, roles, unchanged starter assets and acknowledged result")
        report |= {"passed": True, "final_database_counts": final, "monitoring": json.loads((MONITORING / "provenance.json").read_text(encoding="utf-8")),
                   "alert_test_for": "1s; production template uses 1m", "tls_directory": str(folder / "tls")}
    except Exception as error:
        report |= {"passed": False, "error": str(error)}
    finally:
        if prometheus is not None and prometheus.poll() is None:
            prometheus.terminate()
            try:
                prometheus.wait(timeout=10)
            except subprocess.TimeoutExpired:
                prometheus.kill()
                prometheus.wait()
        if prometheus_log:
            prometheus_log.close()
        if proxy:
            proxy.resume()
        if stack:
            try:
                stack.close()
            except Exception as error:
                report |= {"passed": False, "cleanup_error": str(error)}
        if proxy:
            proxy.close()
        leaks = []
        for path in folder.glob("*.log"):
            data = path.read_text(encoding="utf-8", errors="replace")
            if any(secret in data for secret in private_values) or re.search(r"YZR-[A-Za-z0-9_-]{43}", data):
                leaks.append(path.name)
        report["secret_values_in_logs"] = leaks
        report["checks"] = checks
        report["player_data_unchanged"] = player_snapshot() == before
        report["online_sources_unchanged"] = source_fingerprint() == fingerprint
        report["worker_errors"] = [line for path in folder.glob("worker-*.log") for line in path.read_text(encoding="utf-8", errors="replace").splitlines() if any(marker in line for marker in ("SCRIPT ERROR", "ERROR:", "Parse Error", "Compile Error"))]
        report["passed"] = bool(report.get("passed")) and all(item["passed"] for item in checks) and not leaks and not report["worker_errors"] and report["player_data_unchanged"] and report["online_sources_unchanged"]
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"report": str(folder / "report.json"), **report}, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
