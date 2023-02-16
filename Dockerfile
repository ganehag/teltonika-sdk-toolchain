FROM debian:11

ENV SDK_MODEL=RUT9_R
ENV SDK_VERSION=00.07.03.4
ENV SDK_CHECKSUM=531de3a16aef0d5f5d79b01b7c29709d

WORKDIR /tmp

RUN \
  DEBIAN_FRONTEND=noninteractive \
  apt update -y && \
  apt install -y wget build-essential git cmake libssl-dev libpcre3-dev libcurl4-openssl-dev libjson-c-dev libsqlite3-dev libssl-dev libusb-1.0-0-dev libmodbus-dev

RUN wget -O - https://wiki.teltonika-networks.com/gpl/${SDK_MODEL}_GPL_${SDK_VERSION}.tar.gz | tar xvzf -

RUN ls /tmp

CMD ["/bin/bash]
