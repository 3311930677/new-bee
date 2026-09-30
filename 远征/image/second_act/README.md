# 第二幕重绘素材

所有 source/ 母稿使用本次已授权的 imagegen 工作流生成，保留透明 alpha。运行时使用打包后的 ready/ 与 main_world/ 图片。

| 母稿 | 运行时文件 | 打包规则 |
|---|---|---|
| mon_salt_crab.png | image/main_world/mon_salt_crab.png | pack_static_sprite.ps1，256×160，脚底156 |
| city_port_hall.png / warehouse / market / kennel | image/generated_342_353/ready/city_buildings/city_port_*.png | pack_static_sprite.ps1，256×192，底缘188；场景统一0.75倍 |
| npc_harbormaster_idle.png / npc_port_trader_idle.png / npc_port_keeper_idle.png / npc_port_worker_idle.png | image/generated_201_333/ready/npcs/ 同名图片 | pack_npc_idle.ps1，512×128四帧，各帧脚底123，0.72倍，与旧NPC相同 |

机械打包只取 alpha 可见范围并以最近邻缩放，未改变设计内容。NPC 对话头肩图由同一待机条首帧 AtlasTexture 裁切，不混用另一人物立绘。建筑名字牌按表内 art_visible_height 放在实际屋顶上方；基座碰撞与原有建筑规格保持一致。NPC 站位已经移出基座，留在主街两侧。

资源存在契约由 VerifyAssets 从沉渊港配置推导，实际帧条/贴图挂接、NPC脚点避让与盐甲蟹地图精灵由 VerifySecondAct 验证。实机截图见 tools/_logs/second_*_review.png。
