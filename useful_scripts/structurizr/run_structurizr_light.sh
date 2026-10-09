#!/bin/bash

source .env.light

WORKSPACE_PATH=${LOCAL_WORKSPACE_PATH}:${CONTAINER_PATH}

docker_cmd="docker run -it --rm --name structurizr -p ${HOST_PORT}:8080 -v ${WORKSPACE_PATH} 834847642577.dkr.ecr.eu-central-1.amazonaws.com/structurizr/lite:2025.03.28"

echo "Running Docker command:"
echo "${docker_cmd}"

$docker_cmd
