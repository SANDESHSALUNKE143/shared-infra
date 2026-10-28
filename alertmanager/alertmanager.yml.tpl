global:
  resolve_timeout: 5m

route:
  receiver: default
  group_by: ["alertname", "env"]

receivers:
  - name: default
__WEBHOOK__
