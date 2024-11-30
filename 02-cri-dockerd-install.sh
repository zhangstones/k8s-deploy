#!/bin/bash

export https_proxy=myproxy-server:7890

# download and extract binary and necessary files
curl -OsSL https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.15/cri-dockerd-0.3.15.amd64.tgz
curl -sSL -o cri-dockerd-v0.3.15.zip https://github.com/Mirantis/cri-dockerd/archive/refs/tags/v0.3.15.zip
tar zxf cri-dockerd-0.3.15.amd64.tgz
unzip -q cri-dockerd-v0.3.15.zip

# install cri-docker service and start it
install -v -o root -g root -m 0755 cri-dockerd/cri-dockerd /usr/bin/cri-dockerd
install -v cri-dockerd-0.3.15/packaging/systemd/cri-docker.service /etc/systemd/system
install -v cri-dockerd-0.3.15/packaging/systemd/cri-docker.socket /etc/systemd/system
systemctl daemon-reload
systemctl enable --now cri-docker.socket

rm -f cri-dockerd-0.3.15.amd64.tgz
rm -f cri-dockerd-v0.3.15.zip
rm -fr cri-dockerd
rm -fr cri-dockerd-0.3.15

# set default config for crictl
echo "runtime-endpoint: unix:///var/run/cri-dockerd.sock" > /etc/crictl.yaml

