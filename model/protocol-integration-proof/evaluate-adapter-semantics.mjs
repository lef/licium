import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [sourcePath] = process.argv.slice(2);
if (!sourcePath) {
  throw new Error('usage: node evaluate-adapter-semantics.mjs SOURCE');
}
const { authenticate } = await import(pathToFileURL(resolve(sourcePath)));
const outcome = await authenticate({
  loginIdentifier: 'login-alice',
  proof: 'toy-password-v1',
});
const rows = [
  ['envelope', 'disposition', outcome.disposition],
  ['envelope', 'stable_protocol_account_key', outcome.stableAccountKey],
  ['envelope', 'root_ref', outcome.rootRef],
  ['envelope', 'definition_ref', outcome.definitionRef],
  ['envelope', 'profile_ref', outcome.profileRef],
  ['envelope', 'context_ref', outcome.contextRef],
];
for (const [name, value] of outcome.values ?? []) {
  rows.push(['value', name, value]);
}
for (const [name, value] of outcome.relations ?? []) {
  rows.push(['relation', name, value]);
}
rows.sort((a, b) => a.join('\t').localeCompare(b.join('\t'), 'en'));
process.stdout.write(`${rows.map((row) => row.join('\t')).join('\n')}\n`);
