#!/bin/sh

set -eu

# Docker channel to follow
DOCKER_CHANNEL=${DOCKER_CHANNEL:-"stable"}

# Docker version to install. This can be `latest`: the latest release from the
# stable channel. This can also be a SemVer, possibly with a git sha at its end
# (dash separated), in which case the git sha is removed to get the version.
DOCKER_VERSION=${DOCKER_VERSION:-"latest"}

# Command to use to download a URL passed as a parameter and print out its
# content to stdout. The default is an empty string, which will use wget or
# curl, if present.
DOCKER_DOWNLOAD=${DOCKER_DOWNLOAD:-""}

# Destination directory. This should be an existing directory that will be in
# the PATH.
DOCKER_DESTINATION=${DOCKER_DESTINATION:-"/usr/local/bin"}

while getopts "v:c:h-" opt; do
  case "$opt" in
    v) # Docker version
      DOCKER_VERSION=$OPTARG;;
    c) # Docker release channel
      DOCKER_CHANNEL=$OPTARG;;
    h) # Print help and exit
      echo "install rootless tools";;
    -)
      break;;
    *)
      echo "Unknown option";;
  esac
done
shift $((OPTIND-1))

version() {
  if command -v "version.sh" >/dev/null 2>&1; then
    version.sh "$1"
  else
    "$(dirname "$0")/version.sh" "$1"
  fi
}

# When we are on the stable channel, and the latest version is specified, go and
# get the latest version of Docker to build upon.
if [ "${DOCKER_CHANNEL}" = "stable" ]; then
  if [ "${DOCKER_VERSION}" = "latest" ] || printf %s\\n "${DOCKER_VERSION}" | grep -Eq '^[0-9a-f]{7}$'; then
    DOCKER_VERSION=$(version "moby/moby")
  fi
fi

# When the version number ends with a git sha, remove that and build with the
# remaining version number.
if printf %s\\n "${DOCKER_VERSION}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+-[0-9a-f]{7}$'; then
  DOCKER_VERSION=$(printf %s\\n "${DOCKER_VERSION}" | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+')
fi

# Decide upon a tool for downloads
if [ -z "$DOCKER_DOWNLOAD" ]; then
  if command -v wget >/dev/null 2>&1; then
    DOCKER_DOWNLOAD="wget -q -O -"
  elif command -v curl >/dev/null 2>&1; then
    DOCKER_DOWNLOAD="curl -sSL -"
  else
    echo "Cannot find an external tool for URL downloads!" >&2
    exit 1
  fi
fi

# Decide which URL to get the tar from, this depends on the current
# architecture.
arch="$(uname --m)"
case "$arch" in
      # amd64
  x86_64) dockerArch='x86_64' ;;
      # arm32v6
  armhf) dockerArch='armel' ;;
      # arm32v7
  armv7) dockerArch='armhf' ;;
      # arm64v8
  aarch64) dockerArch='aarch64' ;;
  *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;
esac
url=https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz

# Download and install into /usr/local/bin
$DOCKER_DOWNLOAD "$url" >/tmp/docker.tgz
tar \
  --extract \
  --file /tmp/docker.tgz \
  --strip-components 1 \
  --directory "${DOCKER_DESTINATION}"
rm /tmp/docker.tgz

# Print out the installed versions, this is to make sure we got the binaries right.
dockerd --version
docker --version
