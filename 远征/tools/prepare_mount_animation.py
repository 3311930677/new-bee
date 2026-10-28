"""Extract generated animation cels; retain alpha and one scale per sheet.

This prepares existing authored poses, never synthesizes anatomy or repeats cels.
Row cuts follow transparent gutters, since source sheets can drift off exact grid.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/full_issue_fix_20261024'
REPORT = ROOT.parent / 'reports/full_issue_fix_20261024'
CELL, FOOT = 192, 176

def remove_dust(cell):
    alpha=cell.getchannel('A'); width,height=cell.size
    data=bytearray(alpha.tobytes()); seen=bytearray(width*height)
    for start,value in enumerate(data):
        if value<=30 or seen[start]:continue
        seen[start]=1;todo=[start];component=[]
        while todo:
            at=todo.pop();component.append(at);x=at%width
            for nxt in ([at-1] if x else [])+([at+1] if x+1<width else [])+([at-width] if at>=width else [])+([at+width] if at+width<len(data) else []):
                if data[nxt]>30 and not seen[nxt]:seen[nxt]=1;todo.append(nxt)
        if len(component)<20:
            for at in component:data[at]=0
    cell.putalpha(Image.frombytes('L',(width,height),bytes(data)))
    return cell

def cut_lines(alpha, divisions, axis):
    length = alpha.height if axis == 'y' else alpha.width
    result = [0]
    for index in range(1, divisions):
        nominal = round(length * index / divisions)
        radius = round(length / divisions * .15)
        def coverage(at):
            strip = alpha.crop((0, at, alpha.width, at+1) if axis == 'y' else (at, 0, at+1, alpha.height))
            return sum(v > 30 for v in strip.get_flattened_data()), abs(at-nominal)
        result.append(min(range(nominal-radius, nominal+radius+1), key=coverage))
    return result + [length]

def extract_poses(source,expected=24,columns=4):
    """Find the 24 connected silhouettes without cutting through a painted pose."""
    width,height=source.size
    alpha=source.getchannel('A'); data=alpha.tobytes(); seen=bytearray(width*height)
    components=[]
    for start,value in enumerate(data):
        if value<=30 or seen[start]:continue
        seen[start]=1;todo=[start];pixels=[];left=width;right=0;top=height;bottom=0
        while todo:
            at=todo.pop();pixels.append(at);x=at%width;y=at//width
            left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y)
            for dy in [-1,0,1]:
                ny=y+dy
                if ny<0 or ny>=height:continue
                for dx in [-1,0,1]:
                    nx=x+dx
                    if (dx==0 and dy==0) or nx<0 or nx>=width:continue
                    nxt=ny*width+nx
                    if data[nxt]>30 and not seen[nxt]:seen[nxt]=1;todo.append(nxt)
        if len(pixels)>=20:components.append({'pixels':pixels,'bbox':(left,top,right+1,bottom+1),'area':len(pixels)})
    bodies=sorted(components,key=lambda c:c['area'],reverse=True)[:expected]
    if len(bodies)!=expected or min(c['area'] for c in bodies)<max(c['area'] for c in bodies)*.2:
        raise ValueError('source does not contain 24 complete separate body silhouettes: '+str([(c['area'],c['bbox']) for c in sorted(components,key=lambda c:c['area'],reverse=True)[:28]]))
    bodies.sort(key=lambda c:(c['bbox'][1]+c['bbox'][3])/2)
    ordered=[]
    for row in range(expected//columns):ordered+=sorted(bodies[row*columns:row*columns+columns],key=lambda c:c['bbox'][0])
    small=[c for c in components if c not in bodies]
    frames=[];bounds=[];clipped=[]
    for index,body in enumerate(ordered):
        left,top,right,bottom=body['bbox']
        if min(left,top)<=0 or right>=width or bottom>=height:clipped.append(index)
        pixels=list(body['pixels'])
        for part in small:
            a,b,c,d=part['bbox']
            if a>=left-6 and c<=right+6 and b>=top-6 and d<=bottom+6:pixels+=part['pixels']
        # Build only this component's mask, preventing neighboring hooves or cloaks.
        mask=bytearray(width*height)
        for at in pixels:mask[at]=data[at]
        pose=source.copy();pose.putalpha(Image.frombytes('L',(width,height),bytes(mask)))
        bbox=pose.getchannel('A').getbbox()
        frames.append(pose.crop(bbox));bounds.append(list(bbox))
    return frames,bounds,clipped

def prepare(job):
    identifier = '_'.join(job[k] for k in ['mount', 'role', 'direction'])
    source = Image.open(job['path']).convert('RGBA')
    master = ASSETS / 'source' / (identifier+'.png')
    shutil.copy2(job['path'], master)
    supplements=job.get('supplements',[])
    expected=supplements[0]['base_count'] if supplements else 24
    frames,bounds,clipped = extract_poses(source,expected)
    replaced=set()
    for supplement in supplements:
        extra=Image.open(supplement['path']).convert('RGBA')
        extra_frames,extra_bounds,extra_clipped=extract_poses(extra,supplement['count'],2 if supplement['count']==4 else 1)
        if extra_clipped:raise ValueError('supplement has clipped body')
        references=frames[12:20] if supplement['count']==4 else [frames[supplement['indices'][0]]]
        reference_height=sorted(p.height for p in references)[len(references)//2]
        factor=reference_height/sorted(p.height for p in extra_frames)[len(extra_frames)//2]
        for index,pose in zip(supplement['indices'],extra_frames):
            pose=pose.resize((round(pose.width*factor),round(pose.height*factor)),Image.Resampling.NEAREST)
            if index<len(frames):frames[index]=pose;bounds[index]=extra_bounds[supplement['indices'].index(index)];replaced.add(index)
            else:frames.append(pose);bounds.append(extra_bounds[supplement['indices'].index(index)])
        shutil.copy2(supplement['path'],ASSETS/'source'/(identifier+'_supplement_'+str(supplement['indices'][0])+'.png'))
    if set(clipped)-replaced:raise ValueError('source silhouettes clipped at sheet edge: '+str(clipped))
    if len(frames)!=24:raise ValueError('authored pose count must equal 24')
    factor = min(118 / sorted(f.height for f in frames[:4])[2], 180 / max(f.width for f in frames), 134 / max(f.height for f in frames))
    atlas = Image.new('RGBA', (CELL*4, CELL*6))
    prepared = []
    hashes = []
    for index, frame in enumerate(frames):
        frame = frame.resize((max(1,round(frame.width*factor)), max(1,round(frame.height*factor))), Image.Resampling.NEAREST)
        cel = Image.new('RGBA', (CELL,CELL))
        lift = [0,0,3,7,9,5,0,0,3,7,9,5][index-12] if index >= 12 else 0
        cel.alpha_composite(frame, ((CELL-frame.width)//2, FOOT-frame.height-lift))
        atlas.alpha_composite(cel, ((index%4)*CELL, (index//4)*CELL))
        prepared.append(cel)
        hashes.append(hashlib.sha256(cel.tobytes()).hexdigest())
    if len(set(hashes)) != 24: raise ValueError('duplicate poses '+identifier)
    path = ASSETS / 'ready' / (identifier+'.png')
    atlas.save(path, optimize=True)
    for action, start, end, duration in [('idle',0,4,200),('walk',4,12,110),('run',12,24,65)]:
        preview=[]
        for cel in prepared[start:end]:
            canvas=Image.new('RGBA',(CELL,CELL),'#25343b');canvas.alpha_composite(cel)
            ImageDraw.Draw(canvas).line((0,FOOT,CELL,FOOT),fill='#738374')
            preview.append(canvas.convert('RGB').resize((320,320),Image.Resampling.NEAREST))
        preview[0].save(REPORT/'motion'/(identifier+'_'+action+'.gif'),save_all=True,append_images=preview[1:],duration=duration,loop=0)
    return {**job, 'source':str(master.relative_to(ROOT)), 'texture':'res://'+path.relative_to(ROOT).as_posix(), 'cell':CELL,'foot':[96,FOOT], 'frames':{'idle':4,'walk':8,'run':12},'unique_frames':len(set(hashes)), 'source_edge_clipping':clipped,'extraction_bounds':bounds,'scale':factor,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('manifest');args=parser.parse_args()
    ASSETS.joinpath('source').mkdir(parents=True,exist_ok=True)
    ASSETS.joinpath('ready').mkdir(exist_ok=True)
    REPORT.joinpath('motion').mkdir(parents=True,exist_ok=True)
    jobs=json.loads(Path(args.manifest).read_text(encoding='utf-8'))
    results=[];rejected=[]
    for job in jobs:
        identifier='_'.join(job[k] for k in ['mount','role','direction'])
        print('PREPARE',identifier,flush=True)
        try:results.append(prepare(job))
        except ValueError as error:
            rejected.append({**job,'reason':str(error)})
            print('REJECT',identifier,str(error)[:130],flush=True)
    (REPORT/'mount_rejected.json').write_text(json.dumps(rejected,ensure_ascii=False,indent=2),encoding='utf-8')
    (REPORT/'mount_preparation.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    runtime={}
    for result in results:runtime.setdefault(result['mount'],{}).setdefault(result['role'],{})[result['direction']]=result['texture']
    (ROOT/'data/mount_animation_20261024.json').write_text(json.dumps(runtime,indent=2),encoding='utf-8')
    print('Prepared',len(results),'sheets;',len(results)*24,'unique authored cels; rejected',len(rejected))

if __name__=='__main__':main()
