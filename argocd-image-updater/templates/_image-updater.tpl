{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

argocd-image-updater.imageUpdater renders one native ImageUpdater custom
resource. The glyph resolves a book-default write-back profile from Lexicon,
then overlays the native spec.writeBackConfig so callers can override any
profile field without losing access to new upstream CRD fields.
*/}}
{{- define "argocd-image-updater.imageUpdater" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $name := required "argocd-image-updater.imageUpdater: name is required" $definition.name -}}
{{- $spec := deepCopy (required (printf "argocd-image-updater.imageUpdater '%s': spec is required" $name) $definition.spec) -}}
{{- $_ := required (printf "argocd-image-updater.imageUpdater '%s': spec.applicationRefs is required" $name) $spec.applicationRefs -}}
{{- $profileSettings := deepCopy (default dict $definition.writeBackProfile) -}}
{{- $profileEnabled := true -}}
{{- if hasKey $profileSettings "enabled" -}}
  {{- $profileEnabled = $profileSettings.enabled -}}
{{- end -}}
{{- if $profileEnabled -}}
  {{- $selector := deepCopy (default (dict "default" "book") $profileSettings.selector) -}}
  {{- $profiles := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "argocd-image-writeback" $root.Values.chapter.name) | fromJson) "results" -}}
  {{- if eq (len $profiles) 0 -}}
    {{- fail (printf "argocd-image-updater.imageUpdater '%s': write-back selector %v matched no type=argocd-image-writeback lexicon entry" $name $selector) -}}
  {{- else if gt (len $profiles) 1 -}}
    {{- fail (printf "argocd-image-updater.imageUpdater '%s': write-back selector %v matched multiple type=argocd-image-writeback lexicon entries" $name $selector) -}}
  {{- end -}}
  {{- $profile := index $profiles 0 -}}
  {{- $profileConfig := deepCopy (required (printf "argocd-image-updater.imageUpdater '%s': selected write-back profile requires writeBackConfig" $name) $profile.writeBackConfig) -}}
  {{- $manualConfig := deepCopy (default dict $spec.writeBackConfig) -}}
  {{- $_ := set $spec "writeBackConfig" (mergeOverwrite $profileConfig $manualConfig) -}}
{{- end -}}
---
apiVersion: argocd-image-updater.argoproj.io/v1alpha1
kind: ImageUpdater
metadata:
  name: {{ $name }}
  namespace: {{ default $root.Release.Namespace $definition.namespace }}
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
  {{- toYaml $spec | nindent 2 }}
{{- end -}}
