# mermaid-example

A worked example of a workflow whose topology lives in a mermaid graph.
The graph binds each step to its file with a mermaid `click` line. A lint
holds every other copy of that knowledge to the graph, so nothing here
drifts by hand.

## What is here

| Unit | Path | What it does |
|---|---|---|
| Agent | `agents/orchestrator/agent.md` | Reads a workflow graph and runs it. |
| Agent | `agents/researcher/agent.md` | Owns the evidence rules eight steps share. |
| Agent | `agents/document-writer/agent.md` | Owns the report's structure and prose. |
| Skill | `skills/create-workflow/SKILL.md` | Creates a workflow in the shape the orchestrator reads. |
| Workflow | `workflows/research-topic/workflow.md` | Turns a topic into a source-backed report. |

The orchestrator reads the shape. The skill writes the shape. The workflow
is one instance of it. The skill built the workflow, so the example checks
its own rules.

## Step index

GitHub does not resolve a `click`, so these links are how a reader reaches
a step file. See [Why `click`](#why-click) for what breaks.

The lint rebuilds every row from the graph and compares it. A row that
falls behind is an error, so this table cannot go stale.

| Workflow | Step | What happens there |
|---|---|---|
| research-topic | [plan](./workflows/research-topic/steps/plan/step.md) | Turn the topic into ranked research questions |
| research-topic | [gather](./workflows/research-topic/steps/gather/step.md) | Find and store the primary sources that answer them |
| research-topic | [extract](./workflows/research-topic/steps/extract/step.md) | Pull claims out of each source, tied to a quoted line |
| research-topic | [verify](./workflows/research-topic/steps/verify/step.md) | Check whether each claim's own source holds it up |
| research-topic | [crosscheck](./workflows/research-topic/steps/crosscheck/step.md) | Find claims from different sources that disagree |
| research-topic | [coverage](./workflows/research-topic/steps/coverage/step.md) | Find planned questions that no claim answers |
| research-topic | [recency](./workflows/research-topic/steps/recency/step.md) | Find stored sources that a newer version replaced |
| research-topic | [draft](./workflows/research-topic/steps/draft/step.md) | Write the report from the claims that survived |
| research-topic | [review](./workflows/research-topic/steps/review/step.md) | Read the report back against the sources |
| research-topic | [revise](./workflows/research-topic/steps/revise/step.md) | Fix what the review found, and change nothing else |

This is a second list of step links, which the graph rules otherwise
forbid. It is allowed here for one reason: a machine writes it, and the
lint checks it. The ban is on knowledge that two people can edit
separately, not on a derived copy.

## The shape

```
mermaid-example/
  agents/<agent-name>/
    agent.md                     frontmatter and standing rules
    evals/                       eval cases
  skills/<skill-name>/
    SKILL.md                     the skill
    evals/                       eval cases
    tests/                       only when the folder holds code
  workflows/<workflow-name>/
    workflow.md                  frontmatter, prose, one mermaid flowchart
    evals/                       eval cases
    steps/<step-name>/
      step.md                    frontmatter and prompt
      evals/                     eval cases
      tests/                     only when the folder holds code
      <script or asset>          optional files the step body names
```

A step folder follows the skill convention. The canonical file sits at the
root of the folder. Scripts and data sit beside it. The `extract` step
shows this: it ships `check-claims.mjs`, and its body names the script by
relative path.

Two folder rules cover the rest:

- **Every prompt unit has `evals/`.** Steps, workflows, agents, and skills
  are all prompt units.
- **Every folder holding code has `tests/`.** Prompts get evals. Code gets
  tests. `steps/extract/` holds a script, so it has both.

Every `evals/` and `tests/` folder here holds a placeholder README naming
what belongs there. This is a shape demo, so no case is written.

## Agents hold the shared rules

A step names an agent. It never names a tool, an output format, or a prose
rule. Those live in the agent, so that one change reaches every step that
names it.

| Agent | Steps | What it owns |
|---|---|---|
| `researcher` | eight | Source quality, quoting, three-state reachability, never guess. |
| `document-writer` | `draft`, `revise` | Report structure, citation format, prose. |

`document-writer` is the clearest case. Two steps produce the report:
`draft` writes it and `revise` edits it. Both need the same output rules.
Putting those rules in the agent gives them one home. Change the citation
format there, and both steps change with it.

A step that restates a rule its agent holds has made a second home for it.
The skill's refusal list rejects that.

## Labels say what happens, ids are handles

A node carries two things, and they do different jobs. Declare the label
first, then reference the bare id in the edges:

```
gather["Find and store the primary sources that answer them"]
...
plan --> gather
```

The **label** is plain English. It is what a reader sees, and it is the
one home for what that step does. The lint requires at least three words,
so a diagram of bare ids cannot ship.

The **id** is a machine handle. It matches the folder name and the `click`
target, and it appears nowhere else.

Edge labels are the exception. They stay one or two words, because a step
returns one as its outcome and frontmatter names it to break a tie.

## Why `click`

Mermaid binds a node to its file with one line inside the diagram:

```
click gather "./steps/gather/step.md"
```

No tooltip. The node label already says what the step does, and a tooltip
would be a second home for it that most renderers never show.

The `click` line gives two things at once.

1. **One source of truth.** The graph names the step and locates its file
   in the same line.
2. **A machine can navigate.** The orchestrator parses that line. It never
   guesses a path from a node id.

A node with a `click` line is a step. A node without one is a marker. This
is how the orchestrator tells a step from a start, an end, or a fork.

Mermaid supports `click` in `flowchart` on every renderer. Support in
`stateDiagram-v2` arrived later and is uneven. This example uses
`flowchart` for that reason.

### It does not work on GitHub

On GitHub the click fires and the link does not resolve. GitHub draws the
diagram inside a sandboxed frame, so `./steps/plan/step.md` resolves
against that frame instead of the repository. The reader lands on a
missing page.

An absolute url would resolve. It would also tie this file to one
repository and one branch, which breaks a fork and breaks any other
branch. So the relative path stays, and the
[step index](#step-index) carries the working links.

## Parallel work

The example runs steps at the same time in two ways. They compose, and the
orchestrator knows both.

This section names steps and their settings. `workflow.md` may not, and
the lint stops it. The difference is what reads the file. A run reads
`workflow.md`, so a stale sentence there changes behavior. Nothing reads
this README during a run, so it is free to tell the story. Treat it as a
tour that can fall behind, and treat the graph and the step files as the
truth.

**Fork and join.** A marker whose id starts with `fork` starts every
outgoing edge at once. A marker whose id starts with `join` waits for every
branch, then takes its one outgoing edge. Draw both with `{{...}}`.

`research-topic` forks four checks over the same claim set:

| Branch | Question it asks |
|---|---|
| `verify` | Does the cited source hold this claim up? |
| `crosscheck` | Do two sources contradict each other? |
| `coverage` | Does every question have a claim? |
| `recency` | Has a newer version replaced this source? |

**Merge.** Two of the four can leave the fork region early, on a labelled
edge. Both route into one marker whose id starts with `merge`. A merge
never waits. The first branch to reach it wins. The orchestrator cancels
the other three, and the run takes the merge's one outgoing edge.

| Marker | Arrivals it needs | What it does with the rest |
|---|---|---|
| `join` | All of them. | Nothing to cancel. Carries every branch's outputs forward. |
| `merge` | The first one. | Cancels them, and discards their results. |

The merge earns its place twice over. It keeps two long return edges from
sweeping past the whole fan-out. It also puts cancellation in the picture
rather than in prose, and prose is what this example keeps moving out of
the graph.

Two incoming edges make neither. Alternative ways into a step are ordinary
edges. Only a marker changes how arrivals are treated.

**Map fan-out.** A step whose frontmatter names `map_over` runs once per
item in that input, capped by `max_concurrency`. `extract` maps over
sources, `verify` over claims, `recency` over sources.

Map only when the items are independent. Four steps here stay sequential on
purpose, and each says why in its own body. `crosscheck` is the clearest
case: it compares claims to each other, so an instance holding one claim
cannot see the claim that disagrees with it.

A mapped step with more than one way out needs `outcome_precedence`. It
lists the outcome labels in the order that decides.

## One subagent per step run

The orchestrator spawns a new subagent for every step run. It never reuses
one. Five rules make this exact:

1. Each step run gets its own spawn, which ends when the step returns.
2. A second visit to a node, through a cycle, is a fresh subagent with no
   memory of the first visit.
3. A mapped step spawns one subagent per item. The instances share no
   context.
4. An `llm-judge` gate runs in its own subagent, never inside the worker
   it judges.
5. Only declared outputs cross a boundary. No step reads another step's
   reasoning, and none reads the orchestrator's.

Rule 5 is what makes an independent check independent. A review step reads
the artifact, not the account of how the artifact was made.

## The workflow file restates nothing

`workflow.md` holds frontmatter, one mermaid block, and the little prose
that neither can carry. Everything else has a home already.

| Knowledge | Its one home |
|---|---|
| What runs after what | The mermaid block. |
| A step's agent, model, gate, or fan-out | That step's frontmatter. |
| What a step does | Its node label, and that step's body. |
| How a fork, a join, or a mapped step is run | The orchestrator agent. |
| The cycle bound | The workflow frontmatter. |

The file once carried six sections restating that: a branch table, a
fan-out table, a cycles table, an agents table, and a model split. They
read well and went stale on the first tuned step. They are gone.

The lint keeps them out. It reads the prose outside the frontmatter and
the diagram. There, a backticked step name is an error. So is a backticked
model class, or a backticked fan-out field name. A plain English word is
fine, because the check looks for deliberate references only.

## Step frontmatter

Frontmatter holds what an author tweaks, and nothing else. Four fields are
required, four are optional.

| Field | Required | Value |
|---|---|---|
| `name` | yes | Matches the folder name and the node id. |
| `agent` | yes | Resolves to `agents/<name>/agent.md`. |
| `model` | yes | `haiku`, `sonnet`, or `opus`. Overrides the agent's default. |
| `gate` | yes | `none`, `deterministic`, `llm-judge`, or `human`. |
| `reasoning_effort` | no | `low`, `medium`, or `high`. Default is the agent's. |
| `map_over` | no | The input holding a list. One spawn per item. |
| `max_concurrency` | no | Cap on spawns at once. Required with `map_over`. |
| `outcome_precedence` | no | Reduces a mapped step's instance outcomes to one. |

Most steps carry the four required fields and stop. The linter rejects any
other key, and names where it belongs instead:

| Not in frontmatter | Lives in |
|---|---|
| The tool allowlist | The agent. |
| Output format and prose rules | The agent. |
| The step's inputs and outputs | The step body's opening lines. |
| The routing | The graph. |

## Run the check

```
bash skills/create-workflow/check-workflow.sh workflows/research-topic
```

Exit 0 means the workflow matches the shape. The script checks:

| Area | What it holds to |
|---|---|
| The diagram | One mermaid flowchart, one edge per line, no implementation words. |
| Nodes | A step id is a lowercase word. A step node carries a label of three words or more. |
| Binding | One `click` per step node, no tooltip, resolving to `./steps/<id>/step.md`. |
| Control markers | A fork has two or more unlabelled exits. A join and a merge each have two or more entries and one exit. Every edge into a merge is labelled. |
| Step frontmatter | The four required fields, valid values, and no key that belongs elsewhere. |
| Agents | Every `agent` resolves to a file. |
| Folders | Every unit has `evals/`. Every folder with code has `tests/`. |
| Restatement | No step name, model class, or fan-out field in `workflow.md` prose. |
| Step index | Every row of this README's index matches the graph, and there are no extras. |

```
bash skills/create-workflow/check-workflow.sh workflows
```

The same script checks every workflow under a parent folder.

The step folder `steps/extract/` ships its own `check-claims.mjs`, which
the step body runs against its output. It reads JSON with a JSON parser,
and it holds a source id to a slug before that id becomes a file path.

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
