{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.serviceExposure is a meta-glyph for exposing one existing Kubernetes
Service through a published native NetBird network. It renders the complete
service-owned access bundle:
  1. one destination Group;
  2. one NetworkResource attached to the selected NetworkRouter;
  3. one NetBirdPolicy per access entry.

The selected type=netbird-network lexicon entry must publish routerRef.name
and routerRef.namespace. Generated Groups and NetworkResources are deliberately
not published: every reference inside this bundle is direct and local.

Defaults:
- serviceRef.name: Helm release/Application name
- namespace: Helm release/Application namespace
- destination group: resources-<network>-<service>
- policy: <access-key>-<service>-access

accessName can override the name fragment used by the generated Group and
Policies without changing the Service or NetworkResource identity.

Each access entry uses its map key as the JWT/source group unless
sourceGroupRefs is provided. Shorthand tcp/udp/all fields generate safe accept,
unidirectional rules; advanced consumers may provide rules directly.
*/}}
{{- define "netbird.serviceExposure" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $network := get (include "netbird.networkEntry" (list $root $definition.networkRef (default (dict) $definition.networkSelector) "netbird.serviceExposure network") | fromJson) "entry" -}}
{{- $routerRef := required "netbird.serviceExposure: selected network must publish routerRef" $network.routerRef -}}
{{- $_ := required "netbird.serviceExposure: selected network routerRef.name is required" $routerRef.name -}}
{{- $_ := required "netbird.serviceExposure: selected network routerRef.namespace is required" $routerRef.namespace -}}
{{- $serviceRef := default (dict) $definition.serviceRef -}}
{{- $serviceName := default $root.Release.Name $serviceRef.name -}}
{{- $namespace := default $root.Release.Namespace $definition.namespace -}}
{{- $resourceName := default $serviceName $definition.resourceName -}}
{{- $accessName := default $resourceName $definition.accessName -}}
{{- $networkName := required "netbird.serviceExposure: selected network requires name" $network.name -}}
{{- $groupName := default (printf "resources-%s-%s" $networkName $accessName) $definition.groupName -}}
{{- $access := required "netbird.serviceExposure: access is required" $definition.access -}}

{{ include "netbird.group" (list $root (dict
  "name" $groupName
  "namespace" $namespace
)) }}

{{ include "netbird.networkResource" (list $root (dict
  "name" $resourceName
  "namespace" $namespace
  "networkRouterRef" $routerRef
  "serviceRef" (dict "name" $serviceName)
  "groups" (list $groupName)
)) }}

{{- range $accessKey, $grant := $access -}}
  {{- $sourceGroupRefs := default (list $accessKey) $grant.sourceGroupRefs -}}
  {{- $rules := default (list) $grant.rules -}}
  {{- if not $rules -}}
    {{- if hasKey $grant "tcp" -}}
      {{- $rules = append $rules (dict "name" "tcp" "enabled" true "action" "accept" "bidirectional" false "protocol" "tcp" "ports" $grant.tcp) -}}
    {{- end -}}
    {{- if hasKey $grant "udp" -}}
      {{- $rules = append $rules (dict "name" "udp" "enabled" true "action" "accept" "bidirectional" false "protocol" "udp" "ports" $grant.udp) -}}
    {{- end -}}
    {{- if $grant.all -}}
      {{- $rules = append $rules (dict "name" "all" "enabled" true "action" "accept" "bidirectional" false "protocol" "all") -}}
    {{- end -}}
  {{- end -}}
  {{- if not $rules -}}
    {{- fail (printf "netbird.serviceExposure: access.%s requires tcp, udp, all=true or rules" $accessKey) -}}
  {{- end -}}
{{ include "netbird.policy" (list $root (dict
  "name" (default (printf "%s-%s-access" $accessKey $accessName) $grant.policyName)
  "namespace" $namespace
  "description" (default (printf "Allow %s to reach %s" $accessKey $serviceName) $grant.description)
  "sourceGroupRefs" $sourceGroupRefs
  "destinationGroupRefs" (list $groupName)
  "rules" $rules
)) }}
{{- end -}}
{{- end -}}
