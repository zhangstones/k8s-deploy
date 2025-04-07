#!/bin/bash

set -e

. 00-kubeadm-env.sh

helm repo add projectcalico https://docs.tigera.io/calico/charts
helm repo update

# setup docker registry and images for tiger-operator and calicoctl
helm show values projectcalico/tigera-operator --version "$CALICO_VER" > calico-values.yaml

sed -i 's/registry: quay.io/registry: registry.local/g' calico-values.yaml
sed -i 's/image: docker.io/image: registry.local/g' calico-values.yaml

# install tiger-operator and calico system
kubectl create namespace tigera-operator
helm install calico projectcalico/tigera-operator --version "$CALICO_VER" -f calico-values.yaml --namespace tigera-operator

kubectl patch installations.operator.tigera.io default -p '{"spec": {"registry": "registry.local"}}' --type merge

rm -f calico-values.yaml

echo "[Step $(basename $0 | grep -Eo '^[0-9]+')] calico system installed successfully!"

