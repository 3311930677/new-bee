# 商路账册与贴地阴影

## 界面

- 商路分为货市、运单、驿站三页，共用钱囊、行囊与游戏日状态栏。
- 货市保留四类货品报价、当日库存/收购额度、数量与买卖操作。近五日中价使用带数值的折线。
- 运单集中展示起终点、实际持货/需求、净报酬、经验、期限与当前可用操作。三城合约、霜关条款入口保留。
- 驿站集中展示歇脚换日与每日差事；完成的差事按钮禁用。
- 右上角问号打开当前页的规则，正文可以滚动；不推进游戏日或更改玩家进度。
- RewardLedger 的缺货提示通过宿主的 item_name 取得中文名称；无此接口的测试宿主使用“所需物品”。货币名称同时改为中文。

## 阴影参考

1. Unity 官方 Happy Harvest 俯视角游戏示例：
   https://discussions.unity.com/t/2d-light-and-shadow-techniques-with-the-universal-render-pipeline/1641848
   参考其对投影、接触阴影与美术光照的一致性处理。该文说明 blob shadow 适合低成本贴地效果，阴影轮廓与受光应结合素材本身。
2. Godot 官方 2D lights and shadows：
   https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html
   DirectionalLight2D 的无限长度阴影不适合这里的有限建筑投影；像素画的阴影还需保持匹配的采样风格。

## 实现选择

建筑与道具保留原图。以显示尺寸逐列读取 alpha ≥ 0.5 的可见底缘，只让靠近地面的轮廓参与接触。接触影最深处紧贴底座，外侧两像素迅速减弱；城门两座塔脚分别生成，不补平门洞。透明画布留白不参与接地带宽度和投影长度计算。

短投影沿实际底缘统一向右下延伸，近端较深、末端渐弱，外沿保留一像素过渡并使用最近邻采样。移除旧的大块地表磨损色斑与全图压扁投影。商路摊位、路牌、图集道具、地图怪物和宝箱/商店/营火共用这一处理；怪物双脚保留各自的接触影，替代偏离脚底的椭圆。缓存键包含图集区域和边距，防止同尺寸物件误用另一张底座。这是既有像素素材的视觉近似，不是三维光照模拟。

## 验证

CaptureTradeShadow 遍历五个交易点、三页及规则页，检查 480×800 与 480×1067 布局，并实际验证按钮买入、卖出、缺货回滚、差事、换日与运单接取。截图位于 shots/trade_shadow_20261005。

既有回归七项通过：VerifyCity、VerifyWorldSession、VerifyEconomy、VerifyTradeWorld、VerifyShipping、VerifyFrostHerbOrder、VerifyTradeContracts。

用户反馈后新增 CaptureGroundingReview：实际调用 CityScene._Building、MapScene._MapMonster 与商路实体，截图检查 11 种建筑、两种尺寸的僵尸、雪地建筑，以及城内城门/仓廪、地图僵尸和断碑营地。480×800 截图与三倍最近邻细节图位于 shots/grounding_review_20261005，final_* 为最后通过目视检查的版本。

检查脚本验证门洞不填影、双脚下一个像素已有接触、接触和投影向外减弱、低透明度残留不改变脚点、透明边距不改变接触位置或投影长度，以及同尺寸图集区域独立缓存。GROUNDING_REVIEW_OK。

阴影修正后的相关回归七项通过：VerifyCity、VerifyMapScene、VerifyMainWorld、VerifyWorldSession、VerifyTradeWorld、VerifyFrostArt、VerifyPerf。

引擎退出时的资源释放诊断属于项目已有 issue #43，既有回归运行器会单独记录；本次没有交易、布局或运行中脚本错误。
