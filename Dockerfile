FROM ubuntu:24.04 AS base

ENV GCC_VERSION=15
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV TZ=Asia/Shanghai

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

RUN apt-get update && apt-get install -y sudo && rm -rf /var/lib/apt/lists/

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
        useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/zsh -G sudo ${USERNAME}; \
    fi && \
    mkdir -p /etc/sudoers.d && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}

COPY build.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/build.sh && rm /home/${USERNAME}/build.sh

FROM base AS tools
COPY install-dev-tools.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/install-dev-tools.sh && rm /home/${USERNAME}/install-dev-tools.sh

FROM tools AS languages
COPY install-languages.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/install-languages.sh && rm /home/${USERNAME}/install-languages.sh

FROM languages AS llvm
COPY install-llvm.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/install-llvm.sh && rm /home/${USERNAME}/install-llvm.sh

FROM llvm AS emacs
COPY build-emacs.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/build-emacs.sh && rm /home/${USERNAME}/build-emacs.sh
COPY *.el /home/${USERNAME}/
COPY build-doom.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/build-doom.sh && rm /home/${USERNAME}/build-doom.sh /home/${USERNAME}/*.el

FROM emacs AS final

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sudo chmod +x /usr/local/bin/entrypoint.sh

RUN sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -f /home/${USERNAME}/*.sh /home/${USERNAME}/*.el

WORKDIR /home/dev/code
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
