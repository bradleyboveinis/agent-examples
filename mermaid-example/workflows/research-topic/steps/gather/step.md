---
name: gather
agent: researcher
model: sonnet
gate: deterministic
---

# Step: gather

Input: the question list, the source floor, and `gaps`. Output: fetched
sources under `sources/`, plus an index at `sources/index.md`.

`gaps` is empty on the first visit. On a later visit the verify step fills
it with the claims that lost their support. Then this step looks only for
sources that answer those gaps. It keeps the sources it already stored.

## Procedure

1. Read `questions.md`. Read `gaps` when it holds entries.
2. Search for each question, highest rank first. Prefer the source type the
   question names.
3. Remove duplicates across the whole set. Two urls for one document are
   one source.
4. Fetch each source you keep. Store the fetched text under `sources/` as
   `<source-id>.md`. A source id is a short lowercase slug.
5. Record the source in `sources/index.md`:
   `| source id | title | publisher | url | retrieved |`.
6. Stop when the stored count reaches `source_floor` and every question has
   at least one source. Report a question you cannot source. Do not invent
   one.

Store the source text as fetched. Do not summarise it here. The extract
step reads the stored text, so a summary at this stage hides the wording a
later check needs.

## Gate

The check counts rows in `sources/index.md` and files under `sources/`. It
passes when the counts match, the count reaches `source_floor`, and every
row carries a url and a retrieval date.

## Outcome

This step has one way out. Return `sources_dir` and `source_index_path`,
and the run moves to `extract`.
