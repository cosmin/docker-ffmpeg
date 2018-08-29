FROM nvidia/cuda:9.2-devel-ubuntu18.04
LABEL maintainer "Cosmin Stejerean <cosmin@offbytwo.com>"

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
    libnuma-dev && \
    apt-get -y clean && rm -r /var/lib/apt/lists/*

ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN mkdir -p /opt/sources /opt/ffmpeg/bin
ENV PATH="/opt/ffmpeg/bin:$PATH"
ENV PKG_CONFIG_PATH="/opt/ffmpeg/lib/pkgconfig"

RUN apt-get update -qq && apt-get install -y gcc-8 g++-8 && apt-get -y clean && rm -r /var/lib/apt/lists/*
ENV CC=/usr/bin/gcc-8
ENV CXX=/usr/bin/g++-8

WORKDIR /opt/sources

RUN curl -sS -O https://www.nasm.us/pub/nasm/releasebuilds/2.14rc15/nasm-2.14rc15.tar.bz2 && \
    tar xjf nasm-2.14rc15.tar.bz2 && \
    cd /opt/sources/nasm-2.14rc15 && \
    ./autogen.sh && ./configure --prefix="/opt/ffmpeg" --bindir="/opt/ffmpeg/bin" && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/sources/nasm-*

RUN git clone https://github.com/FFmpeg/nv-codec-headers /opt/sources/nv-codec-headers && \
    cd /opt/sources/nv-codec-headers && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/sources/nv-codec-headers

RUN git -C x264 pull 2> /dev/null || git clone --depth 1 https://git.videolan.org/git/x264 && \
    cd /opt/sources/x264 && \
    ./configure --prefix="/opt/ffmpeg" --bindir="/opt/ffmpeg/bin" --enable-static --enable-pic && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/sources/x264

RUN hg clone https://bitbucket.org/multicoreware/x265 && \
    cd x265/build/linux && \
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/opt/ffmpeg" -DENABLE_SHARED=off ../../source && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/sources/x265

RUN git -C libvpx pull 2> /dev/null || git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git && \
    cd libvpx && \
    ./configure --prefix="/opt/ffmpeg" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/sources/libvpx

RUN git -C fdk-aac pull 2> /dev/null || git clone --depth 1 https://github.com/mstorsjo/fdk-aac && \
    cd fdk-aac && \
    autoreconf -fiv && ./configure --prefix="/opt/ffmpeg" --disable-shared && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/sources/fdk_aac

RUN curl -sS -L -O https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz && \
    tar xzf lame-3.100.tar.gz && \
    cd lame-3.100 && \
    ./configure --prefix="/opt/ffmpeg" --bindir="/opt/ffmpeg/bin" --disable-shared --enable-nasm && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/sources/lame-3.100

RUN git -C opus pull 2> /dev/null || git clone --depth 1 https://github.com/xiph/opus.git && \
    cd opus && \
    ./autogen.sh && \
    ./configure --prefix="/opt/ffmpeg" --disable-shared && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/sources/opus

RUN git -C aom pull 2> /dev/null || git clone --depth 1 https://aomedia.googlesource.com/aom && \
    mkdir aom_build && \
    cd aom_build && \
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/opt/ffmpeg" -DENABLE_SHARED=off -DENABLE_DOCS=0 -DCONFIG_UNIT_TESTS=0 -DENABLE_EXAMPLES=off -DENABLE_NASM=on ../aom && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/sources/aom && \
    rm -rf /opt/sources/aom_build

RUN git clone --branch v1.3.9 --depth 1 https://github.com/Netflix/vmaf.git vmaf && \
    cd vmaf && \
    make -j$(nproc) && \
    sed -i 's|/usr/local|/opt/ffmpeg|g' wrapper/libvmaf.pc && \
    cd wrapper && \
    make install INSTALL_PREFIX=/opt/ffmpeg && \
    rm -rf /opt/sources/vmaf

RUN curl -sS -O https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
    tar xjf ffmpeg-snapshot.tar.bz2 && \
    rm ffmpeg-snapshot.tar.bz2 && \
    cd ffmpeg && \
    ./configure \
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
	--enable-libnpp && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/sources/ffmpeg

RUN rm -rf /opt/sources
RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1
RUN echo "/usr/local/cuda/lib64/stubs" > /etc/ld.so.conf.d/zz_cuda_stubs.conf
RUN ldconfig
WORKDIR /root
