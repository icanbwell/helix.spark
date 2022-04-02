
![Deploy Docker Image](https://github.com/imranq2/helix.spark/workflows/Deploy%20Docker%20Image/badge.svg)

# To build a new image
If you want to rebuild the base Spark docker image then run the `Build Java Base Image` Github Action.  This should only be needed if you're upgrading Spark version.

To build our docker image on top of the base Spark image, then create a new release.  You can update the version in Dockerfile for base docker image (if needed).  Then create a new release and the image will be built and posted on dockerhub (https://hub.docker.com/repository/docker/imranq2/helix.spark/general).
Note that since we also build an image for arm64 using emulation this build can take 3-4 hours.


# helix.spark
Image to use for Spark Kubernetes clusters


```shell
docker manifest inspect --verbose imranq2/helix.spark:3.0.14
```
