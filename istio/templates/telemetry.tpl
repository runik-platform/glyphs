{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

istio.telemetry renders native Telemetry resources. Default association uses
selector as a Runic Indexer selector for istio-gw lexicon entries (including its
book/chapter defaults). Each entry must publish gateway: namespace/name and
workloadSelector: {pod-label: value}. Gateway resource names cannot reliably
identify gateway pods. Entries sharing namespace and workloadSelector are
coalesced, since multiple selector Telemetries on one workload are invalid.

Explicit target bypasses discovery and is exclusive with selector:
  target: {namespace: apps, workloadSelector: {app: api}}
  target: {namespace: apps, targetRefs: [{group: "", kind: Service, name: api}]}
  target: {namespace: apps, scope: namespace}
The last form intentionally has no selector (root-namespace placement gives
mesh defaults). targetRefs follows native Istio attachment support; in
particular an Istio networking.istio.io Gateway is NOT a supported targetRef.

accessLogging, tracing, metrics pass through the native Telemetry arrays.
No provider, error filter or dashboard is imposed. Register providers in the
Istio installation. Do not select a workload already owned by another Telemetry.
Optional enabled (default true), name/namespace/labels/annotations. namespace
can override a discovered namespace, but not conflict with target.namespace.
*/}}
{{- define "istio.telemetry.targets" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $targets := list -}}
{{- if hasKey $definition "target" -}}
  {{- if hasKey $definition "selector" -}}{{- fail "istio.telemetry: target and lexicon selector are mutually exclusive" -}}{{- end -}}
  {{- $target := deepCopy $definition.target -}}
  {{- if not (kindIs "map" $target) -}}{{- fail "istio.telemetry: target must be a map" -}}{{- end -}}
  {{- if and $target.namespace $definition.namespace (ne $target.namespace $definition.namespace) -}}{{- fail "istio.telemetry: conflicting namespaces" -}}{{- end -}}
  {{- $_ := set $target "namespace" (default $root.Release.Namespace (default $definition.namespace $target.namespace)) -}}
  {{- $modes := 0 -}}
  {{- if $target.workloadSelector -}}{{- $modes = add1 $modes -}}{{- end -}}
  {{- if $target.targetRefs -}}{{- $modes = add1 $modes -}}{{- end -}}
  {{- if eq (default "" $target.scope) "namespace" -}}{{- $modes = add1 $modes -}}{{- else if $target.scope -}}{{- fail "istio.telemetry: target.scope must be namespace" -}}{{- end -}}
  {{- if ne (int $modes) 1 -}}{{- fail "istio.telemetry: target requires exactly one of workloadSelector, targetRefs or scope: namespace" -}}{{- end -}}
  {{- $targets = append $targets $target -}}
{{- else -}}
  {{- $gateways := get (include "runic-system.runic-indexer" (list (default dict $root.Values.lexicon) (default dict $definition.selector) "istio-gw" $root.Values.chapter.name) | fromJson) "results" -}}
  {{- if not $gateways -}}{{- fail "istio.telemetry: no istio-gw found in lexicon; provide a matching selector/default or an explicit target" -}}{{- end -}}
  {{- $seen := dict -}}
  {{- range $gateway := $gateways -}}
    {{- $reference := required "istio.telemetry: gateway lexicon entry requires gateway: namespace/name" $gateway.gateway -}}
    {{- $parts := splitList "/" $reference -}}
    {{- if ne (len $parts) 2 -}}{{- fail "istio.telemetry: gateway reference must be namespace/name" -}}{{- end -}}
    {{- $namespace := default (index $parts 0) $definition.namespace -}}
    {{- $selector := required (printf "istio.telemetry: lexicon gateway %s requires workloadSelector pod labels" $gateway.name) $gateway.workloadSelector -}}
    {{- $target := dict "namespace" $namespace "workloadSelector" $selector -}}
    {{- $key := toJson $target -}}
    {{- if not (hasKey $seen $key) -}}
      {{- $_ := set $seen $key true -}}
      {{- $targets = append $targets $target -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- dict "targets" $targets | toJson -}}
{{- end -}}

{{- define "istio.telemetry" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- if or (not (hasKey $definition "enabled")) $definition.enabled -}}
{{- $targets := get (include "istio.telemetry.targets" (list $root $definition) | fromJson) "targets" -}}
{{- $baseName := default (include "common.name" $root) $definition.name -}}
{{- range $target := $targets -}}
{{- $name := $baseName -}}
{{- if gt (len $targets) 1 -}}{{- $name = printf "%s-%s" ($baseName | trunc 52 | trimSuffix "-") (toJson $target | sha256sum | trunc 10) -}}{{- end -}}
{{ printf "\n---\n" }}
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: {{ $name | quote }}
  namespace: {{ $target.namespace | quote }}
  labels:
    {{- include "common.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $definition.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- $spec := dict -}}
{{- with $target.workloadSelector -}}{{- $_ := set $spec "selector" (dict "matchLabels" .) -}}{{- end -}}
{{- with $target.targetRefs -}}{{- $_ := set $spec "targetRefs" . -}}{{- end -}}
{{- range $field := list "accessLogging" "tracing" "metrics" -}}
{{- if hasKey $definition $field -}}{{- $_ := set $spec $field (get $definition $field) -}}{{- end -}}
{{- end }}
spec:
  {{- toYaml $spec | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
