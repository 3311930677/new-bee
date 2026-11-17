package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"

	"yuanzheng/online/internal/devcert"
)

func main() {
	out := flag.String("out", "", "New output directory; existing directories are never overwritten")
	negative := flag.Bool("negative-fixtures", false, "Also generate wrong-name, expired and untrusted-CA fixtures for verification")
	flag.Parse()
	if *out == "" {
		fmt.Fprintln(os.Stderr, "--out is required")
		os.Exit(2)
	}
	manifest, err := devcert.Create(*out, *negative, time.Now())
	if err != nil {
		fmt.Fprintln(os.Stderr, "development certificates failed:", err)
		os.Exit(1)
	}
	if err = json.NewEncoder(os.Stdout).Encode(manifest); err != nil {
		os.Exit(1)
	}
}
