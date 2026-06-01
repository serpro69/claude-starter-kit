package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestMetricsLinearChain(t *testing.T) {
	g := NewGraph()
	for _, name := range []string{"A", "B", "C", "D"} {
		g.AddNode(&Node{Path: name, Type: NodeShared})
	}
	g.Edges = []Edge{
		{Source: "A", Target: "B", RawSource: "A", RawTarget: "B", Type: EdgeMarkdownLink},
		{Source: "B", Target: "C", RawSource: "B", RawTarget: "C", Type: EdgeMarkdownLink},
		{Source: "C", Target: "D", RawSource: "C", RawTarget: "D", Type: EdgeMarkdownLink},
	}

	root := setupMetricsDiskFixture(t, "A", "B", "C", "D")
	m, diags := ComputeMetrics(g, root, 3)

	if len(diags) != 0 {
		t.Errorf("unexpected diagnostics: %v", diags)
	}

	wantDepth := map[string]int{"A": 3, "B": 2, "C": 1, "D": 0}
	for node, want := range wantDepth {
		if got := m.PerNode[node].Depth; got != want {
			t.Errorf("depth(%s) = %d, want %d", node, got, want)
		}
	}

	wantTC := map[string]int{"A": 3, "B": 2, "C": 1, "D": 0}
	for node, want := range wantTC {
		if got := m.PerNode[node].TransitiveClosureSize; got != want {
			t.Errorf("transitive(%s) = %d, want %d", node, got, want)
		}
	}

	if m.PerNode["A"].FanOut != 1 {
		t.Errorf("fan-out(A) = %d, want 1", m.PerNode["A"].FanOut)
	}
	if m.PerNode["D"].FanOut != 0 {
		t.Errorf("fan-out(D) = %d, want 0", m.PerNode["D"].FanOut)
	}
	if m.PerNode["D"].FanIn != 1 {
		t.Errorf("fan-in(D) = %d, want 1", m.PerNode["D"].FanIn)
	}
}

func TestMetricsDiamond(t *testing.T) {
	g := NewGraph()
	for _, name := range []string{"A", "B", "C", "D"} {
		g.AddNode(&Node{Path: name, Type: NodeShared})
	}
	g.Edges = []Edge{
		{Source: "A", Target: "B", RawSource: "A", RawTarget: "B", Type: EdgeMarkdownLink},
		{Source: "A", Target: "C", RawSource: "A", RawTarget: "C", Type: EdgeMarkdownLink},
		{Source: "B", Target: "D", RawSource: "B", RawTarget: "D", Type: EdgeMarkdownLink},
		{Source: "C", Target: "D", RawSource: "C", RawTarget: "D", Type: EdgeMarkdownLink},
	}

	root := setupMetricsDiskFixture(t, "A", "B", "C", "D")
	m, _ := ComputeMetrics(g, root, 3)

	if m.PerNode["D"].FanIn != 2 {
		t.Errorf("fan-in(D) = %d, want 2", m.PerNode["D"].FanIn)
	}
	if m.PerNode["A"].FanOut != 2 {
		t.Errorf("fan-out(A) = %d, want 2", m.PerNode["A"].FanOut)
	}
	if m.PerNode["A"].Depth != 2 {
		t.Errorf("depth(A) = %d, want 2", m.PerNode["A"].Depth)
	}
	if m.PerNode["A"].TransitiveClosureSize != 3 {
		t.Errorf("transitive(A) = %d, want 3", m.PerNode["A"].TransitiveClosureSize)
	}
}

func TestMetricsStar(t *testing.T) {
	g := NewGraph()
	for _, name := range []string{"A", "B", "C", "D", "E"} {
		g.AddNode(&Node{Path: name, Type: NodeShared})
	}
	g.Edges = []Edge{
		{Source: "A", Target: "B", RawSource: "A", RawTarget: "B", Type: EdgeMarkdownLink},
		{Source: "A", Target: "C", RawSource: "A", RawTarget: "C", Type: EdgeMarkdownLink},
		{Source: "A", Target: "D", RawSource: "A", RawTarget: "D", Type: EdgeMarkdownLink},
		{Source: "A", Target: "E", RawSource: "A", RawTarget: "E", Type: EdgeMarkdownLink},
	}

	root := setupMetricsDiskFixture(t, "A", "B", "C", "D", "E")
	m, _ := ComputeMetrics(g, root, 3)

	if m.PerNode["A"].FanOut != 4 {
		t.Errorf("fan-out(A) = %d, want 4", m.PerNode["A"].FanOut)
	}
	if m.PerNode["A"].Depth != 1 {
		t.Errorf("depth(A) = %d, want 1", m.PerNode["A"].Depth)
	}
	if m.PerNode["A"].TransitiveClosureSize != 4 {
		t.Errorf("transitive(A) = %d, want 4", m.PerNode["A"].TransitiveClosureSize)
	}
}

func TestMetricsOrphan(t *testing.T) {
	g := NewGraph()
	g.AddNode(&Node{Path: "skills/a/", Type: NodeSkill})
	g.AddNode(&Node{Path: "agents/reviewer.md", Type: NodeAgent})
	g.AddNode(&Node{Path: "profiles/go/", Type: NodeProfile})
	g.AddNode(&Node{Path: "commands/cove/", Type: NodeCommand})
	g.AddNode(&Node{Path: "connected.md", Type: NodeContent})
	g.AddNode(&Node{Path: "orphan.md", Type: NodeContent})
	g.AddNode(&Node{Path: "shared-orphan.md", Type: NodeShared})
	g.AddNode(&Node{Path: "README.md", Type: NodeContent})
	g.AddNode(&Node{Path: "skills/a/evals/fixture.md", Type: NodeContent})
	g.Edges = []Edge{
		{Source: "skills/a/", Target: "connected.md", RawSource: "skills/a/SKILL.md", RawTarget: "connected.md", Type: EdgeMarkdownLink},
	}

	root := setupMetricsDiskFixture(t, "connected.md", "orphan.md", "shared-orphan.md", "README.md")
	m, _ := ComputeMetrics(g, root, 3)

	want := []string{"orphan.md", "shared-orphan.md"}
	if len(m.Orphans) != len(want) {
		t.Fatalf("orphans = %v, want %v", m.Orphans, want)
	}
	for i, w := range want {
		if m.Orphans[i] != w {
			t.Errorf("orphans[%d] = %q, want %q", i, m.Orphans[i], w)
		}
	}

	for _, ep := range []string{"skills/a/", "agents/reviewer.md", "profiles/go/", "commands/cove/"} {
		for _, o := range m.Orphans {
			if o == ep {
				t.Errorf("entry-point %q should not be an orphan", ep)
			}
		}
	}
}

func TestMetricsBrokenEdge(t *testing.T) {
	g := NewGraph()
	g.AddNode(&Node{Path: "source.md", Type: NodeContent})
	g.AddNode(&Node{Path: "exists.md", Type: NodeContent})
	g.Edges = []Edge{
		{Source: "source.md", Target: "exists.md", RawSource: "source.md", RawTarget: "exists.md", Type: EdgeMarkdownLink},
		{Source: "source.md", Target: "missing.md", RawSource: "source.md", RawTarget: "missing.md", Type: EdgeMarkdownLink},
	}

	root := setupMetricsDiskFixture(t, "source.md", "exists.md")

	m, _ := ComputeMetrics(g, root, 3)

	if len(m.BrokenEdges) != 1 {
		t.Fatalf("broken edges = %d, want 1", len(m.BrokenEdges))
	}
	if m.BrokenEdges[0].RawTarget != "missing.md" {
		t.Errorf("broken edge target = %q, want %q", m.BrokenEdges[0].RawTarget, "missing.md")
	}
}

func TestMetricsBrokenEdgeSkipsNonOperative(t *testing.T) {
	// Edges from non-operative content (eval fixtures and example-*.md artifacts)
	// legitimately dangle and must not be flagged as broken, while an edge from a
	// live instruction file to the same missing target must still be flagged.
	g := NewGraph()
	g.AddNode(&Node{Path: "skills/foo/", Type: NodeSkill})
	g.AddNode(&Node{Path: "skills/foo/example-tasks.md", Type: NodeContent})
	g.AddNode(&Node{Path: "skills/foo/evals/case/test-files/tasks.md", Type: NodeContent})
	g.Edges = []Edge{
		// Live instruction file → missing target: still broken.
		{Source: "skills/foo/", Target: "skills/foo/", RawSource: "skills/foo/SKILL.md", RawTarget: "skills/foo/missing.md", Type: EdgeMarkdownLink},
		// Example artifact → missing target: exempt.
		{Source: "skills/foo/", Target: "skills/foo/", RawSource: "skills/foo/example-tasks.md", RawTarget: "skills/foo/design.md", Type: EdgeMarkdownLink},
		// Eval fixture → missing target: exempt.
		{Source: "skills/foo/", Target: "skills/foo/", RawSource: "skills/foo/evals/case/test-files/tasks.md", RawTarget: "skills/foo/evals/case/test-files/implementation.md", Type: EdgeMarkdownLink},
	}

	root := setupMetricsDiskFixture(t, "skills/foo/SKILL.md")
	m, _ := ComputeMetrics(g, root, 3)

	if len(m.BrokenEdges) != 1 {
		t.Fatalf("broken edges = %v, want exactly the live-file edge", m.BrokenEdges)
	}
	if m.BrokenEdges[0].RawSource != "skills/foo/SKILL.md" {
		t.Errorf("broken edge source = %q, want skills/foo/SKILL.md (non-operative sources must be exempt)", m.BrokenEdges[0].RawSource)
	}
}

func TestMetricsCycle(t *testing.T) {
	g := NewGraph()
	g.AddNode(&Node{Path: "A", Type: NodeShared})
	g.AddNode(&Node{Path: "B", Type: NodeShared})
	g.Edges = []Edge{
		{Source: "A", Target: "B", RawSource: "A", RawTarget: "B", Type: EdgeMarkdownLink},
		{Source: "B", Target: "A", RawSource: "B", RawTarget: "A", Type: EdgeMarkdownLink},
	}

	root := setupMetricsDiskFixture(t, "A", "B")
	m, diags := ComputeMetrics(g, root, 3)

	if m.PerNode["A"].Depth != -1 {
		t.Errorf("depth(A) = %d, want -1", m.PerNode["A"].Depth)
	}
	if m.PerNode["B"].Depth != -1 {
		t.Errorf("depth(B) = %d, want -1", m.PerNode["B"].Depth)
	}
	if len(diags) == 0 {
		t.Error("expected cycle diagnostic, got none")
	}
}

func TestMetricsIntraArtifactSelfLoop(t *testing.T) {
	g := NewGraph()
	g.AddNode(&Node{Path: "skills/foo/", Type: NodeSkill})
	g.AddNode(&Node{Path: "X", Type: NodeShared})

	g.AddEdge(Edge{
		RawSource: "skills/foo/SKILL.md",
		RawTarget: "skills/foo/process.md",
		Type:      EdgeMarkdownLink,
		Line:      1,
	})
	g.AddEdge(Edge{
		RawSource: "skills/foo/SKILL.md",
		RawTarget: "X",
		Type:      EdgeMarkdownLink,
		Line:      2,
	})

	root := t.TempDir()
	os.MkdirAll(filepath.Join(root, "skills/foo"), 0o755)
	for _, f := range []string{"skills/foo/SKILL.md", "skills/foo/process.md", "X"} {
		os.WriteFile(filepath.Join(root, f), nil, 0o644)
	}

	m, diags := ComputeMetrics(g, root, 3)

	if m.PerNode["skills/foo/"].FanOut != 1 {
		t.Errorf("fan-out(skills/foo/) = %d, want 1 (intra-artifact suppressed)", m.PerNode["skills/foo/"].FanOut)
	}
	if len(diags) != 0 {
		t.Errorf("expected no diagnostics (self-loop suppressed), got %v", diags)
	}
	if m.PerNode["skills/foo/"].Depth != 1 {
		t.Errorf("depth(skills/foo/) = %d, want 1", m.PerNode["skills/foo/"].Depth)
	}
}

func TestMetricsHotspots(t *testing.T) {
	g := NewGraph()
	g.AddNode(&Node{Path: "A", Type: NodeShared})
	g.AddNode(&Node{Path: "B", Type: NodeShared})
	g.AddNode(&Node{Path: "hot", Type: NodeShared})
	g.Edges = []Edge{
		{Source: "A", Target: "hot", RawSource: "A", RawTarget: "hot", Type: EdgeMarkdownLink},
		{Source: "B", Target: "hot", RawSource: "B", RawTarget: "hot", Type: EdgeMarkdownLink},
		{Source: "A", Target: "B", RawSource: "A", RawTarget: "B", Type: EdgeMarkdownLink},
	}

	root := setupMetricsDiskFixture(t, "A", "B", "hot")
	m, _ := ComputeMetrics(g, root, 3)

	if len(m.Hotspots) < 1 || m.Hotspots[0] != "hot" {
		t.Errorf("hotspots = %v, want [hot, ...] (hot has fan-in 2)", m.Hotspots)
	}
}

func TestMetricsCoupling(t *testing.T) {
	g := NewGraph()
	g.AddNode(&Node{Path: "skills/a/", Type: NodeSkill})
	g.AddNode(&Node{Path: "skills/b/", Type: NodeSkill})
	for _, name := range []string{"W", "X", "Y", "Z"} {
		g.AddNode(&Node{Path: name, Type: NodeShared})
	}
	g.Edges = []Edge{
		{Source: "skills/a/", Target: "W", RawSource: "skills/a/SKILL.md", RawTarget: "W", Type: EdgeMarkdownLink},
		{Source: "skills/a/", Target: "X", RawSource: "skills/a/SKILL.md", RawTarget: "X", Type: EdgeMarkdownLink},
		{Source: "skills/a/", Target: "Y", RawSource: "skills/a/SKILL.md", RawTarget: "Y", Type: EdgeMarkdownLink},
		{Source: "skills/a/", Target: "Z", RawSource: "skills/a/SKILL.md", RawTarget: "Z", Type: EdgeMarkdownLink},
		{Source: "skills/b/", Target: "W", RawSource: "skills/b/SKILL.md", RawTarget: "W", Type: EdgeMarkdownLink},
		{Source: "skills/b/", Target: "X", RawSource: "skills/b/SKILL.md", RawTarget: "X", Type: EdgeMarkdownLink},
		{Source: "skills/b/", Target: "Y", RawSource: "skills/b/SKILL.md", RawTarget: "Y", Type: EdgeMarkdownLink},
		{Source: "skills/b/", Target: "Z", RawSource: "skills/b/SKILL.md", RawTarget: "Z", Type: EdgeMarkdownLink},
	}

	root := t.TempDir()
	for _, d := range []string{"skills/a", "skills/b"} {
		os.MkdirAll(filepath.Join(root, d), 0o755)
	}
	for _, f := range []string{"skills/a/SKILL.md", "skills/b/SKILL.md", "W", "X", "Y", "Z"} {
		os.WriteFile(filepath.Join(root, f), nil, 0o644)
	}

	m, _ := ComputeMetrics(g, root, 3)

	if len(m.Coupling) != 1 {
		t.Fatalf("coupling pairs = %d, want 1", len(m.Coupling))
	}
	if m.Coupling[0].SharedCount != 4 {
		t.Errorf("shared count = %d, want 4", m.Coupling[0].SharedCount)
	}
}

func TestMetricsCouplingBelowThreshold(t *testing.T) {
	g := NewGraph()
	g.AddNode(&Node{Path: "skills/a/", Type: NodeSkill})
	g.AddNode(&Node{Path: "skills/b/", Type: NodeSkill})
	g.AddNode(&Node{Path: "X", Type: NodeShared})
	g.Edges = []Edge{
		{Source: "skills/a/", Target: "X", RawSource: "skills/a/SKILL.md", RawTarget: "X", Type: EdgeMarkdownLink},
		{Source: "skills/b/", Target: "X", RawSource: "skills/b/SKILL.md", RawTarget: "X", Type: EdgeMarkdownLink},
	}

	root := setupMetricsDiskFixture(t, "X")
	m, _ := ComputeMetrics(g, root, 3)

	if len(m.Coupling) != 0 {
		t.Errorf("coupling pairs = %d, want 0 (shared=1, below threshold 3)", len(m.Coupling))
	}
}

func setupMetricsDiskFixture(t *testing.T, files ...string) string {
	t.Helper()
	root := t.TempDir()
	for _, f := range files {
		dir := filepath.Dir(filepath.Join(root, f))
		if dir != root {
			os.MkdirAll(dir, 0o755)
		}
		os.WriteFile(filepath.Join(root, f), nil, 0o644)
	}
	return root
}
