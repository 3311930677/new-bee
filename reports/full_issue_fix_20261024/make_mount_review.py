"""Read-only contact sheets for reviewing every authored pose at display scale."""
from pathlib import Path
from PIL import Image, ImageDraw

report = Path(__file__).resolve().parent
assets = report.parents[1] / '远征/assets/full_issue_fix_20261024/ready'
for mount in ['horse','bear']:
    for direction in ['down','left','right','up']:
        for action,start,count in [('idle',0,4),('walk',4,8),('run',12,12)]:
            sheet = Image.new('RGB',(count*128,4*158),'#25343b')
            draw = ImageDraw.Draw(sheet)
            for index,role in enumerate(['zs','ck','fs','fz']):
                with Image.open(assets / f'{mount}_{role}_{direction}.png') as source:
                    for cel in range(count):
                        at = start + cel
                        pose = source.crop((at%4*192,at//4*192,(at%4+1)*192,(at//4+1)*192)).resize((128,128),Image.Resampling.NEAREST)
                        sheet.paste(pose,(cel*128,index*158+25),pose)
                        draw.text((cel*128+4,index*158+6),f'{role} {cel}',fill='white')
            sheet.save(report / f'review_{mount}_{direction}_{action}.png')
print('MOUNT_CONTACT_SHEETS_SAVED 24')
