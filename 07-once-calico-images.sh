#!/bin/bash

set -e

# pull and push calico images to local docker registry for future use
CALICO_IMAGES=(
	docker.io/calico/typha:v3.29.1
	docker.io/calico/kube-controllers:v3.29.1
	docker.io/calico/apiserver:v3.29.1
	docker.io/calico/cni:v3.29.1
	docker.io/calico/node-driver-registrar:v3.29.1
	docker.io/calico/csi:v3.29.1
	docker.io/calico/pod2daemon-flexvol:v3.29.1
	docker.io/calico/node:v3.29.1
)

for image in "${CALICO_IMAGES[@]}"; do 
	new_image=${image/docker.io/registry.local}
	docker tag $image $new_image
	docker push $new_image
done

