---
name: draft
agent: document-writer
model: sonnet
gate: deterministic
---

# Step: draft

Input: the question list, the claims, the source index, and the four
artifacts the parallel checks produced. Output: the report at `report.md`.

`joinchecks` waits for all four checks before this step runs, so every
artifact below is present. None of them is optional.

The `document-writer` agent owns the report's structure, its citation
format, and its prose rules. This step does not restate them. It says
which artifact feeds which part of the document.

## Procedure

1. Read `verdicts.jsonl` first. Load only the claims it marks `supported`.
   An `unsupported` claim never reaches the report.
2. Answer each question from the loaded claims, in rank order.
3. Read `contradictions.jsonl`. Put both sides of a disagreement in the
   section for its question.
4. Read `recency.jsonl`. Mark every `superseded` source at its citation,
   and put its `replaced_by` url in the source list.
5. Fill `## Limits` from three artifacts.

   | Artifact | What goes in Limits |
   |---|---|
   | `coverage.jsonl` | Every question whose state is `thin`. |
   | `contradictions.jsonl` | Every unresolved disagreement. |
   | `recency.jsonl` | Every source whose state is `unknown`. |

## Gate

The check reads `report.md`. It passes when every section maps to a
question, every cited source id appears in `sources/index.md`, and the
`## Limits` section is present.

## Outcome

This step has one way out. Return `report_path` and the run moves to
`review`.
