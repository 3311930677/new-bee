"""Record real Godot UI motion and package frames with a stable GIF palette."""
from pathlib import Path
import argparse, os, subprocess
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot',required=True)
    args=parser.parse_args()
    output=PROJECT/'shots/frontend_overhaul_20261004/motion'
    output.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy()
    for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
        runtime=PROJECT/'Godot/ui_refinement_runtime'/folder
        runtime.mkdir(parents=True,exist_ok=True)
        env[key]=str(runtime)
    run=subprocess.run([args.godot,'--path',str(PROJECT),'--position','-4000,-4000',
                        'res://tools/MotionPreviewRunner.tscn'],env=env,capture_output=True,timeout=120,
                       creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
    log=(run.stdout+run.stderr).decode('utf-8',errors='replace')
    (output/'capture.log').write_text(log,encoding='utf-8')
    if run.returncode or 'MOTION_PREVIEW_OK' not in log or 'SCRIPT ERROR' in log:
        raise RuntimeError(log)
    for key,expected in [('home',30),('pages',18),('dialogue',30)]:
        sources=sorted((output/key).glob('*.png'))
        assert len(sources)==expected,(key,len(sources))
        frames=[Image.open(source).convert('RGB') for source in sources]
        samples=Image.new('RGB',(240*5,400))
        for i in range(5):
            samples.paste(frames[round((len(frames)-1)*i/4)].resize((240,400)),(240*i,0))
        palette=samples.quantize(colors=256,dither=Image.Dither.NONE)
        gif=[frame.quantize(palette=palette,dither=Image.Dither.NONE) for frame in frames]
        gif[0].save(output/(key+'.gif'),save_all=True,append_images=gif[1:],duration=75,loop=0,
                    optimize=False,disposal=2)
        print('MOTION_OK',key,len(gif),'frames',flush=True)

if __name__=='__main__': main()
