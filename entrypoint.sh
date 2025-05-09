#!/bin/bash
set -e

# 🧱 سحب الكود من GitHub
git clone https://github.com/abdulsamed113/Intellichain.git /app/contract

# ✅ الانتقال للمجلد وتنفيذ التنصيب
cd /app/contract
make install

# 🐚 بدء جلسة Bash للمستخدم
exec bash
