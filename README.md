# docker-ffmpeg

A build of ffmpeg with many common audio and video codecs, including HEVC/VP9/AV1, as well as the Nvidia `nvenc` support.

Netflix's `libvmaf` support is also compiled in for running metrics on transcoded video.

## Usage

It's best to make another docker container and copy the contents of /opt/ffmpeg from this container to your new container. This will make for a much smaller image. But you can also run it directly with

```
docker run -it offbytwo/ffmpeg
```

For an example of a smaller image that contains this (and other tools) see [video-tools](https://github.com/cosmin/docker-video-tools)
