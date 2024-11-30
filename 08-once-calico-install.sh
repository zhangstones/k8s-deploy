#!/bin/bash

set -e

# params
TIGER_VER=v3.29.1

export https_proxy=myproxy-server:7890
export no_proxy=localhost,127.0.0.1,registry.local,k8s-server.local

helm repo add projectcalico https://docs.tigera.io/calico/charts
helm repo update

# setup docker registry and images for tiger-operator and calicoctl
helm show values projectcalico/tigera-operator > calico-values.yaml

sed -i 's/registry: quay.io/registry: registry.local/g' calico-values.yaml
sed -i 's/image: docker.io/image: registry.local/g' calico-values.yaml

# install tiger-operator and calico system
kubectl create namespace tigera-operator
helm install calico projectcalico/tigera-operator --version "$TIGER_VER" -f calico-values.yaml --namespace tigera-operator

kubectl patch installations.operator.tigera.io default -p '{"spec": {"registry": "registry.local"}}' --type merge

rm -f calico-values.yaml

