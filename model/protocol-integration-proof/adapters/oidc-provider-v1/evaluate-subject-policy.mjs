import { readFile } from 'node:fs/promises';

import { mapSubject } from './subject-policy.mjs';

const [inputPath] = process.argv.slice(2);
if (!inputPath) {
  throw new Error('usage: node evaluate-subject-policy.mjs INPUT_TSV');
}

const inputs = (await readFile(inputPath, 'utf8'))
  .trim()
  .split('\n')
  .map((line) => line.split('\t'));
const outputs = [];
for (const [
  scenario,
  stableAccountKey,
  entityRef,
  subjectType,
  policySemantics,
  policyRevision,
  contextRef,
  sector,
] of inputs) {
  const result = await mapSubject({
    stableAccountKey,
    entityRef,
    subjectType,
    policySemantics,
    policyRevision,
    contextRef,
    sector,
  });
  outputs.push([
    scenario,
    result.disposition,
    result.subject ?? '-',
  ].join('\t'));
}
outputs.sort();
process.stdout.write(`${outputs.join('\n')}\n`);
