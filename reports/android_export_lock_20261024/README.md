# Android 导出文件占用问题处理记录

2026年10月24日

截图中的签名失败由目标APK文件占用引起。Windows Restart Manager报告占用应用为QQ，PID14624；对原文件进行独占打开检查返回错误32，即文件共享冲突。

原目标为 D:/new-bee/远征/Yuanzheng.apk。已保留该文件及QQ进程，没有结束用户应用。项目Android预设的默认导出位置改为 D:/new-bee/远征/exports/android/Yuanzheng-0.2.1-mobile2.apk，并在新位置完成导出。

新APK为同一工作区游戏版本0.2.1-mobile2，ARM64，调试签名。Godot导出退出码0；独立apksigner校验成功，v2与v3签名有效。普通游戏入口不含src/qa，283份正式脚本和JSON与此前已巡检的普通流程包一致。此记录只证明打包和签名成功，不关闭游戏复验报告中的未解决问题。

[导出APK](https://github.com/3311930677/new-bee/releases/download/workspace-sync-20261024/Yuanzheng-0.2.1-mobile2-arm64.apk)

[文件占用证据](lock_check.json) · [导出日志](export_console.log) · [独立签名校验](signature_verify.txt) · [包信息与代码一致性](verification.json)

截图上方Java native-access提示为警告，直接失败的异常是FileSystemException和“另一个程序正在使用此文件”。不应通过关闭签名或忽略异常交付未签名APK。

当前已经打开的Godot导出窗口可能仍缓存旧路径；再次导出时确认目标为上述新路径。若文件已被QQ预览、发送或其他程序打开，应先关闭该文件的预览或另选新文件名，避免覆盖正在使用的文件。

