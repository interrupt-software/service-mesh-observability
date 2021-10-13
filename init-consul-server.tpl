#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
export CONSUL_VERSION="1.10.3"
export CONSUL_URL="https://releases.hashicorp.com/consul"

curl --silent --remote-name \
  ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

curl --silent --remote-name \
  ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS

curl --silent --remote-name \
  ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig

unzip consul_${CONSUL_VERSION}_linux_amd64.zip

sudo chown root:root consul

sudo mv consul /usr/bin/

consul -autocomplete-install

complete -C /usr/bin/consul consul

sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul

## Agents

sudo mkdir --parents /etc/consul.d

cat << EOF > consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"
retry_join = ["SERVER0", "SERVER1", "SERVER2"]
acl = {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}

performance {
  raft_multiplier = 3
}

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
}

audit {
  enabled = true
  sink "My sink" {
    type   = "file"
    format = "json"
    path   = "/opt/consul/data/audit/audit.json"
    delivery_guarantee = "best-effort"
    rotate_duration = "24h"
    rotate_max_files = 15
    rotate_bytes = 25165824
  }
}
EOF

sudo mv consul.hcl /etc/consul.d/consul.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul.hcl

## Server

cat << EOF > server.hcl
server = true
bootstrap_expect = 3
client_addr = "0.0.0.0"
ui = true
EOF

sudo mv server.hcl /etc/consul.d/server.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/server.hcl

cat << EOF > consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo mv consul.service /usr/lib/systemd/system/consul.service
sudo chown root:root  /usr/lib/systemd/system/consul.service

sudo systemctl enable consul
sudo systemctl start consul
sudo systemctl status consul

