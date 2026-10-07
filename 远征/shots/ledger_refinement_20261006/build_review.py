from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
FONT = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 20)
SMALL = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 15)


def sheet(entries, name, title, width=280, height=467):
    canvas = Image.new('RGB', (len(entries) * (width + 16) + 16, height + 94), '#182923')
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 12), title, font=FONT, fill='#e6d0a0')
    for i, (path, caption) in enumerate(entries):
        shot = Image.open(path).convert('RGB')
        shot.thumbnail((width, height), Image.Resampling.LANCZOS)
        x = 16 + i * (width + 16)
        canvas.paste(shot, (x + (width - shot.width) // 2, 50))
        draw.text((x, height + 62), caption, font=SMALL, fill='#e3deca')
    canvas.save(OUT / name)


sheet([(OUT / 'slope_order_800.png', '可接取 · 规则入口'),
       (OUT / 'city_order_800.png', '接单操作 · 独立规则按钮'),
       (OUT / 'commission_800.png', '同一套卡片与状态标志')],
      'ledger_samples.png', '商路与委托 · 实际游戏界面')
sheet([(OUT / f'slope_{state}_800.png', caption) for state, caption in
       [('order', '可接取'), ('active', '运送中'), ('expired', '已逾期')]],
      'status_states.png', '状态使用文字与颜色双重区分')
sheet([(OUT / 'frost_contract_800.png', '霜关药单'),
       (OUT / 'contracts_800.png', '三城合约'),
       (OUT / 'commission_800.png', '世界委托')],
      'related_panels.png', '行旅面板 · 共用材质与排版')
before = ROOT / 'shots/trade_shadow_20261005/slope_camp_page1_800.png'
if before.exists():
    sheet([(before, '上一版'), (OUT / 'slope_order_800.png', '本次修改')],
          'before_after.png', '商路运单 · 布局与色调对照', width=360, height=600)
records = json.loads((OUT / 'panel_capture_index.json').read_text(encoding='utf-8'))
assert len(records) == 18
audit = {'captures': len(records), 'text_nodes': 0, 'issues': []}
for row in records:
    file = OUT / Path(row['path']).name
    assert list(Image.open(file).size) == [480, row['height']]
    data = json.loads(file.with_suffix('.text.json').read_text(encoding='utf-8'))
    audit['text_nodes'] += len(data['text_nodes'])
    for key in ['nonlinear_text', 'compact_art', 'short_text_boxes']:
        audit['issues'].extend({'capture': file.name, 'issue': key, **item} for item in data[key])
(OUT / 'text_audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding='utf-8')
assert not audit['issues'], audit['issues']
print(f"LEDGER_REVIEW_OK captures={audit['captures']} text_nodes={audit['text_nodes']} issues=0")
