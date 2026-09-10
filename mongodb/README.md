# MongoDB glyphs

The chart separates physical MongoDB lifecycle from logical access:

- `mongodb.cluster` creates a Percona cluster, scheduled backups and optionally
  composes its `MongoDBEngine` registration.
- `mongodb.engine` registers any existing MongoDB-compatible engine using an
  administrative credential Secret and optional TLS CA reference.
- `mongodb.database` is the application-facing meta glyph. It creates one
  `MongoDBDatabase` and one `MongoDBUser` with `readWrite` access by default.
- `mongodb.user` creates an additional database-scoped identity.
- `mongodb.instance` and `mongodb.restore` remain Percona escape hatches.

There is intentionally no collection or role glyph. A database is MongoDB's
authorization boundary for this API, collections are created lazily, and the
role preset belongs to `MongoDBUser.spec.access`.

## Physical cluster and engine

Logical operations are opt-in on the physical cluster and require an explicit
namespace authorization policy:

```yaml
mongodb:
  main:
    type: cluster
    operations:
      allowedNamespaces:
        matchLabels:
          mongodb.runik.io/engine: main
```

The composed engine uses one stable administrative Secret. With the normal
Runik Vault integration, the glyph creates that Secret and Percona creates the
administrative MongoDB user from it. Set
`operations.credentials.generate=false` and provide
`operations.credentialsSecretRef` to use a Secret managed elsewhere.

Generated Percona connection coordinates use the complete
`.svc.cluster.local` service FQDN. This matches the SANs in Percona's generated
TLS certificate and keeps hostname verification enabled for both the logical
operator and applications.

`allowedNamespaces` is mandatory and is never defaulted to every namespace.
Database consumers must match every configured selector clause.

## Application database

```yaml
mongodb:
  orders:
    type: database
```

This renders:

1. `MongoDBDatabase/orders`, with `deletionPolicy: Retain`;
2. a stable credential Secret generated through the Vault glyph;
3. `MongoDBUser/orders`, with `readWrite` and `deletionPolicy: Delete`.

The canonical access presets are `readOnly`, `readWrite`, `schemaAdmin` and
`owner`. `owner` maps to MongoDB `dbOwner` and should remain exceptional because
it includes user administration.

Set `defaultUser.enabled=false` to render only the database. Use `mongodb.user`
for a separate read-only or administrative identity. Every user references one
database and one Secret; it cannot request cross-database permissions.

## Existing credentials

The operator is independent from Vault. To use an externally managed Secret:

```yaml
mongodb:
  reporting-reader:
    type: user
    databaseRef:
      name: reporting
    access: readOnly
    credentials:
      generate: false
    credentialsSecretRef:
      name: reporting-reader-mongodb
      usernameKey: username
      passwordKey: password
    credentialsRevision: "1"
```

## Manual rotation

Rotation is deliberately two-phase so the controller cannot apply an old value
under a new revision during an asynchronous Secret update:

1. rotate or replace the referenced Secret and wait until the new value exists;
2. advance `credentialsRevision` on the `mongodb.user` or its `defaultUser`.

For Vault-generated credentials, `credentials.generationRevision` changes the
RandomSecret/VaultSecret source while preserving the output Secret name. Change
and sync `generationRevision` first, verify the output Secret, then change and
sync `credentialsRevision`. No workload restart, Reloader or random ConfigMap is
created by these glyphs.

Deleting a database retains its data by default. `deletionPolicy: Delete` also
requires `allowDrop: true`; this produces the operator's explicit confirmation
annotation.
