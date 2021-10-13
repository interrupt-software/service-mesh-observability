export NOMAD_VERSION="1.1.4"
curl --silent --remote-name https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip
unzip nomad_${NOMAD_VERSION}_linux_amd64.zip

sudo chown root:root nomad
sudo mv nomad /usr/local/bin/
nomad version
nomad -autocomplete-install
complete -C /usr/local/bin/nomad nomad

sudo mkdir --parents /opt/nomad
sudo mkdir --parents /opt/nomad/audit

cat << EOF > nomad.service
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

# When using Nomad with Consul it is not necessary to start Consul first. These
# lines start Consul before Nomad as an optimization to avoid Nomad logging
# that Consul is unavailable at startup.
#Wants=consul.service
#After=consul.service

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
Restart=on-failure
RestartSec=2

## Configure unit start rate limiting. Units which are started more than
## *burst* times within an *interval* time span are not permitted to start any
## more. Use `StartLimitIntervalSec` or `StartLimitInterval` (depending on
## systemd version) to configure the checking interval and `StartLimitBurst`
## to configure how many starts per interval are allowed. The values in the
## commented lines are defaults.

# StartLimitBurst = 5

## StartLimitIntervalSec is used for systemd versions >= 230
# StartLimitIntervalSec = 10s

## StartLimitInterval is used for systemd versions < 230
# StartLimitInterval = 10s

TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
EOF

sudo chown root:root nomad.service
sudo mv nomad.service /etc/systemd/system/nomad.service

sudo mkdir --parents /etc/nomad.d
sudo chmod 700 /etc/nomad.d

cat << EOF > nomad.hcl
datacenter = "dc1"
data_dir = "/opt/nomad"

consul {
  address = "127.0.0.1:8500"
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

audit {
  enabled = true

  sink "audit" {
    type               = "file"
    delivery_guarantee = "enforced"
    format             = "json"
    path               = "/opt/nomad/audit/audit.log"
    rotate_bytes       = 100
    rotate_duration    = "24h"
    rotate_max_files   = 10
    mode               = "0600"
  }
}
EOF

sudo chown root:root nomad.hcl
sudo mv nomad.hcl /etc/nomad.d/nomad.hcl

cat << EOF > client.hcl
client {
  enabled = true
  servers = ["SERVER0", "SERVER1", "SERVER2"]
}
EOF

sudo chown root:root client.hcl
sudo mv client.hcl /etc/nomad.d/client.hcl

sudo systemctl enable nomad
sudo systemctl start nomad
sudo systemctl status nomad
