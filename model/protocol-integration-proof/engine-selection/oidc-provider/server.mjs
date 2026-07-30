import { Provider } from 'oidc-provider';

const issuer = 'http://127.0.0.1:56000';
const accounts = new Map([
  ['account-alice', {
    sub: 'account-alice',
    name: 'Synthetic Alice',
    preferred_username: 'alice.synthetic',
  }],
]);

const provider = new Provider(issuer, {
  clients: [{
    client_id: 'toy-rp',
    redirect_uris: ['http://127.0.0.1:56001/cb'],
    response_types: ['code'],
    grant_types: ['authorization_code'],
    token_endpoint_auth_method: 'none',
  }],
  claims: {
    profile: ['name', 'preferred_username'],
  },
  async findAccount(_ctx, id) {
    const claims = accounts.get(id);
    if (!claims) return undefined;
    return {
      accountId: id,
      async claims() {
        return claims;
      },
    };
  },
  pkce: {
    required() {
      return true;
    },
  },
});

provider.listen(56000, '127.0.0.1', () => {
  process.stdout.write('OIDC_PROVIDER_SELECTION_READY 56000\n');
});
