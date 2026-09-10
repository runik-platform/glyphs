{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

vault.role creates the KubernetesAuthEngineRole formerly embedded in
vault.prolicy. It can reference a separately managed policy or policy set.

Parameters:
- $root: Chart root context (index . 0)
- $glyph: Role configuration (index . 1)
  - nameOverride: Role name (default: common.name)
  - policies: Vault Policy names (default: the resolved role name)
  - serviceAccount: ServiceAccount to bind (default: common.name)
  - tokenPeriod: Optional periodic token duration in seconds
  - targetNamespace: Namespace containing the target ServiceAccount
*/}}

{{- define "vault.role.resource" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{- $vaultConf := index . 2 -}}
{{- $roleName := default (include "common.name" $root) $glyph.nameOverride -}}
{{- $policies := default (list $roleName) $glyph.policies }}
---
apiVersion: redhatcop.redhat.io/v1alpha1
kind: KubernetesAuthEngineRole
metadata:
  name: {{ $roleName }}
  namespace: {{ default "vault" $vaultConf.namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyph.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- $annotations := include "common.annotations.map" (list $root (default dict $glyph.annotations) dict) | fromJson -}}
  {{- with $annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- include "vault.connect" (list $root $vaultConf "True") | nindent 2 }}
  path: {{ default $root.Values.spellbook.name $vaultConf.path }}
  policies:
  {{- range $policy := $policies }}
    - {{ $policy }}
  {{- end }}
  {{- with $glyph.tokenPeriod }}
  # Periodic token (seconds): renewable indefinitely, never reaches a max_ttl, so
  # vault-agent only ever renews and never re-authenticates. Use for consumers that
  # capture the token once and cannot pick up a rotation (e.g. versity's
  # --iam-vault-root-token, read at boot from the agent sink).
  tokenPeriod: {{ int64 . }}
  {{- end }}
  targetServiceAccounts:
    - {{ default (include "common.name" $root) $glyph.serviceAccount }}
  targetNamespaces:
    targetNamespaces:
      - {{ default $root.Release.Namespace $glyph.targetNamespace }}
{{- end -}}

{{- define "vault.role" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $glyph.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- range $vaultConf := $vaultServers }}
{{ include "vault.role.resource" (list $root $glyph $vaultConf) }}
{{- end -}}
{{- end -}}
