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

客户端标题页点击“进入联机”，连接工具显示的地址，注册/登录并创建和选择在线角色，再点击“进入昭元边城”。方向键或屏幕下方按钮移动，靠近城南野狼后挑战；战斗中使用攻/技/物/逃。首胜奖励金币 10、阅历 5，确认结算回城。创建时可选择未指定/男/女，以及随职业或四种批准职业头像；头像选择不改变战斗职业。昵称、职业、性别和批准头像可以从单机角色预览，本机自选图片回退为职业头像并在提交前说明，不读取或上传图片。在线角色拥有独立 ID、钱包和进度。本阶段所有令牌只留客户端内存，退出后重新登录，不保存密码或刷新令牌。城镇“同行名片”可查看同频道角色的公开身份，尚不包含好友、聊天或组队。

注册时保存一次性恢复码；忘记密码可在登录页使用，找回后旧会话退出，原角色与资产保留。账号安全页验证当前密码可更新恢复码并查看站内安全记录。恢复码默认遮挡，只在内存保留，由玩家点击复制/显示；密码和恢复码都丢失时，当前版本不能自动证明账号归属。角色列表的“管理”提供昵称确认删除和七天内恢复；重名时给三项候选昵称。

## 部署边界

生产部署从环境变量读取 `YUANZHENG_DATABASE_URL`，禁止把凭据写入仓库或打进客户端。独立机器需要通过 PostgreSQL 的角色/网络权限限制数据库访问。API 监听非回环地址时必须配置完整的 `--tls-cert / --tls-key`；同机反向代理可启用 `--behind-tls-proxy`，其明文后端仍只能绑定字面回环地址。应用不信任任意 `X-Forwarded-For`。

```powershell
# 在 server 目录，连接已准备的数据库后运行已构建服务。
# YUANZHENG_DATABASE_URL 由部署环境提供；不要放入命令行或日志。
.\bin\gateway.exe --game-root .. --listen 127.0.0.1:18080
# 启用世界时另外启动 room-project/RoomHost.gd，双方由环境提供同一
# YUANZHENG_ROOM_SECRET，网关附 --authority-address 127.0.0.1:<私有端口>。
```

权威进程只接收自己的房间签名密钥，不接收数据库、管理令牌或 TLS 私钥等环境。`run_stack.py` 按进程过滤这些值；手工部署也需分开服务环境。权威进程启动时发现持久化/管理凭据会拒绝运行，并且不回显值。

首次启动应用会在事务中执行嵌入式迁移；并行部署由数据库锁串行化，已执行迁移的 SHA256 变化会阻止启动。`--startup-timeout` 默认 `90s`，可设 `1s`–`10m`，仅用于初始连接、迁移和权威进程校验，日志记录迁移实际耗时；不改变 HTTP 或战斗指令期限。正式迁移只新增，不修改已上线 SQL。本次没有对任何已有系统数据库执行迁移。

独立部署先用离线 `dbops.exe` 给新空库配置 migrator/runtime/backup 三种身份、执行迁移和明确授权，再让网关使用 `--migration-mode check --require-restricted-database`。该模式只读检查迁移，拒绝所有权/管理权限和继承的离线凭据。`auto` 是本地开发默认，不能代替正式权限模式。`dbops.exe` 还提供使用同一导出快照的只读逻辑备份，以及仅面向新库的校验恢复；恢复撤销旧会话和租约，保留资产、回执和未确认结算，不自动切换正在使用的服务。参数、身份边界和未完成的生产备份策略见[部署说明](../docs/online-operations.md)。

`/livez` 判断进程能否响应；`/healthz` 保留数据库连通检查；`/readyz` 在两秒期限内检查数据库、已配置权威进程的签名响应及版本、当前直连 TLS 证书有效期。只启用账号 API 时不要求房间进程；依赖或证书不可用时就绪返回 503。

管理指标默认关闭。需要时由服务环境提供随机 `YUANZHENG_ADMIN_TOKEN`（至少 32 字节），加 `--admin-listen 127.0.0.1:18081`，再以 `Authorization: Bearer` 读取该端口的 `/metrics`、`/readyz`、`/livez`；游戏监听的 `/metrics` 始终不可用。指标只使用固定路由、方法与状态分类，包含请求耗时、依赖、证书到期、有效会话/租约、战斗和未确认结果，不含角色 ID 或凭据。管理文件权限、启动示例和验收边界见[部署与监控说明](../docs/online-operations.md)。

## 测试范围

`dev.py test` 使用独立 `yuanzheng_test` 数据库；每个测试再创建随机 schema，结束时只删除自身 schema。缺少测试连接时会失败，不能输出跳过后全绿。

覆盖账号密码哈希、换机撤销、令牌轮换、角色所有权/上限、非法物资/版本、并发重复创建、持久化回执、频道容量/租约/移动权限，以及账本故障后的回滚、并发重试、一次性奖励。事务测试使用真实 PostgreSQL、脚本化权威对端隔离数据库故障；不能用它代替下述真实 Godot 端到端验证。

客户端隔离验证已登记在 `tools/run_regression.ps1` 的 `VerifyOnlineBoundary`；真实 HTTP + Godot 双端验证另行运行。单机回归不依赖在线服务运行。

```powershell
python 远征/server/tools/verify_clients.py --godot <Godot-4.7.2路径> --capture
python 远征/server/tools/verify_room.py --godot <Godot-4.7.2路径>
python 远征/server/tools/verify_world.py --godot <Godot-4.7.2路径> --capture
python 远征/server/tools/verify_world.py --godot <Godot-4.7.2路径> --database-recovery --capture
python 远征/server/tools/verify_accounts.py --godot <Godot-4.7.2路径> --capture
python 远征/server/tools/verify_identity.py --godot <Godot-4.7.2路径> --capture
python 远征/server/tools/bootstrap_monitoring.py --proxy <本机实际代理>
python 远征/server/tools/verify_operations.py --godot <Godot-4.7.2路径>
```

第二条从当前共享战斗源码和全部 JSON 构建 `.local/room-project`，导入并检查脚本；真实 Go 签名客户端连接进程，检查签名、nonce、顺序、服务器时钟、重放、已提交状态校验、未提交输入/时钟回滚和移动判定。原单调时钟接口保留作私有探针；正式战斗同步由网关根据持久化时钟与输入驱动。

第三条启动真实 PostgreSQL、Go 网关、Godot 权威进程和两个独立 Godot 客户端，同城移动并各自完成真实战斗。在胜利入账时通过数据库触发器注入故障，按安全日志中的 SQLSTATE 核对两个数据库异常，并核对无半笔奖励/claim/输入，随后重启网关和战斗进程，再让客户端以原请求标识重试；独立查询数据库确认各自仅发奖一次。另验证重复回执、重登录后恢复未确认结算、确认回城、退出撤销会话及单机数据哈希。只清理随机测试 schema 和自有进程。

这仍是桌面本机证据，不能替代双手机、广域网、24 人压力、合作副本、PVP 或运营验收。`VerifyOnlineWorld` 与 `VerifyOnlineHttp` 需要外部真实服务与隔离测试身份，由对应 Python 工具启动；常规单机回归不依赖这些服务。

`--database-recovery` 变体新建专用测试库与三种独立数据库身份，以 TLS 和无 DDL 权限的网关完成同样的真实双端链，再在两个未确认胜利时使用只读身份备份、恢复到新库、撤销旧会话并重启服务。两个原客户端必须拒绝旧令牌、普通登录回到原角色、以原请求取得同一回执并各确认一次奖励。仅清理该运行创建的随机库与角色，私有 dump 和密码留在忽略目录；归档验收只取脱敏报告和日志。

账号页面脚本用真实按钮及 Go/PostgreSQL 验证注册恢复码遮挡、重名建议、删除确认/取消、恢复原角色、旧恢复码拒绝、新密码找回、站内记录确认和单机隔离。截图只保存遮挡状态，脚本扫描日志中的恢复码模式并拒绝把泄漏样本算作通过。客户端联测工具均过滤服务端数据库连接/私有密钥等环境变量，Godot 客户端还在运行时检查这些变量不存在。

身份页面脚本使用独立测试库、受限网关、真实 HTTPS 和两个 Godot 客户端：经实际创建页选择不同性别与批准头像，检查本机图片回退提示、删除/恢复后的身份与资产，以及双方在“同行名片”中看到对方的头像和身份。数据库独立核对两份初始资产，没有额外发奖；截图、日志凭据扫描、单机文件与在线源码前后摘要另行留证。Go 测试还用真实旧版 schema 和旧创建回执验证新增迁移不改资产与幂等摘要，拒绝自定义路径/URL，检查并发创建和默认身份归一。

最后一条使用真实 Godot HTTPS 客户端、网关、数据库、权威进程和本机 Prometheus：检查有效证书、不受信任根、错误主机名及过期证书；实际抓取私有指标、观察依赖告警触发/恢复，并中断仅此网关的数据库连接检查无半笔资产。测试 CA 不进入系统信任库，私钥和管理令牌不传给客户端，不向外部接收人发送通知。正式监控模板在 `deploy/monitoring`，实际工具校验和告警状态另行留证。

`verify_world.py --tls-directory <开发证书目录> --capture` 可用同一验证中的短期 CA 重验完整双端战斗链；仅调试构建接受显式测试 CA，仍校验证书和主机名。`VerifyOnlineTLS` 与其他外部服务验收一样由 Python 工具提供上下文，常规单机 79 项不依赖服务或测试证书。

验收记录保存在 `.local/verification`；Go 测试的完整 JSON 在 `go-integration.jsonl`。首批证据在仓库根 `reports/online_20261116`；最新账号管理与双端重验在 [20261117/account-management](../../reports/online_20261117/account-management/README.md)，完整单机回归另行归档。此前性能/传输失败记录继续保留，不通过覆盖文件追认成功。

协议：[online-protocol-v1.md](../docs/online-protocol-v1.md)。依赖 API 依据为 [pgx 官方文档](https://pkg.go.dev/github.com/jackc/pgx/v5)、[Go bcrypt 文档](https://pkg.go.dev/golang.org/x/crypto/bcrypt)。便携 PostgreSQL 来源由 [PostgreSQL 官方 Windows 下载页](https://www.postgresql.org/download/windows/)指向 EDB。
