package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"slices"
)

const (
	defaultRoot              = "klaude-plugin/"
	defaultCouplingThreshold = 3
)

// Exit codes. validate distinguishes "found issues" (1) from "could not run" (2)
// so CI can treat the two differently: 1 is a real plugin defect to fix, 2 is a
// usage or environment problem.
const (
	exitOK       = 0
	exitFindings = 1
	exitError    = 2
)

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

// run parses args, dispatches to a subcommand, and returns the process exit
// code. Structured output goes to stdout; diagnostics and errors go to stderr.
// Keeping the body out of main (which only wires os.Args/os.Stdout/os.Stderr)
// makes the whole CLI testable: a test calls run with explicit args and buffers.
func run(args []string, stdout, stderr io.Writer) int {
	// Global flags precede the subcommand. flag.Parse stops at the first
	// non-flag token, so globalFS consumes --root/--ref and leaves the
	// subcommand plus its flags and targets in Args().
	globalFS := flag.NewFlagSet("plugin-graph", flag.ContinueOnError)
	globalFS.SetOutput(stderr)
	globalFS.Usage = func() { usage(stderr) }
	root := globalFS.String("root", defaultRoot, "plugin root directory to analyze")
	ref := globalFS.String("ref", "", "git ref to analyze via a temporary worktree (default: working tree)")
	if err := globalFS.Parse(args); err != nil {
		// flag.ErrHelp means -h/--help was requested: usage is already printed,
		// so exit cleanly (0) rather than signaling a usage error (2).
		if err == flag.ErrHelp {
			return exitOK
		}
		return exitError
	}

	rest := globalFS.Args()
	sub := "graph" // default subcommand when none is given
	if len(rest) > 0 {
		sub = rest[0]
		rest = rest[1:]
	}
	switch sub {
	case "graph", "metrics", "validate":
	default:
		fmt.Fprintf(stderr, "error: unknown subcommand %q\n", sub)
		usage(stderr)
		return exitError
	}

	subFS := flag.NewFlagSet(sub, flag.ContinueOnError)
	subFS.SetOutput(stderr)
	subFS.Usage = func() { usage(stderr) }
	format := subFS.String("format", "text", "output format: json, text, dot, or mermaid")
	direction := subFS.String("direction", "forward", "targeted-mode traversal: forward, reverse, or both")
	if err := subFS.Parse(rest); err != nil {
		if err == flag.ErrHelp {
			return exitOK
		}
		return exitError
	}
	targets := subFS.Args()

	// validate is a whole-graph health gate: broken edges and orphans are global
	// signals, not slice-relative complexity. A reachable subgraph would zero out
	// fan-in for boundary nodes (false orphans) and drop filtered-out broken
	// edges, making the gate's findings misleading. Reject targets outright
	// rather than silently narrow the gate. Targeted mode is for graph/metrics.
	if sub == "validate" && len(targets) > 0 {
		fmt.Fprintln(stderr, "error: validate analyzes the whole graph and does not accept target arguments")
		return exitError
	}

	dir, err := parseDirection(*direction)
	if err != nil {
		fmt.Fprintf(stderr, "error: %v\n", err)
		return exitError
	}

	if *ref != "" {
		// TODO(Task 6): wrap the build below in WithWorktree(*ref, ...) once
		// worktree.go lands. Until then the flag is parsed (so the grammar is
		// stable) but rejected loudly rather than silently ignored.
		fmt.Fprintln(stderr, "error: --ref is not yet supported")
		return exitError
	}

	return execute(runConfig{
		subcommand: sub,
		root:       *root,
		format:     *format,
		direction:  dir,
		targets:    targets,
	}, stdout, stderr)
}

// runConfig is the parsed CLI invocation handed from run to execute. Grouping
// the parsed flags keeps execute's signature stable as flags accrue — Task 6's
// --ref slots in here without growing the parameter list.
type runConfig struct {
	subcommand string
	root       string
	format     string
	direction  Direction
	targets    []string
}

// execute runs the build → metrics → render pipeline for one invocation. The
// subgraph filter (targeted mode) is applied before metrics so complexity is
// measured over the requested slice, per the design's targeted-mode contract.
func execute(cfg runConfig, stdout, stderr io.Writer) int {
	ctx, err := NewParseContext(cfg.root)
	if err != nil {
		fmt.Fprintf(stderr, "error: %v\n", err)
		return exitError
	}
	g, buildDiags, err := BuildGraph(ctx)
	if err != nil {
		fmt.Fprintf(stderr, "error: %v\n", err)
		return exitError
	}

	// --direction only steers the targeted-mode traversal; with no targets it is
	// inert. Warn rather than silently ignore, so a non-default --direction typed
	// without targets surfaces as a mistake instead of a no-op.
	if len(cfg.targets) == 0 && cfg.direction != Forward {
		fmt.Fprintln(stderr, "warning: --direction has no effect without targets")
	}
	if len(cfg.targets) > 0 {
		g, err = subgraph(g, cfg.targets, cfg.direction)
		if err != nil {
			fmt.Fprintf(stderr, "error: %v\n", err)
			return exitError
		}
	}

	m, metricDiags := ComputeMetrics(g, cfg.root, defaultCouplingThreshold)
	// slices.Concat allocates a fresh backing array. Appending metricDiags onto
	// buildDiags directly could reuse buildDiags' array and mutate it under any
	// later reader of that slice.
	diags := slices.Concat(buildDiags, metricDiags)

	// Diagnostics always go to stderr regardless of format. Render additionally
	// embeds them into json/text output per the design's per-format rules; for
	// dot/mermaid stderr is the only channel.
	for _, d := range diags {
		fmt.Fprintln(stderr, "warning: "+d)
	}

	var out []byte
	var findings bool
	if cfg.subcommand == "validate" {
		out, err = renderValidate(cfg.format, m)
		findings = len(m.BrokenEdges) > 0 || len(m.Orphans) > 0
	} else {
		// graph and metrics share Render: output is determined by --format
		// (json=full report, text=metric table, dot/mermaid=visual graph). The
		// subcommands are kept distinct for the CLI contract and to allow future
		// divergence without changing the command surface.
		out, err = Render(cfg.format, g, m, diags)
	}
	if err != nil {
		fmt.Fprintf(stderr, "error: %v\n", err)
		return exitError
	}
	if _, werr := stdout.Write(out); werr != nil {
		fmt.Fprintf(stderr, "error: writing output: %v\n", werr)
		return exitError
	}
	if findings {
		return exitFindings
	}
	return exitOK
}

// subgraph filters g to the targeted-mode slice: each target path is resolved to
// its owning artifact node via NormalizePath, the reachable set is computed per
// direction and unioned across targets, and the graph is narrowed to nodes in
// that set plus edges whose normalized endpoints are both kept. Edges are copied
// with their original (full-graph) normalization intact — re-adding them via
// AddEdge would re-normalize against the smaller node set and corrupt endpoints.
func subgraph(g *Graph, targets []string, dir Direction) (*Graph, error) {
	keep := make(map[string]bool)
	for _, t := range targets {
		start := g.NormalizePath(t)
		if g.NodeByPath(start) == nil {
			return nil, fmt.Errorf("target %q does not resolve to a known node", t)
		}
		for n := range g.Reachable(start, dir) {
			keep[n] = true
		}
	}

	sg := NewGraph()
	for p := range keep {
		if n := g.NodeByPath(p); n != nil {
			sg.AddNode(n)
		}
	}
	for _, e := range g.Edges {
		if keep[e.Source] && keep[e.Target] {
			sg.Edges = append(sg.Edges, e)
		}
	}
	return sg, nil
}

func parseDirection(s string) (Direction, error) {
	switch s {
	case "forward":
		return Forward, nil
	case "reverse":
		return Reverse, nil
	case "both":
		return Both, nil
	default:
		return 0, fmt.Errorf("invalid direction %q (want forward, reverse, or both)", s)
	}
}

func usage(w io.Writer) {
	fmt.Fprint(w, `plugin-graph — analyze the klaude-plugin dependency graph

Usage:
  plugin-graph [global-flags] <subcommand> [subcommand-flags] [target...]

Global flags (before the subcommand):
  --root <path>      plugin root directory (default: klaude-plugin/)
  --ref <git-ref>    analyze a git ref via a temporary worktree (default: working tree)

Subcommands:
  graph              emit the dependency graph (default when none given)
  metrics            compute and emit complexity metrics
  validate           report broken edges and orphans; exit 1 if any are found

Subcommand flags (after the subcommand):
  --format <fmt>     json, text, dot, or mermaid (default: text)
  --direction <dir>  targeted-mode traversal: forward, reverse, or both (default: forward)

Targets, given after the subcommand flags, restrict output to the subgraph
reachable from those artifact paths (graph and metrics only; validate analyzes
the whole graph and rejects targets).
`)
}
