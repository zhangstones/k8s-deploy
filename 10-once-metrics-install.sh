#!/bin/bash

set -e

# params
METRICS_VER=v0.7.2

export https_proxy=myproxy-server:7890
export no_proxy=localhost,127.0.0.1,registry.local,k8s-server.local

# pull and push metrics-server images to local docker registry
docker pull registry.k8s.io/metrics-server/metrics-server:${METRICS_VER}
docker tag {registry.k8s.io,registry.local}/metrics-server/metrics-server:${METRICS_VER}
docker push registry.local/metrics-server/metrics-server:${METRICS_VER}

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

helm show values metrics-server/metrics-server --version 3.12.2 > metrics-values.yaml
sed -i '/metric-resolution=/a\  - --kubelet-insecure-tls' metrics-values.yaml

helm upgrade --install metrics-server metrics-server/metrics-server --version 3.12.2 -n kube-system \
	--set image.repository=registry.local/metrics-server/metrics-server \
	--set image.tag=${METRICS_VER} \
	-f metrics-values.yaml

rm -f metrics-values.yaml
