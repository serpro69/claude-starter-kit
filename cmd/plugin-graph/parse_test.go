package main

import (
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"testing"
)

// setupParseFixture builds a minimal plugin tree and returns its root plus a
// ParseContext derived from it. Disk-dependent extractors (plugin-root refs,
// command/skill resolution) rely on this real structure.
func setupParseFixture(t *testing.T) (string, *ParseContext) {
	t.Helper()
	root := t.TempDir()

	files := map[string]string{
		"skills/_shared/profile-detection.md": "" +
			"## Profile detection procedure\n\n" +
			"### Known profiles\n\n" +
			"This is the authoritative enumeration.\n\n" +
			"- `go`\n" +
			"- `k8s`\n\n" +
			"### Algorithm\n\n" +
			"- `not-a-profile` (this line is past the section and must be ignored)\n",
		"skills/_shared/shared-thing.md": "shared content\n",
		"skills/review-code/SKILL.md": "" +
			"# review-code\n\n" +
			"See [shared](../_shared/profile-detection.md).\n" +
			"Run `/kk:test` then `/kk:test` again (deduped).\n" +
			"Read `${CLAUDE_PLUGIN_ROOT}/profiles/k8s/overview.md` for context.\n",
		"skills/review-code/review-isolated.md": "" +
			"| Param | Value |\n|---|---|\n| `subagent_type` | `kk:code-reviewer` |\n",
		"skills/test/SKILL.md":             "# test\n",
		"skills/implement/SKILL.md":        "# implement\n",
		"agents/code-reviewer.md":          "# code-reviewer\n",
		"agents/spec-reviewer.md":          "# spec-reviewer\n",
		"profiles/go/DETECTION.md":         "# go detection\n",
		"profiles/go/overview.md":          "# go overview\n",
		"profiles/go/review-code/index.md": "# go review-code index\n",
		"profiles/go/review-code/foo.md":   "# foo\n",
		"profiles/go/review-code/bar.md":   "# bar\n",
		"profiles/go/design/index.md":      "# go design index\n",
		"profiles/k8s/DETECTION.md":        "# k8s detection\n",
		"profiles/k8s/overview.md":         "# k8s overview\n",
		"profiles/k8s/design/index.md":     "# k8s design index\n",
		"commands/review-code/isolated.md": "# review-code isolated command\n",
		"commands/template/sync.md":        "# template sync command\n",
		"README.md":                        "# readme\n",
	}
	for rel, content := range files {
		full := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(full, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	ctx, err := NewParseContext(root)
	if err != nil {
		t.Fatalf("NewParseContext: %v", err)
	}
	return root, ctx
}

type edgeKey struct {
	target string
	typ    string
}

func collectEdgeKeys(edges []Edge) []edgeKey {
	keys := make([]edgeKey, 0, len(edges))
	for _, e := range edges {
		keys = append(keys, edgeKey{e.RawTarget, string(e.Type)})
	}
	sort.Slice(keys, func(i, j int) bool {
		if keys[i].target != keys[j].target {
			return keys[i].target < keys[j].target
		}
		return keys[i].typ < keys[j].typ
	})
	return keys
}

func assertEdgeKeys(t *testing.T, got []Edge, want []edgeKey) {
	t.Helper()
	gotKeys := collectEdgeKeys(got)
	sort.Slice(want, func(i, j int) bool {
		if want[i].target != want[j].target {
			return want[i].target < want[j].target
		}
		return want[i].typ < want[j].typ
	})
	if len(want) == 0 {
		want = []edgeKey{}
	}
	if !reflect.DeepEqual(gotKeys, want) {
		t.Errorf("edges mismatch\ngot:  %+v\nwant: %+v", gotKeys, want)
	}
}

func TestExtractMarkdownLinks(t *testing.T) {
	source := []byte("# Heading\n" + // 1
		"\n" + // 2
		"See [design](design.md) and [impl](impl.md#deps).\n" + // 3
		"External [site](https://example.com) and [anchor](#x).\n" + // 4
		"Image [pic](pic.png) skipped.\n" + // 5
		"Up one [other](../other.md).\n" + // 6
		"Nested [**bold** link](nested.md).\n" + // 7
		"\n" + // 8
		"```\n" + // 9
		"[incode](incode.md)\n" + // 10
		"```\n") // 11

	edges := extractMarkdownLinks("skills/review-code/SKILL.md", source, nil)

	type want struct {
		target string
		line   int
	}
	expected := []want{
		{"skills/review-code/design.md", 3},
		{"skills/review-code/impl.md", 3},
		{"skills/other.md", 6},
		{"skills/review-code/nested.md", 7},
	}
	if len(edges) != len(expected) {
		t.Fatalf("expected %d edges, got %d: %+v", len(expected), len(edges), edges)
	}
	for i, w := range expected {
		if edges[i].RawTarget != w.target {
			t.Errorf("edge[%d] target: got %q, want %q", i, edges[i].RawTarget, w.target)
		}
		if edges[i].Line != w.line {
			t.Errorf("edge[%d] line: got %d, want %d (%s)", i, edges[i].Line, w.line, w.target)
		}
		if edges[i].Type != EdgeMarkdownLink {
			t.Errorf("edge[%d] type: got %q, want markdown-link", i, edges[i].Type)
		}
	}
}

func TestExtractPluginRootRefs(t *testing.T) {
	_, ctx := setupParseFixture(t)

	tests := []struct {
		name    string
		content string
		want    []edgeKey
	}{
		{
			"concrete file -> template-ref",
			"`${CLAUDE_PLUGIN_ROOT}/profiles/k8s/overview.md`",
			[]edgeKey{{"profiles/k8s/overview.md", "template-ref"}},
		},
		{
			"concrete directory -> template-ref",
			"`${CLAUDE_PLUGIN_ROOT}/profiles/k8s/design/`",
			[]edgeKey{{"profiles/k8s/design", "template-ref"}},
		},
		{
			"parameterized name expands only to existing files",
			"`${CLAUDE_PLUGIN_ROOT}/profiles/<name>/review-code/index.md`",
			[]edgeKey{{"profiles/go/review-code/index.md", "parameterized-nav"}},
		},
		{
			"checklist glob excludes index.md",
			"`${CLAUDE_PLUGIN_ROOT}/profiles/<profile>/review-code/<checklist>`",
			[]edgeKey{
				{"profiles/go/review-code/bar.md", "parameterized-nav"},
				{"profiles/go/review-code/foo.md", "parameterized-nav"},
			},
		},
		{
			"bare variable without braces is ignored",
			"$CLAUDE_PLUGIN_ROOT/profiles/k8s/overview.md",
			nil,
		},
		{
			"glob wildcard placeholder skipped",
			"`${CLAUDE_PLUGIN_ROOT}/**`",
			nil,
		},
		{
			"ellipsis placeholder skipped",
			"`${CLAUDE_PLUGIN_ROOT}/…`",
			nil,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			edges := extractPluginRootRefs("skills/review-code/SKILL.md", []byte(tt.content), ctx)
			assertEdgeKeys(t, edges, tt.want)
		})
	}
}

func TestExtractAgentDelegation(t *testing.T) {
	_, ctx := setupParseFixture(t)

	tests := []struct {
		name    string
		content string
		want    []edgeKey
	}{
		{
			"table row with kk agent",
			"| `subagent_type` | `kk:code-reviewer` |\n",
			[]edgeKey{{"agents/code-reviewer.md", "agent-delegation"}},
		},
		{
			"table row trailing whitespace",
			"| `subagent_type` | `kk:spec-reviewer`   |\n",
			[]edgeKey{{"agents/spec-reviewer.md", "agent-delegation"}},
		},
		{
			"general-purpose row has no kk agent",
			"| `subagent_type` | From `--agent` flag or default `general-purpose` |\n",
			nil,
		},
		{
			"prose mention without table is ignored",
			"Delegate to the code-reviewer agent for an independent review.\n",
			nil,
		},
		{
			"unknown agent not in KnownAgents",
			"| `subagent_type` | `kk:made-up-agent` |\n",
			nil,
		},
		{
			"subagent_type list item without kk is ignored",
			"- `subagent_type`: `general-purpose` (or from flags)\n",
			nil,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			edges := extractAgentDelegation("skills/review-code/review-isolated.md", []byte(tt.content), ctx)
			assertEdgeKeys(t, edges, tt.want)
		})
	}
}

func TestExtractSkillInvocation(t *testing.T) {
	_, ctx := setupParseFixture(t)

	tests := []struct {
		name     string
		filePath string
		content  string
		want     []edgeKey
	}{
		{
			"skill invocation",
			"skills/document/SKILL.md",
			"Run `/kk:review-code` first.",
			[]edgeKey{{"skills/review-code/", "skill-invocation"}},
		},
		{
			"skill plus command invocation",
			"skills/document/SKILL.md",
			"Use `/kk:review-code:isolated` here.",
			[]edgeKey{
				{"commands/review-code/isolated.md", "skill-invocation"},
				{"skills/review-code/", "skill-invocation"},
			},
		},
		{
			"self reference skipped",
			"skills/implement/SKILL.md",
			"This is `/kk:implement` itself.",
			nil,
		},
		{
			"unknown skill skipped",
			"skills/document/SKILL.md",
			"Mentions `/kk:does-not-exist` skill.",
			nil,
		},
		{
			"peerless command resolves without skill",
			"skills/document/SKILL.md",
			"Invoke `/kk:template:sync` to sync.",
			[]edgeKey{{"commands/template/sync.md", "skill-invocation"}},
		},
		{
			"own command edge kept despite self skill",
			"skills/review-code/SKILL.md",
			"See `/kk:review-code:isolated`.",
			[]edgeKey{{"commands/review-code/isolated.md", "skill-invocation"}},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			edges := extractSkillInvocation(tt.filePath, []byte(tt.content), ctx)
			assertEdgeKeys(t, edges, tt.want)
		})
	}
}

func TestExtractRejectsRootEscape(t *testing.T) {
	_, ctx := setupParseFixture(t)

	// A markdown link and a concrete template-ref that both climb out of the
	// plugin root must produce no edge — resolved paths are confined to root.
	mdEdges := extractMarkdownLinks(
		"skills/review-code/SKILL.md",
		[]byte("Escape [out](../../../../etc/passwd.md) here.\n"),
		ctx,
	)
	if len(mdEdges) != 0 {
		t.Errorf("escaping markdown link should yield no edge, got %+v", mdEdges)
	}

	refEdges := extractPluginRootRefs(
		"skills/review-code/SKILL.md",
		[]byte("`${CLAUDE_PLUGIN_ROOT}/../../../etc/passwd.md`"),
		ctx,
	)
	if len(refEdges) != 0 {
		t.Errorf("escaping template-ref should yield no edge, got %+v", refEdges)
	}
}

func TestExtractStripCodeBlocks(t *testing.T) {
	source := []byte("before\n" + // 1
		"```go\n" + // 2
		"code line\n" + // 3
		"```\n" + // 4
		"middle\n" + // 5
		"~~~\n" + // 6
		"tilde fenced\n" + // 7
		"~~~\n" + // 8
		"after\n") // 9

	got := string(stripCodeBlocks(source))
	want := "before\n" +
		"\n" +
		"\n" +
		"\n" +
		"middle\n" +
		"\n" +
		"\n" +
		"\n" +
		"after\n"
	if got != want {
		t.Errorf("stripCodeBlocks mismatch\ngot:  %q\nwant: %q", got, want)
	}
}

func TestExtractCodeBlockStrippingFeedsExtractors(t *testing.T) {
	_, ctx := setupParseFixture(t)

	content := []byte("Live reference `/kk:test` outside a fence.\n" +
		"```\n" +
		"/kk:test inside a fence must be ignored\n" +
		"```\n")

	edges := extractAll("skills/document/SKILL.md", content, ctx)

	var count int
	for _, e := range edges {
		if e.Type == EdgeSkillInvocation && e.RawTarget == "skills/test/" {
			count++
		}
	}
	if count != 1 {
		t.Errorf("expected exactly 1 skill edge to skills/test/ (code-block ref stripped), got %d", count)
	}
}

func TestExtractBuildGraph(t *testing.T) {
	root, ctx := setupParseFixture(t)

	// Add a symlink mirroring the per-skill shared-instruction convention.
	symlink := filepath.Join(root, "skills", "review-code", "shared-thing.md")
	if err := os.Symlink(filepath.Join("..", "_shared", "shared-thing.md"), symlink); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}

	g, diags, err := BuildGraph(ctx)
	if err != nil {
		t.Fatalf("BuildGraph: %v", err)
	}
	if len(diags) != 0 {
		t.Errorf("unexpected diagnostics: %v", diags)
	}

	nodeTypes := map[string]NodeType{
		"skills/review-code/":                 NodeSkill,
		"skills/_shared/profile-detection.md": NodeShared,
		"skills/_shared/shared-thing.md":      NodeShared,
		"agents/code-reviewer.md":             NodeAgent,
		"profiles/go/":                        NodeProfile,
		"profiles/go/review-code/":            NodeProfilePhase,
		"commands/review-code/":               NodeCommand,
		"README.md":                           NodeContent,
	}
	for p, want := range nodeTypes {
		node := g.NodeByPath(p)
		if node == nil {
			t.Errorf("missing node %q", p)
			continue
		}
		if node.Type != want {
			t.Errorf("node %q type: got %q, want %q", p, node.Type, want)
		}
	}

	// The symlink file is absorbed into its skill artifact, never a standalone node.
	if n := g.NodeByPath("skills/review-code/shared-thing.md"); n != nil {
		t.Errorf("symlink file should not be a standalone node, got %+v", n)
	}

	// Edges discovered from review-code's SKILL.md normalize to the skill artifact.
	hasEdge := func(src, tgt string, typ EdgeType) bool {
		for _, e := range g.Edges {
			if e.Source == src && e.Target == tgt && e.Type == typ {
				return true
			}
		}
		return false
	}

	if !hasEdge("skills/review-code/", "skills/_shared/profile-detection.md", EdgeMarkdownLink) {
		t.Error("missing normalized markdown-link edge review-code -> profile-detection")
	}
	// overview.md is absorbed into the profile artifact, so the normalized
	// target is the profile node even though RawTarget keeps the file path.
	if !hasEdge("skills/review-code/", "profiles/k8s/", EdgeTemplateRef) {
		t.Error("missing template-ref edge review-code -> profiles/k8s/ (normalized)")
	}
	if !hasEdge("skills/review-code/", "skills/test/", EdgeSkillInvocation) {
		t.Error("missing skill-invocation edge review-code -> test")
	}
	if !hasEdge("skills/review-code/", "skills/_shared/shared-thing.md", EdgeSymlink) {
		t.Error("missing symlink edge review-code -> shared-thing")
	}

	// The duplicated `/kk:test` reference collapses to a single edge.
	var testEdges int
	for _, e := range g.Edges {
		if e.Type == EdgeSkillInvocation && e.Source == "skills/review-code/" && e.Target == "skills/test/" {
			testEdges++
		}
	}
	if testEdges != 1 {
		t.Errorf("expected deduped skill edge to test, got %d", testEdges)
	}
}

func TestNewParseContext(t *testing.T) {
	_, ctx := setupParseFixture(t)

	wantProfiles := []string{"go", "k8s"}
	if !reflect.DeepEqual(ctx.KnownProfiles, wantProfiles) {
		t.Errorf("KnownProfiles: got %v, want %v", ctx.KnownProfiles, wantProfiles)
	}

	sort.Strings(ctx.KnownSkills)
	wantSkills := []string{"implement", "review-code", "test"}
	if !reflect.DeepEqual(ctx.KnownSkills, wantSkills) {
		t.Errorf("KnownSkills: got %v, want %v", ctx.KnownSkills, wantSkills)
	}

	sort.Strings(ctx.KnownAgents)
	wantAgents := []string{"code-reviewer", "spec-reviewer"}
	if !reflect.DeepEqual(ctx.KnownAgents, wantAgents) {
		t.Errorf("KnownAgents: got %v, want %v", ctx.KnownAgents, wantAgents)
	}

	if got := ctx.KnownCommands["review-code"]; !reflect.DeepEqual(got, []string{"isolated"}) {
		t.Errorf("KnownCommands[review-code]: got %v, want [isolated]", got)
	}
	if got := ctx.KnownCommands["template"]; !reflect.DeepEqual(got, []string{"sync"}) {
		t.Errorf("KnownCommands[template]: got %v, want [sync]", got)
	}
}
