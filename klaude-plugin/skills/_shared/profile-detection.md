## Profile detection procedure

Single source of truth for computing the set of profiles active in the current context.
Consumed by six skills: `review-code`, `review-spec`, `design`, `implement`, `test`, and `document`.

Every profile under `klaude-plugin/profiles/<name>/` declares its own trigger rule in `DETECTION.md` using the mandatory three-section schema (`## Path signals`, `## Filename signals`, `## Content signals`).
The shared procedure below applies the same algorithm against every profile's declared values.

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

The design phase runs before any code exists, so file-based detection is impossible. Detection uses idea-prose keyword matching against tokens declared in each profile's `DETECTION.md`.

**Algorithm:**

1. **Collect tokens.** Iterate §Known profiles. For each `<name>`, `Read` `<plugin_root>/profiles/<name>/DETECTION.md`. If the file has no `## Design signals` section, skip — that profile does not participate in design-phase detection. Otherwise, parse `display_name` and `tokens` from the section.
2. **Build union.** Collect all declared tokens into a single set, each tagged by its source profile name and `display_name`.
3. **Match.** Check the idea prose against the union. Matching is case-insensitive, whole-word (so `pod` in "podcast" does not fire).
4. **Confirm.** On match, surface a confirmation prompt per matched profile:
   *"This appears to be a {display_name} feature. Activate the {profile_name} profile?"* — let the user confirm yes/no. When multiple profiles match, confirm each independently.
5. **Fallback.** If no token matches but the idea is **ambiguous** — names infrastructure, deployment, runtime, or platform concerns without naming a specific technology (e.g., _"add a caching layer for the service"_, _"build a CI pipeline"_, _"deploy to production"_); or includes overloaded tokens that collide across domains — build the fallback prompt dynamically from all profiles that declare `## Design signals`:
   *"Does this feature involve {display_name_1, display_name_2, ...}? If yes, which?"*

Confirmation is required — the design skill never auto-activates a profile silently. The narrow per-profile token sets avoid noisy false positives from tokens that overload across domains.

Once activated, subsequent design-phase steps treat the profile as active in the same record shape produced by file-based detection (see §Output shape).

### Known profiles

This is the authoritative enumeration of profile `<name>`s — do NOT try discover profiles via any other means.
An explicit list is boring, deterministic, and unambiguous; runtime filesystem enumeration against the plugin tree has proven unreliable.

- `go`
- `python`
- `java`
- `js_ts`
- `kotlin`
- `k8s`

### Algorithm

Throughout this procedure, `<plugin_root>` denotes the absolute plugin-root path the agent already knows from the SKILL.md that invoked the procedure. Use that resolved absolute path wherever `<plugin_root>` appears.

1. **Iterate profiles.** For each §Known profiles `<name>`:
   1. Use the `Read` tool on `<plugin_root>/profiles/<name>/DETECTION.md`.
   2. If `Read` fails with ENOENT (profile name in list but directory missing — a stale list entry), skip silently and move on.
   3. If `Read` succeeds, parse the declared `## Path signals`, `## Filename signals`, and `## Content signals` sections.

2. **Evaluate in cost order.** For each input file, check signals in this order: path → filename → content. Cheapest first.
3. **Apply the authority rule.** A file activates the profile only if a **filename signal** OR **content signal** matches.
   A path-only match does NOT activate. Paths are a pre-filter that promotes files to "candidates"; authoritative activation requires filename or content confirmation.
   A file that matches NO path signal is still evaluated against filename and content signals — path pre-filtering is a cost hint, not a gate.
   (Otherwise a `Chart.yaml` at a non-standard path would be missed.)
4. **Bound content inspection.** Read at most ~16 KB per file when evaluating content signals.
   Multi-document YAML is inspected per `---`-separated block — a file may have five blocks, and only the third need match for the file to activate the profile.
5. **Collect records.** Accumulate one record per matched profile with the triggering files and the signal descriptions that fired.

### Tool choice

- Single file at `<plugin_root>/…` → `Read`. This is what the algorithm uses.
- Enumeration across profiles → iterate the §Known profiles list, `Read` each. Never `Glob` (cwd-scoped, misses outside-cwd paths).

### Two dimensions: cost vs authority

Signals live on two axes that point in different directions. Keep them separate in your mental model:

- **Evaluation cost** (cheapest first): path < filename < content.
  Path globs touch only the path string;
  filename matches are exact string compares;
  content inspection opens the file.
- **Authority** (most authoritative first): filename ≈ content > path.
  A filename or content match activates the profile; a path-only match does not.
  Filename and content are equally authoritative, but filename resolves first at runtime — a filename match short-circuits content inspection for that file.

Evaluating cheapest-first optimizes work. Applying authority correctly prevents false positives from incidental path matches — a stray `manifests/` directory in a Go project does not make the project Kubernetes.

### Plugin-root resolution failure

If every `Read` attempt in Algorithm step 1 fails — i.e., `<plugin_root>` could not be resolved from SKILL.md context, or the paths do not exist — the procedure cannot continue.

On that failure:

1. Emit an actionable error pointing to `CLAUDE.md` §Profile Conventions.
2. Return an empty result set so the calling skill falls back to generic guidance rather than panicking.
3. Do not retry; do not silently guess a path.

Consumers inherit this check by invoking the shared procedure — no skill re-implements it.

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
  Used downstream to resolve `profiles/<profile>/<phase>/index.md`,
  where `<phase>` is the profile phase subdirectory named identically to the calling skill:
  `review-code/`, `review-spec/`, `design/`, `implement/`, `test/`, or `document/`.
- `triggered_by` — which signal type fired and the specific value that matched.
  For debugging and for explaining detection to the user; never used as the key for profile lookup.
- `files` — the subset of input files that activated this profile.
  Skills use this to scope behavior (e.g., `helm lint` runs only on files triggered under Helm filename signals, not on every YAML in the diff).

When no profile matches, return the empty list `[]`. The caller falls back to generic guidance, identical to today's "no language detected" path.
