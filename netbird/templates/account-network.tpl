{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.accountNetwork creates a complementary NetBirdNetwork, an
account-plane container for external resources and already-enrolled routers.
It never creates Kubernetes workloads. The upstream Networks API has no
disabled state, so enabled=false is rejected and deletion is represented by
deleting the CR.

Publish a matching lexicon entry with type netbird-network when other glyphs
should discover this Network through networkSelector.
*/}}
{{- define "netbird.accountNetwork" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- if and (hasKey $definition "enabled") (not $definition.enabled) -}}
  {{- fail "netbird.accountNetwork: enabled=false is unsupported by the NetBird Networks API; delete the CR to delete the Network" -}}
{{- end }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdNetwork
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
  description: {{ default "" $definition.description | quote }}
  enabled: true
{{- end }}
