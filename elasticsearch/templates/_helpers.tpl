{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}

{{/* Resolve the shared cluster coordinates published as type: elasticsearch. */}}
{{- define "elasticsearch.resolveLexicon" -}}
{{- $root := index . 0 -}}
{{- $selector := default dict (index . 1) -}}
{{- $entries := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "elasticsearch" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $entries -}}
  {{- fail (printf "elasticsearch: no 'type: elasticsearch' entry found in lexicon for selector %v" $selector) -}}
{{- end -}}
{{- $e := index $entries 0 -}}
{{- $cluster := default $e.name $e.clusterName -}}
{{- $ns := default "elastic-infra" $e.namespace -}}
{{- $host := default (printf "%s-es-http.%s.svc" $cluster $ns) $e.host -}}
{{- $tlsEnabled := true -}}
{{- if and (hasKey $e "tls") (hasKey $e.tls "enabled") -}}
  {{- $tlsEnabled = $e.tls.enabled -}}
{{- end -}}
{{- $derivedScheme := ternary "https" "http" $tlsEnabled -}}
{{- if and (hasKey $e "scheme") (ne $e.scheme $derivedScheme) (and (hasKey $e "tls") (hasKey $e.tls "enabled")) -}}
  {{- fail (printf "elasticsearch: scheme %q conflicts with tls.enabled=%v" $e.scheme $tlsEnabled) -}}
{{- end -}}
{{- dict
      "clusterName" $cluster
      "namespace" $ns
      "host" $host
      "port" (toString (default "9200" $e.port))
      "scheme" (default $derivedScheme $e.scheme)
      "tlsEnabled" $tlsEnabled
      "databaseMount" (default "database" $e.databaseMount)
      "legacyDatabaseMount" (hasKey $e "databaseMount")
      "credentialsSecret" (default (printf "%s-es-elastic-user" $cluster) $e.credentialsSecret)
      "credentialsKey" (default "elastic" $e.credentialsKey)
      "engineConfigNamespace" (default $ns $e.engineConfigNamespace)
      "engineServiceAccount" (default $cluster $e.engineServiceAccount)
      "engineAuthRole" (default $cluster $e.engineAuthRole)
  | toJson -}}
{{- end -}}
