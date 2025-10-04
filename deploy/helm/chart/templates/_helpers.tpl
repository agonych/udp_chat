{{/* =========================================
   Common naming helpers
   ========================================= */}}

{{- define "udpchat.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "udpchat.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "udpchat.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "udpchat.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}


{{/* =========================================
   Labels & selectors
   ========================================= */}}

{{- define "udpchat.labels" -}}
app.kubernetes.io/name: {{ include "udpchat.name" . }}
helm.sh/chart: {{ include "udpchat.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
{{- end -}}

{{- define "udpchat.selectorLabels" -}}
app.kubernetes.io/name: {{ include "udpchat.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}


{{/* =========================================
   Environment & colour helpers
   - deployTarget: testing | blue | green | both | www
   - activeColor:  green | blue (for www routing)
   ========================================= */}}

{{- define "udpchat.isTesting" -}}
{{- eq (default "testing" .Values.deployTarget | lower) "testing" -}}
{{- end -}}

{{- define "udpchat.isProd" -}}
{{- not (include "udpchat.isTesting" . | eq "true") -}}
{{- end -}}

{{- define "udpchat.currentColour" -}}
{{- $t := default "" .Values.deployTarget | lower -}}
{{- if or (eq $t "blue") (eq $t "green") -}}
{{- $t -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "udpchat.colourSuffix" -}}
{{- $c := include "udpchat.currentColour" . -}}
{{- if $c -}}
-{{ $c }}
{{- end -}}
{{- end -}}

{{- define "udpchat.activeColour" -}}
{{- default "green" (.Values.activeColor | lower) -}}
{{- end -}}

{{/* Build a name that is colour-aware in prod and plain in testing.
     Usage: {{ include "udpchat.colouredName" (dict "root" . "base" "nginx") }} */}}
{{- define "udpchat.colouredName" -}}
{{- $ := .root -}}
{{- $base := .base -}}
{{- if (include "udpchat.isTesting" $ | eq "true") -}}
{{- $base -}}
{{- else -}}
{{- printf "%s%s" $base (include "udpchat.colourSuffix" $) -}}
{{- end -}}
{{- end -}}


{{/* =========================================
   Hosts & TLS helpers
   ========================================= */}}

{{- define "udpchat.host.testing" -}}
{{- printf "%s.%s" (default "testing" .Values.testing.subdomain) .Values.domain -}}
{{- end -}}

{{- define "udpchat.host.blue" -}}
{{- printf "%s.%s" (default "blue" .Values.prod.subdomains.blue) .Values.domain -}}
{{- end -}}

{{- define "udpchat.host.green" -}}
{{- printf "%s.%s" (default "green" .Values.prod.subdomains.green) .Values.domain -}}
{{- end -}}

{{- define "udpchat.host.www" -}}
{{- printf "%s.%s" (default "www" .Values.prod.subdomains.www) .Values.domain -}}
{{- end -}}

{{- define "udpchat.host.root" -}}
{{- .Values.domain -}}
{{- end -}}

{{- define "udpchat.tlsSecretName" -}}
{{- default "wildcard-udpchat-tls" .Values.certificate.secretName -}}
{{- end -}}


{{/* =========================================
   Component name shorthands
   ========================================= */}}

{{/* Service/Deployment names for components, colour-aware in prod */}}
{{- define "udpchat.name.nginx" -}}
{{- include "udpchat.colouredName" (dict "root" . "base" "nginx") -}}
{{- end -}}

{{- define "udpchat.name.connector" -}}
{{- include "udpchat.colouredName" (dict "root" . "base" "connector") -}}
{{- end -}}

{{- define "udpchat.name.udp" -}}
{{- include "udpchat.colouredName" (dict "root" . "base" "udp-server") -}}
{{- end -}}


{{/* =========================================
   Image helpers
   ========================================= */}}

{{- define "udpchat.image.nginx" -}}
{{- default "nginx:1.27-alpine" .Values.images.nginx -}}
{{- end -}}

{{- define "udpchat.image.connector" -}}
{{- required "values.images.connector is required" .Values.images.connector -}}
{{- end -}}

{{- define "udpchat.image.udp" -}}
{{- required "values.images.udp is required" .Values.images.udp -}}
{{- end -}}
