package main

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

const (
	keepAll         = "all"
	keepFromFirstH1 = "from_first_h1"
)

type Manifest []*Upstream

type Upstream struct {
	Repo        string  `yaml:"repo"`
	Ref         string  `yaml:"ref"`
	KeepDefault string  `yaml:"keep_default,omitempty"` // string-only by design: "all" or "from_first_h1"; headings is per-file
	Files       []*File `yaml:"files"`
}

type File struct {
	Source        string `yaml:"source"`
	Phase         string `yaml:"phase"`
	As            string `yaml:"as"`
	Keep          any    `yaml:"keep,omitempty"`
	Condition     string `yaml:"condition,omitempty"`
	EffectiveKeep any    // resolved at runtime, not from YAML
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
		if upstream.KeepDefault != "" && upstream.KeepDefault != keepAll && upstream.KeepDefault != keepFromFirstH1 {
			return nil, fmt.Errorf("upstream[%d] (%s): invalid keep_default %q (must be %q or %q)", i, upstream.Repo, upstream.KeepDefault, keepAll, keepFromFirstH1)
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
			if err := validateKeep(file.Keep); err != nil {
				return nil, fmt.Errorf("upstream[%d] (%s) file[%d]: %w", i, upstream.Repo, j, err)
			}
		}
	}

	return manifest, nil
}

func validateKeep(keep any) error {
	if keep == nil {
		return nil
	}
	switch v := keep.(type) {
	case string:
		if v != keepAll && v != keepFromFirstH1 {
			return fmt.Errorf("invalid keep mode %q (must be %q or %q)", v, keepAll, keepFromFirstH1)
		}
	case map[string]any:
		headings, ok := v["headings"]
		if !ok {
			return fmt.Errorf("keep object missing 'headings' key")
		}
		if len(v) > 1 {
			return fmt.Errorf("keep object has unexpected keys (only 'headings' is allowed)")
		}
		list, ok := headings.([]any)
		if !ok {
			return fmt.Errorf("headings must be a list of strings")
		}
		if len(list) == 0 {
			return fmt.Errorf("headings list must not be empty")
		}
		for i, h := range list {
			if _, ok := h.(string); !ok {
				return fmt.Errorf("headings[%d] must be a string, got %T", i, h)
			}
		}
	default:
		return fmt.Errorf("unsupported keep type: %T", keep)
	}
	return nil
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
	f.EffectiveKeep = keepAll
}
