#!/bin/bash

# Parameters
SOURCE_REGION=[source-region]
SOURCE_PROFILE=[source-profile]
SOURCE_REPO_NAME=[source-repo-name]
DEST_REGION=[dest-region]
DEST_PROFILE=[dest-profile]
DEST_REPO_NAME=[dest-repo-name]

# Login to Source ECR
aws ecr get-login-password --region $SOURCE_REGION --profile $SOURCE_PROFILE | docker login --username AWS --password-stdin $(aws sts get-caller-identity --profile $SOURCE_PROFILE --query "Account" --output text).dkr.ecr.$SOURCE_REGION.amazonaws.com

# List Images in Source ECR Repository
IMAGES=$(aws ecr list-images --repository-name $SOURCE_REPO_NAME --region $SOURCE_REGION --profile $SOURCE_PROFILE --query 'imageIds[*].imageTag' --output text)

# Login to Destination ECR
aws ecr get-login-password --region $DEST_REGION --profile $DEST_PROFILE | docker login --username AWS --password-stdin $(aws sts get-caller-identity --profile $DEST_PROFILE --query "Account" --output text).dkr.ecr.$DEST_REGION.amazonaws.com

for TAG in $IMAGES; do
    echo "Migrating image with tag: $TAG"

    SOURCE_IMAGE_URI=$(aws sts get-caller-identity --profile $SOURCE_PROFILE --query "Account" --output text).dkr.ecr.$SOURCE_REGION.amazonaws.com/$SOURCE_REPO_NAME:$TAG
    DEST_IMAGE_URI=$(aws sts get-caller-identity --profile $DEST_PROFILE --query "Account" --output text).dkr.ecr.$DEST_REGION.amazonaws.com/$DEST_REPO_NAME:$TAG

    # Pull image from source ECR
    docker pull $SOURCE_IMAGE_URI

    # Tag image for destination ECR
    docker tag $SOURCE_IMAGE_URI $DEST_IMAGE_URI

    # Push image to destination ECR
    docker push $DEST_IMAGE_URI

    # Remove local images (both source and destination tags)
    docker image rm $SOURCE_IMAGE_URI
    docker image rm $DEST_IMAGE_URI
done
