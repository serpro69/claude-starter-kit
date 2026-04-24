package main

import (
	"bytes"
	"fmt"
	"strings"
)

func ApplyTransform(content []byte, keep any) ([]byte, error) {
	switch v := keep.(type) {
	case string:
		switch v {
		case keepAll:
			return TransformAll(content), nil
		case keepFromFirstH1:
			return TransformFromFirstH1(content)
		default:
			return nil, fmt.Errorf("unknown keep mode: %q", v)
		}
	case map[string]any:
		headings, ok := v["headings"]
		if !ok {
			return nil, fmt.Errorf("keep object missing 'headings' key")
		}
		list, ok := headings.([]any)
		if !ok {
			return nil, fmt.Errorf("headings must be a list of strings")
		}
		var names []string
		for _, h := range list {
			s, ok := h.(string)
			if !ok {
				return nil, fmt.Errorf("heading must be a string, got %T", h)
			}
			names = append(names, s)
		}
		return TransformHeadings(content, names)
	default:
		return nil, fmt.Errorf("unsupported keep type: %T", keep)
	}
}

func TransformAll(content []byte) []byte {
	return content
}

func TransformFromFirstH1(content []byte) ([]byte, error) {
	if len(bytes.TrimSpace(content)) == 0 {
		return nil, fmt.Errorf("empty content: no H1 found")
	}

	lines := strings.Split(string(content), "\n")
	for i, line := range lines {
		if strings.HasPrefix(line, "# ") {
			return []byte(strings.Join(lines[i:], "\n")), nil
		}
	}
	return nil, fmt.Errorf("no H1 heading found")
}

func TransformHeadings(content []byte, headings []string) ([]byte, error) {
	lines := strings.Split(string(content), "\n")
	var sections []string

	for _, target := range headings {
		found := false
		for i, line := range lines {
			if strings.TrimSpace(line) == target {
				found = true
				var section []string
				section = append(section, line)
				for j := i + 1; j < len(lines); j++ {
					if strings.HasPrefix(lines[j], "## ") || strings.HasPrefix(lines[j], "# ") {
						break
					}
					section = append(section, lines[j])
				}
				sections = append(sections, strings.Join(section, "\n"))
				break
			}
		}
		if !found {
			return nil, fmt.Errorf("heading not found: %q", target)
		}
	}

	return []byte(strings.Join(sections, "\n\n")), nil
}
