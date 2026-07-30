import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [mapperPath] = process.argv.slice(2);
if (!mapperPath) {
  throw new Error('usage: node evaluate-subject-stability.mjs MAPPER');
}
const { mapSubject } = await import(pathToFileURL(resolve(mapperPath)));

const base = {
  stableAccountKey: 'account-alice',
  entityRef: 'entity-alice',
  subjectType: 'public',
  policySemantics: 'public-v1',
  policyRevision: 'subject-policy-v1',
  sector: '-',
};
for (const [scenario, contextRef] of [
  ['context-a', 'context-claims-v1'],
  ['context-b', 'context-claims-v2'],
]) {
  const decision = await mapSubject({ ...base, contextRef });
  process.stdout.write([
    scenario,
    decision.disposition,
    decision.subject ?? '-',
  ].join('\t') + '\n');
}
