#!/usr/bin/env bash
# Claim shape check for the extract step.
#
#   ./check-claims.sh <claims.jsonl> <sources-dir>
#
# Every line must be one JSON object carrying id, question, source_id,
# quote, and claim. Every id must be unique. Every source_id must resolve
# to a stored source file. Exit 0 on a clean file, 1 on any finding.
set -uo pipefail

claims="${1:-}"
sources="${2:-}"

if [ -z "$claims" ] || [ -z "$sources" ]; then
  echo "usage: check-claims.sh <claims.jsonl> <sources-dir>" >&2
  exit 2
fi

[ -f "$claims" ]  || { echo "no claims file at $claims" >&2; exit 1; }
[ -d "$sources" ] || { echo "no sources folder at $sources" >&2; exit 1; }

fail=0
say() { printf '%s\n' "$1" >&2; fail=1; }

ids=""
n=0

while IFS= read -r line; do
  n=$((n + 1))
  [ -n "${line//[[:space:]]/}" ] || continue

  case "$line" in
    \{*\}) ;;
    *) say "line $n: not a single JSON object"; continue ;;
  esac

  for key in id question source_id quote claim; do
    printf '%s' "$line" | grep -q "\"${key}\"[[:space:]]*:" \
      || say "line $n: missing key '${key}'"
  done

  id="$(printf '%s' "$line" | sed -nE 's/.*"id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')"
  sid="$(printf '%s' "$line" | sed -nE 's/.*"source_id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')"
  quote="$(printf '%s' "$line" | sed -nE 's/.*"quote"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')"

  [ -n "$id" ] || say "line $n: 'id' is empty"
  if [ -n "$id" ]; then
    printf '%s' "$ids" | grep -qx -- "$id" && say "line $n: duplicate id '$id'"
    ids="${ids}${id}"$'\n'
  fi

  if [ -n "$sid" ] && [ ! -f "${sources}/${sid}.md" ]; then
    say "line $n: source_id '$sid' has no file at ${sources}/${sid}.md"
  fi

  # A quote short enough to match anything is not evidence.
  if [ -n "$quote" ] && [ "${#quote}" -lt 20 ]; then
    say "line $n: quote is under 20 characters — quote the whole source line"
  fi

  # The quote must appear in the source it names.
  if [ -n "$sid" ] && [ -n "$quote" ] && [ -f "${sources}/${sid}.md" ]; then
    grep -qF -- "$quote" "${sources}/${sid}.md" \
      || say "line $n: quote does not appear in ${sources}/${sid}.md"
  fi
done < "$claims"

[ "$n" -gt 0 ] || say "$claims is empty"

if [ "$fail" -eq 0 ]; then
  printf 'ok  %s (%d claims)\n' "$claims" "$n"
fi
exit "$fail"
