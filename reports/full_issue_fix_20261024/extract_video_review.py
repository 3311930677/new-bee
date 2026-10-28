from pathlib import Path
import shutil
import subprocess
import sys
from PIL import Image,ImageDraw

root=Path(__file__).resolve().parent
ffmpeg=shutil.which('ffmpeg') or r'C:\Users\tsz\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.1-full_build\bin\ffmpeg.exe'
for identifier in sys.argv[1:]:
    directory=root/identifier
    target=directory/'video_review'
    target.mkdir(exist_ok=True)
    sheet=Image.new('RGB',(8*240,560),'#25343b')
    for index,second in enumerate([3,4,7,8,11,12,15,16]):
        frame=target/f'frame_{second}.png'
        subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-ss',str(second),'-i',str(directory/'native_screenrecord.mp4'),'-frames:v','1','-y',str(frame)],check=True,timeout=30)
        with Image.open(frame) as image:
            image.thumbnail((230,515))
            sheet.paste(image,(index*240+(240-image.width)//2,32))
        ImageDraw.Draw(sheet).text((index*240+5,10),f'{second}s',fill='white')
    sheet.save(target/'contact.jpg',quality=95)
    print('VIDEO_REVIEW_READY',identifier)
