#!/bin/bash

sudo ARCH=amd64 GCLOUD_STACK_ID="261673" GCLOUD_API_KEY="${GCLOUD_API_KEY}" GCLOUD_API_URL="https://integrations-api-us-central.grafana.net" /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/grafana/agent/release/production/grafanacloud-install.sh)"
sudo systemctl stop grafana-agent.service

cat << EOF > grafana-agent.yaml
integrations:
  consul_exporter:
    enabled: true
    server: ${HOST_IP}:8500
  node_exporter:
    enabled: true
  prometheus_remote_write:
  - basic_auth:
      password: ${GRAFANA_PASS}
      username: ${PROM_USER}
    url: https://prometheus-prod-10-prod-us-central-0.grafana.net/api/prom/push
loki:
  configs:
  - clients:
    - basic_auth:
        password: ${GRAFANA_PASS}
        username: ${LOKI_USER}
      url: https://logs-prod-us-central1.grafana.net/api/prom/push
    name: integrations
    positions:
      filename: /tmp/positions.yaml
    target_config:
      sync_period: 10s
prometheus:
  configs:
  - name: integrations
    remote_write:
    - basic_auth:
        password: ${GRAFANA_PASS}
        username: ${PROM_USER}
      url: https://prometheus-prod-10-prod-us-central-0.grafana.net/api/prom/push
    scrape_configs:
      - job_name: consul
        honor_timestamps: true
        scrape_interval: 15s
        scrape_timeout: 10s
        metrics_path: /v1/agent/metrics
        scheme: http
        params:
          format: ["prometheus"]
        static_configs:
        - targets:
          - ${HOST_IP}:8500
      - job_name: integrations/nomad
        honor_timestamps: true
        scrape_interval: 15s
        scrape_timeout: 10s
        metrics_path: /v1/metrics
        scheme: http
        params:
          format: ["prometheus"]
        static_configs:
        - targets:
          - ${HOST_IP}:4646
      - job_name: integrations/docker
        static_configs:
        - targets: 
          - ${HOST_IP}:8080          
  global:
    scrape_interval: 15s
  wal_directory: /tmp/grafana-agent-wal

server:
  http_listen_port: 12345
EOF

sudo mv grafana-agent.yaml /etc/grafana-agent.yaml
sudo chown root:grafana-agent /etc/grafana-agent.yaml
sudo systemctl restart grafana-agent.service

cat << EOF > promtail-local-config.yaml
server:
  http_listen_port: 0
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

client:
  url: https://${LOKI_USER}:${LOKI_API_KEY}@logs-prod-us-central1.grafana.net/api/prom/push

scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      job: varlogs
      __path__: /var/log/*log

EOF

sudo chown root:root promtail-local-config.yaml
sudo mv promtail-local-config.yaml /etc/.

curl -O -L "https://github.com/grafana/loki/releases/download/v2.3.0/promtail-linux-amd64.zip"
unzip promtail-linux-amd64.zip

sudo chown root:root promtail-linux-amd64
sudo mv promtail-linux-amd64 /usr/bin/.

cat << EOF > promtail.service
[Unit]
Description="Promptail"
Documentation="https://grafana.com/docs/grafana-cloud/quickstart/logs_promtail_linuxnode/#install-and-configure-promtail"
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/promtail-local-config.yaml

[Service]
Type=notify
User=root
Group=root
ExecStart=/usr/bin/promtail-linux-amd64 -config.file=/etc/promtail-local-config.yaml
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo chown root:root promtail.service
sudo mv promtail.service /usr/lib/systemd/system/.

sudo systemctl enable promtail
sudo systemctl start promtail </dev/null &>/dev/null &
