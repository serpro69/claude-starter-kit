package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

func GeneratePluginManifest(m *Manifest, dryRun bool) error {
	outDir := filepath.Join(m.TargetPlugin, ".codex-plugin")
	outPath := filepath.Join(outDir, "plugin.json")

	if dryRun {
		fmt.Printf("[dry-run] generate manifest → %s\n", outPath)
		return nil
	}

	version, err := readSourceVersion(m.Manifest.VersionFrom)
	if err != nil {
		return fmt.Errorf("reading source version: %w", err)
	}

	manifest := map[string]any{
		"name":    m.Manifest.Name,
		"version": version,
	}
	for k, v := range m.Manifest.ExtraFields {
		manifest[k] = v
	}

	data, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return fmt.Errorf("marshaling manifest: %w", err)
	}
	data = append(data, '\n')

	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return fmt.Errorf("creating directory: %w", err)
	}
	if err := os.WriteFile(outPath, data, 0o644); err != nil {
		return fmt.Errorf("writing manifest: %w", err)
	}

	fmt.Printf("generated %s\n", outPath)
	return nil
}

func readSourceVersion(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("reading %s: %w", path, err)
	}

	var source struct {
		Version string `json:"version"`
	}
	if err := json.Unmarshal(data, &source); err != nil {
		return "", fmt.Errorf("parsing %s: %w", path, err)
	}
	if source.Version == "" {
		return "", fmt.Errorf("no version field in %s", path)
	}

	return source.Version, nil
}
