# NetBird glyphs

This chart contains reusable Runik renderers for the native NetBird Kubernetes
operator and the complementary account-plane operator. It contains no site,
tenant, user-group or environment policy; those decisions belong in spells.

Invoke a renderer below `glyphs.netbird` when using kaster directly, or below
top-level `netbird` in a summon spell. The mapping is always
`type: <type>` → `netbird.<type>`.

## Resource planes

| Type | Kubernetes kind | Purpose |
| --- | --- | --- |
| `accountSettings` | `NetBirdAccountSettings` | Singleton account configuration (`metadata.name: default`) |
| `dnsSettings` | `NetBirdDNSSettings` | Singleton account DNS policy (`metadata.name: default`) |
| `group` | `Group` | API-managed infrastructure group; never duplicate a JWT-synchronized group name |
| `policy` | `NetBirdPolicy` | Full account access policy or enforced policy absence |
| `accountNetwork` | `NetBirdNetwork` | Account-plane Network without creating workloads |
| `accountNetworkResource` | `NetBirdNetworkResource` | Arbitrary IP, CIDR, domain or wildcard resource |
| `accountNetworkRouter` | `NetBirdNetworkRouter` | Existing peer or peer groups routing an account Network |
| `peerGroupBinding` | `NetBirdPeerGroupBinding` | One peer-to-group membership edge |
| `exitNode` | `NetBirdRoute` + `NetBirdPolicy` | Safe IPv4 full-tunnel route plus required ICMP peer access |
| `networkRouter` | `NetworkRouter` | Native operator-managed routing-peer Deployment |
| `networkResource` | `NetworkResource` | Native exposure of a Kubernetes ClusterIP Service |
| `networkEgress` | `NetworkEgress` | Native workload egress through a `NetworkRouter` |
| `serviceExposure` | `Group` + `NetworkResource` + `NetBirdPolicy` | Service-owned access bundle resolved through a published network |

The chart also includes the lower-level `route` renderer, DNS zones and
records, nameserver groups, peers, setup keys, posture checks, role bindings,
sidecar profiles, cluster proxy and token resources.

## Lexicon and references

Consumers resolve resources through `runicIndexer`. Supported lexicon types
are:

- `netbird-group`: exact NetBird group name when a group genuinely needs
  discovery across ownership boundaries. Stable JWT group names and local
  infrastructure groups should normally use explicit references instead.
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
