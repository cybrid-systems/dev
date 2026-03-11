FROM ubuntu:24.04 AS base

ENV GCC_VERSION=15
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV TZ=Asia/Shanghai

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

# 早早创建 dev 用户 + sudo 免密 (idempotent version)
RUN EXISTING_GROUP=$(getent group 1000 | cut -d: -f1 || true) && \
    if [ -n "${EXISTING_GROUP}" ] && [ "${EXISTING_GROUP}" != "dev" ]; then \
        groupmod -n dev ${EXISTING_GROUP}; \
    elif ! getent group 1000 >/dev/null; then \
        groupadd --gid 1000 dev; \
    fi && \
    EXISTING_USER=$(getent passwd 1000 | cut -d: -f1 || true) && \
    if [ -n "${EXISTING_USER}" ] && [ "${EXISTING_USER}" != "dev" ]; then \
        usermod -l dev -d /home/dev -m ${EXISTING_USER}; \
    elif ! getent passwd 1000 >/dev/null; then \
        useradd --uid 1000 --gid 1000 -m -s /bin/zsh -G sudo dev; \
    fi && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev

# 切换到 dev 用户，所有后续 RUN 默认非 root
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# 复制并运行 build.sh（用 sudo 安装系统依赖 + GCC）
COPY build.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/build.sh && rm /home/${USERNAME}/build.sh

# ==================== Stage 2: 基础工具链 (CMake/Ninja/Zsh/tmux/Node/Python/Rust/fd) ====================
# 合并 install-dev-tools.sh 和 install-languages.sh 的内容（去除重复）
FROM base AS tools
COPY install-dev-tools.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/install-dev-tools.sh && rm /home/${USERNAME}/install-dev-tools.sh

# ==================== Stage 3: Racket (独立，因为 README 注失效，可移除) ====================
FROM tools AS languages
COPY install-languages.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/install-languages.sh && rm /home/${USERNAME}/install-languages.sh

# ==================== Stage 4: LLVM/Clang ====================
FROM languages AS llvm
COPY install-llvm.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/install-llvm.sh && rm /home/${USERNAME}/install-llvm.sh

# ==================== Stage 5: Emacs Stack (编译 Emacs + Doom) ====================
FROM llvm AS emacs
COPY build-emacs.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/build-emacs.sh && rm /home/${USERNAME}/build-emacs.sh
COPY *.el /home/${USERNAME}/
COPY build-doom.sh /home/${USERNAME}/
RUN sudo bash /home/${USERNAME}/build-doom.sh && rm /home/${USERNAME}/build-doom.sh /home/${USERNAME}/*.el

# ==================== Stage 6: Final（gosu + entrypoint + 清理）===================
FROM emacs AS final

# 安装 gosu（动态用户切换神器）
RUN sudo apt-get update && sudo apt-get install -y gosu && sudo rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sudo chmod +x /usr/local/bin/entrypoint.sh

# 最终清理（作为 dev 用户）
RUN sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -f /home/${USERNAME}/*.sh /home/${USERNAME}/*.el

WORKDIR /home/dev/code
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]
