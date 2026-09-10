# Elasticsearch glyph

The official ECK chart owns the `Elasticsearch` resource. This glyph does not
reimplement ECK and intentionally emits no Jobs, CronJobs or Kubernetes RBAC.

`type: connection` configures Vault's bundled
`elasticsearch-database-plugin` from ECK's generated `elastic` user Secret. The
connection CR lives in the ECK namespace, so no Secret is copied. Its endpoint
uses HTTPS by default. A shared cluster may explicitly set `tls.enabled: false`
to use HTTP when the Kubernetes network is the accepted transport-security
boundary. The Elasticsearch plugin receives its endpoint through its native
`url` setting; the generic `connection_url` field is intentionally omitted
because this plugin rejects it. Root rotation stays disabled because ECK owns
the password Secret.

`tls.enabled` is optional and defaults to `true`. The legacy `scheme` field is
still accepted; when both are supplied they must agree.

`type: index` is the application-facing meta glyph analogous to
`postgresql.db`. It creates a least-privilege Vault dynamic role for the chosen
index patterns and exposes `USERNAME`, `PASSWORD`, `HOST`, `PORT`, `SCHEME`,
`URL`, and `INDEX` in a Kubernetes Secret. Clients inherit the HTTP or HTTPS
scheme published by the shared lexicon entry.

The glyph is intentionally **Elastic Basic-only** and does not render or depend
on an Enterprise license or Enterprise-only ECK resource.
