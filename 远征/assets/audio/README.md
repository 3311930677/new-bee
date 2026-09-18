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

音效（**18 个已全部就位**，程序合成，见下节；名字登记在 `Audio.SFX_NAMES`）：

- UI 七件：`ui_click` / `ui_open` / `ui_close` / `ui_page` / `ui_confirm` / `ui_cancel` / `ui_locked`
- 奖励三件：`coin` / `reward` / `level_up`
- 战斗八件：`hit_light` / `hit_heavy` / `hit_crit` / `skill_cast` / `boss_warn` / `low_hp` / `victory` / `defeat`

再加音效的流程：①在 `tools/make_sfx.py` 加一条合成函数（或手工放同名文件）→
②在 `Audio.SFX_NAMES` 登记（加载页预热与 `VerifyAudio` 都按这份清单走）→
③代码里 `Audio.sfx("名字")` 调用。

## 推荐的免费素材来源（都能商用）

| 来源 | 协议 | 说明 |
|---|---|---|
| [Kenney](https://kenney.nl/assets?q=audio) | **CC0** | 项目里已在用他的 UI 素材（`ui_kenney/`）。推荐包：*Interface Sounds*（UI 音效）、*RPG Audio*（打斗/脚步）、*Music Jingles*（短过场） |
| [OpenGameArt](https://opengameart.org/art-search-advanced?license%5B%5D=17981) | 多为 **CC0** | 按 CC0 过滤后搜 "medieval loop" / "fantasy loop"，能捡到循环 BGM |
| [FreePD](https://freepd.com/) | 公共领域 | 按情绪分类的公共领域音乐，无需署名 |
| [Pixabay Music](https://pixabay.com/music/) | Pixabay 许可 | 免费商用、无需署名（非 CC0，但够宽松） |

> 注意：**Incompetech（Kevin MacLeod）是 CC-BY**，用了必须在游戏内标注作者，能避则避。
> 若确实要用 CC-BY / CC-BY-SA 素材，请在本文件里追加一条署名记录（作者 · 曲名 · 协议 · 来源链接）。

## 当前已放入的素材

### BGM（临时占位，只为"先听见声"）

| 文件 | 来源 | 协议 |
|---|---|---|
| `bgm_home.ogg` | Godot 官方示例 `2d/dodge_the_creeps/art/House In a Forest Loop.ogg` | CC0 |
| `bgm_battle.ogg` | Godot 官方示例 `2d/physics_platformer/audio/music.ogg` | CC0 |

| `bgm_title.ogg` | 同上 `3d/truck_town/town/sound/mood_sunrise.ogg`（清晨/开场） | CC0 |
| `bgm_city.ogg` | 同上 `mood_day.ogg`（白昼/据点，轻快） | CC0 |
| `bgm_route.ogg` | 同上 `mood_sunset.ogg`（黄昏/行军） | CC0 |
| `bgm_map.ogg` | 同上 `mood_night.ogg`（夜晚/探索，幽静） | CC0 |

直链前缀 `https://raw.githubusercontent.com/godotengine/godot-demo-projects/master/`。
六首都只是临时件（曲风与《远征》不搭，四首 mood_* 是卡车小镇的氛围曲），
定版请换成上面推荐来源的素材或自己生成；替换时保持同名即可，代码不用动。

### 音效（18 个 · 项目自产：程序合成）

`tools/make_sfx.py` 用 numpy 合成（44.1kHz / 16-bit / 单声道 WAV），风格走
**木质 / 羊皮纸 / 克制**——UI 音峰值压低一档，战斗音允许更脏更重。无第三方版权。

- 可**反复生成**（同名覆盖）：`python tools/make_sfx.py`
- 重生成后必须让引擎重新导入：`godot --headless --path . --import`
- 运行时由 `src/autoload/Audio.gd` 的音效池播放（8 个播放器轮转 + ±3% 随机音高）

## 音量默认值

音乐 70%、音效 80%（`G.audio`，见 `src/autoload/G.gd`）。
