ARG REGISTRY=msyea
ARG DOCKER_VERSION=latest
ARG GIT_VERSION=latest

FROM ${REGISTRY}/ubuntu-git:${GIT_VERSION} AS git

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

# Copy our version guess helper
COPY version.sh /usr/local/bin/

RUN \
  if [ "${DOCKER_CHANNEL}" = "stable" ]; then \
		if [ "${DOCKER_VERSION}" = "latest" ] || printf %s\\n "${DOCKER_VERSION}" | grep -Eq '^[0-9a-f]{7}$'; then \
			DOCKER_VERSION=$(version.sh "moby/moby"); \
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
RUN if [ "$COMPOSE_VERSION" = "latest" ]; then COMPOSE_VERSION=$(version.sh "docker/compose"); fi; \
		if [ "${COMPOSE_VERSION%%.*}" -ge "2" ]; then \
			if [ "$COMPOSE_SWITCH_VERSION" = "latest" ]; then COMPOSE_SWITCH_VERSION=$(version.sh "docker/compose-switch"); fi; \
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

# Install git dependencies and git from image. This will also install a few
# other packages, incl. curl and tini (for process-tree control within
# containers).
RUN apt-get update \
		&& apt-get -y install \
					awscli \
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
# price since that would generate a LARGE image. So, instead, we'll be
# recreating all symlinks by hand, as make install did.

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
# Now over to most of the links, make them point to the main git binary
# (installed itself in /usr/bin)
RUN cd /usr/libexec/git-core && for lname in \
							git-add \
							git-am \
							git-annotate \
							git-apply \
							git-archive \
							git-bisect--helper \
							git-blame \
							git-branch \
							git-bugreport \
							git-bundle \
							git-cat-file \
							git-check-attr \
							git-check-ignore \
							git-check-mailmap \
							git-check-ref-format \
							git-checkout \
							git-checkout--worker \
							git-checkout-index \
							git-cherry \
							git-cherry-pick \
							git-clean \
							git-clone \
							git-column \
							git-commit \
							git-commit-graph \
							git-commit-tree \
							git-config \
							git-count-objects \
							git-credential \
							git-credential-cache \
							git-credential-cache--daemon \
							git-credential-store \
							git-describe \
							git-diff \
							git-diff-files \
							git-diff-index \
							git-diff-tree \
							git-difftool \
							git-env--helper \
							git-fast-export \
							git-fast-import \
							git-fetch \
							git-fetch-pack \
							git-fmt-merge-msg \
							git-for-each-ref \
							git-for-each-repo \
							git-format-patch \
							git-fsck \
							git-fsck-objects \
							git-gc \
							git-get-tar-commit-id \
							git-grep \
							git-hash-object \
							git-help \
							git-index-pack \
							git-init \
							git-init-db \
							git-interpret-trailers \
							git-log \
							git-ls-files \
							git-ls-remote \
							git-ls-tree \
							git-mailinfo \
							git-mailsplit \
							git-maintenance \
							git-merge \
							git-merge-base \
							git-merge-file \
							git-merge-index \
							git-merge-ours \
							git-merge-recursive \
							git-merge-subtree \
							git-merge-tree \
							git-mktag \
							git-mktree \
							git-multi-pack-index \
							git-mv \
							git-name-rev \
							git-notes \
							git-pack-objects \
							git-pack-redundant \
							git-pack-refs \
							git-patch-id \
							git-prune \
							git-prune-packed \
							git-pull \
							git-push \
							git-range-diff \
							git-read-tree \
							git-rebase \
							git-receive-pack \
							git-reflog \
							git-remote \
							git-remote-ext \
							git-remote-fd \
							git-remote-ftp \
							git-remote-ftps \
							git-remote-https \
							git-repack \
							git-replace \
							git-rerere \
							git-reset \
							git-restore \
							git-rev-list \
							git-rev-parse \
							git-revert \
							git-rm \
							git-send-pack \
 							git-shortlog \
							git-show \
							git-show-branch \
							git-show-index \
							git-show-ref \
							git-sparse-checkout \
							git-stage \
							git-stash \
							git-status \
							git-stripspace \
							git-submodule--helper \
							git-switch \
							git-symbolic-ref \
							git-tag \
							git-unpack-file \
							git-unpack-objects \
							git-update-index \
							git-update-ref \
							git-update-server-info \
							git-upload-archive \
							git-upload-pack \
							git-var \
							git-verify-commit \
							git-verify-pack \
							git-verify-tag \
							git-whatchanged \
							git-worktree \
							git-write-tree; do \
					ln -sf ../../bin/git "$lname"; \
				done
# Some links are inside the git-core directory (git-remove-http implements all
# protocols).
RUN cd /usr/libexec/git-core && for lname in \
							git-remote-ftp \
							git-remote-ftps \
							git-remote-https; do \
					ln -sf "git-remote-http" "$lname"; \
				done
# A few /usr/bin/ binaries also want to exist in git-core.
RUN cd /usr/libexec/git-core && for lname in \
							git \
							git-cvsserver \
							git-shell; do \
					ln -sf "../../bin/$lname" "$lname"; \
				done
# Complete the git installation, skip the web stuff
COPY --from=git /usr/libexec/git-core/mergetools/* /usr/libexec/git-core/mergetools/
COPY --from=git /usr/share/git-core /usr/share/git-core

WORKDIR /actions-runner
RUN chown rootless:rootless /actions-runner
USER rootless
RUN if [ "$GH_RUNNER_VERSION" = "latest" ]; then GH_RUNNER_VERSION=$(version.sh "actions/runner"); fi \
		&& wget -q -O actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION#v*}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
		&& tar xzf ./actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz \
		&& rm -f ./actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz
USER root
RUN ./bin/installdependencies.sh

COPY logger.sh utils.sh /opt/bash-utils/
COPY github-actions-entrypoint.sh runner.sh token.sh dockerd-rootless.sh dockerd-rootless-setup-tool.sh /usr/local/bin/
# Create a link to where we will be storing the rootless UNIX socket for the
# Docker daemon. This is to allow Dockerfile-based GH actions to run, as the
# /var/run/docker.sock path is hard-coded in the implementation code.
RUN ln -sf /home/rootless/.docker/run/docker.sock /var/run/docker.sock

USER rootless
RUN dockerd-rootless-setup-tool.sh install ${DOCKERD_ROOTLESS_INSTALL_FLAGS}
ENV XDG_RUNTIME_DIR=/home/rootless/.docker/run \
		PATH=/usr/local/bin:$PATH \
		DOCKER_HOST=unix:///home/rootless/.docker/run/docker.sock

ENTRYPOINT [ "tini", "-s", "--" ]
CMD [ "github-actions-entrypoint.sh" ]