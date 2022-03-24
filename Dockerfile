ARG REGISTRY=msyea
ARG DOCKER_VERSION=latest
# Ubuntu focal (20.04) has git v2.25, but GitHub Actions require higher. We use
# our own git image. When latest, will pick latest stable release at the time of
# the build.
ARG GIT_VERSION=latest

FROM ${REGISTRY}/ubuntu-git:${GIT_VERSION} AS git

FROM ${REGISTRY}/ubuntu-dind:${DOCKER_VERSION}

# Docker release channel and version. Version is inherited from outside the
# source but needs to be redeclared here again.
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION

# When latest, will pick latest official release
ARG GH_RUNNER_VERSION="latest"

# Versions for Docker compose (and shim) releases. When latest, will pick latest
# stable release at the time of the build.
ARG COMPOSE_VERSION=latest
ARG COMPOSE_SWITCH_VERSION=latest

# Name of Users and uid remapping information
ARG USER_DOCKER=rootless
ARG USER_RUNNER=runner
ARG USER_REMAP=65537

ARG DOCKERD_ROOTLESS_INSTALL_FLAGS

# Build arguments for OCI-oriented information
ARG OCI_GITHUB=https://github.com/msyea/github-actions-runner-rootless
ARG OCI_ORG=msyea
ARG OCI_SHA=
ARG OCI_BRANCH=main
ARG OCI_DOCKERFILE=Dockerfile
ARG OCI_RFC3339=

# Dynamic OCI Labels
LABEL org.opencontainers.image.authors="Simon Mayes <https://github.com/msyea>, Emmanuel Frécon <https://github.com/efrecon>"
LABEL org.opencontainers.image.url="${OCI_GITHUB}"
LABEL org.opencontainers.image.documentation="${OCI_GITHUB}"
LABEL org.opencontainers.image.source="${OCI_GITHUB}/blob/${OCI_BRANCH}/${OCI_DOCKERFILE}"
LABEL org.opencontainers.image.vendor="${OCI_ORG}"
LABEL org.opencontainers.image.version="${GH_RUNNER_VERSION}"
LABEL org.opencontainers.image.revision="${OCI_SHA}"
LABEL org.opencontainers.image.license="MIT"
LABEL org.opencontainers.image.title="Rootless-DinD GitHub Runner"
LABEL org.opencontainers.image.description="Dockerised GitHub Actions self-hosted runner using ubuntu and rootless-dind"
LABEL org.opencontainers.image.created="${OCI_RFC3339}"

# "/run/user/UID" will be used by default as the value of XDG_RUNTIME_DIR
RUN mkdir /run/user && chmod 1777 /run/user


# create a default user preconfigured for running rootless dockerd
RUN adduser --home /home/${USER_DOCKER} --gecos 'Rootless' --disabled-password "${USER_DOCKER}"; \
		echo "${USER_DOCKER}:${USER_REMAP}:65536" >> /etc/subuid; \
		echo "${USER_DOCKER}:${USER_REMAP}:65536" >> /etc/subgid

# look into guid !!!
RUN if test "${USER_RUNNER}" != "${USER_DOCKER}"; then adduser --disabled-password "${USER_RUNNER}"; fi

# Copy our utils to /usr/local/bin
COPY utils/version.sh utils/git-symlink.sh utils/install-*.sh /usr/local/bin/

RUN install-rootless.sh -v "${DOCKER_VERSION}" -c "${DOCKER_CHANNEL}"

# pre-create "/var/lib/docker" for our rootless user and arrange for .local
# directory to be owned by rootless so default XDG locations associated to this
# directory (XDG_STATE_HOME and XDG_DATA_HOME) can be used.
RUN mkdir -p /home/${USER_DOCKER}/.local/share/docker; \
		mkdir -p /home/${USER_DOCKER}/.local/state; \
		chown -R ${USER_DOCKER}:${USER_DOCKER} /home/${USER_DOCKER}/.local
VOLUME /home/${USER_DOCKER}/.local/share/docker

# Install Docker compose. Turn on compatibility mode when installing newer 2.x
# branch.
RUN install-compose.sh -c "$COMPOSE_VERSION" -s "${COMPOSE_SWITCH_VERSION}"

# Install git dependencies and git from image. This will also install a few
# other packages, incl. curl and tini (for process-tree control within
# containers).
RUN apt-get update \
		&& apt-get -y install \
					build-essential \
					curl \
					gettext \
					jq \
					libexpat1 \
					libpcre2-8-0 \
					openssh-client \
					perl \
					software-properties-common \
					tini \
					zlib1g \
					zstd \
		&& rm -rf /var/lib/apt/lists/*

# Now... starts the fun! COPY resolves symlinks, which we want to avoid at all
# price since that would generate a LARGE image otherwise. So, instead, we'll be
# recreating all symlinks by hand, as make install did. This is delegated to a
# separate script to keep the Dockerfile somewhat clean.

# Start by copying the main git binaries.
COPY --from=git /usr/bin/git* /usr/bin/
# Add the few ones that are direct executables in the git-core directory. A
# number of these are actually scripts.
COPY --from=git \
				/usr/libexec/git-core/git-add--interactive \
				/usr/libexec/git-core/git-archimport \
				/usr/libexec/git-core/git-bisect \
				/usr/libexec/git-core/git-cvsexportcommit \
				/usr/libexec/git-core/git-cvsimport \
				/usr/libexec/git-core/git-daemon \
				/usr/libexec/git-core/git-difftool--helper \
				/usr/libexec/git-core/git-filter-branch \
				/usr/libexec/git-core/git-http-backend \
				/usr/libexec/git-core/git-http-fetch \
				/usr/libexec/git-core/git-imap-send \
				/usr/libexec/git-core/git-instaweb \
				/usr/libexec/git-core/git-merge-octopus \
				/usr/libexec/git-core/git-merge-one-file \
				/usr/libexec/git-core/git-merge-resolve \
				/usr/libexec/git-core/git-mergetool \
				/usr/libexec/git-core/git-mergetool--lib \
				/usr/libexec/git-core/git-p4 \
				/usr/libexec/git-core/git-quiltimport \
				/usr/libexec/git-core/git-remote-http \
				/usr/libexec/git-core/git-request-pull \
				/usr/libexec/git-core/git-send-email \
				/usr/libexec/git-core/git-sh-i18n \
				/usr/libexec/git-core/git-sh-i18n--envsubst \
				/usr/libexec/git-core/git-sh-setup \
				/usr/libexec/git-core/git-submodule \
				/usr/libexec/git-core/git-svn \
				/usr/libexec/git-core/git-web--browse \
			/usr/libexec/git-core/
# Complete the git installation, skip the web stuff
COPY --from=git /usr/libexec/git-core/mergetools/* /usr/libexec/git-core/mergetools/
COPY --from=git /usr/share/git-core /usr/share/git-core
# And re-create all relevant links. We use a separate shell script to avoid
# polluting the code of the Dockerfile, as this represents lots of symlinks.
RUN git-symlink.sh

WORKDIR /actions-runner
RUN chown ${USER_DOCKER}:${USER_DOCKER} /actions-runner
USER ${USER_DOCKER}
RUN install-runner.sh -v "$GH_RUNNER_VERSION"
USER root
RUN ./bin/installdependencies.sh

COPY lib/*.sh /opt/bash-utils/
COPY github-actions-entrypoint.sh runner.sh token.sh dockerd-rootless.sh dockerd-rootless-setup-tool.sh /usr/local/bin/
# Create a link to where we will be storing the rootless UNIX socket for the
# Docker daemon. This is to allow Dockerfile-based GH actions to run, as the
# /var/run/docker.sock path is hard-coded in the implementation code.
RUN ln -sf /home/${USER_DOCKER}/.docker/run/docker.sock /var/run/docker.sock

USER ${USER_DOCKER}
RUN dockerd-rootless-setup-tool.sh install ${DOCKERD_ROOTLESS_INSTALL_FLAGS}
ENV XDG_RUNTIME_DIR=/home/${USER_DOCKER}/.docker/run \
		PATH=/usr/local/bin:$PATH \
		DOCKER_HOST=unix:///home/${USER_DOCKER}/.docker/run/docker.sock

ENTRYPOINT [ "tini", "-g", "--" ]
CMD [ "github-actions-entrypoint.sh" ]