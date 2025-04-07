#!/bin/bash

set -e

. 00-kubeadm-env.sh

# params
export ETCD_HOST0=${1:-${ETCD_NODE01}}
export ETCD_HOST1=${2:-${ETCD_NODE02}}
export ETCD_HOST2=${3:-${ETCD_NODE03}}

if [ "$ETCD_HOST0" == "" -a $# -lt 1 ]; then
        echo "Usage: $0 [etcd-host01] [etcd-host02] [etcd-host03]"
        exit 1
fi

ETCD_HOSTS=(${ETCD_HOST0} ${ETCD_HOST1} ${ETCD_HOST2})
if  [ "$HOST0" == "$HOST1" ]; then
        ETCD_PORTS=(2379 2479 2579)
else
        ETCD_PORTS=(2379 2379 2379)
fi

ETCD_ENDPOINTS=""
for i in "${!ETCD_HOSTS[@]}"; do
        HOST=${ETCD_HOSTS[$i]}
        PORT=${ETCD_PORTS[$i]}
        ETCD_ENDPOINTS="${ETCD_ENDPOINTS},https://${HOST}:${PORT}"
done
ETCD_ENDPOINTS=${ETCD_ENDPOINTS#,}

CTR_RUNTIME_FLAG=""
if [ "${CTR_TYPE}" == "docker" ]; then
        CTR_RUNTIME_FLAG="container-runtime: ${CTR_TYPE}"
fi

# generate kubeadm config for initing
cat <<EOF > kubeadm-config.yaml
---
# https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-InitConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: ${CTR_RUNTIME}
  kubeletExtraArgs:
    cgroup-driver: systemd
    ${CTR_RUNTIME_FLAG}
    pod-infra-container-image: registry.local/pause:3.9
---
# https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "k8s-server.local:6443" # change this (see below)
etcd:
  external:
    endpoints: [${ETCD_ENDPOINTS}]
    caFile: /etc/kubernetes/pki/etcd/ca.crt
    certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
    keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
imageRepository: registry.local
networking:
  podSubnet: "10.100.0.0/16"  # 必须设置 Pod 的子网范围
EOF

# now etcd is running, recover kubelet config, disable standalone mode
rm -f /var/lib/kubelet/standalone.yaml
rm -f /etc/systemd/system/kubelet.service.d/20-standalone.conf
systemctl daemon-reload && systemctl restart kubelet

# init first control-plate node. pay attention to init logs, there is guidelines for later node joins
kubeadm init --config kubeadm-config.yaml --upload-certs --ignore-preflight-errors=NumCPU,FileAvailable--etc-kubernetes-manifests-etcd.yaml,Port-10250,CRI,ImagePull --log-file=kubeadm-result.log

# increase etcd timeouts
sed -i '/- --etcd-servers/a\    - --etcd-healthcheck-timeout=20s' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/- --etcd-servers/a\    - --etcd-readycheck-timeout=20s' /etc/kubernetes/manifests/kube-apiserver.yaml

rm -f kubeadm-config.yaml

echo "[Step $(basename $0 | grep -Eo '^[0-9]+')] control plane initialized successfully!"

