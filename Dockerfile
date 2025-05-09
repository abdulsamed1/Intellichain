# 🧱 صورة أساس خفيفة
FROM debian:bookworm-slim

# 🌍 المتغيرات البيئية
ENV NODE_VERSION=22.15.0 \
    YARN_VERSION=1.22.22 \
    PATH="/opt/venv/bin:/root/.foundry/bin:/root/.cyfrin/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ⚙️ تحديث النظام وتثبيت الأدوات الأساسية
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash dash curl wget gnupg dirmngr ca-certificates \
        coreutils git python3 python3-pip python3-venv xz-utils \
        make && \
    ln -sf /bin/bash /bin/sh && \
    rm -rf /var/lib/apt/lists/*


# 🟢 تثبيت Node.js يدويًا لتفادي طبقات Docker الخاصة به
RUN ARCH=linux-x64 && \
    curl -fsSL --retry 5 --retry-delay 5 https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-$ARCH.tar.xz -o /tmp/node.tar.xz && \
    mkdir -p /usr/local/lib/nodejs && \
    tar -xf /tmp/node.tar.xz --strip-components=1 -C /usr/local && \
    rm /tmp/node.tar.xz

# 🧶 تفعيل pnpm
RUN corepack enable pnpm

# 🧪 إنشاء بيئة افتراضية وتثبيت Slither فقط
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install slither-analyzer

# 🧰 تثبيت Foundry (باستخدام retry للحماية من فشل الشبكة)
RUN curl --retry 5 --retry-delay 5 -L https://foundry.paradigm.xyz -o /tmp/foundry_install.sh && \
    bash /tmp/foundry_install.sh && \
    /root/.foundry/bin/foundryup && \
    rm /tmp/foundry_install.sh

# 🔐 تثبيت Cyfrinup
RUN mkdir -p /root/.cyfrin/bin && \
    curl --retry 5 --retry-delay 5 -L https://raw.githubusercontent.com/Cyfrin/up/main/install -o /tmp/cyfrin_install.sh && \
    bash /tmp/cyfrin_install.sh && \
    rm /tmp/cyfrin_install.sh


# 🔚 إعداد مسار العمل
WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
