{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

istio.serviceEntry registers an external (or aliased) host inside the Istio
mesh registry, so in-mesh clients can address a service by an arbitrary
hostname instead of its cluster-internal Service DNS.

Primary use case: alias the public FQDN consumed by humans through the
Ingress Gateway (e.g. git.int.example.com) to the internal Service of the
same workload, avoiding LB hairpin for in-cluster callers.

Parameters:
- $root: Chart root context (index . 0)
- $glyphDefinition: ServiceEntry configuration object (index . 1)

Required Configuration:
- glyphDefinition.enabled: must be true to generate the resource
- glyphDefinition.hosts:   list of hostnames this entry registers
- glyphDefinition.ports:   list of { number, protocol [, name] [, targetPort] }

Optional Configuration:
- glyphDefinition.nameOverride:     custom resource name (defaults to common.name + "-" + glyphName)
- glyphDefinition.namespace:        target namespace
- glyphDefinition.annotations:      map of annotations
- glyphDefinition.location:         MESH_INTERNAL (default) | MESH_EXTERNAL
- glyphDefinition.resolution:       DNS (default) | STATIC | NONE | DNS_ROUND_ROBIN
- glyphDefinition.addresses:        list of VIPs (used with resolution = STATIC)
- glyphDefinition.endpoints:        list of { address [, ports] [, labels] [, network] [, locality] [, weight] }
- glyphDefinition.workloadSelector: alternative to endpoints — pick pods by labels
- glyphDefinition.subjectAltNames:  list, for mTLS validation when calling MESH_EXTERNAL hosts
- glyphDefinition.exportTo:         list (default ["*"]); use ["."] to scope to same namespace

Usage: {{- include "istio.serviceEntry" (list $root $glyph) }}
*/}}
{{- define "istio.serviceEntry" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 }}
{{- if $glyphDefinition.enabled }}
---
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: {{ default (printf "%s-%s" (include "common.name" $root) $glyphDefinition.name) $glyphDefinition.nameOverride }}
  labels:
    {{- include "common.labels" $root | nindent 4 }}
  {{- with $glyphDefinition.namespace }}
  namespace: {{ . }}
  {{- end }}
  {{- with $glyphDefinition.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  hosts:
  {{- range $h := $glyphDefinition.hosts }}
    - {{ $h | quote }}
  {{- end }}
  location: {{ default "MESH_INTERNAL" $glyphDefinition.location }}
  resolution: {{ default "DNS" $glyphDefinition.resolution }}
  {{- with $glyphDefinition.addresses }}
  addresses:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  ports:
  {{- range $p := $glyphDefinition.ports }}
    - number: {{ $p.number }}
      name: {{ default (printf "%v-%s" $p.number ($p.protocol | lower)) $p.name }}
      protocol: {{ $p.protocol }}
    {{- with $p.targetPort }}
      targetPort: {{ . }}
    {{- end }}
  {{- end }}
  {{- with $glyphDefinition.endpoints }}
  endpoints:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $glyphDefinition.workloadSelector }}
  workloadSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $glyphDefinition.subjectAltNames }}
  subjectAltNames:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  exportTo:
  {{- range $ns := (default (list "*") $glyphDefinition.exportTo) }}
    - {{ $ns | quote }}
  {{- end }}
{{- end }}
{{- end }}
