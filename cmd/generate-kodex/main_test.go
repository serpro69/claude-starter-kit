package main

import (
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func setupTest(t *testing.T) (targetDir, agentsDir string, m *Manifest) {
	t.Helper()

	m, err := ParseManifest("testdata/manifest.yml")
	if err != nil {
		t.Fatalf("parsing manifest: %v", err)
	}

	targetDir = t.TempDir()
	agentsDir = filepath.Join(t.TempDir(), "agents")

	m.TargetPlugin = targetDir
	m.Agents.TargetDir = agentsDir

	return targetDir, agentsDir, m
}

func runFull(t *testing.T) (targetDir, agentsDir string) {
	t.Helper()
	targetDir, agentsDir, m := setupTest(t)

	if err := GenerateSkills(m, false); err != nil {
		t.Fatalf("GenerateSkills: %v", err)
	}
	if err := GenerateShared(m, false); err != nil {
		t.Fatalf("GenerateShared: %v", err)
	}
	if err := GenerateAgents(m, false); err != nil {
		t.Fatalf("GenerateAgents: %v", err)
	}
	if err := GeneratePluginManifest(m, false); err != nil {
		t.Fatalf("GeneratePluginManifest: %v", err)
	}
	if err := GenerateMCPConfig(m, false); err != nil {
		t.Fatalf("GenerateMCPConfig: %v", err)
	}

	return targetDir, agentsDir
}

func TestParseManifest(t *testing.T) {
	m, err := ParseManifest("testdata/manifest.yml")
	if err != nil {
		t.Fatalf("parsing: %v", err)
	}

	if m.SourcePlugin != "testdata/source-plugin" {
		t.Errorf("source_plugin = %q, want testdata/source-plugin", m.SourcePlugin)
	}
	if !m.Skills.IncludeAll {
		t.Error("skills.include_all should be true")
	}
	if len(m.Skills.Transforms) != 2 {
		t.Errorf("expected 2 transforms, got %d", len(m.Skills.Transforms))
	}
	if m.Manifest.Name != "kk" {
		t.Errorf("manifest.name = %q, want kk", m.Manifest.Name)
	}
}

func TestParseManifest_Missing(t *testing.T) {
	_, err := ParseManifest("testdata/nonexistent.yml")
	if err == nil {
		t.Fatal("expected error for nonexistent manifest")
	}
}

func TestParseManifest_InvalidYAML(t *testing.T) {
	tmp := t.TempDir()
	path := filepath.Join(tmp, "bad.yml")
	if err := os.WriteFile(path, []byte("{{invalid yaml"), 0o644); err != nil {
		t.Fatalf("writing test file: %v", err)
	}

	_, err := ParseManifest(path)
	if err == nil {
		t.Fatal("expected error for invalid YAML")
	}
}

func TestParseManifest_MissingRequired(t *testing.T) {
	tmp := t.TempDir()
	path := filepath.Join(tmp, "empty.yml")
	if err := os.WriteFile(path, []byte("target_plugin: x\n"), 0o644); err != nil {
		t.Fatalf("writing test file: %v", err)
	}

	_, err := ParseManifest(path)
	if err == nil {
		t.Fatal("expected error for missing source_plugin")
	}
}

func TestTransform_PluginRootResolve(t *testing.T) {
	input := []byte("path is ${CLAUDE_PLUGIN_ROOT}/profiles/go/")
	result := applyPluginRootResolve(input, "../klaude-plugin")
	want := "path is ../klaude-plugin/profiles/go/"
	if string(result) != want {
		t.Errorf("got %q, want %q", string(result), want)
	}
}

func TestTransform_InjectHeader_WithFrontmatter(t *testing.T) {
	input := []byte("---\nname: test\n---\n\n# Title\n")
	result := applyInjectHeader(input, "<!-- header -->\n")
	got := string(result)

	if !strings.Contains(got, "---\n<!-- header -->\n") {
		t.Errorf("header not injected after frontmatter:\n%s", got)
	}
	if !strings.Contains(got, "# Title") {
		t.Error("original content lost")
	}
}

func TestTransform_InjectHeader_WithoutFrontmatter(t *testing.T) {
	input := []byte("# Title\nContent\n")
	result := applyInjectHeader(input, "<!-- header -->\n")
	got := string(result)

	if !strings.HasPrefix(got, "<!-- header -->\n# Title") {
		t.Errorf("header not prepended:\n%s", got)
	}
}

func TestGenerateSkills(t *testing.T) {
	targetDir, _ := runFull(t)

	t.Run("SKILL.md exists", func(t *testing.T) {
		path := filepath.Join(targetDir, "skills", "test-skill", "SKILL.md")
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("SKILL.md not found: %v", err)
		}
	})

	t.Run("SKILL.md transformed", func(t *testing.T) {
		data, _ := os.ReadFile(filepath.Join(targetDir, "skills", "test-skill", "SKILL.md"))
		content := string(data)
		if strings.Contains(content, "${CLAUDE_PLUGIN_ROOT}") {
			t.Error("${CLAUDE_PLUGIN_ROOT} not resolved")
		}
		if !strings.Contains(content, "../source-plugin/profiles/go/") {
			t.Error("replacement path not found")
		}
		if !strings.Contains(content, "<!-- codex: generated -->") {
			t.Error("header not injected")
		}
	})

	t.Run("auxiliary files copied as-is", func(t *testing.T) {
		data, _ := os.ReadFile(filepath.Join(targetDir, "skills", "test-skill", "process.md"))
		if !strings.Contains(string(data), "auxiliary file") {
			t.Error("auxiliary file not copied")
		}
	})

	t.Run("symlinks resolved to copies", func(t *testing.T) {
		copied := filepath.Join(targetDir, "skills", "test-skill", "shared-foo.md")
		info, err := os.Lstat(copied)
		if err != nil {
			t.Fatalf("shared-foo.md not found: %v", err)
		}
		if info.Mode()&os.ModeSymlink != 0 {
			t.Errorf("shared-foo.md is still a symlink, expected a regular file")
		}
		content, err := os.ReadFile(copied)
		if err != nil {
			t.Fatalf("reading shared-foo.md: %v", err)
		}
		if len(content) == 0 {
			t.Errorf("shared-foo.md is empty, expected content from _shared/foo.md")
		}
	})

	t.Run("_shared/ copied", func(t *testing.T) {
		path := filepath.Join(targetDir, "skills", "_shared", "foo.md")
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("_shared/foo.md not found: %v", err)
		}
	})

	t.Run("_shared not as skill dir", func(t *testing.T) {
		path := filepath.Join(targetDir, "skills", "_shared", "SKILL.md")
		if _, err := os.Stat(path); err == nil {
			t.Error("_shared should not be treated as a skill directory")
		}
	})
}

func TestGenerateAgents(t *testing.T) {
	_, agentsDir := runFull(t)

	t.Run("TOML file exists", func(t *testing.T) {
		path := filepath.Join(agentsDir, "test-agent.toml")
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("test-agent.toml not found: %v", err)
		}
	})

	t.Run("TOML structure correct", func(t *testing.T) {
		data, _ := os.ReadFile(filepath.Join(agentsDir, "test-agent.toml"))
		content := string(data)

		checks := []struct {
			name    string
			want    string
			negated bool
		}{
			{"name field", `name = "test-agent"`, false},
			{"sandbox_mode", `sandbox_mode = "read-only"`, false},
			{"model", `model = "test-model"`, false},
			{"developer_instructions", `developer_instructions = """`, false},
			{"body content", "# Test Agent", false},
			{"no frontmatter", "---", true},
			{"no CLAUDE_PLUGIN_ROOT", "${CLAUDE_PLUGIN_ROOT}", true},
			{"resolved path", "../../source-plugin/profiles/go/review-code/", false},
		}

		for _, c := range checks {
			if c.negated {
				if strings.Contains(content, c.want) {
					t.Errorf("%s: should not contain %q", c.name, c.want)
				}
			} else {
				if !strings.Contains(content, c.want) {
					t.Errorf("%s: missing %q", c.name, c.want)
				}
			}
		}
	})
}

func TestGeneratePluginManifest(t *testing.T) {
	targetDir, _ := runFull(t)

	path := filepath.Join(targetDir, ".codex-plugin", "plugin.json")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("reading plugin.json: %v", err)
	}

	var manifest map[string]any
	if err := json.Unmarshal(data, &manifest); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}

	if manifest["name"] != "kk" {
		t.Errorf("name = %v, want kk", manifest["name"])
	}
	if manifest["version"] != "1.2.3" {
		t.Errorf("version = %v, want 1.2.3", manifest["version"])
	}
	if manifest["skills"] != "./skills/" {
		t.Errorf("skills = %v, want ./skills/", manifest["skills"])
	}
}

func TestGenerateMCPConfig(t *testing.T) {
	targetDir, _ := runFull(t)

	path := filepath.Join(targetDir, ".mcp.json")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("reading .mcp.json: %v", err)
	}

	var config map[string]any
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}

	servers, ok := config["mcpServers"].(map[string]any)
	if !ok {
		t.Fatal("mcpServers not found or wrong type")
	}
	capy, ok := servers["capy"].(map[string]any)
	if !ok {
		t.Fatal("capy server not found")
	}
	if capy["command"] != "bash" {
		t.Errorf("capy command = %v, want bash", capy["command"])
	}
}

func TestDryRun_NoFilesWritten(t *testing.T) {
	targetDir, agentsDir, m := setupTest(t)

	if err := GenerateSkills(m, true); err != nil {
		t.Fatalf("GenerateSkills dry-run: %v", err)
	}
	if err := GenerateShared(m, true); err != nil {
		t.Fatalf("GenerateShared dry-run: %v", err)
	}
	if err := GenerateAgents(m, true); err != nil {
		t.Fatalf("GenerateAgents dry-run: %v", err)
	}
	if err := GeneratePluginManifest(m, true); err != nil {
		t.Fatalf("GeneratePluginManifest dry-run: %v", err)
	}
	if err := GenerateMCPConfig(m, true); err != nil {
		t.Fatalf("GenerateMCPConfig dry-run: %v", err)
	}

	for _, dir := range []string{targetDir, agentsDir} {
		entries, _ := os.ReadDir(dir)
		if len(entries) != 0 {
			t.Errorf("dry-run created files in %s", dir)
		}
	}
}

func TestIdempotent(t *testing.T) {
	_, _, m := setupTest(t)
	targetDir := t.TempDir()
	agentsDir := filepath.Join(t.TempDir(), "agents")
	m.TargetPlugin = targetDir
	m.Agents.TargetDir = agentsDir

	generate := func() {
		t.Helper()
		if err := GenerateSkills(m, false); err != nil {
			t.Fatalf("GenerateSkills: %v", err)
		}
		if err := GenerateShared(m, false); err != nil {
			t.Fatalf("GenerateShared: %v", err)
		}
		if err := GenerateAgents(m, false); err != nil {
			t.Fatalf("GenerateAgents: %v", err)
		}
		if err := GeneratePluginManifest(m, false); err != nil {
			t.Fatalf("GeneratePluginManifest: %v", err)
		}
		if err := GenerateMCPConfig(m, false); err != nil {
			t.Fatalf("GenerateMCPConfig: %v", err)
		}
	}

	generate()
	first := snapshotDir(t, targetDir)
	firstAgents := snapshotDir(t, agentsDir)

	generate()
	second := snapshotDir(t, targetDir)
	secondAgents := snapshotDir(t, agentsDir)

	compareMaps(t, "target", first, second)
	compareMaps(t, "agents", firstAgents, secondAgents)
}

func TestParseFrontmatter(t *testing.T) {
	t.Run("valid", func(t *testing.T) {
		input := []byte("---\nname: test\ndescription: desc\n---\n\n# Body\n")
		fm, body, err := parseFrontmatter(input)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if fm.Name != "test" {
			t.Errorf("name = %q, want test", fm.Name)
		}
		if !strings.Contains(string(body), "# Body") {
			t.Error("body missing")
		}
	})

	t.Run("no frontmatter", func(t *testing.T) {
		input := []byte("# Just content\n")
		_, _, err := parseFrontmatter(input)
		if err == nil {
			t.Error("expected error for missing frontmatter")
		}
	})

	t.Run("missing name", func(t *testing.T) {
		input := []byte("---\ndescription: desc\n---\n\n# Body\n")
		_, _, err := parseFrontmatter(input)
		if err == nil {
			t.Error("expected error for missing name")
		}
	})

	t.Run("trailing --- at eof", func(t *testing.T) {
		input := []byte("---\nname: x\n---")
		fm, _, err := parseFrontmatter(input)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if fm.Name != "x" {
			t.Errorf("name = %q, want x", fm.Name)
		}
	})
}

func TestEscapeTomlMultiline(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{`no escapes`, `no escapes`},
		{`back\slash`, `back\\slash`},
		{`triple """quotes"""`, `triple ""\"quotes""\"`},
	}
	for _, tt := range tests {
		got := escapeTomlMultiline(tt.input)
		if got != tt.want {
			t.Errorf("escapeTomlMultiline(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func snapshotDir(t *testing.T, root string) map[string]string {
	t.Helper()
	files := make(map[string]string)
	filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Type()&os.ModeSymlink != 0 {
			target, err := os.Readlink(path)
			if err != nil {
				return err
			}
			rel, _ := filepath.Rel(root, path)
			files[rel] = "symlink:" + target
			return nil
		}
		if d.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(root, path)
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		files[rel] = string(data)
		return nil
	})
	return files
}

func compareMaps(t *testing.T, label string, first, second map[string]string) {
	t.Helper()
	if len(first) != len(second) {
		t.Errorf("%s: file count changed: %d → %d", label, len(first), len(second))
		return
	}
	for path, fc := range first {
		sc, ok := second[path]
		if !ok {
			t.Errorf("%s: file %s missing after second run", label, path)
			continue
		}
		if fc != sc {
			t.Errorf("%s: file %s changed between runs", label, path)
		}
	}
}
