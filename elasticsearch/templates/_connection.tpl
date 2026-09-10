{{/*
SPDX-License-Identifier: AGPL-3.0-only

elasticsearch.connection registers an ECK cluster in Vault's database secrets
engine without provisioning or mutating Elasticsearch. The official ECK chart
owns the Elasticsearch CR and its generated `elastic` user Secret.

The DatabaseSecretEngineConfig is created in the ECK namespace so
vault-config-operator can read that Secret without cross-namespace copying.
HTTPS remains the default, while an explicitly published HTTP lexicon entry is
accepted for clusters whose network boundary provides the transport isolation.
Root rotation is forbidden: ECK owns the generated Secret and would otherwise
retain the old password while Vault changed Elasticsearch behind its back.
*/}}
{{- define "elasticsearch.connection" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- if eq true $g.rootRotation -}}
  {{- fail "elasticsearch.connection: rootRotation must remain false when using the ECK-managed elastic user" -}}
{{- end -}}
{{- $es := include "elasticsearch.resolveLexicon" (list $root $g.cluster) | fromJson -}}
{{- $name := default $es.clusterName $g.name -}}
{{- $namespace := default $es.namespace $g.configNamespace -}}
{{- $serviceAccount := default (include "common.name" $root) $g.serviceAccount -}}
{{- $url := default (printf "%s://%s:%s" $es.scheme $es.host $es.port) $g.url -}}
{{- if not (has $es.scheme (list "http" "https")) -}}
  {{- fail "elasticsearch.connection: scheme must be http or https" -}}
{{- end -}}
{{ include "vault.databaseEngine" (list $root (dict
    "name" $name
    "pluginName" "elasticsearch-database-plugin"
    "omitConnectionURL" true
    "databaseSpecificConfig" (dict "url" $url)
    "username" (default "elastic" $g.username)
    "passwordKey" (default $es.credentialsKey $g.passwordKey)
    "credentialsSecret" (default $es.credentialsSecret $g.credentialsSecret)
    "allowedRoles" (default (list "*") $g.allowedRoles)
    "databaseMount" (default $es.databaseMount $g.databaseMount)
    "configNamespace" $namespace
    "serviceAccount" $serviceAccount
    "customRole" $g.customRole
    "selector" $g.selector
    "verifyConnection" true
    "rootRotation" false
)) }}
{{- end -}}
