{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.networkEgress creates a native Kubernetes-workload NetworkEgress
(netbird.io/v1alpha1), allowing workloads behind NetworkRouter to initiate
connections to an external target. It is not a NetBird client access policy.
Target must contain exactly one of `ip` or `fqdn`.

Required: networkRouterRef.name/namespace, target and at least one named port.

Usage: {{- include "netbird.networkEgress" (list $root $glyph) }}
*/}}
{{- define "netbird.networkEgress" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $router := required "netbird.networkEgress: networkRouterRef is required" $definition.networkRouterRef -}}
{{- $target := required "netbird.networkEgress: target is required" $definition.target -}}
{{- $ports := required "netbird.networkEgress: ports is required" $definition.ports -}}
---
apiVersion: netbird.io/v1alpha1
kind: NetworkEgress
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
  networkRouterRef:
    name: {{ required "netbird.networkEgress: networkRouterRef.name is required" $router.name | quote }}
    namespace: {{ required "netbird.networkEgress: networkRouterRef.namespace is required" $router.namespace | quote }}
  target:
    {{- toYaml $target | nindent 4 }}
  ports:
    {{- toYaml $ports | nindent 4 }}
{{- end }}
