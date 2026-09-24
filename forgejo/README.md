# Forgejo glyphs

This chart renders the `hyperspike.io/v1` resources managed by the Runik
Forgejo operator fork. The Kubernetes API retains the upstream `Gitea` kind for
compatibility; the managed application and defaults are Forgejo.

`instance` supports `External` adoption and `Managed` workloads. Its optional
`connectionSelector`, `spec.postgres.selector`, and
`spec.objectStorage.selector` fields resolve `forgejo-instance`, `postgres`, and
`s3-provider` lexicon entries through `runic-system.runic-indexer`.

The supported API-resource glyphs are `org`, `user`, and `repo`. `org` and
`user` accept an exact `instanceRef` or an `instanceSelector`; `repo` currently
supports organization-owned repositories and accepts an exact `orgRef` or an
`orgSelector`. Selectors resolve the canonical lexicon types
`forgejo-instance` and `forgejo-org` and must match exactly one entry.
Resources created and consumed in one ownership boundary may use exact refs;
publish a lexicon entry when another spell needs to discover the resource.

The operator CRDs still include `Auth`, `Runner`, and `MigrateRepo`, but this
chart does not expose them until their controllers provide a functional,
External-compatible reconciliation path. User-owned repositories are omitted
for the same reason.

See `examples/` for external adoption, a stopped managed migration target, and
API-resource reference resolution.
