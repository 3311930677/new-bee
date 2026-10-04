"""Package native game captures into an animation and comparison review."""
from pathlib import Path
import json
from PIL import Image
from capture_checks import failures

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'shots/finesse_20261004'


def main():
    motion = OUT / 'motion'
    log = (motion/'capture.log').read_text(encoding='utf-8')
    assert 'MOTION_PREVIEW_OK finesse' in log and not failures(log), log
    counts = {'home':24,'altar':20,'single':56,'ten':70,'training':34}
    for key, count in counts.items():
        files = sorted((motion/key).glob('*.png'))
        assert len(files)==count, (key,len(files))
        frames = [Image.open(p).convert('RGB') for p in files]
        assert all(any(a!=b for a,b in f.getextrema()) for f in frames), key
        sheet = Image.new('RGB',(480*5,800))
        for i in range(5):
            sheet.paste(frames[round((count-1)*i/4)],(480*i,0))
        palette = sheet.quantize(colors=256,dither=Image.Dither.NONE)
        gifs = [f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
        gifs[0].save(motion/(key+'.gif'),save_all=True,append_images=gifs[1:],
                     duration=70,loop=0,optimize=False,disposal=2)
    results = json.loads((OUT/'results.json').read_text(encoding='utf-8'))
    assert len(results)==16 and all(r['passed'] for r in results)
    labels = {'home':'行旅营帐','gacha':'灵宠召唤','bag':'背包','settings':'设置',
              'growth':'养成','forge_enhance':'强化','forge_gem':'宝石','pet_raise':'灵宠培养'}
    gallery = ''.join(f'<figure class="shot"><img loading="lazy" src="480x800/{k}.png" alt="{v}"><figcaption>{v}</figcaption></figure>'
                      for k,v in labels.items())
    animations = ''.join(f'<figure class="motion"><img loading="lazy" src="motion/{k}.gif" alt="{v}"><figcaption><b>{v}</b><span>{desc}</span></figcaption></figure>' for k,v,desc in [
        ('single','单抽 · 星阵唤灵','星阵聚合 → 灵契展开 → 翻面揭晓 → 稀有光纹'),
        ('ten','十连 · 依次揭晓','卡牌错峰展开，逐张揭晓，全部完成后显示摘要'),
        ('training','养成 · 成长反馈','成功喂养、升级与突破有独立光纹反馈'),
        ('home','营帐 · 徽记与交互','罗盘、盾徽、叶纹、星芒与轻微悬停反馈')])
    html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>远征 · 细节与动效</title><style>
*{box-sizing:border-box}body{margin:0;background:#161b23;color:#e9e2d4;font:16px/1.7 system-ui,sans-serif}main{max-width:1220px;margin:auto;padding:48px 24px}h1{font-size:38px;margin:6px 0 10px;font-weight:600}h2{font-size:25px;font-weight:500;margin:44px 0 18px}p{color:#aeb6bd;max-width:750px}small{letter-spacing:4px;color:#c8ae82}nav{display:flex;gap:12px;flex-wrap:wrap;margin:28px 0}a{color:#e8d0a5;text-decoration:none}nav a{padding:7px 18px;border:1px solid #46505a;border-radius:24px}figure{margin:0}img{display:block;max-width:100%;height:auto}.motions{display:grid;grid-template-columns:repeat(4,1fr);gap:20px}.motion{background:#222a33;border-radius:12px;overflow:hidden}.motion img{width:100%}figcaption{padding:14px 16px}figcaption span{display:block;font-size:13px;color:#aeb6bd;margin-top:6px}.gallery{display:grid;grid-template-columns:repeat(4,1fr);gap:20px}.shot{background:#232930;border-radius:10px;overflow:hidden}.compare{display:grid;grid-template-columns:1fr 1fr;max-width:820px;gap:24px}.compare img{width:100%}footer{margin-top:44px;border-top:1px solid #3b454e;padding-top:20px;color:#929da6;font-size:13px}.size-links{display:flex;gap:10px;flex-wrap:wrap}.size-links a{font-size:13px;padding:3px 10px;background:#293440;border-radius:5px}
@media(max-width:900px){.motions,.gallery{grid-template-columns:repeat(2,1fr)}}@media(max-width:520px){main{padding:28px 16px}h1{font-size:29px}.motions{grid-template-columns:1fr}.gallery{gap:12px}.compare{gap:12px}figcaption{padding:9px}}
</style><main><small>昭元行旅录</small><h1>让每一次结缘，都有仪式感。</h1><p>这次集中打磨召唤演出、营帐徽记和成功反馈。保留像素素材的清晰轮廓，减少重复边框、刺眼爆闪和杂乱纹理。</p><nav><a href="#motion">看动效</a><a href="#compare">主页前后</a><a href="#pages">其他页面</a></nav>
<h2 id="motion">真实游戏动效</h2><div class="motions">ANIMATIONS</div>
<h2 id="compare">主页 · 不同功能，不同造型</h2><div class="compare"><figure><img loading="lazy" src="../frontend_overhaul_20261004/480x800/home.png" alt="修改前"><figcaption>修改前</figcaption></figure><figure><img loading="lazy" src="480x800/home.png" alt="修改后"><figcaption>修改后 · 独立徽记，柔和层次</figcaption></figure></div>
<h2 id="pages">页面细节</h2><div class="gallery">GALLERY</div><h2>长屏预览</h2><div class="size-links">LINKS</div><footer>来自游戏实际运行画面。演出可跳过；揭晓完成后再抽恢复可用。单抽预览使用隔离的传说演示奖池，正式概率、价格和保底规则保持原样。</footer></main></html>'''
    links = ''.join(f'<a href="480x1067/{k}.png">{v}</a>' for k,v in labels.items())
    (OUT/'index.html').write_text(html.replace('ANIMATIONS',animations).replace('GALLERY',gallery).replace('LINKS',links),encoding='utf-8')
    (OUT/'validation.json').write_text(json.dumps({'screenshots':len(results),'motion_frames':sum(counts.values()),
            'animations':list(counts),'regressions':8,'motion_capture_errors':failures(log)},ensure_ascii=False,indent=2),encoding='utf-8')
    print('FINESSE_REVIEW_OK',len(results),'screenshots',sum(counts.values()),'motion frames')

if __name__=='__main__': main()
