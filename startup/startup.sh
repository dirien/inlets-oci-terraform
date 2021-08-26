#!/bin/bash

mkdir /grafana
tee /grafana/agent.yaml <<EOF
server:
  log_level: info
  http_listen_port: 12345
prometheus:
  wal_directory: /tmp/wal
  global:
    scrape_interval: 60s
  configs:
    - name: agent
      scrape_configs:
        - job_name: 'http-tunnel'
          static_configs:
            - targets: [ 'localhost:8123' ]
          scheme: https
          authorization:
            type: Bearer
            credentials: ${authToken}
          tls_config:
            insecure_skip_verify: true
      remote_write:
        - url: ${promUrl}
          basic_auth:
            username: ${promId}
            password: ${promPW}

integrations:
  agent:
    enabled: true

  prometheus_remote_write:
    - url: ${promUrl}
      basic_auth:
        username: ${promId}
        password: ${promPW}
EOF

tee /etc/systemd/system/grafana-agent.service <<EOF
[Unit]
Description=inlets PRO TCP server
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=2
ExecStart=/usr/local/bin/agent-linux-amd64 -config.file /grafana/agent.yaml

[Install]
WantedBy=multi-user.target
EOF


iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -I INPUT -j ACCEPT

export AUTHTOKEN="${authToken}"
export IP=$(curl -sfSL https://checkip.amazonaws.com)

curl -SLsf https://github.com/inlets/inlets-pro/releases/download/${version}/inlets-pro -o /tmp/inlets-pro && \
  chmod +x /tmp/inlets-pro  && \
  mv /tmp/inlets-pro /usr/local/bin/inlets-pro

curl -SLsf https://github.com/inlets/inlets-pro/releases/download/${version}/inlets-pro.service -o inlets-pro.service && \
  sed -i 's/tcp/${tunnelMode}/g' inlets-pro.service
  mv inlets-pro.service /etc/systemd/system/inlets-pro.service && \
  echo "AUTHTOKEN=$AUTHTOKEN" >> /etc/default/inlets-pro && \
  echo "IP=$IP" >> /etc/default/inlets-pro && \
  systemctl daemon-reload && \
  systemctl start inlets-pro && \
  systemctl enable inlets-pro

apt install -y unzip
curl -SLsf https://github.com/grafana/agent/releases/download/v0.18.2/agent-linux-amd64.zip -o /tmp/agent-linux-amd64.zip && \
  unzip /tmp/agent-linux-amd64.zip -d /tmp && \
  chmod a+x /tmp/agent-linux-amd64 && \
  mv /tmp/agent-linux-amd64 /usr/local/bin/agent-linux-amd64

systemctl restart grafana-agent.service
systemctl enable grafana-agent.service