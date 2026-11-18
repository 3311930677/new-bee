"""Real database-role and restore drill used by the two-Godot-client verifier.

Only generated disposable databases/roles are created or dropped. Dumps, TLS
keys and credentials stay in .local; report JSON never contains a connection URL.
"""
import hashlib
import json
from pathlib import Path
import re
import secrets
import subprocess
import urllib.parse
import uuid

from dev import PG, SERVER, config, environment, gateway_environment
from local_stack import free_port


class DatabaseRecovery:
    def __init__(self, folder):
        self.folder = Path(folder).resolve()
        self.tag = uuid.uuid4().hex[:20]
        self.database = "yz_drill_" + self.tag
        self.target = "yz_restore_" + self.tag
        self.roles = {"migrator": "yz_" + self.tag + "_m", "runtime": "yz_" + self.tag + "_r", "backup": "yz_" + self.tag + "_b"}
        self.passwords = {key: secrets.token_hex(24) for key in self.roles}
        self.cfg = config()
        self.private = [self.cfg["password"], *self.passwords.values()]
        self.databases = []
        self.roles_created = False
        self.events = []

    def url(self, database, kind=None):
        user = self.roles[kind] if kind else "yuanzheng"
        password = self.passwords[kind] if kind else self.cfg["password"]
        return f"postgres://{user}:{urllib.parse.quote(password, safe='')}@127.0.0.1:{self.cfg['port']}/{database}?sslmode=disable"

    def sql(self, database, statement, *, timeout=45):
        # Every identifier comes from this object's generated names; secret SQL
        # is never constructed here. SQL goes through stdin, not process args.
        result = subprocess.run([str(PG / "psql.exe"), "-h", "127.0.0.1", "-p", str(self.cfg["port"]),
                                 "-U", "yuanzheng", "-d", database, "-v", "ON_ERROR_STOP=1", "-At", "-q"],
                                input=statement, env=environment() | {"PGPASSWORD": self.cfg["password"], "PGOPTIONS": "-c search_path=game", "PGCLIENTENCODING": "UTF8"},
                                capture_output=True, text=True, encoding="utf-8", timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW)
        if result.returncode:
            raise RuntimeError("Disposable database drill SQL failed; credentials and query data were not logged")
        return result.stdout.strip()

    def command(self, action, *, database=None, folder=None, expect_success=True):
        args = [str(SERVER / "bin/dbops.exe"), "--action", action]
        for key, name in self.roles.items():
            args += ["--" + key + "-role", name]
        if database:
            args += ["--database", database]
        if folder:
            args += ["--folder", str(folder), "--pg-bin", str(PG)]
        env = {key: value for key, value in environment().items() if not key.startswith("YUANZHENG_") and not key.upper().startswith("PG")}
        env |= {"YUANZHENG_DBADMIN_URL": self.url(self.database if action != "restore" else "postgres"),
                "YUANZHENG_MIGRATION_DATABASE_URL": self.url(self.database, "migrator"),
                "YUANZHENG_BACKUP_DATABASE_URL": self.url(self.database, "backup"),
                "YUANZHENG_MIGRATOR_PASSWORD": self.passwords["migrator"], "YUANZHENG_RUNTIME_PASSWORD": self.passwords["runtime"],
                "YUANZHENG_BACKUP_PASSWORD": self.passwords["backup"]}
        result = subprocess.run(args, env=env, capture_output=True, text=True, encoding="utf-8", timeout=180, creationflags=subprocess.CREATE_NO_WINDOW)
        output = result.stdout + result.stderr
        if any(value in output for value in self.private) or "postgres://" in output or re.search(r"YZR-[A-Za-z0-9_-]{43}", output):
            raise RuntimeError("Offline tool emitted private data; report was withheld")
        self.events.append({"action": action, "exit_code": result.returncode, "expected_success": expect_success})
        (self.folder / (f"dbops-{len(self.events)}-{action}.log")).write_text(output, encoding="utf-8")
        if (result.returncode == 0) != expect_success:
            raise RuntimeError("Offline database action did not produce the expected exit code: " + action)
        return json.loads(result.stdout) if expect_success else None

    def create_tls(self):
        path = self.folder / "tls"
        result = subprocess.run([str(SERVER / "bin/devcert.exe"), "--out", str(path)], capture_output=True, text=True,
                                encoding="utf-8", timeout=45, creationflags=subprocess.CREATE_NO_WINDOW)
        if result.returncode:
            raise RuntimeError("Disposable certificate generation failed")
        (self.folder / "certificate-generation.log").write_text(result.stdout, encoding="utf-8")
        return path

    def select_database(self, stack, database):
        stack.env["YUANZHENG_DATABASE_URL"] = self.url(database, "runtime")
        index = stack.psql.index("-d") + 1
        stack.psql[index] = database
        stack.pg_env["PGOPTIONS"] = "-c search_path=game"

    def provision(self, stack):
        self.sql("postgres", f'CREATE DATABASE "{self.database}" TEMPLATE template0;')
        self.databases.append(self.database)
        self.command("provision", database=self.database)
        self.roles_created = True
        self.command("migrate")
        self.command("grant")
        self.select_database(stack, self.database)
        private_names = {"YUANZHENG_TEST_DATABASE_URL", "YUANZHENG_DBADMIN_URL", "YUANZHENG_MIGRATION_DATABASE_URL", "YUANZHENG_BACKUP_DATABASE_URL", "PGPASSWORD"}
        if private_names.intersection(gateway_environment(stack.env)):
            raise RuntimeError("Gateway environment includes offline credentials")
        clean_env = gateway_environment(stack.env)
        self.reject_gateway("offline-credential", clean_env | {"YUANZHENG_DBADMIN_URL": self.url(self.database)}, "must not inherit offline database credentials")
        self.reject_gateway("owner-role", clean_env | {"YUANZHENG_DATABASE_URL": self.url(self.database) + "&search_path=game"}, "ownership or administrative privileges")
        self.sql(self.database, "INSERT INTO schema_migrations(name,sha256) VALUES('999_drill_future.sql','future')")
        try:
            self.reject_gateway("future-schema", clean_env, "migration set does not match")
            self.command("migrate", expect_success=False)
        finally:
            self.sql(self.database, "DELETE FROM schema_migrations WHERE name='999_drill_future.sql'")

    def reject_gateway(self, name, env, reason):
        result = subprocess.run([str(SERVER / "bin/gateway.exe"), "--game-root", str(SERVER.parent),
                                 "--listen", f"127.0.0.1:{free_port()}", "--migration-mode", "check", "--require-restricted-database"],
                                env=env, capture_output=True, text=True, encoding="utf-8", timeout=35, creationflags=subprocess.CREATE_NO_WINDOW)
        output = result.stdout + result.stderr
        if result.returncode == 0 or reason not in output or "postgres://" in output or any(value in output for value in self.private):
            raise RuntimeError("Actual gateway did not safely reject " + name)
        (self.folder / ("gateway-rejected-" + name + ".log")).write_text(output, encoding="utf-8")
        self.events.append({"action": "gateway-reject-" + name, "exit_code": result.returncode, "expected_success": False})

    def restore(self, stack, *, expected_gateway_starts=3):
        counts_sql = "SELECT (SELECT count(*) FROM accounts),(SELECT count(*) FROM wallets WHERE gold=110),(SELECT count(*) FROM wallet_ledger WHERE reason='battle_reward'),(SELECT count(*) FROM battles WHERE acknowledged_at IS NULL),(SELECT count(*) FROM battle_results),(SELECT count(*) FROM battle_reward_claims),(SELECT count(*) FROM sessions WHERE revoked_at IS NULL)"
        before = stack.sql(counts_sql).split("|")
        if before != ["2"] * 7:
            raise RuntimeError("Real pre-backup victories or active sessions are incomplete")
        backup = self.folder / "backup-private"
        manifest = self.command("backup", folder=backup)
        if len(manifest.get("tables", [])) != 28:
            raise RuntimeError("Backup did not include every migrated game table")
        (self.folder / "backup-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        stack.sql("INSERT INTO audit_events(action) VALUES('restore.drill.after_backup')")
        stack.stop("gateway")
        stack.stop("worker")
        # This target was generated for this run; failures are also cleaned up.
        self.databases.append(self.target)
        restored = self.command("restore", database=self.target, folder=backup)
        (self.folder / "restore-report.json").write_text(json.dumps(restored, indent=2), encoding="utf-8")
        if not restored.get("ready_for_review") or restored.get("sessions_revoked") != 2 or restored.get("leases_invalidated") != 2:
            raise RuntimeError("Native restore did not validate/revoke both sessions and leases")
        self.command("restore", database=self.target, folder=backup, expect_success=False)
        self.select_database(stack, self.target)
        after = stack.sql(counts_sql).split("|")
        leases = stack.sql("SELECT count(*) FROM room_leases WHERE expires_at>now()")
        marker = stack.sql("SELECT count(*) FROM audit_events WHERE action='restore.drill.after_backup'")
        source_marker = self.sql(self.database, "SELECT count(*) FROM audit_events WHERE action='restore.drill.after_backup'")
        if after != ["2", "2", "2", "2", "2", "2", "0"] or leases != "0" or marker != "0" or source_marker != "1":
            raise RuntimeError("Restored independent SQL counts, lease expiry or snapshot boundary mismatch")
        stack.start_worker()
        stack.start_gateway()
        if hasattr(stack, "sync_logs"):
            stack.sync_logs()
        gateway_events = [json.loads(line) for path in self.folder.glob("gateway-[0-9]*.log") for line in path.read_text(encoding="utf-8").splitlines() if line.startswith("{")]
        migrations = [event for event in gateway_events if event.get("msg") == "database migrations ready"]
        if len(migrations) != expected_gateway_starts or not all(event.get("mode") == "check" and event.get("restricted_role") for event in migrations):
            raise RuntimeError("Every expected gateway start must verify a restricted runtime role without DDL")
        return {"passed": True, "scope": "actual read-only-role pg_dump, new-database restore, two real unconfirmed Godot victories; no live endpoint promotion",
                "tables_matched": len(restored["tables_matched_before_session_invalidation"]), "before_counts": before, "restored_counts": after,
                "expired_leases": restored["leases_invalidated"], "revoked_sessions": restored["sessions_revoked"],
                "post_backup_source_audit_retained": source_marker == "1", "post_backup_audit_absent_from_restored_snapshot": marker == "0",
                "gateway_restricted_starts": len(migrations), "backup_started_utc": manifest["started_utc"], "backup_finished_utc": manifest["finished_utc"],
                "restore_started_utc": restored["started_utc"], "restore_finished_utc": restored["finished_utc"], "dump_sha256": manifest["dump_sha256"],
                "dbops_binary_sha256": hashlib.sha256((SERVER / "bin/dbops.exe").read_bytes()).hexdigest(), "offline_actions": self.events}

    def close(self):
        for database in reversed(self.databases):
            if not re.fullmatch(r"yz_(drill|restore)_[0-9a-f]{20}", database):
                raise RuntimeError("Refused unsafe disposable database cleanup")
            self.sql("postgres", f'DROP DATABASE IF EXISTS "{database}" WITH (FORCE);', timeout=120)
        if self.roles_created:
            for role in self.roles.values():
                if not re.fullmatch(r"yz_[0-9a-f]{20}_[mrb]", role):
                    raise RuntimeError("Refused unsafe disposable role cleanup")
                self.sql("postgres", f'DROP ROLE "{role}";', timeout=120)
