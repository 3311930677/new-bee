# 在线协议 v1：账号、角色、城镇与权威战斗

当前实现 L0 账号/角色，以及昭元边城最小同屏、独占租约、服务端测试战斗和一次性奖励。城镇使用 HTTP 低频快照，尚未达到 L1 的 10Hz、移动预测/插值/AOI；队伍、市场和竞技仍按联机方案继续实现。

## 信任边界

- 客户端仅提交意图，不提交金币、经验、物品数量、战斗胜负或本地存档。
- JSON 不接受未知字段；请求上限 16 KiB。网关先完成有界读体，再鉴权和访问依赖，避免快速拒绝时关闭仍在传送请求体的 TLS 连接而丢失错误响应。成功 `{ "data": {...} }`，失败 `{ "error": { "code": "...", "message": "..." } }`。
- 认证使用 `Authorization: Bearer <access_token>`。访问令牌有效期 30 分钟；刷新令牌最多 7 天，每次刷新轮转且旧令牌立即作废。同账号重新登录会撤销旧会话。
- 数据库只保存令牌 SHA256 和 bcrypt 密码哈希；日志不包含密码、令牌和请求体。
- 角色写操作须带 `X-Content-Version` 和 `Idempotency-Key`（8–80 位字母、数字、下划线或连字符）。相同操作/标识/内容重试返回原回执；同标识不同内容返回 409。
- 内容摘要为 SHA256，将 `data/` 下全部 `.json` 文件按文件名排序，逐个追加文件名 UTF-8、一个零字节和原始文件字节；成长、组合技、伙伴与地区规则也必须覆盖。客户端、Go 入口和独立 Godot 房间分别从自己的内容计算，不能让客户端照抄服务器版本绕过更新检查。入口在启动时拒绝空目录和无法解析的 JSON。

## 已实现端点

| 方法与路径 | 请求 | 成功响应 |
|---|---|---|
| GET `/healthz` | 无 | 数据库探活、协议与规则版本 |
| GET `/livez` | 无 | 入口进程能否响应，与依赖故障分开 |
| GET `/readyz` | 无 | 数据库、已配置权威版本与 TLS 有效期检查；不就绪返回 503 |
| GET `/v1/manifest` | 无 | 内容版本、职业/外观/性别/头像白名单、角色上限、实际可用功能 |
| POST `/v1/auth/register` | `username,password` | 会话 ID、访问/刷新令牌和访问有效期 |
| POST `/v1/auth/login` | 同上 | 同上；撤销同账号旧会话 |
| POST `/v1/auth/refresh` | `refresh_token` | 新令牌对；旧刷新令牌不能重放 |
| POST `/v1/auth/logout` | 已认证 | 撤销当前会话 |
| POST `/v1/auth/recover` | `username,recovery_code,password`，带内容版本 | 找回并更新密码、轮换恢复码、撤销全部旧会话；要求重新登录 |
| POST `/v1/account/recovery-code` | 已认证，`password`，带内容版本 | 验证当前密码后返回新的恢复码，旧码失效 |
| GET `/v1/account/notifications` | 已认证 | 本账号最近 20 条未确认安全记录 |
| POST `/v1/account/notifications/{id}/acknowledge` | `{}`，所属账号，幂等标识 | 确认该安全记录 |
| GET `/v1/session` | 已认证 | 当前账号/会话/选中在线角色 ID |
| GET `/v1/characters` | 已认证 | 本账号未删除角色列表 |
| GET `/v1/characters/deleted` | 已认证 | 本账号恢复期内角色、删除时间和 UTC 恢复截止时间 |
| GET `/v1/nicknames/suggestions?nickname=...` | 已认证、有效昵称 | 三项当时可用的候选昵称；不预留名称，创建时仍查重 |
| POST `/v1/characters` | `nickname,role_id,appearance_id`，可选 `gender_id,avatar_id` | 新角色；明确 `imported_assets:false` |
| GET `/v1/characters/{id}` | 所属账号 | 在线角色与权威钱包 |
| POST `/v1/characters/{id}/select` | `{}`，所属账号 | 选中角色；一会话仅选中一个角色 |
| DELETE `/v1/characters/{id}` | `confirm_nickname`，所属账号 | 进入 7 天恢复期；移除在线选择，保留资产 |
| POST `/v1/characters/{id}/restore` | `{}`，所属账号 | 恢复期内原角色/原资产恢复 |
| GET `/v1/characters/{id}/journey` | 已选中的所属角色，带内容版本 | 当前任务、背包容量与本角色物品 |
| POST `/v1/characters/{id}/journey/interact` | `step_id,target_id`，带内容版本和幂等标识 | 推进后的任务、行囊和本次对话 |
| POST `/v1/characters/{id}/pack/equipment` | `item_uid,equipped`，带内容版本和幂等标识 | 装备、卸下、出战或休息后的权威行囊和任务 |
| POST `/v1/rooms/join` | `{}`，已选择在线角色 | 独占租约：`room_id,lease_token,generation,character_id,map_id,x,y,move_sequence` |
| GET `/v1/rooms/current` | 已选择角色并有有效租约 | 自己的租约、同频道 `entities`、挑战目标、移动速度；续约 90 秒 |
| POST `/v1/rooms/move` | `lease_token,generation,sequence,x,y` | 服务端验证后持久化的新位置与序号 |
| POST `/v1/battles` | `encounter_id` | 从当前在线角色及服务器规则创建的战斗快照 |
| GET `/v1/battles/active` | 已选择在线角色 | 当前战斗或未确认结算；没有时 `battle:null` |
| GET `/v1/battles/{id}` | 此角色拥有的战斗 | 服务器推进后的快照；结束时原子结算并返回回执 |
| POST `/v1/battles/{id}/commands` | `action`，技能可附 `skill_id,target_uid` | 攻/技/物/逃的校验结果和最新服务器快照 |
| POST `/v1/battles/{id}/acknowledge` | `{}` | 确认已显示的结算回执；不会再次发奖 |

账号名为 3–32 位 ASCII 字母、数字或下划线，忽略大小写；密码为 10–72 UTF-8 字节。昵称为 2–12 个汉字/字母/数字，忽略字母大小写查重。角色职业只能是 `zs/ck/fs/fz`，当前外观只允许 `default`。初始 100 在线金币由服务器写钱包和不可变账本，不读取任何本地金币。每账号最多保留三个角色，7 天恢复期内角色仍占名额；过期记录保留审计但不再恢复。

## 身份展示白名单（本批接入）

在线角色增加 `gender_id` 与 `avatar_id`，只影响身份展示，不参与战斗、资产或权限计算。服务清单以 `character_identity` 功能位及 `gender_ids/avatar_ids` 公布当前白名单。性别为 `unspecified/male/female`（未指定/男/女）；头像为 `role_default/role_zs/role_ck/role_fs/role_fz`，分别为随职业及四种已随客户端发布的职业小像。头像可独立于当前职业选择；战斗继续使用职业形象。

创建请求可增加这两个字段。缺省及显式 `unspecified/role_default` 归一为同一默认请求，旧三字段请求的幂等摘要保持不变；历史回执原样返回，不重写旧 JSON。迁移给旧角色填入未指定性别和随职业头像，不依据角色立绘推断性别。角色列表、选择、详情、恢复列表与公共城镇实体提供已保存的身份字段。

服务端和数据库都拒绝白名单以外的标识，不能提交图片内容、文件名、资源路径或远程 URL。客户端导入预览只带昵称、职业、普通外观、性别和已批准头像建议；单机自选图片不读取或上传，明确回退为职业头像，原本机头像与资产不变。旧服务器未声明功能位时，客户端只允许默认身份创建，不静默丢弃玩家明确选择的非默认展示信息。

创建页在提交前展示本机图片回退与资产不导入说明。城镇的“同行名片”只读显示同频道已有实体的昵称、职业、性别、等级和批准头像，不提供好友、聊天、邀请或组队能力；身份暂时只能在创建时选择。

## 边城任务和在线行囊

`town_journey` 功能位表示网关启用了边城任务数据和权威城镇。房间快照为自己附上 `journey` 当前目标，以及当前旅程可见的遭遇。已选角色的行囊包含服务器生成的 `item_uid`、共享模板 ID、数量、绑定状态、已装备槽及该模板的显示属性。每件物品由服务端独立保存，当前任务物品均绑定。

带租约的玩家在服务端确认的位置靠近当前任务目标后，可提交交互意图。角色任务起点为 `s01`，观察、当前装备和已落库的胜利分别推进指定阶段。持久化的 `coop_entry: stele_cavern` 表示完成碑窟资格前置，真实组队入场由后续副本实现。读档、重登、换机与单机完成记录均不跳过在线阶段。

同一事务提交领取、装备、任务变化、不可改写的物品和任务历史、及幂等回执。满包先回退整次领取，保留原任务。临场换装及交互须先结束并确认现有战斗。角色所有权与当前选择在事务中复核。重复同一合法请求返回原回执，已推进阶段使用新键重领会得到任务已变化的响应。

开战保存由当前装备、岩龟和药品库存计算出的初始配置，权威重放沿用同一配置。在成功接受药品动作时才扣一瓶，和该条有效指令、战斗快照及扣药账本一并落库。失败或回放已确认指令不会扣药。量为零的批次保留其历史引用，行囊只展示余量大于零的批次。胜利推进任务、战斗结果、金币、经验和首胜记录使用同一事务。修改数据表会改变内容摘要，发布前须结清旧版本仍在进行的战斗。

本节是当前接入契约；实际通过结果在实施台账另行登记，不以契约文字代替真实客户端和数据库验收。

## 账号找回与角色管理

注册响应额外提供一次恢复码，格式为 `YZR-` 加 32 字节密码学随机值的 Base64URL 编码。数据库保存随机盐及 SHA256 摘要，既不保存恢复码明文，也不将恢复码写入幂等回执或日志。登录不会重新提供旧恢复码；迁移前的账号可以在登录后验证当前密码生成恢复码。

恢复码供玩家离线妥善保存，直到使用或替换前有效。找回必须同时提供账号、有效恢复码与新密码；页面要求重复确认新密码。成功事务一并更新密码哈希、轮换恢复码、撤销所有旧访问/刷新会话、写安全记录和审计。旧码不能再次使用，并发请求只有一个成功。登录在账号锁内重新检查密码哈希，避免旧密码的校验与找回事务交错后取得新会话。

密码或恢复码更新失败时不产生半笔变更。安全记录写入失败也会回滚密码、恢复码及会话撤销。找回失败对不存在的账号和无效/过期的恢复码返回相同错误；进行相同的密码哈希工作，结合来源 IP/账号的尝试限流。恢复码不是网页短期验证码，也不依赖尚未接入的邮件/短信服务。

找回成功不会自动登录，响应只提供新的恢复码并要求普通登录。更新恢复码和找回响应中的新码只在该响应提供，不使用保存明文结果的通用幂等回执。若响应中断，玩家先尝试用自己填写的新密码登录，再验证当前密码生成新码；密码与恢复码都丢失时，当前版本没有虚构的自动找回途径。

客户端恢复码默认遮挡，显示/复制由玩家明确点击。确认保存、退出或切换账号时清理内存，不写入单机 `save.json`。站内安全记录目前包含密码找回和恢复码替换，可由本人确认；独立通知渠道及客服身份核验仍属于后续公开运营工作。这里借鉴 [NIST 的保存恢复码规则](https://pages.nist.gov/800-63-4/sp800-63b.html#saved-recovery-codes)和 [OWASP 的密码找回指南](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html)，不宣称已完成全部身份认证标准的合规验收。

角色管理页删除前要求完整输入目标昵称，可取消；删除后七天内通过列表恢复同一个角色和资产，恢复期占用名额。昵称重名后给候选项，由玩家重新选择并确认创建。客户端只展示服务清单实际启用的城镇入口，不在账号服务模式展示不可用入口。

## 独占租约、实时位置流与移动（L1-A 接入）

每账号只有一条租约。新会话、过期后重入或切换角色均轮换随机 token 并增加 generation；旧会话已撤销，旧 token、旧 generation 和非连续移动序号拒绝执行。有效会话重复入城复用租约。重新登录同一角色保留数据库记录的位置，切换其他角色从配置出生点开始。频道容量分配由数据库事务锁串行化，已撤销会话和过期租约不占在线容量。

移动只接受目标位置，起点、移动速度与时间间隔取自服务器。Godot 使用共享地图表与 `data/online_rules.json` 核验所有已发布联机地图（当前为 `lorin_wilds` 与 `maple_road`）的边界、速度和建筑阻挡；战斗中拒绝地图移动。清单公布 `town_positions`、`world_channels`、`cross_map` 与 `npc_isolation` 功能位：
- `GET /v1/rooms/positions`（`application/x-ndjson`、10Hz、单连接 8 秒生命周期、每频道共享采集）按玩家权威坐标裁剪 **480px** 半径视野（AOI）内同频道同图在线角色；`/v1/rooms/current` 返回同口径邻近实体、当前地图（`map`）、可用频道摘要（`channels`）、当前地图出口（`portals`）、按当前角色状态水合的当前地图 NPC（`npcs`）及当前地图可见遭遇（`encounters`）。
- `GET /v1/rooms/channels` 与 `POST /v1/rooms/channels/switch` 允许在同图不同分线间幂等切线（受频道容量约束，拒绝满员切入，切换后轮换 `lease_token` 与 `generation`）。
- `POST /v1/rooms/travel` 按权威位置与出口半径执行 `lorin_wilds` ↔ `maple_road` 跨图迁移，落点写入目标地图出生/抵达坐标；战斗开战与任务交互严格核对当前地图匹配。
- `POST /v1/npcs/{id}/interact` 按当前地图、距离与角色个人任务进度更新并记录 `npc_interactions`，不同角色的 NPC 对话、交互计数与地图分布彼此完全隔离。

## 社交、聊天与组队（L1-C 接入）

清单公布 `social_chat` 与 `parties` 功能位后，网关开放角色级社交与最多 4 人小队契约：
- **好友、屏蔽与举报**：`GET /v1/social/state` 汇总当前好友列表、待处理申请、账号屏蔽名单、当前小队与待响应邀请。`POST /v1/social/friends/request`、`POST /v1/social/friends/{id}/respond` 与 `DELETE /v1/social/friends/{id}` 管理好友关系。`POST /v1/social/blocks`（及 `DELETE /v1/social/blocks/{account_id}`）以账号为粒度生效，双向拦截好友申请、组队邀请与私聊，并清理已有好友与待处理申请/邀请。`POST /v1/social/reports` 将分类与正文持久化到不可改写的 `player_reports` 审计表并写入 `audit_events`。
- **分域聊天**：`POST /v1/chat/messages`（限流、控制字符过滤、1–120 字校验）与 `GET /v1/chat/messages?after_id=` 支持 `room`（同频道）、`nearby`（同频道 480px AOI）、`party`（同队跨图）与 `whisper`（双方角色私聊），查询与发送端均由服务端过滤屏蔽关系。
- **真正组队**：`GET /v1/parties/current`、`POST /v1/parties`、`POST /v1/parties/invite`、`POST /v1/parties/invites/{id}/respond`、`POST /v1/parties/ready`、`POST /v1/parties/kick`、`POST /v1/parties/leader` 与 `POST /v1/parties/leave` 管控 4 人上限、队长权限、成员准备校验、离队顺位继任及空队解散（角色删除同步离队）；多人副本匹配与共战由下述 L2 接入。

## 合作副本与公共首领（L2 接入）

清单公布 `coop_dungeons` 与 `world_boss` 功能位后，网关与权威战斗进程支持 1–4 人合作副本（`stele_cavern` 失声碑窟、`tidal_gate` 退潮水闸）及古道公共首领（`maple_road` 枫林失路兽 `mon_lost_beast`）：
- **组队与匹配**：`GET /v1/coop/dungeons` 与 `GET /v1/coop/state` 返回副本规则、缩放表（1/2/3/4 人倍率与增援）、当前队列及所在实例。`POST /v1/coop/queue` 与 `DELETE /v1/coop/queue` 支持自选人数、`friends_only` 及跨队组批匹配，匹配器在事务锁内执行全配对双向账号屏蔽检查，排除互屏玩家经第三人拼成一队；队列确认开本通过 `POST /v1/coop/ready` 与 `POST /v1/coop/instances/{id}/start`（当前队伍一键开本，支持 1–4 人与四职业任意组合及高等级成员导师等级同步 `mentor_sync`）。
- **多房机关、协同共战与救援**：`POST /v1/coop/instances/{id}/action` 处理多房间顺序/并行机关（失声碑窟先左/中后右柱；退潮水闸先旧渠泄水、再侧闸、可选队友救回堤边货箱 `cargo_rescue`）、多数派安全撤退至检查点、队长移交与离开重算缩容（remaining 成员数重新缩放未死亡/下阶段战斗难度）、以及 `disconnect` / `reconnect`（90 秒重连宽限窗口内掉线队友在 `RoomHost` 内切换 `safe_defend`，90 秒内可无损重连恢复战斗站位）。`RoomHost` 与 `BattleSim` 在 `coop_mode=true` 下支持最多 4 名玩家 + 各自出战伙伴同场作战、独立 `owner_uid` 分职目标选择、倒地救援窗口（队友主动 `rescue`）与结算贡献统计。
- **个人掉落与防丢包**：通关由服务端幂等写入每名存活参与者独立的 `coop_instance_drops` 不可篡改掉落记录（含首通徽记、副本装备/碎片与导师印记）；`POST /v1/coop/drops/{id}/claim` 将掉落发入个人行囊，行囊满位（`pack_full`）时保留在待领箱并拒绝吞道具。
- **枫林公共首领**：`GET /v1/world-boss/current`、`POST /v1/world-boss/objective`（阶段目标 `track` / `interrupt`）、`POST /v1/world-boss/engage`（经 `RoomHost` 权威演算输出与首领扣血）与 `POST /v1/world-boss/claim`（`UNIQUE (event_id, account_id)` 保障同账号每次公共首领窗口仅领一次主奖，支持故障关窗/超时结算后补领与迟到玩家阶段目标基础材料）。

## 经济市场与玩家交易（L3 接入，M0 → M1 → M2 → M3）

清单按配置 `market.stage`（`M0` 内部沙盒 / `M1` 材料寄售 / `M2` 可交易装备寄售 / `M3` 面对面交换）发布 `market_sandbox`、`npc_floor_market`、`market_consignment` 与 `direct_trade` 功能位；所有货币与库存变动在同一数据库事务写入 `wallets`/`wallet_ledger` 与 `inventory_items`/`inventory_ledger`，并受全服金币/物品严格守恒校验：
- **NPC 保底价格带与首页看板**：`GET /v1/market/summary` 与 `POST /v1/market/npc/trade` 公布所在地图（`lorin_wilds` / `maple_road`）经运输价差加权的保底买卖价、近 24 小时成交高低区间、当前挂单总量、地区事件与每日行商次数上限；市场暂停开关开启后可继续查询与撤单/领奖，阻止新增买单与挂单。
- **寄售托管、税费与邮件领奖（M1 / M2）**：`GET /v1/market/orders`、`POST /v1/market/orders`、`POST /v1/market/orders/{id}/buy`、`POST /v1/market/orders/{id}/cancel`、`GET /v1/market/payouts` 与 `POST /v1/market/payouts/{id}/claim` 实现最多 20 单上限、1%（最低 1 金）不可退上架费、4% 成交税、行囊物品消费转托管（挂牌期卖家不可穿戴、不可重复交易）、部分成交、`FOR UPDATE` 互斥购买与撤单、同账号自买拦截并触发 `economy_alerts`（`self_trade_attempt` / `price_outlier` / `wash_volume`），以及基于 `market_payouts` 邮箱附件领钱领物与满包（`pack_full`）防吞保护；M2 `equipment` 保留 `item_properties` 词条强化与 `item_origin` 来源，强制 `initial_qty = 1` 且仅允许 `tradeable=true` 且 `bound=false` 实例。
- **好友面对面交换（M3）**：`GET /v1/trade/sessions`、`POST /v1/trade/sessions`、`POST /v1/trade/sessions/{id}/offer`、`POST /v1/trade/sessions/{id}/confirm` 与 `POST /v1/trade/sessions/{id}/cancel` 限制仅对非屏蔽且同图好友开放，放入金币或未绑定物品即时进入托管并发起修订号递增，**任一方修改报价都会立即清除双方确认状态**；`confirm` 校验请求提交的 `revision` 与最新一致，双方确认在同一事务原子交割，取消则无损退还托管金币及物品（满包自动落入 `market_payouts` 退回附件）。

## 其余合作内容、沉渊港首领与帮派（L4 接入）

清单发布 `guilds`、`shenyuan_boss` 与新增合作副本规则后，契约扩展如下：
- **其余合作副本与沉渊港公共首领**：[online_rules.json](../data/online_rules.json) 与迁移扩展 `shenyuan_port`（沉渊港）地图、传送门及 `ore_vein`（赤砂矿脉：`mine_rail_switch` 轨道机关 + `mon_siege`/`mon_mummy` + `mon_redsand_guard`）和 `stele_depths`（界碑深处：`resonance_ring` 共鸣环 + `mon_cultist`/`mon_triad_echo` + `mon_nameless_warden`）合作副本，产出可交易稀有材料与不可交易帮派建材 `mat_guild_timber`/`mat_guild_stone`；`GET /v1/world-boss/current` 支持多地区首领列表与 `?map_id=` 定向查询，`maple_road`（`mon_lost_beast`）与 `shenyuan_port`（`mon_salt_scale` 沉渊盐鳞王）均保持单账号同活动窗口领奖一次与独立阶段目标材料。
- **帮派生命周期、共同据点、建材仓库与不可篡改审计**：迁移 `010_online_guilds.sql` 新增 6 张表（全库增至 **46 张表**），其中 `guild_audit_logs` 由触发器及数据库角色权限锁死只追加（无 `UPDATE`/`DELETE`）；提供 `GET /v1/guilds/state`、`POST /v1/guilds`、`POST /v1/guilds/invites`、`POST /v1/guilds/invites/{id}/respond`、`POST /v1/guilds/join-public`、`POST /v1/guilds/leave`、`POST /v1/guilds/permissions`、`POST /v1/guilds/warehouse/deposit`、`POST /v1/guilds/warehouse/withdraw`、`POST /v1/guilds/decorate`、`POST /v1/guilds/weekly-tasks/complete` 与 `POST /v1/guilds/takeover`。强制校验：帮派仓库只允许 `guild_building=true` 且非可交易建材（拒绝寄售装备/货币/普通可交易物）；离帮进入 `leave_cooldown_seconds`（600s）冷却期；成员上限由 `base_member_cap`（30）随协作周常提升至 `max_member_cap`（60）；会长离线超过 `leader_inactive_seconds`（14 天）由执事或最资深成员通过公开事务交接 `takeover`；未入帮玩家仍可通过个人周常与日常副本取得同等进度奖励。

## 演武场 1v1 / 2v2 / 3v3 切磋与独立排位（L5 接入）

清单发布 `pvp_arena`、`pvp_1v1`、`pvp_2v2` 与 `pvp_3v3` 功能位后，演武场（无公共地图自由攻击、无装备掉落、无经验倒扣）契约如下：
- **权威多人阵营对战**：`BattleSim.gd`、`Combatant.gd`、`MonsterAI.gd`、`SkillSystem.gd` 与 `AuthorityBattle.gd` 在保持单机与合作副本口径零漂移的前提下支持 `mode: "pvp"`（`1v1` / `2v2` / `3v3`，双侧 `ally` / `enemy` 玩家队伍 + 随行宠物缩略参战、属性同步 Lv.20 + 有限装备构筑上限、`aoe_target_cap=3`、`heal_mult=0.85`、时间上限按存活人数→剩余总血量比例→平局结算），`RoomHost` 的 `battle.replay` 同步支持跨进程冷重启持久化状态重演校验。
- **表驱动规则与独立账本**：[online_rules.json](../data/online_rules.json) `pvp` 段定义三模式参数、段位阈值、赛季及荣誉兑换目录；迁移 `011_online_pvp_arena.sql` 新增 `pvp_seasons`、`pvp_ratings`（`PRIMARY KEY (character_id, mode, season_id)` 保障三模式段位/胜负/连胜严格隔离）、`pvp_honor_wallets`、`pvp_honor_ledger`（只追加防篡改触发器与数据库最小权限禁止删改）、`pvp_queues`、`pvp_challenges`、`pvp_matches` 与 `pvp_match_participants`（全库 **54 张表**）。
- **网关接口**：
  - `GET /v1/pvp/overview?mode=1v1|2v2|3v3`：当前赛季、三模式各自独立积分/段位、荣誉点及每周荣誉上限（`weekly_honor_cap=300`）、匹配队列、待响应切磋邀请、活跃战局、最近对局及分模式榜单。
  - **好友切磋（全三模式、不计分）**：`POST /v1/pvp/challenges` 与 `POST /v1/pvp/challenges/{id}/respond` 核验双方好友且非屏蔽、双方（及 `2v2`/`3v3` 队伍）人数匹配对应模式，完成后零积分变动。
  - **独立排位（预组与随机补位）**：`POST /v1/pvp/queue/join`（`allow_random_fill`）与 `POST /v1/pvp/queue/leave` 支持 `1v1` 单人、`2v2` 预组 2 人或允许补位的单人、`3v3` 预组 3 人 / 2+1 补位 / 全散人补位；严格阻止人数不齐（如 2 打 1）、同账号自排与互屏配对。
  - **战局驱动、超时默认动作、断线保护与权威回放**：`GET /v1/pvp/matches/{id}`、`POST /v1/pvp/matches/{id}/ready`、`POST /v1/pvp/matches/{id}/command`、`POST /v1/pvp/matches/{id}/tick`（超出 `turn_timeout_ticks=450` 即 15 秒时自动写入 `timeout_default` 防卡死）、`POST /v1/pvp/matches/{id}/connection`（`disconnected`/`reconnected` 切换 `safe_defend`；掉线/弃权方正常扣分，配合的随机补位队友享保分机制）、`POST /v1/pvp/matches/{id}/forfeit`、`GET /v1/pvp/matches/{id}/replay`（重演全部 `battle_inputs` 并核对 `replayed_hash == expected_hash`）、`POST /v1/pvp/season/claim` 与 `POST /v1/pvp/honor-shop/buy`。

## 玩家隐私自助与回环运维治理（L6 接入）

清单公布 `account_privacy` 功能位后，账号与运维边界扩展如下（全库 **56 张表**，迁移 `012_online_privacy_ops.sql` 新增 `accounts.status/erased_at`、`account_privacy_requests` 与只追加防篡改 `moderation_actions`）：
- **玩家数据导出与不可逆擦除**：
  - `GET /v1/account/privacy/summary`：返回账号状态、角色与安全通知摘要。
  - `GET /v1/account/privacy/export`：导出个人账号、角色、钱包、安全通知与最近审计记录（严格不含 `password_hash`、`recovery_salt`、`recovery_hash`），并记录 `account_privacy_requests`（`export`）。
  - `POST /v1/account/privacy/delete`：要求口令验证及 `confirmation == "DELETE"`；拒绝仍有活跃/未确认战斗、寄售挂单或进行中交易的账号；原子完成会话吊销、房间租约失效、秘境/演武排队与好友屏蔽清理、角色匿名软删（`已注销_...`）与账号擦除（`status='erased'`）；此后任何登录、刷新、找回或原令牌请求一律返回 `401`。
- **受令牌保护的回环运维接口（仅绑定 `AdminListen`，不进入游戏公开路由）**：
  - `GET /ops/reports`（支持 `?status=open|resolved`）：查看玩家举报及最新处分结果。
  - `POST /ops/reports/{id}/resolve`：记录处分决定（`dismissed` / `warned` / `muted` / `suspended`）至仅追加触发器保护的 `moderation_actions` 表，并记入 `audit_events`。
  - `GET /ops/capacity`：返回当前有效会话、分线/分图人数统计、活跃战斗/秘境/演武队列数、未处置举报及寄售开关状态。
  - `POST /ops/config/market-pause`：支持在不重启进程的前提下紧急暂停/恢复寄售与市场交易，并记入审计事件。

房间租约不授予战斗所有权；战斗接口每次仍重新验证账号、当前有效会话及选中在线角色。角色有未完成战斗或未确认结算时，不能切到别的角色或删除该角色。

## 战斗、结算与恢复

`data/online_rules.json` 是当前测试目标、距离、金币和阅历奖励的来源。玩家须持有效城镇租约并靠近目标。战斗初始职业、等级、怪物、随机种子、内容/规则版本和奖励规则在数据库创建，客户端不能提交这些字段。当前测试没有宠物、装备、补给成长或多人协作；药品数量为零，物品指令由权威模拟拒绝。

客户端只发 `attack/skill/potion/flee`。网关为每条输入分配连续序号和服务器时钟对应的 tick，将意图写入当前事务，调用私有 Godot 执行，再将 `accepted/reason/applied_tick`、最新快照和已确认序号提交。响应中的 `last_input` 用于展示冷却、条件不足或成功；`state` 只供表现，不作为客户端可回传的战果。

Godot 进程不连接数据库。网关提供已提交输入前缀、tick 和状态摘要；缓存含有未提交指令或超前时钟时，先从种子重建并校验前缀，再执行新指令。已提交输入的结果或状态摘要不一致时拒绝继续，不能静默换战果。战斗进程 epoch 改变后从数据库重建，按已确认 tick 暂停服务中断的时间，避免恢复时让玩家承受无法操作的攻击。快照/输入与版本必须匹配；跨版本在途战斗不会自动迁移。

终局只接受签名私有进程返回的 `victory/defeat/flee/draw`。同一数据库事务中写入唯一 `battle_results`、必要的首胜 claim、在线钱包/阅历、不可变账本和指令回执。任一步失败全部回滚；同一请求重试返回原回执。训练野狼采用每角色每目标一次奖励；重复通关仍有战果，但不再增加金币和阅历。结算回执含 `result_id,gold,experience,wallet_balance`，余额是当次结算时的余额。

未确认的结算继续由 `/active` 返回，重新登录后也能恢复显示。确认回执后才能开下一场。确认不发奖；战斗结果、发奖记录和回执不会因客户端关闭或请求重放而删除。战斗进程缓存闲置五分钟会清理，后续访问通过持久化输入恢复，不把内存缓存当持久化来源。

私有 RPC 只绑定回环，采用 HMAC-SHA256、随机 nonce、30 秒时间窗、内容/规则版本守卫和 2MiB 帧上限。密钥只通过服务器进程环境传递，不进入客户端、命令行或日志。这个进程间边界仍需同机操作系统权限隔离；尚未实现跨主机调度。

## 错误与重试

400：字段、内容、昵称、移动判定或请求标识错误；401：会话/令牌/恢复凭证无效；404：没有权限或角色/战斗/通知不存在；409：内容版本冲突、角色上限、昵称占用、请求标识内容冲突、旧租约、未完成战斗；429：认证/找回/移动/战斗指令限流；500/503：服务/数据库/权威进程故障。角色、通知和战斗写操作在超时或 5xx 后沿用原请求标识；密码找回和恢复码更新按上面的响应中断流程处理。网络故障不能伪装为移动违规。所有 JSON 请求必须是单个对象，`null`、数组、未知字段和多个对象不作为合法指令。

## 尚待接续

就绪/私有指标与 TLS 验证见[运维说明](online-operations.md)，上线发布、加密备份与外部验收阻塞清单见 [L6 发布清单](l6-release-checklist.md)。管理指标与 `/ops/*` 治理接口仅在受令牌保护的回环监听中提供，游戏公开接口不暴露它；管理令牌不能用游戏令牌替代。单机会话不能成为在线认证，客户端 GM 不提供任何服务端权限。公网主机部署、正式 CA 证书、异网真机广域网、外部值班告警送达与异地 PITR 演练受外部环境阻塞，已作为发布前提登记在发布清单中。
