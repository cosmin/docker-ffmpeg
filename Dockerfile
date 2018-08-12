FROM nvidia/cuda:9.2-devel-ubuntu18.04
LABEL maintainer "Cosmin Stejerean <cosmin@offbytwo.com>"

ENV DEBIAN_FRONTEND noninteractive

# update, and install basic packages
RUN apt-get update -qq
RUN apt-get install -y build-essential curl git python
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get -y install \
  autoconf \
  automake \
  build-essential \
  cmake \
  git-core \
  libass-dev \
  libfreetype6-dev \
  libsdl2-dev \
  libtool \
  libva-dev \
  libvdpau-dev \
  libvorbis-dev \
  libxcb1-dev \
  libxcb-shm0-dev \
  libxcb-xfixes0-dev \
  pkg-config \
  texinfo \
  wget \
  zlib1g-dev

RUN mkdir -p /opt/sources /opt/ffmpeg/bin
ENV PATH="/opt/ffmpeg/bin:$PATH"
ENV PKG_CONFIG_PATH="/opt/ffmpeg_build/lib/pkgconfig"

WORKDIR /opt/sources
RUN wget https://www.nasm.us/pub/nasm/releasebuilds/2.13.03/nasm-2.13.03.tar.bz2
RUN tar xjvf nasm-2.13.03.tar.bz2
WORKDIR /opt/sources/nasm-2.13.03
RUN ./autogen.sh
RUN ./configure --prefix="/opt/ffmpeg_build" --bindir="/opt/ffmpeg/bin"
RUN make -j$(nproc)
RUN make install

RUN apt-get -y install yasm

WORKDIR /opt/sources
RUN git clone https://github.com/FFmpeg/nv-codec-headers /opt/sources/nv-codec-headers
WORKDIR /opt/sources/nv-codec-headers
RUN make -j$(nproc)
RUN make install
RUN rm -rf /opt/sources/nv-codec-headers

WORKDIR  /opt/sources
RUN git -C x264 pull 2> /dev/null || git clone --depth 1 https://git.videolan.org/git/x264
WORKDIR /opt/sources/x264
RUN ./configure --prefix="/opt/ffmpeg_build" --bindir="/opt/ffmpeg/bin" --enable-static --enable-pic
RUN make -j$(nproc)
RUN make install

RUN apt-get install -y mercurial libnuma-dev
WORKDIR /opt/sources
RUN hg clone https://bitbucket.org/multicoreware/x265
WORKDIR x265/build/linux
RUN cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/opt/ffmpeg_build" -DENABLE_SHARED=off ../../source
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources
RUN git -C libvpx pull 2> /dev/null || git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git
WORKDIR libvpx
RUN ./configure --prefix="/opt/ffmpeg_build" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources
RUN git -C fdk-aac pull 2> /dev/null || git clone --depth 1 https://github.com/mstorsjo/fdk-aac
WORKDIR fdk-aac
RUN autoreconf -fiv
RUN ./configure --prefix="/opt/ffmpeg_build" --disable-shared
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources
RUN wget -O lame-3.100.tar.gz https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
RUN tar xzvf lame-3.100.tar.gz
WORKDIR lame-3.100
RUN ./configure --prefix="/opt/ffmpeg_build" --bindir="/opt/ffmpeg/bin" --disable-shared --enable-nasm
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources
RUN git -C opus pull 2> /dev/null || git clone --depth 1 https://github.com/xiph/opus.git
WORKDIR opus
RUN ./autogen.sh
RUN ./configure --prefix="/opt/ffmpeg_build" --disable-shared
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources
RUN git -C aom pull 2> /dev/null || git clone --depth 1 https://aomedia.googlesource.com/aom
RUN mkdir aom_build
WORKDIR aom_build
RUN cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/opt/ffmpeg_build" -DENABLE_SHARED=off -DENABLE_NASM=on ../aom
RUN make -j$(nproc)
RUN make install

RUN apt-get install -y openssl libssl-dev

WORKDIR /opt/sources
RUN wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
RUN tar xjvf ffmpeg-snapshot.tar.bz2
WORKDIR ffmpeg
RUN ./configure \
  --prefix="/opt/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I/opt/ffmpeg_build/include" \
  --extra-cflags="-I/usr/local/cuda/include" \
  --extra-ldflags="-L/opt/ffmpeg_build/lib" \
  --extra-ldflags="-L/usr/local/cuda/lib64" \
  --extra-libs="-lpthread -lm" \
  --bindir="/opt/ffmpeg/bin" \
  --enable-gpl \
  --enable-nonfree \
  --enable-version3 \
  --enable-libaom \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-openssl \
  --enable-vaapi \ 
  --enable-cuda-sdk \
  --enable-cuvid \
  --enable-libnpp
RUN make -j$(nproc)
RUN make install
WORKDIR /opt

RUN apt-get -y clean
RUN rm -r /var/lib/apt/lists/*

RUN apt-get -y clean
RUN rm -r /var/lib/apt/lists/*

RUN rm -rf /opt/sources
