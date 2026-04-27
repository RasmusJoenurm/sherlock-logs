#!/bin/bash
set -e

DISCORD_URL=$(kubectl get secret logstash-alert-webhook -n elastic -o jsonpath='{.data.url}' | base64 -d)

kubectl create secret generic alertmanager-discord-config -n monitoring \
  --from-literal=alertmanager.yaml="global:
  resolve_timeout: 5m
route:
  receiver: discord-warning
  group_by: ['alertname', 'namespace', 'pod', 'job']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 2h
  routes:
    - receiver: discord-critical
      matchers:
        - severity=\"critical\"
      continue: false
    - receiver: discord-warning
      matchers:
        - severity=\"warning\"
      continue: false
inhibit_rules:
  - source_matchers:
      - severity=\"critical\"
    target_matchers:
      - severity=\"warning\"
    equal:
      - alertname
      - namespace
      - pod
receivers:
  - name: discord-warning
    discord_configs:
      - webhook_url: \"$DISCORD_URL\"
        send_resolved: true
        title: '[WARNING] {{ .CommonLabels.alertname }}'
        message: |
          {{ range .Alerts -}}
          **Summary:** {{ .Annotations.summary }}
          **Description:** {{ .Annotations.description }}
          **Severity:** {{ .Labels.severity }}
          **Namespace:** {{ .Labels.namespace }}
          **Pod:** {{ .Labels.pod }}
          {{ end }}
  - name: discord-critical
    discord_configs:
      - webhook_url: \"$DISCORD_URL\"
        send_resolved: true
        title: '[CRITICAL] {{ .CommonLabels.alertname }}'
        message: |
          {{ range .Alerts -}}
          **Summary:** {{ .Annotations.summary }}
          **Description:** {{ .Annotations.description }}
          **Severity:** {{ .Labels.severity }}
          **Namespace:** {{ .Labels.namespace }}
          **Pod:** {{ .Labels.pod }}
          {{ end }}"

echo "Secret created successfully."
