import { appendFile, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';

import { Provider } from 'oidc-provider';

import { authenticate } from '../../../adapters/oidc-provider-v1/authenticate.mjs';
import { mapRequest } from '../../../adapters/oidc-provider-v1/map-request.mjs';
import { mapSubject } from '../../../adapters/oidc-provider-v1/subject-policy.mjs';
import { selectLoginSubject } from './select-login-subject.mjs';

const issuer = 'http://127.0.0.1:56100';
const receiptPath = process.env.LICIUM_ADAPTER_RECEIPT;
const evidenceDir = process.env.LICIUM_EVIDENCE_DIR;
const claimContext = process.env.LICIUM_CLAIM_CONTEXT ?? 'context-claims-v1';
const subjectType = process.env.LICIUM_SUBJECT_TYPE ?? 'public';
const subjectSemantics = process.env.LICIUM_SUBJECT_SEMANTICS ?? 'public-v1';
const subjectRevision = process.env.LICIUM_SUBJECT_REVISION ?? 'subject-policy-v1';
const subjectSector = process.env.LICIUM_SUBJECT_SECTOR ?? '-';
const entityRef = process.env.LICIUM_ENTITY_REF ?? 'entity-alice';
const sourceMode = process.env.LICIUM_SOURCE_MODE ?? 'exact_root';
const sourceRef = process.env.LICIUM_SOURCE_REF ?? 'write-receipt-v1';
const ephemeralOutcomes = new Map();

if (!receiptPath || !evidenceDir) {
  throw new Error('runtime evidence paths are not configured');
}
await Promise.all([
  writeFile(receiptPath, '', { encoding: 'utf8' }),
  writeFile(`${evidenceDir}/backend-request.tsv`, '', { encoding: 'utf8' }),
  writeFile(`${evidenceDir}/backend.log`, '', { encoding: 'utf8' }),
  writeFile(`${evidenceDir}/outcome.tsv`, '', { encoding: 'utf8' }),
  writeFile(`${evidenceDir}/projection-receipt.tsv`, '', { encoding: 'utf8' }),
]);

async function recordReceipt(fields) {
  if (!receiptPath) throw new Error('adapter receipt path is not configured');
  await appendFile(receiptPath, `${fields.join('\t')}\n`, { encoding: 'utf8' });
}

async function appendEvidence(name, fields) {
  if (!evidenceDir) throw new Error('evidence directory is not configured');
  await appendFile(`${evidenceDir}/${name}`, `${fields.join('\t')}\n`, {
    encoding: 'utf8',
  });
}

const provider = new Provider(issuer, {
  clients: [{
    client_id: 'client-raw-sentinel-v1',
    redirect_uris: ['http://127.0.0.1:56101/cb'],
    response_types: ['code'],
    grant_types: ['authorization_code'],
    token_endpoint_auth_method: 'none',
  }],
  claims: {
    profile: ['name', 'member_of'],
  },
  cookies: {
    keys: ['synthetic-public-fixture-cookie-key-1', 'synthetic-public-fixture-cookie-key-2'],
  },
  features: {
    devInteractions: { enabled: false },
  },
  interactions: {
    url(_ctx, interaction) {
      return `/interaction/${interaction.uid}`;
    },
  },
  async findAccount(_ctx, id) {
    const outcome = ephemeralOutcomes.get(id);
    if (!outcome) return undefined;
    return {
      accountId: id,
      async claims() {
        return {
          sub: id,
          name: outcome.values.get('display-name'),
          member_of: outcome.relations.get('member-of'),
        };
      },
    };
  },
  pkce: {
    required() {
      return true;
    },
  },
});

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 8192) reject(new Error('interaction body too large'));
    });
    req.on('end', () => resolve(new URLSearchParams(body)));
    req.on('error', reject);
  });
}

async function finishConsent(req, res, details) {
  const { grantId, session, params, prompt } = details;
  if (prompt.name !== 'consent') throw new Error('unexpected consent prompt');
  let grant;
  if (grantId) {
    grant = await provider.Grant.find(grantId);
  } else {
    grant = new provider.Grant({
      accountId: session.accountId,
      clientId: params.client_id,
    });
  }
  if (prompt.details.missingOIDCScope) {
    grant.addOIDCScope(prompt.details.missingOIDCScope.join(' '));
  }
  if (prompt.details.missingOIDCClaims) {
    grant.addOIDCClaims(prompt.details.missingOIDCClaims);
  }
  await provider.interactionFinished(
    req,
    res,
    { consent: { grantId: await grant.save() } },
    { mergeWithLastSubmission: true },
  );
}

async function handleInteraction(req, res) {
  const details = await provider.interactionDetails(req, res);
  if (req.method === 'GET') {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.end(`synthetic interaction: ${details.prompt.name}\n`);
    return;
  }
  if (req.method !== 'POST') {
    res.statusCode = 405;
    res.end();
    return;
  }

  const body = await readBody(req);
  if (details.prompt.name === 'login') {
    const mapping = await mapRequest({
      clientId: details.params.client_id,
      scope: details.params.scope,
      acr: details.params.acr_values,
    });
    await appendEvidence('backend-request.tsv', [
      'request',
      process.env.LICIUM_AUTH_BACKEND_PROVIDER,
      body.get('login') ?? '',
      'synthetic-proof-present',
      claimContext,
      sourceMode,
      sourceRef,
      mapping.relyingPartyRef,
      mapping.purposeRef,
      mapping.projectionRef,
      mapping.assuranceRequirementRef,
    ]);
    const outcome = await authenticate({
      loginIdentifier: body.get('login') ?? '',
      proof: body.get('password') ?? '',
      contextRef: claimContext,
      sourceMode,
      sourceRef,
      relyingPartyRef: mapping.relyingPartyRef,
      purposeRef: mapping.purposeRef,
      projectionRef: mapping.projectionRef,
      assuranceRequirementRef: mapping.assuranceRequirementRef,
    });
    if (outcome.disposition !== 'accepted') {
      await recordReceipt([
        'rejected',
        process.env.LICIUM_AUTH_BACKEND_PROVIDER,
        outcome.category,
        'outcome-invalid-v1',
        mapping.policyRevision,
        sourceMode,
        sourceRef,
      ]);
      await appendEvidence('outcome.tsv', [
        'outcome-invalid-v1',
        'rejected',
        outcome.category,
      ]);
      await appendEvidence('backend.log', [
        'rejected',
        process.env.LICIUM_AUTH_BACKEND_PROVIDER,
        outcome.category,
      ]);
      res.statusCode = 401;
      res.setHeader('Content-Type', 'text/plain; charset=utf-8');
      res.end('authentication rejected\n');
      return;
    }
    const subjectDecision = await mapSubject({
      stableAccountKey: outcome.stableAccountKey,
      entityRef,
      subjectType,
      policySemantics: subjectSemantics,
      policyRevision: subjectRevision,
      contextRef: outcome.contextRef,
      sector: subjectSector,
    });
    if (subjectDecision.disposition !== 'issued') {
      await recordReceipt([
        'migration_required',
        process.env.LICIUM_AUTH_BACKEND_PROVIDER,
        outcome.stableAccountKey,
        'outcome-valid-v1',
        subjectRevision,
      ]);
      await appendEvidence('outcome.tsv', [
        'outcome-valid-v1',
        'migration_required',
        outcome.stableAccountKey,
        outcome.rootRef,
      ]);
      await appendEvidence('backend.log', [
        'migration_required',
        process.env.LICIUM_AUTH_BACKEND_PROVIDER,
        outcome.rootRef,
      ]);
      res.statusCode = 409;
      res.setHeader('Content-Type', 'text/plain; charset=utf-8');
      res.end('subject migration required\n');
      return;
    }
    const engineSessionSubject = details.session?.accountId
      ? (process.env.LICIUM_ENGINE_DECOY_SUBJECT ?? details.session.accountId)
      : undefined;
    const subject = selectLoginSubject({
      credentialBoundSubject: subjectDecision.subject,
      engineSessionSubject,
    });
    if (subject !== subjectDecision.subject) {
      await recordReceipt([
        'engine_user_override_rejected',
        process.env.LICIUM_AUTH_BACKEND_PROVIDER,
        outcome.stableAccountKey,
        subjectDecision.subject,
        subject,
        outcome.rootRef,
      ]);
      res.statusCode = 409;
      res.setHeader('Content-Type', 'text/plain; charset=utf-8');
      res.end('engine user override rejected\n');
      return;
    }
    ephemeralOutcomes.set(subject, outcome);
    await recordReceipt([
      'accepted',
      process.env.LICIUM_AUTH_BACKEND_PROVIDER,
      outcome.stableAccountKey,
      subject,
      outcome.rootRef,
      outcome.definitionRef,
      outcome.profileRef,
      outcome.contextRef,
      outcome.outcomePersistence,
      'outcome-valid-v1',
      'projection-receipt-v1',
      mapping.policyRevision,
      mapping.relyingPartyRef,
      mapping.purposeRef,
      mapping.projectionRef,
      mapping.assuranceRequirementRef,
      sourceMode,
      sourceRef,
    ]);
    await appendEvidence('outcome.tsv', [
      'outcome-valid-v1',
      'accepted',
      outcome.stableAccountKey,
      outcome.rootRef,
    ]);
    await appendEvidence('projection-receipt.tsv', [
      'projection-receipt-v1',
      outcome.rootRef,
      outcome.definitionRef,
      outcome.profileRef,
      outcome.contextRef,
      'display-name',
      outcome.values.get('display-name'),
      'member-of',
      outcome.relations.get('member-of'),
    ]);
    await appendEvidence('backend.log', [
      'accepted',
      process.env.LICIUM_AUTH_BACKEND_PROVIDER,
      outcome.rootRef,
    ]);
    await provider.interactionFinished(
      req,
      res,
      { login: { accountId: subject } },
      { mergeWithLastSubmission: false },
    );
    return;
  }
  await finishConsent(req, res, details);
}

const oidc = provider.callback();
const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, issuer);
    if (url.pathname.startsWith('/interaction/')) {
      await handleInteraction(req, res);
    } else {
      await oidc(req, res);
    }
  } catch (error) {
    res.statusCode = 500;
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.end('integration fixture error\n');
    process.stderr.write(`${error.stack ?? error}\n`);
  }
});

server.listen(56100, '127.0.0.1', () => {
  process.stdout.write('OIDC_INTEGRATION_READY 56100\n');
});
