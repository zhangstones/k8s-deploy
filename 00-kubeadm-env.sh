#!/bin/bash


export K8S_VER=1.27.16
export CRICTL_VER=1.27.1
export DOCKER_VER=26.1.3
export CONTAINERD_VER=1.6.26
export MASTER_NODE01=node01
export MASTER_NODE02=node02
export MASTER_NODE03=node03
export ETCD_NODE01=192.168.3.213
export ETCD_NODE02=
export ETCD_NODE03=
export CTR_TYPE=remote
export CTR_RUNTIME=unix:///var/run/cri-dockerd.sock
#export CTR_TYPE=docker
#export CTR_RUNTIME=unix:///var/run/dockershim.sock

export TIGERA_VER=v1.36.2
export CALICO_VER=v3.29.1

export https_proxy=myproxy-server:7890
export no_proxy=localhost,127.0.0.1,10.0.0.0/8,192.168.0.0/16,museum.local,statics.local,registry.local,k8s-server.local

