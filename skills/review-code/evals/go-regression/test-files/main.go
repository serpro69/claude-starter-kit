package main

import (
	"fmt"
	"os"
)

// Deploys a greeting message to stdout — runs standalone, no cluster dependencies.
func main() {
	name := os.Getenv("GREET_NAME")
	if name == "" {
		name = "world"
	}
	fmt.Printf("Hello, %s!\n", name)
}
