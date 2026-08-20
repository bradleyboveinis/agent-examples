---
name: plan
description: Turns a topic into research questions and names the source type that answers each one.
agent: planner
model: sonnet
reasoning_effort: medium
thinking_budget: 0
tools: [Read, Write]
max_turns: 6
isolation: none
gate: deterministic
inputs: [topic, source_floor]
outputs: [questions_path]
---

# Step: plan

Input: a topic and a source floor. Output: a question list at
`questions.md`. Each question names the source type that can answer it.

## Procedure

1. Split the topic into questions a source can settle. A question that
   needs an opinion is out of scope. Drop it.
2. Write at least three questions. Write more when the topic holds more.
3. Name one source type per question. Use a primary type: a specification,
   a standard, a filing, a dataset, a vendor document, or a paper. Never
   name a summary site or an aggregator.
4. Rank the questions. The first question is the one the report cannot do
   without.
5. Write `questions.md`. Use one row per question:
   `| rank | question | source type |`.

## Gate

The check reads `questions.md`. It passes when the file holds three or
more rows, every row carries all three columns, and every rank is unique.

## Outcome

This step has one way out. Return `questions_path` and the run moves to
`gather`.
