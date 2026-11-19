{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

s3.bucket.names is shared by the producer and Summon's native env consumer.
instance is an explicit, stable isolation key, independent of nameSuffix.
Without it every legacy name and Vault coordinate is preserved verbatim.
With it the logical glyph name remains unchanged; physical names include a
hash of the full book/chapter/namespace/name/instance tuple, even when short.
*/}}
{{- define "s3.bucket.physicalName" -}}
{{- $prefix := regexReplaceAll "[^a-z0-9-]+" (lower (index . 0)) "-" | trimAll "-" -}}
{{- $hash := index . 1 | toJson | sha256sum | trunc 16 -}}
{{- $limit := int (index . 2) -}}
{{- printf "%s-%s" ($prefix | trunc (int (sub $limit 17)) | trimSuffix "-") $hash -}}
{{- end -}}

{{- define "s3.bucket.names" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $p := index . 2 -}}
{{- $ns := default $root.Release.Namespace $g.namespace -}}
{{- $identity := printf "%s-%s-%s" $root.Values.spellbook.name $root.Values.chapter.name $g.name -}}
{{- $bucket := default $identity $g.bucket -}}
{{- $credentials := printf "s3-identities-%s-%s" $p.name $g.name -}}
{{- $appSecret := $g.name -}}
{{- if hasKey $g "instance" -}}
  {{- if not (kindIs "string" $g.instance) -}}{{- fail "s3.bucket: instance must be a non-empty DNS label string" -}}{{- end -}}
  {{- if or (gt (len $g.instance) 63) (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $g.instance)) -}}{{- fail "s3.bucket: instance must be a non-empty DNS label string of at most 63 characters" -}}{{- end -}}
  {{- $scope := list $root.Values.spellbook.name $root.Values.chapter.name $ns $g.name $g.instance -}}
  {{- $identity = include "s3.bucket.physicalName" (list (printf "%s-%s" $identity $g.instance) $scope 44) -}}
  {{- $bucket = include "s3.bucket.physicalName" (list (printf "%s-%s" $bucket $g.instance) (list $scope $bucket) 63) -}}
  {{- $credentials = printf "s3-identities-%s-%s" $p.name $identity -}}
  {{- /* Preserve the provider policy's s3-identities-<provider>-* prefix.
        CR names are DNS subdomains (253); reserve the random-key suffix. */ -}}
  {{- if gt (len $credentials) 231 -}}{{- fail "s3.bucket: provider name leaves no room for instance credential resources" -}}{{- end -}}
  {{- $appSecret = $identity -}}
{{- end -}}
{{- $providerResource := $credentials -}}
{{- if hasKey $g "instance" -}}{{- $providerResource = printf "%s-provider" $credentials -}}{{- end -}}
{{- toJson (dict "namespace" $ns "identity" $identity "bucket" $bucket "credentials" $credentials "appSecret" $appSecret "providerResource" $providerResource) -}}
{{- end -}}

{{/* Both sides use the existing indexer with a copy of the same selector. */}}
{{- define "s3.bucket.providers" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $selector := deepCopy (default (dict "default" "book") $g.selector) -}}
{{- $providers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "s3-provider" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $providers -}}{{- fail (printf "s3.bucket: No S3 provider found for selector %v. Register an s3-provider lexicon entry." $selector) -}}{{- end -}}
{{- if and (hasKey $g "instance") (ne (len $providers) 1) -}}{{- fail "s3.bucket: instance requires exactly one S3 provider" -}}{{- end -}}
{{- range $provider := $providers -}}
  {{- $backend := default "versity" $provider.provider -}}
  {{- if ne $backend "versity" -}}{{- fail (printf "s3.bucket: unsupported provider %q; managed bucket access requires versity" $backend) -}}{{- end -}}
{{- end -}}
{{- toJson $providers -}}
{{- end -}}
