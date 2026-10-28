#!/system/bin/sh
# =============================================================
#  WebUI 命令桥
#    scan                -> 体检报告（JSON）
#    repair              -> 一键修复（进度行 + RESULT|json）
#    verify              -> 修复后复查（JSON，同 scan）
#    status              -> 模块自身状态（JSON）
#    log                 -> 修复日志
# =============================================================
MODDIR=${0%/*}
case "$MODDIR" in ""|"$0") MODDIR=. ;; esac
export MODDIR
. "$MODDIR/common/util.sh"

cmd="$1"; shift

case "$cmd" in
  scan|verify)
    . "$MODDIR/common/scan.sh"
    ;;
  repair)
    : > "$REPLOG" 2>/dev/null
    . "$MODDIR/common/repair.sh"
    ;;
  status)
    boot=$(getprop sys.boot_completed 2>/dev/null)
    ver=$(grep -m1 '^version=' "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2-)
    echo "{\"status\":\"ok\",\"boot\":\"$boot\",\"version\":\"$ver\",\"root\":$(is_root && echo true || echo false)}"
    ;;
  log)
    cat "$REPLOG" 2>/dev/null || echo "(暂无修复日志)"
    ;;
  *)
    echo '{"status":"error","msg":"未知命令"}'
    ;;
esac
