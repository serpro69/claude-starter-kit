.ONESHELL:
.SHELL      := $(shell which bash)
.SHELLFLAGS := -ec

.PHONY: vendor-profiles generate-kodex generate-all test-structure

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
