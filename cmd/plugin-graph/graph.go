package main

import (
	"os"
	"path"
	"path/filepath"
	"strings"
)

type NodeType string

const (
	NodeSkill        NodeType = "skill"
	NodeShared       NodeType = "shared"
	NodeAgent        NodeType = "agent"
	NodeProfile      NodeType = "profile"
	NodeProfilePhase NodeType = "profile-phase"
	NodeContent      NodeType = "content"
	NodeCommand      NodeType = "command"
)

type EdgeType string

const (
	EdgeMarkdownLink     EdgeType = "markdown-link"
	EdgeSymlink          EdgeType = "symlink"
	EdgeTemplateRef      EdgeType = "template-ref"
	EdgeParameterizedNav EdgeType = "parameterized-nav"
	EdgeAgentDelegation  EdgeType = "agent-delegation"
	EdgeSkillInvocation  EdgeType = "skill-invocation"
)

type Direction int

const (
	Forward Direction = iota
	Reverse
	Both
)

type Node struct {
	Path string   `json:"path"`
	Type NodeType `json:"type"`
	Name string   `json:"name"`
}

type Edge struct {
	RawSource string   `json:"raw_source"`
	RawTarget string   `json:"raw_target"`
	Source    string   `json:"source"`
	Target   string   `json:"target"`
	Type     EdgeType `json:"type"`
	Line     int      `json:"line"`
}

type Graph struct {
	Nodes map[string]*Node `json:"nodes"`
	Edges []Edge           `json:"edges"`
}

func NewGraph() *Graph {
	return &Graph{
		Nodes: make(map[string]*Node),
		Edges: []Edge{},
	}
}

func (g *Graph) AddNode(n *Node) {
	g.Nodes[n.Path] = n
}

func (g *Graph) AddEdge(e Edge) {
	e.Source = g.NormalizePath(e.RawSource)
	e.Target = g.NormalizePath(e.RawTarget)
	g.Edges = append(g.Edges, e)
}

func (g *Graph) NodeByPath(p string) *Node {
	return g.Nodes[p]
}

func isArtifactType(t NodeType) bool {
	switch t {
	case NodeSkill, NodeProfile, NodeProfilePhase, NodeCommand:
		return true
	}
	return false
}

// NormalizePath walks up from a file path and returns the nearest ancestor
// artifact node registered in the graph. Returns the original path if no
// ancestor is an artifact.
func (g *Graph) NormalizePath(p string) string {
	clean := path.Clean(filepath.ToSlash(p))
	current := clean
	for {
		dir := path.Dir(current)
		if dir == "." || dir == current {
			break
		}
		dirPath := dir + "/"
		if node, ok := g.Nodes[dirPath]; ok && isArtifactType(node.Type) {
			return dirPath
		}
		current = dir
	}
	return clean
}

func (g *Graph) OutEdges(p string) []Edge {
	var result []Edge
	for _, e := range g.Edges {
		if e.Source == p {
			result = append(result, e)
		}
	}
	return result
}

func (g *Graph) InEdges(p string) []Edge {
	var result []Edge
	for _, e := range g.Edges {
		if e.Target == p {
			result = append(result, e)
		}
	}
	return result
}

// MetricEdges returns edges excluding intra-artifact self-loops where
// Source == Target after normalization.
func (g *Graph) MetricEdges() []Edge {
	var result []Edge
	for _, e := range g.Edges {
		if e.Source != e.Target {
			result = append(result, e)
		}
	}
	return result
}

// Reachable performs BFS on metric edges from start, following edges in the
// given direction. Returns the set of reachable node paths including start.
func (g *Graph) Reachable(start string, dir Direction) map[string]bool {
	edges := g.MetricEdges()

	outAdj := make(map[string][]string)
	inAdj := make(map[string][]string)
	for _, e := range edges {
		outAdj[e.Source] = append(outAdj[e.Source], e.Target)
		inAdj[e.Target] = append(inAdj[e.Target], e.Source)
	}

	visited := map[string]bool{start: true}
	queue := []string{start}

	for len(queue) > 0 {
		curr := queue[0]
		queue = queue[1:]

		var neighbors []string
		switch dir {
		case Forward:
			neighbors = outAdj[curr]
		case Reverse:
			neighbors = inAdj[curr]
		case Both:
			neighbors = append(outAdj[curr], inAdj[curr]...)
		}

		for _, next := range neighbors {
			if !visited[next] {
				visited[next] = true
				queue = append(queue, next)
			}
		}
	}

	return visited
}

var knownPhases = map[string]bool{
	"review-code": true,
	"review-spec": true,
	"design":      true,
	"implement":   true,
	"test":        true,
	"document":    true,
}

// ClassifyPath determines the NodeType for a path relative to the plugin root.
// Directory paths produce artifact-level types (skill, profile, profile-phase,
// command); file paths produce file-level types (shared, agent, content).
// Artifact directories require marker files on disk (SKILL.md, DETECTION.md,
// index.md) verified via pluginRoot.
func ClassifyPath(relPath string, pluginRoot string) NodeType {
	clean := path.Clean(filepath.ToSlash(relPath))
	parts := strings.Split(clean, "/")

	if len(parts) == 3 && parts[0] == "skills" && parts[1] == "_shared" && strings.HasSuffix(parts[2], ".md") {
		return NodeShared
	}

	if len(parts) == 2 && parts[0] == "agents" && strings.HasSuffix(parts[1], ".md") {
		return NodeAgent
	}

	if len(parts) == 2 && parts[0] == "skills" && parts[1] != "_shared" {
		if _, err := os.Stat(filepath.Join(pluginRoot, parts[0], parts[1], "SKILL.md")); err == nil {
			return NodeSkill
		}
	}

	if len(parts) == 3 && parts[0] == "profiles" && knownPhases[parts[2]] {
		if _, err := os.Stat(filepath.Join(pluginRoot, parts[0], parts[1], parts[2], "index.md")); err == nil {
			return NodeProfilePhase
		}
	}

	if len(parts) == 2 && parts[0] == "profiles" {
		if _, err := os.Stat(filepath.Join(pluginRoot, parts[0], parts[1], "DETECTION.md")); err == nil {
			return NodeProfile
		}
	}

	if len(parts) == 2 && parts[0] == "commands" {
		return NodeCommand
	}

	return NodeContent
}
