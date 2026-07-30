import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const policyPath = fileURLToPath(new URL('./subject-policy.tsv', import.meta.url));

export async function mapSubject({
  stableAccountKey,
  entityRef,
  subjectType,
  policySemantics,
  policyRevision,
  contextRef: _contextRef,
  sector,
}) {
  const rows = (await readFile(policyPath, 'utf8'))
    .trim()
    .split('\n')
    .map((line) => line.split('\t'));
  const family = rows.filter((row) => (
    row[0] === stableAccountKey
    && row[1] === entityRef
    && row[2] === subjectType
    && row[3] === policySemantics
  ));
  const exact = family.find((row) => (
    row[4] === policyRevision
    && row[5] === sector
  ));
  if (exact) {
    return {
      disposition: 'issued',
      subject: exact[6],
    };
  }
  if (family.length > 0) {
    return {
      disposition: 'migration_required',
    };
  }
  return {
    disposition: 'unsupported_subject_tuple',
  };
}
