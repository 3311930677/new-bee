# 游戏 UI 工具安装记录

安装日期：2026-10-05。

## 已安装组件

- Godot MCP：社区项目 https://github.com/blentz/godot-mcp ，检出提交 `735bdc9c98806e5ecdd05b819bc4ac461d9af935`。工具目录 `D:\new-bee\tools\godot-mcp`，50 个工具。
- Figma：插件目录确认官方 Figma, Inc. 插件已经安装且启用。未重复注册远程 MCP；尚未读取具体设计文件。
- Godot UI Skill：安装 `gamedev-skills/awesome-gamedev-agent-skills` 的 `skills/godot/godot-ui-control`，位置 `C:\Users\tsz\.codex\skills\godot-ui-control`，包含布局和 Theme 参考。用户提供的 “Godot UI Design Skill” 名称无法唯一定位，本次选用上述面向 Godot 4.7 的对应技能。

## 连接配置

Codex 全局配置中注册 `godot` STDIO 服务，使用 Node.js 和 `tools/godot-mcp/launch.mjs`。

- Godot：`D:\new-bee\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe`
- 默认项目：`D:\new-bee\远征`
- 编辑器插件：`远征/addons/godot_mcp/plugin.cfg`，已在 `project.godot` 启用。
- 使用编辑器实时工具时，需要打开此项目的 Godot 编辑器。验证用的编辑器进程已关闭。

技能从下一条消息可用。若当前聊天仍未加载 Godot 工具，在 Codex 设置的 MCP 服务列表重启 `godot`，再开新聊天。

## 本机兼容处理

上游启动入口直接比较 `file://` 字符串，Windows 路径无法匹配。`launch.mjs` 显式调用上游 `main()`，不修改启动主体。

上游窗口检测只识别 Linux `DISPLAY` / `WAYLAND_DISPLAY`，本地为 Windows 放行原生窗口运行；实际运行和截图仍检查引擎返回的错误。相关 11 项检测测试通过。升级上游后需要检查是否仍需保留此本地修改，重新构建。

## 已验证

- MCP 握手和 50 个工具列表。
- 读取 `src/ui/Title.tscn` 的 Control 节点。
- 节点修改的 dry_run 差异预览，未应用示例修改。
- 游戏无窗口运行 20 帧，无错误。
- 游戏 Windows 窗口运行 10 帧，无错误。
- `editor_state` 返回实际 Godot 编辑器状态。
- 标题场景截图成功，480×800，非空白：`远征/shots/mcp-install-check/title.png`。

本次安装未进行界面重设计。后续可以直接优化项目 UI；使用 Figma 参考需提供有访问权限的具体设计链接。

## 停用

Godot 编辑器的项目设置 → 插件中关闭 `godot_mcp`；在 Codex 设置 → MCP 服务中关闭 `godot`。Skill 与 Figma 可独立保留。
