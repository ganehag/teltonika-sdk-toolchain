# First stage: build the OpenWrt toolchain
FROM debian:11 as toolchain

ENV SDK_MODEL=RUT9_R
ENV SDK_VERSION=00.07.03.4
ENV SDK_CHECKSUM=531de3a16aef0d5f5d79b01b7c29709d

# Install any required packages
RUN \
  DEBIAN_FRONTEND=noninteractive \
  apt update -y && \
  apt install -y wget build-essential git cmake libssl-dev libpcre3-dev libcurl4-openssl-dev libjson-c-dev libsqlite3-dev libssl-dev libusb-1.0-0-dev libmodbus-dev ncurses-dev gawk unzip python2 python3 rsync nodejs npm jq libffi-dev libnetfilter-acct-dev

# Run as builder user
RUN useradd -ms /bin/bash builder
USER builder

WORKDIR /src

# Download and extract the SDK
RUN wget -O - https://wiki.teltonika-networks.com/gpl/${SDK_MODEL}_GPL_${SDK_VERSION}.tar.gz | tar xvzf -

WORKDIR /src/rutos-ath79-rut9-gpl

# Fix and build toolchain
RUN touch COPYING && \
  sed -i 's/CONFIG_MAKE_TOOLCHAIN is not set/CONFIG_MAKE_TOOLCHAIN=y/' .config && \
  make oldconfig -n && \
  make toolchain/install && \
  make target/toolchain/install

# Second stage
FROM debian:11

RUN useradd -ms /bin/bash compiler
USER compiler

# Copy the toolchain from the first stage to the new stage
COPY --from=toolchain /src/rutos-ath79-rut9-gpl/bin/targets/ath79/generic/openwrt-toolchain-ath79-generic_gcc-8.4.0_musl.Linux-x86_64.tar.bz2 /tmp

USER root

RUN apt update -y && apt install bzip2 make autoconf curl pkg-config libssl-dev -y

# Extract the toolchain tarball
RUN mkdir -p /opt/toolchain-mips_24kc_gcc-8.4.0_musl
RUN tar -C /opt/toolchain-mips_24kc_gcc-8.4.0_musl -xjf /tmp/openwrt-toolchain-ath79-generic_gcc-8.4.0_musl.Linux-x86_64.tar.bz2 --strip-components 2 openwrt-toolchain-ath79-generic_gcc-8.4.0_musl.Linux-x86_64/toolchain-mips_24kc_gcc-8.4.0_musl
RUN rm /tmp/openwrt-toolchain-ath79-generic_gcc-8.4.0_musl.Linux-x86_64.tar.bz2

ENV STAGING_DIR=/opt/toolchain-mips_24kc_gcc-8.4.0_musl
ENV CC=mips-openwrt-linux-musl-gcc-8.4.0
ENV CXX=mips-openwrt-linux-musl-gcc-8.4.0
ENV AR=mips-openwrt-linux-ar
ENV RANLIB=mips-openwrt-linux-ranlib
ENV PATH="$PATH:$STAGING_DIR/bin"
ENV PKG_CONFIG_PATH=$STAGING_DIR/lib/pkgconfig:$STAGING_DIR/usr/lib/pkgconfig

# Handle libmodbus
WORKDIR /tmp
RUN echo "Extract libmodbus 3.1.6" && \
    curl -s -L https://github.com/stephane/libmodbus/releases/download/v3.1.6/libmodbus-3.1.6.tar.gz | tar -xzf - && \
    cd libmodbus-3.1.6 && \
    ./configure --host=mips-openwrt-linux-musl --prefix=$STAGING_DIR && \
    make install && \
    cd .. && \
    rm -rf libmodbus-3.1.6

WORKDIR /tmp
RUN echo "Extract openssl 1.1.1t" && \
    curl -s -L https://www.openssl.org/source/openssl-1.1.1t.tar.gz | tar -xzf - && \
    cd openssl-1.1.1t && \
    ./Configure linux-mips32 \
        --prefix=$STAGING_DIR \
        --libdir=$STAGING_DIR/lib \
        --openssldir=$STAGING_DIR/ssl \
        --cross-compile-prefix= \
        shared no-async no-tests && \
    make && \
    make install && \
    cd .. && \
    rm -rf openssl-1.1.1t

WORKDIR /tmp
RUN echo "Extract cJSON 1.7.15" && \
    curl -s -L https://github.com/DaveGamble/cJSON/archive/refs/tags/v1.7.15.tar.gz | tar -xzf - && \
    cd cJSON-1.7.15 && \
    sed -i 's/^CC =.*/CC = mips-openwrt-linux-musl-gcc-8.4.0/' Makefile && \
    make PREFIX=/usr DESTDIR=$STAGING_DIR && make PREFIX=/usr DESTDIR=$STAGING_DIR install && \
    cd .. && \
    rm -rf cJSON-1.7.15

WORKDIR /tmp
RUN echo "Extract mosquitto 2.0.11" && \
    curl -s -L https://mosquitto.org/files/source/mosquitto-2.0.11.tar.gz | tar -xzf - && \
    cd mosquitto-2.0.11 && \
    sed -i 's/^prefix?=\/usr\/local/prefix?=\/usr/' config.mk && \
    make PREFIX=/usr DESTDIR=$STAGING_DIR && make PREFIX=/usr DESTDIR=$STAGING_DIR install && \
    cd .. && \
    rm -rf mosquitto-2.0.11

WORKDIR /src

USER compiler

CMD ["/bin/bash"]
