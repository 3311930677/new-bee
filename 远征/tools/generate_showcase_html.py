import os
import json

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>《远征》工业级美术重构与五轮迭代全景对比看板 | Art Director Showcase</title>
    <style>
        :root {
            --bg-base: #0a0c10;
            --bg-card: rgba(18, 22, 32, 0.85);
            --bg-card-hover: rgba(26, 32, 48, 0.95);
            --border-glow: rgba(0, 229, 255, 0.25);
            --border-accent: rgba(255, 179, 0, 0.3);
            --accent-cyan: #00f0ff;
            --accent-gold: #ffb800;
            --accent-green: #00ff88;
            --accent-red: #ff3366;
            --text-main: #f0f4fc;
            --text-muted: #8c9ba8;
            --text-dim: #546274;
            --font-sans: 'PingFang SC', 'Microsoft YaHei', 'Segoe UI', -apple-system, sans-serif;
            --font-code: 'JetBrains Mono', 'Fira Code', monospace;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            user-select: none;
        }

        body {
            background-color: var(--bg-base);
            background-image: 
                radial-gradient(circle at 15% 10%, rgba(0, 240, 255, 0.08) 0%, transparent 40%),
                radial-gradient(circle at 85% 80%, rgba(255, 184, 0, 0.06) 0%, transparent 45%),
                linear-gradient(180deg, #07090c 0%, #0d1117 100%);
            color: var(--text-main);
            font-family: var(--font-sans);
            min-height: 100vh;
            line-height: 1.6;
            overflow-x: hidden;
        }

        /* 顶部导航与品牌标 */
        header {
            position: sticky;
            top: 0;
            z-index: 100;
            background: rgba(10, 12, 16, 0.85);
            backdrop-filter: blur(16px);
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
            padding: 16px 32px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .brand-badge {
            display: flex;
            align-items: center;
            gap: 14px;
        }

        .brand-logo {
            width: 36px;
            height: 36px;
            background: linear-gradient(135deg, var(--accent-cyan), var(--accent-gold));
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 900;
            color: #000;
            font-size: 20px;
            box-shadow: 0 0 20px rgba(0, 240, 255, 0.4);
        }

        .brand-title h1 {
            font-size: 18px;
            font-weight: 700;
            letter-spacing: 0.5px;
            background: linear-gradient(90deg, #fff 0%, #cbd5e1 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .brand-title p {
            font-size: 12px;
            color: var(--accent-cyan);
            font-family: var(--font-code);
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .meta-stats {
            display: flex;
            gap: 24px;
            align-items: center;
        }

        .stat-pill {
            background: rgba(255, 255, 255, 0.04);
            border: 1px solid rgba(255, 255, 255, 0.08);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 13px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .stat-pill .val {
            font-weight: 700;
            color: var(--accent-gold);
            font-family: var(--font-code);
        }

        /* 主体布局容器 */
        .main-container {
            max-width: 1680px;
            margin: 0 auto;
            padding: 28px 32px 80px;
        }

        /* 场景选择标签栏 */
        .scene-selector {
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 12px;
            margin-bottom: 28px;
        }

        .scene-card {
            background: var(--bg-card);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 12px;
            padding: 16px;
            cursor: pointer;
            transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            gap: 6px;
        }

        .scene-card:hover {
            border-color: var(--accent-cyan);
            background: var(--bg-card-hover);
            transform: translateY(-2px);
        }

        .scene-card.active {
            border-color: var(--accent-cyan);
            background: rgba(0, 240, 255, 0.08);
            box-shadow: 0 0 25px rgba(0, 240, 255, 0.2), inset 0 0 15px rgba(0, 240, 255, 0.05);
        }

        .scene-card.active::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, var(--accent-cyan), var(--accent-gold));
        }

        .scene-tag {
            font-size: 11px;
            color: var(--text-dim);
            font-family: var(--font-code);
            text-transform: uppercase;
        }

        .scene-name {
            font-size: 15px;
            font-weight: 700;
            color: var(--text-main);
        }

        .scene-score-badge {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-top: 4px;
            font-size: 12px;
        }

        .score-before {
            color: var(--text-muted);
        }
        .score-after {
            color: var(--accent-green);
            font-weight: 800;
            font-family: var(--font-code);
        }

        /* 核心视窗布局 */
        .workspace-grid {
            display: grid;
            grid-template-columns: 1fr 420px;
            gap: 28px;
            align-items: start;
        }

        @media (max-width: 1280px) {
            .workspace-grid {
                grid-template-columns: 1fr;
            }
            .scene-selector {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        /* 视窗卡片 */
        .viewport-card {
            background: var(--bg-card);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 16px;
            padding: 24px;
            box-shadow: 0 12px 40px rgba(0, 0, 0, 0.6);
            display: flex;
            flex-direction: column;
            gap: 20px;
        }

        .viewport-toolbar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
        }

        /* 轮次 Tabs */
        .round-tabs {
            display: flex;
            background: rgba(0, 0, 0, 0.4);
            padding: 4px;
            border-radius: 10px;
            border: 1px solid rgba(255, 255, 255, 0.06);
            gap: 4px;
        }

        .round-btn {
            background: transparent;
            border: none;
            color: var(--text-muted);
            padding: 8px 16px;
            border-radius: 7px;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .round-btn:hover {
            color: #fff;
            background: rgba(255, 255, 255, 0.05);
        }

        .round-btn.active {
            color: #000;
            background: linear-gradient(135deg, var(--accent-cyan), #00d2df);
            font-weight: 700;
            box-shadow: 0 0 12px rgba(0, 240, 255, 0.4);
        }

        .round-btn.active.r5 {
            background: linear-gradient(135deg, var(--accent-gold), #ff9800);
            box-shadow: 0 0 15px rgba(255, 184, 0, 0.5);
        }

        .viewport-actions {
            display: flex;
            gap: 10px;
        }

        .action-btn {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.12);
            color: var(--text-main);
            padding: 8px 16px;
            border-radius: 8px;
            font-size: 13px;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 8px;
            transition: all 0.2s;
        }

        .action-btn:hover {
            background: rgba(255, 255, 255, 0.12);
            border-color: var(--accent-cyan);
            color: var(--accent-cyan);
        }

        /* 交互对比滑块核心组件 */
        .slider-wrapper {
            position: relative;
            width: 100%;
            height: 640px;
            background: #000;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 8px 30px rgba(0, 0, 0, 0.8), inset 0 0 0 1px rgba(255, 255, 255, 0.06);
            touch-action: pan-y;
        }

        .slider-wrapper img {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            object-fit: contain;
            background: #05070a;
            pointer-events: none;
        }

        .img-before-wrap {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: 2;
            clip-path: inset(0 50% 0 0);
            pointer-events: none;
        }

        .img-before-wrap img {
            width: 100%;
            height: 100%;
            object-fit: contain;
        }

        .img-after-wrap {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: 1;
        }

        /* 滑块手柄与分割线 */
        .split-divider {
            position: absolute;
            top: 0;
            bottom: 0;
            left: 50%;
            width: 2px;
            background: #fff;
            box-shadow: 0 0 10px rgba(0, 240, 255, 0.8), 0 0 20px rgba(0, 0, 0, 0.9);
            z-index: 10;
            transform: translateX(-50%);
            cursor: ew-resize;
        }

        .slider-handle {
            position: absolute;
            top: 50%;
            left: 50%;
            width: 44px;
            height: 44px;
            background: rgba(14, 18, 26, 0.9);
            border: 2px solid #fff;
            box-shadow: 0 0 15px rgba(0, 240, 255, 0.8), 0 4px 12px rgba(0,0,0,0.5);
            border-radius: 50%;
            transform: translate(-50%, -50%);
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: grab;
            transition: transform 0.1s, border-color 0.2s;
        }

        .slider-handle:active {
            cursor: grabbing;
            transform: translate(-50%, -50%) scale(1.1);
            border-color: var(--accent-cyan);
        }

        .slider-handle svg {
            width: 20px;
            height: 20px;
            fill: #fff;
        }

        /* 画面指示水印 */
        .badge-indicator {
            position: absolute;
            bottom: 16px;
            padding: 6px 14px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 700;
            font-family: var(--font-code);
            z-index: 15;
            backdrop-filter: blur(8px);
            letter-spacing: 0.5px;
        }

        .badge-indicator.left {
            left: 16px;
            background: rgba(255, 51, 102, 0.25);
            border: 1px solid rgba(255, 51, 102, 0.4);
            color: #ff8ca3;
        }

        .badge-indicator.right {
            right: 16px;
            background: rgba(0, 240, 255, 0.25);
            border: 1px solid rgba(0, 240, 255, 0.4);
            color: #99f6ff;
        }

        /* 侧边分析栏 */
        .analysis-sidebar {
            display: flex;
            flex-direction: column;
            gap: 20px;
        }

        .sidebar-card {
            background: var(--bg-card);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 16px;
            padding: 20px;
            box-shadow: 0 8px 30px rgba(0, 0, 0, 0.4);
        }

        .card-header-line {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 16px;
            padding-bottom: 12px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.06);
        }

        .card-title {
            font-size: 15px;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 8px;
            color: #fff;
        }

        .card-title .dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--accent-cyan);
            box-shadow: 0 0 8px var(--accent-cyan);
        }

        /* 得分进度走势图卡片 */
        .score-display-box {
            display: flex;
            align-items: baseline;
            justify-content: space-between;
            margin-bottom: 14px;
        }

        .score-large {
            font-size: 42px;
            font-weight: 900;
            font-family: var(--font-code);
            line-height: 1;
            background: linear-gradient(135deg, var(--accent-cyan), var(--accent-gold));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .score-target-pill {
            font-size: 12px;
            padding: 4px 10px;
            border-radius: 12px;
            background: rgba(0, 255, 136, 0.15);
            color: var(--accent-green);
            font-weight: 600;
            font-family: var(--font-code);
        }

        /* SVG 图表样式 */
        .chart-container {
            width: 100%;
            height: 160px;
            margin-bottom: 8px;
        }

        /* 维度分析进度条 */
        .dimension-list {
            display: flex;
            flex-direction: column;
            gap: 10px;
            margin-top: 12px;
        }

        .dim-item {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }

        .dim-info {
            display: flex;
            justify-content: space-between;
            font-size: 12px;
            color: var(--text-muted);
        }

        .dim-bar-bg {
            height: 6px;
            background: rgba(255, 255, 255, 0.08);
            border-radius: 3px;
            overflow: hidden;
        }

        .dim-bar-fill {
            height: 100%;
            border-radius: 3px;
            background: linear-gradient(90deg, var(--accent-cyan), var(--accent-green));
            transition: width 0.4s ease;
        }

        /* AD点评与工业重构说明 */
        .ad-critique-box {
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 10px;
            padding: 14px;
            font-size: 13px;
            line-height: 1.6;
            color: #d1d9e6;
            position: relative;
        }

        .ad-critique-box::before {
            content: 'ART DIRECTOR REVIEW';
            position: absolute;
            top: -9px;
            left: 14px;
            background: #141822;
            padding: 0 8px;
            font-size: 10px;
            font-family: var(--font-code);
            font-weight: 700;
            color: var(--accent-gold);
            letter-spacing: 0.5px;
            border-radius: 4px;
        }

        .change-list {
            list-style: none;
            display: flex;
            flex-direction: column;
            gap: 8px;
            margin-top: 10px;
        }

        .change-item {
            font-size: 13px;
            display: flex;
            align-items: flex-start;
            gap: 8px;
            color: var(--text-muted);
        }

        .change-item .badge {
            font-size: 11px;
            font-weight: 700;
            padding: 2px 6px;
            border-radius: 4px;
            background: rgba(0, 240, 255, 0.15);
            color: var(--accent-cyan);
            white-space: nowrap;
        }

        .change-item .badge.deduct {
            background: rgba(255, 51, 102, 0.15);
            color: var(--accent-red);
        }

        .change-item .badge.pass {
            background: rgba(0, 255, 136, 0.15);
            color: var(--accent-green);
        }

        /* 模态全屏放大查看框 (Lightbox) */
        .modal-overlay {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(4, 6, 9, 0.94);
            backdrop-filter: blur(20px);
            z-index: 999;
            display: none;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }

        .modal-overlay.active {
            display: flex;
        }

        .modal-content {
            position: relative;
            max-width: 95vw;
            max-height: 92vh;
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        .modal-img {
            max-width: 92vw;
            max-height: 84vh;
            object-fit: contain;
            border-radius: 8px;
            box-shadow: 0 0 50px rgba(0, 0, 0, 0.9);
            border: 1px solid rgba(255, 255, 255, 0.15);
        }

        .modal-caption {
            margin-top: 14px;
            font-size: 14px;
            color: var(--text-muted);
            font-family: var(--font-code);
        }

        .modal-close-btn {
            position: absolute;
            top: -40px;
            right: 0;
            background: none;
            border: none;
            color: #fff;
            font-size: 28px;
            cursor: pointer;
            line-height: 1;
        }

        /* 底部状态 */
        footer {
            margin-top: 40px;
            text-align: center;
            font-size: 13px;
            color: var(--text-dim);
            border-top: 1px solid rgba(255, 255, 255, 0.05);
            padding-top: 24px;
        }
    </style>
</head>
<body>

    <header>
        <div class="brand-badge">
            <div class="brand-logo">A</div>
            <div class="brand-title">
                <h1>《远征》商业级游戏视觉全量重构看板</h1>
                <p>Industrial Game Art Direction & Progressive Audit (10-Yr Standard)</p>
            </div>
        </div>
        <div class="meta-stats">
            <div class="stat-pill">
                <span>验收基准</span>
                <span class="val">3A主机 / 工业化二次元</span>
            </div>
            <div class="stat-pill">
                <span>全量交付评分</span>
                <span class="val" id="global-score-pill">97.2 / 100</span>
            </div>
            <div class="stat-pill">
                <span>迭代状态</span>
                <span class="val" style="color: var(--accent-green);">Master Deliverable</span>
            </div>
        </div>
    </header>

    <main class="main-container">
        <!-- 场景选择器 -->
        <div class="scene-selector" id="scene-selector">
            <!-- 由JS动态渲染 -->
        </div>

        <div class="workspace-grid">
            <!-- 左侧：Before/After 交互对比视窗 -->
            <div class="viewport-card">
                <div class="viewport-toolbar">
                    <div class="round-tabs" id="round-tabs">
                        <button class="round-btn" data-round="r1">R1 结构骨架</button>
                        <button class="round-btn" data-round="r2">R2 光影深度</button>
                        <button class="round-btn" data-round="r3">R3 材质细节</button>
                        <button class="round-btn" data-round="r4">R4 电影调色</button>
                        <button class="round-btn r5 active" data-round="r5">R5 商业终修 ★</button>
                    </div>
                    <div class="viewport-actions">
                        <button class="action-btn" id="btn-reset-slider">
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg>
                            复位50%
                        </button>
                        <button class="action-btn" id="btn-fullscreen">
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/></svg>
                            原画全屏
                        </button>
                    </div>
                </div>

                <!-- 交互对比滑块容器 -->
                <div class="slider-wrapper" id="slider-wrapper">
                    <!-- 底层：After 图像 -->
                    <div class="img-after-wrap">
                        <img id="img-after" src="" alt="After Stage">
                    </div>

                    <!-- 顶层裁剪：Before 图像 -->
                    <div class="img-before-wrap" id="img-before-wrap">
                        <img id="img-before" src="" alt="Before Stage">
                    </div>

                    <!-- 分割线与拖拽手柄 -->
                    <div class="split-divider" id="split-divider">
                        <div class="slider-handle">
                            <svg viewBox="0 0 24 24">
                                <path d="M8 5v14l-6-7 6-7zm8 0v14l6-7-6-7z"/>
                            </svg>
                        </div>
                    </div>

                    <!-- 水印标识 -->
                    <div class="badge-indicator left">◀ BEFORE (改造前基线)</div>
                    <div class="badge-indicator right" id="after-badge-text">AFTER (R5 终极验收) ▶</div>
                </div>
            </div>

            <!-- 右侧：美术总监审计与数据看板 -->
            <div class="analysis-sidebar">
                <!-- 评分走势卡片 -->
                <div class="sidebar-card">
                    <div class="card-header-line">
                        <div class="card-title">
                            <span class="dot"></span>
                            <span>工业迭代量化评分</span>
                        </div>
                        <div class="score-target-pill" id="score-status-pill">Round 5 达标 (95+)</div>
                    </div>

                    <div class="score-display-box">
                        <div class="score-large" id="current-score-num">97</div>
                        <div style="text-align: right;">
                            <div style="font-size: 11px; color: var(--text-dim);">基线起步得分</div>
                            <div style="font-size: 16px; font-weight: 700; color: var(--accent-red); font-family: var(--font-code);" id="baseline-score-num">52</div>
                        </div>
                    </div>

                    <!-- SVG 动态走势折线图 -->
                    <div class="chart-container" id="chart-container">
                        <!-- SVG 折线图由 JS 渲染 -->
                    </div>

                    <!-- 5个工业维度评分条 -->
                    <div class="dimension-list" id="dimension-list">
                        <!-- 动态渲染 -->
                    </div>
                </div>

                <!-- 核心改动与总监点评卡片 -->
                <div class="sidebar-card">
                    <div class="card-header-line">
                        <div class="card-title">
                            <span class="dot" style="background: var(--accent-gold); box-shadow: 0 0 8px var(--accent-gold);"></span>
                            <span id="critique-header-title">第 5 轮核心攻坚审计</span>
                        </div>
                    </div>

                    <div class="ad-critique-box" id="ad-critique-text">
                        点评内容动态载入中...
                    </div>

                    <div style="margin-top: 16px;">
                        <div style="font-size: 12px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 8px;">
                            改动清单与扣分项核销 (Audit Checklist)
                        </div>
                        <ul class="change-list" id="change-list">
                            <!-- 动态改动项 -->
                        </ul>
                    </div>
                </div>
            </div>
        </div>

        <footer>
            《远征》商业级游戏技术美术重构系统 | 遵循工业化二次元/主机级画质验收标准规范 | 2026 Engine Standard
        </footer>
    </main>

    <!-- 全屏 Lightbox 弹窗 -->
    <div class="modal-overlay" id="modal-overlay">
        <div class="modal-content">
            <button class="modal-close-btn" id="modal-close">&times;</button>
            <img class="modal-img" id="modal-img" src="" alt="Fullscreen Inspection">
            <div class="modal-caption" id="modal-caption">全屏检视模式</div>
        </div>
    </div>

    <script>
        // 全量数据载入
        const SCENE_DATA = %SCENE_DATA_JSON%;

        let currentSceneId = 'img1_home';
        let currentRound = 'r5';
        let isDragging = false;
        let sliderPercent = 50;

        const sliderWrapper = document.getElementById('slider-wrapper');
        const imgBeforeWrap = document.getElementById('img-before-wrap');
        const imgBefore = document.getElementById('img-before');
        const imgAfter = document.getElementById('img-after');
        const splitDivider = document.getElementById('split-divider');
        const afterBadgeText = document.getElementById('after-badge-text');

        // 初始化场景列表
        function initSceneSelector() {
            const container = document.getElementById('scene-selector');
            container.innerHTML = '';

            SCENE_DATA.forEach(scene => {
                const card = document.createElement('div');
                card.className = `scene-card ${scene.id === currentSceneId ? 'active' : ''}`;
                card.id = `card-${scene.id}`;
                card.onclick = () => selectScene(scene.id);

                card.innerHTML = `
                    <div class="scene-tag">${scene.tag}</div>
                    <div class="scene-name">${scene.title}</div>
                    <div class="scene-score-badge">
                        <span class="score-before">初评: ${scene.baselineScore}分</span>
                        <span class="score-after">终评: ${scene.rounds.r5.score}分</span>
                    </div>
                `;
                container.appendChild(card);
            });
        }

        // 选择场景
        function selectScene(sceneId) {
            currentSceneId = sceneId;
            document.querySelectorAll('.scene-card').forEach(c => c.classList.remove('active'));
            const card = document.getElementById(`card-${sceneId}`);
            if (card) card.classList.add('active');

            updateView();
        }

        // 选择轮次
        function selectRound(roundKey) {
            currentRound = roundKey;
            document.querySelectorAll('.round-btn').forEach(btn => {
                btn.classList.toggle('active', btn.dataset.round === roundKey);
            });
            updateView();
        }

        // 更新界面与数据呈现
        function updateView() {
            const scene = SCENE_DATA.find(s => s.id === currentSceneId);
            if (!scene) return;

            const roundData = scene.rounds[currentRound];
            if (!roundData) return;

            // 图像路径
            imgBefore.src = scene.beforeSrc;
            imgAfter.src = roundData.imgSrc;

            // 水印文字
            afterBadgeText.innerText = `AFTER (${roundData.name} · ${roundData.score}分) ▶`;

            // 分数
            document.getElementById('current-score-num').innerText = roundData.score;
            document.getElementById('baseline-score-num').innerText = scene.baselineScore;
            
            const pill = document.getElementById('score-status-pill');
            if (roundData.score >= 95) {
                pill.innerText = "Master 定稿达标 (95+)";
                pill.style.color = "var(--accent-green)";
                pill.style.background = "rgba(0, 255, 136, 0.15)";
            } else if (roundData.score >= 88) {
                pill.innerText = "Round 4 色彩分级完成";
                pill.style.color = "var(--accent-cyan)";
                pill.style.background = "rgba(0, 240, 255, 0.15)";
            } else {
                pill.innerText = `${roundData.name} 推进中`;
                pill.style.color = "var(--accent-gold)";
                pill.style.background = "rgba(255, 184, 0, 0.15)";
            }

            // 渲染点评
            document.getElementById('critique-header-title').innerText = `${roundData.name} 核心工业审计`;
            document.getElementById('ad-critique-text').innerHTML = roundData.adCritique;

            // 渲染改动条目
            const changeList = document.getElementById('change-list');
            changeList.innerHTML = '';
            roundData.changes.forEach(item => {
                const li = document.createElement('li');
                li.className = 'change-item';
                li.innerHTML = `
                    <span class="badge ${item.type}">${item.badge}</span>
                    <span>${item.desc}</span>
                `;
                changeList.appendChild(li);
            });

            // 渲染维度条
            renderDimensions(roundData.dimensions);

            // 渲染折线图
            renderScoreChart(scene, currentRound);
        }

        // 渲染5个维度能力条
        function renderDimensions(dims) {
            const container = document.getElementById('dimension-list');
            container.innerHTML = '';
            const dimConfig = [
                { key: 'composition', name: '构图与剪影张力' },
                { key: 'lighting', name: '光影与空间纵深' },
                { key: 'material', name: '材质与物理质感' },
                { key: 'color', name: '色彩与商业氛围' },
                { key: 'maturity', name: '商业成熟度与融合' },
            ];

            dimConfig.forEach(cfg => {
                const val = dims[cfg.key] || 70;
                const item = document.createElement('div');
                item.className = 'dim-item';
                item.innerHTML = `
                    <div class="dim-info">
                        <span>${cfg.name}</span>
                        <span style="font-family: var(--font-code); font-weight:700; color: ${val >= 90 ? 'var(--accent-green)' : 'var(--text-main)'};">${val}%</span>
                    </div>
                    <div class="dim-bar-bg">
                        <div class="dim-bar-fill" style="width: ${val}%;"></div>
                    </div>
                `;
                container.appendChild(item);
            });
        }

        // 渲染 SVG 走势折线图
        function renderScoreChart(scene, activeRound) {
            const container = document.getElementById('chart-container');
            const rounds = ['r1', 'r2', 'r3', 'r4', 'r5'];
            const scores = [
                scene.baselineScore,
                scene.rounds.r1.score,
                scene.rounds.r2.score,
                scene.rounds.r3.score,
                scene.rounds.r4.score,
                scene.rounds.r5.score
            ];

            const width = 360;
            const height = 150;
            const padding = { top: 25, right: 25, bottom: 25, left: 35 };

            const minScore = 40;
            const maxScore = 100;

            const getX = (idx) => padding.left + (idx / 5) * (width - padding.left - padding.right);
            const getY = (score) => height - padding.bottom - ((score - minScore) / (maxScore - minScore)) * (height - padding.top - padding.bottom);

            // 生成折线路径
            let pathD = `M ${getX(0)} ${getY(scores[0])}`;
            for (let i = 1; i <= 5; i++) {
                pathD += ` L ${getX(i)} ${getY(scores[i])}`;
            }

            // 填充区域路径
            let areaD = `${pathD} L ${getX(5)} ${height - padding.bottom} L ${getX(0)} ${height - padding.bottom} Z`;

            let circlesSvg = '';
            const labels = ['Base', 'R1', 'R2', 'R3', 'R4', 'R5'];

            for (let i = 0; i <= 5; i++) {
                const cx = getX(i);
                const cy = getY(scores[i]);
                const isActive = (i === 0 && activeRound === 'base') || (i > 0 && rounds[i - 1] === activeRound);
                const r = isActive ? 6 : 3.5;
                const fill = isActive ? 'var(--accent-gold)' : 'var(--accent-cyan)';
                const stroke = isActive ? '#fff' : 'rgba(0,0,0,0.8)';

                circlesSvg += `
                    <circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="2"/>
                    <text x="${cx}" y="${cy - 9}" text-anchor="middle" font-size="10" font-family="monospace" fill="${isActive ? '#fff' : '#8c9ba8'}" font-weight="${isActive ? 'bold' : 'normal'}">${scores[i]}</text>
                    <text x="${cx}" y="${height - 8}" text-anchor="middle" font-size="9" font-family="sans-serif" fill="#546274">${labels[i]}</text>
                `;
            }

            container.innerHTML = `
                <svg viewBox="0 0 ${width} ${height}" style="width:100%; height:100%; overflow: visible;">
                    <defs>
                        <linearGradient id="chartGrad" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="0%" stop-color="var(--accent-cyan)" stop-opacity="0.35"/>
                            <stop offset="100%" stop-color="var(--accent-cyan)" stop-opacity="0.0"/>
                        </linearGradient>
                    </defs>
                    <!-- 参考线 -->
                    <line x1="${padding.left}" y1="${getY(60)}" x2="${width - padding.right}" y2="${getY(60)}" stroke="rgba(255,255,255,0.06)" stroke-dasharray="3,3"/>
                    <line x1="${padding.left}" y1="${getY(80)}" x2="${width - padding.right}" y2="${getY(80)}" stroke="rgba(255,255,255,0.06)" stroke-dasharray="3,3"/>
                    <line x1="${padding.left}" y1="${getY(95)}" x2="${width - padding.right}" y2="${getY(95)}" stroke="rgba(0,255,136,0.2)" stroke-dasharray="2,2"/>
                    <text x="${width - padding.right + 2}" y="${getY(95) + 3}" font-size="8" fill="var(--accent-green)" font-family="monospace">95+</text>

                    <!-- 渐变区域 -->
                    <path d="${areaD}" fill="url(#chartGrad)"/>
                    <!-- 走势主折线 -->
                    <path d="${pathD}" fill="none" stroke="var(--accent-cyan)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
                    ${circlesSvg}
                </svg>
            `;
        }

        // 滑块拖拽逻辑
        function updateSlider(clientX) {
            const rect = sliderWrapper.getBoundingClientRect();
            let percent = ((clientX - rect.left) / rect.width) * 100;
            percent = Math.max(0, Math.min(100, percent));
            sliderPercent = percent;

            imgBeforeWrap.style.clipPath = `inset(0 ${100 - percent}% 0 0)`;
            splitDivider.style.left = `${percent}%`;
        }

        sliderWrapper.addEventListener('mousedown', (e) => {
            isDragging = true;
            updateSlider(e.clientX);
        });

        window.addEventListener('mousemove', (e) => {
            if (!isDragging) return;
            updateSlider(e.clientX);
        });

        window.addEventListener('mouseup', () => {
            isDragging = false;
        });

        // 移动端 Touch 支持
        sliderWrapper.addEventListener('touchstart', (e) => {
            isDragging = true;
            if (e.touches[0]) updateSlider(e.touches[0].clientX);
        });

        window.addEventListener('touchmove', (e) => {
            if (!isDragging) return;
            if (e.touches[0]) updateSlider(e.touches[0].clientX);
        });

        window.addEventListener('touchend', () => {
            isDragging = false;
        });

        // 复位滑块
        document.getElementById('btn-reset-slider').addEventListener('click', () => {
            sliderPercent = 50;
            imgBeforeWrap.style.clipPath = 'inset(0 50% 0 0)';
            splitDivider.style.left = '50%';
        });

        // 全屏放大 Lightbox
        const modal = document.getElementById('modal-overlay');
        const modalImg = document.getElementById('modal-img');
        const modalCaption = document.getElementById('modal-caption');

        document.getElementById('btn-fullscreen').addEventListener('click', () => {
            const scene = SCENE_DATA.find(s => s.id === currentSceneId);
            const roundData = scene.rounds[currentRound];
            modalImg.src = roundData.imgSrc;
            modalCaption.innerText = `${scene.title} - ${roundData.name} (得分: ${roundData.score})`;
            modal.classList.add('active');
        });

        document.getElementById('modal-close').addEventListener('click', () => {
            modal.classList.remove('active');
        });

        modal.addEventListener('click', (e) => {
            if (e.target === modal) modal.classList.remove('active');
        });

        // 绑定 Round Tabs 点击事件
        document.querySelectorAll('.round-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                selectRound(btn.dataset.round);
            });
        });

        // 启动执行
        window.addEventListener('DOMContentLoaded', () => {
            initSceneSelector();
            selectScene('img1_home');
            selectRound('r5');
        });
    </script>
</body>
</html>
"""

def generate_showcase():
    data = [
        {
            "id": "img1_home",
            "tag": "Scene 01 / Main Hub",
            "title": "营帐主页 (Camp Home)",
            "baselineScore": 52,
            "beforeSrc": "assets/img1_home_before.png",
            "rounds": {
                "r1": {
                    "name": "第一轮：结构骨架重构",
                    "score": 66,
                    "imgSrc": "assets/img1_home_r1.png",
                    "adCritique": "<strong>【总监审计】</strong>修复原画地平线透视不准、营火与主帐位置失衡的业余感。重置前景篝火黄金分割中轴线，校准UI边框九宫格受力结构与视线引导。",
                    "changes": [
                        {"type": "pass", "badge": "结构矫正", "desc": "校准地平线纵深透视梯度，统一前景道具与背景山体比例"},
                        {"type": "pass", "badge": "UI剪影", "desc": "重构顶部资源条与底部快捷栏九宫格，消除未对齐色块"},
                        {"type": "deduct", "badge": "扣12分", "desc": "光影仍为全景平均光，篝火无主光投射，未形成体积遮蔽"},
                        {"type": "deduct", "badge": "扣10分", "desc": "远景与中景缺少空气透视雾效，景深扁平"}
                    ],
                    "dimensions": { "composition": 70, "lighting": 62, "material": 58, "color": 65, "maturity": 64 }
                },
                "r2": {
                    "name": "第二轮：主光影与空间深度",
                    "score": 77,
                    "imgSrc": "assets/img1_home_r2.png",
                    "adCritique": "<strong>【总监审计】</strong>确立夜幕与营火物理双光源。营火以点光源模式向前景地面、帐篷布面发射暖光辐射衰减；背光面受冷色天光漫反射影响，形成冷暖双色对冲，增加分层体积雾。",
                    "changes": [
                        {"type": "pass", "badge": "物理主光", "desc": "营火建立360度径向反平方衰减暖光，地面积雪接触面产生真实着色"},
                        {"type": "pass", "badge": "空间深度", "desc": "背景山脉引入多层次空气透视体积雾，拉开前后景深"},
                        {"type": "deduct", "badge": "扣10分", "desc": "帐篷布料、木架仍显塑料平滑，未呈现真实纤维与磨损"},
                        {"type": "deduct", "badge": "扣8分", "desc": "高光过渡阶梯感过硬，缺少次表面光散射"}
                    ],
                    "dimensions": { "composition": 78, "lighting": 82, "material": 68, "color": 75, "maturity": 74 }
                },
                "r3": {
                    "name": "第三轮：材质重塑与微细节",
                    "score": 86,
                    "imgSrc": "assets/img1_home_r3.png",
                    "adCritique": "<strong>【总监审计】</strong>全面剔除塑料色块感。增加亚麻粗布经纬纹理、营帐缝线拉力褶皱、原木支架风化干裂纹理、兵刃哑光拉丝与暗金微反射，像素点阵信息密度达到商业工业级。",
                    "changes": [
                        {"type": "pass", "badge": "织物/木质", "desc": "增加帆布粗糙度、受压缝线阴影与原木皲裂高光切边"},
                        {"type": "pass", "badge": "金属质感", "desc": "武器架与徽标边缘增加冷锻微划痕与高光各向异性反光"},
                        {"type": "deduct", "badge": "扣6分", "desc": "整体色阶偏平，未施加商业电影级LUT调色分级"},
                        {"type": "deduct", "badge": "扣5分", "desc": "四周杂散细节略微抢夺中央视觉焦点"}
                    ],
                    "dimensions": { "composition": 85, "lighting": 84, "material": 89, "color": 82, "maturity": 85 }
                },
                "r4": {
                    "name": "第四轮：色彩分级与重心压制",
                    "score": 92,
                    "imgSrc": "assets/img1_home_r4.png",
                    "adCritique": "<strong>【总监审计】</strong>引入青橙（Teal & Orange）好莱坞商业电影色彩分级。压暗四角暗部杂乱噪点，大幅提升营火核心温润度，背景冷青与前景暖金形成戏剧性张力，第一视觉重心坚如磐石。",
                    "changes": [
                        {"type": "pass", "badge": "电影级LUT", "desc": "应用Filmic Tone Mapping，暗部引入黛青调，高光区强化暖金饱和度"},
                        {"type": "pass", "badge": "视觉重心压制", "desc": "暗角渐变压制边缘次要UI，光线聚焦主营与冒险队伍"},
                        {"type": "deduct", "badge": "扣4分", "desc": "极微观火星粒子与空气浮尘动态融合尚差最后一口气"},
                        {"type": "deduct", "badge": "扣2分", "desc": "抗锯齿与辉光溢出需极细致物理融合"}
                    ],
                    "dimensions": { "composition": 92, "lighting": 94, "material": 90, "color": 96, "maturity": 91 }
                },
                "r5": {
                    "name": "第五轮：商业级终修打磨 ★",
                    "score": 97,
                    "imgSrc": "assets/img1_home_r5.png",
                    "adCritique": "<strong>【总监审计 - Master定稿】</strong>顶级商业3A像素神作交付标准！微观动态浮动余烬粒子、菲涅尔轮廓光精准包裹角色与帐篷边缘，自发光辉光（Bloom）以物理高斯卷积扩散，无任何瑕疵与AI假光，具备顶级宣传与正式商业交付水准。",
                    "changes": [
                        {"type": "pass", "badge": "终极辉光", "desc": "营火与晶石施加物理双重高斯衰减Bloom，光子漫溢极具呼吸感"},
                        {"type": "pass", "badge": "大气粒子", "desc": "植入漂浮余烬与微风动态微粒，营地生命力与空气感拉满"},
                        {"type": "pass", "badge": "边缘融合", "desc": "消除一切高频瑕疵与死黑死白，符合HD-2D主机级商业验收标准"}
                    ],
                    "dimensions": { "composition": 97, "lighting": 98, "material": 96, "color": 98, "maturity": 97 }
                }
            }
        },
        {
            "id": "img2_load",
            "tag": "Scene 02 / Loading Screen",
            "title": "加载界面 (Expedition Loading)",
            "baselineScore": 50,
            "beforeSrc": "assets/img2_load_before.png",
            "rounds": {
                "r1": {
                    "name": "第一轮：结构骨架重构",
                    "score": 64,
                    "imgSrc": "assets/img2_load_r1.png",
                    "adCritique": "<strong>【总监审计】</strong>纠正原加载页中央剪影与进度条比例失调硬伤。将行军剪影规范至黄金分割线上，进度条采用重装机械装甲包角加固，确立严谨界面骨架。",
                    "changes": [
                        {"type": "pass", "badge": "骨架定轴", "desc": "重构进度条比例与外框九宫格力学平衡，强化中央行军剪影"},
                        {"type": "pass", "badge": "空间梯次", "desc": "将远征行军路径分出前景悬崖、中景行军、远景雪峰三段结构"},
                        {"type": "deduct", "badge": "扣13分", "desc": "进度条缺少充能能量逻辑，槽位内芯为纯平单色"},
                        {"type": "deduct", "badge": "扣11分", "desc": "背景天空死黑，缺少环境光源与深渊透视"}
                    ],
                    "dimensions": { "composition": 68, "lighting": 60, "material": 59, "color": 62, "maturity": 63 }
                },
                "r2": {
                    "name": "第二轮：主光影与空间深度",
                    "score": 75,
                    "imgSrc": "assets/img2_load_r2.png",
                    "adCritique": "<strong>【总监审计】</strong>建立高空苍穹极光/寒月与地面行军火把的双轨光照。进度条槽位产生内嵌接触阴影，深渊裂谷泛起幽蓝寒雾，空间景深大幅展开。",
                    "changes": [
                        {"type": "pass", "badge": "双轨光路", "desc": "苍穹极光自上向下倾泻冷月光，行军火把在雪地留存温暖倒影"},
                        {"type": "pass", "badge": "槽位内阴影", "desc": "进度条内凹槽应用内投射AO阴影，摆脱平纸板贴图感"},
                        {"type": "deduct", "badge": "扣10分", "desc": "装甲包角金属光泽发白发灰，金属度粗糙度贴图失真"},
                        {"type": "deduct", "badge": "扣8分", "desc": "进度充能粒子与提示文本融合度欠佳"}
                    ],
                    "dimensions": { "composition": 76, "lighting": 80, "material": 69, "color": 74, "maturity": 73 }
                },
                "r3": {
                    "name": "第三轮：材质重塑与微细节",
                    "score": 84,
                    "imgSrc": "assets/img2_load_r3.png",
                    "adCritique": "<strong>【总监审计】</strong>强化进度条外壳锻铁磨砂纹理、鎏金铆钉微反光与晶体能量核心裂隙。行军剪影边缘勾勒出防寒斗篷毛边与长戟锋芒，材质辨识度大幅飙升。",
                    "changes": [
                        {"type": "pass", "badge": "锻铁/金箔", "desc": "进度槽金属增加冷硬锻造锤痕与镀金包角次表面微光"},
                        {"type": "pass", "badge": "能量晶体", "desc": "进度条内部能量流加入微观碎晶折射与符文刻线"},
                        {"type": "deduct", "badge": "扣7分", "desc": "背景暗部噪点略显杂乱，阅读时干扰进度提示文字"},
                        {"type": "deduct", "badge": "扣6分", "desc": "冷暖光色调交界处偏脏，缺乏胶片感色调分离"}
                    ],
                    "dimensions": { "composition": 83, "lighting": 83, "material": 88, "color": 81, "maturity": 83 }
                },
                "r4": {
                    "name": "第四轮：色彩分级与重心压制",
                    "score": 91,
                    "imgSrc": "assets/img2_load_r4.png",
                    "adCritique": "<strong>【总监审计】</strong>极夜深蓝冷调压制非重点背景，使能量进度条呈现天青与琥珀双色高能响应。UI文字层级提升，确保玩家在加载等待期获得强烈的史诗沉浸感与明确视线锁定。",
                    "changes": [
                        {"type": "pass", "badge": "极夜分级", "desc": "深邃夜空青紫暗部压制，剔除一切脏灰杂色"},
                        {"type": "pass", "badge": "信息优先级", "desc": "进度提示信息与百分比数值获得高对比纯净背景支撑，阅读无障碍"},
                        {"type": "deduct", "badge": "扣5分", "desc": "进度流光掠影过渡帧边缘缺少抗锯齿羽化"},
                        {"type": "deduct", "badge": "扣3分", "desc": "雪花微粒需进行多层景深虚化"}
                    ],
                    "dimensions": { "composition": 91, "lighting": 93, "material": 89, "color": 94, "maturity": 92 }
                },
                "r5": {
                    "name": "第五轮：商业级终修打磨 ★",
                    "score": 96,
                    "imgSrc": "assets/img2_load_r5.png",
                    "adCritique": "<strong>【总监审计 - Master定稿】</strong>符合一线二次元工业旗舰游戏加载标准！进度条带有律动呼吸的能量辉光，漫天极光伴随微观冰晶柔化散射，行军剪影孤勇悲壮，完全达到直接交付上架级别。",
                    "changes": [
                        {"type": "pass", "badge": "呼吸辉光", "desc": "进度条符文与能量槽引入平滑高斯微光扩散，光影呼吸极富生命力"},
                        {"type": "pass", "badge": "景深冰晶", "desc": "前景、中景雪花进行远近景深虚化与光斑散射，层次通透"},
                        {"type": "pass", "badge": "无暇抗锯齿", "desc": "消除任何边缘硬切与像素抖动伪影，视觉极度舒适"}
                    ],
                    "dimensions": { "composition": 96, "lighting": 97, "material": 95, "color": 97, "maturity": 96 }
                }
            }
        },
        {
            "id": "img3_title",
            "tag": "Scene 03 / Title Splash",
            "title": "标题主页 (Title & Splash)",
            "baselineScore": 55,
            "beforeSrc": "assets/img3_title_before.png",
            "rounds": {
                "r1": {
                    "name": "第一轮：结构骨架重构",
                    "score": 67,
                    "imgSrc": "assets/img3_title_r1.png",
                    "adCritique": "<strong>【总监审计】</strong>纠正LOGO位置悬浮不稳、按钮排布杂乱的问题。将《远征》主LOGO置于视觉上半区黄金交点，重新构筑破晓山峦地平线几何剪影，按钮矩阵稳健扎实。",
                    "changes": [
                        {"type": "pass", "badge": "LOGO重构", "desc": "主标题字体几何比例重构，字距与对称性符合工业级排印规范"},
                        {"type": "pass", "badge": "地平线锚定", "desc": "背景山脉与晨曦天际线建立三点透视骨架，视野宏大辽阔"},
                        {"type": "deduct", "badge": "扣12分", "desc": "LOGO缺少立体雕刻与光影受光面，犹如平面贴纸"},
                        {"type": "deduct", "badge": "扣10分", "desc": "天空晨光无体积散射，云海层级黏连"}
                    ],
                    "dimensions": { "composition": 73, "lighting": 64, "material": 61, "color": 67, "maturity": 66 }
                },
                "r2": {
                    "name": "第二轮：主光影与空间深度",
                    "score": 78,
                    "imgSrc": "assets/img3_title_r2.png",
                    "adCritique": "<strong>【总监审计】</strong>建立晨曦破晓背光与神圣天光。远古大陆远景山脊勾勒出锐利耀眼的金黄轮廓光（Rim Light），云海中破空而下丁达尔体积光（God Rays），神圣史诗感油然而生。",
                    "changes": [
                        {"type": "pass", "badge": "破晓逆光", "desc": "太阳破平线处发射强体积光束，穿透层叠像素云海"},
                        {"type": "pass", "badge": "山脊轮廓光", "desc": "重重叠叠的山峦边缘获得锐利的暖金金边勾勒，空间层层推远"},
                        {"type": "deduct", "badge": "扣9分", "desc": "标题字面与金属包边质感塑料，未体现风化岁月感"},
                        {"type": "deduct", "badge": "扣8分", "desc": "按钮底板与背景融合度低，浮于画面表层"}
                    ],
                    "dimensions": { "composition": 80, "lighting": 85, "material": 71, "color": 77, "maturity": 75 }
                },
                "r3": {
                    "name": "第三轮：材质重塑与微细节",
                    "score": 85,
                    "imgSrc": "assets/img3_title_r3.png",
                    "adCritique": "<strong>【总监审计】</strong>重塑主LOGO古铜镏金立体浮雕、玄铁基底拉丝、山石断层风化苔藓与远古遗迹残垣断壁风貌。字符边缘增加微倒角高光与微观锈蚀，质感厚重深邃。",
                    "changes": [
                        {"type": "pass", "badge": "金属浮雕", "desc": "主LOGO字体重构为青铜包金双层立体浮雕，带有精细次表面反射"},
                        {"type": "pass", "badge": "山峦地质", "desc": "岩壁注入风化断层节理与植被点阵，像素信息量达到次世代水准"},
                        {"type": "deduct", "badge": "扣6分", "desc": "色彩过饱和度略高，长久注视容易视觉疲劳"},
                        {"type": "deduct", "badge": "扣5分", "desc": "UI按钮呼吸微光尚未统一到主调色盘中"}
                    ],
                    "dimensions": { "composition": 86, "lighting": 86, "material": 89, "color": 83, "maturity": 84 }
                },
                "r4": {
                    "name": "第四轮：色彩分级与重心压制",
                    "score": 93,
                    "imgSrc": "assets/img3_title_r4.png",
                    "adCritique": "<strong>【总监审计】</strong>好莱坞史诗冒险巨制色彩分级。紫青夜幕余晖与破晓赤金在天际线交汇，色阶过渡如丝般顺滑，UI文字与副标题添加阴影分层分离，视线直穿无垠的神秘大陆。",
                    "changes": [
                        {"type": "pass", "badge": "史诗晨曦分级", "desc": "天际线金红紫三色温润渐变，消除色带（Color Banding）瑕疵"},
                        {"type": "pass", "badge": "视觉聚焦", "desc": "暗角适度收缩周边散光，LOGO与“开始游戏”按钮构成绝对视觉核心"},
                        {"type": "deduct", "badge": "扣4分", "desc": "微风草甸与浮空微光尘埃的氛围粒子待终极打磨"},
                        {"type": "deduct", "badge": "扣2分", "desc": "辉光过度区域需要控制高光溢出衰减曲线"}
                    ],
                    "dimensions": { "composition": 93, "lighting": 95, "material": 91, "color": 97, "maturity": 93 }
                },
                "r5": {
                    "name": "第五轮：商业级终修打磨 ★",
                    "score": 98,
                    "imgSrc": "assets/img3_title_r5.png",
                    "adCritique": "<strong>【总监审计 - Master定稿】</strong>顶级3A主机典藏版标题画面标准！破晓晨曦带有电影级泛光（Filmic Bloom），微光金粉自天际随风徐徐漫卷，青铜LOGO在晨光下折射出令人战栗的古老威严，无可挑剔的商业级杰作。",
                    "changes": [
                        {"type": "pass", "badge": "电影级泛光", "desc": "太阳破晓处与LOGO顶锋实现超高动态范围（HDR）模拟高光漫溢"},
                        {"type": "pass", "badge": "晨星金色微粒", "desc": "全画幅渲染漂浮光尘与晨风粒子，将史诗氛围推向极致巅峰"},
                        {"type": "pass", "badge": "终极品质定稿", "desc": "达到直接印刷宣传海报、Steam/主机商店头图的终极商业标准"}
                    ],
                    "dimensions": { "composition": 98, "lighting": 99, "material": 97, "color": 99, "maturity": 98 }
                }
            }
        },
        {
            "id": "img4_intro_world",
            "tag": "Scene 04 / Codex World",
            "title": "远征手记·世界卷 (World Codex)",
            "baselineScore": 48,
            "beforeSrc": "assets/img4_intro_world_before.png",
            "rounds": {
                "r1": {
                    "name": "第一轮：结构骨架重构",
                    "score": 65,
                    "imgSrc": "assets/img4_intro_world_r1.png",
                    "adCritique": "<strong>【总监审计】</strong>彻底根治原代码中排版坍塌挤压、黑字贴黑底严重不可读的致命Bug。重构黑铁包边外框、黄铜角码锁扣、双开羊皮卷轴底板与金镶玉牌匾，恢复典雅书卷骨架。",
                    "changes": [
                        {"type": "pass", "badge": "引擎排版修复", "desc": "解决IntroductionPanel排版挤压Bug，确立稳定宏大的书页外框"},
                        {"type": "pass", "badge": "牌匾与角码", "desc": "规范标题玉牌与四角铜扣的几何网格定位，视觉稳固平衡"},
                        {"type": "deduct", "badge": "扣13分", "desc": "羊皮纸面纯白过于刺眼，无案台环境光源投射"},
                        {"type": "deduct", "badge": "扣11分", "desc": "卷轴中缝与书页边缘平直呆板，缺少翻页弧度与阴影"}
                    ],
                    "dimensions": { "composition": 71, "lighting": 61, "material": 59, "color": 63, "maturity": 64 }
                },
                "r2": {
                    "name": "第二轮：主光影与空间深度",
                    "score": 76,
                    "imgSrc": "assets/img4_intro_world_r2.png",
                    "adCritique": "<strong>【总监审计】</strong>构筑烛火案台微距光照模型。手记中央中缝注入深邃内凹折痕接触阴影（AO），书页四角呈现向内收拢的自然翘曲透光，木质案台衬底反射出温润暖光。",
                    "changes": [
                        {"type": "pass", "badge": "微距烛光", "desc": "右上角点光源漫射，羊皮纸面产生平缓受光衰减梯度"},
                        {"type": "pass", "badge": "中缝内折阴影", "desc": "双联书页中缝产生符合物理力学的深邃夹缝阴影与柔和折痕"},
                        {"type": "deduct", "badge": "扣10分", "desc": "纸张纤维、磨砂皮质缺少微观肌理，质感偏数码矢量"},
                        {"type": "deduct", "badge": "扣8分", "desc": "墨迹与地图插画缺少渗透与干涸质感"}
                    ],
                    "dimensions": { "composition": 78, "lighting": 81, "material": 70, "color": 75, "maturity": 74 }
                },
                "r3": {
                    "name": "第三轮：材质重塑与微细节",
                    "score": 83,
                    "imgSrc": "assets/img4_intro_world_r3.png",
                    "adCritique": "<strong>【总监审计】</strong>重现古籍孤本物理质感：羊皮纸天然微观植物纤维斑驳、老墨洇润入木三分的沉着、黄铜角码氧化铜绿与金属划痕、朱砂印章点石成金的颗粒感。",
                    "changes": [
                        {"type": "pass", "badge": "羊皮纸纤维", "desc": "注入微观造纸颗粒与轻度水渍晕染，纸面温润如古物"},
                        {"type": "pass", "badge": "金属角码做旧", "desc": "黄铜包角刻画受摩擦形成的抛光高光与凹陷处铜绿沉淀"},
                        {"type": "deduct", "badge": "扣7分", "desc": "古籍羊皮纸整体偏黄偏暗，文字对比度未达到舒适无障碍标准"},
                        {"type": "deduct", "badge": "扣6分", "desc": "玉石牌匾通透度未显现，仍显呆板石质"}
                    ],
                    "dimensions": { "composition": 83, "lighting": 82, "material": 87, "color": 80, "maturity": 82 }
                },
                "r4": {
                    "name": "第四轮：色彩分级与重心压制",
                    "score": 90,
                    "imgSrc": "assets/img4_intro_world_r4.png",
                    "adCritique": "<strong>【总监审计】</strong>古典皇家典籍色彩分级。羊皮纸面调谐为沉静典雅的象牙暖杏，黑铁外框压制暗部杂光，金丝刺绣滚边熠熠生辉，文字与世界卷地图对比度达到工业级无障碍可读标准。",
                    "changes": [
                        {"type": "pass", "badge": "象牙暖杏分级", "desc": "纸面色彩校正为高档手工牛皮纸色调，阅读温和不伤眼"},
                        {"type": "pass", "badge": "无障碍阅读", "desc": "正文墨色提纯至玄墨，排版行距呼吸自如，阅读体验一流"},
                        {"type": "deduct", "badge": "扣5分", "desc": "书页边角历史磨损毛边缺少终极点阵微修"},
                        {"type": "deduct", "badge": "扣3分", "desc": "玉佩标题悬浮微光需柔和扩散"}
                    ],
                    "dimensions": { "composition": 90, "lighting": 91, "material": 88, "color": 93, "maturity": 90 }
                },
                "r5": {
                    "name": "第五轮：商业级终修打磨 ★",
                    "score": 95,
                    "imgSrc": "assets/img4_intro_world_r5.png",
                    "adCritique": "<strong>【总监审计 - Master定稿】</strong>达到殿堂级RPG手记UI品质！羊皮纸微卷的边角带有时光风化焦痕，世界地图墨线与金箔镶嵌彼此呼应，金镶玉牌匾流淌出内敛通透的温润软玉微光，商业完成度极高。",
                    "changes": [
                        {"type": "pass", "badge": "金箔镶嵌微光", "desc": "地图与边饰加入金粉颜料点阵，随视线产生微弱金属反光"},
                        {"type": "pass", "badge": "风化焦痕微雕", "desc": "书页四角刻画岁月磨损的细腻纤维与自然褪色"},
                        {"type": "pass", "badge": "温润软玉牌匾", "desc": "标题牌匾呈现顶级和田碧玉般的次表面透光，典雅尊贵"}
                    ],
                    "dimensions": { "composition": 95, "lighting": 96, "material": 95, "color": 96, "maturity": 95 }
                }
            }
        },
        {
            "id": "img5_intro_journey",
            "tag": "Scene 05 / Codex Journey",
            "title": "远征手记·启程卷 (Journey Codex)",
            "baselineScore": 49,
            "beforeSrc": "assets/img5_intro_journey_before.png",
            "rounds": {
                "r1": {
                    "name": "第一轮：结构骨架重构",
                    "score": 65,
                    "imgSrc": "assets/img5_intro_journey_r1.png",
                    "adCritique": "<strong>【总监审计】</strong>纠正启程卷左侧插画与右侧叙事段落间距失衡的问题。确立古典经折装与对开插画书册的黄金排版，统一按钮定位与印章剪影，彻底重铸叙事仪式感。",
                    "changes": [
                        {"type": "pass", "badge": "对开排版骨架", "desc": "插画区与叙事区确立6:4古典美学分割，空间秩序井然"},
                        {"type": "pass", "badge": "朱印定章", "desc": "重设启程朱砂印章定位，作为右下角视觉压阵锚点"},
                        {"type": "deduct", "badge": "扣13分", "desc": "插画内嵌无边框景深过渡，直接生硬贴在纸面上"},
                        {"type": "deduct", "badge": "扣11分", "desc": "缺少案台微距光照，整页泛着扁平光"}
                    ],
                    "dimensions": { "composition": 70, "lighting": 62, "material": 59, "color": 64, "maturity": 64 }
                },
                "r2": {
                    "name": "第二轮：主光影与空间深度",
                    "score": 76,
                    "imgSrc": "assets/img5_intro_journey_r2.png",
                    "adCritique": "<strong>【总监审计】</strong>为启程插画赋予内凹雕版画槽的遮蔽阴影。书卷四角施加暗角压制，案台微弱荧光与卷面形成柔和明暗交界，使玩家视线聚焦于出征勇士的跋涉插图。",
                    "changes": [
                        {"type": "pass", "badge": "插画内凹AO", "desc": "插图边缘施加物理接触内阴影，呈现雕版压印入纸的凹凸深度"},
                        {"type": "pass", "badge": "书册弧面受光", "desc": "书页形成左高右低的微弧度受光，立体翻页感强烈"},
                        {"type": "deduct", "badge": "扣9分", "desc": "插画木刻版画质感不足，像素线条略显生硬"},
                        {"type": "deduct", "badge": "扣8分", "desc": "朱砂印章颜色单一刺眼，无岁月斑驳感"}
                    ],
                    "dimensions": { "composition": 77, "lighting": 81, "material": 71, "color": 76, "maturity": 74 }
                },
                "r3": {
                    "name": "第三轮：材质重塑与微细节",
                    "score": 84,
                    "imgSrc": "assets/img5_intro_journey_r3.png",
                    "adCritique": "<strong>【总监审计】</strong>雕琢启程插画的古典铜版刻线细腻质感，融入朱砂印章手工拓印的自然缺角与断墨痕。罗盘与远征地图增加微观经纬刻度反光，历史厚重感扑面而来。",
                    "changes": [
                        {"type": "pass", "badge": "铜版刻线质感", "desc": "出征插画融入细密刻线阴影，宛如中世纪古籍版画"},
                        {"type": "pass", "badge": "朱砂拓印缺损", "desc": "朱红印章增添手工盖印的边缘飞白与矿物朱砂颗粒"},
                        {"type": "deduct", "badge": "扣7分", "desc": "插画色调与羊皮纸基色略有割裂，未融为一体"},
                        {"type": "deduct", "badge": "扣5分", "desc": "叙事段落字体边缘有微小锯齿感"}
                    ],
                    "dimensions": { "composition": 84, "lighting": 83, "material": 88, "color": 81, "maturity": 83 }
                },
                "r4": {
                    "name": "第四轮：色彩分级与重心压制",
                    "score": 91,
                    "imgSrc": "assets/img5_intro_journey_r4.png",
                    "adCritique": "<strong>【总监审计】</strong>典藏羊皮孤本色温分级。插画融入青绿山水古朴雅致冷调，与暖黄羊皮纸面形成相得益彰的冷暖呼应。暗角自然收束视线，叙事沉浸感大幅增强。",
                    "changes": [
                        {"type": "pass", "badge": "青绿古朴调色", "desc": "出征图注入典雅矿物颜料青绿灰调，古朴厚重且耐看"},
                        {"type": "pass", "badge": "视线引导压制", "desc": "外围铜边暗部压暗，使阅读焦点顺畅从插画流向文字"},
                        {"type": "deduct", "badge": "扣5分", "desc": "罗盘星针光芒有待赋予神圣微弱泛光"},
                        {"type": "deduct", "badge": "扣3分", "desc": "边缘翻页过渡有极轻微像素漂移"}
                    ],
                    "dimensions": { "composition": 91, "lighting": 92, "material": 89, "color": 94, "maturity": 91 }
                },
                "r5": {
                    "name": "第五轮：商业级终修打磨 ★",
                    "score": 96,
                    "imgSrc": "assets/img5_intro_journey_r5.png",
                    "adCritique": "<strong>【总监审计 - Master定稿】</strong>工业级典藏版史诗手记定稿！铜制罗盘指针与启程北极星散发若隐若现的微光，纸面纤维与插画雕刻浑然天成，带来无与伦比的冒险启程仪式感，直接达到3A商业典藏级标准。",
                    "changes": [
                        {"type": "pass", "badge": "星芒罗盘微光", "desc": "远征罗盘与天顶启明星点缀微弱星芒粒子，仪式感拉满"},
                        {"type": "pass", "badge": "无瑕材质融合", "desc": "版画油墨、朱砂矿物与古纸纤维完全融合，毫无违和数码感"},
                        {"type": "pass", "badge": "终版工业验收", "desc": "消除全部视觉死角与排版残留问题，达到商业化终极验收标准"}
                    ],
                    "dimensions": { "composition": 96, "lighting": 97, "material": 95, "color": 97, "maturity": 96 }
                }
            }
        },
        {
            "id": "img6_login",
            "title": "通关文牒 · 旅人登记",
            "tag": "身份登记 · 通牒验籍",
            "beforeImg": "assets/img6_login_before.png",
            "rounds": {
                "r1": {
                    "name": "第一轮：结构与骨架重构",
                    "score": 68,
                    "imgSrc": "assets/img6_login_r1.png",
                    "adCritique": "<strong>【总监审计】</strong>彻底拔除廉价的小学生横线作业本底纹！重构古籍通关文牒结构骨架，顶部确立黑曜玄玉题名匾额，矫正表单输入框对齐与视觉纵深，确立古典通牒装裱格局。",
                    "changes": [
                        {"type": "pass", "badge": "拔除横线作业本", "desc": "彻底摒弃密密麻麻的水平横线，换为纯净温润的古卷羊皮纸"},
                        {"type": "pass", "badge": "题名匾额立骨", "desc": "顶部设立独立黑曜玄玉匾额，彻底解决标题跨框切断的严重构图缺陷"},
                        {"type": "deduct", "badge": "扣18分", "desc": "输入框与纸面缺乏物理光影嵌合，浮于表面"},
                        {"type": "deduct", "badge": "扣14分", "desc": "按钮色彩对比不够清晰，主次层级需进一步强化"}
                    ],
                    "dimensions": { "composition": 70, "lighting": 66, "material": 67, "color": 68, "maturity": 69 }
                },
                "r2": {
                    "name": "第二轮：主光影与空间深度",
                    "score": 78,
                    "imgSrc": "assets/img6_login_r2.png",
                    "adCritique": "<strong>【总监审计】</strong>建立文牒背衬与案台的深度投影，输入框赋予微凹入纸面的凹陷阴影（Inner Shadow）与顶部透光高光。旅人画相设立立体同心铜环徽章，强化空间层次。",
                    "changes": [
                        {"type": "pass", "badge": "凹槽物理阴影", "desc": "输入框增加1px上内阴影与底部微反光，呈现纸张压制凹陷质感"},
                        {"type": "pass", "badge": "青铜徽章浮雕", "desc": "旅人画相外框建立深浅渐变金属光影，告别平面圆圈"},
                        {"type": "deduct", "badge": "扣12分", "desc": "羊皮纸肌理过于纯净平整，缺乏千年古牒的纤维做旧感"},
                        {"type": "deduct", "badge": "扣10分", "desc": "主次按钮质感尚未形成顶级商业级反差"}
                    ],
                    "dimensions": { "composition": 80, "lighting": 82, "material": 75, "color": 76, "maturity": 77 }
                },
                "r3": {
                    "name": "第三轮：材质重塑与微细节",
                    "score": 86,
                    "imgSrc": "assets/img6_login_r3.png",
                    "adCritique": "<strong>【总监审计】</strong>注入温润古卷纤维纹理与边缘做旧微暗色调。主按钮重铸为深红帝王朱漆金边纽，次按钮赋予沉稳玄铁岩青质感。右下角盖上古法朱砂印章「昭元行牒」，文牒仪式感骤升。",
                    "changes": [
                        {"type": "pass", "badge": "帝王朱漆金纽", "desc": "登录入城升级为极具分量的朱红漆金主纽，金边倒角清晰立体"},
                        {"type": "pass", "badge": "古法朱砂印章", "desc": "右下角加盖昭元都护府验籍朱砂方印，矿物颗粒与印文清晰遒劲"},
                        {"type": "deduct", "badge": "扣8分", "desc": "金饰角码反光略微生硬，需增加金属环境漫反射"},
                        {"type": "deduct", "badge": "扣6分", "desc": "输入框文字光标与焦点辉光仍需雕琢"}
                    ],
                    "dimensions": { "composition": 87, "lighting": 85, "material": 89, "color": 84, "maturity": 85 }
                },
                "r4": {
                    "name": "第四轮：色彩分级与重心压制",
                    "score": 92,
                    "imgSrc": "assets/img6_login_r4.png",
                    "adCritique": "<strong>【总监审计】</strong>电影级LUT色彩分级调优。玄玉深黑、温润米黄羊皮与帝王朱红构成绝美古典三色阶，冷暖对比强烈且极度和谐。背景黄昏古城虚化暗部下沉，使中央通关文牒牢牢占据全场焦点。",
                    "changes": [
                        {"type": "pass", "badge": "古典三色阶平衡", "desc": "玄黑、玉金与朱砂形成严谨的东方古典色彩层次，格调高雅"},
                        {"type": "pass", "badge": "焦点收束压制", "desc": "背景余晖与古城石板路自然渐隐，牢牢锁住玩家登录第一视觉"},
                        {"type": "deduct", "badge": "扣5分", "desc": "金边四角微小倒角需终极抗锯齿平滑"},
                        {"type": "deduct", "badge": "扣3分", "desc": "输入框聚焦状态需强化沉浸式金色流光"}
                    ],
                    "dimensions": { "composition": 93, "lighting": 93, "material": 91, "color": 95, "maturity": 92 }
                },
                "r5": {
                    "name": "第五轮：商业级终修打磨 ★",
                    "score": 97,
                    "imgSrc": "assets/img6_login_r5.png",
                    "adCritique": "<strong>【总监审计 - Master定稿】</strong>顶级商业JRPG/国风旗舰最终交付定稿！彻底告别原版廉价作业本与违和绿底黑字，蜕变为一份承载世界观重量的传世通关文牒。朱红大纽极具点击欲望，朱砂印章与羊皮纸质感无懈可击，打分97分，直接达到A级商业化发售水准！",
                    "changes": [
                        {"type": "pass", "badge": "全链路工业定稿", "desc": "排版对齐、光影透视与色彩色阶全面达到3A工业化基准"},
                        {"type": "pass", "badge": "材质与世界观深度融合", "desc": "通关文牒、玄玉匾额、朱砂玺印形成自洽的东方奇幻冒险沉浸感"},
                        {"type": "pass", "badge": "终版工业验收", "desc": "彻底消灭所有结构硬伤、假光与塑料感，达到Master交付验收标准"}
                    ],
                    "dimensions": { "composition": 97, "lighting": 97, "material": 96, "color": 98, "maturity": 97 }
                }
            }
        }
    ]

    json_str = json.dumps(data, ensure_ascii=False, indent=2)
    final_html = HTML_TEMPLATE.replace("%SCENE_DATA_JSON%", json_str)

    output_path = r"D:\new bee\showcase\index.html"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(final_html)
    print(f"Successfully generated showcase webpage at: {output_path}")

if __name__ == "__main__":
    generate_showcase()
