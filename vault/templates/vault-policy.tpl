{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

vault.policy creates a Vault Policy from explicitly declared paths. It does not
derive application, public, pipeline, password-policy, or database paths; those
opinionated defaults belong to the vault.prolicy metaglyph.

Parameters:
- $root: Chart root context (index . 0)
- $glyph: Policy configuration (index . 1)
  - nameOverride: Policy name (default: common.name)
  - paths: Policy rules, each with path and capabilities (required)
*/}}

{{- define "vault.policy.resource" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{- $vaultConf := index . 2 -}}
{{- $paths := required "vault.policy: paths is required" $glyph.paths }}
---
apiVersion: redhatcop.redhat.io/v1alpha1
kind: Policy
metadata:
  name: {{ default (include "common.name" $root) $glyph.nameOverride }}
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
  policy: |
    {{- range $rule := $paths }}
    path "{{ required "vault.policy: each rule requires path" $rule.path }}" {
      capabilities = {{ required "vault.policy: each rule requires capabilities" $rule.capabilities | toJson }}
    }
    {{- end }}
{{- end -}}

{{- define "vault.policy" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $glyph.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- range $vaultConf := $vaultServers }}
{{ include "vault.policy.resource" (list $root $glyph $vaultConf) }}
{{- end -}}
{{- end -}}
