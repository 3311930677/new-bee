# 音频素材目录（放这里就自动生效）

程序按**文件名**寻址（`Audio` 自动加载器），依次尝试 `.ogg` / `.wav` / `.mp3`；
找不到就静默跳过，不报错。音量与静音在游戏内「设置 → 声音」里调，存进存档。

## 需要的文件名

| 文件名 | 用途 | 建议时长 |
|---|---|---|
| `bgm_home.ogg` | 主城 / 营帐主页 BGM | 60~120s 可循环 |
| `bgm_title.ogg` | 标题界面 BGM | 60~120s |
| `bgm_city.ogg` | 主城据点（可行走）BGM | 60~120s |
| `bgm_route.ogg` | 路线图 BGM | 60~90s |
| `bgm_map.ogg` | 探索地图 BGM | 60~90s |
| `bgm_battle.ogg` | 战斗 BGM | 60~90s，节奏更紧 |
| `ui_click.ogg` | 全局按钮点击音（金色按钮与「?」已接） | 0.1~0.3s |

再加音效只需在代码里调 `Audio.sfx("名字")`，文件同名放进来即可。

## 推荐的免费素材来源（都能商用）

| 来源 | 协议 | 说明 |
|---|---|---|
| [Kenney](https://kenney.nl/assets?q=audio) | **CC0** | 项目里已在用他的 UI 素材（`ui_kenney/`）。推荐包：*Interface Sounds*（UI 音效）、*RPG Audio*（打斗/脚步）、*Music Jingles*（短过场） |
| [OpenGameArt](https://opengameart.org/art-search-advanced?license%5B%5D=17981) | 多为 **CC0** | 按 CC0 过滤后搜 "medieval loop" / "fantasy loop"，能捡到循环 BGM |
| [FreePD](https://freepd.com/) | 公共领域 | 按情绪分类的公共领域音乐，无需署名 |
| [Pixabay Music](https://pixabay.com/music/) | Pixabay 许可 | 免费商用、无需署名（非 CC0，但够宽松） |

> 注意：**Incompetech（Kevin MacLeod）是 CC-BY**，用了必须在游戏内标注作者，能避则避。
> 若确实要用 CC-BY / CC-BY-SA 素材，请在本文件里追加一条署名记录（作者 · 曲名 · 协议 · 来源链接）。

## 音量默认值

音乐 70%、音效 80%（`G.audio`，见 `src/autoload/G.gd`）。
