#!/system/bin/sh
# =============================================================
#  安装钩子：只做环境检测与提示，绝不修改系统任何状态。
# =============================================================
MODPATH=${MODPATH:-/data/adb/modules/zzz-coloros-doctor}

ui_print " "
ui_print "********************************"
ui_print "  ColorOS 系统体检修复 · v1.0.2"
ui_print "  本模块只诊断与修复，自身零系统修改"
ui_print "********************************"

# 检测旧优化模块（安装阶段只读探测）
FOUND=""
for base in /data/adb/modules /data/adb/ksu/modules; do
  [ -d "$base" ] || continue
  for d in "$base"/*; do
    [ -d "$d" ] || continue
    case "$(basename "$d")" in
      zzz-coloros-doctor|coloros-doctor) continue;;
    esac
    echo "$(basename "$d")" | grep -qiE 'gms-intl-optimizer|gms-fcm-oppo|GMS-FCM-OPPO' && FOUND="$FOUND $(basename "$d")"
  done
done

if [ -n "$FOUND" ]; then
  ui_print " "
  ui_print "⚠ 检测到旧优化模块残留：$FOUND"
  ui_print "  建议刷入后打开 WebUI 执行「一键体检+修复」，"
  ui_print "  修复会自动停用其看门狗并隔离旧模块目录。"
else
  ui_print " "
  ui_print "未检测到旧优化模块目录（若曾手动删除，属性/组件残留仍可修复）。"
fi

ui_print " "
ui_print "✔ 安装完成。重启后打开管理器 WebUI →"
ui_print "  ① 点「开始体检」查看问题清单"
ui_print "  ② 点「一键修复」恢复系统组件"
ui_print "  ③ 修复完成后重启一次彻底生效"
ui_print " "
