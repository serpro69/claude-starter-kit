package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLocalFetcher_ReadsFromBaseDir(t *testing.T) {
	dir := t.TempDir()
	subdir := filepath.Join(dir, "skills", "golang-security")
	if err := os.MkdirAll(subdir, 0o755); err != nil {
		t.Fatal(err)
	}
	content := []byte("# Security\n\nSome content here.\n")
	if err := os.WriteFile(filepath.Join(subdir, "SKILL.md"), content, 0o644); err != nil {
		t.Fatal(err)
	}

	fetcher := &LocalFetcher{BaseDir: dir}
	got, err := fetcher.Fetch("samber/cc-skills-golang", "v1.1.3", "skills/golang-security/SKILL.md")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !bytes.Equal(got, content) {
		t.Errorf("content mismatch:\ngot:  %q\nwant: %q", got, content)
	}
}

func TestLocalFetcher_IgnoresRepoAndRef(t *testing.T) {
	dir := t.TempDir()
	content := []byte("hello")
	if err := os.WriteFile(filepath.Join(dir, "file.md"), content, 0o644); err != nil {
		t.Fatal(err)
	}

	fetcher := &LocalFetcher{BaseDir: dir}

	got1, err := fetcher.Fetch("repo-a", "v1", "file.md")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	got2, err := fetcher.Fetch("repo-b", "v2", "file.md")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !bytes.Equal(got1, got2) {
		t.Error("expected same content regardless of repo/ref")
	}
}

func TestLocalFetcher_FileNotFound(t *testing.T) {
	dir := t.TempDir()
	fetcher := &LocalFetcher{BaseDir: dir}

	_, err := fetcher.Fetch("repo", "ref", "nonexistent.md")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !strings.Contains(err.Error(), "reading local file") {
		t.Errorf("error = %q, want containing %q", err, "reading local file")
	}
}

func TestHTTPFetcher_ImplementsFetcher(t *testing.T) {
	var _ Fetcher = &HTTPFetcher{}
}

func TestLocalFetcher_ImplementsFetcher(t *testing.T) {
	var _ Fetcher = &LocalFetcher{}
}
