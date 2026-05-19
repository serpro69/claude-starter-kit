package main

import (
	"fmt"
	"strings"
)

func ApplyTransforms(content []byte, transforms []TransformConfig) ([]byte, error) {
	result := content
	for _, t := range transforms {
		switch t.Type {
		case "plugin_root_resolve":
			result = applyPluginRootResolve(result, t.ReplacementBase)
		case "inject_header":
			result = applyInjectHeader(result, t.Content)
		case "plugin_root_placeholder":
			result = applyPluginRootPlaceholder(result, t.Placeholder, t.Preamble)
		case "skill_prefix_rewrite":
			result = applySkillPrefixRewrite(result, t.From, t.To)
		default:
			return nil, fmt.Errorf("unknown transform type %q", t.Type)
		}
	}
	return result, nil
}

func applyPluginRootResolve(content []byte, replacementBase string) []byte {
	s := string(content)
	s = strings.ReplaceAll(s, "${CLAUDE_PLUGIN_ROOT}", replacementBase)
	return []byte(s)
}

func applyPluginRootPlaceholder(content []byte, placeholder, preamble string) []byte {
	s := string(content)
	s = strings.ReplaceAll(s, "${CLAUDE_PLUGIN_ROOT}", placeholder)
	if preamble != "" {
		s = preamble + "\n" + s
	}
	return []byte(s)
}

func applySkillPrefixRewrite(content []byte, from, to string) []byte {
	s := string(content)
	s = strings.ReplaceAll(s, from, to)
	return []byte(s)
}

func applyInjectHeader(content []byte, header string) []byte {
	s := string(content)

	// Inject after frontmatter if present, otherwise at the top.
	if strings.HasPrefix(s, "---\n") {
		end := strings.Index(s[4:], "\n---\n")
		if end >= 0 {
			insertPos := 4 + end + 5 // past closing "---\n"
			return []byte(s[:insertPos] + header + s[insertPos:])
		}
	}

	return []byte(header + s)
}
