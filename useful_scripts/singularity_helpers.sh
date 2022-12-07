#!/usr/bin/env bash

function set_singularity_ecr_credentials() {
    export SINGULARITY_DOCKER_USERNAME=AWS
    export SINGULARITY_DOCKER_PASSWORD="$(aws ecr get-login-password)"
}

