---
name: verify
agent: researcher
model: opus
reasoning_effort: high
gate: llm-judge
map_over: claims
max_concurrency: 6
outcome_precedence: [gaps, supported]
---

# Step: verify

Input: **one** claim and the stored sources. Output: that claim's verdict,
appended to `verdicts.jsonl`, plus `gaps` when the claim fails.

You did not write this claim, and you get no note from the step that did.
That is the design. This is an independent check, not a self-review.

This step maps. One instance checks one claim against one source, so the
instances need nothing from each other. Three other checks run beside this
one. You never read their output.

## Procedure

1. Read your claim and the source file it names.
2. Run three tests on it.
   - **Quote test.** The quote appears in the named source, word for word.
   - **Support test.** The quote carries the claim. A quote on the same
     subject is not support.
   - **Reach test.** The source is a primary source for this claim.
3. Write one verdict line for your claim to `verdicts.jsonl`:

   ```
   {"id":"c1","verdict":"supported","reason":"…","producer_model":"sonnet"}
   ```

   The verdict is `supported` or `unsupported`. Nothing else.
4. Mark the claim `unsupported` when any test fails. Give the reason in
   the words of the failing test.
5. A source that no longer loads is `unreachable` under the `researcher`
   agent's three-state rule. Mark the claim `unsupported` with reason
   `source unreachable`.
6. Set `gaps` to your claim's question when the verdict is `unsupported`.
   Leave it empty otherwise.

You judge one claim. You cannot see whether another claim answers the same
question, and you do not need to. `coverage` runs beside you and owns the
question-level count.

## Gate

An llm-judge reads the rubric and the merged `verdicts.jsonl`. It never
reads your reasoning. The gate passes on three conditions. Every claim id
carries one verdict. Every `unsupported` verdict names a failing test. No
verdict uses a word outside the two allowed.

## Outcome

Return one of two labels. `outcome_precedence` puts `gaps` first, so one
unsupported claim among many sends the whole step down the `gaps` edge.

| Label | When |
|---|---|
| `supported` | Your claim passed all three tests. |
| `gaps` | Your claim failed a test. Its source cannot hold it up. |

The `gaps` edge leaves the fork region. Taking it cancels the other three
branches and returns the run to `gather` for a better source.
