# 手机端修改记录（验收未通过）

用户复测反馈问题基本仍存在，上一轮完成结论已撤回。以下安装包保留用于复现与对照，不能作为已验收修复包。

本目录唯一交付安装包为 [Yuanzheng-mobile-fixed-final.apk](https://github.com/3311930677/new-bee/releases/download/workspace-sync-20261024/Yuanzheng-mobile-fixed-final.apk)，调试签名、ARM64，约694 MiB。

逐项修改、回归结果和真机复测范围见 [修复交付记录](../../远征/docs/plans/2026-10-24-mobile-issues-fixes-delivery.md)。

最终包核验结果见 [package_verification.json](package_verification.json)，可使用 `verify_package.py` 对当前项目的导入缓存及最终APK重新核对。

修复前工作区差异保存在 `baseline.patch`，文件哈希保存在 `baseline_hashes.json`；原有战斗、天赋、教程修改已保留。日志及界面检查合成图保留在本目录，实际截图位于 `远征/shots/mobile_fixes_20261024/`。

没有连接Android设备，外放、耳机和蓝牙试听、系统栏行为、桌面主题图标及覆盖安装仍需真机复测。
