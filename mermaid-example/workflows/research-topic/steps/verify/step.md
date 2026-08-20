---
name: verify
description: Checks each claim against the source it names and separates the supported claims from the gaps.
agent: verifier
model: opus
reasoning_effort: high
thinking_budget: 8000
tools: [Read, WebFetch, Write]
max_turns: 20
isolation: none
gate: llm-judge
inputs: [claims_path, sources_dir, source_index_path]
outputs: [verdicts_path, gaps]
---

# Step: verify

Input: the claim set and the stored sources. Output: one verdict per claim
at `verdicts.jsonl`, plus `gaps`, the list of questions left unsupported.

You did not write these claims, and you get no note from the step that
did. That is the design. This is an independent check, not a self-review.

## Procedure

1. Read `claims.jsonl` and the stored source files.
2. Per claim, run three tests.
   - **Quote test.** The quote appears in the named source, word for word.
   - **Support test.** The quote carries the claim. A quote on the same
     subject is not support.
   - **Reach test.** The source is a primary source for this claim.
3. Write one verdict per claim to `verdicts.jsonl`:

   ```
   {"id":"c1","verdict":"supported","reason":"…","producer_model":"sonnet"}
   ```

   The verdict is `supported` or `unsupported`. Nothing else.
4. Mark a claim `unsupported` when any test fails. Give the reason in the
   words of the failing test.
5. A source that no longer loads is unchecked coverage. Mark the claim
   `unsupported` with reason `source unreachable`. Never pass it, and never
   treat it as a fault in the claim.
6. Build `gaps`. A question is a gap when every claim answering it came
   back `unsupported`.

## Gate

An llm-judge reads the rubric and `verdicts.jsonl`. It never reads your
reasoning. The gate passes on three conditions. Every claim id carries one
verdict. Every `unsupported` verdict names a failing test. No verdict uses
a word outside the two allowed.

## Outcome

Return one of two labels.

| Label | When |
|---|---|
| `supported` | `gaps` is empty. The run moves to `draft`. |
| `gaps` | `gaps` holds at least one question. The run returns to `gather`. |
