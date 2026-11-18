package dbops

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"yuanzheng/online/internal/online"
)

func seedRestoreFixtures(t *testing.T, f *databaseFixture, pair map[string]any, charID string) string {
	t.Helper()
	// These are explicitly SQL fixtures for dump/restore constraints, not a
	// claim of combat correctness. verify_database.py uses real Godot battles.
	var account, room, battle, result string
	if err := f.admin.QueryRow(f.ctx, `SELECT account_id::text FROM characters WHERE id=$1`, charID).Scan(&account); err != nil {
		t.Fatal(err)
	}
	for _, target := range []*string{&room, &battle, &result} {
		if err := f.admin.QueryRow(f.ctx, `SELECT gen_random_uuid()::text`).Scan(target); err != nil {
			t.Fatal(err)
		}
	}
	tx, err := f.admin.Begin(f.ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback(f.ctx)
	statements := []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO room_instances(id,map_id,channel,capacity) VALUES($1,'lorin_wilds',1,24)`, []any{room}},
		{`INSERT INTO room_leases(account_id,character_id,session_id,room_id,token,generation,x,y,expires_at) VALUES($1,$2,$3,$4,gen_random_uuid(),1,600,1520,now()+interval '1 hour')`, []any{account, charID, pair["session_id"], room}},
		{`INSERT INTO battles(id,account_id,character_id,room_id,encounter_id,role_id,level,monster_id,seed,content_version,ruleset_version,reward_gold,reward_experience,reward_policy,status,result,snapshot,settled_at) VALUES($1,$2,$3,$4,'dump_fixture','zs',1,'mon_wolf',123,'dbops-v1','online-0.1',10,5,'once','settled','victory','{"finished":true,"result":"victory"}',now())`, []any{battle, account, charID, room}},
		{`INSERT INTO battle_inputs(battle_id,sequence,tick,action,accepted,applied_tick) VALUES($1,1,1,'{"action":"attack"}',true,1)`, []any{battle}},
		{`UPDATE wallets SET gold=110,version=version+1 WHERE character_id=$1`, []any{charID}},
		{`UPDATE characters SET experience=5,version=version+1 WHERE id=$1`, []any{charID}},
		{`INSERT INTO wallet_ledger(id,character_id,transaction_id,currency,delta,balance_after,reason) VALUES(gen_random_uuid(),$1,$2,'gold',10,110,'battle_reward')`, []any{charID, "battle:" + battle}},
		{`INSERT INTO battle_results(result_id,battle_id,character_id,result,state_hash,gold,experience,wallet_balance,final_snapshot) VALUES($1,$2,$3,'victory','fixture',10,5,110,'{"finished":true,"result":"victory"}')`, []any{result, battle, charID}},
		{`INSERT INTO battle_reward_claims(character_id,encounter_id,result_id) VALUES($1,'dump_fixture',$2)`, []any{charID, result}},
		{`INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,source_transaction) VALUES(gen_random_uuid(),$1,'restore_fixture',3,'fixture')`, []any{charID}},
		{`INSERT INTO security_notifications(id,account_id,kind) VALUES(gen_random_uuid(),$1,'recovery_code_replaced')`, []any{account}},
	}
	for _, statement := range statements {
		if _, err = tx.Exec(f.ctx, statement.sql, statement.args...); err != nil {
			t.Fatal("SQL restore fixture creation failed")
		}
	}
	if err = tx.Commit(f.ctx); err != nil {
		t.Fatal(err)
	}
	return battle
}

func TestLogicalBackupMatchesExportedSnapshotAndRestoresToNewDatabase(t *testing.T) {
	f := newFixture(t)
	_, pair, charID := createTestCharacter(t, f.app)
	battleID := seedRestoreFixtures(t, f, pair, charID)
	folder := filepath.Join(t.TempDir(), "backup")
	// Hold the final table scan so a real concurrent transaction commits after
	// the exported snapshot. Both the manifest and pg_dump must retain 110.
	writer, err := f.admin.Begin(f.ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer writer.Rollback(context.Background())
	if _, err = writer.Exec(f.ctx, `LOCK TABLE wallets IN ACCESS EXCLUSIVE MODE`); err != nil {
		t.Fatal(err)
	}
	type outcome struct {
		manifest *BackupManifest
		err      error
	}
	done := make(chan outcome, 1)
	toolsDirectory := pgBin(t)
	go func() { m, e := Backup(f.ctx, f.reader, f.backupDSN, toolsDirectory, folder); done <- outcome{m, e} }()
	locked := false
	deadline := time.Now().Add(15 * time.Second)
	for time.Now().Before(deadline) {
		if err = f.admin.QueryRow(f.ctx, `SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE datname=$1 AND usename=$2 AND wait_event_type='Lock')`, f.name, f.roles.Backup).Scan(&locked); err != nil {
			t.Fatal(err)
		}
		if locked {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if !locked {
		t.Fatal("backup did not establish the blocked snapshot")
	}
	if _, err = writer.Exec(f.ctx, `UPDATE wallets SET gold=117 WHERE character_id=$1`, charID); err != nil {
		t.Fatal(err)
	}
	if _, err = writer.Exec(f.ctx, `INSERT INTO wallet_ledger(id,character_id,transaction_id,currency,delta,balance_after,reason) VALUES(gen_random_uuid(),$1,'after-snapshot','gold',7,117,'fixture_after_snapshot')`, charID); err != nil {
		t.Fatal(err)
	}
	if err = writer.Commit(f.ctx); err != nil {
		t.Fatal(err)
	}
	result := <-done
	if result.err != nil {
		t.Fatal(result.err)
	}
	if len(result.manifest.Tables) != 19 {
		t.Fatalf("expected all 19 application tables, got %d", len(result.manifest.Tables))
	}
	target := "yz_restore_" + randomHex()[:20]
	f.databases = append(f.databases, target)
	restored, err := Restore(f.ctx, f.cluster, f.dsn, pgBin(t), folder, target, f.roles)
	if err != nil {
		t.Fatal(err)
	}
	if !restored.ReadyForReview || restored.SessionsRevoked != 1 || restored.LeasesInvalidated != 1 || len(restored.TablesMatched) != 19 {
		t.Fatal("restore did not validate all tables or invalidate sessions")
	}
	db := f.pool(t, target, "", "")
	var gold, sourceGold, quantity, results, claims, pending, validSessions, liveLeases int
	if err = db.QueryRow(f.ctx, `SELECT (SELECT gold FROM wallets),(SELECT quantity FROM inventory_items),(SELECT count(*) FROM battle_results),(SELECT count(*) FROM battle_reward_claims),(SELECT count(*) FROM battles WHERE acknowledged_at IS NULL),(SELECT count(*) FROM sessions WHERE revoked_at IS NULL),(SELECT count(*) FROM room_leases WHERE expires_at>now())`).Scan(&gold, &quantity, &results, &claims, &pending, &validSessions, &liveLeases); err != nil {
		t.Fatal(err)
	}
	if err = f.admin.QueryRow(f.ctx, `SELECT gold FROM wallets`).Scan(&sourceGold); err != nil {
		t.Fatal(err)
	}
	if gold != 110 || sourceGold != 117 || quantity != 3 || results != 1 || claims != 1 || pending != 1 || validSessions != 0 || liveLeases != 0 {
		t.Fatal("restored snapshot, assets, pending result or session boundary mismatch")
	}
	rejectCode(t, db, `UPDATE wallet_ledger SET delta=delta`, "P0001")
	rejectCode(t, db, `INSERT INTO battle_reward_claims SELECT * FROM battle_reward_claims`, "23505")
	rejectCode(t, db, `UPDATE wallets SET gold=-1`, "23514")
	rejectCode(t, db, `INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,source_transaction) VALUES(gen_random_uuid(),gen_random_uuid(),'invalid',1,'invalid')`, "23503")
	config := f.app.Config()
	config.ConnConfig.Database = target
	runtimePool, err := pgxpool.NewWithConfig(f.ctx, config)
	if err != nil {
		t.Fatal(err)
	}
	f.pools = append(f.pools, runtimePool)
	if err = online.CheckMigrations(f.ctx, runtimePool); err != nil {
		t.Fatal(err)
	}
	if err = online.CheckRuntimePrivileges(f.ctx, runtimePool); err != nil {
		t.Fatal(err)
	}
	a := newAPI(t, runtimePool)
	a.request(401, "GET", "/v1/session", pair["access_token"].(string), "", nil)
	a.request(401, "POST", "/v1/auth/refresh", "", "", map[string]any{"refresh_token": pair["refresh_token"]})
	login := a.request(200, "POST", "/v1/auth/login", "", "", map[string]any{"username": "backup_account", "password": "test-password-long"})
	token := login["access_token"].(string)
	created := a.request(201, "POST", "/v1/characters", token, "backup-create-001", map[string]any{"nickname": "恢复旅人", "role_id": "zs", "appearance_id": "default"})
	if created["character"].(map[string]any)["id"] != charID {
		t.Fatal("restored idempotency receipt created another character")
	}
	a.request(200, "POST", "/v1/characters/"+charID+"/select", token, "restored-select-001", map[string]any{})
	active := a.request(200, "GET", "/v1/battles/active", token, "", nil)
	if active["battle"].(map[string]any)["id"] != battleID {
		t.Fatal("restored pending settlement was lost")
	}
	for i := 0; i < 2; i++ {
		a.request(200, "POST", "/v1/battles/"+battleID+"/acknowledge", token, "restore-ack-001", map[string]any{})
	}
	a.request(201, "POST", "/v1/characters", token, "restore-new-create", map[string]any{"nickname": "恢复新旅人", "role_id": "fs", "appearance_id": "default"})
	var ledgerCount, auditCount int
	if err = db.QueryRow(f.ctx, `SELECT (SELECT count(*) FROM wallet_ledger WHERE reason='battle_reward'),(SELECT count(*) FROM audit_events)`).Scan(&ledgerCount, &auditCount); err != nil || ledgerCount != 1 || auditCount != 2 {
		t.Fatal("restored rewards or identity sequence duplicated")
	}
	if _, err = Restore(f.ctx, f.cluster, f.dsn, pgBin(t), folder, target, f.roles); err == nil {
		t.Fatal("restore overwrote an existing target")
	}
	t.Logf("actual pg_dump/pg_restore matched all %d tables at exported snapshot despite concurrent 110->117 commit; old tokens rejected; receipt, pending settlement, one reward and audit sequence survived", len(restored.TablesMatched))
}

func TestRestoreRejectsCorruptionBeforeCreatingDatabase(t *testing.T) {
	f := newFixture(t)
	createTestCharacter(t, f.app)
	folder := filepath.Join(t.TempDir(), "backup")
	if _, err := Backup(f.ctx, f.reader, f.backupDSN, pgBin(t), folder); err != nil {
		t.Fatal(err)
	}
	archive := filepath.Join(folder, "database.dump")
	file, err := os.OpenFile(archive, os.O_WRONLY|os.O_APPEND, 0600)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = file.Write([]byte("corrupted"))
	_ = file.Close()
	target := "yz_restore_" + randomHex()[:20]
	if _, err = Restore(f.ctx, f.cluster, f.dsn, pgBin(t), folder, target, f.roles); err == nil || !strings.Contains(err.Error(), "checksum") {
		t.Fatal("corrupt archive was not rejected")
	}
	var exists bool
	if err = f.cluster.QueryRow(f.ctx, `SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname=$1)`, target).Scan(&exists); err != nil || exists {
		t.Fatal("corrupt restore created or changed a target database")
	}
	t.Log("corrupt dump rejected by hash before CREATE DATABASE")
}

func TestNativeToolEnvironmentKeepsCredentialsOffCommandArguments(t *testing.T) {
	t.Setenv("PGPASSWORD", "inherited-password")
	t.Setenv("YUANZHENG_ADMIN_TOKEN", "private-admin-token")
	values, err := privatePGEnvironment("postgres://backup:correct-password@127.0.0.1:55432/game_db?sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}
	joined := strings.Join(values, "\n")
	if strings.Contains(joined, "inherited-password") || strings.Contains(joined, "private-admin-token") || strings.Contains(joined, "postgres://") || !strings.Contains(joined, "PGPASSWORD=correct-password") {
		t.Fatal("native tool environment retained unrelated credentials or full DSN")
	}
	if _, err = privatePGEnvironment("postgres://backup:private@127.0.0.1/game_db?options=unsafe"); err == nil || strings.Contains(err.Error(), "private") {
		t.Fatal("unsupported URL options or credential disclosure")
	}
}

func TestFailedRestoreQuarantinesOnlyItsNewDatabase(t *testing.T) {
	f := newFixture(t)
	createTestCharacter(t, f.app)
	folder := filepath.Join(t.TempDir(), "backup")
	manifest, err := Backup(f.ctx, f.reader, f.backupDSN, pgBin(t), folder)
	if err != nil {
		t.Fatal(err)
	}
	manifest.Tables[0].SHA256 = strings.Repeat("0", 64)
	data, _ := json.Marshal(manifest)
	if err = os.WriteFile(filepath.Join(folder, "manifest.json"), data, 0600); err != nil {
		t.Fatal(err)
	}
	target := "yz_restore_" + randomHex()[:20]
	f.databases = append(f.databases, target)
	if _, err = Restore(f.ctx, f.cluster, f.dsn, pgBin(t), folder, target, f.roles); err == nil || !strings.Contains(err.Error(), "do not match") {
		t.Fatal("mismatched restored data was accepted")
	}
	var runtimeConnect, backupConnect, publicConnect bool
	if err = f.cluster.QueryRow(f.ctx, `SELECT has_database_privilege($1,$3,'CONNECT'),has_database_privilege($2,$3,'CONNECT'),EXISTS(SELECT 1 FROM pg_database d,aclexplode(d.datacl) a WHERE d.datname=$3 AND a.grantee=0 AND a.privilege_type='CONNECT')`, f.roles.Runtime, f.roles.Backup, target).Scan(&runtimeConnect, &backupConnect, &publicConnect); err != nil || runtimeConnect || backupConnect || publicConnect {
		t.Fatal("failed new restore database was not quarantined")
	}
	var gold int
	if err = f.admin.QueryRow(f.ctx, `SELECT gold FROM wallets`).Scan(&gold); err != nil || gold != 100 {
		t.Fatal("failed restore changed its source")
	}
	if _, err = os.Stat(filepath.Join(folder, target+"-restore.json")); !os.IsNotExist(err) {
		t.Fatal("failed restore published a successful review report")
	}
	t.Log("mismatched restored rows left only the new DB quarantined; source assets unchanged and no success report published")
}
