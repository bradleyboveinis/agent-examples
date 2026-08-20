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
  evals/                         eval cases for the workflow
  steps/<step-name>/
    step.md                      frontmatter and prompt
    evals/                       eval cases for this step
    tests/                       only when the folder holds code
    <script or asset>            optional files the step body names
```

A step folder follows the skill convention. The canonical file sits at the
root of the folder. Scripts, templates, and data sit beside it. A step body
names each file it uses by relative path.

Two folder rules, and they are simple:

- **Every prompt unit has `evals/`.** A step, a workflow, an agent, and a
  skill are all prompt units. An eval case gives the unit an input and
  judges the output against a rubric.
- **Every folder holding code has `tests/`.** Prompts get evals. Code gets
  tests. A step folder with a script gets both.

## The graph

`workflow.md` holds exactly one mermaid block. The block is a `flowchart`.

Rules:

1. **A step is a node.** A step is never an edge label.
2. **A `click` line binds the node to its file.** The form is
   `click <node-id> "./steps/<node-id>/step.md"`, and nothing more. The
   node id and the folder name match. No tooltip: a tooltip is a second
   home for the label, and most renderers never show it.
3. **A node with a `click` line is a step.** A node with no `click` line is
   a marker. Draw a start or end marker with the stadium shape `([...])`.
4. **Node ids are single lowercase words.** Use `[a-z][a-z0-9]*`. A hyphen
   can read as part of an arrow, so avoid it. The id is a machine handle,
   not a description.
5. **Every step node carries a plain-English label.** Declare the node
   before the edges: `plan["Turn the topic into ranked research
   questions"]`. Then edges reference the bare id. Write what happens at
   that step, in words a reader who knows nothing can follow. Three words
   is the floor, and the lint enforces it. A diagram of bare ids says the
   order and hides the work.
6. **Edge labels stay short.** Label an edge only when a node has more
   than one way out. An edge label is not prose: a step returns it as its
   outcome, and frontmatter names it to break a tie. Keep it one or two
   words. The node labels carry the explanation.
7. **The graph holds no implementation.** No tool name, no command, no
   store name, no vendor name. A label says what happens, never how.
8. **A fork marker splits the run.** Its id starts with `fork`. Every
   outgoing edge starts at once, and none of them carries a label. Draw it
   with the hexagon shape `{{...}}`.
9. **A join marker waits.** Its id starts with `join`. It has two or more
   incoming edges and exactly one outgoing edge. Draw it with `{{...}}`.
10. **A merge marker takes the first arrival.** Its id starts with `merge`.
    It has two or more incoming edges and exactly one outgoing edge, like a
    join, and it waits for none of them. Every edge into it carries a
    label, because each one names the outcome that turned the run around.
    Draw it with `{{...}}`.
11. **Two incoming edges make neither.** Alternative ways into a step are
    ordinary edges. Only a marker changes how arrivals are treated.

`click` is the reference. Never hand-write a second list of step links
inside `workflow.md`. A hand-written list drifts from the graph.

## The README step index

A `click` does not resolve on GitHub, so a reader cannot reach a step file
from the picture. The fix is one table in the repository `README.md`,
under a `## Step index` heading, with one row per step:

```
| <workflow> | [<id>](./workflows/<workflow>/steps/<id>/step.md) | <node label> |
```

The lint rebuilds every row from the graph and compares it. Three things
are an error: a stale row, a missing row, and a row for a step that no
longer exists. The error prints the exact line the row must be.

This is a second list of step links, which the rule above forbids inside
`workflow.md`. The two are different. The ban is on knowledge that two
people can edit apart from each other. A derived copy that a check holds
to its source cannot drift, so it is not a second home.

Keep it in `README.md`, never in `workflow.md`. A run reads `workflow.md`,
so a stale line there changes behavior. Nothing reads the README during a
run.

## The workflow file restates nothing

`workflow.md` holds frontmatter, one mermaid block, and the little prose
that neither can carry. Everything else has a home already.

| Knowledge | Its one home |
|---|---|
| What runs after what | The mermaid block. |
| A step's agent, model, gate, or fan-out | That step's frontmatter. |
| What a step does, and why it does or does not map | That step's body. |
| How a fork, a join, or a mapped step is run | The orchestrator agent. |
| The cycle bound | The workflow frontmatter. |

A table in `workflow.md` listing steps against their models, their caps, or
their branches is the failure this rule exists to stop. It reads well on
the day it is written. It goes stale the first time someone tunes a step,
and then two files disagree with no way to tell which is right.

The lint enforces this. It reads the prose outside the frontmatter and
the diagram. There, a backticked step name is an error. So is a backticked
`model` class, or a backticked fan-out field name. A plain English word is
fine, because the check looks for deliberate references only.

Narrative belongs in `README.md`, which documents the example for a
person and is never read during a run.

Renderer note: on GitHub the click fires and the relative path does not
resolve. GitHub draws the diagram in a sandboxed frame, so the path
resolves against that frame. The `click` line stays the machine-readable
binding, and the README step index carries the links a reader can follow.

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

Frontmatter holds what an author tweaks. Everything else lives in the
agent the step names, or in the step body. Four fields are required.

| Field | Required | Value |
|---|---|---|
| `name` | yes | The step name. Matches the folder name and the node id. |
| `agent` | yes | Resolves to `agents/<name>/agent.md`. |
| `model` | yes | `haiku`, `sonnet`, or `opus`. A class, never a version. |
| `gate` | yes | `none`, `deterministic`, `llm-judge`, or `human`. |
| `reasoning_effort` | no | `low`, `medium`, or `high`. Default is the agent's. |
| `map_over` | no | The input holding a list. One spawn per item. |
| `max_concurrency` | no | Cap on spawns at once. Required with `map_over`. |
| `outcome_precedence` | no | Reduces instance outcomes to one. See below. |

Four things that are **not** frontmatter, and where they live instead:

| Not here | Lives in |
|---|---|
| The tool allowlist | The agent. |
| Output format and prose rules | The agent. |
| The step's inputs and outputs | The step body's opening lines. |
| The routing | The graph. |

Set `model` and `reasoning_effort` to the smallest pair that does the job.
Raise them for judgment work. Lower them for lookup and bookkeeping.

An independent check never runs on the model class that produced the work.
Give a review or verify step a different `model` than the step it checks.

## Assigning an agent

A step names an agent, never a bare model. The agent carries what holds
across every step that names it: the tool allowlist, the standing rules,
the default model.

Write a new agent when two or more steps need the same standing rules.
`research-topic` shows both shapes. Eight steps share `researcher`, which
owns source quality, quoting, and how to report a check that could not
run. Two steps share `document-writer`, which owns the report's structure,
citation format, and prose.

The gain is one home per rule. Change the citation format in
`document-writer`, and both `draft` and `revise` change with it. A step
that restates an agent's rule has made a second home for it. Delete the
restatement and point at the agent.

## Mapping a step

`map_over` names an input that holds a list. The orchestrator spawns one
subagent per item, up to `max_concurrency` at a time.

**Map only when the items are independent.** Ask one question: can an
instance do its work seeing one item and nothing else? A no means the step
does not map. Two failures to watch for:

| Failure | Example |
|---|---|
| The step needs a whole-set view. | A step that removes duplicates across items. |
| The step compares items to each other. | A step that finds contradictions between items. |

Write the reason in the step body when a step could look mappable and is
not. The next author will ask.

A mapped step with more than one way out needs `outcome_precedence`. It
lists the outcome labels in the order that decides. The orchestrator reads
it left to right and takes the first label any instance returned. Put the
label that stops the happy path first.

## Branches that leave early

A fork's branch does not have to reach the join. One that finds a fault
takes a labelled edge out of the fork region, and the run turns around.

Route every such edge into one `merge` marker, then one edge from the
merge to wherever the run resumes. Two gains, and only one is cosmetic:

- **The picture stays readable.** Two long return edges sweeping past the
  whole fan-out become two short hops and one clean return.
- **Cancellation becomes visible.** The merge marker is where the run
  turns around. Without it, that fact lives only in prose, and prose is
  the thing this skill keeps moving out of the graph.

Order the fork's outgoing edges so the branches that can leave early sit
next to each other. The layout engine keeps them adjacent, and the return
edges stop crossing the branches that always reach the join.

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
2. **Find the parallel work.** Two questions per step. Does it repeat the
   same work over a list of independent items? Then map it. Does it need
   nothing another step produces? Then it can share a fork with that step.
   Done when every step is marked sequential, mapped, or forked.
3. **Draw the graph.** Declare every node with its plain-English label
   first, then write the edges by bare id, then the outcome labels. Pair
   every fork with a join. Where branches leave the fork early, gather
   them into one merge marker rather than running each back on its own
   long edge. Done on three conditions. The block parses. Every step
   node sits on at least one edge. A reader who knows nothing about the
   domain can say what the run does from the picture alone.
4. **Add the `click` lines.** One per step node, at the end of the block.
   A fork or join marker gets none. Done when each path reads
   `./steps/<node-id>/step.md`.
5. **Write the workflow frontmatter.** Fill every required field. Done when
   `entry` and each entry in `terminals` name real nodes.
6. **Assign the agents.** Give each step an `agent`. Write a new agent when
   two or more steps need the same standing rules. Done when every `agent`
   resolves to a file, and no step restates a rule its agent holds.
7. **Write each step folder.** Create `steps/<name>/step.md` with the four
   required fields and a body. Add `evals/`. Add `tests/` when the folder
   holds a script. Done when step folders and `click` lines match one to
   one.
8. **Update the README step index.** One row per step, in the order the
   `click` lines run. Done when every row matches the graph.
9. **Check.** Run `./check-workflow.sh <path-to-workflow-folder>` from this
   skill's folder. The lint prints the exact row for any index line that
   is missing or stale, so a failure is a copy and paste to fix. Done on
   exit 0.

## Refusals

Stop and report, rather than write, when any of these hold:

- A node id needs a hyphen or a capital letter.
- A step node needs two step files, or two nodes need one file.
- The graph needs a tool name or a command to make sense.
- A cycle has no `max_step_visits` cap to bound it.
- A step maps over items that are not independent.
- A fork branch writes a file another branch on the same fork writes.
- A step names an agent that has no file.
- A step restates a rule its agent already holds.
- `workflow.md` restates what the graph or a step's frontmatter carries.
