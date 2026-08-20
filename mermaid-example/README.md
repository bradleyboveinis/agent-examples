# mermaid-example

A worked example of a workflow whose topology lives in a mermaid graph.
The graph binds each step to its file with a mermaid `click` line. No
second list of links exists, so nothing can drift out of sync.

## What is here

| Unit | Path | What it does |
|---|---|---|
| Agent | `agents/orchestrator/agent.md` | Reads a workflow graph and runs it. |
| Skill | `skills/create-workflow/SKILL.md` | Creates a workflow in the shape the agent reads. |
| Workflow | `workflows/research-topic/workflow.md` | Turns a topic into a source-backed report. |

The agent reads the shape. The skill writes the shape. The workflow is one
instance of it. The skill built the workflow, so the example checks its own
rules.

## The shape

```
workflows/<workflow-name>/
  workflow.md                    frontmatter, prose, one mermaid flowchart
  steps/<step-name>/
    step.md                      frontmatter and prompt
    <script or asset>            optional files the step body names
```

A step folder follows the skill convention. The canonical file sits at the
root of the folder. Scripts and data sit beside it. The `extract` step
shows this: it ships `check-claims.sh`, and its body names the script by
relative path.

## Why `click`

Mermaid binds a node to a target with one line inside the diagram:

```
click gather "./steps/gather/step.md" "Find and fetch primary sources"
```

This gives three things at once.

1. **One source of truth.** The graph names the step and locates its file
   in the same line.
2. **A reader can navigate.** A renderer with `securityLevel: loose` turns
   the node into a link.
3. **A machine can navigate.** The orchestrator parses the same line. It
   never guesses a path from a node id.

A node with a `click` line is a step. A node without one is a marker, drawn
with the stadium shape `([...])`. This is how the orchestrator tells a step
from a start or an end.

Mermaid supports `click` in `flowchart` on every renderer. Support in
`stateDiagram-v2` arrived later and is uneven. This example uses
`flowchart` for that reason.

Some hosts render mermaid with `securityLevel: strict` and drop the link.
The line still holds the binding, and the orchestrator reads it from the
source either way.

## Step frontmatter

Each step declares how to run it. `SKILL.md` holds the full table. The
fields in short:

| Field | Value |
|---|---|
| `agent` | The subagent type to spawn. |
| `model` | `haiku`, `sonnet`, or `opus`. A class, never a version. |
| `reasoning_effort` | `low`, `medium`, or `high`. |
| `thinking_budget` | Extended thinking tokens. `0` means off. |
| `tools` | The tool allowlist for the spawn. |
| `max_turns` | The turn cap for the spawn. |
| `isolation` | `none`, or `worktree` for a spawn that edits files. |
| `gate` | `none`, `deterministic`, `llm-judge`, or `human`. |
| `inputs` / `outputs` | The step's contract. |

## Run the check

```
bash skills/create-workflow/check-workflow.sh workflows/research-topic
```

It reads the graph, the `click` lines, the step folders, and both sets of
frontmatter. Exit 0 means the workflow matches the shape.

```
bash skills/create-workflow/check-workflow.sh workflows
```

The same script checks every workflow under a parent folder.

## Wire it into a harness

The files here are canonical units, not harness config. Point the harness
at them:

1. Add `.claude/agents/orchestrator.md` at your repo root. Give it the
   agent frontmatter, and a body that reads
   `mermaid-example/agents/orchestrator/agent.md`.
2. Add `.claude/skills/create-workflow/` at your repo root, or copy
   `skills/create-workflow/` there.
3. Run the orchestrator against a workflow path.

## Writing style

Every markdown file here follows adapted STE100: short sentences, active
voice, one idea per sentence, and one word per meaning.
