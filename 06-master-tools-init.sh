#!/bin/bash

set -e

. 00-kubeadm-env.sh

# setup kubectl config
mkdir -p $HOME/.kube
cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
kubectl completion bash > /etc/bash_completion.d/kubectl

# install helm and jq tools for later use
curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# install yq for yaml processing
curl -sSL -o /usr/sbin/yq https://github.com/mikefarah/yq/releases/download/v4.44.5/yq_linux_amd64
chmod a+x /usr/sbin/yq

echo "[Step $(basename $0 | grep -Eo '^[0-9]+')] master tools installed successfully!"

