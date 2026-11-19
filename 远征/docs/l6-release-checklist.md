# 《远征》联机版 L6 上线运维检查清单与外部验收阻塞项

> [!IMPORTANT]
> 本清单严格区分 **“本机可控环境已验证项”** 与 **“需真实外部账号/云主机/手机/值班通道才能执行的阻塞项”**。任何未在真实生产/预发布环境完成签字的阻塞项，不得宣称已完成全量公网正式上线。

## 一、本机已实现的 L6 核心运维能力

1. **受控回环运维面 (`AdminHandler`, `GET/POST /ops/*`)**：
   - `GET /readyz`、`GET /livez`、`GET /metrics`：实时探测数据库、权威 `RoomHost` 进程与 TLS 证书有效期。
   - `GET /ops/reports` 与 `POST /ops/reports/{id}/resolve`：只允许携带 `YUANZHENG_ADMIN_TOKEN` 的回环管理员查看 `player_reports`，并将处理结论（`dismissed` / `warned` / `muted` / `suspended`）写入防篡改仅追加表 `moderation_actions` 及 `audit_events`。
   - `GET /ops/capacity`：按地图/分线实时输出在线会话、有效房间租约、活跃战斗/秘境/演武队列数、未处置举报数及当前寄售开关状态。
   - `POST /ops/config/market-pause`：无需重启即可热熔断/恢复寄售行与玩家交易入口，并记录审计事件。
2. **玩家数据合规自助接口 (`/v1/account/privacy/*`)**：
   - `GET /v1/account/privacy/summary`：返回账号状态、角色与安全通知摘要。
   - `GET /v1/account/privacy/export`：导出账号基础信息、角色、钱包与近期审计/通知记录，严格剥离 `password_hash`、`recovery_salt`、`recovery_hash`，并记入 `account_privacy_requests`。
   - `POST /v1/account/privacy/delete`：二次口令+确认字校验；拒绝仍有未结算战斗、挂单或交易的账号；原子完成会话吊销、租约失效、排队/好友/屏蔽清理、角色昵称匿名化软删除与账号擦除（`status='erased'`），后续登录、刷新与找回全部拒绝。
3. **离线加密备份与校验恢复 (`dbops --encrypt-key-file`)**：
   - 支持以 64 位十六进制 256-bit 密钥文件对 `pg_dump` 自定义归档进行分块 `AES-256-GCM` 加密密封（`database.dump.enc`），密封校验完成后立即删除明文 `database.dump`。
   - `restore` 自动拒绝缺密钥、错误密钥、清单或密文任意字节篡改；恢复后核对全部 56 张表行数与内容哈希，并强制吊销旧会话及房间租约。
4. **回滚门禁 (`CheckMigrations`) 与协议版本保护**：
   - 客户端请求头 `X-Content-Version` 不匹配时返回 `409 content_version_mismatch`。
   - 运行时网关启动检查 `schema_migrations` 集合与嵌入式 SQL 校验和精确一致，存在未知新迁移时直接 `fail-closed` 拒绝启动，防止旧版代码误连已前向迁移的数据库。

## 二、标准发布、故障切换与回滚 SOP

### 发布前检查 (Pre-Flight)
1. 确认目标库完成全量加密备份：
   ```powershell
   dbops.exe --action backup --pg-bin <PG_BIN> --folder <ABS_BACKUP_DIR> --encrypt-key-file <KEY_FILE>
   ```
2. 校验备份清单 `manifest.json`（确认 `"encrypted": true`、`"cipher": "AES-256-GCM"` 及 56 张表摘要完整）。
3. 对新版本运行只读演练恢复至临时 `yz_restore_*` 校验表数据一致。

### 发布流程 (Rolling Upgrade)
1. 通过隔离 `migrator` 角色执行：`dbops.exe --action migrate` 及 `dbops.exe --action grant`。
2. 先启动 `RoomHost` 权威进程并确认版本校验通过，再启动新版本 `gateway` 并检查 `/readyz == 200`、`/ops/capacity`。
3. 观察 Prometheus 指标 `yuanzheng_ready == 1`、`yuanzheng_battle_rpc_duration_seconds` 与 `yuanzheng_unacknowledged_results` 无异常飙升。

### 应急停服与回滚 (Emergency & Rollback)
1. 若发现经济异常，优先调用回环 `POST /ops/config/market-pause`（`{"paused": true}`）止损，无需重启服务。
2. 若版本缺陷但**未引入新表迁移**：切回上一版二进制（`gateway` + `RoomHost` 需同 `ContentVersion` 成对回退）。
3. 若数据库已应用新迁移（旧版 `CheckMigrations` 会按设计拒绝启动）：
   - **禁止**在生产库直接手动 `DELETE schema_migrations` 降级；
   - 应由升级前加密快照按 `dbops --action restore --encrypt-key-file` 恢复至新库并校验会话/租约已吊销，再切流至旧版二进制，或在原库热修发布 `N+1` 版本。

## 三、真实外部验收阻塞清单 (必须人工/外网环境完成)

以下项目受限于本机隔离开发环境（无公网云服务器、无正式域名 CA、无外部值班通道及真机外网接入），均如实登记为 **待外部验收（Blocked by External Environment）**：

| 编号 | 外部验收项 | 当前状态 | 上线前签字要求 |
| :--- | :--- | :--- | :--- |
| EXT-01 | 公网云服务器与 VPC 安全组配置 | 未执行（需云账号与主机） | 确认 5432 与 `AdminListen` 仅内网/回环可达，公网仅暴露 TLS 端口 |
| EXT-02 | 正式权威 CA HTTPS 证书部署与自动续期 | 未执行（需正式域名与 DNS） | 用正式证书替换测试自签 CA，验证 `yuanzheng_tls_certificate_expiry_seconds > 30d` |
| EXT-03 | Android / iOS / Windows 异网真机广域网实测 | 未执行（需测试机与公网入口） | Wi-Fi/5G 切换、锁屏断线重连、1v1~3v3 与秘境真机全链路签字 |
| EXT-04 | 外部 Alertmanager 值班通道实收送达 | 本机仅演练回环 Webhook | 配置钉钉/飞书/邮件/PagerDuty 接收端，制造真实故障确认值班手机实收与恢复通知 |
| EXT-05 | 异地对象存储 KMS 加密上传与 WAL PITR 演练 | 本机已演练 `dbops` AES-256-GCM 备份还原 | 上传 `database.dump.enc` 至异地只读归档桶，验证按时间点（PITR）恢复与双人接管 |
| EXT-06 | 运营客服与审计密钥分离交接 | 待运维团队接管 | 轮换全部初始密钥、管理员 Token 及数据库角色密码，禁用开发调试配置 |
