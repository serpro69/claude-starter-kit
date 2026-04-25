package main

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Manifest struct {
	SourcePlugin string          `yaml:"source_plugin"`
	TargetPlugin string          `yaml:"target_plugin"`
	Skills       SkillsConfig    `yaml:"skills"`
	Agents       AgentsConfig    `yaml:"agents"`
	Manifest     ManifestConfig  `yaml:"manifest"`
	MCP          MCPConfig       `yaml:"mcp"`
}

type SkillsConfig struct {
	IncludeAll bool              `yaml:"include_all"`
	Overrides  []SkillOverride   `yaml:"overrides"`
	Transforms []TransformConfig `yaml:"transforms"`
	Shared     SharedConfig      `yaml:"shared"`
}

type SkillOverride struct {
	Name    string `yaml:"name"`
	Exclude bool   `yaml:"exclude"`
}

type TransformConfig struct {
	Type            string `yaml:"type"`
	ReplacementBase string `yaml:"replacement_base"`
	Content         string `yaml:"content"`
}

type SharedConfig struct {
	Copy bool `yaml:"copy"`
}

type AgentsConfig struct {
	TargetDir            string            `yaml:"target_dir"`
	SandboxMode          string            `yaml:"sandbox_mode"`
	Model                string            `yaml:"model"`
	ModelReasoningEffort string            `yaml:"model_reasoning_effort"`
	Transforms           []TransformConfig `yaml:"transforms"`
}

type ManifestConfig struct {
	Name        string            `yaml:"name"`
	VersionFrom string            `yaml:"version_from"`
	ExtraFields map[string]string `yaml:"extra_fields"`
}

type MCPConfig struct {
	Servers map[string]MCPServer `yaml:"servers"`
}

type MCPServer struct {
	Command string   `yaml:"command"`
	Args    []string `yaml:"args"`
}

func ParseManifest(path string) (*Manifest, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading manifest: %w", err)
	}

	var m Manifest
	if err := yaml.Unmarshal(data, &m); err != nil {
		return nil, fmt.Errorf("parsing YAML: %w", err)
	}

	if m.SourcePlugin == "" {
		return nil, fmt.Errorf("source_plugin is required")
	}
	if m.TargetPlugin == "" {
		return nil, fmt.Errorf("target_plugin is required")
	}
	if m.Agents.TargetDir == "" {
		return nil, fmt.Errorf("agents.target_dir is required")
	}
	if m.Manifest.Name == "" {
		return nil, fmt.Errorf("manifest.name is required")
	}
	if m.Manifest.VersionFrom == "" {
		return nil, fmt.Errorf("manifest.version_from is required")
	}

	return &m, nil
}
