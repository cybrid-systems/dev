FROM ubuntu:26.10 AS base
ENV GCC_VERSION=16
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV TZ=Asia/Shanghai
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
RUN apt-get update && apt-get install -y sudo
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
# Switch to root for build script and stay as root for inheritance
USER root
COPY build.sh /home/${USERNAME}/
RUN bash /home/${USERNAME}/build.sh && rm /home/${USERNAME}/build.sh
FROM base AS tools
# Already root from base
COPY install-dev-tools.sh /home/${USERNAME}/
RUN bash /home/${USERNAME}/install-dev-tools.sh && rm /home/${USERNAME}/install-dev-tools.sh
FROM tools AS languages
# Already root
COPY install-languages.sh /home/${USERNAME}/
RUN bash /home/${USERNAME}/install-languages.sh && rm /home/${USERNAME}/install-languages.sh
FROM languages AS llvm
# Already root
COPY install-llvm.sh /home/${USERNAME}/
RUN bash /home/${USERNAME}/install-llvm.sh && rm /home/${USERNAME}/install-llvm.sh
# Already root, stay as root for ENTRYPOINT

# Install gosu for proper privilege drop and TTY handling (multi-arch compatible)
RUN apt-get update && \
    ARCH="$(dpkg --print-architecture)" && \
    curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.17/gosu-${ARCH}" && \
    curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.17/gosu-${ARCH}.asc" && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
    rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc && \
    chmod +x /usr/local/bin/gosu && \
    /usr/local/bin/gosu nobody true

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -f /home/${USERNAME}/*.sh /home/${USERNAME}/*.el
WORKDIR /home/dev/code
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
