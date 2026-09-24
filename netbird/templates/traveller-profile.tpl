{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.travellerProfile composes the existing exitNode and nameserverGroup
primitives for roaming clients. Full-tunnel distribution remains opt-in:
autoApply defaults to false and is passed unchanged to every generated route.
*/}}
{{- define "netbird.travellerProfile" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $_ := include "netbird.requireInstance" (list $root $definition "netbird.travellerProfile") }}
{{- $name := $definition.name -}}
{{- $namespace := default $root.Release.Namespace $definition.namespace -}}
{{- $sourceRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.sourceGroupRefs) (default (dict) $definition.sourceGroupsSelector) "netbird-group" "netbird.travellerProfile source groups") | fromJson) "refs" -}}
{{- $routerRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.routingPeerGroupRefs) (default (dict) $definition.routingPeerGroupsSelector) "netbird-group" "netbird.travellerProfile routing peer groups") | fromJson) "refs" -}}
{{- $postureRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.sourcePostureCheckRefs) (default (dict) $definition.sourcePostureChecksSelector) "netbird-posture-check" "netbird.travellerProfile source posture checks") | fromJson) "refs" -}}
{{- if not $sourceRefs -}}{{- fail "netbird.travellerProfile: at least one source group is required" -}}{{- end -}}
{{- if not $routerRefs -}}{{- fail "netbird.travellerProfile: at least one routing-peer group is required" -}}{{- end -}}
{{- $autoApply := false -}}
{{- if hasKey $definition "autoApply" -}}{{- $autoApply = $definition.autoApply -}}{{- end -}}
{{- $enabled := true -}}
{{- if hasKey $definition "enabled" -}}{{- $enabled = $definition.enabled -}}{{- end -}}
{{- $metric := 9999 -}}
{{- if hasKey $definition "metric" -}}{{- $metric = $definition.metric -}}{{- end -}}
{{- $keepRoute := false -}}
{{- if hasKey $definition "keepRoute" -}}{{- $keepRoute = $definition.keepRoute -}}{{- end -}}
{{- $dnsName := printf "%s-dns" $name -}}
{{- range $generated := list $name (printf "%s-peer-access" $name) $dnsName -}}
  {{- if gt (len $generated) 63 -}}{{- fail (printf "netbird.travellerProfile: generated name %q exceeds 63 characters" $generated) -}}{{- end -}}
{{- end -}}

{{ include "netbird.exitNode" (list $root (dict
  "name" $name
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" (default $name $definition.nbName)
  "description" (default (printf "Traveller full-tunnel profile %s" $name) $definition.description)
  "policyDescription" $definition.policyDescription
  "networkId" (default $name $definition.networkId)
  "sourceGroupRefs" $sourceRefs
  "routingPeerGroupRefs" $routerRefs
  "sourcePostureCheckRefs" $postureRefs
  "autoApply" $autoApply
  "enabled" $enabled
  "metric" $metric
  "keepRoute" $keepRoute
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}

{{- $dns := default (dict) $definition.dns -}}
{{- if not (kindIs "map" $dns) -}}{{- fail "netbird.travellerProfile: dns must be an object" -}}{{- end -}}
{{- if $dns }}
  {{- $nameservers := required "netbird.travellerProfile: dns.nameservers is required" $dns.nameservers -}}
{{ include "netbird.nameserverGroup" (list $root (dict
  "name" (default $dnsName $dns.name)
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" (default $dnsName $dns.nbName)
  "description" (default (printf "DNS for traveller profile %s" $name) $dns.description)
  "nameservers" $nameservers
  "domains" $dns.domains
  "enabled" (ternary $dns.enabled true (hasKey $dns "enabled"))
  "primary" (ternary $dns.primary true (hasKey $dns "primary"))
  "searchDomainsEnabled" (ternary $dns.searchDomainsEnabled false (hasKey $dns "searchDomainsEnabled"))
  "groupRefs" $sourceRefs
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}
{{- end -}}

{{- $routes := default (dict) $definition.additionalRoutes -}}
{{- if not (kindIs "map" $routes) -}}{{- fail "netbird.travellerProfile: additionalRoutes must be a map" -}}{{- end -}}
{{- range $routeKey, $route := $routes }}
  {{- if not (kindIs "map" $route) -}}{{- fail (printf "netbird.travellerProfile: additionalRoutes.%s must be an object" $routeKey) -}}{{- end -}}
  {{- $routeName := printf "%s-%s" $name $routeKey -}}
  {{- if gt (len $routeName) 63 -}}{{- fail (printf "netbird.travellerProfile: generated route name %q exceeds 63 characters" $routeName) -}}{{- end -}}
{{ include "netbird.route" (list $root (dict
  "name" $routeName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "description" (default (printf "Additional traveller route %s" $routeKey) $route.description)
  "networkId" (default $routeName $route.networkId)
  "network" $route.network
  "domains" $route.domains
  "peerGroupRefs" $routerRefs
  "groupRefs" $sourceRefs
  "accessControlGroupRefs" $routerRefs
  "enabled" (ternary $route.enabled $enabled (hasKey $route "enabled"))
  "masquerade" true
  "metric" (ternary $route.metric $metric (hasKey $route "metric"))
  "keepRoute" (ternary $route.keepRoute $keepRoute (hasKey $route "keepRoute"))
  "skipAutoApply" (not $autoApply)
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}
{{- end }}
{{ end }}
