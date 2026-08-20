---
name: create-workflow
description: Create a workflow, or change one's topology, and leave it valid. The mermaid flowchart holds the graph, one `click` line binds each step node to its step.md, and every step folder carries the required frontmatter. Invoke when creating a workflow, adding, removing, or renaming a step, or rewiring edges. Skip when editing a step's prompt body without changing the graph; edit that step.md directly.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Create workflow

Input: a workflow to create, or a topology change to an existing one.
Output: a workflow folder that `check-workflow.sh` passes.

This skill enforces one shape. The graph carries the topology. The step
files carry the behavior. Neither carries the other.

## Layout

One folder per workflow. One folder per step.

```
workflows/<workflow-name>/
  workflow.md                    the canonical file
  steps/<step-name>/
    step.md                      frontmatter and prompt
    <script or asset>            optional files the step body names
```

A step folder follows the skill convention. The canonical file sits at the
root of the folder. Scripts, templates, and data sit beside it. A step body
names each file it uses by relative path.

## The graph

`workflow.md` holds exactly one mermaid block. The block is a `flowchart`.

Rules:

1. **A step is a node.** A step is never an edge label.
2. **A `click` line binds the node to its file.** The form is
   `click <node-id> "./steps/<node-id>/step.md" "<tooltip>"`. The node id
   and the folder name match.
3. **A node with a `click` line is a step.** A node with no `click` line is
   a terminal or a marker. Draw terminals with the stadium shape `([...])`.
4. **Node ids are single lowercase words.** Use `[a-z][a-z0-9]*`. A hyphen
   can read as part of an arrow, so avoid it.
5. **Edge labels are outcomes.** Label an edge only when a node has more
   than one way out. The label is the outcome the step returns.
6. **The graph holds no implementation.** No tool name, no command, no
   store name, no vendor name. A node names what the step does.

`click` is the reference. Do not add a separate list of step links. A
second list drifts from the graph.

Renderer note: mermaid disables `click` under `securityLevel: strict`, and
some hosts render with it. The `click` line stays the machine-readable
binding either way. The orchestrator reads it from the source.

## Workflow frontmatter

| Field | Required | Value |
|---|---|---|
| `name` | yes | The workflow name. Matches the folder name. |
| `description` | yes | One line. What the workflow takes in and gives out. |
| `version` | yes | Semantic version. |
| `entry` | yes | The node id the run starts at. |
| `terminals` | yes | List of node ids that end a run. |
| `inputs` | yes | Named values a caller supplies. |
| `outputs` | yes | Named values the run returns. |
| `max_step_visits` | yes | Visit cap per node. Bounds every cycle. |

## Step frontmatter

| Field | Required | Value |
|---|---|---|
| `name` | yes | The step name. Matches the folder name and the node id. |
| `description` | yes | One line. What this step does. |
| `agent` | yes | The subagent type that runs the step. |
| `model` | yes | `haiku`, `sonnet`, or `opus`. A class, never a version. |
| `reasoning_effort` | yes | `low`, `medium`, or `high`. |
| `gate` | yes | `none`, `deterministic`, `llm-judge`, or `human`. |
| `inputs` | yes | Named values the step reads. |
| `outputs` | yes | Named values the step returns. |
| `thinking_budget` | no | Extended thinking tokens. Default `0`, meaning off. |
| `tools` | no | Tool allowlist. Absent means the agent's own default. |
| `max_turns` | no | Turn cap for the spawn. |
| `isolation` | no | `none` or `worktree`. Default `none`. |

Set `model` and `reasoning_effort` to the smallest pair that does the job.
Raise them for judgment work. Lower them for lookup and bookkeeping.

An independent check never runs on the model class that produced the work.
Give a review or verify step a different `model` than the step it checks.

## Step body

The body is the prompt the orchestrator passes to the subagent. Open with
the contract in one short paragraph: what comes in, what goes out. Then
give the procedure. Close with the outcome labels the step can return.

Every outcome label the body names must match an outgoing edge label in
the graph. Every outgoing edge label must appear in the body.

## Procedure

1. **Name the steps.** Write one line per step: what it does, what it takes
   in, what it gives out. Reject any name that says how. A name like
   `fetch-with-curl` becomes `gather`. Done when every name states domain
   behavior only.
2. **Draw the graph.** Write the flowchart. Add the terminal nodes, the
   edges, and the outcome labels. Done when the block parses and every step
   node sits on at least one edge.
3. **Add the `click` lines.** One per step node, at the end of the block.
   Done when each path reads `./steps/<node-id>/step.md`.
4. **Write the workflow frontmatter.** Fill every required field. Done when
   `entry` and each entry in `terminals` name real nodes.
5. **Write each step folder.** Create `steps/<name>/step.md` with the
   frontmatter table's required fields and a body. Add any script the body
   names into the same folder. Done when step folders and `click` lines
   match one to one.
6. **Check.** Run `./check-workflow.sh <path-to-workflow-folder>` from this
   skill's folder. Done on exit 0.

## Refusals

Stop and report, rather than write, when any of these hold:

- A node id needs a hyphen or a capital letter.
- A step node needs two step files, or two nodes need one file.
- The graph needs a tool name or a command to make sense.
- A cycle has no `max_step_visits` cap to bound it.
