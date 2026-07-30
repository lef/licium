import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [mapPath, authPath] = process.argv.slice(2);
if (!mapPath || !authPath) {
  throw new Error('usage: node invoke-mapped-authentication.mjs MAP AUTH');
}
const { mapRequest } = await import(pathToFileURL(resolve(mapPath)));
const { authenticate } = await import(pathToFileURL(resolve(authPath)));

const mapping = await mapRequest({
  clientId: 'client-raw-sentinel-v1',
  scope: 'openid profile',
  acr: 'acr-raw-sentinel-v1',
});
const outcome = await authenticate({
  loginIdentifier: 'login-alice',
  proof: 'toy-password-v1',
  contextRef: 'context-claims-v1',
  sourceMode: 'exact_root',
  sourceRef: 'write-receipt-v1',
  relyingPartyRef: mapping.relyingPartyRef,
  purposeRef: mapping.purposeRef,
  projectionRef: mapping.projectionRef,
  assuranceRequirementRef: mapping.assuranceRequirementRef,
});
if (
  outcome.disposition !== 'accepted'
  || outcome.stableAccountKey !== 'account-alice'
) {
  throw new Error('mapped authentication did not complete the valid path');
}
process.stdout.write('PI_N19_MAPPED_AUTHENTICATION_REACHED\n');
