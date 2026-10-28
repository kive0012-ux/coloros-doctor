#!/system/bin/sh
# =============================================================
#  service 阶段：本模块自身不做任何系统修改。
#  仅记录启动日志；AUTO_FIX_ON_BOOT=true 时自动执行一次安全修复。
# =============================================================
MODDIR=${0%/*}
case "$MODDIR" in ""|"$0") MODDIR=. ;; esac
export MODDIR
. "$MODDIR/common/util.sh"

dlog "==== ColorOS 系统体检修复 service 启动 ===="

if [ "$AUTO_FIX_ON_BOOT" = "true" ]; then
  (
    # 等系统就绪再修复
    i=0
    while [ "$i" -lt 150 ]; do
      [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ] && cmd deviceidle help >/dev/null 2>&1 && break
      sleep 2; i=$((i+1))
    done
    : > "$REPLOG"
    . "$MODDIR/common/repair.sh" >> "$REPLOG" 2>&1
    dlog "开机自动修复完成"
  ) &
fi
exit 0
