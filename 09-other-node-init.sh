#!/bin/bash

set -e

ROLE=${1-worker}
ROLE=${ROLE,,}

# CAUTION: when kubeadm init compeletes, it will print join cmd with token and certificate-key
# if token expired in 24 hours, or logs are lost, using following cmd to recreate join token:
#         kubeadm token create --print-join-command
# to create a new certificate key you must use 'kubeadm init phase upload-certs --upload-certs'


TOKEN=$(cat kubeadm-result.log | awk '/kubeadm join.*--token/{print $5; exit}')
HASH=$(cat kubeadm-result.log | awk '/--discovery-token-ca-cert-hash/{print $2; exit}')
KEY=$(cat kubeadm-result.log | awk '/--certificate-key/{print $3; exit}')


if [ "$ROLE" == "master" ]; then
	kubeadm join k8s-server.local:6443 --cri-socket unix:///var/run/cri-dockerd.sock --token "$TOKEN" \
		--discovery-token-ca-cert-hash "$HASH" --control-plane --certificate-key "$KEY"
elif [ "$ROLE" == "worker" ]; then
	kubeadm join k8s-server.local:6443 --cri-socket unix:///var/run/cri-dockerd.sock --token "$TOKEN" \
		--discovery-token-ca-cert-hash "$HASH"
else
	echo "invalid k8s node role: $ROLE"
	exit 1
fi
