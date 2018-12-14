FROM nvidia/cuda:9.2-devel-ubuntu18.04 as build
ENV DEBIAN_FRONTEND noninteractive

# update, and install basic packages
RUN apt-get update -qq && \
    apt-get upgrade -y && \
    apt-get -y install --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    cmake \
    git-core \
    libass-dev \
    libfreetype6-dev \
    libva-dev \
    libtool \
    libvorbis-dev \
    openssl \
    libssl-dev \
    pkg-config \
    texinfo \
    wget \
    zlib1g-dev \
    yasm \
    curl \
    git \
    mercurial \
    libnuma-dev \
    gcc-8 \
    g++-8


ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN mkdir -p /opt/ffmpeg/bin
ENV PATH="/opt/ffmpeg/bin:$PATH"
ENV PKG_CONFIG_PATH="/opt/ffmpeg/lib/pkgconfig"

ENV CC=/usr/bin/gcc-8
ENV CXX=/usr/bin/g++-8

WORKDIR /opt/sources

RUN curl -sS -O https://www.nasm.us/pub/nasm/releasebuilds/2.14/nasm-2.14.tar.bz2
RUN tar xjf nasm-2.14.tar.bz2
WORKDIR /opt/sources/nasm-2.14
RUN ./autogen.sh && ./configure --prefix="/opt/ffmpeg" --bindir="/opt/ffmpeg/bin"
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/nv-codec-headers
RUN git clone https://github.com/FFmpeg/nv-codec-headers .
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/x264
RUN git clone --branch master --depth 1 https://git.videolan.org/git/x264 .
RUN ./configure --prefix="/opt/ffmpeg" --bindir="/opt/ffmpeg/bin" --enable-static --enable-pic
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources
RUN curl -O http://ftp.videolan.org/pub/videolan/x265/x265_2.8.tar.gz
RUN tar zxvf x265_2.8.tar.gz
WORKDIR x265_2.8/build/linux
RUN cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/opt/ffmpeg" -DENABLE_SHARED=off ../../source
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/libvpx
RUN git clone --branch v1.7.0 --depth 1 https://chromium.googlesource.com/webm/libvpx.git .
RUN ./configure --prefix="/opt/ffmpeg" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/fdk-aac
RUN git clone --branch v0.1.6 --depth 1 https://github.com/mstorsjo/fdk-aac .
RUN autoreconf -fiv && ./configure --prefix="/opt/ffmpeg" --disable-shared
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources
RUN curl -sS -L -O https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
RUN tar xzf lame-3.100.tar.gz
WORKDIR lame-3.100
RUN ./configure --prefix="/opt/ffmpeg" --bindir="/opt/ffmpeg/bin" --disable-shared --enable-nasm
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/opus
RUN git clone --branch v1.3 --depth 1 https://github.com/xiph/opus.git .
RUN ./autogen.sh
RUN ./configure --prefix="/opt/ffmpeg" --disable-shared
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/aom
RUN git -C aom pull 2> /dev/null || git clone --branch v1.0.0 --depth 1 https://aomedia.googlesource.com/aom .
WORKDIR /opt/sources/aom_build
RUN cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/opt/ffmpeg" -DENABLE_SHARED=off -DENABLE_DOCS=0 -DCONFIG_UNIT_TESTS=0 -DENABLE_EXAMPLES=off -DENABLE_NASM=on ../aom
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/vmaf
RUN git clone --branch v1.3.9 --depth 1 https://github.com/Netflix/vmaf.git .
RUN make -j$(nproc)
RUN sed -i 's|/usr/local|/opt/ffmpeg|g' wrapper/libvmaf.pc
WORKDIR wrapper
RUN make install INSTALL_PREFIX=/opt/ffmpeg

WORKDIR /opt/sources
RUN curl -sS -O https://ffmpeg.org/releases/ffmpeg-4.1.tar.bz2
RUN tar xjf ffmpeg-4.1.tar.bz2
WORKDIR ffmpeg-4.1
RUN    ./configure \
        --prefix="/opt/ffmpeg" \
        --pkg-config-flags="--static" \
	--extra-cflags="-I/opt/ffmpeg/include" \
	--extra-cflags="-I/usr/local/cuda/include" \
	--extra-ldflags="-L/opt/ffmpeg/lib" \
	--extra-ldflags="-L/usr/local/cuda/lib64" \
        --extra-ldexeflags="-Bstatic" \
	--extra-libs="-lpthread -lm" \
	--bindir="/opt/ffmpeg/bin" \
        --disable-shared \
        --enable-static \
        --disable-ffplay \
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
        --enable-libvmaf \
	--enable-openssl \
	--enable-vaapi \ 
	--enable-cuda-sdk \
	--enable-cuvid \
	--enable-libnpp
RUN make -j$(nproc)
RUN make install

FROM nvidia/cuda:9.2-devel-ubuntu18.04
LABEL maintainer "Cosmin Stejerean <cosmin@offbytwo.com>"
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get upgrade -y && \
    apt-get -y install --no-install-recommends \
    cuda-npp-9-2 cuda-driver-dev-9-2 \
    libva2 libva-drm2 \
    libass9 \
    libnuma1 \
    libfreetype6 \
    libvorbisenc2 libvorbis0a \
    && apt-get -y clean && rm -r /var/lib/apt/lists/*

ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /opt/ffmpeg
COPY --from=build /opt/ffmpeg .

RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1
RUN ln -s /opt/ffmpeg/share/model /usr/local/share/
RUN echo "/usr/local/cuda/lib64/stubs" > /etc/ld.so.conf.d/zz_cuda_stubs.conf
RUN ldconfig

ENV PATH="/opt/ffmpeg/bin:$PATH"
ENV PKG_CONFIG_PATH="/opt/ffmpeg/lib/pkgconfig"
WORKDIR /root
