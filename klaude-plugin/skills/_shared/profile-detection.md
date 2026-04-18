## Profile detection procedure

Single source of truth for computing the set of profiles active in the current
context. Consumed by six skills: `review-code`, `review-spec`, `design`,
`implement`, `test`, and `document`. Six independent implementations would
drift; this file prevents that.

Every profile under `klaude-plugin/profiles/<name>/` declares its own trigger
rule in `DETECTION.md` using the mandatory three-section schema (`## Path
signals`, `## Filename signals`, `## Content signals`). The shared procedure
below applies the same algorithm against every profile's declared values.

### Inputs per consuming skill

Not every consumer has a diff available. Use the input listed for your skill:

- **`review-code`** — git diff (staged, or an explicit commit range). Scope is
  the set of files the diff touches.
- **`review-spec`** — git diff when invoked standalone; the feature directory's
  full file list when invoked by `implement` (spec review runs over the whole
  feature, not just the current task's diff).
- **`test`** — git diff mid-feature, OR the feature directory's file list
  post-implementation.
- **`implement`** — the current sub-task's target file list, augmented by the
  diff accumulated so far in the feature.
- **`design`** — **no file list available** (implementation does not yet exist).
  Detection uses a user-declared or keyword-inferred signal instead; see
  [The `design` interaction pattern](#the-design-interaction-pattern) below.
- **`document`** — feature directory's current file list; diff optional.

### The `design` interaction pattern

The design phase runs before any code exists, so file-based detection is
impossible. Instead, the skill checks the idea prose against a
**high-precision auto-trigger set**:

```
Kubernetes, K8s, Helm chart, kubectl, kustomize, manifest.yaml,
Deployment resource, StatefulSet, DaemonSet, CronJob
```

If any auto-trigger token matches, surface a single confirmation prompt:
"This appears to be a Kubernetes feature. Activate the Kubernetes profile for
this design session?" — let the user confirm yes/no.

If no auto-trigger matches but the idea is **ambiguous** (names infrastructure,
deployment, runtime, or platform concerns without naming a specific technology;
or includes overloaded tokens like `cluster`, `namespace`, `pod` that collide
with non-K8s meanings), ask explicitly: "Does this feature involve Kubernetes,
Terraform, or other IaC artifacts? If yes, which?"

The narrow auto-trigger set avoids noisy false positives from tokens that
overload across domains. Confirmation is required — the design skill never
auto-activates a profile silently.

Once activated, subsequent design-phase steps treat the profile as active in
the same record shape produced by file-based detection (see §Output shape).

### Algorithm

1. **Iterate profiles.** For each `${CLAUDE_PLUGIN_ROOT}/profiles/*/DETECTION.md`:
   load the declared `## Path signals`, `## Filename signals`, and `## Content
   signals`.
2. **Evaluate in cost order.** For each input file, check signals in this
   order: path → filename → content. Cheapest first.
3. **Apply the authority rule.** A file activates the profile only if a
   **filename signal** OR **content signal** matches. A path-only match does
   NOT activate. Paths are a pre-filter that promotes files to "candidates";
   authoritative activation requires filename or content confirmation.
4. **Bound content inspection.** Read at most ~16 KB per file when evaluating
   content signals. Multi-document YAML is inspected per `---`-separated block
   — a file may have five blocks, and only the third need match for the file
   to activate the profile.
5. **Collect records.** Accumulate one record per matched profile with the
   triggering files and the signal descriptions that fired.

### Two dimensions: cost vs authority

Signals live on two axes that point in different directions. Keep them separate
in your mental model:

- **Evaluation cost** (cheapest first): path < filename < content. Path globs
  touch only the path string; filename matches are exact string compares;
  content inspection opens the file.
- **Authority** (most authoritative first): filename ≈ content > path. A
  filename or content match activates the profile; a path-only match does not.

Evaluating cheapest-first optimizes work. Applying authority correctly prevents
false positives from incidental path matches — a stray `manifests/` directory
in a Go project does not make the project Kubernetes.

### Unset-variable protocol

Before emitting any results, check that `$CLAUDE_PLUGIN_ROOT` is set and
non-empty. The harness normally guarantees this; the check exists to fail
loudly when it does not (harness bug, manual CLI invocation, local testing
outside the plugin context).

On unset:

1. Emit an actionable error naming the variable and pointing to
   `CLAUDE.md` §Profile Conventions.
2. Return an empty result set so the calling skill falls back to generic
   guidance rather than panicking.
3. Do not retry; do not silently guess a path.

Example error string:

```
$CLAUDE_PLUGIN_ROOT is not set; profile detection cannot locate the
profiles/ directory. See CLAUDE.md §Profile Conventions.
```

Consumers inherit this check by invoking the shared procedure — no skill
re-implements it.

### Output shape

A list of records, one per matched profile:

```
[
  {
    profile: "<name>",                     // directory name under profiles/
    triggered_by: [
      "filename: Chart.yaml",              // signal type + matched value
      "content: apiVersion+kind in block 2"
    ],
    files: [
      "path/to/file1.yaml",
      "path/to/file2.yaml"
    ]
  },
  ...
]
```

Field semantics:

- `profile` — the directory name under `profiles/` (e.g., `go`, `python`, `k8s`).
  Used downstream to resolve `profiles/<profile>/<phase>/index.md`.
- `triggered_by` — which signal type fired and the specific value that matched.
  For debugging and for explaining detection to the user; never used as the key
  for profile lookup.
- `files` — the subset of input files that activated this profile. Skills use
  this to scope behavior (e.g., `helm lint` runs only on files triggered under
  Helm filename signals, not on every YAML in the diff).

When no profile matches, return the empty list `[]`. The caller falls back to
generic guidance, identical to today's "no language detected" path.

### Authoring convention (for editors of this file)

This file lives at `klaude-plugin/skills/_shared/profile-detection.md` — INSIDE
the plugin tree — and is therefore subject to `${CLAUDE_PLUGIN_ROOT}`
substitution when an agent reads it (verified 2026-04-18; see
[ADR 0003 §Verification](../../../docs/adr/0003-plugin-root-referenced-content.md)).

The rule is simple but easy to trip over:

- When prose **references the variable by name** (documenting or explaining it),
  use the bare form `$CLAUDE_PLUGIN_ROOT` — the harness does NOT substitute the
  bare form. Alternative: the HTML entity `&#36;{CLAUDE_PLUGIN_ROOT}` when the
  brace shape must appear in rendered output.
- When prose **uses the variable as a path** that must resolve at runtime
  (e.g., `${CLAUDE_PLUGIN_ROOT}/profiles/*/DETECTION.md`), use the brace form —
  that IS the intended substitution.

Both conventions coexist in the same file. The path references in §Algorithm
step 1 use the brace form on purpose. The error-message example in
§Unset-variable protocol and the text discussing `$CLAUDE_PLUGIN_ROOT` by name
use the bare form on purpose. When editing this file, match the intent.

Markdown containers (inline backticks, fenced blocks, indented code, blockquotes,
HTML comments, backslash escape) do NOT protect the brace form from substitution.
The only escape forms that survive are the bare form and the HTML entity above.
