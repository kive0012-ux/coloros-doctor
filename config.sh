#!/system/bin/sh
# =============================================================
#  修复模块配置（本模块自身不做任何系统修改，此文件只影响修复行为）
# =============================================================

# 开机后自动执行一次"安全修复"（默认关，请在 WebUI 手动体检+修复）
AUTO_FIX_ON_BOOT=false

# 出厂即禁用属正常，修复时不启用的包（空格分隔，可自行追加）
# 一加 Ace3 (PJE110) 上属正常状态的禁用包（出厂即禁用或用户自行禁用，修复时绝不启用）
KEEP_DISABLED="com.android.egg com.android.cts.ctsshim com.android.cts.priv.ctsshim \
com.android.devicelockcontroller com.android.stk com.coloros.findmyphone \
com.google.android.gms com.oplus.customize.coreapp com.oplus.ocar com.oplus.sau"

# 游戏/HyperBoost 相关包：修复时重点确保启用并解除后台限制
GAME_PKGS="com.coloros.gamespace com.oplus.gamespace com.oneplus.gamespace com.oppo.gamespace com.coloros.gameassistant com.oplus.games com.coloros.assistants com.heytap.assistant com.coloros.smartsidebar"

# 云控框架包（游戏助手依赖，确保启用）
CLOUD_PKGS="com.oplus.atlas com.oppo.atlas com.oplus.cota com.coloros.cota com.oplus.cosa com.coloros.ocs com.oplus.ocs com.oppo.cota com.heytap.cota"

# 旧优化模块 bind-mount 冷冻过的目录（修复时解冻）
CLOUD_DIRS="/data/oplus/atlas /data/oplus/cota /data/oplus/cosa /data/oplus/ocs /data/system/cota /data/system/atlas /data/system/cosa"

# 已知旧模块的看门狗/守护标记文件
WATCHDOG_MARKS="/dev/.gms_intl_opt_wd /dev/.gms_fcm_opt_wd /dev/.ufcs_bk_loop /dev/.spk_audio_dry"

# 旧优化模块识别关键字（匹配目录名或 module.prop 的 id/name）
OLD_MODULE_PAT="gms-intl-optimizer|gms-fcm-oppo|GMS-FCM-OPPO|gms_fcm_optimizer"

# =============================================================
#  一加 Ace3 (PJE110) 设备身份
#  真值来源 = 手机只读分区 build.prop（与本机固件版本完全一致，最可靠）
#  下面白名单来自公开硬件数据库核对（brand/manufacturer/model/product），
#  仅用于"发现被改成其它手机(如 Google Pixel)"的判定，绝不作为写入值。
# =============================================================
STOCK_ID_BRAND="OnePlus"
STOCK_ID_MODEL="PJE110"
STOCK_ID_MANUFACTURER="OnePlus"

# 指纹/机型属性清单：修复时逐项从分区真值钉回（分区没有的一律不动、绝不删除）
STOCK_PROP_KEYS="ro.build.fingerprint ro.product.brand ro.product.manufacturer \
ro.product.model ro.product.device ro.product.name ro.product.marketname \
ro.product.system.brand ro.product.system.model ro.product.system.device \
ro.product.vendor.brand ro.product.vendor.model ro.product.vendor.device \
ro.product.product.brand ro.product.product.model \
ro.product.odm.brand ro.product.odm.model ro.product.odm.device \
ro.product.system_ext.brand ro.product.system_ext.model"
