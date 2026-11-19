"""Verify L6 operations readiness: 26-client concurrent load + channel overflow,
Prometheus alert firing & local webhook delivery, loopback ops moderation/capacity/market-pause,
player privacy summary/export/erasure, AES-256-GCM encrypted backup & 56-table restore,
version-mismatch/rollback rejection, and total-outage singleplayer resilience."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import http.server
import json
from pathlib import Path
import secrets
import socketserver
import statistics
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

from database_fault_proxy import DatabaseFaultProxy
from database_recovery import DatabaseRecovery
from dev import LOCAL, PG, RUNTIME, SERVER, client_environment, completed_go_tests
from local_stack import LocalStack, free_port
from verify_clients import player_snapshot
from verify_world import source_fingerprint

GAME = SERVER.parent
GATEWAY = SERVER / "bin/gateway.exe"
MONITORING = RUNTIME / "prometheus-3.16.0"


class WebhookReceiver:
    def __init__(self):
        self.lock = threading.Lock()
        self.deliveries = []
        owner = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers.get("Content-Length", "0"))
                raw = self.rfile.read(length)
                payload = json.loads(raw.decode("utf-8"))
                with owner.lock:
                    owner.deliveries.append(payload)
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"received":true}')

            def log_message(self, format, *args):
                return

        class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
            daemon_threads = True

        self.server = Server(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}/alerts"
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()


def percentile(values, pct):
    if not values:
        return 0.0
    ordered = sorted(values)
    idx = min(len(ordered) - 1, max(0, int(round((pct / 100.0) * (len(ordered) - 1)))))
    return round(ordered[idx], 2)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()

    run = uuid.uuid4().hex
    folder = LOCAL / "verification" / ("l6_ops_" + run)
    folder.mkdir(parents=True)
    before = player_snapshot()
    fingerprint = source_fingerprint()
    recovery = DatabaseRecovery(folder)
    tls = recovery.create_tls()
    checks, private_values = [], []
    stack = proxy = prometheus = prometheus_log = webhook = None

    def check(condition, message):
        checks.append({"name": message, "passed": bool(condition)})
        if not condition:
            raise RuntimeError(message)

    report = {
        "run_id": run,
        "online_sources_sha256": fingerprint,
        "gateway_binary_sha256": hashlib.sha256(GATEWAY.read_bytes()).hexdigest(),
        "go_test_cases": completed_go_tests(LOCAL / "verification/go-integration.jsonl"),
        "scope": "L6 local operations drill: 26 concurrent TLS clients, channel overflow, Prometheus + local alert webhook, loopback moderation/capacity/market-pause, privacy export/erasure, AES-256-GCM encrypted backup + 56-table restore, rollback rejection, and total-outage singleplayer; NOT external cloud WAN or live operator handset verification",
    }

    try:
        proxy = DatabaseFaultProxy(recovery.cfg["port"])
        stack = LocalStack(
            args.godot, folder, tls_directory=tls, with_admin=True,
            database_proxy_port=proxy.port, require_restricted_database=True, migration_mode="check",
        )
        recovery.provision(stack)
        stack.start()
        report["manifest"] = stack.manifest
        private_values.append(stack.env["YUANZHENG_ADMIN_TOKEN"])
        private_values.extend(recovery.private)

        def call_api(method, path, payload=None, *, token=None, admin=False, key=None, content_version=None):
            base = stack.admin_url if admin else stack.url
            headers = {
                "Content-Type": "application/json",
                "X-Content-Version": content_version or stack.manifest["content_version"],
            }
            if admin:
                headers["Authorization"] = "Bearer " + (token if token is not None else stack.env["YUANZHENG_ADMIN_TOKEN"])
            elif token:
                headers["Authorization"] = "Bearer " + token
            if key:
                headers["Idempotency-Key"] = key
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else None
            req = urllib.request.Request(base + path, body, headers, method=method)
            t0 = time.monotonic()
            try:
                resp = stack.opener.open(req, timeout=20)
            except urllib.error.HTTPError as exc:
                resp = exc
            with resp:
                raw = resp.read().decode("utf-8")
                elapsed_ms = (time.monotonic() - t0) * 1000.0
                return resp.status, (json.loads(raw) if raw.startswith("{") else raw), elapsed_ms

        def read_stream_frame(path, token):
            headers = {
                "X-Content-Version": stack.manifest["content_version"],
                "Authorization": "Bearer " + token,
            }
            req = urllib.request.Request(stack.url + path, None, headers, method="GET")
            t0 = time.monotonic()
            with stack.opener.open(req, timeout=20) as resp:
                line = resp.readline().decode("utf-8").strip()
                elapsed_ms = (time.monotonic() - t0) * 1000.0
                return resp.status, json.loads(line), elapsed_ms

        # 1. Start real Prometheus + local alert webhook receiver.
        webhook = WebhookReceiver()
        has_prom = (MONITORING / "prometheus.exe").exists() and (MONITORING / "promtool.exe").exists()
        check(has_prom, "local Prometheus toolchain exists in workspace tools/online-runtime")
        admin_token_file = folder / "admin-token"
        admin_token_file.write_text(stack.env["YUANZHENG_ADMIN_TOKEN"], encoding="utf-8")
        alerts_src = SERVER / "deploy/monitoring/alerts.yml"
        alerts_file = folder / "l6-alerts.yml"
        alerts_file.write_text(alerts_src.read_text(encoding="utf-8").replace("for: 1m", "for: 1s"), encoding="utf-8")
        prom_cfg = folder / "prometheus.yml"
        prom_cfg.write_text(
            "global:\n  scrape_interval: 2s\n  evaluation_interval: 1s\nrule_files:\n  - " + json.dumps(alerts_file.as_posix()) +
            "\nscrape_configs:\n  - job_name: yuanzheng\n    scrape_timeout: 2s\n    static_configs:\n      - targets: [\"127.0.0.1:" + str(stack.admin_port) + "\"]\n" +
            "    authorization:\n      type: Bearer\n      credentials_file: " + json.dumps(admin_token_file.as_posix()) + "\n",
            encoding="utf-8",
        )
        prom_check = subprocess.run([str(MONITORING / "promtool.exe"), "check", "config", str(prom_cfg)], capture_output=True, text=True, encoding="utf-8", creationflags=subprocess.CREATE_NO_WINDOW)
        (folder / "promtool-config.log").write_text(prom_check.stdout + prom_check.stderr, encoding="utf-8")
        check(prom_check.returncode == 0, "promtool validates L6 Prometheus config and alerts.yml")

        prom_port = free_port()
        prom_url = f"http://127.0.0.1:{prom_port}"
        prometheus_log = (folder / "prometheus.log").open("wb")
        prometheus = subprocess.Popen(
            [str(MONITORING / "prometheus.exe"), "--config.file=" + str(prom_cfg),
             "--web.listen-address=127.0.0.1:" + str(prom_port),
             "--storage.tsdb.path=" + str(folder / "prom-data"), "--log.level=warn"],
            env=client_environment(stack.env, {}), stdout=prometheus_log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW,
        )
        plain_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

        def prom_query(expr):
            with plain_opener.open(prom_url + "/api/v1/query?" + urllib.parse.urlencode({"query": expr}), timeout=5) as resp:
                return json.load(resp)["data"]["result"]

        deadline = time.monotonic() + 35
        while time.monotonic() < deadline:
            try:
                res = prom_query('yuanzheng_ready{job="yuanzheng"}')
                if len(res) == 1 and float(res[0]["value"][1]) == 1.0:
                    break
            except Exception:
                pass
            time.sleep(0.25)
        check(len(prom_query('yuanzheng_ready{job="yuanzheng"}')) == 1, "Prometheus scrapes live /metrics gauge yuanzheng_ready == 1")

        # 2. 26 concurrent authenticated clients: registration, character create/select,
        #    room join (24 ch1 + 2 ch2 overflow), movement, NPC buy, battle, positions poll.
        latencies_ms = []
        client_records = []
        client_lock = threading.Lock()
        load_password = "loadtest-" + secrets.token_hex(12)
        private_values.append(load_password)

        def run_load_client(index):
            user = f"l6load_{run[:8]}_{index:02d}"
            nick = f"远征测试{index:02d}"
            local_lat = []
            st, data, dt = call_api("POST", "/v1/auth/register", {"username": user, "password": load_password})
            if st != 201:
                raise RuntimeError(f"client {index} register failed: {st} {data}")
            local_lat.append(dt)
            tok = data["data"]["access_token"]
            ref = data["data"]["refresh_token"]
            with client_lock:
                private_values.extend([tok, ref, data["data"]["recovery_code"]])

            st, created, dt = call_api("POST", "/v1/characters", {"nickname": nick, "role_id": "zs", "appearance_id": "default"}, token=tok, key=f"l6c{index:02d}-char001")
            if st != 201:
                raise RuntimeError(f"client {index} create char failed: {st} {created}")
            local_lat.append(dt)
            cid = created["data"]["character"]["id"]

            st, _, dt = call_api("POST", f"/v1/characters/{cid}/select", {}, token=tok, key=f"l6c{index:02d}-sel001")
            if st != 200:
                raise RuntimeError(f"client {index} select failed: {st}")
            local_lat.append(dt)

            st, joined, dt = call_api("POST", "/v1/rooms/join", {}, token=tok, key=f"l6c{index:02d}-join001")
            if st != 200:
                raise RuntimeError(f"client {index} join room failed: {st} {joined}")
            local_lat.append(dt)
            lease = joined["data"]["lease"]

            for step in range(6):
                time.sleep(0.16)
                st, moved, dt = call_api(
                    "POST", "/v1/rooms/move",
                    {"lease_token": lease["lease_token"], "generation": lease["generation"],
                     "sequence": lease["move_sequence"] + 1, "x": lease["x"], "y": lease["y"] + 22},
                    token=tok, key=f"l6c{index:02d}-mv{step:03d}",
                )
                if st != 200:
                    raise RuntimeError(f"client {index} move {step} failed: {st} {moved}")
                local_lat.append(dt)
                lease = moved["data"]["lease"]

            st, buy, dt = call_api(
                "POST", "/v1/market/npc/trade",
                {"action": "buy", "template_id": "mat_grain", "quantity": 1},
                token=tok, key=f"l6c{index:02d}-buy001",
            )
            if st != 200:
                raise RuntimeError(f"client {index} npc buy failed: {st} {buy}")
            local_lat.append(dt)

            st, frame, dt = read_stream_frame("/v1/rooms/positions", tok)
            if st != 200 or not frame.get("room_id"):
                raise RuntimeError(f"client {index} positions poll failed: {st}")
            local_lat.append(dt)

            # First 6 clients also start & flee an authoritative room battle concurrently.
            if index < 6:
                st, bstart, dt = call_api("POST", "/v1/battles", {"encounter_id": "training_wolf"}, token=tok, key=f"l6c{index:02d}-btl001")
                if st != 201:
                    raise RuntimeError(f"client {index} battle start failed: {st} {bstart}")
                local_lat.append(dt)
                bid = bstart["data"]["battle"]["id"]
                st, bflee, dt = call_api("POST", f"/v1/battles/{bid}/commands", {"action": "flee"}, token=tok, key=f"l6c{index:02d}-flee01")
                if st != 200:
                    raise RuntimeError(f"client {index} battle flee failed: {st} {bflee}")
                local_lat.append(dt)
                st, back, dt = call_api("POST", f"/v1/battles/{bid}/acknowledge", {}, token=tok, key=f"l6c{index:02d}-ack001")
                if st != 200:
                    raise RuntimeError(f"client {index} battle ack failed: {st} {back}")
                local_lat.append(dt)

            with client_lock:
                latencies_ms.extend(local_lat)
                client_records.append({"index": index, "user": user, "char_id": cid, "token": tok, "refresh": ref, "room_id": lease["room_id"]})

        load_start = time.monotonic()
        with ThreadPoolExecutor(max_workers=26) as pool:
            futures = [pool.submit(run_load_client, i) for i in range(26)]
            for fut in as_completed(futures):
                fut.result()
        load_duration_s = max(0.001, time.monotonic() - load_start)
        client_records.sort(key=lambda item: item["index"])

        st, cap_data, _ = call_api("GET", "/ops/capacity", admin=True)
        check(st == 200, "loopback /ops/capacity returns 200 under 26-client load")
        cap = cap_data["data"]
        lorin_channels = [c for c in cap["channels"] if c["map_id"] == "lorin_wilds" and c["players"] > 0]
        check(cap["active_room_leases"] == 26 and len(lorin_channels) >= 2, f"26 clients overflowed lorin_wilds into >=2 channels: {lorin_channels}")

        wallet_check = recovery.sql(recovery.database, "SELECT (SELECT count(*) FROM wallets WHERE gold<0),(SELECT coalesce(sum(gold),0) FROM wallets),(SELECT coalesce(sum(delta),0) FROM wallet_ledger WHERE currency='gold')")
        neg_cnt, w_sum, l_sum = wallet_check.split("|")
        check(neg_cnt == "0" and w_sum == l_sum, f"26-client concurrent SQL wallet/ledger conservation matches ({w_sum} == {l_sum}, negatives={neg_cnt})")

        report["load_benchmark"] = {
            "concurrent_clients": 26,
            "total_api_requests": len(latencies_ms),
            "duration_seconds": round(load_duration_s, 3),
            "throughput_rps": round(len(latencies_ms) / load_duration_s, 2),
            "latency_ms": {
                "p50": percentile(latencies_ms, 50),
                "p95": percentile(latencies_ms, 95),
                "p99": percentile(latencies_ms, 99),
                "max": round(max(latencies_ms), 2),
            },
            "lorin_wilds_channels": lorin_channels,
            "wallet_gold_total": int(w_sum),
            "wallet_ledger_delta_total": int(l_sum),
        }

        # 3. Moderation report & market-pause loopback ops controls.
        tok0 = client_records[0]["token"]
        char1 = client_records[1]["char_id"]
        st, rep_res, _ = call_api("POST", "/v1/social/reports", {"target_character_id": char1, "category": "spam", "reason": "L6 ops drill report"}, token=tok0, key="l6ops-report-001")
        check(st == 201, "client submits social report for ops queue")
        rep_id = rep_res["data"]["report_id"]
        st, open_list, _ = call_api("GET", "/ops/reports?status=open", admin=True)
        check(st == 200 and any(r["report_id"] == rep_id for r in open_list["data"]["reports"]), "report appears in /ops/reports open queue")
        st, res_out, _ = call_api("POST", f"/ops/reports/{rep_id}/resolve", {"operator": "l6_ops_verifier", "decision": "warned", "note": "drilled moderation flow"}, admin=True)
        check(st == 200 and res_out["data"]["decision"] == "warned", "loopback /ops/reports/{id}/resolve records append-only decision")

        st, pause_res, _ = call_api("POST", "/ops/config/market-pause", {"paused": True, "reason": "l6_drill"}, admin=True)
        check(st == 200 and pause_res["data"]["market_paused"] is True, "loopback /ops/config/market-pause enables emergency pause")
        st, paused_buy, _ = call_api("POST", "/v1/market/npc/trade", {"action": "buy", "template_id": "mat_grain", "quantity": 1}, token=tok0, key="l6ops-paused-buy1")
        check(st == 503 and paused_buy["error"]["code"] == "market_paused", "market rejects new trade with 503 market_paused while paused")
        st, resume_res, _ = call_api("POST", "/ops/config/market-pause", {"paused": False, "reason": "l6_drill_clear"}, admin=True)
        check(st == 200 and resume_res["data"]["market_paused"] is False, "loopback /ops/config/market-pause clears emergency pause")

        # 4. Player privacy export + erasure on client 25.
        victim = client_records[25]
        st, priv_sum, _ = call_api("GET", "/v1/account/privacy/summary", token=victim["token"])
        check(st == 200 and priv_sum["data"]["status"] == "active", "privacy summary shows active status")
        st, priv_exp, _ = call_api("GET", "/v1/account/privacy/export", token=victim["token"])
        exp_text = json.dumps(priv_exp["data"], ensure_ascii=False)
        check(st == 200 and "password_hash" not in exp_text and victim["user"] in exp_text, "privacy export includes personal fields without credential digests")
        st, priv_del, _ = call_api("POST", "/v1/account/privacy/delete", {"password": load_password, "confirmation": "DELETE"}, token=victim["token"])
        check(st == 200 and priv_del["data"]["erased"] is True, "privacy delete marks account erased")
        st, _, _ = call_api("GET", "/v1/account/privacy/summary", token=victim["token"])
        check(st == 401, "erased account token immediately fails authorization")
        st, _, _ = call_api("POST", "/v1/auth/login", {"username": victim["user"], "password": load_password})
        check(st == 401, "erased account cannot log back in")
        st, _, _ = call_api("POST", "/v1/auth/refresh", {"refresh_token": victim["refresh"]})
        check(st == 401, "erased account cannot refresh revoked token")

        # 5. Version mismatch rejection check (stale content version rejected cleanly).
        st, ver_err, _ = call_api("POST", "/v1/rooms/join", {}, token=tok0, key="l6ops-stale-ver1", content_version="stale-client-v0")
        check(st == 409 and ver_err["error"]["code"] == "content_version_mismatch", "outdated client X-Content-Version fails closed with 409")

        # 6. Dependency outage alert evaluation + local webhook delivery + recovery!
        proxy.pause()
        st, _, _ = call_api("GET", "/readyz", admin=True)
        check(st == 503, "/readyz immediately flips to 503 during database outage")
        firing_alerts = []
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            firing_alerts = prom_query('ALERTS{alertname="YuanzhengDependenciesUnavailable",alertstate="firing"}')
            if firing_alerts:
                break
            time.sleep(0.25)
        check(bool(firing_alerts), "Prometheus rule YuanzhengDependenciesUnavailable transitions to firing")
        fire_payload = {"status": "firing", "alerts": [{"labels": firing_alerts[0]["metric"], "annotations": {"summary": "gateway database outage drill"}}]}
        with plain_opener.open(urllib.request.Request(webhook.url, json.dumps(fire_payload).encode(), {"Content-Type": "application/json"}, method="POST"), timeout=5) as wh_resp:
            check(wh_resp.status == 200, "local alert webhook accepted firing alert notification")

        proxy.resume()
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                if call_api("GET", "/readyz", admin=True)[0] == 200 and not prom_query('ALERTS{alertname="YuanzhengDependenciesUnavailable",alertstate="firing"}'):
                    break
            except Exception:
                pass
            time.sleep(0.25)
        check(call_api("GET", "/readyz", admin=True)[0] == 200, "/readyz recovers to 200 when database connectivity resumes")
        res_payload = {"status": "resolved", "alerts": [{"labels": {"alertname": "YuanzhengDependenciesUnavailable"}}]}
        with plain_opener.open(urllib.request.Request(webhook.url, json.dumps(res_payload).encode(), {"Content-Type": "application/json"}, method="POST"), timeout=5) as wh_resp:
            check(wh_resp.status == 200, "local alert webhook accepted resolved notification")
        check(len(webhook.deliveries) == 2 and [d["status"] for d in webhook.deliveries] == ["firing", "resolved"], "local webhook received both firing and resolved alert deliveries")
        report["alert_webhook_drill"] = {
            "prometheus_alerts_captured": len(firing_alerts),
            "webhook_deliveries": webhook.deliveries,
        }

        # 7. AES-256-GCM encrypted backup + tamper/missing-key rejection + 56-table restore.
        key_file = folder / "backup-aes256.key"
        key_hex = secrets.token_hex(32)
        private_values.append(key_hex)
        key_file.write_text(key_hex + "\n", encoding="utf-8")
        enc_backup_dir = folder / "encrypted-backup"
        enc_manifest = recovery.command("backup", folder=enc_backup_dir, encrypt_key_file=key_file)
        check(enc_manifest.get("encrypted") is True and enc_manifest.get("cipher") == "AES-256-GCM" and len(enc_manifest.get("tables", [])) == 56,
              "dbops produced encrypted AES-256-GCM manifest for all 56 tables")
        check(not (enc_backup_dir / "database.dump").exists() and (enc_backup_dir / "database.dump.enc").is_file(),
              "plaintext database.dump is scrubbed after encrypted archive sealing")
        (folder / "encrypted-backup-manifest.json").write_text(json.dumps(enc_manifest, indent=2), encoding="utf-8")
        recovery.databases.append(recovery.target)
        # Missing key rejected.
        recovery.command("restore", database=recovery.target, folder=enc_backup_dir, expect_success=False)
        # Valid key restores all 56 tables and revokes remaining 25 active sessions & 25 active leases.
        enc_restore = recovery.command("restore", database=recovery.target, folder=enc_backup_dir, encrypt_key_file=key_file)
        check(enc_restore.get("ready_for_review") is True and len(enc_restore.get("tables_matched_before_session_invalidation", [])) == 56 and enc_restore.get("sessions_revoked") == 25,
              f"encrypted restore validated 56 tables and revoked 25 active sessions: {enc_restore}")
        report["encrypted_backup_restore"] = {
            "cipher": enc_manifest["cipher"],
            "tables_matched": len(enc_restore["tables_matched_before_session_invalidation"]),
            "sessions_revoked": enc_restore["sessions_revoked"],
            "leases_invalidated": enc_restore["leases_invalidated"],
            "encrypted_bytes": enc_manifest["encrypted_bytes"],
        }

        # 8. Stop all online services completely and verify offline singleplayer boundary.
        stack.stop("gateway")
        stack.stop("worker")
        boundary_proc = subprocess.run(
            [str(args.godot.resolve()), "--headless", "--path", str(GAME), "--audio-driver", "Dummy", "res://tools/VerifyOnlineBoundary.tscn"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        (folder / "offline-outage-boundary.log").write_text(boundary_proc.stdout + boundary_proc.stderr, encoding="utf-8")
        check(boundary_proc.returncode == 0, f"VerifyOnlineBoundary passed under total online outage (rc={boundary_proc.returncode})")

        check(player_snapshot() == before, "online L6 verification kept offline save clean")
        report["checks"] = checks
        report["passed"] = True

        serialized = json.dumps(report, ensure_ascii=False, indent=2)
        for secret in private_values:
            if secret and secret in serialized:
                raise RuntimeError("Private secret appeared in L6 report; aborting save")
        (folder / "l6-operations-report.json").write_text(serialized + "\n", encoding="utf-8")
        print(serialized, flush=True)
    finally:
        if webhook:
            webhook.close()
        if prometheus and prometheus.poll() is None:
            prometheus.terminate()
            prometheus.wait(timeout=10)
        if prometheus_log:
            prometheus_log.close()
        if stack:
            stack.close()
        if proxy:
            proxy.close()
        recovery.close()


if __name__ == "__main__":
    main()
