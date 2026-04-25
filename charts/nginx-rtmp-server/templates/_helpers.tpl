{{/*
Common helpers
*/}}
{{- define "nginx-rtmp-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "nginx-rtmp-server.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" (include "nginx-rtmp-server.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "nginx-rtmp-server.labels" -}}
app.kubernetes.io/name: {{ include "nginx-rtmp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "nginx-rtmp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nginx-rtmp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
