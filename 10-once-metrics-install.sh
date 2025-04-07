#!/bin/bash

set -e

. 00-kubeadm-env.sh

# params
METRICS_VER=v0.7.2

# pull and push metrics-server images to local docker registry
docker pull registry.k8s.io/metrics-server/metrics-server:${METRICS_VER}
docker tag {registry.k8s.io,registry.local}/metrics-server/metrics-server:${METRICS_VER}
docker push registry.local/metrics-server/metrics-server:${METRICS_VER}

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm show values metrics-server/metrics-server --version 3.12.2 > metrics-values.yaml
sed -i '/metric-resolution=/a\  - --kubelet-insecure-tls' metrics-values.yaml

helm upgrade --install metrics-server metrics-server/metrics-server --version 3.12.2 -n kube-system \
	--set image.repository=registry.local/metrics-server/metrics-server \
	--set image.tag=${METRICS_VER} \
	--set tolerations[0].key="node-role.kubernetes.io/control-plane" \
	--set tolerations[0].effect="NoSchedule" \
	-f metrics-values.yaml

rm -f metrics-values.yaml

echo "[Step $(basename $0 | grep -Eo '^[0-9]+')] metrics server installed successfully!"

