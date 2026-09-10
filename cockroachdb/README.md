# CockroachDB glyphset

This glyphset bootstraps a shared CockroachDB cluster and gives applications
databases with Vault-managed SQL credentials. It deliberately does **not**
define a cluster or engine type: the official chart owns the `CrdbCluster`, and
its spell owns the `DatabaseSecretEngineConfig` and publishes the cluster in
the lexicon.

## Types

- `bootstrap`: one retained Vault manager identity plus idempotent initialization
  SQL and its execution Job for a physical cluster.
- `database`: exactly one persistent application database. Credentials are
  dynamic by default; consumers can instead request one stable SQL identity
  whose password Vault rotates through a database static role.

The physical cluster spell must publish a `type: cockroachdb` lexicon entry,
including its `host`. Every glyph resolves the physical endpoint from that
entry; cluster coordinates are never repeated in the glyph declaration.
Consumers receive `HOST`, `PORT`, `DATABASE`, `DBNAME`, `SSLMODE`, `USERNAME`,
and `PASSWORD` in the generated Kubernetes Secret.

Publish the server transport mode once in that entry. The glyph derives the
client `SSLMODE` from it, so secure and insecure modes cannot be enabled at the
same time for one cluster:

```yaml
appendix:
  lexicon:
    crdb-main:
      type: cockroachdb
      host: crdb-main-public.cockroachdb.svc
      tls:
        enabled: false
```

`tls.enabled: false` produces `SSLMODE=disable`; `tls.enabled: true` produces
`SSLMODE=require`. A secure entry may explicitly set `sslmode: verify-ca` or
`sslmode: verify-full` after distributing the required CA material. Declaring
`tls.enabled: false` with a secure `sslmode`, or `tls.enabled: true` with
`sslmode: disable`, fails rendering. Entries that omit both fields retain the
backward-compatible `require` default.

CockroachDB disables password authentication together with server TLS in
insecure mode. The generated manager, dynamic-role, and static-role SQL
therefore omits `PASSWORD` when `tls.enabled: false`. Credential Secrets keep
their usual `USERNAME` and `PASSWORD` fields for consumer compatibility; the
server ignores the password while running insecurely.

## Physical cluster bootstrap

Declare the bootstrap beside an external CockroachDB chart under `glyphs:`:

```yaml
glyphs:
  cockroachdb:
    bootstrap:
      type: bootstrap
      backup:
        enabled: true
        uri: s3://cluster-backups?AUTH=implicit&AWS_ENDPOINT=http://s3.s3.svc:7070&AWS_REGION=us-east-1&AWS_USE_PATH_STYLE=true
```

The default SQL creates or reconciles the retained `vault_mgr` role. When
`backup.enabled` is true it also creates the idempotent native backup schedule.
Configure `manager.username`, `manager.secretName`, `backup.scheduleName`,
`backup.recurring`, and `backup.fullBackup` without copying SQL.

By default the bootstrap also mirrors the retained manager identity into the
Vault namespace and renders its `DatabaseSecretEngineConfig`. The connection
URL derives `sslmode` from the same lexicon `tls.enabled`, so Vault cannot drift
from the server or consumer Secrets. Configure this through `engine`, or set
`engine.enabled: false` when another Application owns the connection. Multiple
Vault installations can be disambiguated with `engine.vaultSelector`.

The default `execution.mode: job` works in both transport modes. It derives
`--certs-dir` for a secure cluster and `--insecure` when `tls.enabled: false`.
The secure Job mounts the chart's root client Secret, defaulting to
`<cluster>-client-secret`.

`execution.mode: postInitSQL` remains available for an existing secure cluster
that intentionally delegates execution to the official chart. In that legacy
mode, point the chart at the generated Secret:

```yaml
cockroachdb:
  crdbCluster:
    postInitSQL:
      secretRef:
        name: <cluster>-vault-manager
        key: bootstrap.sql
```

The official chart rejects `postInitSQL` when server TLS is disabled, and the
glyph rejects that combination before deployment. The default Job is
idempotent and runs on every Argo CD sync after deleting the previous hook.

For an exceptional installation, `bootstrapSQL` replaces the generated SQL
completely. It may reference the retained password as
`'{{ .secret.password }}'`. Prefer the structured manager and backup fields so
upgrades to the common bootstrap remain centralized.

With one default cluster, consumers only declare the resource they want:

```yaml
cockroachdb:
  app:
    type: database
```

The declaration above keeps the original dynamic behavior. Vault creates a new
SQL login for the lease and removes that login on revocation.

Use a static role when migrations or application-owned objects require a stable
SQL owner:

```yaml
cockroachdb:
  app:
    type: database
    credentials:
      mode: static
      username: app
      rotationPeriod: 86400
      passwordPolicy: short-policy
```

`rotationPeriod` is required for static credentials and is expressed as integer
seconds, matching `DatabaseSecretEngineStaticRole` in vault-config-operator
v0.8.51. Static means a stable username, not an immutable password: Vault
rotates the password and exposes the current value through
`db/<book>/<chapter>/<spell>/static-creds/<name>`.

Declare the application's normal `vault.prolicy` beside the database. It owns
the spell mount and grants only `creds/*` and `static-creds/*` inside that
scope. Its Vault auth role may bind a ServiceAccount shared by other spells
without sharing their policies.

When more than one cluster exists, use Runik's standard `selector` to choose it
by lexicon labels:

```yaml
cockroachdb:
  app:
    type: database
    selector:
      name: crdb-analytics
```

## Operational constraints

In dynamic mode, `database` is actuated when the Vault operator requests a
lease. Vault's PostgreSQL plugin executes `creationStatements`, renews the
login, and executes `revocationStatements`.

In static mode, the first password rotation idempotently creates the database
and stable SQL role before setting its password and grants. Later rotations
reuse that identity. Both modes avoid per-database Jobs and extra reconcilers.

Objects created directly by the ephemeral login can block `DROP ROLE` when its
lease is revoked. Prefer migrations through a separately controlled owner
workflow or select static mode. Override `creationStatements`,
`renewStatements`, `revocationStatements`, or `rollbackStatements` for dynamic
credentials, and `credentials.rotationStatements` for static credentials, when
an application needs a different ownership model.

Deleting a static-role declaration removes its Vault configuration but does not
drop the SQL user or database. Password rotations update the Kubernetes Secret;
applications that consume it through environment variables still need a
coordinated Pod restart.

The default connection uses `sslmode=require`, matching Cockroach Labs' Vault
integration guidance. This encrypts the connection but does not verify the
server CA; CA verification requires distributing CockroachDB's CA to Vault and
setting `sslmode: verify-ca` or `sslmode: verify-full` in the lexicon entry.

The bootstrap manager password is retained in Vault and must survive cluster
reconciliation and transport-mode migrations. `postInitSQL` is one-shot; the
Job executor is intentionally idempotent and may run again on later syncs.
