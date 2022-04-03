#!/bin/sh

set -eu

# git version to install. This can be `latest`: the latest release. This can
# also be a SemVer, possibly with a git sha at its end (dash separated), in
# which case the git sha is removed to get the version.
GIT_VERSION=${GIT_VERSION:-"latest"}

# Command to use to download a URL passed as a parameter and print out its
# content to stdout. The default is an empty string, which will use wget or
# curl, if present.
GIT_DOWNLOAD=${GIT_DOWNLOAD:-""}

# Prefix under which to install, e.g. /usr or /usr/local
GIT_INSTALL_PREFIX=${GIT_INSTALL_PREFIX:-/usr}

while getopts "v:h-" opt; do
  case "$opt" in
    v) # gitversion
      GIT_VERSION=$OPTARG;;
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

# When the latest version is specified, go and get the latest version of git to
# build upon.
if [ "${GIT_VERSION}" = "latest" ] || printf %s\\n "${GIT_VERSION}" | grep -Eq '^[0-9a-f]{7}$'; then
  GIT_VERSION=$(version "git/git")
fi

# When the version number ends with a git sha, remove that and build with the
# remaining version number.
if printf %s\\n "${GIT_VERSION}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+-[0-9a-f]{7}$'; then
  GIT_VERSION=$(printf %s\\n "${GIT_VERSION}" | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+')
fi

# Decide upon a tool for downloads
if [ -z "$GIT_DOWNLOAD" ]; then
  if command -v wget >/dev/null 2>&1; then
    GIT_DOWNLOAD="wget -q -O -"
  elif command -v curl >/dev/null 2>&1; then
    GIT_DOWNLOAD="curl -sSL"
  else
    echo "Cannot find an external tool for URL downloads!" >&2
    exit 1
  fi
fi

# Download and install under prefix
$GIT_DOWNLOAD "https://www.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz" >/tmp/git.tgz
tar -C /tmp -zxf /tmp/git.tgz
( cd "/tmp/git-${GIT_VERSION}" && \
  ./configure --prefix="${GIT_INSTALL_PREFIX}" && \
  NO_TCLTK=1 INSTALL_SYMLINKS=1 make install )
rm -rf /tmp/git*

# Print out the installed versions, this is to make sure we got the binaries
# right.
git --version
