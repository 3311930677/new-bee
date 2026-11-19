// dbops is an offline operator command. It is not linked into the game gateway.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"yuanzheng/online/internal/dbops"
	"yuanzheng/online/internal/online"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	action := flag.String("action", "", "provision, migrate, grant, backup or restore")
	database := flag.String("database", "", "Explicit existing empty database for provisioning, or new yz_restore_* target")
	migrator := flag.String("migrator-role", "", "Offline migration role")
	runtimeRole := flag.String("runtime-role", "", "Gateway runtime role")
	backupRole := flag.String("backup-role", "", "Read-only backup role")
	pgBin := flag.String("pg-bin", "", "Absolute directory of trusted PostgreSQL tools")
	folder := flag.String("folder", "", "Absolute new backup directory or existing trusted backup")
	encryptKeyFile := flag.String("encrypt-key-file", "", "Optional path to a 64-char hex AES-256 backup encryption key file")
	timeout := flag.Duration("timeout", 10*time.Minute, "Offline operation deadline, 1s to 60m")
	flag.Parse()
	if *timeout < time.Second || *timeout > time.Hour {
		return fmt.Errorf("offline operation deadline must be 1s to 60m")
	}
	env := map[string]string{"provision": "YUANZHENG_DBADMIN_URL", "migrate": "YUANZHENG_MIGRATION_DATABASE_URL", "grant": "YUANZHENG_DBADMIN_URL", "backup": "YUANZHENG_BACKUP_DATABASE_URL", "restore": "YUANZHENG_DBADMIN_URL"}[*action]
	if env == "" || os.Getenv(env) == "" {
		return fmt.Errorf("offline action and its dedicated database environment are required")
	}
	dsn := os.Getenv(env)
	config, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return fmt.Errorf("offline database configuration invalid")
	}
	if *action == "provision" && (*database == "" || config.ConnConfig.Database != *database) {
		return fmt.Errorf("provisioning database must explicitly match the admin connection")
	}
	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()
	db, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return fmt.Errorf("offline database connection invalid")
	}
	defer db.Close()
	if err = db.Ping(ctx); err != nil {
		return fmt.Errorf("offline database unavailable")
	}
	roles := dbops.Roles{Migrator: *migrator, Runtime: *runtimeRole, Backup: *backupRole}
	var result any = map[string]any{"action": *action, "completed": true}
	switch *action {
	case "provision":
		err = dbops.Provision(ctx, db, roles, [3]string{os.Getenv("YUANZHENG_MIGRATOR_PASSWORD"), os.Getenv("YUANZHENG_RUNTIME_PASSWORD"), os.Getenv("YUANZHENG_BACKUP_PASSWORD")})
	case "migrate":
		err = online.Migrate(ctx, db)
		if err != nil {
			// Migrations can contain private deployment data. Emit no SQL/DSN.
			err = fmt.Errorf("offline migration failed")
		}
	case "grant":
		err = dbops.GrantRuntime(ctx, db, roles)
	case "backup":
		result, err = dbops.BackupWithKey(ctx, db, dsn, *pgBin, *folder, *encryptKeyFile)
	case "restore":
		result, err = dbops.RestoreWithKey(ctx, db, dsn, *pgBin, *folder, *database, roles, *encryptKeyFile)
	}
	if err != nil {
		return err
	}
	return json.NewEncoder(os.Stdout).Encode(result)
}
