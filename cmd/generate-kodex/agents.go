package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

type AgentFrontmatter struct {
	Name        string `yaml:"name"`
	Description string `yaml:"description"`
}

func GenerateAgents(m *Manifest, dryRun bool) error {
	sourceAgents := filepath.Join(m.SourcePlugin, "agents")
	targetDir := m.Agents.TargetDir

	entries, err := os.ReadDir(sourceAgents)
	if err != nil {
		return fmt.Errorf("reading agents directory: %w", err)
	}

	if dryRun {
		for _, entry := range entries {
			if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".md") {
				continue
			}
			name := strings.TrimSuffix(entry.Name(), ".md")
			fmt.Printf("[dry-run] generate agent %s → %s/%s.toml\n", entry.Name(), targetDir, name)
		}
		return nil
	}

	if err := os.MkdirAll(targetDir, 0o755); err != nil {
		return fmt.Errorf("creating agents directory: %w", err)
	}

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".md") {
			continue
		}

		src := filepath.Join(sourceAgents, entry.Name())
		name := strings.TrimSuffix(entry.Name(), ".md")
		dst := filepath.Join(targetDir, name+".toml")

		if err := generateAgent(src, dst, m.Agents); err != nil {
			return fmt.Errorf("generating agent %s: %w", name, err)
		}
		fmt.Printf("generated agent %s\n", name)
	}

	return nil
}

func generateAgent(src, dst string, cfg AgentsConfig) error {
	content, err := os.ReadFile(src)
	if err != nil {
		return fmt.Errorf("reading %s: %w", src, err)
	}

	fm, body, err := parseFrontmatter(content)
	if err != nil {
		return fmt.Errorf("parsing frontmatter: %w", err)
	}

	body, err = ApplyTransforms(body, cfg.Transforms)
	if err != nil {
		return fmt.Errorf("transforming agent body: %w", err)
	}

	toml := formatAgentTOML(fm, string(body), cfg)

	return os.WriteFile(dst, []byte(toml), 0o644)
}

func parseFrontmatter(content []byte) (AgentFrontmatter, []byte, error) {
	s := string(content)

	if !strings.HasPrefix(s, "---\n") {
		return AgentFrontmatter{}, content, fmt.Errorf("no frontmatter found")
	}

	end := strings.Index(s[4:], "\n---\n")
	if end < 0 {
		// Try trailing --- at end of file
		end = strings.Index(s[4:], "\n---")
		if end < 0 || (4+end+4 < len(s) && s[4+end+4] != '\n') {
			return AgentFrontmatter{}, content, fmt.Errorf("unterminated frontmatter")
		}
	}

	fmRaw := s[4 : 4+end]
	body := strings.TrimLeft(s[4+end+4:], "\n")

	var fm AgentFrontmatter
	if err := yaml.Unmarshal([]byte(fmRaw), &fm); err != nil {
		return AgentFrontmatter{}, nil, fmt.Errorf("parsing frontmatter YAML: %w", err)
	}

	if fm.Name == "" {
		return AgentFrontmatter{}, nil, fmt.Errorf("frontmatter missing name")
	}

	return fm, []byte(body), nil
}

func formatAgentTOML(fm AgentFrontmatter, body string, cfg AgentsConfig) string {
	var b strings.Builder

	fmt.Fprintf(&b, "name = %q\n", fm.Name)

	desc := strings.TrimSpace(fm.Description)
	if strings.Contains(desc, "\n") {
		fmt.Fprintf(&b, "description = \"\"\"\n%s\n\"\"\"\n", escapeTomlMultiline(desc))
	} else {
		fmt.Fprintf(&b, "description = %q\n", desc)
	}

	fmt.Fprintf(&b, "sandbox_mode = %q\n", cfg.SandboxMode)
	fmt.Fprintf(&b, "model = %q\n", cfg.Model)
	fmt.Fprintf(&b, "model_reasoning_effort = %q\n", cfg.ModelReasoningEffort)

	body = strings.TrimRight(body, "\n")
	fmt.Fprintf(&b, "developer_instructions = \"\"\"\n%s\n\"\"\"\n", escapeTomlMultiline(body))

	return b.String()
}

func escapeTomlMultiline(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, `"""`, `""\"`)
	return s
}
