import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [sourcePath] = process.argv.slice(2);
if (!sourcePath) {
  throw new Error('usage: node invoke-adapter-pi-n03.mjs SOURCE');
}

const module = await import(pathToFileURL(resolve(sourcePath)));
const outcome = await module.authenticate({
  loginIdentifier: 'login-alice',
  proof: 'toy-password-v1',
});
if (
  outcome.disposition !== 'accepted'
  || outcome.stableAccountKey !== 'account-alice'
) {
  throw new Error('adapter did not complete the valid path');
}
process.stdout.write('PI_N03_ADAPTER_PATH_REACHED\n');
