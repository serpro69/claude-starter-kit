package main

import (
	"bytes"
	"encoding/json"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// writeCLIFixture builds a minimal but valid plugin tree in a temp dir and
// returns its root. The tree exercises every node level the CLI cares about
// (skills, shared files, an agent) plus a skill-invocation edge. When broken is
// true, one skill gains a dangling markdown link so `validate` has a finding.
//
// skills/_shared/profile-detection.md is mandatory: NewParseContext fails if it
// cannot derive at least one Known profile.
func writeCLIFixture(t *testing.T, broken bool) string {
	t.Helper()
	root := t.TempDir()

	files := map[string]string{
		"skills/_shared/profile-detection.md": "# Profile detection\n\n## Known profiles\n\n- `go`\n",
		"skills/_shared/common.md":            "# Common\n\nShared instruction body.\n",
		"skills/alpha/SKILL.md": "# Alpha\n\n" +
			"See [common](../_shared/common.md) and [detection](../_shared/profile-detection.md).\n\n" +
			"Delegate follow-up work to /kk:beta when needed.\n",
		"skills/beta/SKILL.md":    "# Beta\n\nA second skill with no outgoing edges.\n",
		"agents/code-reviewer.md": "# Code Reviewer\n\nAn agent definition.\n",
	}
	if broken {
		files["skills/beta/SKILL.md"] += "\nFurther detail lives in [missing notes](./missing.md).\n"
	}

	for rel, content := range files {
		abs := filepath.Join(root, filepath.FromSlash(rel))
		if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
			t.Fatalf("mkdir for %s: %v", rel, err)
		}
		if err := os.WriteFile(abs, []byte(content), 0o644); err != nil {
			t.Fatalf("write %s: %v", rel, err)
		}
	}
	return root
}

// runCLI invokes run with captured stdout/stderr and returns code + buffers.
func runCLI(args ...string) (int, string, string) {
	var stdout, stderr bytes.Buffer
	code := run(args, &stdout, &stderr)
	return code, stdout.String(), stderr.String()
}

func TestMainGraphSubcommand(t *testing.T) {
	root := writeCLIFixture(t, false)

	code, stdout, stderr := runCLI("--root", root, "graph")
	if code != exitOK {
		t.Fatalf("graph exit = %d, want %d (stderr: %s)", code, exitOK, stderr)
	}
	if strings.TrimSpace(stdout) == "" {
		t.Errorf("graph produced empty stdout")
	}
}

func TestMainDefaultSubcommand(t *testing.T) {
	root := writeCLIFixture(t, false)

	// No subcommand → defaults to graph.
	code, stdout, _ := runCLI("--root", root)
	if code != exitOK {
		t.Fatalf("default exit = %d, want %d", code, exitOK)
	}
	if strings.TrimSpace(stdout) == "" {
		t.Errorf("default invocation produced empty stdout")
	}
}

func TestMainMetricsJSON(t *testing.T) {
	root := writeCLIFixture(t, false)

	// Global flag before subcommand, per-subcommand flag after — the documented
	// grammar. The output must be valid JSON carrying every skill node.
	code, stdout, stderr := runCLI("--root", root, "metrics", "--format", "json")
	if code != exitOK {
		t.Fatalf("metrics exit = %d, want %d (stderr: %s)", code, exitOK, stderr)
	}

	var rep Report
	if err := json.Unmarshal([]byte(stdout), &rep); err != nil {
		t.Fatalf("metrics --format json did not produce valid JSON: %v", err)
	}
	wantSkills := map[string]bool{"skills/alpha/": false, "skills/beta/": false}
	for _, n := range rep.Nodes {
		if _, ok := wantSkills[n.Path]; ok {
			wantSkills[n.Path] = true
		}
	}
	for path, found := range wantSkills {
		if !found {
			t.Errorf("metrics JSON missing skill node %q", path)
		}
	}
}

func TestMainGlobalFlagAfterSubcommandFails(t *testing.T) {
	root := writeCLIFixture(t, false)

	// --root after the subcommand is not a per-subcommand flag, so the
	// subcommand FlagSet must reject it. This pins the "global before, per-sub
	// after" grammar.
	code, _, _ := runCLI("metrics", "--root", root)
	if code != exitError {
		t.Fatalf("global flag after subcommand exit = %d, want %d", code, exitError)
	}
}

func TestMainValidateClean(t *testing.T) {
	root := writeCLIFixture(t, false)

	code, stdout, stderr := runCLI("--root", root, "validate")
	if code != exitOK {
		t.Fatalf("validate (clean) exit = %d, want %d (stdout: %s, stderr: %s)", code, exitOK, stdout, stderr)
	}
	if !strings.Contains(stdout, "OK") {
		t.Errorf("validate (clean) stdout = %q, want an OK message", stdout)
	}
}

func TestMainValidateBroken(t *testing.T) {
	root := writeCLIFixture(t, true)

	code, stdout, _ := runCLI("--root", root, "validate")
	if code != exitFindings {
		t.Fatalf("validate (broken) exit = %d, want %d", code, exitFindings)
	}
	if !strings.Contains(stdout, "missing.md") {
		t.Errorf("validate (broken) stdout = %q, want it to name the broken target", stdout)
	}
}

func TestMainValidateJSON(t *testing.T) {
	root := writeCLIFixture(t, true)

	code, stdout, _ := runCLI("--root", root, "validate", "--format", "json")
	if code != exitFindings {
		t.Fatalf("validate --format json exit = %d, want %d", code, exitFindings)
	}
	var rep validationReport
	if err := json.Unmarshal([]byte(stdout), &rep); err != nil {
		t.Fatalf("validate --format json invalid: %v", err)
	}
	if len(rep.BrokenEdges) == 0 {
		t.Errorf("validate JSON reported no broken edges, want at least one")
	}
}

func TestMainValidateUnsupportedFormat(t *testing.T) {
	root := writeCLIFixture(t, false)

	// validate emits a findings list; dot/mermaid have no meaning for it and must
	// be a loud error rather than a surprising graph render. This pins the only
	// branch in renderValidate the other validate tests don't reach.
	code, _, stderr := runCLI("--root", root, "validate", "--format", "dot")
	if code != exitError {
		t.Fatalf("validate --format dot exit = %d, want %d", code, exitError)
	}
	if !strings.Contains(stderr, "validate supports only text and json") {
		t.Errorf("validate --format dot stderr = %q, want it to name the supported formats", stderr)
	}
}

func TestMainTargetedMode(t *testing.T) {
	root := writeCLIFixture(t, false)

	// Forward reachability from alpha reaches beta (skill-invocation) and the
	// two shared files, but never the unrelated agent node.
	code, stdout, stderr := runCLI("--root", root, "metrics", "--format", "json", "skills/alpha/")
	if code != exitOK {
		t.Fatalf("targeted exit = %d, want %d (stderr: %s)", code, exitOK, stderr)
	}
	var rep Report
	if err := json.Unmarshal([]byte(stdout), &rep); err != nil {
		t.Fatalf("targeted output invalid JSON: %v", err)
	}
	paths := make(map[string]bool)
	for _, n := range rep.Nodes {
		paths[n.Path] = true
	}
	if !paths["skills/beta/"] {
		t.Errorf("targeted subgraph missing skills/beta/ (reachable via skill-invocation)")
	}
	if paths["agents/code-reviewer.md"] {
		t.Errorf("targeted subgraph included unreachable agents/code-reviewer.md")
	}
}

func TestMainValidateRejectsTargets(t *testing.T) {
	root := writeCLIFixture(t, false)

	// validate is a whole-graph gate; a reachable slice would make its orphan and
	// broken-edge counts misleading. Targets must be rejected, not silently
	// applied. graph/metrics still accept targets (covered by TestMainTargetedMode).
	code, _, stderr := runCLI("--root", root, "validate", "skills/alpha/")
	if code != exitError {
		t.Fatalf("validate with target exit = %d, want %d", code, exitError)
	}
	if !strings.Contains(stderr, "does not accept target") {
		t.Errorf("validate with target stderr = %q, want a rejection message", stderr)
	}
}

func TestMainTargetedModeUnknownTarget(t *testing.T) {
	root := writeCLIFixture(t, false)

	code, _, stderr := runCLI("--root", root, "graph", "skills/does-not-exist/")
	if code != exitError {
		t.Fatalf("unknown target exit = %d, want %d", code, exitError)
	}
	if !strings.Contains(stderr, "does not resolve") {
		t.Errorf("unknown target stderr = %q, want a resolution error", stderr)
	}
}

func TestMainUnknownSubcommand(t *testing.T) {
	root := writeCLIFixture(t, false)

	code, _, stderr := runCLI("--root", root, "bogus")
	if code != exitError {
		t.Fatalf("unknown subcommand exit = %d, want %d", code, exitError)
	}
	if !strings.Contains(stderr, "unknown subcommand") {
		t.Errorf("unknown subcommand stderr = %q", stderr)
	}
}

func TestMainUnknownFormat(t *testing.T) {
	root := writeCLIFixture(t, false)

	code, _, stderr := runCLI("--root", root, "graph", "--format", "yaml")
	if code != exitError {
		t.Fatalf("unknown format exit = %d, want %d", code, exitError)
	}
	if !strings.Contains(stderr, "unknown format") {
		t.Errorf("unknown format stderr = %q", stderr)
	}
}

func TestMainInvalidDirection(t *testing.T) {
	root := writeCLIFixture(t, false)

	code, _, stderr := runCLI("--root", root, "graph", "--direction", "sideways")
	if code != exitError {
		t.Fatalf("invalid direction exit = %d, want %d", code, exitError)
	}
	if !strings.Contains(stderr, "invalid direction") {
		t.Errorf("invalid direction stderr = %q", stderr)
	}
}

func TestMainRefAbsoluteRootRejected(t *testing.T) {
	// --ref resolves the repo-relative --root inside the worktree. An absolute
	// --root cannot be located there, so the combination is rejected up front —
	// before any worktree is created, so this needs no git. The happy path
	// (--ref against a real repo) is covered in worktree_test.go.
	code, _, stderr := runCLI("--root", "/abs/klaude-plugin", "--ref", "HEAD~1", "metrics")
	if code != exitError {
		t.Fatalf("--ref with absolute root exit = %d, want %d", code, exitError)
	}
	if !strings.Contains(stderr, "repo-relative --root") {
		t.Errorf("--ref absolute-root stderr = %q, want it to explain the relative-root requirement", stderr)
	}
}

func TestMainHelpExitsZero(t *testing.T) {
	root := writeCLIFixture(t, false)

	// -h/--help is an explicit request, not a usage error: usage is printed and
	// the process exits 0. Cover both the global and per-subcommand flag sets.
	for _, args := range [][]string{
		{"--root", root, "-h"},
		{"--root", root, "graph", "-h"},
	} {
		code, _, _ := runCLI(args...)
		if code != exitOK {
			t.Errorf("runCLI(%v) exit = %d, want %d", args, code, exitOK)
		}
	}
}

func TestMainDirectionWithoutTargetsWarns(t *testing.T) {
	root := writeCLIFixture(t, false)

	// A non-default --direction with no targets is inert; the run still succeeds
	// but must warn so the no-op surfaces rather than confusing the user.
	code, _, stderr := runCLI("--root", root, "graph", "--direction", "reverse")
	if code != exitOK {
		t.Fatalf("graph --direction reverse (no targets) exit = %d, want %d", code, exitOK)
	}
	if !strings.Contains(stderr, "has no effect without targets") {
		t.Errorf("stderr = %q, want a --direction no-op warning", stderr)
	}
}

// fixtureRoot is the committed minimal-plugin tree the integration test walks
// end-to-end. Unlike writeCLIFixture's temp tree, it is checked in so the
// symlink, the ${CLAUDE_PLUGIN_ROOT} references, the intentional broken link,
// and the orphan are exercised exactly as a real plugin would be — including
// the on-disk symlink, which a map-of-strings fixture cannot represent.
const fixtureRoot = "testdata/minimal-plugin"

// TestIntegrationFixturePipeline runs the whole walk → parse → build → metrics
// pipeline against testdata/minimal-plugin and pins the node/edge shape, both
// intentional defects (one broken edge, one orphan), and that connected nodes
// get non-zero metrics. It is the feature's end-to-end safety net: each extractor
// and every node level is exercised against a real filesystem rather than a
// hand-built graph.
func TestIntegrationFixturePipeline(t *testing.T) {
	ctx, err := NewParseContext(fixtureRoot)
	if err != nil {
		t.Fatalf("NewParseContext(%q): %v", fixtureRoot, err)
	}
	g, diags, err := BuildGraph(ctx)
	if err != nil {
		t.Fatalf("BuildGraph: %v", err)
	}

	// A clean, acyclic fixture must walk without warnings; a stray diagnostic
	// means an unreadable file or a broken symlink crept into the tree.
	if len(diags) != 0 {
		t.Errorf("unexpected build diagnostics: %v", diags)
	}

	// Nodes: exactly the nine artifact/file nodes, grouped by type. The content
	// pair is orphan.md plus the entry-point README.md.
	wantNodeTypes := map[NodeType]int{
		NodeSkill:        2, // skills/alpha/, skills/beta/
		NodeShared:       2, // _shared/profile-detection.md, _shared/common-helper.md
		NodeAgent:        1, // agents/example-reviewer.md
		NodeProfile:      1, // profiles/sample/
		NodeProfilePhase: 1, // profiles/sample/review-code/
		NodeContent:      2, // orphan.md, README.md
	}
	gotNodeTypes := make(map[NodeType]int)
	for _, n := range g.Nodes {
		gotNodeTypes[n.Type]++
	}
	if !maps.Equal(gotNodeTypes, wantNodeTypes) {
		t.Errorf("node type counts = %v, want %v", gotNodeTypes, wantNodeTypes)
	}
	if len(g.Nodes) != 9 {
		t.Errorf("node count = %d, want 9", len(g.Nodes))
	}
	for _, p := range []string{
		"skills/alpha/", "skills/beta/",
		"skills/_shared/profile-detection.md", "skills/_shared/common-helper.md",
		"agents/example-reviewer.md",
		"profiles/sample/", "profiles/sample/review-code/",
		"orphan.md", "README.md",
	} {
		if g.NodeByPath(p) == nil {
			t.Errorf("expected node %q missing from graph", p)
		}
	}

	// Edges: every edge type the extractors can produce is exercised by the
	// fixture, so the integration test fails if any extractor stops firing.
	edgesByType := make(map[EdgeType][]Edge)
	for _, e := range g.Edges {
		edgesByType[e.Type] = append(edgesByType[e.Type], e)
	}
	// Symlink is asserted separately below (it depends on the checkout
	// materializing a real symlink, which Windows may not do).
	for _, et := range []EdgeType{
		EdgeMarkdownLink, EdgeTemplateRef,
		EdgeParameterizedNav, EdgeAgentDelegation, EdgeSkillInvocation,
	} {
		if len(edgesByType[et]) == 0 {
			t.Errorf("no %q edge produced; the fixture should exercise every edge type", et)
		}
	}

	// Pin the agent-delegation edge to its source: a type-only check would pass
	// even if an extractor misfired and produced the edge from the wrong file.
	if !slices.ContainsFunc(edgesByType[EdgeAgentDelegation], func(e Edge) bool {
		return e.RawSource == "skills/alpha/SKILL.md" && e.RawTarget == "agents/example-reviewer.md"
	}) {
		t.Errorf("agent-delegation edge not attributed to skills/alpha/SKILL.md -> agents/example-reviewer.md; got %v", edgesByType[EdgeAgentDelegation])
	}

	// The symlink edge depends on shared-common-helper.md being checked out as a
	// real symlink. Git on Windows without symlink support materializes it as a
	// regular file, so assert the edge (and its source) only when the on-disk
	// entry is actually a symlink; otherwise skip rather than fail off-platform.
	symlinkPath := filepath.Join(fixtureRoot, "skills", "alpha", "shared-common-helper.md")
	if fi, statErr := os.Lstat(symlinkPath); statErr == nil && fi.Mode()&os.ModeSymlink != 0 {
		if !slices.ContainsFunc(edgesByType[EdgeSymlink], func(e Edge) bool {
			return e.RawSource == "skills/alpha/shared-common-helper.md" && e.RawTarget == "skills/_shared/common-helper.md"
		}) {
			t.Errorf("symlink edge not attributed to skills/alpha/shared-common-helper.md -> skills/_shared/common-helper.md; got %v", edgesByType[EdgeSymlink])
		}
	} else {
		t.Logf("skipping symlink-edge assertion: %s is not a materialized symlink (expected on Windows checkouts without symlink support)", symlinkPath)
	}

	m, mDiags := ComputeMetrics(g, fixtureRoot, defaultCouplingThreshold)
	// The fixture is acyclic, so metric computation must also emit no diagnostics
	// — symmetric with the BuildGraph diagnostics check above.
	if len(mDiags) != 0 {
		t.Errorf("unexpected metric diagnostics: %v", mDiags)
	}

	// The intentional broken edge: beta links to a file that does not exist.
	// Broken detection works off RawTarget, so the missing concrete path is
	// flagged even though it normalizes into the existing skills/beta/ artifact.
	if !slices.ContainsFunc(m.BrokenEdges, func(e Edge) bool {
		return e.RawTarget == "skills/beta/does-not-exist.md"
	}) {
		t.Errorf("broken edge to skills/beta/does-not-exist.md not detected; broken edges = %v", m.BrokenEdges)
	}

	// The intentional orphan: orphan.md has zero fan-in and is a content node.
	// README.md also has zero fan-in but is an entry point and must be excluded.
	if !slices.Contains(m.Orphans, "orphan.md") {
		t.Errorf("orphan.md not flagged as orphan; orphans = %v", m.Orphans)
	}
	if slices.Contains(m.Orphans, "README.md") {
		t.Errorf("README.md must be excluded from orphans; orphans = %v", m.Orphans)
	}

	// Connected nodes carry non-zero metrics: alpha pulls in shared + agent +
	// beta; the agent is reached by two skills; beta is reached by alpha.
	for path, check := range map[string]func(*NodeMetrics) bool{
		"skills/alpha/":              func(nm *NodeMetrics) bool { return nm.FanOut > 0 },
		"agents/example-reviewer.md": func(nm *NodeMetrics) bool { return nm.FanIn > 0 },
		"skills/beta/":               func(nm *NodeMetrics) bool { return nm.FanIn > 0 },
	} {
		nm := m.PerNode[path]
		if nm == nil || !check(nm) {
			t.Errorf("node %q has unexpected zero metric: %+v", path, nm)
		}
	}
}

// TestIntegrationFixtureValidate runs the validate gate over the same fixture
// through the real CLI entry point. Both intentional defects make it a findings
// exit (1), and the report must name the broken target and the orphan.
func TestIntegrationFixtureValidate(t *testing.T) {
	code, stdout, stderr := runCLI("--root", fixtureRoot, "validate")
	if code != exitFindings {
		t.Fatalf("validate exit = %d, want %d (stdout: %s, stderr: %s)", code, exitFindings, stdout, stderr)
	}
	if !strings.Contains(stdout, "does-not-exist.md") {
		t.Errorf("validate stdout should name the broken target; got %q", stdout)
	}
	if !strings.Contains(stdout, "orphan.md") {
		t.Errorf("validate stdout should name the orphan; got %q", stdout)
	}
}
