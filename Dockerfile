FROM ubuntu:24.04

ARG GCC_VERSION=15

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    GCC_VERSION=${GCC_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY build.sh /tmp/
RUN /tmp/build.sh && rm -f /tmp/build.sh

COPY build-dev-tools.sh /tmp/
RUN /tmp/build-dev-tools.sh && rm -f /tmp/build-dev-tools.sh

COPY install-llvm.sh /tmp/
RUN /tmp/install-llvm.sh && rm -f /tmp/install-llvm.sh

COPY build-emacs.sh /tmp/
RUN /tmp/build-emacs.sh && rm -f /tmp/build-emacs.sh

COPY install-nodejs.sh /tmp/
RUN /tmp/install-nodejs.sh && rm -f /tmp/install-nodejs.sh

COPY install-python.sh /tmp/
RUN /tmp/install-python.sh && rm -f /tmp/install-python.sh

COPY install-rust.sh /tmp/
RUN /tmp/install-rust.sh && rm -f /tmp/install-rust.sh

COPY *.el install-doom.sh /tmp/
RUN /tmp/install-doom.sh && rm -rf /tmp/*

COPY install-racket.sh /tmp/
RUN /tmp/install-racket.sh && rm -f /tmp/install-racket.sh

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
