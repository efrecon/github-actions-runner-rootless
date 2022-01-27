#!/bin/sh

# Docker (moby) version to build for (without leading v). When empty, the
# default will discover the latest stable release and build for it.
BUILD_DOCKER_VERSION=${BUILD_DOCKER_VERSION:-}

# GitHub runner version to build for (without leading v). When empty, the
# default will discover the latest stable release and build for it.
BUILD_RUNNER_VERSION=${BUILD_RUNNER_VERSION:-}

# Docker compose version to install in runner, when latest (the default), the
# image logic will discover latest stable release and build for it.
BUILD_COMPOSE_VERSION=${BUILD_COMPOSE_VERSION:-latest}

# git version to install in runner, when latest (the default), the image logic
# will discover latest stable release and build for it.
BUILD_GIT_VERSION=${BUILD_GIT_VERSION:-latest}

# Root of Docker registry to build images for
BUILD_REGISTRY=${BUILD_REGISTRY:-msyea}

# Rootless install arguments, by default: nothing
BUILD_ROOTLESS_INSTALL_ARGS=${BUILD_ROOTLESS_INSTALL_ARGS:-}


set -eu

# utility functions
INFO() {
	printf "\e[104m\e[97m[INFO]\e[49m\e[39m %s\n" "$1"
}

WARNING() {
	printf "\e[101m\e[97m[WARNING]\e[49m\e[39m %s\n" "$1" >&2
}

ERROR() {
	printf "\e[101m\e[97m[ERROR]\e[49m\e[39m %s\n" "$1" >&2
}

# Guess latest pure semantic version of GitHub project passed as a parameter.
# This does not use the GH API, but will rather perform some HTML scraping to
# bypass any API access restrictions.
latest() {
  wget -q -O - "https://github.com/${1%/}/releases" |
    grep -Eo "href=\"/${1%/}/releases/tag/v[0-9]+.[0-9]+.[0-9]+\"" |
    grep -v no-underline |
    head -n 1 |
    cut -d '"' -f 2 |
    awk '{n=split($NF,a,"/");print a[n]}' |
    awk 'a !~ $0{print}; {a=$0}' |
    sed -E 's/^v//'
}

if [ -z "$BUILD_DOCKER_VERSION" ]; then
  BUILD_DOCKER_VERSION=$(latest "moby/moby")
  INFO "Picked latest stable Docker version: $BUILD_DOCKER_VERSION"
fi

if [ -z "$BUILD_RUNNER_VERSION" ]; then
  BUILD_RUNNER_VERSION=$(latest "actions/runner")
  INFO "Picked latest stable GitHub Runner version: $BUILD_RUNNER_VERSION"
fi

if [ -z "$BUILD_DOCKER_VERSION" ] || [ -z "$BUILD_RUNNER_VERSION" ]; then
  ERROR "Cannot build with semantic versions for Docker and GitHub Runner!"
  exit 1
fi

INFO "Building ubuntu-docker base image"
docker build \
  --build-arg "REGISTRY=$BUILD_REGISTRY" \
  --build-arg "DOCKER_VERSION=$BUILD_DOCKER_VERSION" \
  --tag "${BUILD_REGISTRY%/}/ubuntu-docker:${BUILD_DOCKER_VERSION}" \
  .

INFO "Building ubuntu-dind (Docker in Docker) base image"
docker build \
  --build-arg "REGISTRY=$BUILD_REGISTRY" \
  --build-arg "DOCKER_VERSION=$BUILD_DOCKER_VERSION" \
  --tag "${BUILD_REGISTRY%/}/ubuntu-dind:${BUILD_DOCKER_VERSION}" \
  .

INFO "Building GitHub Runner with Rootless Docker image"
docker build \
  --build-arg "REGISTRY=$BUILD_REGISTRY" \
  --build-arg "DOCKER_VERSION=$BUILD_DOCKER_VERSION" \
  --build-arg "COMPOSE_VERSION=$BUILD_COMPOSE_VERSION" \
  --build-arg "GIT_VERSION=$BUILD_GIT_VERSION" \
  --build-arg "GH_RUNNER_VERSION=$BUILD_RUNNER_VERSION" \
  --build-arg "DOCKERD_ROOTLESS_INSTALL_FLAGS=$BUILD_ROOTLESS_INSTALL_ARGS" \
  --tag "${BUILD_REGISTRY%/}/github-actions-runner:${BUILD_RUNNER_VERSION}" \
  .
