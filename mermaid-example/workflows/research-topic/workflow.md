---
name: research-topic
description: Turns one topic into a source-backed report. Every claim traces to a primary source, and a step outside the writer checks each trace.
version: 1.0.0
entry: plan
terminals: [report]
inputs: [topic, source_floor]
outputs: [report_path]
max_step_visits: 3
---

# Workflow: research-topic

Input: a topic, plus `source_floor`, the least number of primary sources
the run accepts. Output: a report file whose every claim carries a checked
source.

The run splits the work three ways. One set of steps collects and reads
sources. A second set checks the claims against those sources. A third set
writes and edits the report. No step checks its own output.

## Graph

```mermaid
flowchart TD
    topic([topic in]) --> plan
    plan --> gather
    gather --> extract
    extract --> verify
    verify -- supported --> draft
    verify -- gaps --> gather
    draft --> review
    review -- problems --> revise
    review -- clean --> report([report out])
    revise --> review

    click plan "./steps/plan/step.md" "Turn the topic into research questions"
    click gather "./steps/gather/step.md" "Find and fetch primary sources"
    click extract "./steps/extract/step.md" "Pull claims, each traced to a source"
    click verify "./steps/verify/step.md" "Check each claim against its source"
    click draft "./steps/draft/step.md" "Write the report from supported claims"
    click review "./steps/review/step.md" "Review the draft against the sources"
    click revise "./steps/revise/step.md" "Fix the findings review raised"
```

`topic` and `report` carry no `click` line. They are markers, not steps.
They show what enters the run and what leaves it. The run starts at
`entry`, which is `plan`.

## Cycles

The graph holds two cycles.

| Cycle | Edge that opens it | What it repairs |
|---|---|---|
| Source gap | `verify -- gaps --> gather` | A claim with no source that holds it up. |
| Draft fault | `review -- problems --> revise` | A draft the sources do not support. |

`max_step_visits` is 3. The orchestrator counts visits per node and stops
the run at the cap. A topic that needs a fourth pass needs a person.

## Model split

`extract` runs on `sonnet`. `verify` runs on `opus`. `draft` runs on
`sonnet`. `review` runs on `opus`. A check never runs on the model class
that produced the work it checks.
