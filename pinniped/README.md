# Pinniped glyphs

The Pinniped chart renders the persistent declarative CRDs shipped by Pinniped
v0.47.0. Every glyph accepts the upstream CRD `spec` unchanged; Runik owns the
resource `name`, optional `namespace`, `labels`, and `annotations` envelope.

| Glyph type | Pinniped resource | Scope |
| --- | --- | --- |
| `oidcIdentityProvider` | OIDCIdentityProvider | namespaced |
| `ldapIdentityProvider` | LDAPIdentityProvider | namespaced |
| `activeDirectoryIdentityProvider` | ActiveDirectoryIdentityProvider | namespaced |
| `githubIdentityProvider` | GitHubIdentityProvider | namespaced |
| `federationDomain` | FederationDomain | namespaced |
| `oidcClient` | OIDCClient | namespaced |
| `credentialIssuer` | CredentialIssuer | cluster |
| `jwtAuthenticator` | JWTAuthenticator | cluster |
| `webhookAuthenticator` | WebhookAuthenticator | cluster |

Supervisor resources default to the `pinniped-supervisor` namespace. Concierge
resources are cluster-scoped and reject a `namespace` value.

## Associating a FederationDomain with identity providers

Publish each provider as a `pinniped-identity-provider` lexicon entry and set
`identityProviderSelector` on the FederationDomain. The selector is resolved by
`runic-system.runic-indexer`, using the same label/default semantics as other
Runik associations.

```yaml
lexicon:
  keycloak:
    type: pinniped-identity-provider
    name: keycloak
    namespace: pinniped-supervisor
    kind: OIDCIdentityProvider
    displayName: Keycloak
    labels:
      access: workforce

glyphs:
  pinniped:
    federation:
      type: federationDomain
      identityProviderSelector:
        access: workforce
      spec:
        issuer: https://login.example.com
```

The optional lexicon fields are `apiGroup` (defaults to
`idp.supervisor.pinniped.dev`) and `transforms` (copied to the selected
FederationDomain entry). Selected providers must be in the FederationDomain's
namespace because Pinniped uses local object references. Explicit
`spec.identityProviders` references remain available as an escape hatch and
are mutually exclusive with `identityProviderSelector`.

The original flat contracts for `oidcIdentityProvider` and `federationDomain`
remain supported for compatibility. Do not mix their legacy fields with
`spec`.
