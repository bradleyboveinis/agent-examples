---
name: review
agent: researcher
model: opus
reasoning_effort: high
gate: deterministic
---

# Step: review

Input: the report, the claim set, the verdicts, and the stored sources.
Output: findings at `findings.jsonl`.

You run on a different model class than the step that wrote the report.
Your job is to find fault, not to agree.

## Procedure

1. Read `report.md` sentence by sentence.
2. Raise a finding when a sentence fails any of these.
   - **Uncited.** The sentence states a fact and cites no source.
   - **Unsupported.** The cited claim is `unsupported` in `verdicts.jsonl`.
   - **Overreach.** The sentence says more than its claim says.
   - **Missing limit.** A question the run could not settle is absent from
     `## Limits`.
3. Write one finding per line to `findings.jsonl`:

   ```
   {"id":"f1","kind":"overreach","report_quote":"…","source_quote":"…","reason":"…"}
   ```

4. Quote both sides, under the `researcher` agent's quoting rules.
5. Write `findings.jsonl` even when it is empty. An empty file is the clean
   result.

Wording is out of scope. The `document-writer` agent owns the report's
prose rules, and it wrote this draft. Raise a finding on evidence, never
on a phrasing you would have chosen.

## Gate

The check reads `findings.jsonl`. It passes when every line carries all
five keys, every `kind` is one of the four named above, and every
`report_quote` appears in `report.md`.

## Outcome

Return one of two labels.

| Label | When |
|---|---|
| `clean` | `findings.jsonl` is empty. The run reaches `report`. |
| `problems` | The file holds a finding. The run moves to `revise`. |
