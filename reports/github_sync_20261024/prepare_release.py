from pathlib import Path
import json,shutil
R=Path(r"D:\new-bee");O=R/"reports/github_sync_20261024"
pre=json.loads((O/"preflight.json").read_text(encoding="utf-8"))
tag="workspace-sync-20261024";base="https://github.com/3311930677/new-bee/releases/download/"+tag+"/"
assets=pre["release_assets"]
for x in assets:x["download_url"]=base+x["asset"]
out={"repository":"3311930677/new-bee","tag":tag,"release_url":"https://github.com/3311930677/new-bee/releases/tag/"+tag,"scope":"Full workspace sync, APK build archive; outstanding issues remain open","assets":assets}
(O/"release_assets.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
(O/"SHA256SUMS.txt").write_text("".join(x["sha256"]+"  "+x["asset"]+"\n" for x in assets),encoding="utf-8")
staging=O/"upload_staging";staging.mkdir(exist_ok=True)
latest=[x for x in assets if x["asset"]=="Yuanzheng-0.2.1-mobile2-arm64.apk"][0]
shutil.copyfile(R/latest["path"],staging/latest["asset"])
for rel,old,name in [
("reports/mobile_fixes_20261024/README.md","(Yuanzheng-mobile-fixed-final.apk)","Yuanzheng-mobile-fixed-final.apk"),
("reports/mobile_rework_20261024/README.md","(Yuanzheng-0.2.1-mobile2.apk)","Yuanzheng-0.2.1-mobile2.apk"),
("reports/android_export_lock_20261024/README.md","(../../远征/exports/android/Yuanzheng-0.2.1-mobile2.apk)","Yuanzheng-0.2.1-mobile2-arm64.apk")]:
    p=R/rel;t=p.read_text(encoding="utf-8")
    assert old in t,rel
    p.write_text(t.replace(old,"("+base+name+")"),encoding="utf-8")
readme="""# 2026年10月24日全量同步

源码、游戏素材、诊断脚本、问题文档、截图、录屏和内部混音记录随main提交上传。9份APK作为同一GitHub Release附件保存，保留原相对路径、文件大小及SHA-256。

发布地址：https://github.com/3311930677/new-bee/releases/tag/workspace-sync-20261024

[APK路径与校验清单](release_assets.json) · [SHA256SUMS](SHA256SUMS.txt) · [Android全量复验与修改方案](../android_full_audit_20261024/README.md) · [签名报错处理](../android_export_lock_20261024/README.md)

当前ARM64包为Yuanzheng-0.2.1-mobile2-arm64.apk，来自远征/exports/android/Yuanzheng-0.2.1-mobile2.apk，签名已校验。其他附件是历史交付或模拟器巡检构建；x86_64诊断包不能当作手机正式交付包。

本次发布是工作区全量归档，标为预发布。系统导航遮挡、誓约文字越界、胜利音漏播等仍未解决，详见复验报告；不能据此称手机端已经全部修复。

本机Android SDK、模拟器磁盘、Godot缓存和现有忽略规则中的环境文件保持本地。已检查新增非二进制文件中的常见凭据格式，没有发现匹配项；上传过程沿用现有本机代理，不强制改写远程main历史。
"""
(O/"README.md").write_text(readme,encoding="utf-8")
notes="""此次为当前工作区全量同步和构建归档，包含源码、游戏素材、问题文档及Android实际复验证据。此版本仍有未解决问题，标为预发布。

- 手机ARM64重新打包文件：Yuanzheng-0.2.1-mobile2-arm64.apk。0.2.1-mobile2，versionCode 3，调试签名；独立签名校验通过。
- 其余8份APK保留历史构建和x86_64模拟器诊断构建，不代表问题已经全部修复。
- 已明确复现系统导航遮挡、誓约文字越界、胜利音漏播；另有方向焦点、触控范围和切换导航后退出等问题。
- 音频附件为Android内部混音；手机外放、蓝牙及ARM64真机验收仍待完成。
- APK原相对路径及SHA-256见release_assets.json与SHA256SUMS.txt。

复验报告及修改方案：reports/android_full_audit_20261024/README.md
签名文件占用处理：reports/android_export_lock_20261024/README.md
"""
(O/"release_notes.md").write_text(notes,encoding="utf-8")
print("Prepared",len(assets),"APK assets and download manifests")

