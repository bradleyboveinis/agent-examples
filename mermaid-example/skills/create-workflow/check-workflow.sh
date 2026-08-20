#!/usr/bin/env bash
# Workflow shape check for the create-workflow skill.
#
# Checks one workflow folder, or every workflow folder under a parent:
#   ./check-workflow.sh ../../workflows/research-topic
#   ./check-workflow.sh ../../workflows
#
# It enforces the contract SKILL.md states:
#   - one mermaid flowchart block in workflow.md
#   - a `click` line binds each step node to ./steps/<node-id>/step.md
#   - step folders and click lines match one to one
#   - fork markers split with unlabelled edges, join markers wait and merge
#   - map_over carries a concurrency cap, and outcome_precedence names
#     labels that real outgoing edges carry
#   - required frontmatter on the workflow and on every step
#   - entry and terminals name real nodes
#   - no second list of step links to drift from the graph
#
# Exit 0 on a clean workflow. Exit 1 on any finding.
set -uo pipefail

fail=0
say() { printf '%s\n' "$1" >&2; fail=1; }

# Print the YAML frontmatter of a file.
frontmatter() {
  awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside' "$1"
}

# Print the body of the single mermaid block.
mermaid_block() {
  awk '/^```mermaid$/ {inside=1; next} inside && /^```$/ {exit} inside' "$1"
}

# Strip node shapes and normalise the two label forms to `-- label -->`.
normalise() {
  sed -E '
    s/\(\[[^]]*\]\)//g; s/\[\[[^]]*\]\]//g; s/\(\([^)]*\)\)//g;
    s/\{\{[^}]*\}\}//g; s/\[[^]]*\]//g; s/\{[^}]*\}//g; s/\([^)]*\)//g;
    s/-\.->/-->/g; s/==>/-->/g;
    s/-->\|([^|]*)\|/-- \1 -->/g;
  '
}

# Print one edge per line as "src|label|dst". Label is empty when absent.
edges() {
  normalise \
  | grep -- '-->' \
  | grep -v '^ *click ' \
  | sed -E '
      s/^ *([A-Za-z0-9_]+) *-- *([^>]*[^ >]) *--> *([A-Za-z0-9_]+) *$/\1|\2|\3/;
      t
      s/^ *([A-Za-z0-9_]+) *--> *([A-Za-z0-9_]+) *$/\1||\2/;
    '
}

# True when a folder holds a runnable file. The language does not matter,
# only that code lives there, because code is what earns a tests/ folder.
has_code() { # folder
  local f
  for f in "$1"/*.sh "$1"/*.mjs "$1"/*.js "$1"/*.ts "$1"/*.py "$1"/*.rb; do
    [ -f "$f" ] && return 0
  done
  return 1
}

require_field() { # file, message, field regex
  if ! printf '%s\n' "$(frontmatter "$1")" | grep -qE "$3"; then
    say "$1: $2"
  fi
}

ALLOWED_STEP_FIELDS='name|agent|model|gate|reasoning_effort|map_over|max_concurrency|outcome_precedence'

check_step() { # step.md path, expected name, outgoing labels, agents root
  local step="$1" want="$2" out_labels="$3" agents="$4"
  local dir; dir="$(dirname "$step")"

  require_field "$step" "frontmatter needs 'name: $want'" "^name: ${want}$"
  require_field "$step" "frontmatter needs 'agent:'" '^agent: [a-z][a-z0-9-]*$'
  require_field "$step" "frontmatter needs 'model: haiku|sonnet|opus'" \
    '^model: (haiku|sonnet|opus)$'
  require_field "$step" "frontmatter needs 'gate: none|deterministic|llm-judge|human'" \
    '^gate: (none|deterministic|llm-judge|human)$'

  local fm; fm="$(frontmatter "$step")"

  # Frontmatter holds only what an author tweaks. Anything else has a home.
  local key
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    printf '%s' "$key" | grep -qE "^(${ALLOWED_STEP_FIELDS})$" \
      || say "$step: '${key}:' is not a step field — it belongs in the agent, the body, or the graph"
  done < <(printf '%s\n' "$fm" | sed -nE 's/^([a-z_]+):.*/\1/p')

  # The named agent must exist.
  local agent
  agent="$(printf '%s\n' "$fm" | sed -nE 's/^agent: (.*)$/\1/p')"
  if [ -n "$agent" ] && [ ! -f "${agents}/${agent}/agent.md" ]; then
    say "$step: agent '${agent}' has no file at ${agents}/${agent}/agent.md"
  fi

  # Every prompt unit has evals. Every folder with code has tests.
  [ -d "${dir}/evals" ] || say "${dir}: a step is a prompt unit and needs evals/"
  if has_code "$dir" && [ ! -d "${dir}/tests" ]; then
    say "${dir}: holds a script and needs tests/"
  fi

  if printf '%s\n' "$fm" | grep -qE '^reasoning_effort:' \
     && ! printf '%s\n' "$fm" | grep -qE '^reasoning_effort: (low|medium|high)$'; then
    say "$step: 'reasoning_effort:' must be low, medium, or high"
  fi

  # Map fan-out: map_over needs a cap, and a cap needs a map_over.
  local mapped=0
  printf '%s\n' "$fm" | grep -qE '^map_over: .+' && mapped=1

  if printf '%s\n' "$fm" | grep -qE '^max_concurrency:' \
     && ! printf '%s\n' "$fm" | grep -qE '^max_concurrency: [1-9][0-9]*$'; then
    say "$step: 'max_concurrency:' must be a whole number above zero"
  fi
  if [ "$mapped" -eq 1 ] \
     && ! printf '%s\n' "$fm" | grep -qE '^max_concurrency:'; then
    say "$step: 'map_over:' needs 'max_concurrency: <n>' to bound the fan-out"
  fi
  if [ "$mapped" -eq 0 ] && printf '%s\n' "$fm" | grep -qE '^max_concurrency:'; then
    say "$step: 'max_concurrency:' without 'map_over:' bounds nothing"
  fi

  # outcome_precedence must list labels that real outgoing edges carry.
  local prec label
  prec="$(printf '%s\n' "$fm" | sed -nE 's/^outcome_precedence: \[(.*)\]$/\1/p')"
  if printf '%s\n' "$fm" | grep -qE '^outcome_precedence:' && [ -z "$prec" ]; then
    say "$step: 'outcome_precedence:' must be an inline list, as [a, b]"
  fi
  if [ -n "$prec" ] && [ "$mapped" -eq 0 ]; then
    say "$step: 'outcome_precedence:' only reduces a mapped step's instances"
  fi
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    printf '%s\n' "$out_labels" | grep -qx -- "$label" \
      || say "$step: outcome_precedence '$label' matches no outgoing edge label"
  done < <(printf '%s' "$prec" | tr ',' '\n' | tr -d ' ')

  # A mapped step with a branching exit needs a rule to reduce its instances.
  local exits; exits="$(printf '%s\n' "$out_labels" | grep -c . || true)"
  if [ "$mapped" -eq 1 ] && [ "$exits" -gt 1 ] && [ -z "$prec" ]; then
    say "$step: mapped step has $exits labelled exits and no 'outcome_precedence:'"
  fi
}

check_workflow() { # workflow folder
  local dir="${1%/}" wf="${1%/}/workflow.md"
  local before="$fail"

  if [ ! -f "$wf" ]; then
    say "$dir: no workflow.md"
    return
  fi

  # Agents sit beside the workflows folder: <root>/agents, <root>/workflows.
  local agents_root
  agents_root="$(cd "$(dirname "$dir")/.." 2>/dev/null && pwd)/agents"

  # A workflow is a prompt unit too.
  [ -d "${dir}/evals" ] || say "${dir}: a workflow is a prompt unit and needs evals/"

  if [ "$(grep -c '^```mermaid$' "$wf")" -ne 1 ]; then
    say "$wf: needs exactly one mermaid block"
    return
  fi

  local block; block="$(mermaid_block "$wf")"

  if ! printf '%s\n' "$block" | grep -qE '^ *flowchart '; then
    say "$wf: the mermaid block must be a flowchart"
  fi

  # A second list of step links drifts from the graph. The click lines are it.
  if grep -qE '\]\(\./steps/' "$wf"; then
    say "$wf: markdown link to ./steps/ — use a click line, not a second list"
  fi

  # The prose outside the frontmatter and the diagram restates nothing.
  # A backticked token is a deliberate reference, so that is what is checked.
  # Plain English words are left alone.
  local prose tok
  prose="$(awk '
    NR==1 && $0=="---" {fm=1; next}
    fm && $0=="---"    {fm=0; next}
    fm                 {next}
    /^```mermaid$/     {mm=1; next}
    mm && /^```$/      {mm=0; next}
    mm                 {next}
    {print}
  ' "$wf")"

  for tok in haiku sonnet opus map_over max_concurrency outcome_precedence \
             reasoning_effort; do
    if printf '%s\n' "$prose" | grep -qF -- "\`${tok}\`"; then
      say "$wf: prose names \`${tok}\` — that belongs to a step's frontmatter, not here"
    fi
  done

  # One edge per line keeps the parse honest.
  local chained
  chained="$(printf '%s\n' "$block" | normalise | grep -v '^ *click ' \
             | grep -c -- '-->.*-->' || true)"
  if [ "$chained" -gt 0 ]; then
    say "$wf: $chained line(s) chain two arrows — write one edge per line"
  fi

  local edgelist; edgelist="$(printf '%s\n' "$block" | edges)"
  if [ -z "$edgelist" ]; then
    say "$wf: the flowchart has no edges"
    return
  fi

  local bad
  bad="$(printf '%s\n' "$edgelist" | grep -vc '|' || true)"
  if [ "$bad" -gt 0 ]; then
    say "$wf: $bad edge line(s) did not parse as 'from --> to' or 'from -- label --> to'"
    printf '%s\n' "$edgelist" | grep -v '|' | sed 's/^/    unparsed: /' >&2
  fi

  local nodes srcs dsts
  nodes="$(printf '%s\n' "$edgelist" | grep '|' | awk -F'|' '{print $1"\n"$3}' | sort -u)"
  srcs="$(printf '%s\n' "$edgelist" | grep '|' | cut -d'|' -f1)"
  dsts="$(printf '%s\n' "$edgelist" | grep '|' | cut -d'|' -f3)"

  # Click lines: one per step node.
  local clicked=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local id path
    id="$(printf '%s' "$line" | sed -E 's/^ *click +([A-Za-z0-9_]+).*/\1/')"
    path="$(printf '%s' "$line" | sed -E 's/^[^"]*"([^"]*)".*/\1/')"

    if ! printf '%s' "$id" | grep -qE '^[a-z][a-z0-9]*$'; then
      say "$wf: node id '$id' must match [a-z][a-z0-9]*"
    fi

    # The label is the one home for what a step does. A tooltip is a second.
    if printf '%s' "$line" | grep -qE '^ *click +[A-Za-z0-9_]+ +"[^"]*" +"'; then
      say "$wf: click '$id' carries a tooltip — put the plain words in the node label"
    fi

    # A step node declares a plain-English label. An id alone is not a label.
    local label
    label="$(printf '%s\n' "$block" \
             | sed -nE "s/^ *${id}\[\"?([^]\"]*)\"?\].*/\1/p" | head -1)"
    if [ -z "$label" ]; then
      say "$wf: step '$id' has no label — declare it as ${id}[\"what happens here\"]"
    elif [ "$(printf '%s' "$label" | wc -w)" -lt 3 ]; then
      say "$wf: step '$id' label '${label}' is not plain English — say what happens there"
    fi
    case "$id" in
      fork*|join*|merge*) say "$wf: '$id' is a marker and must carry no click line" ;;
    esac
    if [ "$path" != "./steps/${id}/step.md" ]; then
      say "$wf: click '$id' points at '$path', expected './steps/${id}/step.md'"
    fi
    if ! printf '%s\n' "$nodes" | grep -qx -- "$id"; then
      say "$wf: click '$id' names a node that sits on no edge"
    fi
    if [ ! -f "${dir}/steps/${id}/step.md" ]; then
      say "$wf: click '$id' does not resolve to ${dir}/steps/${id}/step.md"
    else
      local out_labels
      out_labels="$(printf '%s\n' "$edgelist" | grep '|' \
                    | awk -F'|' -v n="$id" '$1==n && $2!="" {print $2}')"
      check_step "${dir}/steps/${id}/step.md" "$id" "$out_labels" "$agents_root"
    fi
    clicked="${clicked}${id}"$'\n'
  done < <(printf '%s\n' "$block" | grep -E '^ *click ' || true)

  if [ -z "$clicked" ]; then
    say "$wf: no click lines — nothing binds a node to a step"
  fi

  # The README's step index is the navigable copy of the click lines. A
  # click does not resolve on GitHub, so the index is how a reader gets to
  # a step file. It is a derived copy, not a second author, so the lint
  # holds every row to the graph exactly. A stale row is an error.
  local root readme wfname
  root="$(cd "$(dirname "$dir")/.." 2>/dev/null && pwd)"
  readme="${root}/README.md"
  wfname="$(basename "$dir")"

  if [ ! -f "$readme" ]; then
    say "${root}: no README.md to hold the step index"
  elif ! grep -qx '## Step index' "$readme"; then
    say "$readme: missing '## Step index' section"
  else
    local isid ilabel want rows steps
    while IFS= read -r isid; do
      [ -n "$isid" ] || continue
      ilabel="$(printf '%s\n' "$block" \
                | sed -nE "s/^ *${isid}\[\"?([^]\"]*)\"?\].*/\1/p" | head -1)"
      want="| ${wfname} | [${isid}](./workflows/${wfname}/steps/${isid}/step.md) | ${ilabel} |"
      grep -qxF -- "$want" "$readme" \
        || say "$readme: step index row for '${isid}' missing or stale, expected exactly:
    ${want}"
    done < <(printf '%s' "$clicked")

    rows="$(grep -cF -- "](./workflows/${wfname}/steps/" "$readme" || true)"
    steps="$(printf '%s' "$clicked" | grep -c . || true)"
    if [ "$rows" -ne "$steps" ]; then
      say "$readme: step index holds ${rows} row(s) for '${wfname}', the graph has ${steps} step(s)"
    fi
  fi

  # Naming a step in the prose is how a restated table gets started.
  local sid
  while IFS= read -r sid; do
    [ -n "$sid" ] || continue
    if printf '%s\n' "$prose" | grep -qF -- "\`${sid}\`"; then
      say "$wf: prose names step \`${sid}\` — the graph names the steps, this file does not"
    fi
  done < <(printf '%s' "$clicked")

  # Fork and join markers.
  local n outn inn labelled
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    outn="$(printf '%s\n' "$srcs" | grep -cx -- "$n" || true)"
    inn="$(printf '%s\n' "$dsts" | grep -cx -- "$n" || true)"
    case "$n" in
      fork*)
        [ "$outn" -ge 2 ] || say "$wf: fork '$n' has $outn outgoing edge(s), needs 2 or more"
        [ "$inn" -ge 1 ]  || say "$wf: fork '$n' has no incoming edge"
        labelled="$(printf '%s\n' "$edgelist" | grep '|' \
                    | awk -F'|' -v k="$n" '$1==k && $2!="" {c++} END {print c+0}')"
        [ "$labelled" -eq 0 ] \
          || say "$wf: fork '$n' has $labelled labelled outgoing edge(s) — a fork is not a choice"
        ;;
      join*)
        [ "$inn" -ge 2 ]  || say "$wf: join '$n' has $inn incoming edge(s), needs 2 or more"
        [ "$outn" -eq 1 ] || say "$wf: join '$n' has $outn outgoing edge(s), needs exactly 1"
        ;;
      merge*)
        [ "$inn" -ge 2 ]  || say "$wf: merge '$n' has $inn incoming edge(s), needs 2 or more"
        [ "$outn" -eq 1 ] || say "$wf: merge '$n' has $outn outgoing edge(s), needs exactly 1"
        # A merge takes the first arrival. Every way in must say which
        # outcome brought the run there, or the cancellation is unreadable.
        labelled="$(printf '%s\n' "$edgelist" | grep '|' \
                    | awk -F'|' -v k="$n" '$3==k && $2=="" {c++} END {print c+0}')"
        [ "$labelled" -eq 0 ] \
          || say "$wf: merge '$n' has $labelled unlabelled incoming edge(s) — each way in names its outcome"
        ;;
    esac
  done < <(printf '%s\n' "$nodes")

  # Every step folder is reachable from a click line.
  local d name
  for d in "${dir}"/steps/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    if [ ! -f "${d}step.md" ]; then
      say "${d}: no step.md"
      continue
    fi
    if ! printf '%s' "$clicked" | grep -qx -- "$name"; then
      say "${d}step.md: no click line names this step"
    fi
  done

  # Workflow frontmatter.
  require_field "$wf" "frontmatter needs 'name: $(basename "$dir")'" \
    "^name: $(basename "$dir")$"
  require_field "$wf" "frontmatter needs 'description:'" '^description: .+'
  require_field "$wf" "frontmatter needs 'version:'" '^version: .+'
  require_field "$wf" "frontmatter needs 'entry:'" '^entry: [a-z][a-z0-9]*$'
  require_field "$wf" "frontmatter needs 'terminals:'" '^terminals:'
  require_field "$wf" "frontmatter needs 'inputs:'" '^inputs:'
  require_field "$wf" "frontmatter needs 'outputs:'" '^outputs:'
  require_field "$wf" "frontmatter needs 'max_step_visits:' to bound cycles" \
    '^max_step_visits: [0-9]+$'

  local fm entry
  fm="$(frontmatter "$wf")"
  entry="$(printf '%s\n' "$fm" | sed -nE 's/^entry: (.*)$/\1/p')"
  if [ -n "$entry" ] && ! printf '%s\n' "$nodes" | grep -qx -- "$entry"; then
    say "$wf: entry '$entry' names no node in the graph"
  fi

  local t
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if ! printf '%s\n' "$nodes" | grep -qx -- "$t"; then
      say "$wf: terminal '$t' names no node in the graph"
    fi
    if printf '%s' "$clicked" | grep -qx -- "$t"; then
      say "$wf: terminal '$t' also has a click line — a terminal runs no step"
    fi
  done < <(printf '%s\n' "$fm" | sed -nE 's/^terminals: \[(.*)\]$/\1/p' | tr ',' '\n' | tr -d ' ')

  if [ "$fail" = "$before" ]; then
    local steps forks
    steps="$(printf '%s' "$clicked" | grep -c . || true)"
    forks="$(printf '%s\n' "$nodes" | grep -c '^fork' || true)"
    printf 'ok  %s (%s steps, %s fork(s))\n' "$wf" "$steps" "$forks"
  fi
}

if [ "$#" -eq 0 ]; then
  echo "usage: check-workflow.sh <workflow-folder|workflows-parent>..." >&2
  exit 2
fi

for target in "$@"; do
  if [ -f "${target%/}/workflow.md" ]; then
    check_workflow "$target"
  elif [ -d "$target" ]; then
    found=0
    for sub in "${target%/}"/*/; do
      [ -f "${sub}workflow.md" ] || continue
      found=1
      check_workflow "$sub"
    done
    [ "$found" -eq 1 ] || say "$target: holds no workflow folder"
  else
    say "$target: not a folder"
  fi
done

exit "$fail"
