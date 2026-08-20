---
name: coverage
agent: researcher
model: opus
gate: deterministic
---

# Step: coverage

Input: the claim set and the question list. Output: a coverage row per
question at `coverage.jsonl`, plus `thin_questions`.

This step reads the plan against the claims. It never reads a source. It
asks one question: did the run answer what it set out to answer?

**This step does not map.** Mapping would make each instance read every
claim to answer one question. The step is cheap, so the read costs more
than the wait it saves.

## Procedure

1. Read `questions.md` and `claims.jsonl`.
2. Per question, count two numbers. Count the claims that answer it. Count
   the distinct `source_id` values behind those claims.
3. Write one row per question to `coverage.jsonl`:

   ```
   {"question":2,"rank":2,"claims":3,"sources":2,"state":"covered"}
   ```

4. Set `state` by these rules, in order.

   | Condition | State |
   |---|---|
   | No claim answers the question. | `thin` |
   | The question has rank 1 and one source. | `thin` |
   | Anything else. | `covered` |

   The highest-ranked question carries the report. One source behind it is
   not enough.
5. Build `thin_questions` from every row whose state is `thin`.

Count what is there. Do not judge whether a claim is true. `verify` runs
at the same time and owns that judgment.

## Gate

The check reads `coverage.jsonl`. It passes when the row count equals the
question count, every row carries all five keys, and every `state` is one
of the two allowed.

## Outcome

Return one of two labels.

| Label | When |
|---|---|
| `answered` | `thin_questions` is empty. The run waits at `joinchecks`. |
| `thin` | A question is thin. The run returns to `gather`. |

The `thin` edge leaves the fork region. Taking it cancels the other three
branches, because `gather` is about to change the claim set they read.
