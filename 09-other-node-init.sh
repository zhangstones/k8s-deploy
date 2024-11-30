#!/bin/bash

set -e

ROLE=${1-worker}
ROLE=${ROLE,,}

# CAUTION: when kubeadm init compeletes, it will print join cmd with token and certificate-key
# if token expired in 24 hours, or logs are lost, using following cmd to recreate join token:
#         kubeadm token create --print-join-command
# to create a new certificate key you must use 'kubeadm init phase upload-certs --upload-certs'

if [ "$ROLE" != "master" ]; then
	kubeadm join k8s-server.local:6443 --cri-socket unix:///var/run/cri-dockerd.sock --token nefx8k.k9cw8d5kasben9dg \
        	--discovery-token-ca-cert-hash sha256:26f69a8eaf25dedfebc905e257bbb2cca63d81fa4638ebcebc4612f57b8bb896 \
        	--control-plane --certificate-key 13e15ab838333753016450278b426a21eb276d96c5059c7a01d8b54407f36706
else

	kubeadm join k8s-server.local:6443 --cri-socket unix:///var/run/cri-dockerd.sock --token nefx8k.k9cw8d5kasben9dg \
		--discovery-token-ca-cert-hash sha256:26f69a8eaf25dedfebc905e257bbb2cca63d81fa4638ebcebc4612f57b8bb896
fi
