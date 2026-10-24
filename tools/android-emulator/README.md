# Android 17 本地测试环境

运行环境位于被 Git 忽略的 `tools/android-sdk-mobile/`。已创建 `Yuanzheng_Android17`，Android 17 / API 37、Pixel 9 配置、1080×2424、420 dpi、4 GB 内存、4 核、WHPX 加速，使用本机 GPU 渲染。SDK 下载沿用本机代理。

启动后台模拟器：`powershell -File tools/android-emulator/Start-Android17.ps1`。需要可见窗口时手动添加 `-ShowWindow`。

ADB：`tools/android-sdk-mobile/platform-tools/adb.exe -s emulator-5554`。关闭本次虚拟设备：`adb -s emulator-5554 emu kill`。

Godot 导出预设 `Android Emulator` 使用 x86_64 和 `android_ui_audit` 特性，自动运行真实 Android 页面巡检，输出在应用私有目录 `files/android_ui_audit/`。正式 `Android` 预设仍为 ARM64，不启用巡检特性，并排除 `src/qa/`。

普通游戏流程验证包为 `reports/android_emulator_20261024/Yuanzheng-emulator.apk`；巡检包为 `Yuanzheng-android-audit.apk`。先前的普通游戏包和手机 `0.2.1-mobile2` 包中283个脚本与JSON文件已逐字节比较一致，仅原生处理器库不同，记录在 `code_equivalence.json`。

原始安卓截图、系统日志、SDK镜像校验和测试说明位于 `reports/android_emulator_20261024/`。AOSP 标准镜像经官方清单SHA-1与ZIP CRC校验后解压安装；当前只接受了本次所需的普通 Android SDK 许可。

软件 SwiftShader 后端在此机遇到 Godot GLES3 uniform 上限错误，应使用已验证的 `-gpu host`。系统覆盖切换曾触发 Android 原生 InputEventReceiver 释放崩溃，日志已保留；切换导航/挖孔配置的稳定布局检查需先停止应用，再设置系统配置并重启测试，不能将该原生异常写为已解决。

软键盘验证使用巡检脚本的 `--touch-only`：该AOSP x86内核在 `hw.keyboard=no` 下仍有PS/2键盘，引擎检测到它会跳过软键盘。脚本仅在确认模拟器后临时解绑该设备，重启可恢复。长屏与16:9下均已得到原生系统键盘画面；完整边界和未解决项见 `reports/android_emulator_20261024/README.md`。
