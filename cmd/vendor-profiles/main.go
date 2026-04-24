package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	manifestPath := flag.String("manifest", "", "path to the vendor manifest YAML file (required)")
	targetDir := flag.String("target", "profiles/go", "profile root directory for output")
	dryRun := flag.Bool("dry-run", false, "print planned actions without writing files")
	flag.Parse()

	if *manifestPath == "" {
		fmt.Fprintln(os.Stderr, "error: -manifest is required")
		flag.Usage()
		os.Exit(1)
	}

	if err := run(*manifestPath, *targetDir, *dryRun, &HTTPFetcher{}); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run(manifestPath, targetDir string, dryRun bool, fetcher Fetcher) error {
	manifest, err := ParseManifest(manifestPath)
	if err != nil {
		return fmt.Errorf("parsing manifest: %w", err)
	}

	for _, upstream := range manifest {
		for _, file := range upstream.Files {
			file.ResolveKeep(upstream.KeepDefault)
		}

		for _, file := range upstream.Files {
			content, err := fetcher.Fetch(upstream.Repo, upstream.Ref, file.Source)
			if err != nil {
				return fmt.Errorf("fetching %s: %w", file.Source, err)
			}

			transformed, err := ApplyTransform(content, file.EffectiveKeep)
			if err != nil {
				return fmt.Errorf("transforming %s: %w", file.Source, err)
			}

			transformed = RewriteLinks(transformed, file.Source, file.Phase, upstream.Files)

			outPath := fmt.Sprintf("%s/%s/%s", targetDir, file.Phase, file.As)

			if dryRun {
				fmt.Printf("[dry-run] %s/%s/%s → %s\n", upstream.Repo, upstream.Ref, file.Source, outPath)
				continue
			}

			if err := os.MkdirAll(fmt.Sprintf("%s/%s", targetDir, file.Phase), 0o755); err != nil {
				return fmt.Errorf("creating directory: %w", err)
			}
			if err := os.WriteFile(outPath, transformed, 0o644); err != nil {
				return fmt.Errorf("writing %s: %w", outPath, err)
			}
			fmt.Printf("wrote %s\n", outPath)
		}
	}

	if dryRun {
		return nil
	}

	phases := collectPhases(manifest, targetDir)
	for phase, files := range phases {
		if err := UpdateIndex(targetDir, phase, files); err != nil {
			return fmt.Errorf("updating index for %s: %w", phase, err)
		}
	}

	return nil
}

type phaseFile struct {
	As          string
	Condition   string
	ContentPath string
}

func collectPhases(manifest Manifest, targetDir string) map[string][]phaseFile {
	phases := make(map[string][]phaseFile)
	for _, upstream := range manifest {
		for _, file := range upstream.Files {
			phases[file.Phase] = append(phases[file.Phase], phaseFile{
				As:          file.As,
				Condition:   file.Condition,
				ContentPath: fmt.Sprintf("%s/%s/%s", targetDir, file.Phase, file.As),
			})
		}
	}
	return phases
}
