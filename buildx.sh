#!/usr/bin/env sh
#shellcheck shell=sh

set -x

REPO=mikenye
IMAGE=adsb-to-influxdb
PLATFORMS="linux/amd64,linux/arm/v7,linux/arm64"

docker context use x86_64
export DOCKER_CLI_EXPERIMENTAL="enabled"
docker buildx use homecluster

# Get previous versions
docker pull "${REPO}/${IMAGE}:latest"
docker run --rm --entrypoint cat "${REPO}/${IMAGE}:latest" /VERSIONS > "/tmp/${IMAGE}.oldlatest.VERSIONS"

# Build & push latest
docker buildx build --no-cache -t "${REPO}/${IMAGE}:latest" --compress --push --platform "${PLATFORMS}" .

# Get new versions
docker pull "${REPO}/${IMAGE}:latest"
docker run --rm --entrypoint cat "${REPO}/${IMAGE}:latest" > /VERSIONS "/tmp/${IMAGE}.newlatest.VERSIONS"

# Check for version differences
diff "/tmp/${IMAGE}.oldlatest.VERSIONS" "/tmp/${IMAGE}.newlatest.VERSIONS" > /dev/null
DIFFEXITCODE=$?

if [ -z "$FORCEPUSH" ]; then
    DIFFEXITCODE=1
fi

# If there are version differences, build & push with a tag matching the build date
if [ $DIFFEXITCODE -ne 0 ]; then
    docker buildx build -t "${REPO}/${IMAGE}:$(date -I)" --compress --push --platform "${PLATFORMS}" .
else
  if [ -z "$FORCEPUSH" ]; then
    echo "No version changes, not building/pushing."
    echo "To override, set FORCEPUSH=1."
    echo ""
  fi
fi

# Clean up
rm "/tmp/${IMAGE}.oldlatest.VERSIONS" "/tmp/${IMAGE}.newlatest.VERSIONS"

# BUILD NOHEALTHCHECK VERSION
# Modify dockerfile to remove healthcheck
sed '/^HEALTHCHECK /d' < Dockerfile > Dockerfile.nohealthcheck

# Build & push latest
docker buildx build -f Dockerfile.nohealthcheck -t ${REPO}/${IMAGE}:latest_nohealthcheck --compress --push --platform "${PLATFORMS}" .

# If there are version differences, build & push with a tag matching the build date
if [ $DIFFEXITCODE -ne 0 ]; then
    docker buildx build -f Dockerfile.nohealthcheck -t "${REPO}/${IMAGE}:$(date -I)_nohealthcheck" --compress --push --platform "${PLATFORMS}" .
else
  if [ -z "$FORCEPUSH" ]; then
    echo "No version changes, not building/pushing."
    echo "To override, set FORCEPUSH=1."
    echo ""
  fi
fi
