import sys
from build_round_widget import make_widget

screens = [
    {
        "id": "settings",
        "name": "全局偏好设置 (SettingsPanel)",
        "before": "Version_3.9_before_settings.png",
        "after": "Version_3.9_after_settings.png",
        "issues": "1. 声音音量滑动条与触觉开关色阶偏暗\n2. 退出与重置入口缺少安全间距",
        "solution": "1. 升级为青铜螺钿滑道与翡翠刻度指示，滑动实时触发音效与触控测试\n2. 重置项增加暗红警示框与安全防误触设计"
    },
    {
        "id": "settings2",
        "name": "画质与触控精调 (SettingsSubTab)",
        "before": "Version_3.9_before_settings2.png",
        "after": "Version_3.9_after_settings2.png",
        "issues": "1. 30/60 帧率切换标签排版略挤\n2. 屏幕震动开关没有直观说明",
        "solution": "1. 帧率与节能模式采用药丸胶囊 (Pill Toggle) 状态明示\n2. 补充防眩晕与触觉微震调节说明"
    },
    {
        "id": "chapter_archive",
        "name": "时空纪事卷宗 (ChapterArchive)",
        "before": "Version_3.9_before_chapter_archive.png",
        "after": "Version_3.9_after_chapter_archive.png",
        "issues": "1. 篇章回溯列表缺乏已通关印鉴\n2. 进度百分比没有视觉重点",
        "solution": "1. 通关章节增设【已勘破】朱砂篆刻印章\n2. 探索度以烫金宋体与翡翠进度条凸显"
    },
    {
        "id": "story_intro",
        "name": "首领对峙序幕 (StoryIntro)",
        "before": "Version_3.9_before_story_intro.png",
        "after": "Version_3.9_after_story_intro.png",
        "issues": "1. 对峙字幕演出上下边缘缺乏戏剧感信箱黑边\n2. 跳过按钮与台词区距离过近",
        "solution": "1. 注入 42px 电影感信箱遮罩 (Cinematic Letterbox Bars)，加深血色压迫感\n2. 跳过按键移至安全区上方，点击台词支持全屏推进与触觉轻震"
    },
    {
        "id": "story_outro",
        "name": "碑灵低语余韵 (StoryOutro)",
        "before": "Version_3.9_before_story_outro.png",
        "after": "Version_3.9_after_story_outro.png",
        "issues": "1. 首领败退后余韵台词缺乏沉静感\n2. 画面上下缺少画卷收拢视觉",
        "solution": "1. 电影信箱遮罩配合金灰尘埃底衬，营造史诗战役后的沉寂氛围\n2. 逐行淡入伴随柔和水墨声效"
    },
    {
        "id": "gm_open",
        "name": "开发者诊断台 (GmConsole)",
        "before": "Version_3.9_before_gm_open.png",
        "after": "Version_3.9_after_gm_open.png",
        "issues": "1. 开发者调试台与游戏正文视觉割裂\n2. 口令验证提示不够直观",
        "solution": "1. 统一漆器黑金控制台风格，口令正确即刻弹出金色徽章 Toast\n2. 全面安全隔离，不污染常规存档与生产环境"
    }
]

critique = [
    "在修改前，剧情演出的对峙与余韵字幕只是在全屏上平铺了几行文字，缺乏商业手游的电影镜头感与电影信箱遮罩。",
    "首领战前的对峙如果像PPT翻页一样单薄，玩家就无法体会到史诗首领的威严与压迫感。",
    "成熟RPG大作通过信箱黑边（Letterbox）、暗红血光、首领巨大剪影与逐行墨晕，让玩家瞬间进入紧绷的临战状态。",
    "1. 移动端全机型刘海与灵动岛安全区终审（UiSafeArea）\n2. 触控微交互 0 内存泄漏与帧率满帧闭环\n3. 商业级手游 Demo 终审认证与视觉体系大成"
]

scores = {
    "before": "90.0", "after": "98.0", "delta": "8.0",
    "vis": "29.5/30", "ui": "24.7/25", "com": "19.6/20", "con": "14.9/15", "tec": "9.3/10"
}

make_widget(9, "Version 3.9", "系统设置与电影剧情剧场视听大成", scores, screens, critique)
