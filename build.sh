#!/usr/bin/env bash
# 打包 Magisk/KSU 模块 zip（module.prop 必须在 zip 根目录）
set -e
cd "$(dirname "$0")"
rm -f coloros-doctor.zip
zip -r coloros-doctor.zip module.prop config.sh action.sh service.sh customize.sh uninstall.sh \
    common webroot system README.md \
    -x "*.DS_Store" -x "*.tmp" >/dev/null
echo "== zip 内容 =="
unzip -l coloros-doctor.zip
echo "== 根目录文件校验 =="
unzip -p coloros-doctor.zip module.prop | head -4
