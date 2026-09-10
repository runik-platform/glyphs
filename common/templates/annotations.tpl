{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}

{{/*
Standard Kubernetes annotations
https://kubernetes.io/docs/reference/labels-annotations-taints/

Annotations store non-identifying metadata that is not used for selection.
They can contain structured or unstructured data and are ideal for:
- Build/release/deployment information
- Client tool configurations
- Human-readable descriptions
- External system references
*/}}
{{/*
Build a single annotations map before rendering it. Callers that need to add
resource-specific or generated annotations can pass them as the second and
third arguments. Later maps take precedence over earlier maps.
*/}}
{{- define "common.annotations.map" -}}
{{- $root := index . 0 -}}
{{- $local := default dict (index . 1) -}}
{{- $generated := default dict (index . 2) -}}
{{- $annotations := dict -}}
{{- with $root.Values.description -}}
{{- $_ := set $annotations "kubernetes.io/description" . -}}
{{- end -}}
{{- $_ := mergeOverwrite $annotations (deepCopy (default dict $root.Values.annotations)) -}}
{{- $_ := mergeOverwrite $annotations (deepCopy $local) -}}
{{- $_ := mergeOverwrite $annotations (deepCopy $generated) -}}
{{- toJson $annotations -}}
{{- end -}}

{{- define "common.annotations" -}}
{{- $annotations := include "common.annotations.map" (list . dict dict) | fromJson -}}
{{- with $annotations -}}
{{- toYaml . -}}
{{- end -}}
{{- end -}}
