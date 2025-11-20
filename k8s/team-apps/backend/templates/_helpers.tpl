{{/*
Expand the name of the chart.
*/}}
{{- define "backend-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "backend-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "backend-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "backend-app.labels" -}}
helm.sh/chart: {{ include "backend-app.chart" . }}
{{ include "backend-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/team: {{ .Values.teamName }}
{{- if .Values.version.name }}
app.kubernetes.io/app-version: {{ .Values.version.name | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "backend-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "backend-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ .Values.teamName }}
{{- end }}
