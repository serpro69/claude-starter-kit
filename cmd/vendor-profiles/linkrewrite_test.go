package main

import (
	"strings"
	"testing"
)

func testFiles() []*File {
	return []*File{
		{Source: "skills/golang-security/SKILL.md", Phase: "review-code", As: "security.md"},
		{Source: "skills/golang-security/references/injection.md", Phase: "review-code", As: "security-injection-ref.md"},
		{Source: "skills/golang-naming/SKILL.md", Phase: "review-code", As: "naming.md"},
		{Source: "skills/golang-security/SKILL.md", Phase: "implement", As: "security.md"},
	}
}

func TestRewriteLinks_ExternalURLPreserved(t *testing.T) {
	input := []byte(`See [Go docs](https://pkg.go.dev/net/http) and [RFC](http://example.com/rfc).`)
	got := RewriteLinks(input, "skills/golang-security/SKILL.md", "review-code", testFiles())
	result := string(got)
	if !strings.Contains(result, "](https://pkg.go.dev/net/http)") {
		t.Error("HTTPS link was modified")
	}
	if !strings.Contains(result, "](http://example.com/rfc)") {
		t.Error("HTTP link was modified")
	}
}

func TestRewriteLinks_CoVendoredRewrite(t *testing.T) {
	input := []byte(`See [injection details](references/injection.md) for more.`)
	got := RewriteLinks(input, "skills/golang-security/SKILL.md", "review-code", testFiles())
	result := string(got)
	if !strings.Contains(result, "[injection details](security-injection-ref.md)") {
		t.Errorf("co-vendored link not rewritten, got: %s", result)
	}
}

func TestRewriteLinks_CoVendoredSamePhaseOnly(t *testing.T) {
	input := []byte(`See [injection details](references/injection.md) for more.`)
	// injection.md is only vendored into review-code, not implement
	got := RewriteLinks(input, "skills/golang-security/SKILL.md", "implement", testFiles())
	result := string(got)
	if strings.Contains(result, "](security-injection-ref.md)") {
		t.Error("link was rewritten to a file in a different phase")
	}
	if !strings.Contains(result, "injection details") {
		t.Error("display text was lost")
	}
	if strings.Contains(result, "[injection details]") {
		t.Error("link brackets should be removed when stripping")
	}
}

func TestRewriteLinks_CrossSkillRefStripped(t *testing.T) {
	input := []byte(`Also see [golang-naming](samber/cc-skills-golang@golang-naming) for naming rules.`)
	got := RewriteLinks(input, "skills/golang-security/SKILL.md", "review-code", testFiles())
	result := string(got)
	if strings.Contains(result, "](") {
		t.Errorf("cross-skill link not stripped, got: %s", result)
	}
	if !strings.Contains(result, "golang-naming") {
		t.Error("display text was lost")
	}
}

func TestRewriteLinks_NonVendoredStripped(t *testing.T) {
	input := []byte(`See [crypto details](references/crypto.md) for more.`)
	got := RewriteLinks(input, "skills/golang-security/SKILL.md", "review-code", testFiles())
	result := string(got)
	if strings.Contains(result, "](") {
		t.Errorf("non-vendored link not stripped, got: %s", result)
	}
	if !strings.Contains(result, "crypto details") {
		t.Error("display text was lost")
	}
}

func TestRewriteLinks_FragmentPreserved(t *testing.T) {
	input := []byte(`See [SQL injection](references/injection.md#sql-injection) section.`)
	got := RewriteLinks(input, "skills/golang-security/SKILL.md", "review-code", testFiles())
	result := string(got)
	if !strings.Contains(result, "[SQL injection](security-injection-ref.md#sql-injection)") {
		t.Errorf("fragment not preserved in rewritten link, got: %s", result)
	}
}

func TestRewriteLinks_FragmentStrippedWhenNotCoVendored(t *testing.T) {
	input := []byte(`See [crypto](references/crypto.md#aes) section.`)
	got := RewriteLinks(input, "skills/golang-security/SKILL.md", "review-code", testFiles())
	result := string(got)
	if strings.Contains(result, "](") {
		t.Errorf("non-vendored link with fragment not stripped, got: %s", result)
	}
	if !strings.Contains(result, "crypto") {
		t.Error("display text was lost")
	}
}

func TestRewriteLinks_MultipleLinksInOneLine(t *testing.T) {
	input := []byte(`See [injection](references/injection.md) and [Go docs](https://pkg.go.dev) and [crypto](references/crypto.md).`)
	got := RewriteLinks(input, "skills/golang-security/SKILL.md", "review-code", testFiles())
	result := string(got)
	if !strings.Contains(result, "[injection](security-injection-ref.md)") {
		t.Errorf("co-vendored link not rewritten, got: %s", result)
	}
	if !strings.Contains(result, "[Go docs](https://pkg.go.dev)") {
		t.Errorf("external link modified, got: %s", result)
	}
	if strings.Contains(result, "[crypto]") {
		t.Errorf("non-vendored link not stripped, got: %s", result)
	}
	if !strings.Contains(result, "crypto") {
		t.Error("display text was lost for non-vendored link")
	}
}

func TestRewriteLinks_NoLinksUnchanged(t *testing.T) {
	input := []byte("No links here, just plain text.\n\nAnother paragraph.")
	got := RewriteLinks(input, "skills/golang-security/SKILL.md", "review-code", testFiles())
	if string(got) != string(input) {
		t.Errorf("content without links was modified: got %q", got)
	}
}

func TestRewriteLinks_CrossSkillRelativePathRewrittenWhenCoVendored(t *testing.T) {
	input := []byte(`See [naming conventions](../golang-naming/SKILL.md) for details.`)
	got := RewriteLinks(input, "skills/golang-security/SKILL.md", "review-code", testFiles())
	result := string(got)
	// ../golang-naming/SKILL.md resolves to skills/golang-naming/SKILL.md which IS in files
	// but the source file (golang-security/SKILL.md) is different from the resolved target,
	// so this would match only if source+phase match — here naming.md IS in review-code
	// This actually IS a co-vendored file in the same phase, so it should rewrite
	if !strings.Contains(result, "[naming conventions](naming.md)") {
		t.Errorf("cross-skill link to co-vendored file not rewritten, got: %s", result)
	}
}

func TestRewriteLinks_EmptyContent(t *testing.T) {
	got := RewriteLinks([]byte{}, "skills/golang-security/SKILL.md", "review-code", testFiles())
	if len(got) != 0 {
		t.Errorf("empty content produced output: %q", got)
	}
}
