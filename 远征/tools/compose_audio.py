"""Original frontier chamber loops and restrained acoustic-inspired feedback.

Deterministic additive synthesis, no downloaded recordings or third-party samples.
Run with the bundled numpy runtime. Wrapped note tails make BGM sample loops seamless.
"""
from pathlib import Path
import wave
import numpy as np
import make_sfx as fx

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio'
SR = 32000
RNG = np.random.default_rng(20261024)

def write(name, audio, rate=SR, peak=.55):
    a = np.asarray(audio,dtype=np.float64)
    a -= a.mean()
    a *= peak / max(float(abs(a).max()),1e-8)
    if not name.startswith('bgm_'):
        n=min(len(a),int(rate*.008));a[:n]*=np.linspace(0,1,n);a[-n:]*=np.linspace(1,0,n)
    with wave.open(str(OUT/(name+'.wav')),'wb') as stream:
        stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(rate)
        stream.writeframes((np.clip(a,-1,1)*32767).astype('<i2').tobytes())

def note(midi, duration, kind='string'):
    t=np.arange(int(duration*SR))/SR
    f=440*2**((midi-69)/12)
    if kind=='flute':
        tone=np.sin(2*np.pi*f*t+.002*np.sin(2*np.pi*4*t))+.14*np.sin(2*np.pi*2*f*t)
        env=np.minimum(t/.12,1)*np.minimum((duration-t)/.20,1)*np.exp(-t*.25)
    else:
        tone=sum(np.sin(2*np.pi*f*k*t+(.2 if k%2 else 0))*np.exp(-t*(1.8+k*.7))/(k**1.5) for k in range(1,7))
        env=np.minimum(t/.008,1)*np.minimum((duration-t)/.06,1)
    return tone*env

def add(track, audio, at, gain):
    start=int(at*SR)%len(track)
    # All sustained tails wrap into the beginning of the same musical phrase.
    for cursor in range(0,len(audio),len(track)):
        part=audio[cursor:cursor+len(track)];n=min(len(part),len(track)-start)
        track[start:start+n]+=part[:n]*gain
        if n<len(part):track[:len(part)-n]+=part[n:]*gain

def music(name,bpm,root,melody,energy):
    beat=60/bpm
    track=np.zeros(round(64*beat*SR))
    chords=[0,-3,-5,-2,0,-5,-3,-2]
    scale=[0,2,4,7,9]
    for bar,chord in enumerate(chords):
        for pulse in range(8):
            at=(bar*8+pulse)*beat
            add(track,note(root+chord+[0,7,12,7][pulse%4],2.8*beat),at,.25)
            if pulse%2==0:add(track,note(root+chord-12,3.5*beat),at,.15)
            if energy>.5:
                t=np.arange(int(.16*SR))/SR
                drum=np.sin(2*np.pi*(85*t-50*t*t))*np.exp(-t*35)
                add(track,drum,at,.10)
        for j,degree in enumerate(melody[bar%len(melody)]):
            if degree<0:continue
            midi=root+12+scale[degree%5]+12*(degree//5)
            add(track,note(midi,1.7*beat,'flute'),(bar*8+j*2)*beat,.20)
    write(name,track,peak=.43 if energy<.5 else .52)

def hoof(name,frequency,texture,peak):
    n=int(.115*SR);t=np.arange(n)/SR
    noise=RNG.normal(0,1,n)
    smoothed=np.convolve(noise,np.ones(texture)/texture,'same')
    body=np.sin(2*np.pi*frequency*t)*np.exp(-t*65)
    write(name,.7*body+.30*smoothed*np.exp(-t*85),peak=peak)

def acoustic_ui(kind):
    durations={'ui_click':.065,'ui_open':.15,'ui_close':.12,'ui_page':.19}
    duration=durations[kind];n=int(duration*fx.SR);t=np.arange(n)/fx.SR
    noise=fx.lp(RNG.normal(0,1,n),1700)
    if kind=='ui_click':
        return (noise+.3*np.sin(2*np.pi*340*t))*fx.env(n,.012,attack=.001)
    paper=fx.hp(noise,400)*np.sin(np.pi*t/duration)**1.4
    tap=.20*np.sin(2*np.pi*240*t)*fx.env(n,.025,attack=.002)
    return paper+tap

def combat_profiles():
    for kind in ['blade','bow','frost','radiant']:
        duration=.22 if kind in ['blade','bow'] else .36
        n=int(duration*fx.SR);t=np.arange(n)/fx.SR
        noise=fx.lp(RNG.normal(0,1,n),3600)
        if kind=='blade':audio=noise*np.sin(np.pi*t/duration)**2+.12*fx.metal(460,n,.04)
        elif kind=='bow':audio=.35*fx.thud(260,n,.035)+noise*fx.env(n,.04)
        elif kind=='frost':audio=.25*fx.metal(950,n,.11)+noise*fx.env(n,.09,attack=.03)
        else:audio=fx.bell(660,n,.13)+.18*fx.bell(990,n,.1)
        write('cast_'+kind,audio,rate=fx.SR,peak=.40)
        impact=(fx.lp(noise,2300)*fx.env(n,.027)+.4*fx.thud(170,n,.04))
        if kind in ['frost','radiant']:impact+=.22*audio
        write('hit_'+('arrow' if kind=='bow' else kind),impact,rate=fx.SR,peak=.46)

def main():
    # Replace piercing synthetic pings with shorter, low-passed acoustic transients.
    for function in fx.UI_SFX+fx.REWARD_SFX+fx.BATTLE_SFX+fx.EXPLORE_SFX:
        a=acoustic_ui(function.__name__) if function.__name__ in ['ui_click','ui_open','ui_close','ui_page'] else function()
        cutoff=2400 if function in fx.UI_SFX else 4200
        a=fx.lp(a,cutoff)
        if function in fx.UI_SFX:
            a=fx.lp(a,1800)
        peak=.30 if function in fx.UI_SFX else .45 if function in fx.REWARD_SFX else .50
        write(function.__name__,a,rate=fx.SR,peak=peak)
    hoof('mount_hoof',175,10,.30)
    hoof('hoof_stone',230,4,.32)
    hoof('hoof_wood',160,12,.30)
    hoof('hoof_snow',130,26,.22)
    hoof('hoof_sand',145,18,.24)
    combat_profiles()
    music('bgm_title',66,50,[[0,2,3,2],[1,0,2,-1],[3,4,3,2],[1,2,0,-1]],.2)
    music('bgm_home',72,55,[[0,1,2,1],[2,3,2,0],[1,2,4,3],[2,1,0,-1]],.3)
    music('bgm_city',78,55,[[0,2,1,3],[2,4,3,2],[1,0,2,1],[3,2,0,-1]],.4)
    music('bgm_route',80,50,[[0,1,3,2],[1,2,4,3],[2,1,0,1],[3,2,1,0]],.55)
    music('bgm_map',64,48,[[0,-1,2,-1],[1,3,-1,2],[0,-1,1,-1],[3,2,1,-1]],.15)
    music('bgm_battle',104,50,[[0,2,3,4],[3,2,1,2],[0,1,3,2],[4,3,2,1]],.8)
    print('AUDIO_COMPOSE_OK 34 effects and 6 original seamless loops')

if __name__=='__main__':main()
