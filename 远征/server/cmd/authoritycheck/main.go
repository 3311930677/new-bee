// authoritycheck verifies the authenticated private worker before a deployment joins it.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"

	"yuanzheng/online/internal/authority"
)

func main() {
	address := flag.String("address", "127.0.0.1:19081", "private worker loopback address")
	content := flag.String("content-version", "", "expected game content SHA256")
	ruleset := flag.String("ruleset-version", "online-0.1", "expected rule version")
	flag.Parse()
	client, err := authority.New(*address, []byte(os.Getenv("YUANZHENG_ROOM_SECRET")), *content, *ruleset)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	health, err := client.Ping(ctx)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if err = json.NewEncoder(os.Stdout).Encode(health); err != nil {
		os.Exit(1)
	}
}
