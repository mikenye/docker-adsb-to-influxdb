#!/usr/bin/env sh
#shellcheck shell=sh

REPO=mikenye
IMAGE=adsb-to-influxdb
PLATFORMS="linux/amd64,linux/arm/v7,linux/arm64"

docker context use x86_64
export DOCKER_CLI_EXPERIMENTAL="enabled"
docker buildx use homecluster

# Get previous versions
docker pull "${REPO}/${IMAGE}:latest"
docker run --entrypoint cat "${REPO}/${IMAGE}:latest" > "/tmp/${IMAGE}.oldlatest.VERSIONS"

# Build & push latest
docker buildx build -t "${REPO}/${IMAGE}:latest" --compress --push --platform "${PLATFORMS}" .

# Get new versions
docker pull "${REPO}/${IMAGE}:latest"
docker run --entrypoint cat "${REPO}/${IMAGE}:latest" > "/tmp/${IMAGE}.newlatest.VERSIONS"

# Check for version differences
diff "/tmp/${IMAGE}.oldlatest.VERSIONS" "/tmp/${IMAGE}.newlatest.VERSIONS" > /dev/null

# If there are version differences, build & push with a tag matching the build date
if [ $? -ne 0 ]; then
    docker buildx build -t "${REPO}/${IMAGE}:$(date -I)" --compress --push --platform "${PLATFORMS}" .
fi

# Clean up
rm "/tmp/${IMAGE}.oldlatest.VERSIONS" "/tmp/${IMAGE}.newlatest.VERSIONS"
