{{- define "nuphos.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 50 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 50 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "nuphos.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}

{{/* Usage: include "nuphos.selectorLabels" (list $ "backend") */}}
{{- define "nuphos.selectorLabels" -}}
{{- $ := index . 0 -}}
app.kubernetes.io/name: {{ $.Chart.Name }}
app.kubernetes.io/instance: {{ $.Release.Name }}
app.kubernetes.io/component: {{ index . 1 }}
{{- end -}}

{{/* A map as comma-separated key=value, the shape optionalList() reads. */}}
{{- define "nuphos.keyValues" -}}
{{- $pairs := list -}}
{{- range $k, $v := . -}}
{{- $pairs = append $pairs (printf "%s=%s" $k $v) -}}
{{- end -}}
{{- join "," $pairs -}}
{{- end -}}

{{- define "nuphos.secretName" -}}
{{- .Values.secrets.existingSecret | default (printf "%s-secrets" (include "nuphos.fullname" .)) -}}
{{- end -}}

{{/* Stable pod DNS name; the replica set member and backend URI both use it. */}}
{{- define "nuphos.mongoHost" -}}
{{- $name := printf "%s-mongo" (include "nuphos.fullname" .) -}}
{{- printf "%s-0.%s.%s.svc" $name $name .Release.Namespace -}}
{{- end -}}


{{- define "nuphos.backendUrl" -}}
{{- required "backend.url is required" .Values.backend.url | trimSuffix "/" -}}
{{- end -}}

{{- define "nuphos.storageUrl" -}}
{{- required "storage.url is required" .Values.storage.url | trimSuffix "/" -}}
{{- end -}}

{{- define "nuphos.runtimeUrl" -}}
{{- required "runtime.url is required when runtime.enabled" .Values.runtime.url | trimSuffix "/" -}}
{{- end -}}
