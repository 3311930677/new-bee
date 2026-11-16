# 《远征》在线服务

本目录实现 Go + PostgreSQL 持久化入口，以及不加载单机 autoload 的独立 Godot 权威世界/战斗进程。当前已连接账号、在线角色、昭元边城最小同屏、指令战斗和一次性奖励。完整范围与 L0–L6 证据见 [实施台账](../docs/plans/2026-11-16-online-implementation-progress.md)；移动预测/AOI、社交、合作副本和多人竞技仍待开发。

## Windows 本地运行

从仓库根执行；所有工具、数据库、日志与本地凭据留在被忽略的工作区目录。

```powershell
# 正常继承当前代理环境；仅在环境变量失效时显式传本机实际可用代理。
python 远征/server/tools/bootstrap_runtime.py
python 远征/server/tools/dev.py init
python 远征/server/tools/dev.py deps
python 远征/server/tools/dev.py test
python 远征/server/tools/dev.py build
# 同时启动私有 Godot 世界进程和 Go 入口；Ctrl+C 清理这两个进程。
python 远征/server/tools/run_stack.py --godot <Godot-4.7.2路径>
```

`--proxy http://127.0.0.1:<实际端口>` 可用于 bootstrap、deps、build、test，不修改全局代理。数据库只绑定 `127.0.0.1:55432`。`run_stack.py` 选择可用回环端口，在终端显示完整 API 地址，客户端填写该地址。退出服务不停止数据库；需要时执行 `python 远征/server/tools/dev.py stop`。`status` 检查这个工作区自己的实例，不操作系统服务。`dev.py run` 仍可单独启动仅账号/角色 API，默认端口 18080，清单不会宣称有世界/战斗能力。

客户端标题页点击“进入联机”，连接工具显示的地址，注册/登录并创建和选择在线角色，再点击“进入昭元边城”。方向键或屏幕下方按钮移动，靠近城南野狼后挑战；战斗中使用攻/技/物/逃。首胜奖励金币 10、阅历 5，确认结算回城。昵称、职业可以从单机角色预览；在线角色拥有独立 ID、钱包和进度。本阶段所有令牌只留客户端内存，退出后重新登录，不保存密码或刷新令牌。

注册时保存一次性恢复码；忘记密码可在登录页使用，找回后旧会话退出，原角色与资产保留。账号安全页验证当前密码可更新恢复码并查看站内安全记录。恢复码默认遮挡，只在内存保留，由玩家点击复制/显示；密码和恢复码都丢失时，当前版本不能自动证明账号归属。角色列表的“管理”提供昵称确认删除和七天内恢复；重名时给三项候选昵称。

## 部署边界

生产部署从环境变量读取 `YUANZHENG_DATABASE_URL`，禁止把凭据写入仓库或打进客户端。独立机器需要通过 PostgreSQL 的角色/网络权限限制数据库访问。API 监听非回环地址时必须配置 `--tls-cert / --tls-key`，或明确启用 `--behind-tls-proxy` 并由可信入口终止 TLS；应用不信任任意 `X-Forwarded-For`。

```powershell
# 在 server 目录，连接已准备的数据库后运行已构建服务。
# YUANZHENG_DATABASE_URL 由部署环境提供；不要放入命令行或日志。
.\bin\gateway.exe --game-root .. --listen 127.0.0.1:18080
# 启用世界时另外启动 room-project/RoomHost.gd，双方由环境提供同一
# YUANZHENG_ROOM_SECRET，网关附 --authority-address 127.0.0.1:<私有端口>。
```

首次启动应用会在事务中执行嵌入式迁移；并行部署由数据库锁串行化，已执行迁移的 SHA256 变化会阻止启动。`--startup-timeout` 默认 `90s`，可设 `1s`–`10m`，仅用于初始连接、迁移和权威进程校验，日志记录迁移实际耗时；不改变 HTTP 或战斗指令期限。正式迁移只新增，不修改已上线 SQL。本次没有对任何已有系统数据库执行迁移。

## 测试范围

`dev.py test` 使用独立 `yuanzheng_test` 数据库；每个测试再创建随机 schema，结束时只删除自身 schema。缺少测试连接时会失败，不能输出跳过后全绿。

覆盖账号密码哈希、换机撤销、令牌轮换、角色所有权/上限、非法物资/版本、并发重复创建、持久化回执、频道容量/租约/移动权限，以及账本故障后的回滚、并发重试、一次性奖励。事务测试使用真实 PostgreSQL、脚本化权威对端隔离数据库故障；不能用它代替下述真实 Godot 端到端验证。

客户端隔离验证已登记在 `tools/run_regression.ps1` 的 `VerifyOnlineBoundary`；真实 HTTP + Godot 双端验证另行运行。单机回归不依赖在线服务运行。

```powershell
python 远征/server/tools/verify_clients.py --godot <Godot-4.7.2路径> --capture
python 远征/server/tools/verify_room.py --godot <Godot-4.7.2路径>
python 远征/server/tools/verify_world.py --godot <Godot-4.7.2路径> --capture
python 远征/server/tools/verify_accounts.py --godot <Godot-4.7.2路径> --capture
```

第二条从当前共享战斗源码和全部 JSON 构建 `.local/room-project`，导入并检查脚本；真实 Go 签名客户端连接进程，检查签名、nonce、顺序、服务器时钟、重放、已提交状态校验、未提交输入/时钟回滚和移动判定。原单调时钟接口保留作私有探针；正式战斗同步由网关根据持久化时钟与输入驱动。

第三条启动真实 PostgreSQL、Go 网关、Godot 权威进程和两个独立 Godot 客户端，同城移动并各自完成真实战斗。在胜利入账时通过数据库触发器注入故障，按安全日志中的 SQLSTATE 核对两个数据库异常，并核对无半笔奖励/claim/输入，随后重启网关和战斗进程，再让客户端以原请求标识重试；独立查询数据库确认各自仅发奖一次。另验证重复回执、重登录后恢复未确认结算、确认回城、退出撤销会话及单机数据哈希。只清理随机测试 schema 和自有进程。

这仍是桌面本机证据，不能替代双手机、广域网、24 人压力、合作副本、PVP 或运营验收。`VerifyOnlineWorld` 与 `VerifyOnlineHttp` 需要外部真实服务与隔离测试身份，由对应 Python 工具启动；常规单机回归不依赖这些服务。

第四条用真实账号页面按钮及 Go/PostgreSQL 验证注册恢复码遮挡、重名建议、删除确认/取消、恢复原角色、旧恢复码拒绝、新密码找回、站内记录确认和单机隔离。截图只保存遮挡状态，脚本扫描日志中的恢复码模式并拒绝把泄漏样本算作通过。三个客户端联测工具均过滤服务端数据库连接/私有密钥等环境变量，Godot 客户端还在运行时检查这些变量不存在。

验收记录保存在 `.local/verification`；Go 测试的完整 JSON 在 `go-integration.jsonl`。首批证据在仓库根 `reports/online_20261116`；最新账号管理与双端重验在 [20261117/account-management](../../reports/online_20261117/account-management/README.md)，完整单机回归另行归档。此前性能/传输失败记录继续保留，不通过覆盖文件追认成功。

协议：[online-protocol-v1.md](../docs/online-protocol-v1.md)。依赖 API 依据为 [pgx 官方文档](https://pkg.go.dev/github.com/jackc/pgx/v5)、[Go bcrypt 文档](https://pkg.go.dev/golang.org/x/crypto/bcrypt)。便携 PostgreSQL 来源由 [PostgreSQL 官方 Windows 下载页](https://www.postgresql.org/download/windows/)指向 EDB。
