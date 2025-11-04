# Language-Specific Skills Design

## Overview

This feature extends the claude-starter-kit template with language-specific development skills that provide comprehensive guidance on code style, testing strategies, tooling, and best practices for Go, Python, Java, Kotlin, and JavaScript/TypeScript.

## Problem Statement

The current template includes process-based skills (analysis, testing, documentation, development) that are intentionally language-agnostic. While this maintains flexibility, it means:

1. Users must repeatedly look up language-specific conventions, testing frameworks, and tooling
2. The `%LANGUAGE%` placeholder in `testing-process/SKILL.md` provides minimal guidance
3. There's no centralized reference for language-specific best practices within the Claude Code workflow
4. New contributors to a codebase lack quick access to project language idioms and patterns

## Goals

1. **Provide language-specific guidance** - Create dedicated skills for the 5 most common languages
2. **Integrate seamlessly** - Enhance existing process skills without disrupting current workflows
3. **Keep template lean** - Only include the language skill relevant to each project
4. **Enable extensibility** - Allow users to add framework-specific guidance as needed
5. **Maintain practicality** - Focus on actionable insights, not encyclopedic reference material

## Non-Goals

1. **Not a language tutorial** - Assumes developer proficiency in the target language
2. **Not framework documentation** - Focus on core language, not specific frameworks
3. **Not API reference** - Claude can look up API details via Context7
4. **Not code generation templates** - Provide guidance, not boilerplate code

## Design Principles

1. **Practical over comprehensive** - Essential patterns and common pitfalls, not exhaustive coverage
2. **Progressive disclosure** - Quick reference in SKILL.md, deep dives in separate files
3. **Hybrid integration** - Brief inline guidance in process skills + links to full language skill docs
4. **Framework-agnostic core** - Language fundamentals in main content, frameworks in extensible section

## Architecture

### Directory Structure

```
.claude/skills/
├── analysis-process/
├── development-process/
├── documentation-process/
├── testing-process/
├── task-master-process/
├── lang-go/
│   ├── SKILL.md              # Entry point with overview + quick reference
│   ├── style.md              # Code style & conventions
│   ├── testing.md            # Testing strategies & tools
│   ├── tooling.md            # Ecosystem & build tools
│   ├── patterns.md           # Best practices & anti-patterns
│   └── frameworks/           # Extensible framework section
│       └── README.md         # Instructions for adding guides
├── lang-python/
│   └── [same structure as lang-go]
├── lang-java/
│   └── [same structure as lang-go]
├── lang-kotlin/
│   └── [same structure as lang-go]
└── lang-typescript/
    └── [same structure as lang-go]
```

### Skill Structure

Each language skill follows a two-tier modular structure:

**Tier 1: SKILL.md (Entry Point)**
- YAML frontmatter with skill metadata
- Language philosophy and when to use this skill
- Quick reference guide (essential commands, common patterns)
- Navigation links to detailed topic files

**Tier 2: Topic Files (Deep Dives)**
- `style.md` - Naming conventions, formatting, project structure, language idioms
- `testing.md` - Testing frameworks, patterns, coverage, mocking strategies
- `tooling.md` - Package managers, build tools, linters, formatters, debugging
- `patterns.md` - Design patterns, anti-patterns, concurrency, error handling
- `frameworks/README.md` - Instructions for adding optional framework guides

### Integration with Process Skills

Process skills reference language-specific skills through a hybrid approach:

**Before Template Cleanup:**
```markdown
Use %LANGUAGE% best practices and well-established %LANGUAGE% testing tools
```

**After Template Cleanup (LANGUAGE=go):**
```markdown
Use Go best practices and well-established Go testing tools.

For comprehensive Go testing guidance including table-driven tests,
test coverage, and benchmark testing, see the `lang-go` skill at
[skills/lang-go/testing.md](./../lang-go/testing.md).
```

**Integration Points:**
1. `testing-process/SKILL.md` → Links to `lang-<language>/testing.md`
2. `development-process/SKILL.md` → Links to `lang-<language>/tooling.md` for dependency management
3. Users can invoke `lang-<language>` skill directly for standalone language guidance

### Template Cleanup Workflow

The `.github/workflows/template-cleanup.yml` workflow is extended to:

1. **Accept LANGUAGE input** - Uses existing `LANGUAGE` input parameter
2. **Prune unused skills** - Removes all `lang-*` directories except the one matching `LANGUAGE`
3. **Replace placeholders** - Substitutes `%LANGUAGE%` with actual language name in process skills
4. **Inject skill references** - Adds markdown links to language skill in relevant process skills

**Workflow Logic:**
```
Input: LANGUAGE=go

Actions:
1. Keep: .claude/skills/lang-go/
2. Delete: .claude/skills/lang-{python,java,kotlin,typescript}/
3. Replace in testing-process/SKILL.md:
   "%LANGUAGE%" → "Go"
   Add link to lang-go/testing.md
4. Replace in development-process/SKILL.md:
   "%LANGUAGE%" → "Go"
   Add link to lang-go/tooling.md
```

## Content Guidelines

### Depth and Scope

Each language skill balances practical guidance with comprehensive coverage:

**SKILL.md (Lightweight)**
- Quick command reference (build, test, run, format)
- Common decision guides (when to use pointers, interface vs struct, etc.)
- Links to deeper topic files

**Topic Files (Practical + Comprehensive)**
- Essential patterns with brief explanations
- Common pitfalls and how to avoid them
- Recommended tools with rationale
- Architectural guidance specific to language features
- NO framework comparisons (can be looked up elsewhere)
- NO code examples for API usage (use Context7)
- Focus on what's unique or commonly misunderstood

### Framework Extensibility

Each language skill includes an empty `frameworks/` directory:

**Purpose:**
- Provides clear extensibility point for users
- Keeps template lean (no framework content by default)
- `frameworks/README.md` explains how to add framework guides

**Example frameworks (not included in template):**
- Go: Gin, Fiber, Echo
- Python: Django, Flask, FastAPI
- Java: Spring Boot, Micronaut, Quarkus
- Kotlin: Ktor, Spring Boot
- TypeScript: React, Next.js, Express, NestJS

### Language Coverage

**Initial languages (priority order):**
1. Go - Strong typing, concurrency, stdlib focus
2. Python - Dynamic typing, ecosystem richness, multiple paradigms
3. TypeScript - JavaScript superset, type system, frontend/backend
4. Java - Enterprise patterns, JVM ecosystem, Spring dominance
5. Kotlin - Modern JVM, coroutines, multi-platform

**Future expansion:** Additional languages can follow the same structure pattern.

## User Experience

### For Template Users

1. **During project creation:**
   - Run template-cleanup workflow with LANGUAGE input
   - Receive project with only relevant language skill
   - Process skills automatically reference language skill

2. **During development:**
   - Invoke process skills normally (testing-process, development-process)
   - Follow inline brief guidance
   - Navigate to language skill for deep dives when needed
   - Invoke language skill directly: "Use the lang-go skill to help with..."

3. **For framework guidance:**
   - Check `lang-<language>/frameworks/README.md` for instructions
   - Create custom framework guides as project-specific needs arise

### For Template Maintainers

1. **Adding new language:**
   - Create `lang-<language>/` directory following established structure
   - Write SKILL.md + 4 topic files + frameworks/README.md
   - Update template-cleanup workflow to include new language
   - Update CLAUDE.md to list supported languages

2. **Updating language content:**
   - Edit topic files directly
   - No workflow changes needed
   - Changes automatically available in new template instances

## Success Metrics

1. **Template adoption** - Number of projects using language-specific skills
2. **Skill invocation frequency** - How often users reference language skills
3. **Framework directory usage** - Indication users extend with custom guides
4. **Feedback on content quality** - User reports on practical value
5. **Maintenance overhead** - Time required to keep language guidance current

## Future Considerations

1. **Multi-language projects** - Template-cleanup could support comma-separated LANGUAGE values
2. **Language version specificity** - Topic files could include version-specific guidance (Go 1.23+, Python 3.12+)
3. **Automated content updates** - Scripts to refresh tooling references from package ecosystems
4. **Community contributions** - Framework guides could be contributed back to template
5. **Cross-language patterns** - Identify patterns common across languages for shared guidance
