FROM ubuntu:26.10

# Aura-minimal image.
# Ubuntu 26.10, GCC 16.2, CMake 4.5.0-rc3 (newest Kitware release; 4.4.5 is
# the newest stable), Ninja 1.13.2, LLVM 23.1.5 trimmed to the binaries and
# static libraries Aura's CMake build actually links.
# Also: mold, ld.lld, libgit2, Python 3, ruff, pexpect.
# Not installed: Emacs and its X11/GTK stack, Node, pnpm, Rust, OpenClaw,
# Flang, MLIR, LLDB, and the rest of the upstream LLVM tarball.

ARG CMAKE_VERSION=4.5.0-rc3
ARG LLVM_VERSION=23.1.5
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    TZ=Asia/Shanghai \
    GCC_VERSION=16 \
    CMAKE_VERSION=${CMAKE_VERSION} \
    LLVM_VERSION=${LLVM_VERSION}

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

RUN apt-get update && apt-get install -y --no-install-recommends sudo \
    && rm -rf /var/lib/apt/lists/*
RUN EXISTING_GROUP=$(getent group ${USER_GID} | cut -d: -f1 || true) && \
    if [ -n "${EXISTING_GROUP}" ] && [ "${EXISTING_GROUP}" != "${USERNAME}" ]; then \
        groupmod -n ${USERNAME} ${EXISTING_GROUP}; \
    elif ! getent group ${USER_GID} >/dev/null; then \
        groupadd --gid ${USER_GID} ${USERNAME}; \
    fi && \
    EXISTING_USER=$(getent passwd ${USER_UID} | cut -d: -f1 || true) && \
    if [ -n "${EXISTING_USER}" ] && [ "${EXISTING_USER}" != "${USERNAME}" ]; then \
        usermod -l ${USERNAME} -d /home/${USERNAME} -m ${EXISTING_USER}; \
    elif ! getent passwd ${USER_UID} >/dev/null; then \
        useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/zsh -G sudo,tty ${USERNAME}; \
    fi && \
    mkdir -p /etc/sudoers.d && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

WORKDIR /home/${USERNAME}
USER root

COPY build.sh install-llvm.sh /home/${USERNAME}/
RUN bash /home/${USERNAME}/build.sh \
    && bash /home/${USERNAME}/install-llvm.sh \
    && rm -f /home/${USERNAME}/build.sh /home/${USERNAME}/install-llvm.sh

# gosu drops privileges and keeps the TTY. Multi-arch binary, verified by signature.
RUN apt-get update && \
    ARCH="$(dpkg --print-architecture)" && \
    curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.17/gosu-${ARCH}" && \
    curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.17/gosu-${ARCH}.asc" && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
    rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc && \
    chmod +x /usr/local/bin/gosu && \
    /usr/local/bin/gosu nobody true && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
WORKDIR /home/dev/code
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
