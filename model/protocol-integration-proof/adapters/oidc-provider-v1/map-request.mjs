import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const policyPath = fileURLToPath(new URL('./mapping-policy.tsv', import.meta.url));

export async function mapRequest({ clientId, scope, acr }) {
  const row = (await readFile(policyPath, 'utf8')).trim().split('\t');
  const [
    policyRevision,
    expectedClientId,
    expectedScope,
    expectedAcr,
    relyingPartyRef,
    purposeRef,
    projectionRef,
    assuranceRequirementRef,
  ] = row;
  if (
    clientId !== expectedClientId
    || scope !== expectedScope
    || acr !== expectedAcr
  ) {
    throw new Error('raw protocol input is not covered by the pinned mapping policy');
  }
  return {
    policyRevision,
    relyingPartyRef,
    purposeRef,
    projectionRef,
    assuranceRequirementRef,
  };
}
