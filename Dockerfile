FROM ubuntu:24.04

ARG GCC_VERSION=15

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    GCC_VERSION=${GCC_VERSION}

# === 后面所有 build 脚本（顺序优化：基础→工具链→语言→Emacs）===
COPY build.sh /tmp/ && /tmp/build.sh && rm /tmp/build.sh

COPY build-dev-tools.sh /tmp/ && /tmp/build-dev-tools.sh && rm /tmp/build-dev-tools.sh

# 新增/调整的 GCC + LLVM 脚本
COPY install-llvm.sh /tmp/ && /tmp/install-llvm.sh && rm /tmp/install-llvm.sh

COPY build-emacs.sh /tmp/ && /tmp/build-emacs.sh && rm /tmp/build-emacs.sh

COPY build-nodejs.sh /tmp/ && /tmp/build-nodejs.sh && rm /tmp/build-nodejs.sh

COPY build-python.sh /tmp/ && /tmp/build-python.sh && rm /tmp/build-python.sh

COPY build-rust.sh /tmp/ && /tmp/build-rust.sh && rm /tmp/build-rust.sh

# Doom Emacs 配置
COPY *.el build-doom.sh /tmp/
RUN /tmp/build-doom.sh && rm -rf /tmp/*

# Racket（保留，但 README 注失效）
COPY build-racket.sh /tmp/ && /tmp/build-racket.sh && rm /tmp/build-racket.sh

# === 创建固定 dev 用户（构建时写死 1000）===
RUN groupadd --gid 1000 dev \
    && useradd --uid 1000 --gid 1000 -m -s /bin/zsh -G sudo dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev \
    && mkdir -p /home/dev/code /home/dev/.cache/ccache \
    && chown -R dev:dev /home/dev

# 复制 entrypoint
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# 最终清理
RUN rm -rf /root/*.sh /tmp/* /var/tmp/*

# 使用 entrypoint（关键！）
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/zsh"]
