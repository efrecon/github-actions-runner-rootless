ARG REGISTRY=msyea
ARG DOCKER_VERSION=latest
FROM ${REGISTRY}/ubuntu-dind:${DOCKER_VERSION}

# Docker release channel and version. Version is inherited from outside the
# source but needs to be redeclared here again.
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION

# Ubuntu focal (20.04) has git v2.25, but GitHub Actions require higher. We
# build git from source instead. When latest, will pick latest stable release at
# the time of the build.
ARG GIT_VERSION="latest"
# When latest, will pick latest official release
ARG GH_RUNNER_VERSION="latest"

# Root URL and version for Docker compose (and shim) releases. When latest, will
# pick latest stable release at the time of the build.
ARG COMPOSE_ROOT=https://github.com/docker/compose
ARG COMPOSE_VERSION=latest
ARG COMPOSE_SWITCH_ROOT=https://github.com/docker/compose-switch
ARG COMPOSE_SWITCH_VERSION=latest

ARG DOCKERD_ROOTLESS_INSTALL_FLAGS

# "/run/user/UID" will be used by default as the value of XDG_RUNTIME_DIR
RUN mkdir /run/user && chmod 1777 /run/user

# look into guid !!!
RUN adduser --disabled-password runner

# create a default user preconfigured for running rootless dockerd
RUN adduser --home /home/rootless --gecos 'Rootless' --disabled-password rootless; \
		echo 'rootless:100000:65536' >> /etc/subuid; \
		echo 'rootless:100000:65536' >> /etc/subgid

RUN \
  if [ "${DOCKER_CHANNEL}" = "stable" ]; then \
		if [ "${DOCKER_VERSION}" = "latest" ] || printf %s\\n "${DOCKER_VERSION}" | grep -Eq '^[0-9a-f]{7}$'; then \
			DOCKER_VERSION=$(wget -q -O - "https://raw.githubusercontent.com/docker-library/docker/master/versions.json"|grep '"version"'|head -n 1|sed -E 's/\s+"version"\s*:\s*"([^"]+)".*/\1/'); \
		fi; \
	fi; \
	\
	arch="$(uname --m)"; \
	case "$arch" in \
		'x86_64') \
			url="https://download.docker.com/linux/static/${DOCKER_CHANNEL}/x86_64/docker-rootless-extras-${DOCKER_VERSION}.tgz"; \
			;; \
		'aarch64') \
			url="https://download.docker.com/linux/static/${DOCKER_CHANNEL}/aarch64/docker-rootless-extras-${DOCKER_VERSION}.tgz"; \
			;; \
		*) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;; \
	esac; \
	\
	wget -O rootless.tgz "$url"; \
	\
	tar --extract \
		--file rootless.tgz \
		--strip-components 1 \
		--directory /usr/local/bin/ \
		'docker-rootless-extras/rootlesskit' \
		'docker-rootless-extras/rootlesskit-docker-proxy' \
		'docker-rootless-extras/vpnkit' \
	; \
	rm rootless.tgz; \
	\
	rootlesskit --version; \
	vpnkit --version

# pre-create "/var/lib/docker" for our rootless user and arrange for .local
# directory to be owned by rootless so default XDG locations associated to this
# directory (XDG_STATE_HOME and XDG_DATA_HOME) can be used.
RUN mkdir -p /home/rootless/.local/share/docker; \
		mkdir -p /home/rootless/.local/state; \
		chown -R rootless:rootless /home/rootless/.local
VOLUME /home/rootless/.local/share/docker

# Install Docker compose. Turn on compatibility mode when installing newer 2.x
# branch.
RUN if [ "$COMPOSE_VERSION" = "latest" ]; then COMPOSE_VERSION=$(wget -q -O - "${COMPOSE_ROOT%/}/tags"| grep -E '/docker/compose/releases/tag/v[0-9]' | grep -v rc  |  awk -F'[v\"]' '{print $3}' | head -1); fi; \
		if [ "${COMPOSE_VERSION%%.*}" -ge "2" ]; then \
			if [ "$COMPOSE_SWITCH_VERSION" = "latest" ]; then COMPOSE_SWITCH_VERSION=$(wget -q -O - "${COMPOSE_SWITCH_ROOT%/}/tags"| grep -E '/docker/compose-switch/releases/tag/v[0-9]' | grep -v rc  |  awk -F'[v\"]' '{print $3}' | head -1); fi; \
			mkdir -p /usr/lib/docker/cli-plugins; \
			wget -q -O /usr/lib/docker/cli-plugins/docker-compose "${COMPOSE_ROOT%/}/releases/download/v${COMPOSE_VERSION#v*}/docker-compose-$(uname -s|tr '[:upper:]' '[:lower:]')-$(uname -m)" ; \
			chmod a+x /usr/lib/docker/cli-plugins/docker-compose; \
			case "$(uname -m)" in \
				'x86_64') \
					arch=amd64; \
					;; \
				'aarch64') \
					arch=arm64; \
					;; \
				*) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;; \
			esac; \
			wget -q -O /usr/local/bin/docker-compose "${COMPOSE_SWITCH_ROOT%/}/releases/download/v${COMPOSE_SWITCH_VERSION#v*}/docker-compose-$(uname -s|tr '[:upper:]' '[:lower:]')-${arch}" ; \
			chmod a+x /usr/local/bin/docker-compose; \
		else \
			wget -q -O /usr/local/bin/docker-compose "${COMPOSE_ROOT%/}/releases/download/${COMPOSE_VERSION#v*}/docker-compose-$(uname -s)-$(uname -m)"; \
			chmod a+x /usr/local/bin/docker-compose; \
		fi; \
		docker-compose --version

# Install and compile git. This will also install a few other packages, incl.
# curl and tini (for process-tree control within containers).
RUN apt-get update \
		&& apt-get -y install \
					awscli \
					build-essential \
					curl \
					gettext \
					jq \
					libcurl4-openssl-dev \
					software-properties-common \
					tini \
					zlib1g-dev \
					zstd \
		&& if [ "$GIT_VERSION" = "latest" ]; then GIT_VERSION=$(wget -q -O - "https://github.com/git/git/tags"| grep -E '/git/git/releases/tag/v[0-9]' | grep -v rc  |  awk -F'[v\"]' '{print $3}' | head -1); fi \
		&& cd /tmp \
		&& curl -sL https://www.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz -o git.tgz \
		&& tar zxf git.tgz \
		&& cd git-${GIT_VERSION} \
		&& ./configure --prefix=/usr \
		&& make \
		&& make install \
		&& rm -rf /var/lib/apt/lists/* \
		&& rm -rf /tmp/* \
		&& git --version

WORKDIR /actions-runner
RUN chown rootless:rootless /actions-runner
USER rootless
RUN if [ "$GH_RUNNER_VERSION" = "latest" ]; then GH_RUNNER_VERSION=$(wget -q -O - "https://raw.githubusercontent.com/actions/runner/main/src/runnerversion"); fi \
		&& wget -q -O actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION#v*}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
		&& tar xzf ./actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
		&& rm -f ./actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz
USER root
RUN ./bin/installdependencies.sh

COPY logger.sh /opt/bash-utils/
COPY github-actions-entrypoint.sh runner.sh token.sh dockerd-rootless.sh dockerd-rootless-setup-tool.sh /usr/local/bin/

USER rootless
RUN dockerd-rootless-setup-tool.sh install ${DOCKERD_ROOTLESS_INSTALL_FLAGS}
ENV XDG_RUNTIME_DIR=/home/rootless/.docker/run \
		PATH=/usr/local/bin:$PATH \
		DOCKER_HOST=unix:///home/rootless/.docker/run/docker.sock

ENTRYPOINT [ "tini", "-s", "--" ]
CMD [ "github-actions-entrypoint.sh" ]