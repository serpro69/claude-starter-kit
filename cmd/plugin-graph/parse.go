package main

import (
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/text"
)

// ParseContext carries the shared, plugin-wide state the extractors need to
// resolve references. It is built once per build via NewParseContext.
type ParseContext struct {
	PluginRoot    string
	KnownProfiles []string
	KnownPhases   []string
	KnownAgents   []string
	KnownSkills   []string
	KnownCommands map[string][]string // skill name -> command file basenames (no .md)
}

var defaultPhases = []string{"review-code", "review-spec", "design", "implement", "test", "document"}

// NewParseContext derives the known-entity sets from the plugin tree rooted at
// pluginRoot: profiles from the §Known profiles list, agents/skills/commands
// from directory listings, and the fixed phase vocabulary.
func NewParseContext(pluginRoot string) (*ParseContext, error) {
	profiles, err := parseKnownProfiles(pluginRoot)
	if err != nil {
		return nil, err
	}
	agents, err := listAgents(pluginRoot)
	if err != nil {
		return nil, err
	}
	skills, err := listSkills(pluginRoot)
	if err != nil {
		return nil, err
	}
	commands, err := listCommands(pluginRoot)
	if err != nil {
		return nil, err
	}
	return &ParseContext{
		PluginRoot:    pluginRoot,
		KnownProfiles: profiles,
		KnownPhases:   slices.Clone(defaultPhases),
		KnownAgents:   agents,
		KnownSkills:   skills,
		KnownCommands: commands,
	}, nil
}

var profileItemRe = regexp.MustCompile("^\\s*-\\s*`([^`]+)`")

// parseKnownProfiles extracts the backtick-wrapped profile names listed under
// the "Known profiles" heading of skills/_shared/profile-detection.md. It stops
// at the next heading so prose and later sections are ignored.
func parseKnownProfiles(pluginRoot string) ([]string, error) {
	p := filepath.Join(pluginRoot, "skills", "_shared", "profile-detection.md")
	content, err := os.ReadFile(p)
	if err != nil {
		return nil, fmt.Errorf("read profile-detection.md: %w", err)
	}

	var profiles []string
	inSection := false
	for line := range strings.SplitSeq(string(content), "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "#") {
			if inSection {
				break // reached the heading after the §Known profiles list
			}
			if strings.Contains(strings.ToLower(trimmed), "known profiles") {
				inSection = true
			}
			continue
		}
		if inSection {
			if m := profileItemRe.FindStringSubmatch(line); m != nil {
				profiles = append(profiles, m[1])
			}
		}
	}
	if len(profiles) == 0 {
		return nil, fmt.Errorf("no known profiles found in %s", p)
	}
	return profiles, nil
}

func listAgents(pluginRoot string) ([]string, error) {
	entries, err := os.ReadDir(filepath.Join(pluginRoot, "agents"))
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("list agents: %w", err)
	}
	var agents []string
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		agents = append(agents, strings.TrimSuffix(e.Name(), ".md"))
	}
	return agents, nil
}

func listSkills(pluginRoot string) ([]string, error) {
	entries, err := os.ReadDir(filepath.Join(pluginRoot, "skills"))
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("list skills: %w", err)
	}
	var skills []string
	for _, e := range entries {
		if !e.IsDir() || e.Name() == "_shared" {
			continue
		}
		if _, err := os.Stat(filepath.Join(pluginRoot, "skills", e.Name(), "SKILL.md")); err != nil {
			continue
		}
		skills = append(skills, e.Name())
	}
	return skills, nil
}

func listCommands(pluginRoot string) (map[string][]string, error) {
	commands := make(map[string][]string)
	entries, err := os.ReadDir(filepath.Join(pluginRoot, "commands"))
	if err != nil {
		if os.IsNotExist(err) {
			return commands, nil
		}
		return nil, fmt.Errorf("list commands: %w", err)
	}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		cmdEntries, err := os.ReadDir(filepath.Join(pluginRoot, "commands", e.Name()))
		if err != nil {
			return nil, fmt.Errorf("list commands/%s: %w", e.Name(), err)
		}
		var cmds []string
		for _, c := range cmdEntries {
			if c.IsDir() || !strings.HasSuffix(c.Name(), ".md") {
				continue
			}
			cmds = append(cmds, strings.TrimSuffix(c.Name(), ".md"))
		}
		commands[e.Name()] = cmds
	}
	return commands, nil
}

// BuildGraph walks the plugin tree, classifies nodes, runs the extractors on
// every Markdown file, and returns the assembled graph plus any diagnostics
// (non-fatal warnings emitted during the walk).
func BuildGraph(ctx *ParseContext) (*Graph, []string, error) {
	g := NewGraph()
	var rawEdges []Edge
	var diagnostics []string

	walkErr := filepath.WalkDir(ctx.PluginRoot, func(absPath string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, relErr := relSlash(ctx.PluginRoot, absPath)
		if relErr != nil {
			return relErr
		}
		if rel == "." {
			return nil
		}

		if d.IsDir() {
			if t := ClassifyPath(rel, ctx.PluginRoot); isArtifactType(t) {
				g.AddNode(&Node{Path: rel + "/", Type: t, Name: artifactName(rel)})
			}
			return nil
		}

		// Symlinks: record a symlink edge and skip content extraction so a
		// shared file's outgoing links are attributed to its canonical path
		// only, never duplicated across each consuming skill.
		if d.Type()&fs.ModeSymlink != 0 {
			if e, ok := symlinkEdge(rel, absPath); ok {
				rawEdges = append(rawEdges, e)
			} else {
				diagnostics = append(diagnostics, fmt.Sprintf("%s: could not read symlink", rel))
			}
			return nil
		}

		// Guard against irregular files (named pipes, devices) named *.md —
		// os.ReadFile on those would block the walk indefinitely.
		if !d.Type().IsRegular() || !strings.HasSuffix(rel, ".md") {
			return nil
		}

		// A Markdown file gets its own node only when no artifact ancestor
		// absorbs it (shared files, agents, root-level content). Files inside a
		// skill/profile/command directory normalize to that artifact instead.
		if g.NormalizePath(rel) == rel {
			g.AddNode(&Node{Path: rel, Type: ClassifyPath(rel, ctx.PluginRoot), Name: path.Base(rel)})
		}

		content, readErr := os.ReadFile(absPath)
		if readErr != nil {
			diagnostics = append(diagnostics, fmt.Sprintf("%s: read failed: %v", rel, readErr))
			return nil
		}
		rawEdges = append(rawEdges, extractAll(rel, content, ctx)...)
		return nil
	})
	if walkErr != nil {
		return nil, diagnostics, fmt.Errorf("walk plugin root: %w", walkErr)
	}

	for _, e := range dedupEdges(rawEdges) {
		g.AddEdge(e)
	}
	return g, diagnostics, nil
}

// extractAll runs the content extractors over a single file. Regex-based
// extractors (3-5) operate on code-block-stripped content; the goldmark link
// extractor (1) is inherently code-block-safe and sees the raw content.
func extractAll(filePath string, content []byte, ctx *ParseContext) []Edge {
	var edges []Edge
	edges = append(edges, extractMarkdownLinks(filePath, content, ctx)...)

	stripped := stripCodeBlocks(content)
	edges = append(edges, extractPluginRootRefs(filePath, stripped, ctx)...)
	edges = append(edges, extractAgentDelegation(filePath, stripped, ctx)...)
	edges = append(edges, extractSkillInvocation(filePath, stripped, ctx)...)
	return edges
}

// dedupEdges collapses repeated references (e.g. a skill mentioned many times in
// one file) to a single edge per (RawSource, RawTarget, Type), keeping the first
// occurrence's line. Without this, fan-in/out would count the same dependency
// once per mention and distort complexity metrics.
func dedupEdges(edges []Edge) []Edge {
	seen := make(map[[3]string]bool)
	var result []Edge
	for _, e := range edges {
		key := [3]string{e.RawSource, e.RawTarget, string(e.Type)}
		if seen[key] {
			continue
		}
		seen[key] = true
		result = append(result, e)
	}
	return result
}

// --- Extractor 1: Markdown links ---

// ParseContext is unused here; the parameter keeps all five extractors on one
// signature so extractAll can call them uniformly.
func extractMarkdownLinks(filePath string, content []byte, _ *ParseContext) []Edge {
	// A fresh parser per file: goldmark's parser is stateful per Parse call and
	// not safe to share across concurrent callers.
	doc := goldmark.New().Parser().Parse(text.NewReader(content))
	dir := path.Dir(filePath)

	var edges []Edge
	ast.Walk(doc, func(n ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			return ast.WalkContinue, nil
		}
		link, ok := n.(*ast.Link)
		if !ok {
			return ast.WalkContinue, nil
		}
		target, ok := resolveMarkdownTarget(dir, string(link.Destination))
		if !ok {
			return ast.WalkContinue, nil
		}
		edges = append(edges, Edge{
			RawSource: filePath,
			RawTarget: target,
			Type:      EdgeMarkdownLink,
			Line:      linkLine(content, link),
		})
		return ast.WalkContinue, nil
	})
	return edges
}

// resolveMarkdownTarget filters out external URLs, anchor-only refs, and
// non-Markdown targets, strips any #fragment, and resolves the remainder
// relative to the linking file's directory.
func resolveMarkdownTarget(dir, dest string) (string, bool) {
	if dest == "" || strings.HasPrefix(dest, "#") {
		return "", false
	}
	if strings.Contains(dest, "://") {
		return "", false
	}
	if i := strings.IndexByte(dest, '#'); i >= 0 {
		dest = dest[:i]
	}
	if dest == "" || !strings.HasSuffix(dest, ".md") {
		return "", false
	}
	resolved := path.Clean(path.Join(dir, dest))
	if escapesRoot(resolved) {
		return "", false
	}
	return resolved, true
}

// linkLine finds the first text segment anywhere in the link's subtree and
// converts its byte offset to a line number. Walking the subtree (rather than
// only the first child) handles links whose text contains nested inline
// formatting such as emphasis, code spans, or image alt text. A link with no
// text descendant at all (e.g. an empty `[](x.md)`) yields 0; such links do
// not occur in the plugin corpus.
func linkLine(source []byte, link *ast.Link) int {
	line := 0
	ast.Walk(link, func(n ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering || line != 0 {
			return ast.WalkContinue, nil
		}
		if tn, ok := n.(*ast.Text); ok {
			line = lineNumber(source, tn.Segment.Start)
			return ast.WalkStop, nil
		}
		return ast.WalkContinue, nil
	})
	return line
}

// --- Extractor 2: Symlinks ---

func symlinkEdge(relPath, absPath string) (Edge, bool) {
	target, err := os.Readlink(absPath)
	if err != nil {
		return Edge{}, false
	}
	// relPath is already slash-normalized, so path.Join is the correct join;
	// filepath.ToSlash normalizes the OS-native link target before joining.
	resolved := path.Clean(path.Join(path.Dir(relPath), filepath.ToSlash(target)))
	if escapesRoot(resolved) {
		return Edge{}, false
	}
	return Edge{
		RawSource: relPath,
		RawTarget: resolved,
		Type:      EdgeSymlink,
	}, true
}

// --- Extractor 3: Plugin-root references (template + parameterized) ---

var pluginRootRefRe = regexp.MustCompile("`\\$\\{CLAUDE_PLUGIN_ROOT\\}/([^`]+)`")

func extractPluginRootRefs(filePath string, content []byte, ctx *ParseContext) []Edge {
	var edges []Edge
	for _, loc := range pluginRootRefRe.FindAllSubmatchIndex(content, -1) {
		remainder := string(content[loc[2]:loc[3]])
		line := lineNumber(content, loc[0])

		if isParameterizedRef(remainder) {
			for _, target := range expandParameterized(remainder, ctx) {
				edges = append(edges, Edge{
					RawSource: filePath,
					RawTarget: target,
					Type:      EdgeParameterizedNav,
					Line:      line,
				})
			}
			continue
		}

		target, ok := concreteTarget(remainder)
		if !ok {
			continue
		}
		edges = append(edges, Edge{
			RawSource: filePath,
			RawTarget: target,
			Type:      EdgeTemplateRef,
			Line:      line,
		})
	}
	return edges
}

func isParameterizedRef(remainder string) bool {
	return strings.Contains(remainder, "<name>") ||
		strings.Contains(remainder, "<profile>") ||
		strings.Contains(remainder, "<phase>") ||
		strings.Contains(remainder, "<checklist>")
}

// concreteTarget cleans a non-parameterized plugin-root remainder into a target
// path, rejecting documentation placeholders (glob wildcards and ellipses) that
// are not real on-disk paths.
func concreteTarget(remainder string) (string, bool) {
	// ContainsAny scans runes for '*' and '…' (Unicode ellipsis); the separate
	// Contains catches the ASCII '...' triple-dot. All three are doc placeholders.
	if strings.ContainsAny(remainder, "*…") || strings.Contains(remainder, "...") {
		return "", false
	}
	target := path.Clean(remainder)
	if escapesRoot(target) {
		return "", false
	}
	return target, true
}

// expandParameterized expands <name>/<profile> over known profiles, <phase> over
// known phases, and <checklist> by globbing the resolved phase directory, then
// keeps only expansions that exist on disk.
func expandParameterized(remainder string, ctx *ParseContext) []string {
	candidates := []string{remainder}
	candidates = expandToken(candidates, "<name>", ctx.KnownProfiles)
	candidates = expandToken(candidates, "<profile>", ctx.KnownProfiles)
	candidates = expandToken(candidates, "<phase>", ctx.KnownPhases)

	var expanded []string
	for _, c := range candidates {
		expanded = append(expanded, expandChecklist(c, ctx.PluginRoot)...)
	}

	seen := make(map[string]bool)
	var result []string
	for _, c := range expanded {
		if strings.ContainsAny(c, "<>") {
			continue // an unexpanded placeholder remained
		}
		clean := path.Clean(c)
		if escapesRoot(clean) {
			continue
		}
		if seen[clean] {
			continue
		}
		if _, err := os.Stat(filepath.Join(ctx.PluginRoot, clean)); err != nil {
			continue
		}
		seen[clean] = true
		result = append(result, clean)
	}
	return result
}

func expandToken(candidates []string, token string, values []string) []string {
	var out []string
	for _, c := range candidates {
		if !strings.Contains(c, token) {
			out = append(out, c)
			continue
		}
		for _, v := range values {
			out = append(out, strings.ReplaceAll(c, token, v))
		}
	}
	return out
}

// expandChecklist replaces a trailing <checklist> token with each Markdown file
// in the resolved phase directory (excluding index.md). The bidirectional index
// invariant guarantees these are exactly the files index.md references.
func expandChecklist(candidate, pluginRoot string) []string {
	if !strings.Contains(candidate, "<checklist>") {
		return []string{candidate}
	}
	dir := path.Dir(candidate)
	if strings.ContainsAny(dir, "<>") {
		return nil // profile/phase not fully resolved yet
	}
	entries, err := os.ReadDir(filepath.Join(pluginRoot, dir))
	if err != nil {
		return nil
	}
	var out []string
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || name == "index.md" || !strings.HasSuffix(name, ".md") {
			continue
		}
		out = append(out, path.Join(dir, name))
	}
	return out
}

// --- Extractor 4: Agent delegation ---

// agentDelegationRe matches a Markdown table row whose first cell mentions
// subagent_type and whose remainder names a kk: agent. `.` does not cross
// newlines, so each match is bounded to a single row.
var agentDelegationRe = regexp.MustCompile(`\|[^|]*subagent_type[^|]*\|.*kk:([a-z-]+)`)

func extractAgentDelegation(filePath string, content []byte, ctx *ParseContext) []Edge {
	var edges []Edge
	for _, loc := range agentDelegationRe.FindAllSubmatchIndex(content, -1) {
		name := string(content[loc[2]:loc[3]])
		if !slices.Contains(ctx.KnownAgents, name) {
			continue
		}
		edges = append(edges, Edge{
			RawSource: filePath,
			RawTarget: "agents/" + name + ".md",
			Type:      EdgeAgentDelegation,
			Line:      lineNumber(content, loc[0]),
		})
	}
	return edges
}

// --- Extractor 5: Skill and command invocation ---

var skillInvocationRe = regexp.MustCompile(`/kk:([a-z-]+)(?::([a-z-]+))?`)

func extractSkillInvocation(filePath string, content []byte, ctx *ParseContext) []Edge {
	owner := owningSkill(filePath)

	var edges []Edge
	for _, loc := range skillInvocationRe.FindAllSubmatchIndex(content, -1) {
		line := lineNumber(content, loc[0])
		skill := string(content[loc[2]:loc[3]])

		if skill != owner && slices.Contains(ctx.KnownSkills, skill) {
			edges = append(edges, Edge{
				RawSource: filePath,
				RawTarget: "skills/" + skill + "/",
				Type:      EdgeSkillInvocation,
				Line:      line,
			})
		}

		// A command edge is independent of the skill edge: it resolves against
		// the known-commands set alone, so peerless commands (template,
		// migrate-*) still link even when no skill of that name exists.
		if loc[4] >= 0 {
			cmd := string(content[loc[4]:loc[5]])
			if slices.Contains(ctx.KnownCommands[skill], cmd) {
				edges = append(edges, Edge{
					RawSource: filePath,
					RawTarget: "commands/" + skill + "/" + cmd + ".md",
					Type:      EdgeSkillInvocation,
					Line:      line,
				})
			}
		}
	}
	return edges
}

func owningSkill(filePath string) string {
	parts := strings.Split(filePath, "/")
	if len(parts) >= 2 && parts[0] == "skills" && parts[1] != "_shared" {
		return parts[1]
	}
	return ""
}

// --- Code-block stripping ---

// stripCodeBlocks blanks out fenced code blocks (``` and ~~~) while preserving
// the total line count so byte offsets still map to the correct source line.
func stripCodeBlocks(content []byte) []byte {
	lines := bytes.Split(content, []byte("\n"))
	inFence := false
	var fenceChar byte
	var fenceLen int

	for i, line := range lines {
		trimmed := bytes.TrimLeft(line, " \t")
		if !inFence {
			if ch, n, ok := fenceMarker(trimmed); ok {
				inFence, fenceChar, fenceLen = true, ch, n
				lines[i] = nil
			}
			continue
		}
		if isClosingFence(trimmed, fenceChar, fenceLen) {
			inFence = false
		}
		lines[i] = nil
	}
	return bytes.Join(lines, []byte("\n"))
}

// fenceMarker reports whether a (left-trimmed) line opens a code fence, plus the
// fence character and its run length.
func fenceMarker(line []byte) (byte, int, bool) {
	if len(line) == 0 || (line[0] != '`' && line[0] != '~') {
		return 0, 0, false
	}
	ch := line[0]
	n := 0
	for n < len(line) && line[n] == ch {
		n++
	}
	if n < 3 {
		return 0, 0, false
	}
	return ch, n, true
}

// isClosingFence reports whether a (left-trimmed) line closes a fence opened
// with fenceChar at fenceLen: same character, at least as long, nothing else.
func isClosingFence(line []byte, fenceChar byte, fenceLen int) bool {
	n := 0
	for n < len(line) && line[n] == fenceChar {
		n++
	}
	if n < fenceLen {
		return false
	}
	return len(bytes.TrimRight(line[n:], " \t")) == 0
}

// --- Helpers ---

func lineNumber(source []byte, offset int) int {
	if offset > len(source) {
		offset = len(source)
	}
	return bytes.Count(source[:offset], []byte("\n")) + 1
}

// escapesRoot reports whether a cleaned, slash-separated relative path points
// outside the plugin root. Resolvers reject such paths so a plugin-authored
// link or symlink cannot produce an edge (or a broken-edge stat) outside the
// analyzed tree.
func escapesRoot(p string) bool {
	return p == ".." || strings.HasPrefix(p, "../")
}

func relSlash(root, abs string) (string, error) {
	rel, err := filepath.Rel(root, abs)
	if err != nil {
		return "", err
	}
	return filepath.ToSlash(rel), nil
}

func artifactName(rel string) string {
	return path.Base(strings.TrimSuffix(rel, "/"))
}
