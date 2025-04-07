#!/bin/bash

set -e 

. 00-kubeadm-env.sh

# setup docker-ce repo and install docker runtime
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce-${DOCKER_VER} docker-ce-cli-${DOCKER_VER} containerd.io-${CONTAINERD_VER}

# CAUTION: change containerd settings
sed -i 's:#root = "/var/lib/containerd":root = "/data/containerd":' /etc/containerd/config.toml
sed -i 's:^disabled_plugins = ["cri"]:# disabled_plugins = ["cri"]:' /etc/containerd/config.toml
systemctl enable containerd
systemctl restart containerd

# CAUTION: change docker config
cat <<EOF >/etc/docker/daemon.json
{
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],
  "insecure-registries": [
    "registry.local"
  ],
  "data-root": "/data/docker"
}
EOF

systemctl enable docker
systemctl restart docker

# set default config for crictl
echo "runtime-endpoint: ${CTR_RUNTIME}" > /etc/crictl.yaml

if [ "$CTR_RUNTIME" != "unix:///var/run/cri-dockerd.sock" ]; then
	exit 0
fi

# download and extract binary and necessary files
curl -OsSL https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.15/cri-dockerd-0.3.15.amd64.tgz
curl -sSL -o cri-dockerd-v0.3.15.zip https://github.com/Mirantis/cri-dockerd/archive/refs/tags/v0.3.15.zip
tar zxf cri-dockerd-0.3.15.amd64.tgz
unzip -qo cri-dockerd-v0.3.15.zip

# install cri-docker service and start it
install -v -o root -g root -m 0755 cri-dockerd/cri-dockerd /usr/bin/cri-dockerd
install -v cri-dockerd-0.3.15/packaging/systemd/cri-docker.service /etc/systemd/system
install -v cri-dockerd-0.3.15/packaging/systemd/cri-docker.socket /etc/systemd/system

if ! grep -q "pod-infra-container-image" /etc/systemd/system/cri-docker.service; then
	sed -i -r 's#ExecStart=(.*)#ExecStart=\1 --pod-infra-container-image=registry.local/pause:3.9#' /etc/systemd/system/cri-docker.service
fi

systemctl daemon-reload
systemctl enable cri-docker.socket
systemctl start cri-docker.socket

rm -f cri-dockerd-0.3.15.amd64.tgz
rm -f cri-dockerd-v0.3.15.zip
rm -fr cri-dockerd
rm -fr cri-dockerd-0.3.15

echo "[Step $(basename $0 | grep -Eo '^[0-9]+')] docker runtime installed successfully!"

