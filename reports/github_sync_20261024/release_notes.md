此次为当前工作区全量同步和构建归档，包含源码、游戏素材、问题文档及Android实际复验证据。此版本仍有未解决问题，标为预发布。

- 直接安装手机包：Yuanzheng-0.2.1-mobile2-arm64.apk。0.2.1-mobile2，versionCode 3，ARM64，调试签名；独立签名校验通过。
- 完整归档：Yuanzheng-apk-archive-20261024.tar.zst。包含9份APK原文件与可用idsig，按原相对路径保存；逐一解压流校验SHA-256，全部一致。
- 归档中的历史交付包和x86_64模拟器诊断包不代表问题已经全部修复。
- 已明确复现系统导航遮挡、誓约文字越界、胜利音漏播；另有方向焦点、触控范围和切换导航后退出问题。
- 手机外放、蓝牙及ARM64真机验收仍待完成。
- 校验与原路径：release_assets.json、SHA256SUMS.txt及ARCHIVE_SHA256SUMS.txt。

复验报告及修改方案：reports/android_full_audit_20261024/README.md
签名文件占用处理：reports/android_export_lock_20261024/README.md
