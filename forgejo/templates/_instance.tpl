{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

forgejo.instance renders one hyperspike.io/v1 Gitea compatibility resource.
Selectors are Runik-only input and are replaced with concrete Kubernetes
references before the CR reaches the operator.
*/}}
{{- define "forgejo.instance" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $spec := deepCopy (required "forgejo.instance: spec is required" $definition.spec) -}}

{{- if hasKey $definition "connectionSelector" -}}
  {{- $entry := include "forgejo.entry" (list $root (default dict $definition.connectionSelector) "forgejo-instance" "forgejo.instance connection") | fromJson -}}
  {{- $connection := deepCopy (default dict $spec.connection) -}}
  {{- if or $connection.url $connection.service -}}
    {{- fail "forgejo.instance: connectionSelector cannot be combined with spec.connection.url or service" -}}
  {{- end -}}
  {{- if $entry.url -}}
    {{- $_ := set $connection "url" $entry.url -}}
  {{- else -}}
    {{- $service := deepCopy (default dict $entry.service) -}}
    {{- if not $service.name }}{{- $_ := set $service "name" (default $entry.name $entry.serviceName) -}}{{- end -}}
    {{- with $entry.namespace }}{{- if not $service.namespace }}{{- $_ := set $service "namespace" . -}}{{- end }}{{- end -}}
    {{- with $entry.port }}{{- if not $service.port }}{{- $_ := set $service "port" . -}}{{- end }}{{- end -}}
    {{- with $entry.scheme }}{{- if not $service.scheme }}{{- $_ := set $service "scheme" . -}}{{- end }}{{- end -}}
    {{- $_ := required "forgejo.instance: selected forgejo-instance must publish url or service.name" $service.name -}}
    {{- $_ := set $connection "service" $service -}}
  {{- end -}}
  {{- $_ := set $spec "connection" $connection -}}
{{- end -}}

{{- $postgres := deepCopy (default dict $spec.postgres) -}}
{{- if hasKey $postgres "selector" -}}
  {{- if $postgres.provider }}{{- fail "forgejo.instance: postgres.selector selects an existing cluster and cannot be combined with provider" -}}{{- end -}}
  {{- $entry := include "forgejo.entry" (list $root (default dict $postgres.selector) "postgres" "forgejo.instance postgres") | fromJson -}}
  {{- $existing := deepCopy (default dict $postgres.existing) -}}
  {{- if not $existing.host }}{{- $_ := set $existing "host" (required "forgejo.instance: selected postgres entry must publish host" $entry.host) -}}{{- end -}}
  {{- if not $existing.port }}{{- $_ := set $existing "port" (default 5432 $entry.port) -}}{{- end -}}
  {{- $_ := unset $postgres "selector" -}}
  {{- $_ := set $postgres "existing" $existing -}}
  {{- $_ := set $spec "postgres" $postgres -}}
{{- end -}}

{{- $storage := deepCopy (default dict $spec.objectStorage) -}}
{{- if hasKey $storage "selector" -}}
  {{- $entry := include "forgejo.entry" (list $root (default dict $storage.selector) "s3-provider" "forgejo.instance object storage") | fromJson -}}
  {{- if not $storage.type }}{{- $_ := set $storage "type" "s3" -}}{{- end -}}
  {{- if not $storage.endpoint }}{{- $_ := set $storage "endpoint" (required "forgejo.instance: selected s3-provider must publish endpoint" $entry.endpoint) -}}{{- end -}}
  {{- if not $storage.region }}{{- $_ := set $storage "region" (default "us-east-1" $entry.region) -}}{{- end -}}
  {{- $_ := unset $storage "selector" -}}
  {{- $_ := set $spec "objectStorage" $storage -}}
{{- end -}}

{{ include "forgejo.resource" (list $root $definition "Gitea" $spec) }}
{{- end -}}
