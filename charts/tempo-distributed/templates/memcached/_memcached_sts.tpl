{{/*
memcached StatefulSet
*/}}
{{- define "tempo.memcached.statefulSet" -}}
{{ with $.memcacheConfig }}
{{- if .enabled -}}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "tempo.resourceName" (dict "ctx" $.ctx "component" $.component) }}
  labels:
    {{- include "tempo.labels" (dict "ctx" $.ctx "component" "memcached") | nindent 4 }}
  {{- if .annotations }}
  annotations:
    {{- toYaml .annotations | nindent 4 }}
  {{- end }}
  namespace: {{ $.ctx.Release.Namespace | quote }}
spec:
  podManagementPolicy: {{ .podManagementPolicy }}
  replicas: {{ .replicas }}
  selector:
    matchLabels:
      {{- include "tempo.selectorLabels" (dict "ctx" $.ctx "component" $.component) | nindent 6 }}
  updateStrategy:
    {{- toYaml .statefulStrategy | nindent 4 }}
  serviceName: {{ template "tempo.fullname" $.ctx }}-{{ $.component }}
  {{- if .volumeClaimTemplates }}
  volumeClaimTemplates:
  {{- with .volumeClaimTemplates }}
      {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
  template:
    metadata:
      labels:
        {{- include "tempo.podLabels" $ | nindent 8 }}
      annotations:
        {{- with $.ctx.Values.global.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- with .podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      serviceAccountName: {{ template "tempo.serviceAccountName" $.ctx }}
      {{- if .priorityClassName }}
      priorityClassName: {{ .priorityClassName }}
      {{- end }}
      {{- with $.ctx.Values.tempo.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .initContainers }}
      initContainers:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $.ctx.Values.parquetFooterCache.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- tpl . $ | nindent 8 }}
      {{- end }}
      {{- with .tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .terminationGracePeriodSeconds }}
      {{- include "tempo.memcachedExporterImagePullSecrets" $.ctx | nindent 6 -}}
      {{- with .dnsConfig }}
      dnsConfig:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumes:
        {{- with .extraVolumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- with $.ctx.Values.global.extraVolumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      containers:
        {{- if .extraContainers }}
        {{ toYaml .extraContainers | nindent 8 }}
        {{- end }}
        - name: memcached
          {{- with $.ctx.Values.memcached.image }}
          image: {{ .repository }}:{{ .tag }}
          imagePullPolicy: {{ .pullPolicy }}
          {{- end }}
          resources:
          {{- if .resources }}
            {{- toYaml .resources | nindent 12 }}
          {{- else }}
          {{- /* Calculate requested memory as round(allocatedMemory * 1.2). But with integer built-in operators. */}}
          {{- $requestMemory := div (add (mul .allocatedMemory 12) 5) 10 }}
            limits:
              memory: {{ $requestMemory }}Mi
            requests:
              cpu: 500m
              memory: {{ $requestMemory }}Mi
          {{- end }}
          ports:
            - containerPort: {{ .port }}
              name: client
          args:
            - -m {{ .allocatedMemory }}
            - --extended=modern{{ with .extraExtendedOptions }},{{ . }}{{ end }}
            - -I {{ .maxItemMemory }}m
            - -c {{ .connectionLimit }}
            - -v
            - -u {{ .port }}
            {{- range $key, $value := .extraArgs }}
            - "-{{ $key }}{{ if $value }} {{ $value }}{{ end }}"
            {{- end }}
          {{- with $.ctx.Values.global.extraEnv }}
          env:
              {{ toYaml . | nindent 12 }}
          {{- end }}
          {{- with $.ctx.Values.global.extraEnvFrom }}
          envFrom:
              {{- toYaml . | nindent 12 }}
          {{- end }}
          securityContext:
            {{- toYaml $.ctx.Values.memcached.containerSecurityContext | nindent 12 }}
          volumeMounts:
            {{- with .extraVolumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
            {{- with $.ctx.Values.global.extraVolumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}

      {{- if $.ctx.Values.memcachedExporter.enabled }}
        - name: exporter
          {{- with $.ctx.Values.memcachedExporter.image }}
          image: {{ .repository}}:{{ .tag }}
          imagePullPolicy: {{ .pullPolicy }}
          {{- end }}
          ports:
            - containerPort: 9150
              name: http-metrics
          args:
            - "--memcached.address=localhost:{{ .port }}"
            - "--web.listen-address=0.0.0.0:9150"
            {{- range $key, $value := $.ctx.Values.memcachedExporter.extraArgs }}
            - "--{{ $key }}{{ if $value }}={{ $value }}{{ end }}"
            {{- end }}
          resources:
            {{- toYaml $.ctx.Values.memcachedExporter.resources | nindent 12 }}
          securityContext:
            {{- toYaml $.ctx.Values.memcachedExporter.containerSecurityContext | nindent 12 }}
          {{- if or .extraVolumeMounts $.ctx.Values.global.extraVolumeMounts }}
          volumeMounts:
            {{- with .extraVolumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
            {{- with $.ctx.Values.global.extraVolumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
      {{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
