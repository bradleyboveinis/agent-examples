---
name: recency
agent: researcher
model: haiku
reasoning_effort: low
gate: deterministic
map_over: sources
max_concurrency: 4
---

# Step: recency

Input: **one** stored source and its index row. Output: that source's
recency row, appended to `recency.jsonl`.

A source can hold a claim up and still be out of date. A specification
gets obsoleted. A filing gets amended. A dataset gets a later release.
This step finds that, and it reads no claim.

This step maps. One instance handles one source. A source has its own
version history, so the instances need nothing from each other.

## Procedure

1. Read your source's row in `sources/index.md`. Take its title,
   publisher, and url.
2. Look for a later version from the same publisher. Look for an obsoletes
   notice, a superseded banner, an amendment, or a higher version number.
3. Write one row to `recency.jsonl`:

   ```
   {"source_id":"rfc9110","state":"current","replaced_by":null,"checked":"2026-08-20"}
   ```

4. Set `state` to one of three values.

   | Condition | State |
   |---|---|
   | No later version exists. | `current` |
   | A later version exists. | `superseded` |
   | The publisher gives no version signal. | `unknown` |

5. Fill `replaced_by` with the later version's url on `superseded`. Leave
   it null otherwise.

The `researcher` agent's never-guess rule applies here. Do not read
`current` out of finding nothing, and do not read `superseded` out of a
page that looks old.

## Gate

The orchestrator merges the instance rows in source-index order. The check
passes on three conditions. The row count equals the source count. Every
`state` is one of the three allowed. Every `superseded` row carries a
`replaced_by` url.

## Outcome

This step has one way out. Return `recency_path`. The run waits at
`joinchecks` for the other three branches.
