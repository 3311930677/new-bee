from pathlib import Path
import json
R=Path(r"D:\new-bee");O=R/"reports/github_sync_20261024"
p=O/"release_assets.json";m=json.loads(p.read_text(encoding="utf-8"))
v=json.loads((O/"apk_archive_verification.json").read_text(encoding="utf-8"))
base="https://github.com/3311930677/new-bee/releases/download/"+m["tag"]+"/"
archive_url=base+v["archive"]
for a in m["assets"]:
    a["archive_member"]=a["path"]
    a["download_url"]=base+a["asset"] if a["asset"]=="Yuanzheng-0.2.1-mobile2-arm64.apk" else archive_url
    a["delivery"]="standalone APK and full archive" if a["asset"]=="Yuanzheng-0.2.1-mobile2-arm64.apk" else "full archive member"
m["archive"]={**{k:v[k] for k in ["archive","bytes","sha256","format"]},"download_url":archive_url,"contains":"all 9 APKs at original relative paths plus available idsig sidecars"}
p.write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding="utf-8")
latest=next(a for a in m["assets"] if a["asset"]=="Yuanzheng-0.2.1-mobile2-arm64.apk")
delivery={"repository":m["repository"],"tag":m["tag"],"release_id":422468629,"assets":[{"asset":latest["asset"],"path":"reports/github_sync_20261024/upload_staging/"+latest["asset"],"bytes":latest["bytes"],"sha256":latest["sha256"]},{"asset":v["archive"],"path":"reports/github_sync_20261024/upload_staging/"+v["archive"],"bytes":v["bytes"],"sha256":v["sha256"]}]}
(O/"delivery_assets.json").write_text(json.dumps(delivery,ensure_ascii=False,indent=2),encoding="utf-8")
(O/"ARCHIVE_SHA256SUMS.txt").write_text(v["sha256"]+"  "+v["archive"]+"\n",encoding="utf-8")
for rel,old in [("reports/mobile_fixes_20261024/README.md","Yuanzheng-mobile-fixed-final.apk"),("reports/mobile_rework_20261024/README.md","Yuanzheng-0.2.1-mobile2.apk")]:
    f=R/rel;t=f.read_text(encoding="utf-8")
    t=t.replace("("+base+old+")","("+archive_url+")")
    if "历史构建下载说明" not in t:t+="\n\n历史构建下载说明：上述安装包包含于完整APK归档，解压后按本目录相对路径取得原文件；当前手机包请见全量同步清单。归档内全部9份APK已逐一验证SHA-256。\n"
    f.write_text(t,encoding="utf-8")
readme="""# 2026年10月24日全量同步

源码、游戏素材、诊断脚本、问题文档、截图、录屏和内部混音记录随main提交上传。9份APK经无损压缩后放入同一GitHub预发布附件，当前手机ARM64包另提供直接下载。

发布地址：https://github.com/3311930677/new-bee/releases/tag/workspace-sync-20261024

[当前手机ARM64 APK](https://github.com/3311930677/new-bee/releases/download/workspace-sync-20261024/Yuanzheng-0.2.1-mobile2-arm64.apk) · [全部9份APK归档](https://github.com/3311930677/new-bee/releases/download/workspace-sync-20261024/Yuanzheng-apk-archive-20261024.tar.zst)

[APK路径与校验清单](release_assets.json) · [原APK校验值](SHA256SUMS.txt) · [归档校验值](ARCHIVE_SHA256SUMS.txt) · [归档内9份APK逐一校验记录](apk_archive_verification.json)

[Android全量复验与修改方案](../android_full_audit_20261024/README.md) · [签名报错处理](../android_export_lock_20261024/README.md)

归档为标准tar.zst格式，可用支持Zstandard的归档工具解压。文件按原相对路径保存，包含可用的idsig伴随文件。9份APK原始内容合计6565503106字节，归档890685112字节；从归档流逐一读取并计算SHA-256，全部与原文件一致。

当前ARM64包为Yuanzheng-0.2.1-mobile2-arm64.apk，来自远征/exports/android/Yuanzheng-0.2.1-mobile2.apk，签名已校验。其余为历史交付或模拟器巡检构建；x86_64诊断包用于模拟器。

本次发布是工作区全量归档，标为预发布。系统导航遮挡、誓约文字越界、胜利音漏播等仍未解决，详见复验报告；不能据此称手机端已经全部修复。

本机Android SDK、模拟器磁盘、Godot缓存和现有忽略规则中的环境文件保持本地。已检查新增非二进制文件中的常见凭据格式，没有发现匹配项；上传过程沿用本机代理，不强制改写远程main历史。
"""
(O/"README.md").write_text(readme,encoding="utf-8")
notes="""此次为当前工作区全量同步和构建归档，包含源码、游戏素材、问题文档及Android实际复验证据。此版本仍有未解决问题，标为预发布。

- 直接安装手机包：Yuanzheng-0.2.1-mobile2-arm64.apk。0.2.1-mobile2，versionCode 3，ARM64，调试签名；独立签名校验通过。
- 完整归档：Yuanzheng-apk-archive-20261024.tar.zst。包含9份APK原文件与可用idsig，按原相对路径保存；逐一解压流校验SHA-256，全部一致。
- 归档中的历史交付包和x86_64模拟器诊断包不代表问题已经全部修复。
- 已明确复现系统导航遮挡、誓约文字越界、胜利音漏播；另有方向焦点、触控范围和切换导航后退出问题。
- 手机外放、蓝牙及ARM64真机验收仍待完成。
- 校验与原路径：release_assets.json、SHA256SUMS.txt及ARCHIVE_SHA256SUMS.txt。

复验报告及修改方案：reports/android_full_audit_20261024/README.md
签名文件占用处理：reports/android_export_lock_20261024/README.md
"""
(O/"release_notes.md").write_text(notes,encoding="utf-8")
print("Prepared 2 binary delivery assets; all 9 APK payloads retained")

