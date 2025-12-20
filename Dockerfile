FROM ubuntu:24.04
ENV GCC_VERSION=14
COPY build.sh /root/build.sh
RUN /root/build.sh

COPY build-gcc.sh /root/build-gcc.sh
RUN /root/build-gcc.sh

COPY build-dev-tools.sh /root/build-dev-tools.sh
RUN /root/build-dev-tools.sh
