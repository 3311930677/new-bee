# L1-C 好友、屏蔽、举报、聊天与真正组队

本批（L1-C）补齐 L1 剩余全部核心能力：迁移 `007_online_social_parties.sql`（新增 `friend_requests`、`friendships`、`player_blocks`、`player_reports`、`chat_messages`、`parties`、`party_members`、`party_invites` 8 张表，数据库最小权限与只读备份恢复扩展至 **28 张表**；`player_reports` 与 `chat_messages` 追加不可变触发器并禁绝 runtime `UPDATE/DELETE`）、好友申请/接受/拒绝/删除、账号级双向屏蔽与关系清理、持久化举报、分频道/附近 480px/队伍/私聊聊天及服务端屏蔽过滤、以及 4 人组队完整生命周期（创建、邀请、接受/拒绝、准备状态、队长移交、踢人、离队自动递补与解散，含删除角色自动离队），并完成 [OnlineSocialPanel.gd](../../../远征/src/ui/OnlineSocialPanel.gd) 客户端集成。详见[验收索引](verification.json)。

- **Go / PostgreSQL 完整套件**：**64/64 通过，退出码 0**（含新增 `TestFriendsBlockReportAndChatFiltering`、`TestPartyCreateInviteReadyLeaderTransferKickAndCapacity` 及 `dbops` 28 表权限/备份验证），见 [go-integration.jsonl](go-integration.jsonl)。
- **独立 Godot 权威检查**：`room_3131c5ab3f384990ae899210e98b3336` **29/29 通过，退出码 0**，见 [room/report.json](room/report.json)。
- **双真实 Godot 客户端 L1-C 验证**：`social_l1_3d0bb4230ff94b8c855c5423de016abf`（最终源码指纹 `c99c5b35a84b96b78edc5c98104a85d7301dfa3fa9840d3cb6b2a91b0119894a`，含 `ui_cancel` 关窗保留城镇租约实测与 28 表恢复）通过，两端退出码 `0`；目检社交组队界面截图见 [social/social-party.png](social/social-party.png)。
- **L1-B / L1-A / L0-H 双端与 28 表恢复验证**：`world_l1_2b6d3ce0ef1a473a9c17fb251246760f`（28 表恢复）、`positions_09b418562bd945caaafb870c92ccbaed`、`journey_d791908924a4475e96c56e3a97a50523`（**6/6**，28 表恢复）均通过且退出码 `0`。
- **完整 79 项单机回归**：最终轮 **79/79 PASS (`ALL GREEN`)，退出码 `0`**，见 [l1-regression](../l1-regression/README.md)；首轮 `VerifyNav` 拦截失败（78/79，退出码 `1`）完整保留于 [l1-regression-first](../l1-regression-first/README.md)。
