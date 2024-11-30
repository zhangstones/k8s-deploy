#!/bin/bash

set -e

# CAUTION: need to setup https_proxy for docker and support insecure-registries

kubeadm config images list > images-list.txt

# pull and push k8s images to local docker registry for future use
kubeadm config images pull --cri-socket unix:///var/run/cri-dockerd.sock

while read tag; do
	new_tag=${tag/\/coredns/}
	new_tag=${new_tag/registry.k8s.io/registry.local}
	docker tag $tag $new_tag
	docker push $new_tag
done < images-list.txt

rm -f images-list.txt
