"""Original, deterministic low-volume regional sound beds; no downloaded recordings."""
from pathlib import Path
import wave
import numpy as np
SR=22050
SECONDS=8
N=SR*SECONDS
OUT=Path(__file__).resolve().parents[1]/'assets/audio'
t=np.arange(N)/SR
freq=np.fft.rfftfreq(N,1/SR)
for index,name in enumerate(['forest','snow','volcano','tomb','desert','glacier','abyss','castle','port','mine']):
 rng=np.random.default_rng(20261004+index)
 noise=rng.normal(0,1,N)
 cutoff=650 if name in ['port','abyss','forest'] else 220
 spectrum=np.fft.rfft(noise)/(1+(freq/cutoff)**2)
 spectrum[freq<35]=0
 bed=np.fft.irfft(spectrum,n=N)
 bed/=max(abs(bed).max(),1e-8)
 modulation=.6+.22*np.sin(2*np.pi*t/SECONDS)+.12*np.cos(4*np.pi*t/SECONDS)
 signal=bed*modulation*.38
 if name in ['forest','port']:
  for start in ([1.2,4.8,6.3] if name=='forest' else [2.3,5.7]):
   dt=t-start
   envelope=np.where((dt>=0)&(dt<.28),np.sin(np.pi*np.clip(dt/.28,0,1))**2,0)
   signal+=.09*envelope*np.sin(2*np.pi*(1450*dt+1100*dt*dt))
 if name in ['mine','volcano']:
  signal+=.055*np.sin(2*np.pi*(55 if name=='mine' else 40)*t)*(.5+.3*np.cos(2*np.pi*t/SECONDS))
 if name in ['tomb','castle','glacier']:
  for start in [1.5,5.5]:
   dt=t-start
   envelope=np.where((dt>=0)&(dt<1.5),np.exp(-np.maximum(dt,0)*4)*np.minimum(np.maximum(dt,0)*35,1),0)
   signal+=.1*envelope*np.sin(2*np.pi*(360 if name=='glacier' else 240)*dt)
 peak=float(np.max(abs(signal)))
 signal*=.55/max(.55,peak)
 with wave.open(str(OUT/('ambient_'+name+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes((signal*32767).astype('<i2').tobytes())
 print(name,'seconds',SECONDS,'peak',round(float(np.max(abs(signal))),3))
