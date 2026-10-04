# 主体整合本地构建 · 2026-10-04

版本 0.2.0，Godot 4.7.2 stable（ed1daf0bf）。产物保存在本地 `exports/`，不提交大文件、调试密钥、日志或玩家存档。

| 文件 | 字节 | SHA256 |
|---|---:|---|
| `windows/Yuanzheng.exe` | 109,156,864 | `b5aba1b80a01eee08dfa46b72800a2ff6009f86e94b615dedae78a0bc9a97f90` |
| `windows/Yuanzheng.pck` | 426,686,340 | `91227ddc8dcf42f28277751a791ef6d6573f1a82cd3049d9bfdc45a6d9a10775` |
| `android/Yuanzheng-debug.apk` | 454,808,315 | `d9907da9f7c20f3bba28ea55a57f7dca90f06dc532e0e4bb6a916a02ed44c572` |

Windows 启动时同目录保留 exe 与 pck。Android 为 ARM64、API 24 起、目标 API 36、包名 `org.yuanzheng.singleplayer` 的调试签名包；不用于商店发布。

`verify_export_packages.py` 对 Windows PCK 的全部条目逐项校验，安卓 ZIP 全量 CRC 校验并检查唯一 ARM64 架构、生产表及排除工作文件。最终导出日志 `export_windows69_final.log`、`export_android69_final.log`；最终签名、包信息和启动记录另存 `tools/_logs/`。

玩法验证包括 69 项回归、回归器 11 项故障注入、四职业全主线真实输入链、双职业十二条新增支线 A/B 恢复与单次领奖、两骑 64 组移动截图。真实输入链中的满包、败北及测试场景资源夹具边界详见主体推进记录，自动验证不能替代人工体验。

安全区已接入固定面板、地图 HUD、登录、营帐、战斗与城内面板。屏幕缩放和模拟缺口通过自动检查；当前没有安卓连接设备，未宣称真机通过。三副本部分美术仍为程序场景物件，人工音画、手感及回访演出继续推进。根证书提示与登记的退出资源诊断仍存在。
