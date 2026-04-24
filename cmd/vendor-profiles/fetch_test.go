package main

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

var _ Fetcher = (*LocalFetcher)(nil)

type LocalFetcher struct {
	BaseDir string
}

func (f *LocalFetcher) Fetch(repo, ref, source string) ([]byte, error) {
	p := filepath.Join(f.BaseDir, source)
	data, err := os.ReadFile(p)
	if err != nil {
		return nil, fmt.Errorf("reading local file %s: %w", p, err)
	}
	return data, nil
}

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
	if !bytes.Equal(got1, content) {
		t.Errorf("content mismatch: got %q, want %q", got1, content)
	}
}

func TestLocalFetcher_FileNotFound(t *testing.T) {
	dir := t.TempDir()
	fetcher := &LocalFetcher{BaseDir: dir}

	_, err := fetcher.Fetch("repo", "ref", "nonexistent.md")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	var pathErr *os.PathError
	if !errors.As(err, &pathErr) {
		t.Errorf("expected *os.PathError, got %T: %v", err, err)
	}
}
