.ONESHELL:
.SHELL      := $(shell which bash)
.SHELLFLAGS := -ec

.PHONY: vendor-profiles generate-kodex generate-all test-structure plugin-graph docs-serve docs-build

vendor-profiles:
	go test ./cmd/vendor-profiles/...
	go run ./cmd/vendor-profiles -manifest scripts/go-vendor-manifest.yml
	$(MAKE) test-structure

generate-kodex:
	go test ./cmd/generate-kodex/...
	go run ./cmd/generate-kodex -manifest scripts/kodex-generate-manifest.yml
	$(MAKE) test-structure

generate-all: vendor-profiles generate-kodex

test-structure:
	bash test/test-plugin-structure.sh
	bash test/test-codex-structure.sh

plugin-graph:
	go test ./cmd/plugin-graph/...
	go run ./cmd/plugin-graph --root klaude-plugin/ validate

docs-serve:
	MKDOCS_SITE_URL=http://localhost:8000 mkdocs serve

docs-build:
	MKDOCS_SITE_URL=https://serpro69.github.io/claude-toolbox/ mkdocs build
