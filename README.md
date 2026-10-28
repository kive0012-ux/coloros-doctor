# ColorOS 系统体检修复 (coloros-doctor)

针对「ColorOS 日用优化」系列模块造成的系统损伤的**专项体检与修复工具**。
典型症状：游戏助手帧率显示 0 帧、系统组件被禁用、指纹被伪造、hosts 被加域名屏蔽、目录被冷冻。

> 本模块自身**零系统修改**：不写属性、不改 hosts、不禁用任何 App。
> 所有修复动作仅在 WebUI 点「一键修复」时执行，且按旧模块备份清单**精确还原原值**，绝不臆造。

## 功能

| 分区 | 体检项 | 修复动作 |
|---|---|---|
| 被禁用组件 | `pm list packages -d` 全量扫描 + 游戏助手/云控框架状态 | 逐个 `pm enable`（出厂黑名单除外）+ 解除后台限制 |
| 属性残留 | 旧模块 `prop_backup.list` / `dolby_backup.list` 待还原数、指纹比对 | 按备份精确还原；指纹/机型从出厂 build.prop 钉回真值 |
| 网络与 hosts | /system/etc/hosts 多余条目、模块挂载、冷冻目录 | 卸载挂载 + 重建原版 hosts（模块自带 stock hosts 兜底）+ umount 解冻 |
| 旧模块与进程 | 看门狗 pid、UFCS 进程、温控服务状态 | kill 进程 + 清标记 + `start` 恢复温控 + 隔离旧模块目录到 `quarantine/` |

## 修复不碰的东西（安全承诺）

- 不 `pm disable` 任何包
- 不删除任何原生属性（无备份记录的 persist 属性一律不动）
- 不覆盖 `/vendor/etc/dolby/dax-default.xml` 等出厂文件
- 隔离旧模块用 `mv` 到 `quarantine/`，备份数据保留可找回

## 使用

1. KernelSU / APatch / Magisk 刷入本模块，重启
2. 打开管理器 WebUI →「开始体检」→ 查看健康分与问题清单
3. 「一键修复」→ 等待完成 → **重启一次**彻底生效
4. 重启后再次「开始体检」验证健康分恢复 100

## 卸载

直接卸载即可。隔离的旧模块数据保留在 `/data/adb/modules/zzz-coloros-doctor/quarantine/`（如确认不再需要可手动删除）。

## 在线更新

模块带 `updateJson`（GitHub raw），KSU/APatch 管理器可检测新版本。
