FROM ubuntu:24.04 AS base

ENV GCC_VERSION=15
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV TZ=Asia/Shanghai

COPY build.sh /root/
RUN /root/build.sh

# ==================== Stage 2: 基础工具链 (CMake/Ninja/Zsh/tmux) ====================
FROM base AS tools
COPY install-dev-tools.sh /root/
RUN /root/install-dev-tools.sh

# ==================== Stage 3: 语言工具 (NodeJS/Python/Rust/Racket) ====================
FROM tools AS languages
COPY install-languages.sh /root/
RUN /root/install-languages.sh

# ==================== Stage 4: LLVM/Clang ====================
FROM languages AS llvm
COPY install-llvm.sh /root/
RUN /root/install-llvm.sh

# ==================== Stage 5: Emacs Stack (编译 Emacs + Doom) ====================
FROM llvm AS emacs
COPY build-emacs.sh /root/
RUN /root/build-emacs.sh
COPY *.el /root/
COPY build-doom.sh /root/
RUN /root/build-doom.sh

# ==================== Stage 6: Final（非 root + entrypoint）===================
FROM emacs AS final

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

RUN if ! getent group 1000 >/dev/null; then \
        groupadd --gid 1000 dev; \
    fi && \
    if ! getent passwd 1000 >/dev/null; then \
        useradd --uid 1000 --gid 1000 -m -s /bin/zsh -G sudo dev; \
    fi && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev && \
    mkdir -p /home/dev/code /home/dev/.cache/ccache && \
    chown -R 1000:1000 /home/dev

RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN chown -R $USERNAME:$USERNAME \
    /usr/local /opt \
    /root/.cargo /root/.rustup \
    /root/.emacs.d /root/.doom.d /root/.local /root/.config 2>/dev/null || true

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -f /root/*.sh /root/*.el

WORKDIR /home/dev/code
USER $USERNAME
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
