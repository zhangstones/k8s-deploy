#!/bin/bash

set -e

# params
ETCD0_ENDPOINT=10.0.2.205:2379
ETCD1_ENDPOINT=10.0.2.205:2479
ETCD2_ENDPOINT=10.0.2.205:2579

# generate kubeadm config for initing
cat <<EOF > kubeadm-config.yaml
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket:  unix:///var/run/cri-dockerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "k8s-server.local:6443" # change this (see below)
etcd:
  external:
    endpoints:
      - https://${ETCD0_ENDPOINT}
      - https://${ETCD1_ENDPOINT}
      - https://${ETCD2_ENDPOINT}
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
kubeadm init --config kubeadm-config.yaml --upload-certs --ignore-preflight-errors=NumCPU --log-file=kubeadm-result.log

# increase etcd timeouts
sed -i '/- --etcd-servers/a\    - --etcd-healthcheck-timeout=20s' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/- --etcd-servers/a\    - --etcd-readycheck-timeout=20s' /etc/kubernetes/manifests/kube-apiserver.yaml

rm -f kubeadm-config.yaml
