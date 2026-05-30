package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"text/tabwriter"
	"text/template"
)

// Report is the canonical programmatic projection of a build: the full node and
// edge sets (raw fidelity, including intra-artifact self-loops), the computed
// metrics, and any diagnostics. It is what the JSON formatter marshals.
type Report struct {
	Nodes       []*Node       `json:"nodes"`
	Edges       []Edge        `json:"edges"`
	Metrics     *GraphMetrics `json:"metrics"`
	Diagnostics []string      `json:"diagnostics"`
}

// nodeStyle maps each node type to its visual attributes, shared by the DOT and
// Mermaid formatters so the two renderings stay in sync. Shape is DOT-specific;
// Color is reused as a DOT fillcolor and a Mermaid classDef fill.
var nodeStyle = map[NodeType]struct {
	Shape string
	Color string
}{
	NodeSkill:        {"box", "#a6cee3"},
	NodeShared:       {"ellipse", "#ffff99"},
	NodeAgent:        {"component", "#b2df8a"},
	NodeProfile:      {"folder", "#fb9a99"},
	NodeProfilePhase: {"folder", "#fdbf6f"},
	NodeContent:      {"note", "#ffffff"},
	NodeCommand:      {"box", "#cab2d6"},
}

// nodeTypeOrder fixes the iteration order over node types so grouped output
// (Mermaid classDef blocks) is deterministic regardless of map ordering.
var nodeTypeOrder = []NodeType{
	NodeSkill, NodeShared, NodeAgent, NodeProfile, NodeProfilePhase, NodeContent, NodeCommand,
}

// Render dispatches to the formatter named by format. Unknown formats are an
// error rather than a silent default, so a typo surfaces loudly at the CLI.
func Render(format string, g *Graph, m *GraphMetrics, diagnostics []string) ([]byte, error) {
	switch format {
	case "json":
		return renderJSON(g, m, diagnostics)
	case "text":
		return renderText(g, m, diagnostics), nil
	case "dot":
		return renderDOT(g, m, diagnostics)
	case "mermaid":
		return renderMermaid(g, m, diagnostics), nil
	default:
		return nil, fmt.Errorf("unknown format %q (want json, text, dot, or mermaid)", format)
	}
}

// --- Validate ---

// validationReport is the JSON projection the `validate` subcommand emits: just
// the findings that drive its exit code, not the full graph or metrics.
type validationReport struct {
	BrokenEdges []Edge   `json:"broken_edges"`
	Orphans     []string `json:"orphans"`
}

// renderValidate emits only the validation findings (broken edges, orphans) that
// determine the validate subcommand's exit code. Unlike the four graph/metric
// formatters it supports json and text only — dot and mermaid have no meaning
// for a findings list, so requesting them is a loud error rather than a
// surprising graph render.
func renderValidate(format string, m *GraphMetrics) ([]byte, error) {
	switch format {
	case "json":
		rep := validationReport{BrokenEdges: m.BrokenEdges, Orphans: m.Orphans}
		if rep.BrokenEdges == nil {
			rep.BrokenEdges = []Edge{}
		}
		if rep.Orphans == nil {
			rep.Orphans = []string{}
		}
		out, err := json.MarshalIndent(rep, "", "  ")
		if err != nil {
			return nil, fmt.Errorf("marshal validation report: %w", err)
		}
		return append(out, '\n'), nil
	case "text":
		return renderValidateText(m), nil
	default:
		return nil, fmt.Errorf("validate supports only text and json formats, got %q", format)
	}
}

func renderValidateText(m *GraphMetrics) []byte {
	var buf bytes.Buffer
	if len(m.BrokenEdges) == 0 && len(m.Orphans) == 0 {
		buf.WriteString("OK: no broken edges or orphans found\n")
		return buf.Bytes()
	}
	if len(m.BrokenEdges) > 0 {
		fmt.Fprintf(&buf, "Broken edges (%d):\n", len(m.BrokenEdges))
		for _, e := range m.BrokenEdges {
			fmt.Fprintf(&buf, "  %s:%d -> %s (%s)\n", e.RawSource, e.Line, e.RawTarget, e.Type)
		}
	}
	if len(m.Orphans) > 0 {
		if buf.Len() > 0 {
			buf.WriteByte('\n')
		}
		fmt.Fprintf(&buf, "Orphans (%d):\n", len(m.Orphans))
		for _, o := range m.Orphans {
			fmt.Fprintf(&buf, "  %s\n", o)
		}
	}
	return buf.Bytes()
}

// --- JSON ---

func renderJSON(g *Graph, m *GraphMetrics, diagnostics []string) ([]byte, error) {
	if diagnostics == nil {
		diagnostics = []string{}
	}
	report := Report{
		Nodes:       sortedNodes(g),
		Edges:       sortedEdges(g),
		Metrics:     m,
		Diagnostics: diagnostics,
	}
	out, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("marshal report: %w", err)
	}
	return append(out, '\n'), nil
}

// --- Text ---

func renderText(g *Graph, m *GraphMetrics, diagnostics []string) []byte {
	var buf bytes.Buffer

	w := tabwriter.NewWriter(&buf, 0, 4, 2, ' ', 0)
	fmt.Fprintln(w, "NAME\tFAN-OUT\tFAN-IN\tDEPTH\tTRANSITIVE")
	for _, n := range skillNodesByTransitive(g, m) {
		nm := metricsOrZero(m, n.Path)
		fmt.Fprintf(w, "%s\t%d\t%d\t%d\t%d\n", n.Name, nm.FanOut, nm.FanIn, nm.Depth, nm.TransitiveClosureSize)
	}
	w.Flush()

	if len(m.Orphans) > 0 {
		fmt.Fprintf(&buf, "\nOrphans (%d):\n", len(m.Orphans))
		for _, o := range m.Orphans {
			fmt.Fprintf(&buf, "  %s\n", o)
		}
	}

	if len(m.BrokenEdges) > 0 {
		fmt.Fprintf(&buf, "\nBroken edges (%d):\n", len(m.BrokenEdges))
		for _, e := range m.BrokenEdges {
			fmt.Fprintf(&buf, "  %s:%d -> %s (%s)\n", e.RawSource, e.Line, e.RawTarget, e.Type)
		}
	}

	if len(m.Hotspots) > 0 {
		fmt.Fprintf(&buf, "\nHotspots (%d):\n", len(m.Hotspots))
		for _, h := range m.Hotspots {
			fmt.Fprintf(&buf, "  %s  (fan-in %d)\n", h, metricsOrZero(m, h).FanIn)
		}
	}

	if len(m.Coupling) > 0 {
		fmt.Fprintf(&buf, "\nCoupling (%d):\n", len(m.Coupling))
		for _, c := range m.Coupling {
			fmt.Fprintf(&buf, "  %s <-> %s  (%d shared)\n", c.SkillA, c.SkillB, c.SharedCount)
		}
	}

	if len(diagnostics) > 0 {
		fmt.Fprintf(&buf, "\nDiagnostics (%d):\n", len(diagnostics))
		for _, d := range diagnostics {
			fmt.Fprintf(&buf, "  %s\n", d)
		}
	}

	return buf.Bytes()
}

// --- DOT ---

type dotNode struct {
	ID    string // already quoted
	Shape string
	Color string
}

type dotEdge struct {
	From  string // already quoted
	To    string // already quoted
	Style string
	Label string
}

type dotData struct {
	Skills   []dotNode
	Profiles []dotNode
	Agents   []dotNode
	Other    []dotNode
	Edges    []dotEdge
}

var dotTemplate = template.Must(template.New("dot").Parse(`digraph plugin {
	rankdir=LR;
	node [style=filled];

	subgraph cluster_skills {
		label="skills";
{{- range .Skills}}
		{{.ID}} [shape={{.Shape}}, fillcolor="{{.Color}}"];
{{- end}}
	}

	subgraph cluster_profiles {
		label="profiles";
{{- range .Profiles}}
		{{.ID}} [shape={{.Shape}}, fillcolor="{{.Color}}"];
{{- end}}
	}

	subgraph cluster_agents {
		label="agents";
{{- range .Agents}}
		{{.ID}} [shape={{.Shape}}, fillcolor="{{.Color}}"];
{{- end}}
	}
{{- range .Other}}
	{{.ID}} [shape={{.Shape}}, fillcolor="{{.Color}}"];
{{- end}}
{{range .Edges}}
	{{.From}} -> {{.To}} [style={{.Style}}, label="{{.Label}}"];
{{- end}}
}
`))

func renderDOT(g *Graph, _ *GraphMetrics, _ []string) ([]byte, error) {
	var data dotData
	for _, n := range sortedNodes(g) {
		shape, color := styleFor(n.Type)
		dn := dotNode{ID: dq(n.Path), Shape: shape, Color: color}
		switch n.Type {
		case NodeSkill:
			data.Skills = append(data.Skills, dn)
		case NodeProfile, NodeProfilePhase:
			data.Profiles = append(data.Profiles, dn)
		case NodeAgent:
			data.Agents = append(data.Agents, dn)
		default:
			data.Other = append(data.Other, dn)
		}
	}
	for _, e := range graphEdges(g) {
		data.Edges = append(data.Edges, dotEdge{
			From:  dq(e.Source),
			To:    dq(e.Target),
			Style: dotEdgeStyle(e.Type),
			Label: string(e.Type),
		})
	}

	var buf bytes.Buffer
	if err := dotTemplate.Execute(&buf, data); err != nil {
		return nil, fmt.Errorf("render dot template: %w", err)
	}
	return buf.Bytes(), nil
}

// dotEdgeStyle maps edge categories to GraphViz line styles: solid for static
// filesystem edges, dashed for plugin-root template/parameterized refs, dotted
// for implicit (prose-inferred) edges.
func dotEdgeStyle(t EdgeType) string {
	switch t {
	case EdgeMarkdownLink, EdgeSymlink:
		return "solid"
	case EdgeTemplateRef, EdgeParameterizedNav:
		return "dashed"
	default: // agent-delegation, skill-invocation
		return "dotted"
	}
}

// --- Mermaid ---

func renderMermaid(g *Graph, _ *GraphMetrics, _ []string) []byte {
	nodes := sortedNodes(g)

	ids := make(map[string]string, len(nodes))
	used := make(map[string]bool, len(nodes))
	for _, n := range nodes {
		ids[n.Path] = uniqueMermaidID(mermaidID(n.Path), used)
	}

	var b strings.Builder
	b.WriteString("flowchart LR\n")
	for _, n := range nodes {
		fmt.Fprintf(&b, "\t%s[\"%s\"]\n", ids[n.Path], mermaidLabel(n.Path))
	}
	for _, e := range graphEdges(g) {
		fmt.Fprintf(&b, "\t%s -->|%s| %s\n", ids[e.Source], mermaidLabel(string(e.Type)), ids[e.Target])
	}
	for _, t := range nodeTypeOrder {
		var members []string
		for _, n := range nodes {
			if n.Type == t {
				members = append(members, ids[n.Path])
			}
		}
		if len(members) == 0 {
			continue
		}
		cls := sanitizeClass(string(t))
		fmt.Fprintf(&b, "\tclassDef %s fill:%s;\n", cls, nodeStyle[t].Color)
		fmt.Fprintf(&b, "\tclass %s %s;\n", strings.Join(members, ","), cls)
	}
	return []byte(b.String())
}

// mermaidID turns a node path into a Mermaid-safe identifier by replacing every
// character that is not a letter or digit with an underscore. All plugin paths
// begin with a letter, so the result is always a valid Mermaid node id.
func mermaidID(path string) string {
	var b strings.Builder
	b.Grow(len(path))
	for _, r := range path {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			b.WriteRune(r)
		default:
			b.WriteByte('_')
		}
	}
	return b.String()
}

// uniqueMermaidID guarantees collision-free ids: two distinct paths that
// sanitize to the same base (e.g. `a/b` and `a-b`) get suffixed `_2`, `_3`, ….
func uniqueMermaidID(base string, used map[string]bool) string {
	id := base
	for i := 2; used[id]; i++ {
		id = fmt.Sprintf("%s_%d", base, i)
	}
	used[id] = true
	return id
}

// sanitizeClass makes a node-type string usable as a Mermaid classDef name
// (hyphens are not valid there): `profile-phase` becomes `profile_phase`.
func sanitizeClass(s string) string {
	return strings.ReplaceAll(s, "-", "_")
}

// --- Shared helpers ---

func sortedNodes(g *Graph) []*Node {
	nodes := make([]*Node, 0, len(g.Nodes))
	for _, n := range g.Nodes {
		nodes = append(nodes, n)
	}
	sort.Slice(nodes, func(i, j int) bool {
		return nodes[i].Path < nodes[j].Path
	})
	return nodes
}

func sortedEdges(g *Graph) []Edge {
	edges := make([]Edge, len(g.Edges))
	copy(edges, g.Edges)
	sort.Slice(edges, func(i, j int) bool {
		return edgeLess(edges[i], edges[j])
	})
	return edges
}

func edgeLess(a, b Edge) bool {
	if a.RawSource != b.RawSource {
		return a.RawSource < b.RawSource
	}
	if a.RawTarget != b.RawTarget {
		return a.RawTarget < b.RawTarget
	}
	if a.Type != b.Type {
		return a.Type < b.Type
	}
	return a.Line < b.Line
}

// graphEdges returns the artifact-level edges used by the visual formatters:
// normalized endpoints with intra-artifact self-loops removed (via MetricEdges),
// deduplicated to one edge per (Source, Target, Type), filtered to edges whose
// both endpoints are declared nodes (so a broken edge's dangling target does not
// introduce an undeclared node), and sorted for deterministic output.
func graphEdges(g *Graph) []Edge {
	seen := make(map[[3]string]bool)
	var result []Edge
	for _, e := range g.MetricEdges() {
		if g.Nodes[e.Source] == nil || g.Nodes[e.Target] == nil {
			continue
		}
		key := [3]string{e.Source, e.Target, string(e.Type)}
		if seen[key] {
			continue
		}
		seen[key] = true
		result = append(result, e)
	}
	sort.Slice(result, func(i, j int) bool {
		if result[i].Source != result[j].Source {
			return result[i].Source < result[j].Source
		}
		if result[i].Target != result[j].Target {
			return result[i].Target < result[j].Target
		}
		return result[i].Type < result[j].Type
	})
	return result
}

// skillNodesByTransitive returns the skill nodes sorted by transitive closure
// size descending (ties broken by path) — the order the text table presents.
func skillNodesByTransitive(g *Graph, m *GraphMetrics) []*Node {
	var skills []*Node
	for _, n := range g.Nodes {
		if n.Type == NodeSkill {
			skills = append(skills, n)
		}
	}
	sort.Slice(skills, func(i, j int) bool {
		ti := metricsOrZero(m, skills[i].Path).TransitiveClosureSize
		tj := metricsOrZero(m, skills[j].Path).TransitiveClosureSize
		if ti != tj {
			return ti > tj
		}
		return skills[i].Path < skills[j].Path
	})
	return skills
}

// dq renders a string as a quoted DOT identifier, escaping embedded quotes and
// backslashes. strconv.Quote produces a valid DOT quoted-string (DOT honors the
// C-style \" and \\ escapes), so a path with unusual characters — possible once
// untrusted roots are analyzed — cannot break the output.
func dq(s string) string {
	return strconv.Quote(s)
}

// styleFor returns the DOT shape and fill color for a node type, falling back
// to a neutral box for any type absent from nodeStyle so the output stays valid
// DOT even if a new NodeType is introduced without updating the style table.
func styleFor(t NodeType) (shape, color string) {
	if st, ok := nodeStyle[t]; ok {
		return st.Shape, st.Color
	}
	return "box", "#cccccc"
}

// mermaidLabel escapes characters that are structurally significant inside a
// Mermaid label, using Mermaid's #code; HTML-entity syntax: '#' first (it
// introduces an entity, so escaping it first keeps the entities we emit from
// being re-escaped), then '"' (the ["..."] delimiter) and '|' (the |...|
// edge-label delimiter). No-op for the current corpus, which has none of these.
func mermaidLabel(s string) string {
	s = strings.ReplaceAll(s, "#", "#35;")
	s = strings.ReplaceAll(s, "\"", "#quot;")
	s = strings.ReplaceAll(s, "|", "#124;")
	return s
}

// metricsOrZero returns the metrics for path, or a zero-value NodeMetrics when
// the node is absent from m.PerNode. This keeps the formatters robust when a
// caller (e.g. targeted mode) renders a graph whose metrics were computed for a
// different node set.
func metricsOrZero(m *GraphMetrics, path string) *NodeMetrics {
	if nm := m.PerNode[path]; nm != nil {
		return nm
	}
	return &NodeMetrics{}
}
