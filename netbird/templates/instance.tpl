{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.instance renders the singleton NetBirdInstance owned by the
complementary operator. The glyph key is a Runik identifier only: Kubernetes
metadata.name is always `default`.

The renderer intentionally mirrors the structural CRD rather than exposing a
second workload API. It adds safe defaults, rejects invalid mode combinations
before they reach Kubernetes, and passes only NetBirdInstance spec fields.
*/}}

{{- define "netbird.instance.secretRef" -}}
{{- $ref := index . 0 -}}
{{- $caller := index . 1 -}}
{{- if not (kindIs "map" $ref) -}}
  {{- fail (printf "%s must be an object with name and key" $caller) -}}
{{- end -}}
{{- $name := required (printf "%s.name is required" $caller) $ref.name -}}
{{- $_ := required (printf "%s.key is required" $caller) $ref.key -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $name) -}}
  {{- fail (printf "%s.name must be a DNS label" $caller) -}}
{{- end -}}
{{- end -}}

{{- define "netbird.instance.componentImage" -}}
{{- $image := index . 0 -}}
{{- $caller := index . 1 -}}
{{- if not (kindIs "map" $image) -}}
  {{- fail (printf "%s.image must be an object" $caller) -}}
{{- end -}}
{{- $_ := required (printf "%s.image.repository is required" $caller) $image.repository -}}
{{- $hasDigest := and (hasKey $image "digest") (not (empty $image.digest)) -}}
{{- $hasTag := and (hasKey $image "tag") (not (empty $image.tag)) -}}
{{- if eq $hasDigest $hasTag -}}
  {{- fail (printf "%s.image requires exactly one of digest or tag" $caller) -}}
{{- end -}}
{{- if and $hasDigest (not (regexMatch "^sha256:[a-f0-9]{64}$" $image.digest)) -}}
  {{- fail (printf "%s.image.digest must be a sha256 digest" $caller) -}}
{{- end -}}
{{- end -}}

{{- define "netbird.instance.service" -}}
{{- $service := index . 0 -}}
{{- $caller := index . 1 -}}
{{- if $service -}}
  {{- if not (kindIs "map" $service) -}}
    {{- fail (printf "%s.service must be an object" $caller) -}}
  {{- end -}}
  {{- if and $service.type (not (has $service.type (list "ClusterIP" "LoadBalancer" "NodePort"))) -}}
    {{- fail (printf "%s.service.type must be ClusterIP, LoadBalancer or NodePort" $caller) -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "netbird.instance" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $spec := deepCopy $definition -}}
{{- range $field := list "type" "name" "namespace" "labels" "annotations" -}}
  {{- $_ := unset $spec $field -}}
{{- end -}}

{{- $management := required "netbird.instance: management is required" $spec.management -}}
{{- if not (kindIs "map" $management) -}}
  {{- fail "netbird.instance: management must be an object" -}}
{{- end -}}
{{- $managementMode := default "managed" $management.mode -}}
{{- $_ := set $management "mode" $managementMode -}}
{{- if not (has $managementMode (list "managed" "external")) -}}
  {{- fail "netbird.instance: management.mode must be managed or external" -}}
{{- end -}}
{{- if eq $managementMode "managed" -}}
  {{- if $management.endpoint -}}
    {{- fail "netbird.instance: managed management forbids endpoint" -}}
  {{- end -}}
  {{- $image := required "netbird.instance: managed management requires image" $management.image -}}
  {{- if not (kindIs "map" $image) -}}
    {{- fail "netbird.instance: management.image must be an object" -}}
  {{- end -}}
  {{- $_ := required "netbird.instance: management.image.repository is required" $image.repository -}}
  {{- $digest := required "netbird.instance: management.image.digest is required" $image.digest -}}
  {{- if $image.tag -}}
    {{- fail "netbird.instance: management.image.tag is forbidden; pin the fork by digest" -}}
  {{- end -}}
  {{- if not (regexMatch "^sha256:[a-f0-9]{64}$" $digest) -}}
    {{- fail "netbird.instance: management.image.digest must be a sha256 digest" -}}
  {{- end -}}
{{- else -}}
  {{- if $management.image -}}
    {{- fail "netbird.instance: external management forbids image" -}}
  {{- end -}}
  {{- $_ := required "netbird.instance: external management requires endpoint" $management.endpoint -}}
  {{- $bootstrapRef := required "netbird.instance: external management requires bootstrapSecretRef" $management.bootstrapSecretRef -}}
  {{- include "netbird.instance.secretRef" (list $bootstrapRef "netbird.instance management.bootstrapSecretRef") -}}
{{- end -}}
{{- include "netbird.instance.service" (list $management.service "netbird.instance management") -}}

{{- with $spec.dashboard -}}
  {{- if not (kindIs "map" .) -}}
    {{- fail "netbird.instance: dashboard must be an object" -}}
  {{- end -}}
  {{- $mode := default "managed" .mode -}}
  {{- $_ := set . "mode" $mode -}}
  {{- if not (has $mode (list "managed" "external")) -}}
    {{- fail "netbird.instance: dashboard.mode must be managed or external" -}}
  {{- end -}}
  {{- if eq $mode "managed" -}}
    {{- include "netbird.instance.componentImage" (list (required "netbird.instance: managed dashboard requires image" .image) "netbird.instance dashboard") -}}
  {{- else -}}
    {{- if .image -}}
      {{- fail "netbird.instance: external dashboard forbids image" -}}
    {{- end -}}
    {{- $_ := required "netbird.instance: external dashboard requires endpoint" .endpoint -}}
  {{- end -}}
  {{- include "netbird.instance.service" (list .service "netbird.instance dashboard") -}}
{{- end -}}

{{- range $field := list "signals" "relays" "stunTurns" -}}
  {{- $items := default (list) (get $spec $field) -}}
  {{- if not (kindIs "slice" $items) -}}
    {{- fail (printf "netbird.instance: %s must be a list" $field) -}}
  {{- end -}}
  {{- if and (eq $field "signals") (gt (len $items) 1) -}}
    {{- fail "netbird.instance: NetBird 0.78 supports at most one Signal" -}}
  {{- end -}}
  {{- $names := dict -}}
  {{- $locations := dict -}}
  {{- range $index, $item := $items -}}
    {{- $caller := printf "netbird.instance %s[%d]" $field $index -}}
    {{- if not (kindIs "map" $item) -}}
      {{- fail (printf "%s must be an object" $caller) -}}
    {{- end -}}
    {{- $name := required (printf "%s.name is required" $caller) $item.name -}}
    {{- $location := required (printf "%s.location is required" $caller) $item.location -}}
    {{- if hasKey $names $name -}}
      {{- fail (printf "netbird.instance: %s names must be unique; duplicate %q" $field $name) -}}
    {{- end -}}
    {{- if hasKey $locations $location -}}
      {{- fail (printf "netbird.instance: %s locations must be unique; duplicate %q" $field $location) -}}
    {{- end -}}
    {{- $_ := set $names $name true -}}
    {{- $_ := set $locations $location true -}}
    {{- $mode := default "managed" $item.mode -}}
    {{- $_ := set $item "mode" $mode -}}
    {{- if not (has $mode (list "managed" "external")) -}}
      {{- fail (printf "%s.mode must be managed or external" $caller) -}}
    {{- end -}}
    {{- if eq $field "stunTurns" -}}
      {{- if eq $mode "managed" -}}
        {{- if hasKey $item "endpoints" -}}
          {{- if or (not (kindIs "slice" $item.endpoints)) (eq (len $item.endpoints) 0) -}}
            {{- fail (printf "%s: endpoints must be a non-empty list when provided" $caller) -}}
          {{- end -}}
        {{- end -}}
        {{- include "netbird.instance.componentImage" (list (required (printf "%s: managed mode requires image" $caller) $item.image) $caller) -}}
      {{- else -}}
        {{- if $item.image -}}
          {{- fail (printf "%s: external mode forbids image" $caller) -}}
        {{- end -}}
        {{- if or (not (kindIs "slice" $item.endpoints)) (eq (len $item.endpoints) 0) -}}
          {{- fail (printf "%s: external mode requires a non-empty endpoints list" $caller) -}}
        {{- end -}}
      {{- end -}}
      {{- with $item.credentialSecretRef -}}
        {{- include "netbird.instance.secretRef" (list . (printf "%s.credentialSecretRef" $caller)) -}}
      {{- end -}}
    {{- else -}}
      {{- if eq $mode "managed" -}}
        {{- if $item.endpoint -}}
          {{- fail (printf "%s: managed mode forbids endpoint" $caller) -}}
        {{- end -}}
        {{- with $item.publicEndpoint -}}
          {{- if and (eq $field "signals") (not (regexMatch "^grpcs?://" .)) -}}
            {{- fail (printf "%s.publicEndpoint must use grpc:// or grpcs://" $caller) -}}
          {{- end -}}
          {{- if and (eq $field "relays") (not (regexMatch "^rels?://" .)) -}}
            {{- fail (printf "%s.publicEndpoint must use rel:// or rels://" $caller) -}}
          {{- end -}}
        {{- end -}}
        {{- include "netbird.instance.componentImage" (list (required (printf "%s: managed mode requires image" $caller) $item.image) $caller) -}}
      {{- else -}}
        {{- if $item.image -}}
          {{- fail (printf "%s: external mode forbids image" $caller) -}}
        {{- end -}}
        {{- if $item.publicEndpoint -}}
          {{- fail (printf "%s: external mode forbids publicEndpoint; use endpoint" $caller) -}}
        {{- end -}}
        {{- $_ := required (printf "%s: external mode requires endpoint" $caller) $item.endpoint -}}
      {{- end -}}
    {{- end -}}
    {{- include "netbird.instance.service" (list $item.service $caller) -}}
  {{- end -}}
{{- end -}}

{{- $database := required "netbird.instance: database is required" $spec.database -}}
{{- if not (kindIs "map" $database) -}}
  {{- fail "netbird.instance: database must be an object" -}}
{{- end -}}
{{- include "netbird.instance.secretRef" (list (required "netbird.instance: database.secretRef is required" $database.secretRef) "netbird.instance database.secretRef") -}}
{{- include "netbird.instance.secretRef" (list (required "netbird.instance: encryptionKeySecretRef is required" $spec.encryptionKeySecretRef) "netbird.instance encryptionKeySecretRef") -}}

{{- $oidc := required "netbird.instance: oidc is required" $spec.oidc -}}
{{- if not (kindIs "map" $oidc) -}}
  {{- fail "netbird.instance: oidc must be an object" -}}
{{- end -}}
{{- $_ := required "netbird.instance: oidc.issuer is required" $oidc.issuer -}}
{{- $_ := required "netbird.instance: oidc.clientID is required" $oidc.clientID -}}
{{- with $oidc.clientSecretRef -}}
  {{- include "netbird.instance.secretRef" (list . "netbird.instance oidc.clientSecretRef") -}}
{{- end -}}

{{- $bootstrap := required "netbird.instance: bootstrap is required" $spec.bootstrap -}}
{{- if not (kindIs "map" $bootstrap) -}}
  {{- fail "netbird.instance: bootstrap must be an object" -}}
{{- end -}}
{{- $_ := required "netbird.instance: bootstrap.accountName is required" $bootstrap.accountName -}}
{{- $ownerName := default "operator-owner" $bootstrap.ownerName -}}
{{- if ne $ownerName "operator-owner" -}}
  {{- fail "netbird.instance: bootstrap.ownerName must be operator-owner" -}}
{{- end -}}
{{- $_ := set $bootstrap "ownerName" $ownerName -}}
{{- $credentialRef := required "netbird.instance: bootstrap.credentialSecretRef is required" $bootstrap.credentialSecretRef -}}
{{- include "netbird.instance.secretRef" (list $credentialRef "netbird.instance bootstrap.credentialSecretRef") -}}
{{- with $bootstrap.adoptionCredentialSecretRef -}}
  {{- include "netbird.instance.secretRef" (list . "netbird.instance bootstrap.adoptionCredentialSecretRef") -}}
  {{- if deepEqual . $credentialRef -}}
    {{- fail "netbird.instance: adoption and output credential Secrets must be different" -}}
  {{- end -}}
{{- end -}}

{{- $lifecycle := default (dict) $spec.lifecycle -}}
{{- if not (kindIs "map" $lifecycle) -}}
  {{- fail "netbird.instance: lifecycle must be an object" -}}
{{- end -}}
{{- $deletionPolicy := default "Retain" $lifecycle.deletionPolicy -}}
{{- if not (has $deletionPolicy (list "Retain" "DeleteRuntime")) -}}
  {{- fail "netbird.instance: lifecycle.deletionPolicy must be Retain or DeleteRuntime" -}}
{{- end -}}
{{- $_ := set $lifecycle "deletionPolicy" $deletionPolicy -}}
{{- $_ := set $spec "lifecycle" $lifecycle -}}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdInstance
metadata:
  name: default
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
  {{- toYaml $spec | nindent 2 }}
{{ end }}
