FROM ubuntu:bionic as build
ARG nasm_version=2.14.02
ARG x264_version=master
ARG x265_version=3.0
ARG libvpx_version=v1.8.0
ARG fdk_aac_version=v2.0.0
ARG lame_version=3.100
ARG opus_version=v1.3
ARG libaom_version=v1.0.0
ARG vmaf_version=v1.3.13
ARG ffmpeg_version=4.1.1
ARG xvid_version=1.3.5

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
    libfreetype6-dev \
    libtool \
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
    g++-8 \
    ca-certificates


ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN mkdir -p /opt/ffmpeg/bin
ENV PATH="/opt/ffmpeg/bin:$PATH"
ENV PKG_CONFIG_PATH="/opt/ffmpeg/lib/pkgconfig"

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 700 --slave /usr/bin/g++ g++ /usr/bin/g++-7 && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 --slave /usr/bin/g++ g++ /usr/bin/g++-8

WORKDIR /opt/sources
# RUN curl -sS -O https://www.nasm.us/pub/nasm/releasebuilds/${nasm_version}/nasm-${nasm_version}.tar.xz
RUN curl -sS -O https://ftp.osuosl.org/pub/blfs/conglomeration/nasm/nasm-${nasm_version}.tar.xz
RUN tar xf nasm-${nasm_version}.tar.xz
WORKDIR /opt/sources/nasm-${nasm_version}
RUN ./autogen.sh && ./configure --prefix="/opt/ffmpeg" --bindir="/opt/ffmpeg/bin"
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources
RUN curl -sS -O http://downloads.xvid.org/downloads/xvidcore-${xvid_version}.tar.bz2
RUN tar xjf xvidcore-${xvid_version}.tar.bz2
WORKDIR /opt/sources/xvidcore/build/generic
RUN ./configure --prefix="/opt/ffmpeg" --enable-static --enable-pic
RUN make -j$(nproc)
RUN make install
RUN rm -rf /opt/ffmpeg/lib/libxvidcore.so*

WORKDIR /opt/sources/x264
RUN git clone --branch ${x264_version} --depth 1 https://git.videolan.org/git/x264 .
RUN ./configure --prefix="/opt/ffmpeg" --bindir="/opt/ffmpeg/bin" --enable-static --enable-pic
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources
RUN curl -O http://ftp.videolan.org/pub/videolan/x265/x265_${x265_version}.tar.gz
RUN tar zxvf x265_${x265_version}.tar.gz
WORKDIR x265_${x265_version}/build/linux
RUN cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/opt/ffmpeg" -DENABLE_SHARED=off ../../source
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/libvpx
RUN git clone --branch ${libvpx_version} --depth 1 https://chromium.googlesource.com/webm/libvpx.git .
RUN ./configure --prefix="/opt/ffmpeg" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/fdk-aac
RUN git clone --branch ${fdk_aac_version} --depth 1 https://github.com/mstorsjo/fdk-aac .
RUN autoreconf -fiv && ./configure --prefix="/opt/ffmpeg" --disable-shared
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources
RUN curl -sS -L -O https://downloads.sourceforge.net/project/lame/lame/${lame_version}/lame-${lame_version}.tar.gz
RUN tar xzf lame-${lame_version}.tar.gz
WORKDIR lame-${lame_version}
RUN ./configure --prefix="/opt/ffmpeg" --bindir="/opt/ffmpeg/bin" --disable-shared --enable-nasm
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/opus
RUN git clone --branch ${opus_version} --depth 1 https://github.com/xiph/opus.git .
RUN ./autogen.sh
RUN ./configure --prefix="/opt/ffmpeg" --disable-shared
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/aom
RUN git -C aom pull 2> /dev/null || git clone --branch ${libaom_version} --depth 1 https://aomedia.googlesource.com/aom .
WORKDIR /opt/sources/aom_build
RUN cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/opt/ffmpeg" -DBUILD_SHARED_LIBS=off -DENABLE_TOOLS=off -DENABLE_DOCS=off -DENABLE_EXAMPLES=off -DENABLE_TESTS=off -DENABLE_NASM=on ../aom
RUN make -j$(nproc)
RUN make install

WORKDIR /opt/sources/vmaf
RUN git clone --branch ${vmaf_version} --depth 1 https://github.com/Netflix/vmaf.git .
RUN make -j$(nproc)
RUN sed -i 's|/usr/local|/opt/ffmpeg|g' wrapper/libvmaf.pc
WORKDIR wrapper
RUN make install INSTALL_PREFIX=/opt/ffmpeg

WORKDIR /opt/sources
RUN curl -sS -O https://ffmpeg.org/releases/ffmpeg-${ffmpeg_version}.tar.bz2
WORKDIR ffmpeg-${ffmpeg_version}
RUN tar xjf ../ffmpeg-${ffmpeg_version}.tar.bz2 --strip-components 1
RUN    ./configure \
        --prefix="/opt/ffmpeg" \
        --pkg-config-flags="--static" \
	--extra-cflags="-I/opt/ffmpeg/include" \
	--extra-ldflags="-L/opt/ffmpeg/lib" \
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
	--enable-libfdk-aac \
	--enable-libfreetype \
	--enable-libmp3lame \
        --enable-libxvid \
	--enable-libopus \
	--enable-libvpx \
	--enable-libx264 \
	--enable-libx265 \
        --enable-libvmaf \
	--enable-openssl
RUN make -j$(nproc)
RUN make install

FROM ubuntu:bionic
LABEL maintainer "Cosmin Stejerean <cosmin@offbytwo.com>"
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get upgrade -y && \
    apt-get -y install --no-install-recommends \
    libnuma1 \
    libssl1.1 \
    libfreetype6 \
    && apt-get -y clean && rm -r /var/lib/apt/lists/*

ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /opt/ffmpeg
COPY --from=build /opt/ffmpeg .

RUN ln -s /opt/ffmpeg/share/model /usr/local/share/
RUN ldconfig

ENV PATH="/opt/ffmpeg/bin:$PATH"
ENV PKG_CONFIG_PATH="/opt/ffmpeg/lib/pkgconfig"
WORKDIR /root
