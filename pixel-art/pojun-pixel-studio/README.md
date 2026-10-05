# 破军 · Pixel Art Studio 行走测试

采用 Gamezxz/pixel-art-studio：逐像素绘制与分层制作的技能工具。
项目地址：https://github.com/Gamezxz/pixel-art-studio
本地安装：D:/new-bee/tools/pixel-art-studio

本次输出：破军朝右的 8 帧行走，128×128 单帧，110ms/帧。

- comparison.gif：左侧静态原版与右侧动态试作。
- pojun_walk_right_8.png：1024×128 透明原尺寸精灵条。
- pojun_walk_right_8.json：帧区域、时长与 walk_right 动作标签。
- pojun_walk_right.gif：4 倍展示动图，背景仅用于预览。
- pojun_walk_right.pxproj.json：Pixel Art Studio 图层与帧项目。
- review.html：可直接在浏览器打开的对比预览。
- build.py：生成所有素材的源文件。

输入：游戏现用破军四向行走图的右向首帧。
保留原图上身、脸、发型、手和剑；拆开披风，并分别重设近腿与远腿。
膝甲与靴子沿用原图纹理，腿部关节和金属明暗带逐帧制作。
本次未使用 Stable Diffusion，也未使用其他图像生成模型。

技能的小色板默认没有套到原图上，以免改变现有游戏外观。
PNG 保留原版颜色和边缘透明度，GIF 因格式限制使用统一展示色板。

四方向已补齐并接入游戏：pojun_walk_4dir.png / pojun_walk_frames.tres。
四方向资源为 1024×512、每朝向 8 帧。four_directions.gif 展示全部朝向。
原来的单向试作文件仍保留，用于比较制作过程。
原版完整文件备份在 backup/，绘制时始终读取备份以保证可重现。
正式素材已替换；game image/role_pixel_studio/zs/original/ 提供原版对比资源。
游戏目录的“打开破军四方向试用.cmd”进入实际地图，空格可切回原版比较。
这是可评估的游戏内试作，前后方向的抬脚动作仍可继续精修。

重新生成：

```powershell
D:\anaconda\python.exe D:\new-bee\pixel-art\pojun-pixel-studio\build.py
D:\anaconda\python.exe D:\new-bee\pixel-art\pojun-pixel-studio\build_four.py
D:\anaconda\python.exe D:\new-bee\pixel-art\pojun-pixel-studio\install_four.py
```
