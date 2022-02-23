# GitHub Actions Runner

Built on `ubuntu:20.04`, configured for rootless dind 🎉, impossible without invaluable advice from [@kenichi-shibata](https://github.com/kenichi-shibata) and [@sidick](https://github.com/sidick).
## Inspiration from
* https://github.com/cruizba/ubuntu-dind showed me it was possible on ubuntu
* https://github.com/myoung34/docker-github-actions-runner showed it running docker outside docker - inspired API and wrote some README - rights theirs
* https://github.com/docker-library/docker/tree/master/20.10/dind-rootless for their outstanding work

# Images
- [msyea/ubuntu-docker](https://hub.docker.com/repository/docker/msyea/ubuntu-docker)
- [msyea/ubuntu-dind](https://hub.docker.com/repository/docker/msyea/ubuntu-dind)
- [msyea/ubuntu-git](https://hub.docker.com/repository/docker/msyea/ubuntu-git)
- [msyea/github-actions-runner](https://hub.docker.com/repository/docker/msyea/github-actions-runner)

Docker Github Actions Runner
============================

[![Docker Pulls](https://img.shields.io/docker/pulls/msyea/github-actions-runner.svg)](https://hub.docker.com/r/msyea/github-actions-runner)

This will run the [new self-hosted github actions runners](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/hosting-your-own-runners).

## Features ##

* DinD Docker daemon running in rootless mode.
* Dynamic registration of the runner at GitHub.
* Runner registration for an entire organisation, or for a repository.
* Support for both enterprise installations, and `github.com`.
* Support for labels and groups to categorise runners.
* Able to run all [types] of actions, including [Docker][container-action]
  container actions!
* Multi-platform support.
* Each runner can be customised through running a series of script/programs
  prior to registration at the GitHub server.
* Automatically [follows](#releases) the [release] tempo of the official
  [runner]. Generated images will be tagged with the SemVer of the release.
* `latest` tag will correspond to latest [release] of the [runner].
* Fully automated [workflows](.github/workflows/README.md), manual interaction
  possible.
* Comes bundled with latest `docker compose` (v2, the plugin), together with the
  `docker-compose` [shim].

  [types]: https://docs.github.com/en/actions/creating-actions/about-custom-actions#types-of-actions
  [container-action]: https://docs.github.com/en/actions/creating-actions/creating-a-docker-container-action
  [release]: https://github.com/actions/runner/releases
  [runner]: https://github.com/actions/runner
  [shim]: https://github.com/docker/compose-switch

## Environment Variables ##

| Environment Variable | Description |
| --- | --- |
| `RUNNER_NAME` | The name of the runner to use. Supercedes (overrides) `RUNNER_NAME_PREFIX` |
| `RUNNER_NAME_PREFIX` | A prefix for a randomly generated name (followed by a random 13 digit string). You must not also provide `RUNNER_NAME`. Defaults to `github-runner` |
| `ACCESS_TOKEN` | A [github PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) to use to generate `RUNNER_TOKEN` dynamically at container start. Not using this requires a valid `RUNNER_TOKEN` |
| `ORG_RUNNER` | Only valid if using `ACCESS_TOKEN`. This will set the runner to an org runner. Default is 'false'. Valid values are 'true' or 'false'. If this is set to true you must also set `ORG_NAME` and makes `REPO_URL` unneccesary |
| `ORG_NAME` | The organization name for the runner to register under. Requires `ORG_RUNNER` to be 'true'. No default value. |
| `LABELS` | A comma separated string to indicate the labels. Default is 'default' |
| `REPO_URL` | If using a non-organization runner this is the full repository url to register under such as 'https://github.com/msyea/repo' |
| `RUNNER_TOKEN` | If not using a PAT for `ACCESS_TOKEN` this will be the runner token provided by the Add Runner UI (a manual process). Note: This token is short lived and will change frequently. `ACCESS_TOKEN` is likely preferred. |
| `RUNNER_WORKDIR` | The working directory for the runner. Runners on the same host should not share this directory. Default is '/_work'. This must match the source path for the bind-mounted volume at RUNNER_WORKDIR, in order for container actions to access files. |
| `RUNNER_GROUP` | Name of the runner group to add this runner to (defaults to the default runner group) |
| `GITHUB_HOST` | Optional URL of the Github Enterprise server e.g github.mycompany.com. Defaults to `github.com`. |
| `RUNNER_PREFLIGHT_PATH` | A colon separated list of directories. All executable files present will be run before the rootless daemon is running and runner registered. Defaults to empty. |
| `RUNNER_INIT_PATH` | A colon separated list of directories. All executable files present will be run once the rootless daemon is running, but before the runner is registered. Defaults to empty. |
| `RUNNER_CLEANUP_PATH` | A colon separated list of directories. All executable files present will be run after the runner has been deregistered. Defaults to empty. |

### Manual ###

```shell
# org runner
docker run -d --restart always --name github-runner \
  -e RUNNER_NAME_PREFIX="myrunner" \
  -e ACCESS_TOKEN="footoken" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  -e ORG_RUNNER="true" \
  -e ORG_NAME="octokode" \
  -e LABELS="my-label,other-label" \
  msyea/github-actions-runner:latest
# per repo
docker run -d --restart always --name github-runner \
  -e REPO_URL="https://github.com/msyea/repo" \
  -e RUNNER_NAME="foo-runner" \
  -e RUNNER_TOKEN="footoken" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  msyea/github-actions-runner:latest
```

Or shell wrapper:

```shell
function github-runner {
    name=github-runner-${1//\//-}
    org=$(dirname $1)
    repo=$(basename $1)
    tag=${3:-latest}
    docker rm -f $name
    docker run -d --restart=always \
        -e REPO_URL="https://github.com/${org}/${repo}" \
        -e RUNNER_TOKEN="$2" \
        -e RUNNER_NAME="linux-${repo}" \
        -e RUNNER_WORKDIR="/tmp/github-runner-${repo}" \
        -e RUNNER_GROUP="my-group" \
        -e LABELS="my-label,other-label" \
        --name $name ${org}/github-runner:${tag}
}

github-runner your-account/your-repo       AARGHTHISISYOURGHACTIONSTOKEN
github-runner your-account/some-other-repo ARGHANOTHERGITHUBACTIONSTOKEN ubuntu-xenial
```

Or `docker-compose.yml`:

```yml
version: '2.3'

services:
  worker:
    image: msyea/github-actions-runner:latest
    environment:
      REPO_URL: https://github.com/example/repo
      RUNNER_NAME: example-name
      RUNNER_TOKEN: someGithubTokenHere
      RUNNER_GROUP: my-group
      ORG_RUNNER: 'false'
      LABELS: linux,x64,gpu
```

## Usage From GH Actions Workflow ##

```yml
name: Package

on:
  release:
    types: [created]

jobs:
  build:
    runs-on: self-hosted
    steps:
    - uses: actions/checkout@v1
    - name: build packages
      run: make all
```

## Automatically Acquiring a Runner Token  ##

A runner token can be automatically acquired at runtime if `ACCESS_TOKEN` (a GitHub personal access token) is a supplied. This uses the [GitHub Actions API](https://developer.github.com/v3/actions/self_hosted_runners/#create-a-registration-token). e.g.:

```shell
docker run -d --restart always --name github-runner \
  -e ACCESS_TOKEN="footoken" \
  -e RUNNER_NAME="foo-runner" \
  -e RUNNER_WORKDIR="/tmp/github-runner-your-repo" \
  -e RUNNER_GROUP="my-group" \
  -e ORG_RUNNER="true" \
  -e ORG_NAME="octokode" \
  -e LABELS="my-label,other-label" \
  msyea/github-actions-runner:latest
```

## Create GitHub personal access token  ##

Creating GitHub personal access token (PAT) for using by self-hosted runner make sure the following scopes are selected:

* repo (all)
* admin:org (all) **_(mandatory for organization-wide runner)_**
* admin:public_key - read:public_key
* admin:repo_hook - read:repo_hook
* admin:org_hook
* notifications
* workflow

Also, when creating a PAT for self-hosted runner which will process events from several repositories of the particular organization, create the PAT using organization owner account. Otherwise your new PAT will not have sufficient privileges for all repositories.

## Available Tools ##

These images do **not** contain **all** the tools that GitHub offers by default
in their runners. Workflows might work improperly when running from within these
runners. The [Dockerfile](./Dockerfile) for the runner images ensures:

* A rootless installation of the Docker daemon, including the `docker` cli
  binary.
* An installation of Docker [compose]. Unless otherwise specified, the latest
  stable version at the time of image building will be automatically picked up.
  At the time of writing, this installs the latest `2.x` branch, rewritten in
  golang, including the `docker-compose` compatibility [shim].
* An installation of `git` that is compatible with the github runner code.
  Unless otherwise specified, the latest stable version at the time of image
  building will be automatically picked up. This is because the default version
  available in Ubuntu is too old.
* The `build-essential` package, in order to facilitate compilation.

In the rootless runners, the `DOCKER_HOST` variable is set to point out the
private socket owned by the `rootless` user. In addition, `/var/run/docker.sock`
is a symbolic link to that socket. This link enables docker
[actions][docker-action] to properly build images and run containers built on
these images. The link is necessary as `/var/run/docker.sock` is currently
[hard-coded].

  [compose]: https://github.com/docker/compose
  [docker-action]: https://docs.github.com/en/actions/creating-actions/creating-a-docker-container-action
  [hard-coded]: https://github.com/actions/runner/blob/47ba1203c98ebe80d7fd27d515485b9624f86e94/src/Runner.Worker/Handlers/ContainerActionHandler.cs#L184

## Releases ##

By default, the Docker images will follow the stable release channel for Docker.
New images with the semantic version as a tag will be made available shortly
after a new release of Docker is made. Similarily, the rootless runner image
follows the release tempo of the main [runner][release] project. New images with
the semantic version as a tag will be made available shortly after a new
[release] is made. Released runner images use the latest Docker stable release
version at the time of the build, e.g. the release. See
[here](.github/workflows/README.md) for more details.
