#!/bin/bash

set -e

export https_proxy=myproxy-server:7890
export no_proxy=localhost,127.0.0.1,registry.local,k8s-server.local

helm repo add projectcalico https://docs.tigera.io/calico/charts
helm repo update

# setup docker registry and images for tiger-operator and calicoctl
helm show values projectcalico/tigera-operator > calico-values.yaml

OPERATOR_REPO=$(cat calico-values.yaml | yq '.tigeraOperator.registry')
OPERATOR_IMAGE=$(cat calico-values.yaml | yq '.tigeraOperator.image')
OPERATOR_TAG=$(cat calico-values.yaml | yq '.tigeraOperator.version')

OLD_TAG="${OPERATOR_REPO}/${OPERATOR_IMAGE}:${OPERATOR_TAG}"
NEW_TAG="registry.local/${OPERATOR_IMAGE}:${OPERATOR_TAG}"

docker pull "$OLD_TAG"
docker tag "$OLD_TAG" "$NEW_TAG"
docker push "$NEW_TAG"
docker rmi "$OLD_TAG"


CALICO_IMAGE=$(cat calico-values.yaml | yq '.calicoctl.image')
CALICO_TAG=$(cat calico-values.yaml | yq '.calicoctl.tag')

OLD_TAG="${CALICO_IMAGE}:${CALICO_TAG}"
NEW_TAG="${CALICO_IMAGE/docker.io/registry.local}:${CALICO_TAG}"

docker pull "$OLD_TAG"
docker tag "$OLD_TAG" "$NEW_TAG"
docker push "$NEW_TAG"
docker rmi "$OLD_TAG"

sed -i 's/registry: quay.io/registry: registry.local/g' calico-values.yaml
sed -i 's/image: docker.io/image: registry.local/g' calico-values.yaml

# install tiger-operator and calico system
kubectl create namespace tigera-operator
helm install calico projectcalico/tigera-operator --version v3.29.1 -f calico-values.yaml --namespace tigera-operator

kubectl patch installations.operator.tigera.io default -p '{"spec": {"registry": "registry.local"}}' --type merge

rm -f calico-values.yaml

