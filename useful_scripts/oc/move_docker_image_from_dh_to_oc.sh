#!/bin/bash

BASE_DOCKER_IMAGE="eclipse-temurin:21-jre-alpine"
OC_PATH="./oc"
OC_REGISTRY="default-route-openshift-image-registry.com"
OC_DOCKER_IMAGE="$OC_REGISTRY/project-cd/$BASE_DOCKER_IMAGE"

docker pull $BASE_DOCKER_IMAGE

docker tag $BASE_DOCKER_IMAGE $OC_DOCKER_IMAGE

docker login -u openshift -p $($OC_PATH whoami -t) $OC_REGISTRY 

