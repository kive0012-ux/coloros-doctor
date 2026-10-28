#!/system/bin/sh
# =============================================================
#  通用工具（本文件只定义函数，不产生任何系统副作用）
# =============================================================

DOCDIR="$MODDIR"
RUNDIR="$DOCDIR/run"
REPLOG="$RUNDIR/repair.log"
SCANJSON="$RUNDIR/last_scan.json"
mkdir -p "$RUNDIR" 2>/dev/null
[ -f "$DOCDIR/config.sh" ] && . "$DOCDIR/config.sh"

dlog() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$RUNDIR/doctor.log" 2>/dev/null; }

rp() {  # resetprop 优先
  if command -v resetprop >/dev/null 2>&1; then resetprop "$@" 2>/dev/null
  else [ -n "$2" ] && setprop "$1" "$2" 2>/dev/null; fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

is_root() { [ "$(id -u 2>/dev/null)" = "0" ]; }

# 出厂属性兜底：从出厂 build.prop 读真实值
get_stock_value() {
  _k="$1"
  for _f in /system/build.prop /vendor/build.prop /system_ext/build.prop /product/build.prop /odm/build.prop /vendor/odm/etc/build.prop; do
    [ -f "$_f" ] || continue
    _v=$(grep "^$_k=" "$_f" 2>/dev/null | head -n1 | cut -d= -f2-)
    [ -n "$_v" ] && { echo "$_v"; return 0; }
  done
  return 1
}

# 旧优化模块目录探测：输出目录路径（每行一个，路径不含空格，可安全逐词遍历）
find_old_modules() {
  for base in /data/adb/modules /data/adb/ksu/modules; do
    [ -d "$base" ] || continue
    for d in "$base"/*; do
      [ -d "$d" ] || continue
      case "$(basename "$d")" in
        zzz-coloros-doctor|coloros-doctor) continue;;
      esac
      [ -f "$d/module.prop" ] || continue
      mid=$(grep -m1 '^id=' "$d/module.prop" 2>/dev/null | cut -d= -f2-)
      mname=$(grep -m1 '^name=' "$d/module.prop" 2>/dev/null | cut -d= -f2-)
      hit=""
      echo "$d" | grep -qiE "$OLD_MODULE_PAT" && hit=1
      echo "$mid $mname" | grep -qiE "$OLD_MODULE_PAT" && hit=1
      [ "$hit" = "1" ] && echo "$d"
    done
  done
}

# JSON 字符串安全化（包名/域名/路径均为安全字符，仅需去引号反斜杠）
jesc() { echo "$1" | sed 's/["\\]/ /g' | tr -d '\n\r\t'; }

pkg_disabled() { pm list packages -d 2>/dev/null | grep -qx "package:$1"; }
pkg_installed() { pm path "$1" >/dev/null 2>&1; }

enable_pkg() {  # 尽力启用 + 解除后台限制，全部容错
  p="$1"
  pm enable "$p" >/dev/null 2>&1
  cmd deviceidle whitelist +"$p" >/dev/null 2>&1
  cmd am set-standby-bucket "$p" active >/dev/null 2>&1
  am set-inactive "$p" false >/dev/null 2>&1
  cmd am set-inactive "$p" false >/dev/null 2>&1
  for op in RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND START_FOREGROUND AUTO_START; do
    cmd appops set "$p" "$op" allow >/dev/null 2>&1
  done
}
