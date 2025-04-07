#!/bin/bash

set -e

. 00-kubeadm-env.sh

# params
export HOST0=${1:-${ETCD_NODE01}}
export HOST1=${2:-${ETCD_NODE02}}
export HOST2=${3:-${ETCD_NODE03}}

if [ "$HOST0" == "" -a $# -lt 1 ]; then
	echo "Usage: $0 [etcd-host01] [etcd-host02] [etcd-host03]"
	exit 1
fi

export NAME0="etcd-node0"
export NAME1="etcd-node1"
export NAME2="etcd-node2"

HOSTS=(${HOST0} ${HOST1} ${HOST2})
NAMES=(${NAME0} ${NAME1} ${NAME2})

if  [ "$HOST0" == "$HOST1" ]; then
        PORTS1=(2379 2479 2579)
        PORTS2=(2380 2480 2580)
        PORTS3=(2381 2481 2581)
else 
        PORTS1=(2379 2379 2379)
        PORTS2=(2380 2380 2380)
        PORTS3=(2381 2381 2381)
fi

INITIAL_CLUSTER=""
for i in "${!HOSTS[@]}"; do
        HOST=${HOSTS[$i]}
        NAME=${NAMES[$i]}
	PORT2=${PORTS2[$i]}
	INITIAL_CLUSTER="${INITIAL_CLUSTER},${NAME}=https://${HOST}:${PORT2}"
done
INITIAL_CLUSTER=${INITIAL_CLUSTER#,}

# generate etcd static pod manifests
for i in "${!HOSTS[@]}"; do
	HOST=${HOSTS[$i]}
	NAME=${NAMES[$i]}
	PORT1=${PORTS1[$i]}
	PORT2=${PORTS2[$i]}
	mkdir -p ./etcd/${NAME}/

cat << EOF > ./etcd/${NAME}/kubeadmcfg.yaml
---
apiVersion: "kubeadm.k8s.io/v1beta3"
kind: InitConfiguration
nodeRegistration:
    name: ${NAME}
    criSocket: ${CTR_RUNTIME}
localAPIEndpoint:
    advertiseAddress: ${HOST}
---
apiVersion: "kubeadm.k8s.io/v1beta3"
kind: ClusterConfiguration
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
          initial-cluster: ${INITIAL_CLUSTER}
          initial-cluster-state: new
          name: ${NAME}
          listen-peer-urls: https://${HOST}:${PORT2}
          listen-client-urls: https://${HOST}:${PORT1}
          advertise-client-urls: https://${HOST}:${PORT1}
          initial-advertise-peer-urls: https://${HOST}:${PORT2}
imageRepository: registry.local
EOF
done

# init certs for etcd nodes
kubeadm init phase certs etcd-ca

for i in "${!HOSTS[@]}"; do
	NAME=${NAMES[$i]}
	kubeadm init phase certs etcd-server --config=./etcd/${NAME}/kubeadmcfg.yaml
	kubeadm init phase certs etcd-peer --config=./etcd/${NAME}/kubeadmcfg.yaml
	kubeadm init phase certs etcd-healthcheck-client --config=./etcd/${NAME}/kubeadmcfg.yaml
	kubeadm init phase certs apiserver-etcd-client --config=./etcd/${NAME}/kubeadmcfg.yaml

	# deploy etcd on one node
	[ "$HOST0" == "$HOST1" -o "$HOST1" == "" ] && break

	# backup certs for etcd node
	cp -fr /etc/kubernetes/pki ./etcd/${NAME}/

	# clean non-reusable certs
	find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete
done


# init etcd static pod manifests and change ports
for i in "${!HOSTS[@]}"; do
	PORT3=${PORTS3[$i]}
	
	kubeadm init phase etcd local --config=./etcd/etcd-node${i}/kubeadmcfg.yaml
	
	sed -i -r "s#port: 2381\b#port: ${PORT3}#g" /etc/kubernetes/manifests/etcd.yaml
	sed -i -r "s#:2381\b#:${PORT3}#g" /etc/kubernetes/manifests/etcd.yaml

	# deploy etcd on one node
	if  [ "$HOST1" == "" ]; then
		break
	elif  [ "$HOST0" == "$HOST1" ]; then
		sed -i "s#^  name: etcd#  name: etcd${i}#g" /etc/kubernetes/manifests/etcd.yaml
		sed -i "s#path: /var/lib/etcd#path: /var/lib/etcd${i}#g" /etc/kubernetes/manifests/etcd.yaml
		
		mv -f /etc/kubernetes/manifests/etcd.yaml /etc/kubernetes/manifests/etcd${i}.yaml
	else
		mv -f /etc/kubernetes/manifests/etcd.yaml ./etcd/${NAME}/
	fi
done


# CAUTION: when deploy on 3 nodes, you have to install etcd certs and manifests on each node

# setup kubelet to work in standalone mode for bringing up local etcd for each node
cat > /var/lib/kubelet/standalone.yaml <<EOF
# https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: true
  webhook:
    enabled: false
authorization:
  mode: AlwaysAllow
address: 127.0.0.1
cgroupDriver: systemd
#containerRuntimeEndpoint: ${CTR_RUNTIME}
staticPodPath: /etc/kubernetes/manifests
EOF

CTR_RUNTIME_FLAG=""
if [ "${CTR_TYPE}" == "docker" ]; then
	CTR_RUNTIME_FLAG="--container-runtime=${CTR_TYPE}"
fi
KUBELET_EXTRA_FLAGS="${CTR_RUNTIME_FLAG} --container-runtime-endpoint=${CTR_RUNTIME} --pod-infra-container-image=registry.local/pause:3.9"

mkdir -p /etc/systemd/system/kubelet.service.d
cat > /etc/systemd/system/kubelet.service.d/20-standalone.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --config=/var/lib/kubelet/standalone.yaml --register-node=false $KUBELET_EXTRA_FLAGS
Restart=always
EOF

systemctl daemon-reload && systemctl restart kubelet

# wait for etcd to be ready
while :; do
	ETCD_ID=$(crictl -r "$CTR_RUNTIME" ps --name etcd -q | head -1)
	status=$(crictl -r "$CTR_RUNTIME" exec "$ETCD_ID" etcdctl --cert /etc/kubernetes/pki/etcd/peer.crt --key /etc/kubernetes/pki/etcd/peer.key \
		--cacert /etc/kubernetes/pki/etcd/ca.crt --endpoints https://${HOST0}:2379 endpoint health || true)
	if echo "$status" | grep -q "is healthy"; then
		echo "etcd is ready!"
		break
	else
		echo "etcd not ready..."
		sleep 2
	fi	
done

rm -fr ./etcd

echo "[Step $(basename $0 | grep -Eo '^[0-9]+')] etcd installed or configured successfully!"

