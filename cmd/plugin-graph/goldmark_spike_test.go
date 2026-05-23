// TODO(Task 2): delete this spike — superseded by link extractor tests.
// Also: the production extractor should handle nested inline formatting
// (emphasis, code spans) inside link text, not just plain ast.Text children.
package main

import (
	"bytes"
	"testing"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/text"
)

// lineNumber converts a byte offset in source to a 1-based line number.
func lineNumber(source []byte, offset int) int {
	return bytes.Count(source[:offset], []byte("\n")) + 1
}

func TestGoldmarkSpike(t *testing.T) {
	source := []byte(`# Heading

An [inline link](target.md) in a paragraph.

A [second link](other/path.md) on line 4.

Some ` + "`backtick content`" + ` that is not a link.

[reference-style link][ref1]

` + "```" + `
[link inside code block](should-be-ignored.md)
` + "```" + `

A [link after code block](after-code.md).

[ref1]: reference-target.md
`)

	md := goldmark.New()
	reader := text.NewReader(source)
	doc := md.Parser().Parse(reader)

	type linkInfo struct {
		destination string
		line        int
	}

	var links []linkInfo

	ast.Walk(doc, func(n ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			return ast.WalkContinue, nil
		}
		link, ok := n.(*ast.Link)
		if !ok {
			return ast.WalkContinue, nil
		}

		dest := string(link.Destination)

		// Derive line number from the link's position in source.
		// Inline nodes don't have Lines() directly; we use the
		// text segment of the first child (the link text) to find
		// the byte offset, then convert to line number.
		line := 0
		if fc := link.FirstChild(); fc != nil {
			if tn, ok := fc.(*ast.Text); ok {
				seg := tn.Segment
				line = lineNumber(source, seg.Start)
			}
		}

		links = append(links, linkInfo{destination: dest, line: line})
		return ast.WalkContinue, nil
	})

	// Expected links (goldmark should NOT produce links for code-block or backtick content)
	expected := []linkInfo{
		{"target.md", 3},
		{"other/path.md", 5},
		{"reference-target.md", 9},
		{"after-code.md", 15},
	}

	if len(links) != len(expected) {
		t.Fatalf("expected %d links, got %d: %+v", len(expected), len(links), links)
	}

	for i, want := range expected {
		got := links[i]
		if got.destination != want.destination {
			t.Errorf("link[%d] destination: got %q, want %q", i, got.destination, want.destination)
		}
		if got.line != want.line {
			t.Errorf("link[%d] line: got %d, want %d (destination: %s)", i, got.line, want.line, got.destination)
		}
	}
}

func TestGoldmarkSpike_LineNumberPrecision(t *testing.T) {
	// Verify line numbers are precise even with multi-line content
	source := []byte(`Line 1
Line 2
[link-on-3](three.md)
Line 4
Line 5
[link-on-6](six.md)
Line 7
[link-on-8](eight.md)
`)

	md := goldmark.New()
	doc := md.Parser().Parse(text.NewReader(source))

	type result struct {
		dest string
		line int
	}

	var results []result
	ast.Walk(doc, func(n ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			return ast.WalkContinue, nil
		}
		link, ok := n.(*ast.Link)
		if !ok {
			return ast.WalkContinue, nil
		}
		line := 0
		if fc := link.FirstChild(); fc != nil {
			if tn, ok := fc.(*ast.Text); ok {
				line = lineNumber(source, tn.Segment.Start)
			}
		}
		results = append(results, result{string(link.Destination), line})
		return ast.WalkContinue, nil
	})

	expected := []result{
		{"three.md", 3},
		{"six.md", 6},
		{"eight.md", 8},
	}

	if len(results) != len(expected) {
		t.Fatalf("expected %d links, got %d: %+v", len(expected), len(results), results)
	}

	for i, want := range expected {
		got := results[i]
		if got.dest != want.dest {
			t.Errorf("link[%d] dest: got %q, want %q", i, got.dest, want.dest)
		}
		if got.line != want.line {
			t.Errorf("link[%d] line: got %d, want %d", i, got.line, want.line)
		}
	}
}
