# 2026年10月24日全量同步

源码、游戏素材、诊断脚本、问题文档、截图、录屏和内部混音记录随main提交上传。9份APK作为同一GitHub Release附件保存，保留原相对路径、文件大小及SHA-256。

发布地址：https://github.com/3311930677/new-bee/releases/tag/workspace-sync-20261024

[APK路径与校验清单](release_assets.json) · [SHA256SUMS](SHA256SUMS.txt) · [Android全量复验与修改方案](../android_full_audit_20261024/README.md) · [签名报错处理](../android_export_lock_20261024/README.md)

当前ARM64包为Yuanzheng-0.2.1-mobile2-arm64.apk，来自远征/exports/android/Yuanzheng-0.2.1-mobile2.apk，签名已校验。其他附件是历史交付或模拟器巡检构建；x86_64诊断包不能当作手机正式交付包。

本次发布是工作区全量归档，标为预发布。系统导航遮挡、誓约文字越界、胜利音漏播等仍未解决，详见复验报告；不能据此称手机端已经全部修复。

本机Android SDK、模拟器磁盘、Godot缓存和现有忽略规则中的环境文件保持本地。已检查新增非二进制文件中的常见凭据格式，没有发现匹配项；上传过程沿用现有本机代理，不强制改写远程main历史。
