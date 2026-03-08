FROM ubuntu:24.04
ENV GCC_VERSION=15
COPY build.sh /root/build.sh
RUN /root/build.sh

COPY build-dev-tools.sh /root/build-dev-tools.sh
RUN /root/build-dev-tools.sh

# llvm
COPY install-llvm.sh /root/install-llvm.sh
RUN /root/install-llvm.sh

# emacs
COPY build-emacs.sh /root/build-emacs.sh
RUN /root/build-emacs.sh

# nodejs
COPY build-nodejs.sh /root/build-nodejs.sh
RUN /root/build-nodejs.sh

# python
COPY build-python.sh /root/build-python.sh
RUN /root/build-python.sh

# rust
COPY build-rust.sh /root/build-rust.sh
RUN /root/build-rust.sh

# doom eamcs
COPY *.el /root/
COPY build-doom.sh /root/build-doom.sh
RUN /root/build-doom.sh

# racket
COPY build-racket.sh /root/build-racket.sh
RUN /root/build-racket.sh

# clear
RUN cd && rm *.sh
