import { readFile } from 'node:fs/promises';
import { createLocalJWKSet, jwtVerify } from 'jose';

const [
  tokenPath,
  jwksPath,
  expectedSubject = 'sub-public-alice-v1',
  expectedNonce = 'synthetic-nonce-v1',
] =
  process.argv.slice(2);
if (!tokenPath || !jwksPath) {
  throw new Error('usage: node verify-token.mjs TOKEN_JSON JWKS_JSON');
}

const token = JSON.parse(await readFile(tokenPath, 'utf8'));
const jwks = JSON.parse(await readFile(jwksPath, 'utf8'));
const { payload } = await jwtVerify(
  token.id_token,
  createLocalJWKSet(jwks),
  {
    issuer: 'http://127.0.0.1:56100',
    audience: 'client-raw-sentinel-v1',
  },
);

if (payload.nonce !== expectedNonce) {
  throw new Error(`unexpected nonce: ${String(payload.nonce)}`);
}
if (payload.sub !== expectedSubject) {
  throw new Error(`unexpected subject: ${String(payload.sub)}`);
}

process.stdout.write(`${JSON.stringify({
  verified: true,
  iss: payload.iss,
  sub: payload.sub,
  aud: payload.aud,
  nonce: payload.nonce,
})}\n`);
