{{/*
Deprecated template alias for spells using the legacy freeForm key.
The implementation lives exclusively in the free-form chart.
*/}}
{{- define "freeForm.manifest" -}}
{{- include "free-form.manifest" . -}}
{{- end -}}
