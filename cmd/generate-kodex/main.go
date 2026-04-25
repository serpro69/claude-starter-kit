package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	manifestPath := flag.String("manifest", "", "path to the generation manifest YAML file (required)")
	target := flag.String("target", "", "override target plugin directory (default: from manifest)")
	dryRun := flag.Bool("dry-run", false, "print planned actions without writing files")
	flag.Parse()

	if *manifestPath == "" {
		fmt.Fprintln(os.Stderr, "error: -manifest is required")
		flag.Usage()
		os.Exit(1)
	}

	if err := run(*manifestPath, *target, *dryRun); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run(manifestPath, targetOverride string, dryRun bool) error {
	m, err := ParseManifest(manifestPath)
	if err != nil {
		return fmt.Errorf("parsing manifest: %w", err)
	}

	if targetOverride != "" {
		m.TargetPlugin = targetOverride
	}

	if !dryRun {
		if err := os.RemoveAll(filepath.Join(m.TargetPlugin, "skills")); err != nil {
			return fmt.Errorf("cleaning target skills: %w", err)
		}
		if err := os.RemoveAll(m.Agents.TargetDir); err != nil {
			return fmt.Errorf("cleaning target agents: %w", err)
		}
	}

	if err := GenerateSkills(m, dryRun); err != nil {
		return fmt.Errorf("generating skills: %w", err)
	}

	if err := GenerateShared(m, dryRun); err != nil {
		return fmt.Errorf("generating shared: %w", err)
	}

	if err := GenerateAgents(m, dryRun); err != nil {
		return fmt.Errorf("generating agents: %w", err)
	}

	if err := GeneratePluginManifest(m, dryRun); err != nil {
		return fmt.Errorf("generating plugin manifest: %w", err)
	}

	if err := GenerateMCPConfig(m, dryRun); err != nil {
		return fmt.Errorf("generating MCP config: %w", err)
	}

	return nil
}
