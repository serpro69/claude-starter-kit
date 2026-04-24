package main

import (
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func writeManifest(t *testing.T, content string) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "manifest.yml")
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestParseManifest_ValidSingleUpstream(t *testing.T) {
	path := writeManifest(t, `
- repo: samber/cc-skills-golang
  ref: v1.1.3
  keep_default: from_first_h1
  files:
    - source: skills/golang-security/SKILL.md
      phase: review-code
      as: security.md
    - source: skills/golang-database/SKILL.md
      phase: review-code
      as: database.md
      condition: "Diff imports database/sql"
`)
	m, err := ParseManifest(path)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(m) != 1 {
		t.Fatalf("expected 1 upstream, got %d", len(m))
	}
	if m[0].Repo != "samber/cc-skills-golang" {
		t.Errorf("repo = %q, want %q", m[0].Repo, "samber/cc-skills-golang")
	}
	if m[0].Ref != "v1.1.3" {
		t.Errorf("ref = %q, want %q", m[0].Ref, "v1.1.3")
	}
	if m[0].KeepDefault != "from_first_h1" {
		t.Errorf("keep_default = %q, want %q", m[0].KeepDefault, "from_first_h1")
	}
	if len(m[0].Files) != 2 {
		t.Fatalf("expected 2 files, got %d", len(m[0].Files))
	}
	f0 := m[0].Files[0]
	if f0.Source != "skills/golang-security/SKILL.md" {
		t.Errorf("file[0].source = %q", f0.Source)
	}
	if f0.Phase != "review-code" {
		t.Errorf("file[0].phase = %q", f0.Phase)
	}
	if f0.As != "security.md" {
		t.Errorf("file[0].as = %q", f0.As)
	}
	if f0.Condition != "" {
		t.Errorf("file[0].condition = %q, want empty", f0.Condition)
	}
	f1 := m[0].Files[1]
	if f1.Condition != "Diff imports database/sql" {
		t.Errorf("file[1].condition = %q, want %q", f1.Condition, "Diff imports database/sql")
	}
}

func TestParseManifest_ValidMultiUpstream(t *testing.T) {
	path := writeManifest(t, `
- repo: samber/cc-skills-golang
  ref: v1.1.3
  files:
    - source: skills/golang-security/SKILL.md
      phase: review-code
      as: security.md
- repo: other/repo
  ref: main
  files:
    - source: skills/testing/SKILL.md
      phase: test
      as: testing.md
`)
	m, err := ParseManifest(path)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(m) != 2 {
		t.Fatalf("expected 2 upstreams, got %d", len(m))
	}
	if m[0].Repo != "samber/cc-skills-golang" {
		t.Errorf("upstream[0].repo = %q", m[0].Repo)
	}
	if m[1].Repo != "other/repo" {
		t.Errorf("upstream[1].repo = %q", m[1].Repo)
	}
}

func TestParseManifest_MissingRequiredFields(t *testing.T) {
	tests := []struct {
		name    string
		yaml    string
		wantErr string
	}{
		{
			name: "missing repo",
			yaml: `
- ref: v1.0.0
  files:
    - source: foo.md
      phase: test
      as: bar.md
`,
			wantErr: "repo is required",
		},
		{
			name: "missing ref",
			yaml: `
- repo: foo/bar
  files:
    - source: foo.md
      phase: test
      as: bar.md
`,
			wantErr: "ref is required",
		},
		{
			name: "missing files",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
`,
			wantErr: "files is required",
		},
		{
			name: "missing source",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - phase: test
      as: bar.md
`,
			wantErr: "source is required",
		},
		{
			name: "missing phase",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      as: bar.md
`,
			wantErr: "phase is required",
		},
		{
			name: "missing as",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: test
`,
			wantErr: "as is required",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			path := writeManifest(t, tt.yaml)
			_, err := ParseManifest(path)
			if err == nil {
				t.Fatal("expected error, got nil")
			}
			if !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("error = %q, want containing %q", err, tt.wantErr)
			}
		})
	}
}

func TestParseManifest_UnknownPhase(t *testing.T) {
	path := writeManifest(t, `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: unknown-phase
      as: bar.md
`)
	_, err := ParseManifest(path)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !strings.Contains(err.Error(), "unknown phase") {
		t.Errorf("error = %q, want containing %q", err, "unknown phase")
	}
}

func TestParseManifest_AsPathTraversal(t *testing.T) {
	cases := []struct {
		name string
		as   string
	}{
		{"slash", "sub/file.md"},
		{"backslash", "sub\\file.md"},
		{"parent traversal", "../evil.md"},
		{"deep traversal", "../../../evil.md"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			path := writeManifest(t, fmt.Sprintf(`
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: review-code
      as: %s
`, tc.as))
			_, err := ParseManifest(path)
			if err == nil {
				t.Fatal("expected error, got nil")
			}
			if !strings.Contains(err.Error(), "plain filename") {
				t.Errorf("error = %q, want containing %q", err, "plain filename")
			}
		})
	}
}

func TestParseManifest_AllValidPhases(t *testing.T) {
	for _, phase := range []string{"review-code", "implement", "design", "test", "document", "review-spec"} {
		t.Run(phase, func(t *testing.T) {
			path := writeManifest(t, fmt.Sprintf(`
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: %s
      as: bar.md
`, phase))
			_, err := ParseManifest(path)
			if err != nil {
				t.Fatalf("phase %q should be valid, got: %v", phase, err)
			}
		})
	}
}

func TestParseManifest_KeepValidation(t *testing.T) {
	tests := []struct {
		name    string
		yaml    string
		wantErr string
	}{
		{
			name: "invalid keep_default",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  keep_default: invalid
  files:
    - source: foo.md
      phase: test
      as: bar.md
`,
			wantErr: "invalid keep_default",
		},
		{
			name: "invalid keep string",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: test
      as: bar.md
      keep: invalid
`,
			wantErr: "invalid keep mode",
		},
		{
			name: "keep headings missing key",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: test
      as: bar.md
      keep:
        not_headings:
          - "## Foo"
`,
			wantErr: "missing 'headings' key",
		},
		{
			name: "keep object unexpected extra keys",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: test
      as: bar.md
      keep:
        headings:
          - "## Foo"
        extra_key: bar
`,
			wantErr: "unexpected keys",
		},
		{
			name: "empty headings list",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: test
      as: bar.md
      keep:
        headings: []
`,
			wantErr: "headings list must not be empty",
		},
		{
			name: "valid keep headings",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: test
      as: bar.md
      keep:
        headings:
          - "## Section A"
          - "## Section B"
`,
		},
		{
			name: "valid keep all",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: test
      as: bar.md
      keep: all
`,
		},
		{
			name: "valid keep from_first_h1",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: test
      as: bar.md
      keep: from_first_h1
`,
		},
		{
			name: "valid keep_default all",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  keep_default: all
  files:
    - source: foo.md
      phase: test
      as: bar.md
`,
		},
		{
			name: "valid keep_default from_first_h1",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  keep_default: from_first_h1
  files:
    - source: foo.md
      phase: test
      as: bar.md
`,
		},
		{
			name: "no keep or keep_default is valid",
			yaml: `
- repo: foo/bar
  ref: v1.0.0
  files:
    - source: foo.md
      phase: test
      as: bar.md
`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			path := writeManifest(t, tt.yaml)
			_, err := ParseManifest(path)
			if tt.wantErr == "" {
				if err != nil {
					t.Fatalf("unexpected error: %v", err)
				}
				return
			}
			if err == nil {
				t.Fatal("expected error, got nil")
			}
			if !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("error = %q, want containing %q", err, tt.wantErr)
			}
		})
	}
}

func TestResolveKeep_FileOverridesUpstream(t *testing.T) {
	f := &File{Keep: "all"}
	f.ResolveKeep("from_first_h1")
	if f.EffectiveKeep != "all" {
		t.Errorf("EffectiveKeep = %v, want %q", f.EffectiveKeep, "all")
	}
}

func TestResolveKeep_UpstreamDefault(t *testing.T) {
	f := &File{}
	f.ResolveKeep("from_first_h1")
	if f.EffectiveKeep != "from_first_h1" {
		t.Errorf("EffectiveKeep = %v, want %q", f.EffectiveKeep, "from_first_h1")
	}
}

func TestResolveKeep_FallbackToAll(t *testing.T) {
	f := &File{}
	f.ResolveKeep("")
	if f.EffectiveKeep != "all" {
		t.Errorf("EffectiveKeep = %v, want %q", f.EffectiveKeep, "all")
	}
}

func TestResolveKeep_HeadingsKeep(t *testing.T) {
	headings := map[string]any{"headings": []any{"## Foo", "## Bar"}}
	f := &File{Keep: headings}
	f.ResolveKeep("from_first_h1")
	if !reflect.DeepEqual(f.EffectiveKeep, headings) {
		t.Errorf("EffectiveKeep = %v, want %v", f.EffectiveKeep, headings)
	}
}

func TestParseManifest_InvalidYAML(t *testing.T) {
	path := writeManifest(t, `[[[invalid yaml`)
	_, err := ParseManifest(path)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !strings.Contains(err.Error(), "parsing YAML") {
		t.Errorf("error = %q, want containing %q", err, "parsing YAML")
	}
}

func TestParseManifest_FileNotFound(t *testing.T) {
	_, err := ParseManifest("/nonexistent/path/manifest.yml")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !strings.Contains(err.Error(), "reading manifest") {
		t.Errorf("error = %q, want containing %q", err, "reading manifest")
	}
}
