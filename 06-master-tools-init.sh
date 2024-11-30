#!/bin/bash

set -e

# setup kubectl config
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
kubectl completion bash > /etc/bash_completion.d/kubectl

# install helm and jq tools for later use
export https_proxy=myproxy-server:7890

curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# install yq for yaml processing
curl -sSL -o /usr/sbin/yq https://github.com/mikefarah/yq/releases/download/v4.44.5/yq_linux_amd64
chmod a+x /usr/sbin/yq

