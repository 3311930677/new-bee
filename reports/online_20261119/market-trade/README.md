# 2026-11-19 L3 市场沙盒、材料/装备寄售与面对面交易验收归档

- market/: erify_market_l3.py --capture (52ff28df1de941299f14a4f28ceb170f)，含双端 NPC 保底购入、M1 材料部分成交/撤单退回与邮箱领奖、同账号自买拦截告警、M2 未绑定锻造武器寄售与词条传承、M3 好友面对面报价修改清确认与原子交割，及 40 表恢复与 market-board.png/ace-trade.png。
- 
oom/: erify_room.py (76726a86a414dfa975420951e7cf33d)，30/30 通过。
- coop/: erify_coop_l2.py (cf460691f3ed41dabb1eef2378bfc2b8)，40 表无回退复验通过。
- social/: erify_social_l1.py (208f8c4ea3c24e9794b20f3db6eef6d5)，40 表无回退复验通过。
- world/: erify_world_l1.py (5b31f7e1cc09408ca38a6ff33f3a51ab)，40 表无回退复验通过。
- journey/: erify_journey.py (21cd3f2c1be401b8906b5ba0fb0526b)，40 表双端旅程 6/6 无回退复验通过。
- go-integration.jsonl: dev.py test **70/70** 通过（含 M0 沙盒闸门、M1/M2 竞态买单撤单互斥与 pack_full 保护、M3 面对面重确认与全局金币/物品严格守恒校验）。
