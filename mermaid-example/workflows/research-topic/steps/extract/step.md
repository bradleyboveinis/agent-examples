---
name: extract
agent: researcher
model: sonnet
gate: deterministic
map_over: sources
max_concurrency: 4
---

# Step: extract

Input: the question list and **one** stored source. Output: that source's
claims, appended to `claims.jsonl`. Each claim carries the source it came
from and the exact words that carry it.

This step maps. One instance reads one source. A source reads on its own,
so the instances need nothing from each other.

## Procedure

1. Read `questions.md` and the row for your source in `sources/index.md`.
2. Read your source file in full. Read the stored text, never the live
   page. The stored text is what the verify step checks against.
3. Write one claim per fact the source states. Keep the claim to one
   sentence.
4. Quote the source line the claim rests on, under the `researcher`
   agent's quoting rules.
5. Write one JSON object per line to `claims.jsonl`:

   ```
   {"id":"c1","question":1,"source_id":"rfc9110","quote":"…","claim":"…"}
   ```

   Prefix every claim id with your source id, as `rfc9110-c1`. Two
   instances run at once and must not pick the same id.

6. Run `./check-claims.mjs claims.jsonl sources` from this step's folder.
   Fix every finding it prints.

Claim only what your own source states. Another source may state the same
fact, and its instance writes its own line for it. Agreement between
sources is evidence, and the crosscheck step reads those pairs.

## Gate

The orchestrator merges the instance outputs in source-index order, then
runs `check-claims.mjs` on the merged file. It passes on exit 0.

## Outcome

This step has one way out. Return `claims_path` and the run moves to
`verify`.
