# === 🏗️ مرحلة البناء ===
FROM debian:bookworm-slim AS builder

ENV NODE_VERSION=22.15.0 \
    YARN_VERSION=1.22.22 \
    PATH="/opt/venv/bin:/root/.foundry/bin:/root/.cyfrin/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# 🔧 Install build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget gnupg ca-certificates \
        coreutils git python3 python3-pip python3-venv xz-utils \
        make bash && \
    ln -sf /bin/bash /bin/sh && \
    rm -rf /var/lib/apt/lists/*

# 🧱 Install Node.js
RUN ARCH=linux-x64 && \
    curl -fsSL https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-$ARCH.tar.xz | \
    tar -xJ --strip-components=1 -C /usr/local && \
    corepack enable pnpm

# 🧪 Install Slither
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir slither-analyzer

# 🔨 Install Foundry
RUN curl -L https://foundry.paradigm.xyz | bash && \
    $HOME/.foundry/bin/foundryup

# ⚙️ Install Cyfrinup tools
RUN curl -L https://raw.githubusercontent.com/Cyfrin/up/main/install | bash

# ===========================================
# === 🧊 الصورة النهائية ===
FROM debian:bookworm-slim

ENV PATH="/opt/venv/bin:/root/.foundry/bin:/root/.cyfrin/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# 🧩 Install only runtime dependencies (lightweight)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-venv git ca-certificates bash curl xz-utils make nano && \
    ln -sf /bin/bash /bin/sh && \
    rm -rf /var/lib/apt/lists/*


# 🧠 Copy needed files from builder
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /usr/local /usr/local
COPY --from=builder /root/.foundry /root/.foundry
COPY --from=builder /root/.cyfrin /root/.cyfrin

# 🧰 Configure git to use nano as the default editor
RUN git config --global core.editor nano

# 🗂️ Set working directory
WORKDIR /app

# 🧾 Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 🚀 Launch script
ENTRYPOINT ["/entrypoint.sh"]