import os
import math
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw

OUT_DIR = "D:/new bee/showcase/assets"
os.makedirs(OUT_DIR, exist_ok=True)

TARGET_SIZE = (500, 888)

INPUTS = [
    {
        "id": "img1_home",
        "title": "营帐主页 · 行旅营帐",
        "before_path": r"C:/Users/Administrator/.gemini/antigravity/brain/51ddb207-600f-4110-af3c-d7395f7fbc70/.user_uploaded/media_1791431582637_603eb0e9.png",
        "clean_path": r"D:/new bee/远征/shots/main_ui_20261008/home.png",
        "light_center": (110, 520),  # campfire on left
        "light_color": (255, 145, 45),
        "light_radius": 240,
        "focal_center": (250, 470),
        "shadow_pos": (245, 625),
        "embers": [(115, 500), (135, 470), (125, 435), (155, 410), (195, 420), (250, 395), (170, 375), (220, 350)]
    },
    {
        "id": "img2_load",
        "title": "加载界面 · 霜羽执杖",
        "before_path": r"C:/Users/Administrator/.gemini/antigravity/brain/51ddb207-600f-4110-af3c-d7395f7fbc70/.user_uploaded/media_1791431607156_61f0bbdc.png",
        "clean_path": r"D:/new bee/远征/shots/main_ui_20261008/load.png",
        "light_center": (330, 440),  # ice crystal on staff
        "light_color": (70, 210, 255),
        "light_radius": 220,
        "focal_center": (240, 500),
        "shadow_pos": (200, 835),
        "embers": [(335, 415), (315, 390), (350, 375), (325, 350), (360, 440), (295, 430)]
    },
    {
        "id": "img3_title",
        "title": "标题界面 · 古道城门",
        "before_path": r"C:/Users/Administrator/.gemini/antigravity/brain/51ddb207-600f-4110-af3c-d7395f7fbc70/.user_uploaded/media_1791436395966_dc0447bf.png",
        "clean_path": r"D:/new bee/远征/shots/main_ui_20261008/title.png",
        "light_center": (250, 280),  # gate archway sunset
        "light_color": (255, 170, 60),
        "light_radius": 260,
        "focal_center": (250, 500),
        "shadow_pos": (250, 680),
        "embers": [(65, 710), (75, 675), (85, 640), (250, 280), (265, 260), (235, 295)]
    },
    {
        "id": "img4_intro_world",
        "title": "远征手记 · 世界卷",
        "before_path": r"C:/Users/Administrator/.gemini/antigravity/brain/51ddb207-600f-4110-af3c-d7395f7fbc70/.user_uploaded/media_1791431638961_6bbb549f.png",
        "clean_path": r"D:/new bee/远征/shots/main_ui_20261008/title_intro.png",
        "light_center": (250, 360),
        "light_color": (255, 235, 190),
        "light_radius": 280,
        "focal_center": (250, 440),
        "shadow_pos": (250, 780),
        "embers": []
    },
    {
        "id": "img5_intro_journey",
        "title": "远征手记 · 启程卷",
        "before_path": r"C:/Users/Administrator/.gemini/antigravity/brain/51ddb207-600f-4110-af3c-d7395f7fbc70/.user_uploaded/media_1791431654596_f7c5f555.png",
        "clean_path": r"D:/new bee/远征/shots/main_ui_20261008/title_intro_journey.png",
        "light_center": (300, 470),  # volcano on map
        "light_color": (255, 185, 95),
        "light_radius": 250,
        "focal_center": (250, 440),
        "shadow_pos": (250, 780),
        "embers": [(300, 450), (290, 435), (315, 420)]
    },
    {
        "id": "img6_login",
        "title": "通关文牒 · 旅人登记",
        "before_path": r"C:/Users/Administrator/.gemini/antigravity/brain/51ddb207-600f-4110-af3c-d7395f7fbc70/.user_uploaded/media_1791436406145_dafdc331.png",
        "clean_path": r"D:/new bee/远征/shots/main_ui_20261008/login.png",
        "light_center": (250, 240),
        "light_color": (255, 220, 150),
        "light_radius": 280,
        "focal_center": (250, 480),
        "shadow_pos": (250, 800),
        "embers": []
    }
]

def load_and_resize(path):
    im = Image.open(path).convert("RGBA")
    return im.resize(TARGET_SIZE, Image.Resampling.LANCZOS)

def create_radial_gradient(size, center, radius, color, max_alpha):
    w, h = size
    cx, cy = center
    cr, cg, cb = color
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    # 阶梯径向羽化，保持极其平滑的自然光衰减
    steps = 24
    for i in range(steps, 0, -1):
        r = radius * (i / float(steps))
        alpha = int(max_alpha * (1.0 - (i / float(steps))**1.4))
        if alpha > 0:
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(cr, cg, cb, alpha))
    return layer.filter(ImageFilter.GaussianBlur(12))

def create_cinematic_vignette(size, intensity=0.28):
    w, h = size
    x = np.linspace(-1, 1, w)
    y = np.linspace(-1, 1, h)
    xx, yy = np.meshgrid(x, y)
    dist = np.sqrt((xx * 0.9)**2 + (yy * 1.1)**2)
    vig = 1.0 - np.clip((dist - 0.45) * intensity, 0.0, 1.0)
    return np.dstack([vig, vig, vig])

def apply_cinematic_grade(img_np):
    # 纯净的电影级调色曲线：暗部冷沉稳，亮部暖通透，杜绝高频白边噪声
    rgb = img_np[:, :, :3].astype(np.float32) / 255.0
    
    # 优雅的微 S 曲线（高对比度但保留暗部与亮部宽容度）
    rgb = 0.5 * (1.0 + np.sin(np.pi * (rgb - 0.5)))
    
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    
    # 暗部融入夜幕靛青色 (Deep Indigo / Twilight Shadow)
    shadow_cool = np.clip((0.45 - lum) * 1.6, 0.0, 1.0)
    b += shadow_cool * 0.04
    g += shadow_cool * 0.01
    r -= shadow_cool * 0.02
    
    # 亮部微染琥珀暖金 (Amber Warmth)
    high_warm = np.clip((lum - 0.45) * 1.6, 0.0, 1.0)
    r += high_warm * 0.05
    g += high_warm * 0.02
    b -= high_warm * 0.03
    
    graded = np.clip(np.dstack([r, g, b]) * 255.0, 0, 255).astype(np.uint8)
    return np.dstack([graded, img_np[:, :, 3]])

def run_pipeline():
    for item in INPUTS:
        item_id = item["id"]
        print(f"Refining {item_id}...")
        
        # 0. Before
        before_im = load_and_resize(item["before_path"])
        before_im.save(os.path.join(OUT_DIR, f"{item_id}_before.png"))
        
        # Base Cleaned Image
        clean_im = load_and_resize(item["clean_path"])
        
        # -------------------------------------------------------------
        # Round 1: 结构与骨架重构 (Structure & Silhouette)
        # -------------------------------------------------------------
        r1 = clean_im.copy()
        r1.save(os.path.join(OUT_DIR, f"{item_id}_r1.png"))
        
        # -------------------------------------------------------------
        # Round 2: 主光影与空间深度 (Lighting & Volumetric Depth)
        # -------------------------------------------------------------
        r2 = r1.copy()
        
        # A. 主光源物理漫射
        lx, ly = item["light_center"]
        lc = item["light_color"]
        lr = item["light_radius"]
        light_layer = create_radial_gradient(TARGET_SIZE, (lx, ly), lr, lc, max_alpha=38)
        r2 = Image.alpha_composite(r2, light_layer)
        
        # B. 脚底/物体接触阴影 (Contact Shadow / AO)
        sx, sy = item["shadow_pos"]
        shadow_layer = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
        sdraw = ImageDraw.Draw(shadow_layer)
        sdraw.ellipse([sx - 100, sy - 22, sx + 100, sy + 22], fill=(4, 8, 12, 110))
        sdraw.ellipse([sx - 65, sy - 14, sx + 65, sy + 14], fill=(2, 4, 6, 140))
        shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(10))
        r2 = Image.alpha_composite(r2, shadow_layer)
        
        r2.save(os.path.join(OUT_DIR, f"{item_id}_r2.png"))
        
        # -------------------------------------------------------------
        # Round 3: 材质重塑与工业级微细节 (Material & Tactile Micro-Detail)
        # -------------------------------------------------------------
        r3 = r2.copy()
        # 提取高光阈值 (Specular Boost) - 绝不使用会导致边缘噪点的全局锐化
        r3_np = np.array(r3).astype(np.float32)
        lum = 0.299 * r3_np[:, :, 0] + 0.587 * r3_np[:, :, 1] + 0.114 * r3_np[:, :, 2]
        
        # 高光阈值掩膜 (高于 190 的金银金属、晶石与火光)
        spec_mask = np.clip((lum - 190.0) / 60.0, 0.0, 1.0)
        # 给高光注入 12% 纯净光泽反光
        r3_np[:, :, 0] += spec_mask * 16.0
        r3_np[:, :, 1] += spec_mask * 18.0
        r3_np[:, :, 2] += spec_mask * 12.0
        r3_np = np.clip(r3_np, 0, 255).astype(np.uint8)
        r3 = Image.fromarray(r3_np, "RGBA")
        
        r3.save(os.path.join(OUT_DIR, f"{item_id}_r3.png"))
        
        # -------------------------------------------------------------
        # Round 4: 色彩分级与视觉重心压制 (Color Grading & Cinematic LUT)
        # -------------------------------------------------------------
        r4_np = np.array(r3)
        r4_graded = apply_cinematic_grade(r4_np)
        
        # 施加电影级柔和暗角
        vig = create_cinematic_vignette(TARGET_SIZE, intensity=0.35)
        r4_rgb = (r4_graded[:, :, :3] * vig).astype(np.uint8)
        r4 = Image.fromarray(np.dstack([r4_rgb, r4_graded[:, :, 3]]), "RGBA")
        
        r4.save(os.path.join(OUT_DIR, f"{item_id}_r4.png"))
        
        # -------------------------------------------------------------
        # Round 5: 商业级终修打磨 (Master Polish 95+ Final)
        # -------------------------------------------------------------
        r5 = r4.copy()
        
        # A. 自然高光光晕 (Natural Emissive Bloom)
        lum_mask = r4.convert("L").point(lambda p: 255 if p > 215 else 0)
        bloom = r4.copy()
        bloom.putalpha(lum_mask)
        bloom = bloom.filter(ImageFilter.GaussianBlur(12))
        # 屏幕微光叠加 (Screen blend approximation via alpha composite)
        r5 = Image.alpha_composite(r5, bloom)
        
        # B. 浮游氛围光微粒 (Atmospheric Sparks / Embers)
        if item["embers"]:
            spark_layer = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
            pdraw = ImageDraw.Draw(spark_layer)
            for (ex, ey) in item["embers"]:
                # 外光晕
                pdraw.ellipse([ex - 4, ey - 4, ex + 4, ey + 4], fill=(255, 175, 45, 75))
                # 亮核
                pdraw.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=(255, 235, 160, 200))
                pdraw.point((ex, ey), fill=(255, 255, 255, 255))
            spark_layer = spark_layer.filter(ImageFilter.GaussianBlur(0.7))
            r5 = Image.alpha_composite(r5, spark_layer)
        
        r5.save(os.path.join(OUT_DIR, f"{item_id}_r5.png"))
        print(f"Master Polish Done: {item_id}")

run_pipeline()
print("All 5 showcase items fully generated!")
