package main

import (
	"os"
	"path/filepath"
	"testing"
)

func setupClassifyFixture(t *testing.T) string {
	t.Helper()
	root := t.TempDir()

	dirs := []string{
		"skills/review-code",
		"skills/_shared",
		"agents",
		"profiles/go/review-code",
		"profiles/go/design",
		"profiles/empty",
		"commands/chain-of-verification",
	}
	for _, d := range dirs {
		if err := os.MkdirAll(filepath.Join(root, d), 0o755); err != nil {
			t.Fatal(err)
		}
	}

	markers := []string{
		"skills/review-code/SKILL.md",
		"profiles/go/DETECTION.md",
		"profiles/go/review-code/index.md",
		"profiles/go/design/index.md",
	}
	for _, m := range markers {
		if err := os.WriteFile(filepath.Join(root, m), nil, 0o644); err != nil {
			t.Fatal(err)
		}
	}

	return root
}

func TestGraphClassifyPath(t *testing.T) {
	root := setupClassifyFixture(t)

	tests := []struct {
		name string
		path string
		want NodeType
	}{
		{"skill directory", "skills/review-code", NodeSkill},
		{"shared file", "skills/_shared/profile-detection.md", NodeShared},
		{"agent file", "agents/code-reviewer.md", NodeAgent},
		{"profile directory", "profiles/go", NodeProfile},
		{"profile-phase review-code", "profiles/go/review-code", NodeProfilePhase},
		{"profile-phase design", "profiles/go/design", NodeProfilePhase},
		{"command directory", "commands/chain-of-verification", NodeCommand},

		// Content: files inside artifact dirs, unknown dirs, etc.
		{"content in skill dir", "skills/review-code/review-process.md", NodeContent},
		{"content outside known dirs", "some/random/file.md", NodeContent},
		{"profile overview file", "profiles/go/overview.md", NodeContent},
		{"root-level file", "README.md", NodeContent},

		// Edge cases: missing marker files
		{"skill without SKILL.md", "skills/nonexistent", NodeContent},
		{"profile without DETECTION.md", "profiles/empty", NodeContent},
		{"profile-phase without index.md", "profiles/empty/review-code", NodeContent},

		// Unknown phase name under profiles
		{"unknown phase", "profiles/go/unknown-phase", NodeContent},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ClassifyPath(tt.path, root)
			if got != tt.want {
				t.Errorf("ClassifyPath(%q) = %q, want %q", tt.path, got, tt.want)
			}
		})
	}
}

func TestGraphNormalizePath(t *testing.T) {
	g := NewGraph()
	g.AddNode(&Node{Path: "skills/review-code/", Type: NodeSkill})
	g.AddNode(&Node{Path: "profiles/go/", Type: NodeProfile})
	g.AddNode(&Node{Path: "profiles/go/review-code/", Type: NodeProfilePhase})
	g.AddNode(&Node{Path: "commands/cove/", Type: NodeCommand})
	g.AddNode(&Node{Path: "skills/_shared/profile-detection.md", Type: NodeShared})

	tests := []struct {
		name string
		path string
		want string
	}{
		{"file inside skill → skill node", "skills/review-code/SKILL.md", "skills/review-code/"},
		{"nested file inside skill", "skills/review-code/evals/test/eval.json", "skills/review-code/"},
		{"file in profile-phase → profile-phase (nearest)", "profiles/go/review-code/index.md", "profiles/go/review-code/"},
		{"file in profile root → profile", "profiles/go/overview.md", "profiles/go/"},
		{"file in command dir → command", "commands/cove/default.md", "commands/cove/"},

		// Directory-form artifact paths resolve to themselves, not a parent artifact
		{"skill dir resolves to itself", "skills/review-code/", "skills/review-code/"},
		{"profile-phase dir resolves to itself (not parent profile)", "profiles/go/review-code/", "profiles/go/review-code/"},
		{"profile dir resolves to itself", "profiles/go/", "profiles/go/"},

		// File-level nodes stay as-is (no artifact ancestor)
		{"shared file stays as file", "skills/_shared/profile-detection.md", "skills/_shared/profile-detection.md"},
		{"agent file stays as file", "agents/code-reviewer.md", "agents/code-reviewer.md"},
		{"unknown path stays as-is", "some/other/file.md", "some/other/file.md"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := g.NormalizePath(tt.path)
			if got != tt.want {
				t.Errorf("NormalizePath(%q) = %q, want %q", tt.path, got, tt.want)
			}
		})
	}
}

func TestGraphMetricEdges(t *testing.T) {
	g := NewGraph()
	g.AddNode(&Node{Path: "skills/review-code/", Type: NodeSkill})
	g.AddNode(&Node{Path: "skills/_shared/detection.md", Type: NodeShared})

	// Intra-artifact edge: both files inside the same skill → normalized Source == Target
	g.AddEdge(Edge{
		RawSource: "skills/review-code/SKILL.md",
		RawTarget: "skills/review-code/process.md",
		Type:      EdgeMarkdownLink,
		Line:      10,
	})

	// Cross-artifact edge: skill → shared file
	g.AddEdge(Edge{
		RawSource: "skills/review-code/SKILL.md",
		RawTarget: "skills/_shared/detection.md",
		Type:      EdgeMarkdownLink,
		Line:      20,
	})

	all := g.Edges
	if len(all) != 2 {
		t.Fatalf("expected 2 total edges, got %d", len(all))
	}

	// Verify normalization happened
	if all[0].Source != "skills/review-code/" || all[0].Target != "skills/review-code/" {
		t.Errorf("intra-artifact edge not normalized: source=%q target=%q", all[0].Source, all[0].Target)
	}

	metric := g.MetricEdges()
	if len(metric) != 1 {
		t.Fatalf("expected 1 metric edge (intra-artifact suppressed), got %d", len(metric))
	}
	if metric[0].Target != "skills/_shared/detection.md" {
		t.Errorf("wrong metric edge target: %q", metric[0].Target)
	}
}

func TestGraphReachable(t *testing.T) {
	// Build a small graph:
	//   A → B → C
	//   A → D
	//   E (isolated)
	g := NewGraph()
	for _, name := range []string{"A", "B", "C", "D", "E"} {
		g.AddNode(&Node{Path: name, Type: NodeShared})
	}
	g.Edges = []Edge{
		{Source: "A", Target: "B", Type: EdgeMarkdownLink},
		{Source: "B", Target: "C", Type: EdgeMarkdownLink},
		{Source: "A", Target: "D", Type: EdgeMarkdownLink},
	}

	t.Run("forward from A", func(t *testing.T) {
		got := g.Reachable("A", Forward)
		want := map[string]bool{"A": true, "B": true, "C": true, "D": true}
		assertSetEqual(t, got, want)
	})

	t.Run("forward from B", func(t *testing.T) {
		got := g.Reachable("B", Forward)
		want := map[string]bool{"B": true, "C": true}
		assertSetEqual(t, got, want)
	})

	t.Run("reverse from C", func(t *testing.T) {
		got := g.Reachable("C", Reverse)
		want := map[string]bool{"C": true, "B": true, "A": true}
		assertSetEqual(t, got, want)
	})

	t.Run("both from B", func(t *testing.T) {
		got := g.Reachable("B", Both)
		want := map[string]bool{"A": true, "B": true, "C": true, "D": true}
		assertSetEqual(t, got, want)
	})

	t.Run("isolated node", func(t *testing.T) {
		got := g.Reachable("E", Forward)
		want := map[string]bool{"E": true}
		assertSetEqual(t, got, want)
	})
}

func TestGraphOutEdgesInEdges(t *testing.T) {
	g := NewGraph()
	g.AddNode(&Node{Path: "A", Type: NodeShared})
	g.AddNode(&Node{Path: "B", Type: NodeShared})
	g.AddNode(&Node{Path: "C", Type: NodeShared})
	g.Edges = []Edge{
		{Source: "A", Target: "B", Type: EdgeMarkdownLink},
		{Source: "A", Target: "C", Type: EdgeSymlink},
		{Source: "B", Target: "C", Type: EdgeTemplateRef},
	}

	out := g.OutEdges("A")
	if len(out) != 2 {
		t.Errorf("OutEdges(A): want 2, got %d", len(out))
	}

	in := g.InEdges("C")
	if len(in) != 2 {
		t.Errorf("InEdges(C): want 2, got %d", len(in))
	}

	none := g.OutEdges("C")
	if len(none) != 0 {
		t.Errorf("OutEdges(C): want 0, got %d", len(none))
	}
}

func assertSetEqual(t *testing.T, got, want map[string]bool) {
	t.Helper()
	if len(got) != len(want) {
		t.Errorf("set size: got %d, want %d\ngot:  %v\nwant: %v", len(got), len(want), keys(got), keys(want))
		return
	}
	for k := range want {
		if !got[k] {
			t.Errorf("missing key %q in result\ngot:  %v\nwant: %v", k, keys(got), keys(want))
		}
	}
}

func keys(m map[string]bool) []string {
	var result []string
	for k := range m {
		result = append(result, k)
	}
	return result
}
