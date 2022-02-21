#!/bin/sh

set -eu

# Directory where most of the git-* commands implementing the sub-commands to
# the main `git` command are installed.
GIT_SYMLINK_CORE_DIR=${GIT_SYMLINK_CORE_DIR:-"/usr/libexec/git-core"}

GIT_SYMLINK_LINKS=${GIT_SYMLINK_LINKS:-"git-add \
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
                                        git-write-tree"}

GIT_SYMLINK_CURL_ALIASES=${GIT_SYMLINK_CURL_ALIASES:-"git-remote-ftp \
                                                      git-remote-ftps \
                                                      git-remote-https"}

GIT_SYMLINK_MAIN=${GIT_SYMLINK_MAIN:-"git git-shell git-cvsserver"}

# Compute relative path from directory $1 to directory $2 (both directories need
# to exist).
relpath() {
  s=$(cd "${1%%/}" && pwd)
  d=$(cd "$2" && pwd)
  b=
  while [ "${d#"$s"/}" = "${d}" ]; do
    s=$(dirname "$s")
    b="../${b}"
  done
  printf %s\\n "${b}${d#"$s"/}"
}

# Locate where from we should link: this is the location of the main git binary
# (if it is in the PATH), but will default to /usr/bin, if it exists.
if command -v git 2>&1 >/dev/null; then
  USRBIN=$(dirname "$(command -v git)")
elif [ -d "/usr/bin" ]; then
  USRBIN=/usr/bin
else
  echo "Cannot find location of installed git or /usr/bin!" >&2
  exit 1
fi

# Create the libexec/git-core directory
if ! [ -d "$GIT_SYMLINK_CORE_DIR" ]; then
  mkdir -p "$GIT_SYMLINK_CORE_DIR"
  echo "Created $GIT_SYMLINK_CORE_DIR"
fi

# Find how to reach /usr/bin from $GIT_SYMLINK_CORE_DIR in a relative way
TO=$(relpath "$GIT_SYMLINK_CORE_DIR" "$USRBIN")

# Create links for sub-commands.
( cd "$GIT_SYMLINK_CORE_DIR" && \
  for p in $GIT_SYMLINK_LINKS; do
    ln -sf "${TO}/git" "$p"
  done )

# Create internal links for HTTP/FTP operations
( cd "$GIT_SYMLINK_CORE_DIR" && \
  for p in $GIT_SYMLINK_CURL_ALIASES; do
    ln -sf "git-remote-http" "$p"
  done )

# Create links for main progs
( cd "$GIT_SYMLINK_CORE_DIR" && \
  for p in $GIT_SYMLINK_MAIN; do
    ln -sf "${TO}/${p}" "$p"
  done )
