#!/system/bin/sh
# =============================================================
#  一键修复：逐步执行，每步输出「# 说明」行，结尾输出 RESULT|{json}
#  原则：先精确还原（按旧模块备份清单），再兜底修复；全程幂等可重复执行
# =============================================================

fixed=0; failed=0
step() { echo "# $*"; echo "$(date '+%m-%d %H:%M:%S') STEP $*" >> "$REPLOG" 2>/dev/null; }
ok()   { fixed=$((fixed+1)); echo "# ✔ $*"; }
bad()  { failed=$((failed+1)); echo "# ✘ $*"; }

# ---------- ① 停掉旧模块的看门狗 / 守护进程 ----------
step "① 停止残留看门狗与守护进程"
for m in $WATCHDOG_MARKS; do
  [ -f "$m" ] || continue
  pid=$(cat "$m" 2>/dev/null)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null && ok "已停止看门狗 pid=$pid ($m)" || bad "停止失败 $m"
  fi
  rm -f "$m" 2>/dev/null
done
pkill -f "bin/UFCS" 2>/dev/null && ok "已停止充电加速进程" 
if [ -f /data/adb/modules/UFCS/webroot/.managed_by_zzz ] && [ ! -f /data/adb/modules/UFCS/module.prop ]; then
  rm -rf /data/adb/modules/UFCS 2>/dev/null && ok "清理充电加速播种目录"
fi

# ---------- ② 按旧模块备份清单精确还原属性 ----------
step "② 还原被注入的系统属性（按备份清单）"
restored_props=0
for d in $(find_old_modules); do
  # prop_backup.list：key=value，value 为空表示该属性原本不存在→删除注入
  if [ -f "$d/prop_backup.list" ]; then
    while IFS= read -r ln; do
      case "$ln" in *=*) k="${ln%%=*}"; v="${ln#*=}";;
                       *) continue;; esac
      case "$k" in *[!A-Za-z0-9_.]*) continue;; esac
      if [ -n "$v" ]; then rp -n "$k" "$v" && restored_props=$((restored_props+1))
      else command -v resetprop >/dev/null 2>&1 && resetprop -d "$k" >/dev/null 2>&1 && restored_props=$((restored_props+1)); fi
    done < "$d/prop_backup.list"
    ok "prop_backup.list 还原完成（$d）"
  fi
  # dolby_backup.list：key=value，__EMPTY__ 表示原本不存在
  if [ -f "$d/dolby_backup.list" ]; then
    while IFS= read -r ln; do
      case "$ln" in *=*) k="${ln%%=*}"; v="${ln#*=}";;
                       *) continue;; esac
      case "$k" in *[!A-Za-z0-9_.]*) continue;; esac
      [ "$v" = "__EMPTY__" ] && v=""
      if [ -n "$v" ]; then rp -n "$k" "$v" && restored_props=$((restored_props+1))
      else command -v resetprop >/dev/null 2>&1 && resetprop -d "$k" >/dev/null 2>&1 && restored_props=$((restored_props+1)); fi
    done < "$d/dolby_backup.list"
    ok "dolby_backup.list 还原完成（$d）"
  fi
done
[ "$restored_props" -gt 0 ] && echo "#   共还原属性 $restored_props 项" || echo "#   无待还原的属性备份"

# ---------- ③ 指纹/机型钉回出厂真值（防伪造残留） ----------
step "③ 设备指纹与机型信息钉回出厂值"
fp_fixed=0
for k in ro.product.brand ro.product.manufacturer ro.product.model \
         ro.product.device ro.product.board ro.build.fingerprint ro.board.first_api_level \
         ro.build.type ro.build.tags ro.debuggable ro.secure; do
  sv=$(get_stock_value "$k")
  cur=$(getprop "$k" 2>/dev/null)
  if [ -n "$sv" ] && [ "$cur" != "$sv" ]; then
    rp -n "$k" "$sv" && fp_fixed=$((fp_fixed+1))
  elif [ -z "$sv" ] && [ -n "$cur" ]; then
    command -v resetprop >/dev/null 2>&1 && resetprop -d "$k" >/dev/null 2>&1 && fp_fixed=$((fp_fixed+1))
  fi
done
[ "$fp_fixed" -gt 0 ] && ok "指纹/机型属性已复位 $fp_fixed 项" || echo "#   指纹/机型信息本就是出厂值"

# ---------- ④ 清除明确由旧模块注入的临时属性 ----------
step "④ 清除明确的临时注入属性"
tmp_removed=0
for k in debug.sf.latch_unsignaled af.resampler.quality; do
  command -v resetprop >/dev/null 2>&1 && resetprop -d "$k" >/dev/null 2>&1 && tmp_removed=$((tmp_removed+1))
done
echo "#   清除 $tmp_removed 项（debug.sf.latch_unsignaled / af.resampler.quality）"

# ---------- ⑤ 恢复动画缩放 / Private DNS ----------
step "⑤ 恢复动画缩放与 Private DNS"
anim_src=""
for d in $(find_old_modules); do
  [ -f "$d/anim_backup.list" ] && anim_src="$d/anim_backup.list"
done
if [ -n "$anim_src" ]; then
  set -- $(cat "$anim_src" 2>/dev/null)
  settings put global window_animation_scale "${1:-1.0}" 2>/dev/null
  settings put global transition_animation_scale "${2:-1.0}" 2>/dev/null
  settings put global animator_duration_scale "${3:-1.0}" 2>/dev/null
  ok "动画缩放按备份还原（$anim_src）"
else
  settings put global window_animation_scale 1.0 2>/dev/null
  settings put global transition_animation_scale 1.0 2>/dev/null
  settings put global animator_duration_scale 1.0 2>/dev/null
  ok "动画缩放恢复 1.0"
fi
settings put global private_dns_mode opportunistic 2>/dev/null
settings put global private_dns_spec "" 2>/dev/null
ok "Private DNS 恢复自动模式"

# ---------- ⑥ hosts：卸载 systemless 挂载 + 真分区重建原版 ----------
step "⑥ 恢复原版 hosts"
if mount 2>/dev/null | grep ' on /system/etc/hosts' | grep -q 'modules/'; then
  umount /system/etc/hosts 2>/dev/null && ok "已卸载模块 hosts 挂载（重启后彻底恢复）" || bad "hosts 挂载卸载失败（重启即可恢复）"
fi
extra=$(grep -vE '^#|^$|localhost' /system/etc/hosts 2>/dev/null | wc -l)
if [ "$extra" -gt 0 ]; then
  if mount -o remount,rw /system 2>/dev/null || mount -o remount,rw / 2>/dev/null; then
    printf '127.0.0.1 localhost\n::1 localhost\n' > /system/etc/hosts 2>/dev/null \
      && ok "真分区 hosts 已重建为原版（去除 $extra 条屏蔽）" \
      || bad "hosts 写回失败（模块自带原版 hosts 将在重启后覆盖生效）"
    mount -o remount,ro /system 2>/dev/null; mount -o remount,ro / 2>/dev/null
  else
    bad "/system 只读，无法直接写回；重启后由本模块原版 hosts 覆盖生效"
  fi
else
  echo "#   真分区 hosts 无多余条目"
fi

# ---------- ⑦ 解冻被 bind-mount 冷冻的目录 ----------
step "⑦ 解冻被冷冻的目录"
unfrozen=0
for d in $CLOUD_DIRS; do
  if mount 2>/dev/null | grep -q " on $d "; then
    umount "$d" 2>/dev/null && { unfrozen=$((unfrozen+1)); ok "已解冻 $d"; } || bad "解冻失败 $d"
  fi
done
[ "$unfrozen" = "0" ] && echo "#   无被冷冻目录"

# ---------- ⑧ 恢复被禁用的系统组件（游戏助手 0 帧主修复点） ----------
step "⑧ 恢复被禁用的系统组件"
ena=0
all_disabled=$(pm list packages -d 2>/dev/null | sed 's/^package://' | sort)
for p in $all_disabled; do
  skip=0
  for k in $KEEP_DISABLED; do [ "$p" = "$k" ] && skip=1; done
  [ "$skip" = "1" ] && continue
  if pm enable "$p" >/dev/null 2>&1; then ena=$((ena+1)); else bad "启用失败 $p"; fi
done
echo "#   已恢复启用 $ena 个包（出厂黑名单 $KEEP_DISABLED 保持禁用）"
[ "$ena" -gt 0 ] && ok "被禁用组件已恢复"

# ---------- ⑨ 游戏助手 / HyperBoost / 云控框架专项保活 ----------
step "⑨ 游戏助手/HyperBoost/云控框架专项修复"
gfix=0
for p in $GAME_PKGS $CLOUD_PKGS; do
  pkg_installed "$p" || continue
  enable_pkg "$p" && gfix=$((gfix+1))
done
echo "#   已处理 $gfix 个相关包（启用+后台放行+解除待机限制）"
# 恢复被停止的温控/性能服务
for s in $(getprop 2>/dev/null | grep -oE 'init\.svc\.[a-zA-Z0-9_.-]*' | sed 's/init\.svc\.//' | grep -iE 'thermal|horae|perfd|oplus_thermal'); do
  [ "$(getprop "init.svc.$s" 2>/dev/null)" = "running" ] && continue
  start "$s" >/dev/null 2>&1 && ok "已重启温控/性能服务 $s"
done

# ---------- ⑩ 隔离旧优化模块（阻止其下次开机继续修改系统） ----------
step "⑩ 隔离旧优化模块"
qdir="$DOCDIR/quarantine"
mkdir -p "$qdir" 2>/dev/null
ts=$(date '+%Y%m%d_%H%M%S')
qmoved=0
for d in $(find_old_modules); do
  for sf in "$d"/*.sh; do chmod 000 "$sf" 2>/dev/null; done
  nd="$qdir/${ts}_$(basename "$d")"
  if mv "$d" "$nd" 2>/dev/null; then
    qmoved=$((qmoved+1)); ok "已隔离 $(basename "$d") → quarantine/（其备份数据已保留，可随时彻底删除）"
  else
    bad "隔离失败 $d（请检查空间）"
  fi
done
[ "$qmoved" = "0" ] && echo "#   未发现需要隔离的旧优化模块"

# ---------- 汇总 ----------
total=$((fixed + failed))
cat <<EOF
RESULT|{"fixed":$fixed,"failed":$failed,"props_restored":$restored_props,"enabled_pkgs":$ena,"quarantined":$qmoved}
# 修复完成：成功 $fixed 项 / 失败 $failed 项。
# ★ 强烈建议立即重启一次：hosts 覆盖、属性层、HyperBoost 服务在重启后彻底复位。
EOF
dlog "repair done fixed=$fixed failed=$failed"
