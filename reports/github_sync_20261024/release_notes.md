此次为当前工作区全量同步和构建归档，包含源码、游戏素材、问题文档及Android实际复验证据。此版本仍有未解决问题，标为预发布。

- 手机ARM64重新打包文件：Yuanzheng-0.2.1-mobile2-arm64.apk。0.2.1-mobile2，versionCode 3，调试签名；独立签名校验通过。
- 其余8份APK保留历史构建和x86_64模拟器诊断构建，不代表问题已经全部修复。
- 已明确复现系统导航遮挡、誓约文字越界、胜利音漏播；另有方向焦点、触控范围和切换导航后退出等问题。
- 音频附件为Android内部混音；手机外放、蓝牙及ARM64真机验收仍待完成。
- APK原相对路径及SHA-256见release_assets.json与SHA256SUMS.txt。

复验报告及修改方案：reports/android_full_audit_20261024/README.md
签名文件占用处理：reports/android_export_lock_20261024/README.md
