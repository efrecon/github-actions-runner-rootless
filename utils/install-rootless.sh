#!/bin/sh

set -eu

# Docker channel to follow
ROOTLESS_CHANNEL=${ROOTLESS_CHANNEL:-"stable"}

# Docker version to download rootless tools for. This can be `latest`: the
# latest release from the stable channel. This can also be a SemVer, possibly
# with a git sha at its end (dash separated), in which case the git sha is
# removed to get the version.
ROOTLESS_VERSION=${ROOTLESS_VERSION:-"latest"}

# Command to use to download a URL passed as a parameter and print out its
# content to stdout. The default is an empty string, which will use wget or
# curl, if present.
ROOTLESS_DOWNLOAD=${ROOTLESS_DOWNLOAD:-""}

# Destination directory. This should be an existing directory that will be in
# the PATH.
ROOTLESS_DESTINATION=${ROOTLESS_DESTINATION:-"/usr/local/bin"}

while getopts "v:c:h-" opt; do
  case "$opt" in
    v) # Docker version
      ROOTLESS_VERSION=$OPTARG;;
    c) # Docker release channel
      ROOTLESS_CHANNEL=$OPTARG;;
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
if [ "${ROOTLESS_CHANNEL}" = "stable" ]; then
  if [ "${ROOTLESS_VERSION}" = "latest" ] || printf %s\\n "${ROOTLESS_VERSION}" | grep -Eq '^[0-9a-f]{7}$'; then
    ROOTLESS_VERSION=$(version "moby/moby")
  fi
fi

# When the version number ends with a git sha, remove that and build with the
# remaining version number.
if printf %s\\n "${ROOTLESS_VERSION}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+-[0-9a-f]{7}$'; then
  ROOTLESS_VERSION=$(printf %s\\n "${ROOTLESS_VERSION}" | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+')
fi

# Decide upon a tool for downloads
if [ -z "$ROOTLESS_DOWNLOAD" ]; then
  if command -v wget >/dev/null 2>&1; then
    ROOTLESS_DOWNLOAD="wget -q -O -"
  elif command -v curl >/dev/null 2>&1; then
    ROOTLESS_DOWNLOAD="curl -sSL -"
  else
    echo "Cannot find an external tool for URL downloads!" >&2
    exit 1
  fi
fi

# Decide which URL to get the tar from, this depends on the current
# architecture.
arch="$(uname --m)"
case "$arch" in
  'x86_64')
    url="https://download.docker.com/linux/static/${ROOTLESS_CHANNEL}/x86_64/docker-rootless-extras-${ROOTLESS_VERSION}.tgz"
    ;;
  'aarch64')
    url="https://download.docker.com/linux/static/${ROOTLESS_CHANNEL}/aarch64/docker-rootless-extras-${ROOTLESS_VERSION}.tgz"
    ;;
  *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;
esac

# Download and install into /usr/local/bin
$ROOTLESS_DOWNLOAD "$url" >/tmp/rootless.tgz
tar \
  --extract \
  --file /tmp/rootless.tgz \
  --strip-components 1 \
  --directory "${ROOTLESS_DESTINATION}" \
  'docker-rootless-extras/rootlesskit' \
  'docker-rootless-extras/rootlesskit-docker-proxy' \
  'docker-rootless-extras/vpnkit'
rm /tmp/rootless.tgz

# Print out the installed versions, this is to make sure we got the binaries right.
rootlesskit --version
vpnkit --version
