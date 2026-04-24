package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("creating directory for %s: %v", path, err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("writing %s: %v", path, err)
	}
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("reading %s: %v", path, err)
	}
	return string(data)
}

func TestUpdateIndex_NewFile(t *testing.T) {
	dir := t.TempDir()
	phase := "implement"

	phaseDir := filepath.Join(dir, phase)
	if err := os.MkdirAll(phaseDir, 0o755); err != nil {
		t.Fatalf("creating phase dir: %v", err)
	}

	writeFile(t, filepath.Join(phaseDir, "design-patterns.md"), "# Design Patterns\n\nApply common Go design patterns.\n")
	writeFile(t, filepath.Join(phaseDir, "concurrency.md"), "# Concurrency\n\nGoroutine lifecycle and sync primitives.\n")

	files := []phaseFile{
		{As: "design-patterns.md", Condition: "", ContentPath: filepath.Join(phaseDir, "design-patterns.md")},
		{As: "concurrency.md", Condition: "Diff uses goroutines, channels, or sync package", ContentPath: filepath.Join(phaseDir, "concurrency.md")},
	}

	if err := UpdateIndex(dir, phase, files); err != nil {
		t.Fatalf("UpdateIndex: %v", err)
	}

	got := readFile(t, filepath.Join(phaseDir, "index.md"))

	if !strings.Contains(got, "# Go — implement checklists") {
		t.Error("missing phase heading")
	}
	if !strings.Contains(got, beginMarker) {
		t.Error("missing BEGIN marker")
	}
	if !strings.Contains(got, endMarker) {
		t.Error("missing END marker")
	}
	if !strings.Contains(got, "[design-patterns.md](design-patterns.md)") {
		t.Error("missing always-load entry")
	}
	if !strings.Contains(got, "[concurrency.md](concurrency.md)") {
		t.Error("missing conditional entry")
	}
	if !strings.Contains(got, "**Load if:**") {
		t.Error("missing Load if clause for conditional entry")
	}
}

func TestUpdateIndex_ExistingWithMarkers_ReplacesVendoredPreservesHandWritten(t *testing.T) {
	dir := t.TempDir()
	phase := "review-code"

	phaseDir := filepath.Join(dir, phase)
	if err := os.MkdirAll(phaseDir, 0o755); err != nil {
		t.Fatalf("creating phase dir: %v", err)
	}

	existing := "# Go — review checklists\n\n" +
		"## Always load\n\n" +
		"- [solid-checklist.md](solid-checklist.md) — SOLID principles.\n\n" +
		beginMarker + "\n" +
		"- [old-entry.md](old-entry.md) — Old vendored content.\n" +
		endMarker + "\n\n" +
		"Some trailing content.\n"
	writeFile(t, filepath.Join(phaseDir, "index.md"), existing)

	writeFile(t, filepath.Join(phaseDir, "security.md"), "# Security\n\nGo security: injection, crypto, secrets.\n")

	files := []phaseFile{
		{As: "security.md", Condition: "", ContentPath: filepath.Join(phaseDir, "security.md")},
	}

	if err := UpdateIndex(dir, phase, files); err != nil {
		t.Fatalf("UpdateIndex: %v", err)
	}

	got := readFile(t, filepath.Join(phaseDir, "index.md"))

	if !strings.Contains(got, "- [solid-checklist.md](solid-checklist.md) — SOLID principles.") {
		t.Error("hand-written content before markers was lost")
	}
	if !strings.Contains(got, "Some trailing content.") {
		t.Error("content after END marker was lost")
	}
	if strings.Contains(got, "old-entry.md") {
		t.Error("old vendored content was not replaced")
	}
	if !strings.Contains(got, "[security.md](security.md)") {
		t.Error("new vendored entry missing")
	}
}

func TestUpdateIndex_ExistingWithoutMarkers_AppendsMarkers(t *testing.T) {
	dir := t.TempDir()
	phase := "review-code"

	phaseDir := filepath.Join(dir, phase)
	if err := os.MkdirAll(phaseDir, 0o755); err != nil {
		t.Fatalf("creating phase dir: %v", err)
	}

	existing := "# Go — review checklists\n\n## Always load\n\n- [solid-checklist.md](solid-checklist.md) — SOLID.\n"
	writeFile(t, filepath.Join(phaseDir, "index.md"), existing)

	writeFile(t, filepath.Join(phaseDir, "security.md"), "# Security\n\nInjection prevention and crypto.\n")

	files := []phaseFile{
		{As: "security.md", Condition: "", ContentPath: filepath.Join(phaseDir, "security.md")},
	}

	if err := UpdateIndex(dir, phase, files); err != nil {
		t.Fatalf("UpdateIndex: %v", err)
	}

	got := readFile(t, filepath.Join(phaseDir, "index.md"))

	if !strings.HasPrefix(got, "# Go — review checklists") {
		t.Error("original content was not preserved at start")
	}
	if !strings.Contains(got, beginMarker) {
		t.Error("BEGIN marker not appended")
	}
	if !strings.Contains(got, endMarker) {
		t.Error("END marker not appended")
	}
	if !strings.Contains(got, "[security.md](security.md)") {
		t.Error("vendored entry missing")
	}

	beginIdx := strings.Index(got, beginMarker)
	solidIdx := strings.Index(got, "solid-checklist.md")
	if solidIdx > beginIdx {
		t.Error("hand-written content should appear before markers")
	}
}

func TestUpdateIndex_AlwaysLoadAndConditionalFormatting(t *testing.T) {
	dir := t.TempDir()
	phase := "review-code"

	phaseDir := filepath.Join(dir, phase)
	if err := os.MkdirAll(phaseDir, 0o755); err != nil {
		t.Fatalf("creating phase dir: %v", err)
	}

	writeFile(t, filepath.Join(phaseDir, "security.md"), "# Security\n\nGo security checklist.\n")
	writeFile(t, filepath.Join(phaseDir, "database.md"), "# Database\n\nDatabase patterns and SQL safety.\n")

	files := []phaseFile{
		{As: "security.md", Condition: "", ContentPath: filepath.Join(phaseDir, "security.md")},
		{As: "database.md", Condition: "Diff imports database/sql, sqlx, gorm, ent, or pgx", ContentPath: filepath.Join(phaseDir, "database.md")},
	}

	if err := UpdateIndex(dir, phase, files); err != nil {
		t.Fatalf("UpdateIndex: %v", err)
	}

	got := readFile(t, filepath.Join(phaseDir, "index.md"))

	if !strings.Contains(got, "## Always load") {
		t.Error("missing Always load heading")
	}
	if !strings.Contains(got, "## Conditional") {
		t.Error("missing Conditional heading")
	}

	alwaysIdx := strings.Index(got, "## Always load")
	condIdx := strings.Index(got, "## Conditional")
	if alwaysIdx > condIdx {
		t.Error("Always load should appear before Conditional")
	}

	securityIdx := strings.Index(got, "[security.md]")
	if securityIdx < alwaysIdx || securityIdx > condIdx {
		t.Error("always-load entry should be between Always load heading and Conditional heading")
	}

	dbIdx := strings.Index(got, "[database.md]")
	if dbIdx < condIdx {
		t.Error("conditional entry should appear after Conditional heading")
	}
	if !strings.Contains(got, "**Load if:** Diff imports database/sql") {
		t.Error("conditional entry missing Load if clause")
	}
}

func TestUpdateIndex_OnlyAlwaysLoad_OmitsConditionalHeading(t *testing.T) {
	dir := t.TempDir()
	phase := "implement"

	phaseDir := filepath.Join(dir, phase)
	if err := os.MkdirAll(phaseDir, 0o755); err != nil {
		t.Fatalf("creating phase dir: %v", err)
	}

	writeFile(t, filepath.Join(phaseDir, "patterns.md"), "# Patterns\n\nDesign patterns for Go.\n")

	files := []phaseFile{
		{As: "patterns.md", Condition: "", ContentPath: filepath.Join(phaseDir, "patterns.md")},
	}

	if err := UpdateIndex(dir, phase, files); err != nil {
		t.Fatalf("UpdateIndex: %v", err)
	}

	got := readFile(t, filepath.Join(phaseDir, "index.md"))

	if !strings.Contains(got, "## Always load") {
		t.Error("missing Always load heading")
	}
	if strings.Contains(got, "## Conditional") {
		t.Error("Conditional heading should be omitted when no conditional entries exist")
	}
}

func TestUpdateIndex_OnlyConditional_OmitsAlwaysLoadHeading(t *testing.T) {
	dir := t.TempDir()
	phase := "design"

	phaseDir := filepath.Join(dir, phase)
	if err := os.MkdirAll(phaseDir, 0o755); err != nil {
		t.Fatalf("creating phase dir: %v", err)
	}

	writeFile(t, filepath.Join(phaseDir, "database.md"), "# Database\n\nDatabase design patterns.\n")

	files := []phaseFile{
		{As: "database.md", Condition: "Diff imports database/sql", ContentPath: filepath.Join(phaseDir, "database.md")},
	}

	if err := UpdateIndex(dir, phase, files); err != nil {
		t.Fatalf("UpdateIndex: %v", err)
	}

	got := readFile(t, filepath.Join(phaseDir, "index.md"))

	if strings.Contains(got, "## Always load") {
		t.Error("Always load heading should be omitted when no always-load entries exist")
	}
	if !strings.Contains(got, "## Conditional") {
		t.Error("missing Conditional heading")
	}
}

func TestUpdateIndex_Idempotent(t *testing.T) {
	dir := t.TempDir()
	phase := "implement"

	phaseDir := filepath.Join(dir, phase)
	if err := os.MkdirAll(phaseDir, 0o755); err != nil {
		t.Fatalf("creating phase dir: %v", err)
	}

	writeFile(t, filepath.Join(phaseDir, "patterns.md"), "# Patterns\n\nDesign patterns.\n")
	writeFile(t, filepath.Join(phaseDir, "db.md"), "# Database\n\nDB patterns.\n")

	files := []phaseFile{
		{As: "patterns.md", Condition: "", ContentPath: filepath.Join(phaseDir, "patterns.md")},
		{As: "db.md", Condition: "Diff imports database/sql", ContentPath: filepath.Join(phaseDir, "db.md")},
	}

	if err := UpdateIndex(dir, phase, files); err != nil {
		t.Fatalf("first UpdateIndex: %v", err)
	}
	first := readFile(t, filepath.Join(phaseDir, "index.md"))

	if err := UpdateIndex(dir, phase, files); err != nil {
		t.Fatalf("second UpdateIndex: %v", err)
	}
	second := readFile(t, filepath.Join(phaseDir, "index.md"))

	if first != second {
		t.Errorf("UpdateIndex is not idempotent.\nFirst:\n%s\nSecond:\n%s", first, second)
	}
}

func TestExtractDescription_FirstContentLine(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.md")
	writeFile(t, path, "# Title\n\nThis is the first real content line.\n\nMore content.\n")

	got := extractDescription(path, "test.md")
	if got != "This is the first real content line." {
		t.Errorf("got %q, want first non-heading non-empty line", got)
	}
}

func TestExtractDescription_SkipsHeadings(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.md")
	writeFile(t, path, "# Title\n\n## Subtitle\n\nActual content here.\n")

	got := extractDescription(path, "test.md")
	if got != "Actual content here." {
		t.Errorf("got %q, want %q", got, "Actual content here.")
	}
}

func TestExtractDescription_TruncatesTo120Chars(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.md")
	long := strings.Repeat("x", 200)
	writeFile(t, path, "# Title\n\n"+long+"\n")

	got := extractDescription(path, "test.md")
	if len(got) != 120 {
		t.Errorf("description length = %d, want 120", len(got))
	}
}

func TestExtractDescription_FallbackWhenFileNotFound(t *testing.T) {
	got := extractDescription("/nonexistent/path/file.md", "security.md")
	if got != "security" {
		t.Errorf("got %q, want %q", got, "security")
	}
}

func TestExtractDescription_FallbackWhenOnlyHeadings(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.md")
	writeFile(t, path, "# Title\n\n## Section\n\n### Subsection\n")

	got := extractDescription(path, "empty-content.md")
	if got != "empty-content" {
		t.Errorf("got %q, want %q (fallback to filename sans extension)", got, "empty-content")
	}
}
