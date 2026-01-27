# Template Sync Feature - Product Requirements Document

## Overview

Enable repositories created from the `claude-starter-kit` template to receive configuration updates from the upstream template repository.

## Problem Statement

Currently, `claude-starter-kit` functions as a one-time template:
- Users create a repo, run cleanup, and template files are deleted
- No mechanism exists to receive updates when the template improves
- Users wanting updates must manually copy changes from upstream

## Solution

Implement a "rehydration" sync mechanism:
1. Store template version and substitution variables in a manifest during initial cleanup
2. Provide a GitHub Actions workflow to fetch upstream templates
3. Re-apply project-specific values to fetched templates
4. Present changes as a Pull Request for human review

## Goals

- Enable existing repos to pull configuration updates from upstream
- Preserve project-specific customizations (project name, language, etc.)
- Give users full control over what changes get merged via PR review
- Support version targeting (latest, specific tag, or bleeding edge)

## Non-Goals

- Selective/granular updates (single directories or files)
- Automatic conflict resolution
- Support for multiple upstream sources
- Local-only sync without GitHub Actions

## User Stories

### US1: Receive Template Updates
As a developer using a repo created from claude-starter-kit, I want to receive configuration updates when the template improves, so I can benefit from new skills, commands, and fixes.

### US2: Preserve Customizations
As a developer who has configured project-specific settings, I want the sync process to preserve my project name, language, and custom prompts, so I don't have to reconfigure after each update.

### US3: Review Before Merge
As a developer, I want to review all changes before they're applied, so I can reject changes that would overwrite my intentional customizations.

### US4: Target Specific Version
As a developer, I want to sync to a specific template version, so I can choose stable releases or test bleeding-edge changes.

## Technical Requirements

### TR1: State Manifest
- Create `.github/template-state.json` during initial cleanup
- Store: template version, upstream repo, all substitution variables
- Include schema version for future migrations

### TR2: Sync Workflow
- GitHub Actions workflow with manual dispatch trigger
- Inputs: version (default: latest), dry_run mode
- Creates PR with changes for review
- Updates manifest with new version in PR

### TR3: Sync Script
- Shell script implementing core sync logic
- Functions: fetch upstream, apply substitutions, compare files
- Supports CI and local execution modes
- Proper error handling and exit codes

### TR4: Cleanup Modifications
- Write manifest after applying substitutions
- Preserve sync workflow and script during cleanup
- Record template version from git tag or SHA

## Acceptance Criteria

### AC1: Manifest Generation
- [ ] Running template-cleanup creates `.github/template-state.json`
- [ ] Manifest contains all substitution variables used
- [ ] Manifest contains template version (tag or SHA)

### AC2: Sync Workflow
- [ ] Workflow appears in Actions tab
- [ ] Can trigger manually with version input
- [ ] Dry-run mode shows diff without creating PR
- [ ] Creates PR when changes detected

### AC3: Rehydration
- [ ] Fetched templates have project name re-applied
- [ ] Fetched templates have language re-applied
- [ ] Custom prompts are preserved in config files

### AC4: PR Quality
- [ ] PR title includes version transition (old → new)
- [ ] PR body includes summary of changed files
- [ ] PR body includes review guidance

### AC5: Error Handling
- [ ] Missing manifest produces clear error message
- [ ] Invalid version produces clear error message
- [ ] Network failures are handled gracefully

## Implementation Reference

See detailed design and implementation plan:
- Design: `/docs/wip/template-sync/design.md`
- Implementation: `/docs/wip/template-sync/implementation.md`

## Success Metrics

- Users can successfully sync to new template versions
- Project-specific values are preserved after sync
- No reports of silent overwrites of user customizations
