---
name: crosscheck
agent: researcher
model: opus
reasoning_effort: high
gate: deterministic
---

# Step: crosscheck

Input: the claim set and the question list. Output: contradictions at
`contradictions.jsonl`.

`verify` asks whether one source holds one claim up. This step asks a
different question: do two sources tell the same story? A claim can pass
`verify` and still contradict a claim from another source. Both run at
once, and neither reads the other's output.

**This step does not map.** It compares claims to each other. An instance
holding one claim cannot see the claim that disagrees with it.

## Procedure

1. Read `claims.jsonl`. Group the claims by their `question` field.
2. Inside a group, compare every pair of claims whose `source_id` differs.
   Two claims from one source are not a cross-check.
3. Record a contradiction when the two claims cannot both be true. A
   difference in wording is not a contradiction. A difference in scope is
   not a contradiction.
4. Write one line per contradiction to `contradictions.jsonl`:

   ```
   {"id":"x1","question":2,"claim_a":"c3","claim_b":"c7","reason":"…"}
   ```

5. Write the file even when it is empty. An empty file is the clean result.

A pair that agrees is evidence, not a finding. Do not record it.

## Gate

The check reads `contradictions.jsonl`. It passes when every line carries
all five keys, and both `claim_a` and `claim_b` name ids that exist in
`claims.jsonl`.

## Outcome

This step has one way out. Return `contradictions_path`. The run waits at
`joinchecks` for the other three branches.
