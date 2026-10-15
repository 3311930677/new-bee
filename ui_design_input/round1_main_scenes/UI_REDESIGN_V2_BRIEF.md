# 远征 UI 重做方案 v2：先定目标效果图，再从零搭建

> 日期：2026-10-13
> 起因：前几轮一直在旧页面上替换按钮和框体，构图、背景、信息层级都沿用旧版，上限就是"整洁一点的独立游戏"。
> 新做法：不再修旧页面。先为每个核心页面生成一张**完整的目标效果图**，确认后按效果图切素材、从零写新页面，旧页面直接替换掉。

---

## 1. 流程

| 步骤 | 谁做 | 产出 |
|---|---|---|
| 1. 效果图 | 你生成 | 每个页面 1 张完整的竖屏效果图（第 4 节），可多出几版挑选 |
| 2. 定稿 | 一起 | 每页选 1 张作为目标，标出要改的地方 |
| 3. 拆件 | 你生成 / 我切图 | 按定稿效果图的画风生成组件表；能直接从效果图上切的部分由我切 |
| 4. 搭建 | 我 | 新写页面场景，布局、层级、动效对照效果图实现 |
| 5. 验收 | 我 | 游戏内截图与效果图并排对比，差距大的地方继续改 |

只有效果图定稿后才开始写代码，避免再出现"边做边猜目标"的情况。

---

## 2. 美术方向（新定，不沿用旧版）

**定位**：东方边塞幻想 × 高精度像素 RPG。参考成熟手游的标准：一屏一个视觉焦点、清楚的主次层级、有世界观的材质与装饰、每个按钮都有分量。

**画面质感**
- 场景与角色：精细像素画（不是粗颗粒复古风），有体积光、空气透视、前中后景三层。
- UI：**高精度像素 UI**，比场景像素更细，接近原生分辨率。成熟像素手游普遍这样处理：世界是像素画，UI 是精致的像素装饰框，不追求和地图同样的粗颗粒。
- 材质：乌金铸铁、鎏金铜饰、朱漆、乌木、宣纸、玉石。金属有高光和磨损，漆面有包浆。
- 光：暖色主光（灯火、夕照）对冷色环境（夜色、雾）。重要按钮和稀有物品有自发光。

**色彩**
- 主色：乌金黑 `#1a1418`、朱漆 `#7a1f17`、鎏金 `#d8a85a`。
- 点缀：玉青 `#3f8f7a`、月白 `#e8dcc0`。
- 稀有度：灰 / 绿 / 蓝 / 紫 / 金，用于边框、底光和粒子颜色。

**字体与文字**
- 标题用书法体（现有"远征"字标保留并加金属质感）。
- 正文用衬线宋体，所有文字要有暗色描边或底托，不能直接压在花背景上。

---

## 3. 各页面的新结构（从零设计，不参照旧布局）

### 3.1 标题页（合并登录）
商业手游通行结构：**全屏主视觉 + 点击开始**，不再是一排菜单按钮。
- 全屏主视觉：主角与三位旅人站在边城城楼前，夕照逆光，旗帜飘动。人物占画面下半部。
- 顶部居中：书法字标"远征"，鎏金质感，底下小字"昭元行旅录"。
- 底部：一行"点击屏幕开始旅程"，呼吸闪烁。
- 角落小图标：左上公告，右上设置 / 账号，左下版本号。
- 登录不再是单独页面：点击后从底部升起一张卷轴式弹窗，内有账号、密码、游客进入。

### 3.2 主页（营地）
- 背景：营地夜景全屏，主角居中站在篝火旁，火光把角色照亮。角色是唯一视觉中心。
- 顶部栏：左边圆形头像徽章（等级在徽章下沿），右边 3 个货币胶囊（金币 / 魂晶 / 荣誉），带"+"号。
- 左侧：1~2 张**活动横幅卡**（有插画的小长图），比如"限时活动""主线进度"。
- 右侧：一列圆形图标入口（竞技、召唤、兑换、小聚），带红点。
- 底部：雕花导航栏，5 个页签，**正中是突出的大圆形"出征"按钮**，比导航栏高出一截，鎏金环、内有动态光。

### 3.3 角色 / 养成
- 左 2/3：角色大立绘站在展示台上，背后有职业纹章与光柱。
- 右侧或底部：**战力数字**（大号金色数字）+ 核心属性 4 项。
- 下方：6 条养成线做成带图标和进度环的卡片网格（装备、天赋、技能书、宠物、坐骑、称号）。

### 3.4 装备
- 中间：角色站在台上，**6 个装备槽围绕角色**（纸娃娃布局），槽位按稀有度显示边框与底光。
- 底部弹出：选中装备的详情卡，有名称（稀有度颜色）、主属性、强化等级、强化 / 宝石 / 精炼三个按钮。
- 强化成功、获得高稀有度装备时有专门的演出：光柱、粒子、物品放大落下。

### 3.5 世界地图入口
- 全屏手绘地图，区域节点是带旗帜的城标，已解锁的亮、未解锁的蒙雾。
- 底部：区域卡片，左边插画缩略、右边名称 / 等级 / 推荐战力，大号"出发"按钮。

---

## 4. 效果图生图需求

**通用规格**
- 画布 1024×1536（竖屏）。游戏比例是 3:5，比画布窄，所以**所有 UI 必须放在中间约 920 像素宽的范围内**，左右两边只放背景（会被裁掉或在宽屏上露出）。
- 内容是**一张完整的游戏截图效果**，包含背景、角色、全部 UI、文字示例。文字可以用中文示例词，但不要求字形准确，定稿后我会换成真实字体。
- 不要参考旧截图。附图只附角色参考（保证主角长相一致）。

**附图**
- 主角参考：`_review/ui_kit/style_ref_character_x4.png`（主角像素立绘放大 4 倍）。

**通用前缀**

```text
A finished in-game screenshot of a commercial-quality portrait mobile RPG (1024x1536), the kind of polished UI seen in top-grossing mobile fantasy games. Art style: high-detail pixel art for the world and characters, with refined high-resolution pixel UI ornaments. Setting: an East-Asian frontier fantasy (ancient border fortress, bronze and red lacquer, lanterns, jade, parchment). Palette: black-gold iron, deep red lacquer, warm gilded bronze, jade accents, moon-white text; warm lantern light against cool night or dusk.
Clear visual hierarchy: one dominant focal point, strong primary action, generous spacing, every panel has material (forged iron, gilded bronze trim, lacquered wood, parchment), ornamental corners, inner bevels, soft glow on key elements. No flat grey boxes, no default rectangles, no plain web-style buttons.
Keep all UI inside the central 920 px width. The hero character must match the attached sprite reference (red-haired armored swordsman with a red cape).
```

**各页（接在前缀后面）**

| 编号 | 页面 | 提示词 |
|---|---|---|
| M-01 | 标题页 | `Title screen. Full-bleed key art: the red-haired hero and three companions (an archer, a frost mage, a lantern-bearing priest) standing on a fortress wall at sunset, backlit, banners in the wind, distant mountains in haze. Large gilded calligraphy logo "远征" at the top with a small subtitle "昭元行旅录". Near the bottom a softly glowing line "点击屏幕开始旅程". Small ornate icon buttons: notice at top-left, settings and account at top-right; tiny version text bottom-left. No menu button list.` |
| M-02 | 登录弹窗 | `The same title key art dimmed, with an unrolled ornate scroll panel rising from the bottom: gilded bronze rollers, parchment body, title "旅人登记", two inlaid input fields (account, password), a large red-lacquer gold-trimmed button "进入边城" and a smaller iron button "游客进入".` |
| M-03 | 主页 | `Home camp screen. Full-screen night camp with a bonfire; the hero stands centre-front lit by firelight, clearly the focal point. Top bar: round gilded avatar badge with level, three currency capsules with icons and "+" on the right. Left side: two small illustrated event banners. Right side: a column of four round ornate icon buttons with red notification dots. Bottom: a carved black-gold navigation bar with five tabs; the centre tab is a large raised circular gilded "出征" button with a glowing core, taller than the bar.` |
| M-04 | 角色养成 | `Character growth screen. The hero stands on an ornate stone pedestal with a class emblem and a soft light pillar behind him, occupying the left two thirds. A large golden power number "战力 12,480" with four key stats. Below, a 3x2 grid of ornate growth cards (equipment, talents, skill books, pets, mounts, titles), each with an icon, name and a small progress ring.` |
| M-05 | 装备 | `Equipment screen. The hero stands centre on a pedestal; six equipment slots arranged around him (weapon, armor, helmet, boots, ring, amulet), each slot framed by rarity colour with a soft inner glow, one legendary gold slot glowing brightest. A bottom sheet shows the selected item's detail card: item name in rarity colour, main stats, "+12" enhance level, and three ornate buttons "强化" "宝石" "精炼".` |
| M-06 | 世界地图 | `World map entry screen. Full-screen illustrated pixel-art map of frontier regions with rivers, mountains and forts; region nodes are small fort icons with banners, locked regions under drifting fog. A bottom card: illustrated region thumbnail on the left, region name, level range and recommended power on the right, and a large red-lacquer gilded "出发" button.` |

**优先顺序**：M-03 主页 → M-01 标题 → M-05 装备 → M-04 养成 → M-06 地图 → M-02 登录。主页是玩家停留最久的地方，先把它定下来，整套 UI 的风格就跟着定了。

**每页建议出 2~3 版**，挑最好的一张定稿。

---

## 5. 定稿之后我做什么

1. 把效果图里的组件（框体、按钮、横幅、图标座、导航栏、卡片）整理成组件表需求，按效果图画风生成，或直接从效果图上切。
2. 为每个页面新建场景文件，按效果图搭建：布局、层级、文字、动效（入场推入、主按钮呼吸光、点击粒子、稀有度光效）。
3. 旧页面保留到新页面通过验收后再删除，游戏流程和存档不受影响。
4. 每页验收时把游戏截图和效果图并排对比，差距明显的地方继续改。

---

## 6. 需要说明的限制

- 效果图里的文字、数字只是示意，最终用游戏字体渲染。
- 效果图里的角色只用来定构图；游戏里仍然用现有的角色像素素材，除非之后另外出新立绘。
- 效果图是"目标"，不是可以直接贴进游戏的图。最终页面由组件拼成，才能缩放、点击、做动效。
