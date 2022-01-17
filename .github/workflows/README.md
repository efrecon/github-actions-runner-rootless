# Auto Releasing

The workflow `autorelease.yml` in this directory arranges to automatically make
releases of the project which follows the releasing of the main [runner]
project. Release checks are scheduled once a day. At the time of the check:

+ The current [runner] release tag is detected (this may contain a leading `v`).
+ The current release of this project is detected.
+ When the semantic versions of these two projects a new release is made:
  + A new Docker is made and published to the GHCR and DockerHub, with a tag
    without a leading `v`. Publication to the DockerHub only happens whenever relevant secrets are accessible to the project.
  + A new (automatic) release is made, named exactly as the [runner] release
    (but with a tag without a leading `v`).

Releases of the rootless runner depend on Docker versions. New versions of the
Docker engine are detected at the same time, and will generate images at the
GHCR (and conditionally the DockerHub). When a new Docker engine image needs to
be created, a logic similar to the one above is used, except that it uses the
presence of the image at the corresponding Docker registry.

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
