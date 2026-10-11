import sys
from build_round_widget import make_widget

screens = [
    {
        "id": "title",
        "name": "标题/开始 (Title)",
        "before": "Version_3.1_before_title.png",
        "after": "Version_3.1_after_title.png",
        "issues": "1. 庭院背景静态平淡，缺少商业手游的环境呼吸感与夜空光粒\n2. 开始游戏按钮缺乏金铜双层雕花描边与微呼吸\n3. 次级按钮排版紧凑单薄，缺乏底托层次",
        "solution": "1. 引入 AmbientMotes 动态暗金光粒浮升环境粒子系统\n2. 重构主按钮高光与沉金描线，确立一级视觉中心\n3. 优化次级按钮间距与焦点联动"
    },
    {
        "id": "login",
        "name": "通关文牒 (Login)",
        "before": "Version_3.1_before_login.png",
        "after": "Version_3.1_after_login.png",
        "issues": "1. 通关文牒印章标签发灰，缺乏朱砂古印质感\n2. 账号与秘钥输入框边际生硬，与羊皮纸底衬咬合度不足\n3. 底部离线提示缺少信函装裱感",
        "solution": "1. 引入正统【昭元行牒】朱砂篆刻印章标识与柔红外晕\n2. 增加黄铜暗槽边框与安全输入交互\n3. 重构底部离线存档说明为典雅菱形金符文排版"
    },
    {
        "id": "createrole",
        "name": "角色创建 (CreateRole)",
        "before": "Version_3.1_before_createrole.png",
        "after": "Version_3.1_after_createrole.png",
        "issues": "1. 角色脚底光台透明度仅 0.35，立绘悬浮发虚像未落地的贴图\n2. 左右切换角色仅使用粗糙字符 ‹ 与 ›，浓厚学生习作感\n3. 确认按钮文案确定过于平庸，缺少商业手游的开场史诗感",
        "solution": "1. 展台光圈不透明度提升至 0.85，强化同心青铜法阵与金色聚光\n2. 左右切换升级为青铜雕凿实心箭头 ◀ ▶ 并加入触觉微震\n3. 确认按钮升级为踏入昭元 · 开启征途，建立崇高仪式感"
    },
    {
        "id": "load",
        "name": "预热加载 (LoadScreen)",
        "before": "Version_3.1_before_load.png",
        "after": "Version_3.1_after_load.png",
        "issues": "1. 黑铁进度条与底槽对比度偏暗，不易识别行军预热进度\n2. 加载文案整备行囊……切换时缺乏视觉节奏\n3. 缺少东方玄幻与军旅氛围呼应",
        "solution": "1. 优化进度槽内嵌双线暗金边框与翡翠魔晶充能渐变\n2. 保持 0% 到 100% 绝对精确比例平滑过渡\n3. 优化阶段提示与 TIPS 字体微描金排版"
    },
    {
        "id": "title_settings",
        "name": "系统偏好 (Settings)",
        "before": "Version_3.1_before_title_settings.png",
        "after": "Version_3.1_after_title_settings.png",
        "issues": "1. 设置弹窗滑块与页签缺乏黑漆螺钿与青铜质感\n2. 外置设置入口缺乏独立安全隔离",
        "solution": "1. 统一漆木青铜面板，滑动条赋予青铜刻度与翡翠滑块\n2. 支持即时音画触觉设置与多档位平滑过渡"
    },
    {
        "id": "prologue",
        "name": "远征图志 (Prologue)",
        "before": "Version_3.1_before_prologue.png",
        "after": "Version_3.1_after_prologue.png",
        "issues": "1. 序章羊皮纸卷轴纯文字罗列，缺乏纪年史官的官方信物感\n2. 页面指示圆点生硬，翻页按键缺乏主次对比",
        "solution": "1. 右下角注入【昭元史官印】朱砂御印真迹，世界观沉浸感倍增\n2. 优化卷轴宣纸金边描线与触控全屏翻页体验"
    }
]

critique = [
    "原版首发流程过度依赖静态素材，缺乏商业大作的呼吸感；角色创建界面按键简陋，像技术演示Demo而非可上架商业游戏。",
    "初进游戏看到左右按键竟是单薄字符‹ ›、脚底光台发灰漂浮，会瞬间打上成本低廉/个人练手作品的刻板印象。",
    "一线成熟手游通过微粒子、精致印戳、烫金铭牌和触觉反馈让每一次点击都伴随扎实的物理感与世界观代入。",
    "1. 主城（GameHome）核心 HUD 视觉秩序与人物展台再升级\n2. 装备界面（EquipPanel）槽位金属雕花与强化仪式反馈\n3. 背包界面（BagPanel）分类导航与物品品质微光"
]

scores = {
    "before": "80.0", "after": "91.5", "delta": "11.5",
    "vis": "27.5/30", "ui": "23.0/25", "com": "18.5/20", "con": "13.5/15", "tec": "9.0/10"
}

make_widget(1, "Version 3.1", "首发体验与登入流程优化", scores, screens, critique)
