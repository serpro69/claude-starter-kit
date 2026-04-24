package main

import (
	"path"
	"regexp"
	"strings"
)

var linkRegex = regexp.MustCompile(`\[([^\]]+)\]\(([^)]+)\)`)

func RewriteLinks(content []byte, sourceFile, sourcePhase string, files []*File) []byte {
	sourceDir := path.Dir(sourceFile)

	result := linkRegex.ReplaceAllStringFunc(string(content), func(match string) string {
		parts := linkRegex.FindStringSubmatch(match)
		if len(parts) != 3 {
			return match
		}
		displayText := parts[1]
		target := parts[2]

		if strings.HasPrefix(target, "http://") || strings.HasPrefix(target, "https://") {
			return match
		}

		targetPath, fragment, _ := strings.Cut(target, "#")
		resolved := path.Clean(path.Join(sourceDir, targetPath))

		for _, f := range files {
			if f.Source == resolved && f.Phase == sourcePhase {
				rewritten := f.As
				if fragment != "" {
					rewritten += "#" + fragment
				}
				return "[" + displayText + "](" + rewritten + ")"
			}
		}

		return displayText
	})

	return []byte(result)
}
