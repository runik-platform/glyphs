{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

summon.checksums.annotations generates annotations with checksums of ConfigMaps and Secrets
to trigger pod restarts when configuration changes.
*/}}

{{- define "summon.checksums.annotations" -}}
{{- $root := . -}}
{{- if $root.Values.configMaps }}
{{- range $name, $cm := $root.Values.configMaps }}
{{- if and (eq (default "create" $cm.location) "create") $cm.content }}
{{- $contentType := default "file" $cm.contentType }}
{{- if eq $contentType "env" }}
  {{- if kindIs "map" $cm.content }}
checksum/configmap-{{ $name }}: {{ $cm.content | toJson | sha256sum }}
  {{- else }}
checksum/configmap-{{ $name }}: {{ $cm.content | sha256sum }}
  {{- end }}
{{- else if eq $contentType "yaml" }}
checksum/configmap-{{ $name }}: {{ $cm.content | toYaml | sha256sum }}
{{- else if eq $contentType "json" }}
checksum/configmap-{{ $name }}: {{ $cm.content | toJson | sha256sum }}
{{- else if eq $contentType "toml" }}
checksum/configmap-{{ $name }}: {{ $cm.content | toToml | sha256sum }}
{{- else }}
  {{- if kindIs "map" $cm.content }}
checksum/configmap-{{ $name }}: {{ $cm.content | toYaml | sha256sum }}
  {{- else }}
checksum/configmap-{{ $name }}: {{ $cm.content | sha256sum }}
  {{- end }}
{{- end }}
{{- end }}

{{- end }}
{{- end }}
{{- if $root.Values.secrets }}
{{- range $name, $secret := $root.Values.secrets }}
{{- if and (eq (default "create" $secret.location) "create") $secret.content }}
{{- $contentType := default "file" $secret.contentType }}
{{- if eq $contentType "env" }}
  {{- if kindIs "map" $secret.content }}
checksum/secret-{{ $name }}: {{ $secret.content | toJson | sha256sum }}
  {{- else }}
checksum/secret-{{ $name }}: {{ $secret.content | sha256sum }}
  {{- end }}
{{- else if eq $contentType "yaml" }}
checksum/secret-{{ $name }}: {{ $secret.content | toYaml | sha256sum }}
{{- else if eq $contentType "json" }}
checksum/secret-{{ $name }}: {{ $secret.content | toJson | sha256sum }}
{{- else if eq $contentType "toml" }}
checksum/secret-{{ $name }}: {{ $secret.content | toToml | sha256sum }}
{{- else }}
  {{- if kindIs "map" $secret.content }}
checksum/secret-{{ $name }}: {{ $secret.content | toYaml | sha256sum }}
  {{- else }}
checksum/secret-{{ $name }}: {{ $secret.content | sha256sum }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Render pod annotations only after global, pod-specific and generated checksum
annotations have been combined. An empty final map produces no YAML key.
*/}}
{{- define "summon.pod.annotations" -}}
{{- $root := . -}}
{{- $checksums := dict -}}
{{- $renderedChecksums := include "summon.checksums.annotations" $root | trim -}}
{{- if $renderedChecksums -}}
{{- $checksums = fromYaml $renderedChecksums -}}
{{- end -}}
{{- $annotations := include "common.annotations.map" (list $root (default dict $root.Values.podAnnotations) $checksums) | fromJson -}}
{{- with $annotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}
