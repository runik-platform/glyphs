{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

vault.databaseRole — a ROLE (DatabaseSecretEngineRole) under a resolved
database secrets-engine mount. One per app (type: db); it issues the dynamic
credentials. The per-engine chart supplies dBName + creationStatements.

See database-engine.tpl for the mount/connection/role cardinality and the
file split rationale. Authenticates as the Vault admin (vault.connect "force")
and lands in the Vault server namespace by default (override: configNamespace).
*/}}
{{- define "vault.databaseRole" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $g.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $vaultServers -}}
  {{- fail "vault.databaseRole: no 'type: secret-store' (provider: operator) entry found in lexicon" -}}
{{- end -}}
{{- $vaultConf := index $vaultServers 0 -}}
{{- $mount := default "database" $g.databaseMount -}}
{{- $ns := default $vaultConf.namespace $g.configNamespace }}
---
apiVersion: redhatcop.redhat.io/v1alpha1
kind: DatabaseSecretEngineRole
metadata:
  name: {{ required "vault.databaseRole: name is required" $g.name }}
  namespace: {{ $ns }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $g.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- $annotations := include "common.annotations.map" (list $root (default dict $g.annotations) dict) | fromJson -}}
  {{- with $annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- include "vault.connect" (list $root $vaultConf "force") | nindent 2 }}
  path: {{ $mount }}
  dBName: {{ required "vault.databaseRole: dBName is required" $g.dBName }}
  creationStatements:
    {{- toYaml (required "vault.databaseRole: creationStatements is required" $g.creationStatements) | nindent 4 }}
  {{- with $g.revocationStatements }}
  revocationStatements:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $g.renewStatements }}
  renewStatements:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $g.rollbackStatements }}
  rollbackStatements:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $g.defaultTTL }}
  defaultTTL: {{ . }}
  {{- end }}
  {{- with $g.maxTTL }}
  maxTTL: {{ . }}
  {{- end }}
{{- end -}}
