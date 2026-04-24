package main

import (
	"fmt"
	"os"
	"strings"
)

const (
	beginMarker = "<!-- BEGIN VENDORED -->"
	endMarker   = "<!-- END VENDORED -->"
)

func UpdateIndex(targetDir, phase string, files []phaseFile) error {
	indexPath := fmt.Sprintf("%s/%s/index.md", targetDir, phase)

	existing, err := os.ReadFile(indexPath)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("reading index: %w", err)
	}

	vendored := generateVendoredSection(files)

	var output string
	if err != nil {
		output = fmt.Sprintf("# Go — %s checklists\n\n%s\n%s\n%s\n", phase, beginMarker, vendored, endMarker)
	} else {
		content := string(existing)
		beginIdx := strings.Index(content, beginMarker)
		endIdx := strings.Index(content, endMarker)
		if beginIdx >= 0 && endIdx >= 0 {
			output = content[:beginIdx+len(beginMarker)] + "\n" + vendored + content[endIdx:]
		} else {
			output = content + "\n" + beginMarker + "\n" + vendored + endMarker + "\n"
		}
	}

	return os.WriteFile(indexPath, []byte(output), 0o644)
}

func generateVendoredSection(files []phaseFile) string {
	var alwaysLoad, conditional []string

	for _, f := range files {
		desc := extractDescription(f.ContentPath, f.As)
		if f.Condition == "" {
			alwaysLoad = append(alwaysLoad, fmt.Sprintf("- [%s](%s) — %s", f.As, f.As, desc))
		} else {
			conditional = append(conditional, fmt.Sprintf("- [%s](%s) — %s **Load if:** %s", f.As, f.As, desc, f.Condition))
		}
	}

	var parts []string
	if len(alwaysLoad) > 0 {
		parts = append(parts, "## Always load\n")
		parts = append(parts, strings.Join(alwaysLoad, "\n"))
	}
	if len(conditional) > 0 {
		if len(alwaysLoad) > 0 {
			parts = append(parts, "")
		}
		parts = append(parts, "## Conditional\n")
		parts = append(parts, strings.Join(conditional, "\n"))
	}

	return strings.Join(parts, "\n") + "\n"
}

func extractDescription(contentPath, fallbackName string) string {
	data, err := os.ReadFile(contentPath)
	if err != nil {
		return strings.TrimSuffix(fallbackName, ".md")
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		if len(trimmed) > 120 {
			return trimmed[:120]
		}
		return trimmed
	}

	return strings.TrimSuffix(fallbackName, ".md")
}
