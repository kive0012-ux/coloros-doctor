#!/system/bin/sh
# 卸载钩子：本模块没有做过任何系统修改，仅清理自身运行数据。
MODDIR=${0%/*}
case "$MODDIR" in ""|"$0") MODDIR=. ;; esac
rm -rf "$MODDIR/run" "$MODDIR/backup" 2>/dev/null
# 隔离区保留：旧模块备份数据不删，用户需要时可从 quarantine/ 找回
echo "系统体检修复已卸载。提示：隔离的旧模块数据存放在模块目录 quarantine/ 内，卸载后会被一并删除；如需保留请先手动复制出来。"
