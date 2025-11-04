# Language-Specific Skills Implementation Plan

## Prerequisites

Before starting implementation, ensure you understand:
- The claude-starter-kit repository structure (especially `.claude/skills/` and `.github/workflows/`)
- How Claude Code skills work (YAML frontmatter, markdown content, skill invocation)
- GitHub Actions workflow syntax for template-cleanup automation
- The existing skill patterns in `analysis-process/`, `testing-process/`, etc.

## Implementation Phases

The implementation is broken into 4 phases:

1. **Phase 1:** Create directory structure and skill templates
2. **Phase 2:** Write language-specific content for all 5 languages
3. **Phase 3:** Update template-cleanup workflow
4. **Phase 4:** Update process skills and documentation

---

## Phase 1: Create Directory Structure and Templates

### Task 1.1: Create Language Skill Directories

**Location:** `.claude/skills/`

**Actions:**
Create 5 new directories following the naming convention `lang-<language>`:
- `lang-go/`
- `lang-python/`
- `lang-java/`
- `lang-kotlin/`
- `lang-typescript/`

Each directory should contain these files (start with empty templates):
- `SKILL.md`
- `style.md`
- `testing.md`
- `tooling.md`
- `patterns.md`
- `frameworks/README.md`
- `frameworks/.gitkeep`

**Key Considerations:**
- Use consistent capitalization: `lang-typescript` not `lang-TypeScript`
- The `frameworks/.gitkeep` ensures the empty directory is tracked in git
- File names are lowercase to match existing skill patterns

---

### Task 1.2: Create SKILL.md Template Structure

**Location:** Each `lang-<language>/SKILL.md`

**Structure:**
```markdown
---
name: lang-<language>
description: Use when working with <Language> codebases to get guidance on <Language>-specific style conventions, testing strategies, tooling, and best practices
---

# <Language> Development Skill

[Brief philosophy/overview section]

## Quick Reference

[Essential commands and common patterns]

## Topics

Comprehensive guidance on <Language> development:

- **[Code Style & Conventions](./style.md)** - Naming, formatting, project structure, idioms
- **[Testing Strategies](./testing.md)** - Frameworks, patterns, coverage, mocking
- **[Tooling & Ecosystem](./tooling.md)** - Package managers, build tools, linters, formatters
- **[Patterns & Best Practices](./patterns.md)** - Design patterns, anti-patterns, error handling
- **[Framework Extensions](./frameworks/README.md)** - How to add framework-specific guides

## When to Use This Skill

[Specific scenarios for invoking this skill]
```

**Key Considerations:**
- Replace `<language>` and `<Language>` placeholders appropriately per file
- Keep SKILL.md concise - detailed content goes in topic files
- The description field uses "Use when..." pattern matching existing skills

---

### Task 1.3: Create Topic File Templates

**Location:** Each `lang-<language>/{style,testing,tooling,patterns}.md`

**Common Structure for All Topic Files:**
```markdown
# <Language> <Topic Name>

## Overview

[Brief intro to this topic in context of the language]

## [Section 1]

[Content organized by logical sections]

## [Section 2]

[More content]

## Common Pitfalls

[Language-specific mistakes to avoid]

## Additional Resources

[Links to official docs, style guides, etc.]
```

**Specific Topic Guidance:**

**style.md sections:**
- Naming conventions (variables, functions, classes, packages)
- Code formatting and organization
- Project structure patterns
- Language-specific idioms
- Module/package organization

**testing.md sections:**
- Primary testing framework(s)
- Test organization patterns (e.g., table-driven for Go)
- Mocking strategies
- Coverage tools and practices
- Integration testing approaches
- Performance/benchmark testing

**tooling.md sections:**
- Package manager usage
- Build tools and task runners
- Linters and formatters (configuration)
- Dependency management
- Debugging tools
- IDE/editor recommendations

**patterns.md sections:**
- Idiomatic patterns for the language
- Common anti-patterns to avoid
- Error handling strategies
- Concurrency patterns (if applicable)
- Memory management considerations
- Dependency injection patterns

**Key Considerations:**
- Focus on practical, actionable guidance
- Avoid framework-specific content (that goes in `frameworks/`)
- Assume reader is experienced in the language but new to the codebase
- Link to official documentation rather than duplicating API details

---

### Task 1.4: Create frameworks/README.md Template

**Location:** Each `lang-<language>/frameworks/README.md`

**Content:**
```markdown
# Framework-Specific Guides

This directory is for optional framework-specific development guidance.

## Purpose

While the main `lang-<language>` skill focuses on core language features, this directory allows you to add guides for specific frameworks used in your project.

## Adding a Framework Guide

Create a new markdown file named after the framework (e.g., `spring-boot.md`, `django.md`, `react.md`) with the following structure:

```markdown
# <Framework Name> Guide

## Overview
[Brief description of the framework and its role in your project]

## Project Structure
[Framework-specific organization patterns]

## Common Patterns
[Framework idioms and best practices]

## Testing
[Framework-specific testing approaches]

## Gotchas
[Common mistakes and how to avoid them]

## Resources
[Framework documentation links]
```

## Example Frameworks for <Language>

Common frameworks you might document:
- [List 3-5 popular frameworks for this language]

## When to Create Framework Guides

Consider creating a framework guide when:
- The framework has significant project-specific configuration
- There are team conventions that differ from framework defaults
- Common patterns have emerged that would benefit new contributors
- Framework usage is non-obvious or has pitfalls
```

**Key Considerations:**
- Replace `<Language>` placeholder per language
- List appropriate frameworks for each language (Go: Gin/Fiber, Python: Django/Flask, etc.)
- Keep instructions concise - this is user-facing documentation
- Emphasize these are optional and project-specific

---

## Phase 2: Write Language-Specific Content

### Task 2.1: Research and Write Go Content

**Files to populate:**
- `lang-go/SKILL.md`
- `lang-go/style.md`
- `lang-go/testing.md`
- `lang-go/tooling.md`
- `lang-go/patterns.md`
- `lang-go/frameworks/README.md`

**Research sources:**
- Effective Go (official style guide)
- Go stdlib documentation
- Go testing package
- Go tooling (go build, go test, go mod, gofmt, golangci-lint)
- Common Go patterns (error handling, interfaces, goroutines)

**Key Go-specific topics to cover:**
- **Style:** Exported vs unexported, package naming, receiver names, interface naming conventions
- **Testing:** Table-driven tests, subtests, test fixtures, testify vs standard library, race detector
- **Tooling:** go mod, go work, gofmt vs goimports, golangci-lint configuration
- **Patterns:** Error wrapping, context usage, interface design, goroutine lifecycle management

**Content depth:**
- SKILL.md: 50-100 lines (overview + quick ref + navigation)
- Each topic file: 150-300 lines (practical guidance with examples)

---

### Task 2.2: Research and Write Python Content

**Files to populate:**
- `lang-python/SKILL.md`
- `lang-python/style.md`
- `lang-python/testing.md`
- `lang-python/tooling.md`
- `lang-python/patterns.md`
- `lang-python/frameworks/README.md`

**Research sources:**
- PEP 8 (style guide)
- PEP 484 (type hints)
- pytest documentation
- Python packaging (pip, poetry, uv)
- Python tooling (black, ruff, mypy, pylint)

**Key Python-specific topics to cover:**
- **Style:** PEP 8 conventions, type hints usage, docstring formats, naming conventions
- **Testing:** pytest vs unittest, fixtures, parametrize, mocking with pytest-mock, coverage.py
- **Tooling:** pip vs poetry vs uv, virtual environments, black/ruff configuration, mypy type checking
- **Patterns:** Context managers, decorators, generators, async/await, dataclasses vs attrs vs pydantic

**Content depth:** Same as Go (50-100 lines SKILL.md, 150-300 lines per topic)

---

### Task 2.3: Research and Write Java Content

**Files to populate:**
- `lang-java/SKILL.md`
- `lang-java/style.md`
- `lang-java/testing.md`
- `lang-java/tooling.md`
- `lang-java/patterns.md`
- `lang-java/frameworks/README.md`

**Research sources:**
- Google Java Style Guide
- Oracle Java documentation
- JUnit 5 documentation
- Maven/Gradle documentation
- Common Java patterns and anti-patterns

**Key Java-specific topics to cover:**
- **Style:** Class naming, package structure, JavaDoc conventions, modern Java features (records, sealed classes)
- **Testing:** JUnit 5 annotations, AssertJ assertions, Mockito, test containers, integration testing
- **Tooling:** Maven vs Gradle, dependency management, Checkstyle, SpotBugs, IntelliJ vs Eclipse
- **Patterns:** Builder pattern, dependency injection, streams and lambdas, Optional usage, exception handling

**Content depth:** Same as above

---

### Task 2.4: Research and Write Kotlin Content

**Files to populate:**
- `lang-kotlin/SKILL.md`
- `lang-kotlin/style.md`
- `lang-kotlin/testing.md`
- `lang-kotlin/tooling.md`
- `lang-kotlin/patterns.md`
- `lang-kotlin/frameworks/README.md`

**Research sources:**
- Kotlin Coding Conventions (official)
- Kotlin stdlib documentation
- Kotlin testing frameworks (Kotest, MockK)
- Kotlin build tools (Gradle Kotlin DSL)

**Key Kotlin-specific topics to cover:**
- **Style:** Naming conventions, extension functions, data classes, when expressions, null safety
- **Testing:** Kotest vs JUnit, MockK, coroutine testing, property-based testing with Kotest
- **Tooling:** Gradle Kotlin DSL, ktlint, detekt, Kotlin compiler options, multiplatform setup
- **Patterns:** Sealed classes, delegation, coroutines, flow, scope functions, DSL building

**Content depth:** Same as above

---

### Task 2.5: Research and Write TypeScript Content

**Files to populate:**
- `lang-typescript/SKILL.md`
- `lang-typescript/style.md`
- `lang-typescript/testing.md`
- `lang-typescript/tooling.md`
- `lang-typescript/patterns.md`
- `lang-typescript/frameworks/README.md`

**Research sources:**
- TypeScript Handbook (official documentation)
- JavaScript/TypeScript style guides (Airbnb, Google)
- Testing frameworks (Jest, Vitest)
- Build tooling (npm, pnpm, yarn, tsx, esbuild, vite)

**Key TypeScript-specific topics to cover:**
- **Style:** Naming conventions, type vs interface, any vs unknown, optional chaining, module organization
- **Testing:** Jest vs Vitest, React Testing Library, mocking with jest.mock, snapshot testing
- **Tooling:** npm vs pnpm vs yarn, tsconfig.json configuration, ESLint + Prettier, TypeScript compiler options
- **Patterns:** Generic constraints, utility types, discriminated unions, type guards, async patterns, module patterns

**Content depth:** Same as above

---

## Phase 3: Update Template-Cleanup Workflow

### Task 3.1: Analyze Current template-cleanup.yml

**Location:** `.github/workflows/template-cleanup.yml`

**Actions:**
- Read the existing workflow file
- Identify where the `LANGUAGE` input is defined
- Locate where placeholder replacements happen
- Understand the file processing logic (sed, awk, or script-based)

**Key Information Needed:**
- Current workflow inputs structure
- Placeholder replacement mechanism
- Which files are currently processed for `%LANGUAGE%` replacement
- Repository path structure in workflow context

---

### Task 3.2: Add Language Skill Pruning Logic

**Location:** `.github/workflows/template-cleanup.yml`

**Actions:**
Add a new step that removes unused language skills based on the `LANGUAGE` input.

**Logic:**
```yaml
- name: Remove unused language skills
  run: |
    LANGUAGE="${{ inputs.LANGUAGE }}"

    # Define all language skills
    ALL_LANGS="go python java kotlin typescript"

    # Remove all language skills except the selected one
    for lang in $ALL_LANGS; do
      if [ "$lang" != "$LANGUAGE" ]; then
        rm -rf ".claude/skills/lang-$lang"
        echo "Removed .claude/skills/lang-$lang"
      fi
    done
```

**Key Considerations:**
- Place this step after repository checkout but before git commit
- Handle case sensitivity (input might be "Go" or "go")
- Add validation to ensure LANGUAGE matches one of the supported languages
- Log which skills are removed for debugging

---

### Task 3.3: Update Process Skills with Language References

**Location:** `.github/workflows/template-cleanup.yml`

**Actions:**
Add logic to inject language skill references into process skills.

**Files to modify:**
- `.claude/skills/testing-process/SKILL.md`
- `.claude/skills/development-process/SKILL.md`

**Replacement logic for testing-process/SKILL.md:**

Find pattern:
```
Use %LANGUAGE% best practices and well-established %LANGUAGE% testing tools
```

Replace with:
```
Use <Language> best practices and well-established <Language> testing tools.

For comprehensive <Language> testing guidance including [language-specific topics],
see the `lang-<language>` skill at [skills/lang-<language>/testing.md](./../lang-<language>/testing.md).
```

**Replacement logic for development-process/SKILL.md:**

Add after dependency documentation section:
```
For <Language>-specific tooling and dependency management guidance,
see the `lang-<language>` skill at [skills/lang-<language>/tooling.md](./../lang-<language>/tooling.md).
```

**Implementation approach:**
- Use sed or a custom script to perform replacements
- Replace `%LANGUAGE%` with capitalized language name
- Replace `<language>` with lowercase language name
- Insert markdown links at appropriate locations

**Example workflow step:**
```yaml
- name: Update process skills with language references
  run: |
    LANGUAGE="${{ inputs.LANGUAGE }}"
    LANG_LOWER=$(echo "$LANGUAGE" | tr '[:upper:]' '[:lower:]')
    LANG_UPPER=$(echo "$LANGUAGE" | sed 's/.*/\u&/')

    # Update testing-process
    sed -i "s/%LANGUAGE%/$LANG_UPPER/g" .claude/skills/testing-process/SKILL.md

    # Add language skill reference to testing-process
    # [Implementation depends on file structure]

    # Update development-process
    sed -i "s/%LANGUAGE%/$LANG_UPPER/g" .claude/skills/development-process/SKILL.md

    # Add language skill reference to development-process
    # [Implementation depends on file structure]
```

**Key Considerations:**
- Test the sed commands locally before committing
- Handle multi-line insertions carefully
- Preserve existing formatting and line breaks
- Consider using a dedicated script file if logic becomes complex

---

### Task 3.4: Update Workflow Input Validation

**Location:** `.github/workflows/template-cleanup.yml`

**Actions:**
Add input validation for the LANGUAGE parameter.

**Validation logic:**
```yaml
- name: Validate language input
  run: |
    LANGUAGE="${{ inputs.LANGUAGE }}"
    VALID_LANGUAGES="go python java kotlin typescript"

    if ! echo "$VALID_LANGUAGES" | grep -wq "$(echo "$LANGUAGE" | tr '[:upper:]' '[:lower:]')"; then
      echo "Error: Invalid LANGUAGE value '$LANGUAGE'"
      echo "Valid options: $VALID_LANGUAGES"
      exit 1
    fi
```

**Key Considerations:**
- Place this step early in the workflow (before destructive operations)
- Case-insensitive matching for user convenience
- Clear error messages with valid options listed

---

### Task 3.5: Test Workflow Changes

**Actions:**
- Create a test branch
- Trigger the template-cleanup workflow with different LANGUAGE inputs
- Verify:
  - Correct language skill is retained
  - Other language skills are removed
  - Process skills have proper references injected
  - `%LANGUAGE%` placeholders are replaced correctly
- Test all 5 supported languages (go, python, java, kotlin, typescript)

**Edge cases to test:**
- Invalid LANGUAGE input (should fail with clear error)
- Case variations (Go, GO, go should all work)
- Verify git commits include proper file changes

---

## Phase 4: Update Process Skills and Documentation

### Task 4.1: Review and Update testing-process/SKILL.md

**Location:** `.claude/skills/testing-process/SKILL.md`

**Actions:**
- Review current content with `%LANGUAGE%` placeholders
- Ensure the content flows naturally when placeholder is replaced
- Verify there's a logical place to insert language skill reference
- Consider if additional `%LANGUAGE%` placeholders are needed elsewhere in the file

**Expected result:**
The file should read naturally when `%LANGUAGE%` is replaced with actual language name and link is inserted.

**Example before:**
```markdown
Use %LANGUAGE% best practices and well-establised %LANGUAGE% mocking tools
```

**Example after (for Go):**
```markdown
Use Go best practices and well-established Go mocking tools.

For comprehensive Go testing guidance including table-driven tests,
test coverage, and benchmark testing, see the `lang-go` skill at
[skills/lang-go/testing.md](./../lang-go/testing.md).
```

---

### Task 4.2: Review and Update development-process/SKILL.md

**Location:** `.claude/skills/development-process/SKILL.md`

**Actions:**
- Add `%LANGUAGE%` placeholder if not already present
- Identify appropriate section to add language skill reference
- Ensure reference to `tooling.md` makes sense contextually

**Suggested addition:**
After the "Working with Dependencies" section, add:

```markdown
For %LANGUAGE%-specific tooling, package management, and ecosystem best practices,
see the `lang-%LANGUAGE_LOWER%` skill at [skills/lang-%LANGUAGE_LOWER%/tooling.md](./../lang-%LANGUAGE_LOWER%/tooling.md).
```

**Key Considerations:**
- Use `%LANGUAGE_LOWER%` placeholder for file paths
- Use `%LANGUAGE%` for user-facing language names
- The workflow will need to replace both placeholders

---

### Task 4.3: Update CLAUDE.md Documentation

**Location:** `/CLAUDE.md`

**Actions:**
Add a new section documenting the language-specific skills feature.

**Suggested location:** After "Task Master Integration" section, add "Language-Specific Skills" section.

**Content to add:**
```markdown
## Language-Specific Skills

The template includes comprehensive language-specific development skills that provide guidance on code style, testing strategies, tooling, and best practices.

### Available Language Skills

After running template-cleanup, your project will include one of these skills based on the `LANGUAGE` input:
- `lang-go` - Go development guidance
- `lang-python` - Python development guidance
- `lang-java` - Java development guidance
- `lang-kotlin` - Kotlin development guidance
- `lang-typescript` - TypeScript/JavaScript development guidance

### Skill Structure

Each language skill includes:
- **SKILL.md** - Overview and quick reference
- **style.md** - Code conventions and idioms
- **testing.md** - Testing frameworks and patterns
- **tooling.md** - Ecosystem and build tools
- **patterns.md** - Best practices and anti-patterns
- **frameworks/** - Extensible framework-specific guides

### Using Language Skills

**Automatic reference from process skills:**
When you invoke process skills like `testing-process`, they automatically reference the appropriate language skill sections.

**Direct invocation:**
You can directly invoke the language skill for comprehensive guidance:
```
Use the lang-go skill to help me structure this package
```

**Framework extensions:**
To add framework-specific guidance, see the `frameworks/README.md` in your language skill directory.

### Best Practices

- Start with the SKILL.md for quick reference
- Navigate to topic files for detailed guidance
- Use Context7 for API documentation lookups
- Extend with framework guides as your project needs evolve
```

**Key Considerations:**
- Keep documentation concise and actionable
- Link to relevant sections for deeper context
- Provide clear usage examples

---

### Task 4.4: Update README.md

**Location:** `/README.md`

**Actions:**
Update the Features section and Quick Start section to mention language-specific skills.

**Features section addition:**
```markdown
- **📚 Language-Specific Development Skills**
  - Comprehensive guidance for Go, Python, Java, Kotlin, and TypeScript
  - Code style conventions, testing strategies, tooling, and best practices
  - Modular structure with quick reference and deep-dive topic files
  - Extensible framework guides for project-specific needs
```

**Quick Start section update:**
In step 3 (Run template-cleanup workflow), clarify that `LANGUAGE` input determines which language skill is included:

```markdown
3. Run the `template-cleanup` workflow from your new repo, and provide some inputs for your specific use-case.

**Serena MCP Configuration Inputs:**

- `LANGUAGE` - the main language(s) of your project. This also determines which language-specific skill is included. Supported: go, python, java, kotlin, typescript. (See [Serena Programming Language Support](https://github.com/oraios/serena?tab=readme-ov-file#programming-language-support--semantic-analysis-capabilities))
```

---

### Task 4.5: Create Migration Guide (Optional)

**Location:** `/docs/wip/language-specific-skills/migration.md`

**Purpose:**
Document how existing users of the template can adopt language-specific skills.

**Content outline:**
```markdown
# Migrating to Language-Specific Skills

## For Existing Projects

If your project was created before language-specific skills were added:

1. **Identify your language**
   Determine which language skill matches your project.

2. **Copy language skill directory**
   From a new template instance, copy `.claude/skills/lang-<language>/` to your project.

3. **Update process skills**
   Add language skill references to:
   - `.claude/skills/testing-process/SKILL.md`
   - `.claude/skills/development-process/SKILL.md`

4. **Replace placeholders**
   Find and replace `%LANGUAGE%` with your language name.

5. **Test integration**
   Invoke process skills and verify language skill references work.

## For Multi-Language Projects

[Guidance on handling projects with multiple languages]

## Rollback Instructions

[How to remove language skills if needed]
```

---

## Phase 5: Testing and Validation

### Task 5.1: Integration Testing

**Actions:**
- Create a fresh project from the template
- Test template-cleanup workflow with each of the 5 languages
- Verify for each language:
  - Only correct language skill remains
  - Process skills have proper references
  - All links work (no broken markdown links)
  - Skills invoke correctly in Claude Code

**Test checklist per language:**
```
[ ] template-cleanup workflow succeeds
[ ] Correct lang-<language> directory present
[ ] Other lang-* directories removed
[ ] testing-process/SKILL.md updated correctly
[ ] development-process/SKILL.md updated correctly
[ ] All markdown links resolve
[ ] SKILL.md loads properly in Claude Code
[ ] Topic files are accessible via navigation links
[ ] frameworks/README.md is present and readable
```

---

### Task 5.2: Content Quality Review

**Actions:**
For each language skill:
- Verify technical accuracy of guidance
- Check for outdated tool versions or practices
- Ensure consistent tone and structure across all 5 languages
- Validate all external links work
- Confirm no framework-specific content in core topic files

**Review checklist per language:**
```
[ ] Naming conventions are accurate
[ ] Testing patterns reflect current best practices
[ ] Tool recommendations are up-to-date
[ ] Pattern guidance is idiomatic for the language
[ ] Links to official documentation work
[ ] Consistent markdown formatting
[ ] No typos or grammatical errors
```

---

### Task 5.3: User Acceptance Testing

**Actions:**
- Have developers from each language background review their respective skill
- Collect feedback on:
  - Content accuracy and completeness
  - Practical value of guidance
  - Missing topics or patterns
  - Clarity of examples and explanations

**Iteration:**
- Incorporate feedback into content
- Update based on real-world usage patterns
- Refine organization based on navigation patterns

---

## Rollout Strategy

### Phase 1: Internal Testing
- Deploy to test template instance
- Validate with internal team members
- Fix critical issues

### Phase 2: Beta Release
- Merge to main branch with clear documentation
- Announce in README as beta feature
- Collect community feedback

### Phase 3: Stable Release
- Incorporate feedback and refinements
- Update documentation to remove beta label
- Announce as stable feature

### Phase 4: Ongoing Maintenance
- Monitor for outdated content
- Update as languages evolve
- Add new languages based on demand

---

## Maintenance Considerations

### Content Updates
- Schedule quarterly reviews of language skills
- Monitor for new language versions (Go 1.24, Python 3.13, etc.)
- Update tool recommendations as ecosystem evolves
- Deprecate outdated patterns

### Community Contributions
- Accept framework guide contributions
- Review and merge language skill improvements
- Maintain consistent quality standards

### Versioning
- Consider semantic versioning for major language skill updates
- Document breaking changes to skill structure
- Provide migration guides for structural changes
