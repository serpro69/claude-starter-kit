package main

import (
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

type NodeMetrics struct {
	FanOut                int `json:"fan_out"`
	FanIn                 int `json:"fan_in"`
	Depth                 int `json:"depth"`
	TransitiveClosureSize int `json:"transitive_closure_size"`
}

type SkillPair struct {
	SkillA      string `json:"skill_a"`
	SkillB      string `json:"skill_b"`
	SharedCount int    `json:"shared_count"`
}

type GraphMetrics struct {
	PerNode     map[string]*NodeMetrics `json:"per_node"`
	Orphans     []string                `json:"orphans"`
	BrokenEdges []Edge                  `json:"broken_edges"`
	Hotspots    []string                `json:"hotspots"`
	Coupling    []SkillPair             `json:"coupling"`
}

func ComputeMetrics(g *Graph, pluginRoot string, couplingThreshold int) (*GraphMetrics, []string) {
	edges := g.MetricEdges()

	m := &GraphMetrics{
		PerNode:     make(map[string]*NodeMetrics),
		Orphans:     []string{},
		BrokenEdges: []Edge{},
		Hotspots:    []string{},
		Coupling:    []SkillPair{},
	}
	for p := range g.Nodes {
		m.PerNode[p] = &NodeMetrics{}
	}

	for _, e := range edges {
		if nm, ok := m.PerNode[e.Source]; ok {
			nm.FanOut++
		}
		if nm, ok := m.PerNode[e.Target]; ok {
			nm.FanIn++
		}
	}

	outAdj := make(map[string][]string)
	for _, e := range edges {
		outAdj[e.Source] = append(outAdj[e.Source], e.Target)
	}

	var diagnostics []string
	diagnostics = append(diagnostics, computeDepth(g, outAdj, m)...)

	for p := range g.Nodes {
		reachable := g.Reachable(p, Forward)
		if nm, ok := m.PerNode[p]; ok {
			nm.TransitiveClosureSize = len(reachable) - 1
		}
	}

	computeOrphans(g, m)
	computeBrokenEdges(g, pluginRoot, m)
	computeHotspots(m)
	computeCoupling(g, m, couplingThreshold)

	return m, diagnostics
}

func computeDepth(g *Graph, outAdj map[string][]string, m *GraphMetrics) []string {
	const (
		unvisited = 0
		visiting  = 1
		visited   = 2
	)
	nodeState := make(map[string]int)
	depthMap := make(map[string]int)
	cyclic := make(map[string]bool)

	var dfs func(string) int
	dfs = func(node string) int {
		switch nodeState[node] {
		case visited:
			return depthMap[node]
		case visiting:
			cyclic[node] = true
			return -1
		}
		nodeState[node] = visiting

		children := outAdj[node]
		if len(children) == 0 {
			nodeState[node] = visited
			depthMap[node] = 0
			return 0
		}

		maxChild := 0
		reachesCycle := false
		for _, next := range children {
			d := dfs(next)
			if d == -1 {
				reachesCycle = true
			} else if d > maxChild {
				maxChild = d
			}
		}

		nodeState[node] = visited
		if cyclic[node] || reachesCycle {
			depthMap[node] = -1
			return -1
		}
		depthMap[node] = maxChild + 1
		return depthMap[node]
	}

	for p := range g.Nodes {
		if nodeState[p] == unvisited {
			dfs(p)
		}
	}

	for p, d := range depthMap {
		if nm, ok := m.PerNode[p]; ok {
			nm.Depth = d
		}
	}

	var affected []string
	for p := range g.Nodes {
		if depthMap[p] == -1 {
			affected = append(affected, p)
		}
	}
	if len(affected) > 0 {
		sort.Strings(affected)
		return []string{"cycle detected affecting: " + strings.Join(affected, ", ")}
	}
	return nil
}

func computeOrphans(g *Graph, m *GraphMetrics) {
	for p, nm := range m.PerNode {
		node := g.Nodes[p]
		if node == nil {
			continue
		}
		if node.Type != NodeContent && node.Type != NodeShared {
			continue
		}
		if nm.FanIn > 0 {
			continue
		}
		if p == "README.md" {
			continue
		}
		if strings.Contains(p, "evals/") {
			continue
		}
		m.Orphans = append(m.Orphans, p)
	}
	sort.Strings(m.Orphans)
}

func computeBrokenEdges(g *Graph, pluginRoot string, m *GraphMetrics) {
	targetExists := make(map[string]bool)
	for _, e := range g.Edges {
		// Edges from non-operative content are not part of the live instruction
		// dependency graph, so a missing target there is not a build-breaking bug.
		if nonOperativeSource(e.RawSource) {
			continue
		}
		target := e.RawTarget
		if _, checked := targetExists[target]; !checked {
			fullPath := filepath.Join(pluginRoot, target)
			_, err := os.Stat(fullPath)
			targetExists[target] = err == nil
		}
		if !targetExists[target] {
			m.BrokenEdges = append(m.BrokenEdges, e)
		}
	}
}

// nonOperativeSource reports whether an edge originating from path should be
// exempt from broken-edge detection because the source is non-operative content
// rather than a live instruction file:
//
//   - eval fixtures under evals/ — synthetic, partial-by-design test inputs;
//     several deliberately reference absent targets (e.g. a tasks.md that links a
//     missing implementation.md) precisely so an eval can test missing-target
//     detection. This mirrors the evals/ exemption already applied to orphans.
//   - example-*.md artifacts — faithful templates whose illustrative links (e.g.
//     example-tasks.md's [design.md](design.md)) intentionally mimic a real file
//     and may dangle.
//
// Live instruction files (SKILL.md, process/checklist content, shared
// instructions) are NOT exempt, so a genuinely broken pointer there is still
// flagged.
//
// The example-*.md match is by basename and therefore plugin-wide by design:
// example-* is the repo's naming convention for example artifacts, so any such
// file is treated as illustrative regardless of where it lives. path.Base (not
// filepath.Base) is correct because RawSource is always slash-normalized by the
// walker (relSlash), independent of the host OS separator.
func nonOperativeSource(p string) bool {
	if strings.Contains(p, "evals/") {
		return true
	}
	return strings.HasPrefix(path.Base(p), "example-")
}

func computeHotspots(m *GraphMetrics) {
	type nodeScore struct {
		path  string
		fanIn int
	}
	var scores []nodeScore
	for p, nm := range m.PerNode {
		if nm.FanIn > 0 {
			scores = append(scores, nodeScore{p, nm.FanIn})
		}
	}
	sort.Slice(scores, func(i, j int) bool {
		if scores[i].fanIn != scores[j].fanIn {
			return scores[i].fanIn > scores[j].fanIn
		}
		return scores[i].path < scores[j].path
	})
	for _, s := range scores {
		m.Hotspots = append(m.Hotspots, s.path)
	}
}

func computeCoupling(g *Graph, m *GraphMetrics, threshold int) {
	var skills []string
	for p, node := range g.Nodes {
		if node.Type == NodeSkill {
			skills = append(skills, p)
		}
	}
	sort.Strings(skills)

	reachableSets := make(map[string]map[string]bool)
	for _, s := range skills {
		reachableSets[s] = g.Reachable(s, Forward)
	}

	for i := 0; i < len(skills); i++ {
		for j := i + 1; j < len(skills); j++ {
			a, b := skills[i], skills[j]
			setA, setB := reachableSets[a], reachableSets[b]
			shared := 0
			for node := range setA {
				if node == a || node == b {
					continue
				}
				if setB[node] {
					shared++
				}
			}
			if shared > threshold {
				m.Coupling = append(m.Coupling, SkillPair{
					SkillA:      a,
					SkillB:      b,
					SharedCount: shared,
				})
			}
		}
	}
	sort.Slice(m.Coupling, func(i, j int) bool {
		if m.Coupling[i].SharedCount != m.Coupling[j].SharedCount {
			return m.Coupling[i].SharedCount > m.Coupling[j].SharedCount
		}
		if m.Coupling[i].SkillA != m.Coupling[j].SkillA {
			return m.Coupling[i].SkillA < m.Coupling[j].SkillA
		}
		return m.Coupling[i].SkillB < m.Coupling[j].SkillB
	})
}
