# 2026年10月24日全量同步

源码、游戏素材、诊断脚本、问题文档、截图、录屏和内部混音记录随main提交上传。9份APK经无损压缩后放入同一GitHub预发布附件，当前手机ARM64包另提供直接下载。

发布地址：https://github.com/3311930677/new-bee/releases/tag/workspace-sync-20261024

[当前手机ARM64 APK](https://github.com/3311930677/new-bee/releases/download/workspace-sync-20261024/Yuanzheng-0.2.1-mobile2-arm64.apk) · [全部9份APK归档](https://github.com/3311930677/new-bee/releases/download/workspace-sync-20261024/Yuanzheng-apk-archive-20261024.tar.zst)

[APK路径与校验清单](release_assets.json) · [原APK校验值](SHA256SUMS.txt) · [归档校验值](ARCHIVE_SHA256SUMS.txt) · [归档内9份APK逐一校验记录](apk_archive_verification.json)

[Android全量复验与修改方案](../android_full_audit_20261024/README.md) · [签名报错处理](../android_export_lock_20261024/README.md)

归档为标准tar.zst格式，可用支持Zstandard的归档工具解压。文件按原相对路径保存，包含可用的idsig伴随文件。9份APK原始内容合计6565503106字节，归档890685112字节；从归档流逐一读取并计算SHA-256，全部与原文件一致。

当前ARM64包为Yuanzheng-0.2.1-mobile2-arm64.apk，来自远征/exports/android/Yuanzheng-0.2.1-mobile2.apk，签名已校验。其余为历史交付或模拟器巡检构建；x86_64诊断包用于模拟器。

本次发布是工作区全量归档，标为预发布。系统导航遮挡、誓约文字越界、胜利音漏播等仍未解决，详见复验报告；不能据此称手机端已经全部修复。

本机Android SDK、模拟器磁盘、Godot缓存和现有忽略规则中的环境文件保持本地。已检查新增非二进制文件中的常见凭据格式，没有发现匹配项；上传过程沿用本机代理，不强制改写远程main历史。
