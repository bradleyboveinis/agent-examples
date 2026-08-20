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

# Print one node id per line, read from the block's edge lines.
node_ids() {
  sed -E '
    s/\(\[[^]]*\]\)//g; s/\[\[[^]]*\]\]//g; s/\(\([^)]*\)\)//g;
    s/\{\{[^}]*\}\}//g; s/\[[^]]*\]//g; s/\{[^}]*\}//g; s/\([^)]*\)//g;
    s/\|[^|]*\|//g;
    s/-\.->/-->/g; s/==>/-->/g;
    s/ *-- [^>]*--> */ --> /g;
  ' \
  | grep -- '-->' \
  | tr ' ' '\n' \
  | grep -vE '^(-->|)$' \
  | sed -E 's/^ *//; s/ *$//' \
  | sort -u
}

require_field() { # file, label, field regex
  if ! printf '%s\n' "$(frontmatter "$1")" | grep -qE "$3"; then
    say "$1: $2"
  fi
}

check_step() { # step.md path, expected name
  local step="$1" want="$2"
  require_field "$step" "frontmatter needs 'name: $want'" "^name: ${want}$"
  require_field "$step" "frontmatter needs 'description:'" '^description: .+'
  require_field "$step" "frontmatter needs 'agent:'" '^agent: .+'
  require_field "$step" "frontmatter needs 'model: haiku|sonnet|opus'" \
    '^model: (haiku|sonnet|opus)$'
  require_field "$step" "frontmatter needs 'reasoning_effort: low|medium|high'" \
    '^reasoning_effort: (low|medium|high)$'
  require_field "$step" "frontmatter needs 'gate: none|deterministic|llm-judge|human'" \
    '^gate: (none|deterministic|llm-judge|human)$'
  require_field "$step" "frontmatter needs 'inputs:'" '^inputs:'
  require_field "$step" "frontmatter needs 'outputs:'" '^outputs:'

  local fm; fm="$(frontmatter "$step")"
  if printf '%s\n' "$fm" | grep -qE '^isolation:' \
     && ! printf '%s\n' "$fm" | grep -qE '^isolation: (none|worktree)$'; then
    say "$step: 'isolation:' must be none or worktree"
  fi
  if printf '%s\n' "$fm" | grep -qE '^thinking_budget:' \
     && ! printf '%s\n' "$fm" | grep -qE '^thinking_budget: [0-9]+$'; then
    say "$step: 'thinking_budget:' must be a whole number of tokens"
  fi
}

check_workflow() { # workflow folder
  local dir="${1%/}" wf="${1%/}/workflow.md"
  local before="$fail"

  if [ ! -f "$wf" ]; then
    say "$dir: no workflow.md"
    return
  fi

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

  # Nodes named by the edges.
  local nodes; nodes="$(printf '%s\n' "$block" | node_ids)"
  if [ -z "$nodes" ]; then
    say "$wf: the flowchart has no edges"
    return
  fi

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
    if [ "$path" != "./steps/${id}/step.md" ]; then
      say "$wf: click '$id' points at '$path', expected './steps/${id}/step.md'"
    fi
    if ! printf '%s\n' "$nodes" | grep -qx -- "$id"; then
      say "$wf: click '$id' names a node that sits on no edge"
    fi
    if [ ! -f "${dir}/steps/${id}/step.md" ]; then
      say "$wf: click '$id' does not resolve to ${dir}/steps/${id}/step.md"
    else
      check_step "${dir}/steps/${id}/step.md" "$id"
    fi
    clicked="${clicked}${id}"$'\n'
  done < <(printf '%s\n' "$block" | grep -E '^ *click ' || true)

  if [ -z "$clicked" ]; then
    say "$wf: no click lines — nothing binds a node to a step"
  fi

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
    printf 'ok  %s\n' "$wf"
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
