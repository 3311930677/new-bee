# 在线服务部署与监控

本文件补充联机实施方案 L0 的可重复启动、就绪判断、私有指标和 TLS 验证边界。实现和实际演练结果分别记录，不把配置模板当成已部署的公网服务。完整阶段范围继续由[实施台账](plans/2026-11-16-online-implementation-progress.md)管理。

## 本批接口约定

- `GET /livez` 只判断入口进程能够响应，不依赖数据库或权威进程。
- `GET /healthz` 保留现有数据库连通检查，兼容已有本机工具。
- `GET /readyz` 在独立的两秒期限内检查数据库，以及已配置权威进程的签名响应、内容/规则版本和有效 epoch；直连 TLS 证书也必须处于有效期。失败返回 503。只启用账号 API 时不要求不存在的房间进程。
- 运行指标由可选的 `--admin-listen 127.0.0.1:<端口>` 提供，强制使用字面回环地址，并要求环境变量中的随机管理令牌。公开游戏监听不提供指标；管理接口不提供写数据或执行脚本能力。
- 指标覆盖固定路由模板的请求数量/耗时、失败类型、依赖可用状态、证书剩余有效时间、有效在线会话/租约、进行中战斗和待确认结算。标签不包含账号、角色、令牌、IP、原始 URL、请求或响应体；数据库异常只使用 SQLSTATE。数据库查询失败时不伪造状态数量为零。

## TLS 与本地演练

公开客户端使用 HTTPS，校验证书信任链和目标主机；生产路径不提供跳过验证选项。明文 HTTP 只允许绑定字面回环地址，反向代理模式也保留这个限制。直接 TLS 可绑定外部地址，证书与私钥由部署环境提供。

本机演练使用独立生成的短期测试 CA/服务证书，不安装到系统信任库。仅调试构建允许测试工具为某次连接提供测试 CA，仍进行主机名和有效期校验；正式构建使用默认验证。私钥、管理令牌和测试账号只保存在忽略目录或服务端进程环境，不传给客户端。证书文件本身不是私钥。

网关持有数据库连接和管理令牌；权威 Godot 仅持有自己的 RPC 签名密钥。启动器分别构造环境，权威进程也拒绝继承数据库、管理或 TLS 私钥变量。生产部署仍需分开操作系统服务身份并限制各自文件访问，不能只依赖环境过滤。

实际演练需要验证：证书不受信任、错误主机名和过期证书被拒绝；有效证书下真实客户端能够登录；权威进程停止后就绪失败而进程仍存活，重启后恢复；独立数据库连接中断后指标与就绪均反映故障，恢复不产生半笔角色或资产。

本批使用 [Godot 的验证型 TLSOptions.client](https://docs.godotengine.org/en/stable/classes/class_tlsoptions.html#class-tlsoptions-method-client)，不设置主机名覆盖。指标遵循 [Prometheus 文本格式](https://prometheus.io/docs/instrumenting/exposition_formats/)的 UTF-8/LF、指标族分组和累计桶规则，由官方 `promtool` 与真实抓取验证。便携监控工具固定为[官方 3.16.0 发布](https://github.com/prometheus/prometheus/releases/tag/v3.16.0)，包摘要同时核对源码固定值和官方校验清单。

## 已执行的本机证据

运维运行 `operations_147328edbbb941b19182ba543e0153af` 验证了五种证书场景、私有指标、真实 Prometheus 抓取和权威/专属数据库连接故障后的告警状态与恢复；使用的是调试客户端，不是正式手机包。故障期 40 次角色请求均收到完整 500，恢复后重试原标识只创建一份角色与初始资产。演练依赖告警等待缩短为 1 秒；正式模板仍为 1 分钟。告警状态发生在本机 Prometheus，没有向外部接收方送达通知。

同一修复后二进制完成了运行 `world_2dcd91f97d314e48a4eed62ea69b0b25` 的两个真实 Godot 客户端 HTTPS 战斗链，包括指定发奖错误、网关/权威重启、原请求重试和各一次奖励。独立权威回归 25 项、Go 完整测试 31 项通过；单机完整回归另行登记。详细失败历史、原始日志和最终证据见[实施台账](plans/2026-11-16-online-implementation-progress.md)。

本轮还复现并修复了快速依赖失败时未读完请求体导致 TLS 错误回包丢失的问题。原来的 16 KiB 限制与请求期限保留；先完成有界读取，再进入鉴权和依赖操作。保留旧二进制与同一探针对照，新构建 40/40 完整错误响应，旧构建 23/40 无响应。这是该故障路径的证据，不替代普通网络稳定性和手机延迟验收。

## 独立数据库身份与离线迁移

`server/bin/dbops.exe` 是单独的离线运维程序，游戏监听不提供这些操作。新环境先由数据库管理员建立**空的专用数据库**，再执行 `provision`；工具拒绝 `postgres`、模板库、现有本机开发/测试库、有应用对象的库，以及已存在的角色名。三种密码通过离线进程环境提供，要求各自独立、32–128 个 URL 安全字符，不出现在参数、报告或客户端中。配置事务失败不会留下半套角色与授权。

空库检查包括依赖 `public` schema 的对象（例如只有枚举类型、还没有表的库），也检查自定义 schema、扩展、大对象、外部数据包装器/服务器、发布和事件触发器；不会因为“没有表”就去改已有数据库的访问权限。

建角色前在离线工具内按 PostgreSQL 格式生成随机盐的 SCRAM-SHA-256 校验值，SQL 不含明文密码，避免数据库活动/语句日志记录原密码。实际连接和 PostgreSQL 原生工具仍以各自私有环境完成认证；数据库管理员可见的校验值也属于私有服务数据。依据为 [PostgreSQL 密码处理说明](https://www.postgresql.org/docs/18/libpq-misc.html#LIBPQ-PQENCRYPTPASSWORDCONN)与[官方 SCRAM 实现](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/common/scram-common.c)。

| 身份 | 用途与权限 | 进入运行中的网关 |
|---|---|---|
| migrator | 拥有 `game` schema 和迁移建立的对象；仅发布时运行迁移 | 否 |
| runtime | 当前 API 所需的明确表读写和审计序列使用；无建表/建库/角色管理、所有权、角色成员关系和账本改写/清空权限 | 是，仅自己的连接 |
| backup | 表与序列只读，供逻辑备份；不能写资产、推进序列或执行 DDL | 否 |

`grant` 对当前代码的写表清单逐项授权；新增表不会自动取得 runtime 写权限。以后发布新增迁移时，必须复核这个清单并重新执行离线授权。backup 的默认只读授权覆盖 migrator 后续建立的表和序列。数据库及 `public` schema 不保留 `PUBLIC` 的默认连接、临时表/创建权限。当前版本没有可由客户端触发的 `SECURITY DEFINER` 运维函数。

以下从 `server` 目录执行，密码和连接由各自离线服务环境提供，不在命令中展开。先用数据库管理工具新建 `yuanzheng_stage`；`YUANZHENG_DBADMIN_URL` 必须明确连接该新库，角色名可按环境换用，三个角色必须不同。

```powershell
.\bin\dbops.exe --action provision --database yuanzheng_stage `
  --migrator-role yz_stage_m --runtime-role yz_stage_r --backup-role yz_stage_b
# 使用 YUANZHENG_MIGRATION_DATABASE_URL，拥有 schema 的离线身份执行。
.\bin\dbops.exe --action migrate
# 使用 YUANZHENG_DBADMIN_URL，离线复核并应用明确授权。
.\bin\dbops.exe --action grant `
  --migrator-role yz_stage_m --runtime-role yz_stage_r --backup-role yz_stage_b
```

部署网关必须使用 `--migration-mode check --require-restricted-database`，以及前文的 HTTPS 与私有权威参数。`check` 仅以只读事务核对迁移名称和摘要；缺失、多出或变动均拒绝启动，不通过修改历史 SQL 回退应用。权限检查拒绝超级用户、创建数据库/角色/复制能力、危险内置角色成员关系、可经 `SET ROLE` 取得的所有权、schema/数据库创建权限和账本改写等权限。网关还拒绝继承离线管理员、迁移、备份连接与密码、测试库连接和原生 PostgreSQL 凭据环境；启动器只传自己的连接、房间密钥和可选管理令牌。默认 `auto` 保留本地开发兼容，**不是正式部署的权限模式**。

## 逻辑备份与新库恢复

`backup` 使用 `YUANZHENG_BACKUP_DATABASE_URL`。在获得与 migrator 互斥的共享锁后，建立 PostgreSQL 可重复读快照；表计数/摘要和实际 `pg_dump --format=custom --snapshot` 使用同一快照，不分别读取两份可能变化的数据。完成后才生成 `manifest.json`，包含全表计数/摘要、归档 SHA256、字节数、PostgreSQL 版本和实际 UTC 起止时间；不输出原始行、密码或令牌。

```powershell
# --folder 必须为尚不存在的绝对目录，父目录预先按服务身份设置权限。
.\bin\dbops.exe --action backup --pg-bin <PostgreSQL-bin绝对目录> `
  --folder <新的备份目录绝对路径>
# YUANZHENG_DBADMIN_URL 在本步骤连接管理员维护库；角色已由 provision 创建。
.\bin\dbops.exe --action restore --database yz_restore_drill_001 `
  --migrator-role yz_stage_m --runtime-role yz_stage_r --backup-role yz_stage_b `
  --pg-bin <PostgreSQL-bin绝对目录> --folder <上一步的备份目录绝对路径>
```

恢复只接受新的 `yz_restore_*` 数据库名，拒绝已存在目标和源库；在建库前校验文件摘要与清单。当前工具要求同一 PostgreSQL 主版本。`pg_restore` 用单事务、遇错即停、忽略原归档所有权/ACL，并以明确的 migrator 身份拥有恢复对象。随后独立核对全部 `game` 表与备份快照一致，才撤销恢复出的全部旧会话、失效旧房间租约并重新应用权限。幂等回执、账本、输入、未确认结算和领奖 claim 保留；会话与租约的变化是有意的恢复步骤。

恢复失败保留工具新建的隔离库供调查，并撤销 runtime/backup 的连接权限。工具从不覆盖或删除现有库，也不改正在使用的网关地址。成功报告 `ready_for_review` 表示数据与身份边界通过本工具检查，**不自动切换线上服务**。运行源库在备份之后产生的数据不在该快照中；发布切换、维护窗口与数据损失边界仍需单独决定和演练。

账号密码摘要、恢复码摘要和删除状态也恢复到备份时刻；仅撤销会话不能保留备份后发生的密码更换或删除申请。正式恢复前还需对照独立安全记录处理这些变更，并补齐必要的强制找回和隐私恢复流程；当前演练不据此宣称完整账号灾难恢复已完成。

当前实际验收为 Go 完整 40/40 和运行 `world_4f4d8659144244c6a9078cb33aaa5f5e` 的真实 HTTPS 双端 9/9：受限网关三次启动，两个未确认胜利经只读备份恢复到新库，17 张表匹配，原客户端重新登录并重放同一回执，各仅一次奖励。完整单机回归另为 79/79。原始结果、截图、失败历史与未完成边界见[本批归档](../../reports/online_20261117/database-recovery/README.md)，不把本机样本当成生产恢复或容量证明。

归档包含账号、会话等敏感数据库内容，不能提交到 Git 或打进客户端。工具要求新目录，在支持 Unix 权限的平台以 0700/0600 建立目录/文件；Windows 的实际访问控制仍由部署者设置并验收，不能把模式位当成已完成的 NTFS 身份隔离。当前归档未加密、没有异地保存、WAL 连续归档或时间点恢复，也不包含集群角色、服务密钥、TLS 私钥和匹配的游戏内容版本包；这些仍属于正式备份策略的门槛。只恢复自己生成且可信的归档；SHA256 发现损坏，不证明可同时替换清单与归档的来源可信。

协议与工具依据：[PostgreSQL 18 pg_dump](https://www.postgresql.org/docs/18/app-pgdump.html)、[pg_restore](https://www.postgresql.org/docs/18/app-pgrestore.html)、[权限](https://www.postgresql.org/docs/18/ddl-priv.html)和[默认权限](https://www.postgresql.org/docs/18/sql-alterdefaultprivileges.html)。逻辑导出不等于完整的生产持续备份方案。

## 后续发布门槛

服务监督/重启、备份加密与异地留存/持续恢复、迁移和发布切换/回退、操作系统服务身份、手机跨网络验证、容量/费用和独立告警送达仍需逐项实现与取证。新数据库身份与逻辑恢复的实际验收结果登记在实施台账；不能仅据上面的工具说明推断通过。目标服务器、域名和真实通知接收方尚未配置，当前文档不宣称公网部署或通知已生效。
