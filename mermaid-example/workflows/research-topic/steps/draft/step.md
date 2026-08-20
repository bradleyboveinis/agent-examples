---
name: draft
description: Writes the report from the supported claims and cites a source on every claim.
agent: writer
model: sonnet
reasoning_effort: medium
thinking_budget: 0
tools: [Read, Write]
max_turns: 12
isolation: none
gate: deterministic
inputs: [questions_path, claims_path, verdicts_path, source_index_path]
outputs: [report_path]
---

# Step: draft

Input: the question list, the claims, the verdicts, and the source index.
Output: the report at `report.md`.

## Procedure

1. Read `verdicts.jsonl` first. Load only the claims it marks `supported`.
   An `unsupported` claim never reaches the report.
2. Order the report by question rank. One section per question.
3. State the answer to the question in the first sentence of its section.
   Support follows the answer.
4. Cite the source id on every claim you state, as `[source-id]`.
5. Close with a source list. Copy each row from `sources/index.md`.
6. Write a `## Limits` section. Name every question the run could not
   settle, and say what the run would need to settle it.

Write no claim that is not in the loaded set. A sentence that reads well
and cites nothing is the fault this step exists to avoid.

## Gate

The check reads `report.md`. It passes when every section maps to a
question, every cited source id appears in `sources/index.md`, and the
`## Limits` section is present.

## Outcome

This step has one way out. Return `report_path` and the run moves to
`review`.
