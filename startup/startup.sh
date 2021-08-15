#!/bin/bash

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
  mv inlets-pro.service /etc/systemd/system/inlets-pro.service && \
  echo "AUTHTOKEN=$AUTHTOKEN" >> /etc/default/inlets-pro && \
  echo "IP=$IP" >> /etc/default/inlets-pro && \
  systemctl daemon-reload && \
  systemctl start inlets-pro && \
  systemctl enable inlets-pro