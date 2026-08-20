---
name: extract
description: Pulls claims out of the stored sources and ties each claim to one quoted source line.
agent: analyst
model: sonnet
reasoning_effort: medium
thinking_budget: 0
tools: [Read, Write, Bash]
max_turns: 20
isolation: none
gate: deterministic
inputs: [questions_path, sources_dir, source_index_path]
outputs: [claims_path]
---

# Step: extract

Input: the question list and the stored sources. Output: a claim set at
`claims.jsonl`. Each claim carries the source it came from and the exact
words that carry it.

## Procedure

1. Read `questions.md` and `sources/index.md`.
2. Read each stored source file in full. Read the stored text, never the
   live page. The stored text is what the verify step checks against.
3. Write one claim per fact the source states. Keep the claim to one
   sentence.
4. Quote the source line the claim rests on. Copy the words exactly. A
   claim you cannot quote does not get written.
5. Write one JSON object per line to `claims.jsonl`:

   ```
   {"id":"c1","question":1,"source_id":"rfc9110","quote":"…","claim":"…"}
   ```

6. Run `./check-claims.sh claims.jsonl sources` from this step's folder.
   Fix every finding it prints.

A claim that two sources state gets two lines, one per source. Agreement
between sources is evidence. Merging the two lines throws it away.

## Gate

The check runs `check-claims.sh`. It passes on exit 0.

## Outcome

This step has one way out. Return `claims_path` and the run moves to
`verify`.
