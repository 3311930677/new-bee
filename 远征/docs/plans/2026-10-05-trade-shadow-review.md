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

建筑与道具保留原图。根据透明轮廓生成有限的压缩、倾斜投影，统一向右下延伸。可见底缘另生成较浓的短接触阴影，避免透明画布留白导致影子与物体脱开。投影外沿仅保留一像素过渡，使用最近邻采样，并按纹理/尺寸缓存。

城内建筑保留原有地基接触与磨损效果，替换投影层。商路摊位、路牌与图集道具使用同一轮廓投影；移除这些对象旧的通用椭圆影以避免叠影。这是为既有像素素材设计的视觉近似，不是三维建筑光照模拟。

## 验证

CaptureTradeShadow 遍历五个交易点、三页及规则页，检查 480×800 与 480×1067 布局，并实际验证按钮买入、卖出、缺货回滚、差事、换日与运单接取。截图位于 shots/trade_shadow_20261005。

既有回归七项通过：VerifyCity、VerifyWorldSession、VerifyEconomy、VerifyTradeWorld、VerifyShipping、VerifyFrostHerbOrder、VerifyTradeContracts。

引擎退出时的资源释放诊断属于项目已有 issue #43，既有回归运行器会单独记录；本次没有交易、布局或运行中脚本错误。
