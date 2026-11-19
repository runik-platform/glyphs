{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

istio.gatewayObservability owns one workload-selected Telemetry and an optional
Grafana dashboard. Do not combine it with another selector-based Telemetry for
the same gateway: pass existing tracing entries through tracing instead.

Association: selector queries istio-gw lexicon entries, or target explicitly
selects workload labels (see istio.telemetry). Required: accessLogs.provider.
The provider must emit JSON with the gateway_access schema used by the bundled
dashboard: log_type, peer_ip, forwarded_for, authority, path, response_code,
response_flags, response_code_details, upstream_cluster (see example).
Mesh provider registration remains the responsibility of the Istio installation.

Optional: enabled (default true), namespace, telemetryName, labels, annotations,
metrics (native Telemetry array),
tracing (native Telemetry array), accessLogs.filter (CEL), dashboard.enabled,
dashboard.name/uid/title/folder/metricsDatasourceUid/logsDatasourceUid.
Only errors are logged by default. Forwarded headers are untrusted, and socket
IPs may identify a proxy/NAT. HTTP metrics and logs do not cover every TCP flow.
*/}}
{{- define "istio.gatewayObservability" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- if or (not (hasKey $definition "enabled")) $definition.enabled -}}
{{- $targets := get (include "istio.telemetry.targets" (list $root $definition) | fromJson) "targets" -}}
{{- $baseName := default (include "common.name" $root) $definition.name -}}
{{- $access := default dict $definition.accessLogs -}}
{{- $provider := required "istio.gatewayObservability requires accessLogs.provider registered in meshConfig.extensionProviders" $access.provider -}}
{{- $baseDashboard := default dict $definition.dashboard -}}
{{- range $target := $targets -}}
{{- $namespace := $target.namespace -}}
{{- if not $target.workloadSelector -}}{{- fail "istio.gatewayObservability requires a workloadSelector target; use istio.telemetry for other scopes" -}}{{- end -}}
{{- $name := $baseName -}}
{{- $dashboard := deepCopy $baseDashboard -}}
{{- $telemetryName := default $baseName $definition.telemetryName -}}
{{- if gt (len $targets) 1 -}}
  {{- $suffix := toJson $target | sha256sum | trunc 10 -}}
  {{- $name = printf "%s-%s" ($baseName | trunc 52 | trimSuffix "-") $suffix -}}
  {{- $telemetryName = printf "%s-%s" ($telemetryName | trunc 52 | trimSuffix "-") $suffix -}}
  {{- if $dashboard.name -}}{{- $_ := set $dashboard "name" (printf "%s-%s" ($dashboard.name | trunc 52 | trimSuffix "-") $suffix) -}}{{- end -}}
  {{- if $dashboard.uid -}}{{- $_ := set $dashboard "uid" (printf "%s-%s" ($dashboard.uid | trunc 29 | trimSuffix "-") $suffix) -}}{{- end -}}
{{- end -}}
{{- $telemetry := dict "name" $telemetryName "target" $target "accessLogging" (list (dict "providers" (list (dict "name" $provider)) "filter" (dict "expression" (default "!has(response.code) || response.code == 0 || response.code >= 400" $access.filter)))) -}}
{{- range $field := list "tracing" "metrics" "labels" "annotations" -}}
{{- if hasKey $definition $field -}}{{- $_ := set $telemetry $field (get $definition $field) -}}{{- end -}}
{{- end -}}
{{ include "istio.telemetry" (list $root $telemetry) }}
{{- if or (not (hasKey $dashboard "enabled")) $dashboard.enabled -}}
{{- $metricsUid := default "mimir" $dashboard.metricsDatasourceUid -}}
{{- $logsUid := default "loki" $dashboard.logsDatasourceUid -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $namespace) -}}
{{- fail "gatewayObservability namespace must be a DNS label" -}}
{{- end -}}
{{- range $uid := list $metricsUid $logsUid -}}
{{- if not (regexMatch "^[A-Za-z0-9_-]+$" $uid) -}}
{{- fail "gatewayObservability datasource UIDs must contain only letters, numbers, underscores or hyphens" -}}
{{- end -}}
{{- end -}}
{{- $json := required "missing bundled Istio gateway dashboard" ($root.Subcharts.istio.Files.Get "files/gateway-errors-dashboard.json") -}}
{{- $json = replace "__GATEWAY_NAMESPACE__" $namespace $json -}}
{{- $json = replace "__METRICS_UID__" $metricsUid $json -}}
{{- $json = replace "__LOGS_UID__" $logsUid $json -}}
{{- $content := mustFromJson $json -}}
{{- $_ := set $content "uid" (default (printf "gateway-%s" (printf "%s/%s" $namespace $name | sha256sum | trunc 24)) $dashboard.uid) -}}
{{- $_ := set $content "title" (default (printf "Gateway — %s — errors and origins" $namespace) $dashboard.title) -}}
{{ printf "\n---\n" }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ default (printf "%s-dashboard" $name) $dashboard.name | quote }}
  namespace: {{ $namespace | quote }}
  labels:
    {{- include "common.labels" $root | nindent 4 }}
    grafana_dashboard: "1"
  annotations:
    grafana_folder: {{ default "infrastructure/gateways" $dashboard.folder | quote }}
data:
  gateway-errors.json: |
    {{- mustToPrettyJson $content | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
