### Workflow

**Phase 1: Load input**

Read the target files. You SHOULD validate that each file exists before processing.

**Verify:** All target files confirmed present.

**Phase 2: Analyze**

Compare each file against the conformance rules. Flag violations with file path and line number.

**Verify:** Every violation has a file path and line reference.

**Phase 3: Write report**

Write findings to `docs/reports/<name>-<date>.md`. Include a summary section and a detailed findings section.

**Verify:** Report file exists and contains both sections.
