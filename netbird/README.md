# NetBird glyphs

This chart contains reusable Runik renderers for the native NetBird Kubernetes
operator and the complementary account-plane operator. It contains no site,
tenant, user-group or environment policy; those decisions belong in spells.

Invoke a renderer below `glyphs.netbird` when using kaster directly, or below
top-level `netbird` in a summon spell. The mapping is always
`type: <type>` → `netbird.<type>`.

Every consumer renderer accepts `instanceRef` or `instanceSelector` and resolves
a `type: netbird-instance` provider through `runicIndexer`. With neither field,
the book-wide `default: book` instance is selected. Books without an instance
entry retain the historical singleton behavior during the compatibility
window; new books and migrations must publish the contract explicitly.

## Resource planes

| Type | Kubernetes kind | Purpose |
| --- | --- | --- |
| `instance` | `NetBirdInstance` | Singleton self-hosted control plane and its managed/external runtime topology |
| `identitySync` | `NetBirdIdentitySync` | Complete Keycloak realm-role/user/membership source |
| `accountSettings` | `NetBirdAccountSettings` | Singleton account configuration (`metadata.name: default`) |
| `dnsSettings` | `NetBirdDNSSettings` | Singleton account DNS policy (`metadata.name: default`) |
| `group` | `Group` | API-managed infrastructure group; never duplicate an externally managed identity-group name |
| `policy` | `NetBirdPolicy` | Full account access policy or enforced policy absence |
| `accountNetwork` | `NetBirdNetwork` | Account-plane Network without creating workloads |
| `accountNetworkResource` | `NetBirdNetworkResource` | Arbitrary IP, CIDR, domain or wildcard resource |
| `accountNetworkRouter` | `NetBirdNetworkRouter` | Existing peer or peer groups routing an account Network |
| `peerGroupBinding` | `NetBirdPeerGroupBinding` | One peer-to-group membership edge |
| `peerEnrollment` | `NetBirdPeerEnrollment` | One-off local enrollment or immutable-ID adoption of an external peer |
| `networkLocation` | composed account Network | Reusable site/LAN bundle built from Network, router groups, resources, policies and DNS primitives |
| `travellerProfile` | `NetBirdRoute` + `NetBirdPolicy` + optional DNS | Safe full-tunnel profile for roaming identity groups |
| `exitNode` | `NetBirdRoute` + `NetBirdPolicy` | Safe IPv4 full-tunnel route plus routed-traffic access |
| `networkRouter` | `NetworkRouter` | Native operator-managed routing-peer Deployment |
| `networkResource` | `NetworkResource` | Native exposure of a Kubernetes ClusterIP Service |
| `networkEgress` | `NetworkEgress` | Native workload egress through a `NetworkRouter` |
| `serviceExposure` | `Group` + `NetworkResource` + `NetBirdPolicy` | Service-owned access bundle resolved through a published network |

The chart also includes the lower-level `route` renderer, DNS zones and
records, nameserver groups, peers, setup keys, posture checks, role bindings,
sidecar profiles, cluster proxy and token resources.

## External identity sync

`type: identitySync` renders one complete Keycloak-backed identity source. The
glyph key defaults `spec.source`, so renaming that key changes ownership;
declare `source` explicitly when the Kubernetes name may change. The provider
contains only its URL, realm, client ID, and a same-namespace Secret reference.
Credentials are never embedded in the spell.

`realmRoles` is an explicit, non-empty list of provider realm-role names. These
roles become integration-owned NetBird groups identified by their Keycloak IDs;
they are not API-managed `type: group` resources and do not use the lexicon.
The same block works below top-level `netbird:` through Summon or below
`glyphs.netbird:` through Kaster.

Adoption of existing users or JWT groups is disabled by default and must be
enabled only for the first controlled cutover snapshot. Deletion defaults to
`Retain`; `Disable` blocks owned users through a complete empty snapshot.
`pollIntervalSeconds` defaults to 60 and accepts 15–3600 seconds.

Identity materialization and authorization are separate entries. Compose an
`identitySync` with `roleBinding` and an exact `groupRef.name` to map a
preprovisioned group such as `tyl-operations-staff` to NetBird `admin`.
Administration does not itself grant VPN access. See
`examples/identity-sync.yaml` and `examples/identity-sync-admin.yaml`.

## Control-plane instance

`type: instance` renders exactly one `NetBirdInstance` named `default`; the
glyph key is not a second instance identity. The complementary operator owns
its lifecycle, generated Management configuration and every component in
`managed` mode. Database, OIDC, TLS, public DNS, ingress/gateway and all
referenced Secrets stay owned by their existing providers.

Management is required and Dashboard is optional. Signal (currently at most
one with NetBird 0.78), Relay and STUN/TURN are collections identified by a
unique name and location. Omitting a component mode defaults it to `managed`:
managed components require an image and forbid external endpoints; external
components require endpoint data and forbid an image. Management's Runik fork
must be pinned by digest, while the other component images accept exactly one
tag or digest.

Managed Signal and Relay entries may set `publicEndpoint`; managed STUN/TURN
entries may set `endpoints`. These values are advertised to clients while the
operator still owns the in-cluster runtime. `oidc.clientSecretRef` is optional
for a public PKCE client.

`database.secretRef`, `encryptionKeySecretRef`, OIDC and bootstrap references
contain Kubernetes Secret names and keys, never values. Bootstrap always uses
the non-human `operator-owner`; `bootstrap.credentialSecretRef` names the
Secret where the complementary operator seals its sole Owner PAT. Deletion
defaults to `Retain`; opt into `DeleteRuntime` only when removing the CR should
also remove operator-owned workloads.

For a one-time migration of an existing account,
`bootstrap.adoptionCredentialSecretRef` points to its current Owner PAT. It
must differ from `credentialSecretRef`, which receives the new service PAT.

See `examples/instance-managed.yaml` and `examples/instance-external.yaml` for
the managed and multi-location external forms. The same definition lives below
top-level `netbird:` in a Summon spell or below `glyphs.netbird:` in Kaster.

The spell that owns this resource publishes only the root provider contract:

```yaml
appendix:
  lexicon:
    netbird:
      type: netbird-instance
      namespace: netbird
      resourceRef:
        name: default
      labels:
        environment: production
        default: book
```

Account, network, DNS and application spells consume that contract. They may
publish their own narrower contracts (`netbird-network`, `netbird-dnszone`)
for downstream resources, just as an Istio Gateway publishes `istio-gw` for
VirtualServices.

## Peer enrollment and external adoption

`type: peerEnrollment` renders exactly one `NetBirdPeerEnrollment`. In
`mode: enroll`, the workload must be a Deployment, StatefulSet or DaemonSet in
the CR namespace and consume `enrollment.secretRef` through an optional Secret
reference. The complementary operator creates a one-off key, observes the new
peer, persists its immutable ID, revokes the key and removes the temporary
Secret. A remote workload or Secret namespace is rejected.

`mode: adopt` requires an immutable `peerIdentity.id` and emits no Secret.
Optional hostname, DNS-label and serial-number values are assertions, not
selectors. Settings and memberships added by the CR are restored or removed
on deletion; the peer itself defaults to `deletionPolicy: Retain`. Deleting an
adopted peer requires both `ownership.takeOwnership: true` and
`deletionPolicy: Delete`.

Use `groupRefs` for exact group names or `groupsSelector` for
`netbird-group` lexicon discovery. See `examples/peer-enrollment-local.yaml`
and `examples/peer-enrollment-adopt.yaml`. Both forms work below top-level
`netbird:` through Summon and below `glyphs.netbird:` through Kaster.

## Network locations

`type: networkLocation` composes the existing account-plane primitives for a
physical site without creating a second implementation of their CRDs. It owns
an account Network, a deterministic router group and Network router, optional
resources plus access policy, optional router-input policy, and optional local
DNS. Router entries reference an existing `peerEnrollment`, peer name, or peer
group; the location never creates or transports a SetupKey.

`routers.<name>.enrollmentRef` defaults the NetBird peer name to the enrollment
name. Set `peerName` when the enrollment deliberately manages a different
`settings.name`. Multiple direct peers are bound to the generated router group;
existing peer groups are attached directly for HA. Resources require explicit
source groups and `access.rules`, so declaring a location never grants traffic
implicitly. `routerInput.rules` is likewise explicit and is only needed for
services terminating on a routing peer itself.

Generated object names are scoped by the location key and validated against
Kubernetes' 63-character limit. See `examples/network-location-fwck.yaml` and
`examples/network-location-ha.yaml` for remote adoption, local DNS and
multi-router forms.

Existing declarative objects can be adopted without replacement by setting
`networkName`, `routerGroupName`, `resourceGroupName`, `routerResourceName`,
`accessPolicyName`, `routerInputPolicyName`, `routers.<name>.bindingName`, and
`resources.<name>.resourceName`. These fields only override Kubernetes object
names; NetBird-side names remain controlled by the corresponding `nbName`.

An `enrollmentRef` normally emits a peer-group binding. Set
`routers.<name>.manageBinding: false` only when the referenced
`peerEnrollment.groupRefs` already owns membership in the location's router
group; this avoids two CRs managing the same edge during adoption.

## Traveller profiles

`type: travellerProfile` composes `exitNode` with an optional
`nameserverGroup`, keeping routing, the routed-traffic policy, posture and
DNS scoped to the same source identity groups. Routing peers are groups rather
than individual peers so a profile can move from a single exit to HA without
changing its contract.

Generated routes use the routing-peer groups as NetBird route ACL targets;
the companion policy grants the declared source groups access to those targets.

`autoApply` defaults to `false`; the rendered full-tunnel route has
`skipAutoApply: true` until a spell opts in explicitly. Optional
`additionalRoutes` reuse the low-level `route` primitive and inherit the same
source, router and auto-apply boundary. IPv6 full-tunnel and an explicit route
exclusion API are not emitted until the complementary operator and upstream
NetBird expose stable contracts for them.

See `examples/traveller-profile-single.yaml` and
`examples/traveller-profile-ha.yaml`. A traveller profile can coexist with
`networkLocation`: the former controls client egress/DNS while location access
continues to be granted by the latter's explicit resource policies.

## Lexicon and references

Consumers resolve resources through `runicIndexer`. Supported lexicon types
are:

- `netbird-instance`: root provider for one singleton NetBird installation.
  It publishes `namespace`, optional `resourceRef.name` (default `default`) and
  optional `instanceId` (default `<namespace>/<resourceRef.name>`). Consumers
  choose it with `instanceRef` or `instanceSelector`.
- `netbird-group`: exact NetBird group name when a group genuinely needs
  discovery across ownership boundaries. Stable external-identity/JWT group
  names and local infrastructure groups should normally use explicit
  references instead.
- `netbird-peer`: exact hostname/name of an already-enrolled NetBird peer.
- `netbird-network`: published Network provider contract. Account-plane
  consumers use its exact name; native service consumers additionally require
  `routerRef.name` and `routerRef.namespace`.
- `netbird-posture-check`: exact NetBird posture-check name.
- `netbird-dnszone`: exact native operator DNS-zone reference.
- `netbird-user`: exact existing NetBird user name or email for token
  ownership; users are provisioned outside these operators.

List references merge explicit names with selector results and remove
duplicates. Singular references reject zero or multiple matches instead of
silently selecting the first result. Selectors are label selectors in the
normal Runik lexicon scope; the spell owns the labels and business meaning.

`serviceExposure` consumes a `netbird-network` provider entry containing a
`routerRef` object. The provider is discoverable across spells; the generated
destination Group and NetworkResource remain private implementation details
and are referenced directly rather than republished in the lexicon.

## Lifecycle notes

- `accountNetwork` rejects `enabled: false` because the Networks API has no
  disabled state. Delete the CR declaratively to delete the Network.
- Deleting a `NetBirdPeer` unregisters that peer. Use a lexicon-only
  `netbird-peer` entry when the glyph should discover but not own it.
- Prefer account Networks for site and service access. `route` remains for
  existing/domain/advanced routes. Prefer `exitNode` for `0.0.0.0/0`.
- `exitNode.autoApply` defaults to `false`, rendering `skipAutoApply: true`.
  A spell must opt in explicitly after its source and routing groups are
  correct. Nameserver selection remains a separate concern.
