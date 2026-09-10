{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.group creates a Group (netbird.io/v1alpha1) with the current native
NetBird Kubernetes operator API.

Required:
- $definition.name: auto-injected by kaster (YAML key).

Optional:
- $definition.nbName: override the NetBird-side name (defaults to $definition.name)
- $definition.namespace

This glyph is only for API-managed infrastructure groups. Do not create a
Group whose NetBird name is also supplied by the account JWT group claim:
NetBird does not synchronize users into an API-created group with that name.
JWT groups should normally be referenced by their stable name. Publish one as
type netbird-group only when an independent consumer genuinely needs label-based
discovery.

Lexicon: this glyph does NOT publish automatically. Resources created and
consumed in the same ownership boundary should use exact refs. Only declare a
matching type=netbird-group entry when a separate spell must discover it.

Usage: {{- include "netbird.group" (list $root $glyph) }}
*/}}
{{- define "netbird.group" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
---
apiVersion: netbird.io/v1alpha1
kind: Group
metadata:
  name: {{ $definition.name }}
  {{- with $definition.namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $definition.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  name: {{ default $definition.name $definition.nbName | quote }}
{{- end }}
