package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
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

func TestMainRefNotSupported(t *testing.T) {
	root := writeCLIFixture(t, false)

	// --ref is parsed (the grammar is stable) but rejected until Task 6 wires
	// the worktree. Asserting the rejection guards against it silently no-oping.
	code, _, stderr := runCLI("--root", root, "--ref", "HEAD~1", "metrics")
	if code != exitError {
		t.Fatalf("--ref exit = %d, want %d", code, exitError)
	}
	if !strings.Contains(stderr, "--ref is not yet supported") {
		t.Errorf("--ref stderr = %q", stderr)
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
