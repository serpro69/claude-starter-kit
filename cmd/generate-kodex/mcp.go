package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type mcpServerJSON struct {
	Command string   `json:"command"`
	Args    []string `json:"args"`
}

func GenerateMCPConfig(m *Manifest, dryRun bool) error {
	outPath := filepath.Join(m.TargetPlugin, ".mcp.json")

	if dryRun {
		fmt.Printf("[dry-run] generate MCP config → %s\n", outPath)
		return nil
	}

	servers := make(map[string]mcpServerJSON, len(m.MCP.Servers))
	for name, srv := range m.MCP.Servers {
		servers[name] = mcpServerJSON{
			Command: srv.Command,
			Args:    srv.Args,
		}
	}

	out := map[string]any{
		"mcpServers": servers,
	}

	data, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return fmt.Errorf("marshaling MCP config: %w", err)
	}
	data = append(data, '\n')

	if err := os.WriteFile(outPath, data, 0o644); err != nil {
		return fmt.Errorf("writing MCP config: %w", err)
	}

	fmt.Printf("generated %s\n", outPath)
	return nil
}
