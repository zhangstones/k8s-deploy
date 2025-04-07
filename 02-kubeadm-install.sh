#!/bin/bash

set -e

. 00-kubeadm-env.sh

# disable selinux
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# disable firewall
systemctl disable --now firewalld

# disable swap
swapoff -a
sed -i '/ swap /d' /etc/fstab

# CAUTION: need to set http proxy for yum
K8S_REPO_VER="v${K8S_VER%.*}"
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/${K8S_REPO_VER}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${K8S_REPO_VER}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

yum makecache

yum install -y kubelet-${K8S_VER} kubeadm-${K8S_VER} kubectl-${K8S_VER} cri-tools-${CRICTL_VER} --disableexcludes=kubernetes
systemctl enable kubelet
systemctl restart kubelet

echo "[Step $(basename $0 | grep -Eo '^[0-9]+')] kubeadm tools and components installed successfully!"

