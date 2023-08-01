#!/bin/bash

# Get AWS Credentials & login to ECR
aws-vault exec human-data-engineer@bwell-dev aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 875300655693.dkr.ecr.us-east-1.amazonaws.com/helix.spark

# Build the Docker image
docker build -t helix.spark:latest-ci -f Dockerfile .

# Tag the image for ECR repository
docker tag helix.spark:latest-ci 875300655693.dkr.ecr.us-east-1.amazonaws.com/helix.spark:arm64

# Push the image to ECR
docker push 875300655693.dkr.ecr.us-east-1.amazonaws.com/helix.spark:arm64
docker manifest create 875300655693.dkr.ecr.us-east-1.amazonaws.com/helix.spark:latest-ci 875300655693.dkr.ecr.us-east-1.amazonaws.com/helix.spark:arm64 875300655693.dkr.ecr.us-east-1.amazonaws.com/helix.spark:amd64
docker manifest annotate 875300655693.dkr.ecr.us-east-1.amazonaws.com/helix.spark:latest-ci 875300655693.dkr.ecr.us-east-1.amazonaws.com/helix.spark:amd64 --os linux --arch amd64
docker manifest annotate 875300655693.dkr.ecr.us-east-1.amazonaws.com/helix.spark:latest-ci 875300655693.dkr.ecr.us-east-1.amazonaws.com/helix.spark:arm64 --os linux --arch arm64