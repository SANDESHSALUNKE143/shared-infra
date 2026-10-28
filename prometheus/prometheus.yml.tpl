global:
  scrape_interval: 15s
  external_labels:
    env: __ENV_NAME__

rule_files:
  - /etc/prometheus/alerts.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: alertmanager
    static_configs:
      - targets: ["alertmanager:9093"]
  - job_name: node
    static_configs:
      - targets: ["node-exporter:9100"]
  - job_name: elasticsearch
    static_configs:
      - targets: ["elasticsearch-exporter:9114"]
  - job_name: log-worker
    static_configs:
      - targets: ["log-worker:8080"]
  - job_name: applications
    file_sd_configs:
      - files: ["/etc/prometheus/targets.yml"]
