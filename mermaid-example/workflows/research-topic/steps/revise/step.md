---
name: revise
agent: document-writer
model: sonnet
gate: deterministic
---

# Step: revise

Input: the report and the review findings. Output: the edited report, plus
a log at `revisions.jsonl` holding one entry per finding.

## Procedure

1. Read `findings.jsonl`. Handle every finding. Handle no other thing.
2. Pick one action per finding.

   | Finding | Action |
   |---|---|
   | Uncited | Cite the supported claim, or cut the sentence. |
   | Unsupported | Cut the sentence. Add the question to `## Limits`. |
   | Overreach | Narrow the sentence to what the claim says. |
   | Missing limit | Add the question to `## Limits`. |

3. Never add a claim to fix a finding. This step has no sources and no
   search tools. A gap that needs a new source is a gap for `## Limits`.
4. Log each finding to `revisions.jsonl`:

   ```
   {"finding_id":"f1","action":"narrowed","before":"…","after":"…"}
   ```

5. Decline a finding only when the report quote is already gone. Log it
   with `"action":"declined"` and the reason.

## Gate

The check pairs `revisions.jsonl` against `findings.jsonl`. It passes when
every finding id appears once in the log, and every logged `before` string
is absent from the edited report.

## Outcome

This step has one way out. Return the edited `report_path` and the run
returns to `review`. The review step reads the edited report with no memory
of this edit, so the fix is checked, not asserted.
