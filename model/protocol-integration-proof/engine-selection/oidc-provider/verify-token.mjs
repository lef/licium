import { readFile } from 'node:fs/promises';
import { createLocalJWKSet, jwtVerify } from 'jose';

const [tokenPath, jwksPath] = process.argv.slice(2);
if (!tokenPath || !jwksPath) {
  throw new Error('usage: node verify-token.mjs TOKEN_JSON JWKS_JSON');
}

const token = JSON.parse(await readFile(tokenPath, 'utf8'));
const jwks = JSON.parse(await readFile(jwksPath, 'utf8'));
const { payload, protectedHeader } = await jwtVerify(
  token.id_token,
  createLocalJWKSet(jwks),
  {
    issuer: 'http://127.0.0.1:56000',
    audience: 'toy-rp',
  },
);

if (payload.nonce !== 'synthetic-nonce-v1') {
  throw new Error(`unexpected nonce: ${String(payload.nonce)}`);
}
if (payload.sub !== 'account-alice') {
  throw new Error(`unexpected subject: ${String(payload.sub)}`);
}

process.stdout.write(`${JSON.stringify({
  verified: true,
  alg: protectedHeader.alg,
  iss: payload.iss,
  sub: payload.sub,
  aud: payload.aud,
  nonce: payload.nonce,
})}\n`);
