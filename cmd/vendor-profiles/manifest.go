package main

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Manifest []Upstream

type Upstream struct {
	Repo        string `yaml:"repo"`
	Ref         string `yaml:"ref"`
	KeepDefault string `yaml:"keep_default,omitempty"`
	Files       []File `yaml:"files"`
}

type File struct {
	Source        string `yaml:"source"`
	Phase         string `yaml:"phase"`
	As            string `yaml:"as"`
	Keep          any    `yaml:"keep,omitempty"`
	Condition     string `yaml:"condition,omitempty"`
	EffectiveKeep any    // resolved at runtime, not from YAML
}

type KeepHeadings struct {
	Headings []string `yaml:"headings"`
}

var knownPhases = map[string]bool{
	"review-code": true,
	"implement":   true,
	"design":      true,
	"test":        true,
	"document":    true,
	"review-spec": true,
}

func ParseManifest(path string) (Manifest, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading manifest: %w", err)
	}

	var manifest Manifest
	if err := yaml.Unmarshal(data, &manifest); err != nil {
		return nil, fmt.Errorf("parsing YAML: %w", err)
	}

	for i, upstream := range manifest {
		if upstream.Repo == "" {
			return nil, fmt.Errorf("upstream[%d]: repo is required", i)
		}
		if upstream.Ref == "" {
			return nil, fmt.Errorf("upstream[%d]: ref is required", i)
		}
		if len(upstream.Files) == 0 {
			return nil, fmt.Errorf("upstream[%d] (%s): files is required", i, upstream.Repo)
		}
		for j, file := range upstream.Files {
			if file.Source == "" {
				return nil, fmt.Errorf("upstream[%d] (%s) file[%d]: source is required", i, upstream.Repo, j)
			}
			if file.Phase == "" {
				return nil, fmt.Errorf("upstream[%d] (%s) file[%d]: phase is required", i, upstream.Repo, j)
			}
			if !knownPhases[file.Phase] {
				return nil, fmt.Errorf("upstream[%d] (%s) file[%d]: unknown phase %q", i, upstream.Repo, j, file.Phase)
			}
			if file.As == "" {
				return nil, fmt.Errorf("upstream[%d] (%s) file[%d]: as is required", i, upstream.Repo, j)
			}
		}
	}

	return manifest, nil
}

func (f *File) ResolveKeep(upstreamDefault string) {
	if f.Keep != nil {
		f.EffectiveKeep = f.Keep
		return
	}
	if upstreamDefault != "" {
		f.EffectiveKeep = upstreamDefault
		return
	}
	f.EffectiveKeep = "all"
}
