#!/usr/bin/env node
// Claim shape check for the extract step.
//
//   ./check-claims.mjs <claims.jsonl> <sources-dir>
//
// Every line must be one JSON object carrying id, question, source_id,
// quote, and claim. Every id must be unique. Every source_id must name a
// stored source, and the quote must appear in it word for word.
//
// Exit 0 on a clean file, 1 on any finding, 2 on bad usage.
//
// This reads JSON with a JSON parser, on purpose. An earlier version
// matched keys with regular expressions, which broke on the first quote
// that carried a quotation mark of its own: `[^"]*` stopped at the
// backslash and truncated the value. Quoting a source line that contains
// speech is ordinary in research, so that version rejected valid claims.

import { readFileSync, existsSync, statSync } from "node:fs";
import { resolve, sep } from "node:path";

const REQUIRED = ["id", "question", "source_id", "quote", "claim"];
const SOURCE_ID = /^[a-z0-9][a-z0-9-]*$/;
const MIN_QUOTE = 20;

const [claimsPath, sourcesDir] = process.argv.slice(2);
if (!claimsPath || !sourcesDir) {
  console.error("usage: check-claims.mjs <claims.jsonl> <sources-dir>");
  process.exit(2);
}

let findings = 0;
const say = (m) => { console.error(m); findings++; };

if (!existsSync(claimsPath)) { console.error(`no claims file at ${claimsPath}`); process.exit(1); }
if (!existsSync(sourcesDir) || !statSync(sourcesDir).isDirectory()) {
  console.error(`no sources folder at ${sourcesDir}`);
  process.exit(1);
}

const sourcesRoot = resolve(sourcesDir);
const seen = new Set();
const sourceText = new Map();
let count = 0;

const lines = readFileSync(claimsPath, "utf8").split("\n");

lines.forEach((raw, i) => {
  const n = i + 1;
  if (raw.trim() === "") return;
  count++;

  let claim;
  try {
    claim = JSON.parse(raw);
  } catch (e) {
    say(`line ${n}: not valid JSON — ${e.message}`);
    return;
  }
  if (claim === null || typeof claim !== "object" || Array.isArray(claim)) {
    say(`line ${n}: not a single JSON object`);
    return;
  }

  for (const key of REQUIRED) {
    if (!Object.hasOwn(claim, key)) say(`line ${n}: missing key '${key}'`);
  }

  const { id, source_id: sid, quote } = claim;

  if (typeof id !== "string" || id === "") {
    say(`line ${n}: 'id' must be a non-empty string`);
  } else if (seen.has(id)) {
    say(`line ${n}: duplicate id '${id}'`);
  } else {
    seen.add(id);
  }

  // A source id becomes a file path, so it is a slug and nothing else.
  // Without this a source_id of "../../etc/passwd" would read outside the
  // sources folder and still pass the quote check.
  let sourceFile = null;
  if (typeof sid !== "string" || !SOURCE_ID.test(sid)) {
    say(`line ${n}: source_id ${JSON.stringify(sid)} must match ${SOURCE_ID}`);
  } else {
    const candidate = resolve(sourcesRoot, `${sid}.md`);
    // Belt and braces: the slug already forbids a separator, and this
    // confirms the resolved path never leaves the sources folder.
    if (!candidate.startsWith(sourcesRoot + sep)) {
      say(`line ${n}: source_id '${sid}' resolves outside ${sourcesDir}`);
    } else if (!existsSync(candidate)) {
      say(`line ${n}: source_id '${sid}' has no file at ${sourcesDir}/${sid}.md`);
    } else {
      sourceFile = candidate;
    }
  }

  if (typeof quote !== "string") {
    say(`line ${n}: 'quote' must be a string`);
    return;
  }
  // A quote short enough to match anything is not evidence.
  if (quote.length < MIN_QUOTE) {
    say(`line ${n}: quote is under ${MIN_QUOTE} characters — quote the whole source line`);
  }
  if (sourceFile) {
    if (!sourceText.has(sourceFile)) {
      sourceText.set(sourceFile, readFileSync(sourceFile, "utf8"));
    }
    if (!sourceText.get(sourceFile).includes(quote)) {
      say(`line ${n}: quote does not appear in ${sourcesDir}/${sid}.md`);
    }
  }
});

if (count === 0) say(`${claimsPath} is empty`);

if (findings === 0) console.log(`ok  ${claimsPath} (${count} claims)`);
process.exit(findings === 0 ? 0 : 1);
