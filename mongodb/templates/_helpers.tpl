{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

Non-rendering helpers shared by the Percona and logical MongoDB glyphs.
*/}}

{{- define "mongodb.safeName" -}}
{{- $raw := toString . -}}
{{- $slug := regexReplaceAll "[^a-z0-9-]+" (lower $raw) "-" | trimAll "-" -}}
{{- if gt (len $slug) 63 -}}
{{- printf "%s-%s" (trunc 54 $slug | trimSuffix "-") (trunc 8 (sha256sum $raw)) -}}
{{- else -}}
{{- $slug -}}
{{- end -}}
{{- end -}}

{{- define "mongodb.access" -}}
{{- $requested := default "readWrite" . -}}
{{- $aliases := dict "rw" "readWrite" "ro" "readOnly" -}}
{{- $access := default $requested (get $aliases $requested) -}}
{{- if not (has $access (list "readOnly" "readWrite" "schemaAdmin" "owner")) -}}
  {{- fail (printf "mongodb: unsupported access %q (expected readOnly, readWrite, schemaAdmin or owner)" $requested) -}}
{{- end -}}
{{- $access -}}
{{- end -}}

{{- define "mongodb.resolveCluster" -}}
{{- $root := index . 0 -}}
{{- $requested := index . 1 -}}
{{- $selector := dict -}}
{{- if kindIs "string" $requested -}}
  {{- $selector = dict "name" $requested -}}
{{- else -}}
  {{- $selector = default dict $requested -}}
{{- end -}}
{{- $entries := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "mongodb" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $entries -}}
  {{- fail (printf "mongodb: no type=mongodb lexicon entry matches selector %v" $selector) -}}
{{- end -}}
{{- $entry := index $entries 0 -}}
{{- $clusterName := default $entry.name $entry.clusterName -}}
{{- $engineName := default $clusterName $entry.engineName -}}
{{- $namespace := default "databases" $entry.namespace -}}
{{- $sharded := default false $entry.sharded -}}
{{- $replset := default "rs0" $entry.replset -}}
{{- /* Percona's generated server certificate contains the complete Kubernetes
       service FQDN, but not the intermediate .svc name. Keep client coordinates
       verifiable by default instead of requiring insecure hostname handling. */ -}}
{{- $defaultHost := ternary (printf "%s-mongos.%s.svc.cluster.local" $clusterName $namespace) (printf "%s-%s.%s.svc.cluster.local" $clusterName $replset $namespace) $sharded -}}
{{- dict
      "clusterName" $clusterName
      "engineName" $engineName
      "namespace" $namespace
      "host" (default $defaultHost $entry.host)
      "port" (toString (default "27017" $entry.port))
      "replset" $replset
      "sharded" $sharded
      "tls" (ne false $entry.tls)
  | toJson -}}
{{- end -}}
