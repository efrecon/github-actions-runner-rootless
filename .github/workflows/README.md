# Auto Releasing

The workflow `autorelease.yml` in this directory arranges to automatically make
releases of the project. These releases follows the release tempo of the main
[runner] project. When a new release for the runner is detected, i.e. whenever
there is no Docker image with the same tag within this repository, a new image
is built. This is checked once per day.

Once a new image has been generated successfully:

+ The latest [runner] release tag is detected.
+ The latest release of this project is detected.
+ When the semantic versions of these two projects differs, a new release is
  made and will point to the image generated as described above.

Releases of the rootless runner depend on Docker and git versions. New versions
of the Docker engine and git are detected at the same time, and will generate
images at the GHCR (and conditionally the DockerHub). When a new Docker
engine/git image needs to be created, a logic similar to the one above is used,
except that it uses the presence of the image at the corresponding Docker
registry.

Auto releasing uses a reusable [workflow](./_release.yml), called 4 times, once
for each of the relevant `Dockerfile`s at the root of the project. The following
Docker images will be generated:

+ `ubuntu-docker` for [`Dockerfile.docker`](../../Dockerfile.docker), a Docker
  image with the Docker client and daemon installed.
+ `ubuntu-dind` for [`Dockerfile.dind`](../../Dockerfile.dind), a Docker image
  built upon `ubuntu-docker`, but capable of running Docker in Docker.
+ `ubuntu-git` for [`Dockerfile.docker`](../../Dockerfile.git), a Docker image
  with a minimal (latest) git client.
+ `github-actions-runner` for [`Dockerfile`](../../Dockerfile), the Docker image
  which is the target of this project. It depends on all other images above, and
  adds and configure the rootless tools.

  [runner]: https://github.com/actions/runner/releases

## Removing

If you wanted to manually re-create all images for a given release, perform the
following operations:

+ Remove the Docker images tagged with a version number, e.g.
  `ubuntu-docker:20.10.12`, `ubuntu-dind:20.10.12` from the package registry.
+ Remove the release from the list of releases for this project.
+ Remove the tag at the origin, e.g. `git push --delete origin 2.286.0`.
+ (optional) Remove the Docker image for the rootless runner from the package
  registry.

Once you have cleaned up, it is possible to manually re-run the workflow from
the GitHub UI.

## Manual Release

It is possible to manually release, back in time, if necessary. This is handled
by the `manual.yml` workflow. You can interact with it from the GitHub actions
UI. The workflow takes the SemVer for the `runner`, `docker` and `git` as
inputs. These versions will default to the latest stable release of each
project. When releasing back in time, "latest" will not always have the expected
outcome. Instead, you should arrange to research which version of each project
(`git` and `docker`) was the latest when the runner release that you want to
catch up with was made.
