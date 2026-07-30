import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

function parseTsv(stdout) {
  return stdout.trim().split('\n').filter(Boolean).map((line) => line.split('\t'));
}

export async function authenticate({
  loginIdentifier,
  proof,
  contextRef = 'context-claims-v1',
  sourceMode = 'exact_root',
  sourceRef = 'write-receipt-v1',
  relyingPartyRef = 'rp-proof-v1',
  purposeRef = 'interactive-login-v1',
  projectionRef = 'projection-basic-v1',
  assuranceRequirementRef = 'assurance-password-fixture-v1',
}) {
  // PI_N01_REACHABLE_INSERTION_POINT
  const command = process.env.LICIUM_AUTH_BACKEND_COMMAND;
  const provider = process.env.LICIUM_AUTH_BACKEND_PROVIDER;
  if (!command || !provider) {
    throw new Error('protocol-neutral backend command is not configured');
  }

  const { stdout, stderr } = await execFileAsync(
    command,
    [
      provider,
      loginIdentifier,
      proof,
      contextRef,
      sourceMode,
      sourceRef,
      relyingPartyRef,
      purposeRef,
      projectionRef,
      assuranceRequirementRef,
    ],
    {
      encoding: 'utf8',
      maxBuffer: 64 * 1024,
      timeout: 5000,
    },
  );
  if (stderr !== '') {
    throw new Error('protocol-neutral backend wrote stderr');
  }

  const rows = parseTsv(stdout);
  if (rows.length === 1 && rows[0][1] === 'rejected') {
    return {
      disposition: 'rejected',
      category: rows[0][2],
    };
  }

  const envelope = new Map();
  const values = new Map();
  const relations = new Map();
  for (const [kind, name, value] of rows) {
    if (kind === 'envelope') envelope.set(name, value);
    if (kind === 'value') values.set(name, value);
    if (kind === 'relation') relations.set(name, value);
  }
  if (envelope.get('disposition') !== 'accepted') {
    throw new Error('backend returned an invalid accepted envelope');
  }

  return {
    disposition: 'accepted',
    stableAccountKey: envelope.get('stable_protocol_account_key'),
    rootRef: envelope.get('root_ref'),
    definitionRef: envelope.get('definition_ref'),
    profileRef: envelope.get('profile_ref'),
    contextRef: envelope.get('context_ref'),
    outcomePersistence: envelope.get('outcome_persistence'),
    values,
    relations,
  };
}
