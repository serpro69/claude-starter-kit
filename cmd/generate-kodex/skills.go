package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

func GenerateSkills(m *Manifest, dryRun bool) error {
	sourceSkills := filepath.Join(m.SourcePlugin, "skills")
	targetSkills := filepath.Join(m.TargetPlugin, "skills")

	excludes := make(map[string]bool)
	for _, o := range m.Skills.Overrides {
		if o.Exclude {
			excludes[o.Name] = true
		}
	}

	entries, err := os.ReadDir(sourceSkills)
	if err != nil {
		return fmt.Errorf("reading skills directory: %w", err)
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		name := entry.Name()

		if name == "_shared" {
			continue
		}
		if excludes[name] {
			continue
		}

		srcDir := filepath.Join(sourceSkills, name)
		dstDir := filepath.Join(targetSkills, name)

		if dryRun {
			fmt.Printf("[dry-run] copy skill %s → %s\n", srcDir, dstDir)
			continue
		}

		if err := copySkillDir(srcDir, dstDir, m.Skills.Transforms); err != nil {
			return fmt.Errorf("copying skill %s: %w", name, err)
		}
		fmt.Printf("generated skill %s\n", name)
	}

	return nil
}

func copySkillDir(srcDir, dstDir string, transforms []TransformConfig) error {
	if err := os.MkdirAll(dstDir, 0o755); err != nil {
		return fmt.Errorf("creating directory: %w", err)
	}

	return filepath.WalkDir(srcDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		rel, err := filepath.Rel(srcDir, path)
		if err != nil {
			return err
		}
		dst := filepath.Join(dstDir, rel)

		if d.Type()&os.ModeSymlink != 0 {
			return copySymlink(path, dst, rel, transforms)
		}

		if d.IsDir() {
			return os.MkdirAll(dst, 0o755)
		}

		info, err := d.Info()
		if err != nil {
			return err
		}

		return copyFile(path, dst, rel, transforms, info.Mode())
	})
}

func copySymlink(src, dst, rel string, transforms []TransformConfig) error {
	resolved, err := filepath.EvalSymlinks(src)
	if err != nil {
		return fmt.Errorf("resolving symlink %s: %w", src, err)
	}
	info, err := os.Stat(resolved)
	if err != nil {
		return fmt.Errorf("stat %s: %w", resolved, err)
	}
	return copyFile(resolved, dst, rel, transforms, info.Mode())
}

func copyFile(src, dst, rel string, transforms []TransformConfig, mode fs.FileMode) error {
	content, err := os.ReadFile(src)
	if err != nil {
		return fmt.Errorf("reading %s: %w", src, err)
	}

	ext := filepath.Ext(rel)
	if ext == ".md" || ext == ".json" {
		isSkillMD := filepath.Base(rel) == "SKILL.md"
		applicable := filterTransforms(transforms, isSkillMD)
		var err error
		content, err = ApplyTransforms(content, applicable)
		if err != nil {
			return fmt.Errorf("transforming %s: %w", rel, err)
		}
	}

	return os.WriteFile(dst, content, mode)
}

func filterTransforms(transforms []TransformConfig, isSkillMD bool) []TransformConfig {
	var result []TransformConfig
	for _, t := range transforms {
		scope := t.Scope
		if scope == "" {
			scope = "skill_md"
		}
		if scope == "all_md" || (scope == "skill_md" && isSkillMD) {
			result = append(result, t)
		}
	}
	return result
}

func GenerateShared(m *Manifest, dryRun bool) error {
	if !m.Skills.Shared.Copy {
		return nil
	}

	srcShared := filepath.Join(m.SourcePlugin, "skills", "_shared")
	dstShared := filepath.Join(m.TargetPlugin, "skills", "_shared")

	if dryRun {
		fmt.Printf("[dry-run] copy _shared/ → %s\n", dstShared)
		return nil
	}

	if _, err := os.Stat(srcShared); os.IsNotExist(err) {
		return nil
	}

	if err := copySkillDir(srcShared, dstShared, m.Skills.Transforms); err != nil {
		return fmt.Errorf("copying _shared directory: %w", err)
	}

	fmt.Println("generated _shared/")
	return nil
}
