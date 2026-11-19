// Package dbops contains offline database operations, never exposed by the API.
package dbops

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"regexp"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/pbkdf2"
)

const Schema = "game"

var identifier = regexp.MustCompile(`^[a-z][a-z0-9_]{0,47}$`)
var password = regexp.MustCompile(`^[A-Za-z0-9_-]{32,128}$`)

type Roles struct {
	Migrator string `json:"migrator"`
	Runtime  string `json:"runtime"`
	Backup   string `json:"backup"`
}

func (r Roles) Validate() error {
	seen := map[string]bool{}
	for _, name := range []string{r.Migrator, r.Runtime, r.Backup} {
		if !identifier.MatchString(name) || strings.HasPrefix(name, "pg_") || seen[name] {
			return fmt.Errorf("three distinct application role names are required")
		}
		seen[name] = true
	}
	return nil
}

func quote(name string) string { return pgx.Identifier{name}.Sanitize() }

// Build the PostgreSQL SCRAM verifier before sending CREATE ROLE. Sending a
// plaintext PASSWORD clause could expose it in activity/error statement logs.
// Provision accepts ASCII URL-safe passwords, so SASLprep cannot change them.
// Format follows PostgreSQL src/common/scram-common.c, scram_build_secret.
func scramVerifier(value string) (string, error) {
	var salt [16]byte
	if _, err := rand.Read(salt[:]); err != nil {
		return "", fmt.Errorf("role password salt unavailable")
	}
	salted := pbkdf2.Key([]byte(value), salt[:], 4096, sha256.Size, sha256.New)
	key := func(label string) []byte {
		mac := hmac.New(sha256.New, salted)
		mac.Write([]byte(label))
		return mac.Sum(nil)
	}
	stored := sha256.Sum256(key("Client Key"))
	encode := base64.StdEncoding.EncodeToString
	return "SCRAM-SHA-256$4096:" + encode(salt[:]) + "$" + encode(stored[:]) + ":" + encode(key("Server Key")), nil
}

// Provision refuses any existing application objects or role names. It operates
// in one transaction against an explicitly selected, already-created empty DB.
func Provision(ctx context.Context, db *pgxpool.Pool, roles Roles, passwords [3]string) error {
	if err := roles.Validate(); err != nil {
		return err
	}
	for _, value := range passwords {
		if !password.MatchString(value) {
			return fmt.Errorf("role passwords must contain 32-128 URL-safe characters")
		}
	}
	if passwords[0] == passwords[1] || passwords[0] == passwords[2] || passwords[1] == passwords[2] {
		return fmt.Errorf("role passwords must be independent")
	}
	tx, err := db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("database provisioning unavailable")
	}
	defer tx.Rollback(ctx)
	var name string
	var occupied bool
	if err := tx.QueryRow(ctx, `SELECT current_database(),
      EXISTS(SELECT 1 FROM pg_namespace WHERE nspname !~ '^pg_' AND nspname NOT IN ('public','information_schema'))
      OR EXISTS(SELECT 1 FROM pg_depend d JOIN pg_namespace n ON n.oid=d.refobjid
        WHERE d.refclassid='pg_namespace'::regclass AND n.nspname='public')
      OR EXISTS(SELECT 1 FROM pg_extension WHERE extname<>'plpgsql')
      OR EXISTS(SELECT 1 FROM pg_largeobject_metadata)
      OR EXISTS(SELECT 1 FROM pg_foreign_data_wrapper)
      OR EXISTS(SELECT 1 FROM pg_foreign_server)
      OR EXISTS(SELECT 1 FROM pg_publication)
      OR EXISTS(SELECT 1 FROM pg_event_trigger)`).Scan(&name, &occupied); err != nil {
		return fmt.Errorf("empty database check unavailable")
	}
	if occupied || name == "postgres" || strings.HasPrefix(name, "template") || name == "yuanzheng_dev" || name == "yuanzheng_test" {
		return fmt.Errorf("provisioning requires a new empty application database")
	}
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(743012664); SET LOCAL password_encryption='scram-sha-256'`); err != nil {
		return fmt.Errorf("database provisioning lock unavailable")
	}
	for index, role := range []string{roles.Migrator, roles.Runtime, roles.Backup} {
		verifier, err := scramVerifier(passwords[index])
		if err != nil {
			return err
		}
		// The verifier's alphabet cannot contain a SQL quote. Plaintext is never
		// sent in a statement or included in errors or application logs.
		if _, err = tx.Exec(ctx, "CREATE ROLE "+quote(role)+" LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD '"+verifier+"'"); err != nil {
			return fmt.Errorf("application role creation failed; existing roles are never changed")
		}
	}
	statements := []string{
		"REVOKE ALL ON DATABASE " + quote(name) + " FROM PUBLIC",
		"REVOKE ALL ON SCHEMA public FROM PUBLIC",
		"CREATE SCHEMA game AUTHORIZATION " + quote(roles.Migrator),
		"GRANT CONNECT ON DATABASE " + quote(name) + " TO " + quote(roles.Migrator) + "," + quote(roles.Runtime) + "," + quote(roles.Backup),
		"GRANT USAGE ON SCHEMA game TO " + quote(roles.Runtime) + "," + quote(roles.Backup),
		"ALTER DEFAULT PRIVILEGES FOR ROLE " + quote(roles.Migrator) + " IN SCHEMA game GRANT SELECT ON TABLES TO " + quote(roles.Backup),
		"ALTER DEFAULT PRIVILEGES FOR ROLE " + quote(roles.Migrator) + " IN SCHEMA game GRANT SELECT ON SEQUENCES TO " + quote(roles.Backup),
		"ALTER DEFAULT PRIVILEGES FOR ROLE " + quote(roles.Migrator) + " IN SCHEMA game REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC",
	}
	for _, role := range []string{roles.Migrator, roles.Runtime, roles.Backup} {
		statements = append(statements, "ALTER ROLE "+quote(role)+" IN DATABASE "+quote(name)+" SET search_path=game")
	}
	for _, statement := range statements {
		if _, err = tx.Exec(ctx, statement); err != nil {
			return fmt.Errorf("database privilege provisioning failed")
		}
	}
	if err = tx.Commit(ctx); err != nil {
		return fmt.Errorf("database privilege provisioning commit failed")
	}
	return nil
}

// GrantRuntime enumerates current API writes. New tables receive no implicit
// runtime write grant; migration releases must explicitly review this list.
func GrantRuntime(ctx context.Context, db *pgxpool.Pool, roles Roles) error {
	if err := roles.Validate(); err != nil {
		return err
	}
	tx, err := db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("runtime grants unavailable")
	}
	defer tx.Rollback(ctx)
	for _, role := range []string{roles.Migrator, roles.Runtime, roles.Backup} {
		var safe bool
		if err = tx.QueryRow(ctx, `SELECT NOT(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)
          AND NOT EXISTS(SELECT 1 FROM pg_auth_members WHERE member=r.oid) FROM pg_roles r WHERE rolname=$1`, role).Scan(&safe); err != nil || !safe {
			return fmt.Errorf("runtime grants require independent restricted application roles")
		}
	}
	var database string
	if err = tx.QueryRow(ctx, "SELECT current_database()").Scan(&database); err != nil {
		return fmt.Errorf("runtime grants database unavailable")
	}
	statements := []string{
		"REVOKE ALL ON DATABASE " + quote(database) + " FROM PUBLIC",
		"REVOKE ALL ON SCHEMA public FROM PUBLIC",
		"GRANT CONNECT ON DATABASE " + quote(database) + " TO " + quote(roles.Migrator) + "," + quote(roles.Runtime) + "," + quote(roles.Backup),
		"REVOKE ALL ON SCHEMA game FROM PUBLIC",
		"REVOKE ALL ON ALL TABLES IN SCHEMA game FROM PUBLIC," + quote(roles.Runtime) + "," + quote(roles.Backup),
		"REVOKE ALL ON ALL SEQUENCES IN SCHEMA game FROM PUBLIC," + quote(roles.Runtime) + "," + quote(roles.Backup),
		"REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA game FROM PUBLIC",
		"GRANT USAGE ON SCHEMA game TO " + quote(roles.Runtime) + "," + quote(roles.Backup),
		"GRANT SELECT ON ALL TABLES IN SCHEMA game TO " + quote(roles.Backup),
		"GRANT SELECT ON ALL SEQUENCES IN SCHEMA game TO " + quote(roles.Backup),
		"ALTER DEFAULT PRIVILEGES FOR ROLE " + quote(roles.Migrator) + " IN SCHEMA game GRANT SELECT ON TABLES TO " + quote(roles.Backup),
		"ALTER DEFAULT PRIVILEGES FOR ROLE " + quote(roles.Migrator) + " IN SCHEMA game GRANT SELECT ON SEQUENCES TO " + quote(roles.Backup),
		"ALTER DEFAULT PRIVILEGES FOR ROLE " + quote(roles.Migrator) + " IN SCHEMA game REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC",
	}
	selectTables := "accounts,characters,sessions,wallets,wallet_ledger,inventory_items,inventory_ledger,character_progress,quest_events,npc_interactions,friend_requests,friendships,player_blocks,player_reports,chat_messages,parties,party_members,party_invites,coop_queues,coop_instances,coop_instance_members,coop_instance_drops,world_boss_events,world_boss_participations,market_orders,market_fills,market_payouts,trade_sessions,trade_offers,economy_alerts,guilds,guild_members,guild_invites,guild_warehouse,guild_audit_logs,guild_member_cooldowns,pvp_seasons,pvp_ratings,pvp_honor_wallets,pvp_honor_ledger,pvp_queues,pvp_challenges,pvp_matches,pvp_match_participants,account_privacy_requests,moderation_actions,command_receipts,audit_events,room_instances,room_leases,battles,battle_inputs,battle_results,battle_reward_claims,security_notifications,schema_migrations"
	insertTables := "accounts,characters,sessions,wallets,wallet_ledger,inventory_items,inventory_ledger,character_progress,quest_events,npc_interactions,friend_requests,friendships,player_blocks,player_reports,chat_messages,parties,party_members,party_invites,coop_queues,coop_instances,coop_instance_members,coop_instance_drops,world_boss_events,world_boss_participations,market_orders,market_fills,market_payouts,trade_sessions,trade_offers,economy_alerts,guilds,guild_members,guild_invites,guild_warehouse,guild_audit_logs,guild_member_cooldowns,pvp_seasons,pvp_ratings,pvp_honor_wallets,pvp_honor_ledger,pvp_queues,pvp_challenges,pvp_matches,pvp_match_participants,account_privacy_requests,moderation_actions,command_receipts,audit_events,room_instances,room_leases,battles,battle_inputs,battle_results,battle_reward_claims,security_notifications"
	updateTables := "accounts,characters,sessions,wallets,character_progress,npc_interactions,friend_requests,parties,party_members,party_invites,coop_queues,coop_instances,coop_instance_members,coop_instance_drops,world_boss_events,world_boss_participations,market_orders,market_payouts,trade_sessions,economy_alerts,guilds,guild_members,guild_invites,guild_warehouse,guild_member_cooldowns,pvp_seasons,pvp_ratings,pvp_honor_wallets,pvp_queues,pvp_challenges,pvp_matches,pvp_match_participants,room_leases,battles,battle_inputs,security_notifications"
	deleteTables := "friendships,player_blocks,parties,party_members,coop_queues,trade_offers,guild_members,pvp_queues"
	for _, grant := range []struct{ privilege, tables string }{{"SELECT", selectTables}, {"INSERT", insertTables}, {"UPDATE", updateTables}, {"DELETE", deleteTables}} {
		var tables []string
		for _, table := range strings.Split(grant.tables, ",") {
			tables = append(tables, pgx.Identifier{Schema, table}.Sanitize())
		}
		statements = append(statements, "GRANT "+grant.privilege+" ON "+strings.Join(tables, ",")+" TO "+quote(roles.Runtime))
	}
	statements = append(statements, "GRANT USAGE ON SEQUENCE game.audit_events_id_seq TO "+quote(roles.Runtime))
	statements = append(statements, "GRANT USAGE ON SEQUENCE game.chat_messages_id_seq TO "+quote(roles.Runtime))
	statements = append(statements, "GRANT USAGE ON SEQUENCE game.economy_alerts_id_seq TO "+quote(roles.Runtime))
	statements = append(statements, "GRANT USAGE ON SEQUENCE game.guild_audit_logs_id_seq TO "+quote(roles.Runtime))
	statements = append(statements, "GRANT USAGE ON SEQUENCE game.pvp_honor_ledger_id_seq TO "+quote(roles.Runtime))
	statements = append(statements, "GRANT USAGE ON SEQUENCE game.moderation_actions_id_seq TO "+quote(roles.Runtime))
	statements = append(statements, "GRANT UPDATE (quantity,equipped_slot,version,updated_at) ON game.inventory_items TO "+quote(roles.Runtime))
	for _, role := range []string{roles.Migrator, roles.Runtime, roles.Backup} {
		statements = append(statements, "ALTER ROLE "+quote(role)+" IN DATABASE "+quote(database)+" SET search_path=game")
	}
	for _, statement := range statements {
		if _, err = tx.Exec(ctx, statement); err != nil {
			return fmt.Errorf("runtime privilege grant failed")
		}
	}
	if err = tx.Commit(ctx); err != nil {
		return fmt.Errorf("runtime privilege grant commit failed")
	}
	return nil
}
