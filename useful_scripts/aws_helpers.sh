#!/bin/bash

# For docker
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <ECR>

# For singularity
export SINGULARITY_DOCKER_USERNAME=AWS
export SINGULARITY_DOCKER_PASSWORD=$(aws ecr get-login-password --region eu-west-1)
