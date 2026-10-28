#!/system/bin/sh
# =============================================================
#  体检扫描：只读不改，输出 JSON 到 stdout，并缓存到 run/last_scan.json
# =============================================================

TMP="$RUNDIR/scan.tmp"
: > "$TMP"

# ---------- 1) 旧优化模块 ----------
old_json=""
old_count=0
for d in $(find_old_modules); do
  mid=$(grep -m1 '^id=' "$d/module.prop" 2>/dev/null | cut -d= -f2-)
  mname=$(grep -m1 '^name=' "$d/module.prop" 2>/dev/null | cut -d= -f2-)
  [ "$old_count" -gt 0 ] && old_json="$old_json,"
  old_json="$old_json{\"dir\":\"$(jesc "$d")\",\"id\":\"$(jesc "$mid")\",\"name\":\"$(jesc "$mname")\"}"
  old_count=$((old_count+1))
done

# ---------- 2) 被禁用的包（排除出厂黑名单） ----------
all_disabled=$(pm list packages -d 2>/dev/null | sed 's/^package://' | sort)
bad_disabled=""
n_disabled=0
for p in $all_disabled; do
  skip=0
  for k in $KEEP_DISABLED; do [ "$p" = "$k" ] && skip=1; done
  [ "$skip" = "1" ] && continue
  if [ -z "$bad_disabled" ]; then bad_disabled="$p"; else bad_disabled="$bad_disabled $p"; fi
  n_disabled=$((n_disabled+1))
done

# ---------- 3) 属性残留（旧模块备份清单待还原条数） ----------
props_pending=0
props_files=""
for d in $(find_old_modules); do
  for f in prop_backup.list dolby_backup.list; do
    [ -s "$d/$f" ] && { props_files="$props_files $d/$f"; props_pending=$((props_pending + $(grep -c '=' "$d/$f" 2>/dev/null))); }
  done
done

# ---------- 4) 指纹是否与出厂一致 ----------
fp_ok=1
fp_cur=$(getprop ro.build.fingerprint 2>/dev/null)
fp_stock=$(get_stock_value ro.build.fingerprint 2>/dev/null)
[ -n "$fp_stock" ] && [ "$fp_cur" != "$fp_stock" ] && fp_ok=0
brand_ok=1
[ "$(getprop ro.product.brand 2>/dev/null)" != "$(get_stock_value ro.product.brand 2>/dev/null)" ] && brand_ok=0

# ---------- 5) 动画缩放 ----------
aw=$(settings get global window_animation_scale 2>/dev/null)
at=$(settings get global transition_animation_scale 2>/dev/null)
ad=$(settings get global animator_duration_scale 2>/dev/null)
anim_ok=1
for v in "$aw" "$at" "$ad"; do [ "$v" = "1.0" ] || [ "$v" = "1" ] || anim_ok=0; done

# ---------- 6) Private DNS ----------
pdns=$(settings get global private_dns_mode 2>/dev/null)
pdns_ok=1
[ "$pdns" = "hostname" ] && pdns_ok=0

# ---------- 7) hosts（真分区多余条目 + systemless 挂载） ----------
hosts_extra=""
[ -f /system/etc/hosts ] && hosts_extra=$(grep -vE '^#|^$|localhost' /system/etc/hosts 2>/dev/null | awk '{print $2}')
n_hosts=0
[ -n "$hosts_extra" ] && n_hosts=$(echo $hosts_extra | wc -w)

# ---------- 8) 被冷冻目录 / hosts 挂载 ----------
frozen=""
for d in $CLOUD_DIRS; do
  mount 2>/dev/null | grep -q " on $d " && frozen="$frozen $d"
done
n_frozen=0
[ -n "$frozen" ] && n_frozen=$(echo $frozen | wc -w)
hosts_mounted=0
mount 2>/dev/null | grep -E ' on /system/etc/hosts | on /system/etc/hosts\(' | grep -q 'modules/' && hosts_mounted=1

# ---------- 9) 看门狗/守护进程残留 ----------
wd_alive=0
wd_list=""
for m in $WATCHDOG_MARKS; do
  [ -f "$m" ] || continue
  pid=$(cat "$m" 2>/dev/null)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then wd_alive=$((wd_alive+1)); wd_list="$wd_list $m:$pid"; fi
done
pgrep -f "bin/UFCS" >/dev/null 2>&1 && wd_alive=$((wd_alive+1)) && wd_list="$wd_list UFCS"

# ---------- 10) 游戏助手/云控框架状态 ----------
game_json=""
game_bad=0
for p in $GAME_PKGS $CLOUD_PKGS; do
  pkg_installed "$p" || continue
  st="enabled"
  pkg_disabled "$p" && { st="disabled"; game_bad=$((game_bad+1)); }
  [ -n "$game_json" ] && game_json="$game_json,"
  game_json="$game_json{\"pkg\":\"$p\",\"state\":\"$st\"}"
done

# ---------- 11) 温控服务 ----------
thermal_ok=1
thermal_svcs=""
for s in $(getprop 2>/dev/null | grep -oE 'init\.svc\.[a-zA-Z0-9_.-]*thermal[a-zA-Z0-9_.-]*' | sed 's/init\.svc\.//'); do
  stv=$(getprop "init.svc.$s" 2>/dev/null)
  if [ "$stv" != "running" ]; then thermal_ok=0; thermal_svcs="$thermal_svcs $s"; fi
done

# ---------- 评分 ----------
score=100
[ "$n_disabled" -gt 0 ] 2>/dev/null && score=$((score - 30 - n_disabled))
[ "$props_pending" -gt 0 ] 2>/dev/null && score=$((score - 10 - props_pending))
[ "$fp_ok" = "0" ] && score=$((score - 15))
[ "$brand_ok" = "0" ] && score=$((score - 5))
[ "$anim_ok" = "0" ] && score=$((score - 5))
[ "$pdns_ok" = "0" ] && score=$((score - 3))
[ "$n_hosts" -gt 0 ] 2>/dev/null && score=$((score - 8))
[ "$n_frozen" -gt 0 ] 2>/dev/null && score=$((score - 10))
[ "$wd_alive" -gt 0 ] 2>/dev/null && score=$((score - 8))
[ "$game_bad" -gt 0 ] 2>/dev/null && score=$((score - 15))
[ "$thermal_ok" = "0" ] && score=$((score - 5))
[ "$score" -lt 0 ] && score=0

cat > "$TMP" <<EOF
{"ok":true,"root":$(is_root && echo true || echo false),
"score":$score,
"old_modules":[$old_json],
"disabled_pkgs":"$(jesc "$bad_disabled")","n_disabled":$n_disabled,
"props_pending":$props_pending,
"fingerprint_ok":$( [ "$fp_ok" = "1" ] && echo true || echo false),
"brand_ok":$( [ "$brand_ok" = "1" ] && echo true || echo false),
"anim_ok":$( [ "$anim_ok" = "1" ] && echo true || echo false),
"pdns_ok":$( [ "$pdns_ok" = "1" ] && echo true || echo false),
"n_hosts_extra":$n_hosts,"hosts_extra":"$(jesc "$hosts_extra")","hosts_mounted":$hosts_mounted,
"n_frozen":$n_frozen,"frozen":"$(jesc "$frozen")",
"n_watchdogs":$wd_alive,"watchdogs":"$(jesc "$wd_list")",
"game_pkgs":[$game_json],
"thermal_ok":$( [ "$thermal_ok" = "1" ] && echo true || echo false),
"thermal_stopped":"$(jesc "$thermal_svcs")",
"anim":{"window":"$aw","transition":"$at","animator":"$ad"},
"private_dns":"$(jesc "$pdns")"}
EOF
cat "$TMP" > "$SCANJSON" 2>/dev/null
cat "$TMP"
