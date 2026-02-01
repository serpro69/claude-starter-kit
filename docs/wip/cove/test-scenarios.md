# CoVe Skill Test Scenarios

Manual verification test scenarios for the Chain-of-Verification (CoVe) skill implementation.

## Prerequisites

Before running tests:
1. Ensure template-sync has been run to copy CoVe files to `.claude/` directory
2. Verify `/mcp` shows all servers connected
3. Clear Claude Code context with `/clear` between tests

---

## Test 1: Slash Command with Question

**Input:**
```
/cove What is the default port for PostgreSQL?
```

**Expected Behavior:**
- Full 4-step CoVe workflow executes
- Initial Answer identifies port 5432
- 3-5 verification questions generated targeting the claim
- Independent answers confirm or challenge the port number
- Final answer states the verified port

**Output Format Checklist:**
- [ ] Initial Answer section clearly marked
- [ ] Verification section has 3-5 Q&A pairs
- [ ] Q&A pairs use independent reasoning (no self-reference)
- [ ] Final Verified Answer section present
- [ ] Verification notes list corrections OR confirm no corrections needed

---

## Test 2: Previous Response Verification

**Step 1:** Ask a factual question:
```
What is TCP and how does the three-way handshake work?
```

**Step 2:** Invoke CoVe without arguments:
```
/cove
```

**Expected Behavior:**
- CoVe applies to the previous response about TCP
- Verification questions target claims about TCP handshake
- All 4 steps present in output
- Questions relevant to networking concepts from previous response

**Output Format Checklist:**
- [ ] Initial Answer references or uses previous response content
- [ ] Verification questions target TCP/handshake claims
- [ ] Independent answers don't reference "my previous response"
- [ ] Final Verified Answer section present
- [ ] Verification notes section present

---

## Test 3: Natural Language Invocation

**Input:**
```
Use chain of verification to answer: What is the memory limit for AWS Lambda?
```

**Expected Behavior:**
- Skill recognized via natural language trigger
- Same 4-step structure as explicit /cove invocation
- Verification questions target AWS Lambda specs
- Tool usage (WebSearch or context7) may be employed for verification

**Output Format Checklist:**
- [ ] Initial Answer section clearly marked
- [ ] Verification section has 3-5 Q&A pairs
- [ ] Questions challenge specific memory claims
- [ ] Final Verified Answer section present
- [ ] Verification notes section present

---

## Test 4: Code/Technical Verification

**Input:**
```
/cove Is binary search O(log n) time complexity?
```

**Expected Behavior:**
- Initial answer explains binary search complexity
- Verification questions cover:
  - Algorithm correctness assumptions
  - Edge cases (sorted input requirement)
  - Space complexity distinction
  - Best/worst/average case analysis
- Technical accuracy verified through independent reasoning

**Output Format Checklist:**
- [ ] Initial Answer addresses time complexity claim
- [ ] Verification questions cover algorithm analysis
- [ ] At least one question challenges assumptions
- [ ] Final Verified Answer technically accurate
- [ ] Verification notes explain any nuances discovered

---

## Edge Cases

### Ambiguous Questions
**Input:** `/cove How do you sort data?`
- Expected: CoVe should still work, verification questions may seek clarification on context

### Initial Answer Already Correct
**Input:** `/cove What is 2 + 2?`
- Expected: Verification confirms initial answer, notes state "No corrections needed"

### Complex Multi-Part Questions
**Input:** `/cove What are the differences between REST and GraphQL, and when should you use each?`
- Expected: Verification questions target multiple claims, may require more Q&A pairs

---

## Validation Summary Template

Use this template when recording test results:

```markdown
| Test | Status | Notes |
|------|--------|-------|
| Test 1: Slash command | Pass/Fail | |
| Test 2: Previous response | Pass/Fail | |
| Test 3: Natural language | Pass/Fail | |
| Test 4: Code verification | Pass/Fail | |
```

## Issues Found

Document any issues discovered during testing:

| Issue | Severity | Description | Suggested Fix |
|-------|----------|-------------|---------------|
| | | | |
