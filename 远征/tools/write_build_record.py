"""Record local delivery hashes; do not add distributables to Git."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COUNT = int(sys.argv[1]) if len(sys.argv)>1 else 69
files = ['windows/Yuanzheng.exe', 'windows/Yuanzheng.pck', 'android/Yuanzheng-debug.apk']
rows = []
for name in files:
    path = ROOT / 'exports' / name
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            digest.update(block)
    rows.append({'file': name, 'bytes': path.stat().st_size, 'sha256': digest.hexdigest()})
(ROOT / f'tools/_logs/build_hashes{COUNT}_final.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
instructions = '''远征 0.2.0 · 本地主体整合试玩版

Windows：打开 windows/Yuanzheng.exe。Yuanzheng.pck 必须与程序保持在同一目录。
Android：android/Yuanzheng-debug.apk 为 ARM64 调试签名安装包，最低 Android 7.0（API 24）。
这是本地试玩构建，尚未在安卓真机上验证，不是商店发布包。

按界面按钮创建或继续角色，进入主世界沿当前任务推进；地图左下摇杆移动，靠近人物或目标自动互动。
历练是独立模式，主线、支线、委托和合约分别保存进度。退出后可继续，但请勿同时启动多个实例写同一存档。
首次试玩建议新建角色。验证工具使用隔离存档，没有改写已有玩家存档。

已完成四职业36步主线自动真实输入回放、十二新增支线双职业回放、跨进程恢复及两坐骑64组移动渲染。
人工手感、音景听感、安卓触控及异形屏仍待设备验收。已知引擎退出资源诊断未修复。
完整开发进度和验证边界见 docs/plans/2026-10-04-game-body-progress.md。
'''
(ROOT / 'exports/试玩说明.txt').write_text(instructions, encoding='utf-8-sig')
table = '\n'.join(f"| `{r['file']}` | {r['bytes']:,} | `{r['sha256']}` |" for r in rows)
document = f'''# 主体整合本地构建 · 2026-10-04

版本 0.2.0，Godot 4.7.2 stable（ed1daf0bf）。产物保存在本地 `exports/`，不提交大文件、调试密钥、日志或玩家存档。

| 文件 | 字节 | SHA256 |
|---|---:|---|
{table}

Windows 启动时同目录保留 exe 与 pck。Android 为 ARM64、API 24 起、目标 API 36、包名 `org.yuanzheng.singleplayer` 的调试签名包；不用于商店发布。

`verify_export_packages.py` 对 Windows PCK 的全部条目逐项校验，安卓 ZIP 全量 CRC 校验并检查唯一 ARM64 架构、生产表及排除工作文件。最终导出日志 `export_windows{COUNT}_final.log`、`export_android{COUNT}_final.log`；最终签名、包信息和启动记录另存 `tools/_logs/`。

玩法验证包括 {COUNT} 项回归、回归器 11 项故障注入、四职业全主线真实输入链、双职业十二条新增支线 A/B 恢复与单次领奖、两骑 64 组移动截图。真实输入链中的满包、败北及测试场景资源夹具边界详见主体推进记录，自动验证不能替代人工体验。

安全区已接入固定面板、地图 HUD、登录、营帐、战斗与城内面板。屏幕缩放和模拟缺口通过自动检查；当前没有安卓连接设备，未宣称真机通过。三副本部分美术仍为程序场景物件，人工音画、手感及回访演出继续推进。根证书提示与登记的退出资源诊断仍存在。
'''
(ROOT / 'docs/plans/2026-10-04-build-verification.md').write_text(document, encoding='utf-8')
for name in ['assets/fonts/mashanzheng-OFL.txt', 'assets/fonts/zcoolqingkehuangyou-OFL.txt',
             'tools/VerifyRunResume.gd', 'tools/build_world_commissions.py']:
    path = ROOT / name
    text = '\n'.join(line.rstrip() for line in path.read_text(encoding='utf-8').splitlines()).rstrip() + '\n'
    path.write_text(text, encoding='utf-8')
print('BUILD_RECORD_READY', len(rows), 'artifacts')
