#!/bin/bash

set -e

. 00-kubeadm-env.sh

ROLE=${1-worker}
ROLE=${ROLE,,}

# CAUTION: when kubeadm init compeletes, it will print join cmd with token and certificate-key
# if token expired in 24 hours, or logs are lost, using following cmd to recreate join token:
#         kubeadm token create --print-join-command
# to create a new certificate key you must use 'kubeadm init phase upload-certs --upload-certs'


TOKEN=$(cat kubeadm-result.log | awk '/kubeadm join.*--token/{print $5; exit}')
HASH=$(cat kubeadm-result.log | awk '/--discovery-token-ca-cert-hash/{print $2; exit}')
KEY=$(cat kubeadm-result.log | awk '/--certificate-key/{print $3; exit}')

CONTROL_PLANE=""
if [ "$ROLE" == "master" ]; then
	CONTROL_PLANE="
controlPlane:
  certificateKey: $KEY
"
elif [ "$ROLE" == "worker" ]; then
	CONTROL_PLANE=""
else
	echo "invalid k8s node role: $ROLE"
	exit 1
fi

CTR_RUNTIME_FLAG=""
if [ "${CTR_TYPE}" == "docker" ]; then
	CTR_RUNTIME_FLAG="container-runtime: ${CTR_TYPE}"
fi

# generate kubeadm config for initing
cat <<EOF > kubeadm-config.yaml
---
# https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-JoinConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
discovery:
  bootstrapToken:
    apiServerEndpoint: k8s-server.local:6443
    token: $TOKEN
    caCertHashes: [$HASH]
kind: JoinConfiguration
${CONTROL_PLANE}
nodeRegistration:
  criSocket: ${CTR_RUNTIME}
  kubeletExtraArgs:
    cgroup-driver: systemd
    ${CTR_RUNTIME_FLAG}
    pod-infra-container-image: registry.local/pause:3.9
EOF

kubeadm join --config kubeadm-config.yaml "--ignore-preflight-errors=NumCPU,CRI,ImagePull"

rm -f kubeadm-config.yaml

echo "[Step $(basename $0 | grep -Eo '^[0-9]+')] $ROLE node joined successfully!"

