#!/bin/bash

set -e

# params
TIGERA_VER=v1.36.2
CALICO_VER=v3.29.1

# pull and push calico images to local docker registry for future use
CALICO_IMAGES=(
	quay.io/tigera/operator:${TIGERA_VER}
	docker.io/calico/ctl:${CALICO_VER}
	docker.io/calico/typha:${CALICO_VER}
	docker.io/calico/kube-controllers:${CALICO_VER}
	docker.io/calico/apiserver:${CALICO_VER}
	docker.io/calico/cni:${CALICO_VER}
	docker.io/calico/node-driver-registrar:${CALICO_VER}
	docker.io/calico/csi:${CALICO_VER}
	docker.io/calico/pod2daemon-flexvol:${CALICO_VER}
	docker.io/calico/node:${CALICO_VER}
)

for image in "${CALICO_IMAGES[@]}"; do 
	new_image=${image/docker.io/registry.local}
	new_image=${new_image/quay.io/registry.local}
	docker tag $image $new_image
	docker push $new_image
done

