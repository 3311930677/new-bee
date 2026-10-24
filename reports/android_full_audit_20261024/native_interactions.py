"""Real Android input against measured game controls; records rather than hides failures."""
from pathlib import Path
import json
import re
import time
from run_deep_audit import adb, command, pull, ROOT

findings=[]

def perform(identifier, suite="probe", **options):
    result=command(identifier,suite,**options)
    pull(identifier)
    return result

def record(label, ok, detail=None):
    findings.append({"label":label,"ok":bool(ok),"detail":detail})
    print("NATIVE",label,bool(ok),flush=True)
    (ROOT/'native_interactions.json').write_text(json.dumps(findings,ensure_ascii=False,indent=2),encoding='utf-8')

def control(result,suffix):
    candidates=[c for c in result['final']['controls'] if c['path'].endswith('/'+suffix) and not c['disabled'] and not c['clipped']]
    if not candidates:raise LookupError(suffix)
    return candidates[-1]

def click(result,button,hold=0):
    x,y,w,h=button['rect']
    win=list(map(float,re.findall(r'[\d.]+',result['device']['window'])))
    viewport=list(map(float,re.findall(r'[\d.]+',result['device']['viewport'])))
    px=str(round((x+w/2)*win[0]/viewport[-2]));py=str(round((y+h/2)*win[1]/viewport[-1]))
    if hold:adb('shell','input','swipe',px,py,px,py,str(hold))
    else:adb('shell','input','tap',px,py)
    time.sleep(.45)

def main():
    home=perform('native_home2','page',page='home',live=True)
    for currency in ['gold','expedition','soul','honor']:
        click(home,control(home,'Currency_'+currency))
        shown=perform('native_currency_'+currency)
        record('M07 native currency entrance '+currency,
               any(m['currency']==currency for m in shown['final']['modals']),shown['final']['modals'])
        click(shown,control(shown,'CloseCurrency'))
    perform('native_clear_events','audio_events',events=[])
    click(home,control(home,'Rail_bag'),hold=280)
    bag=perform('native_bag_open')
    events=bag['final']['audio']['events']
    record('A04 native bag hold/open feedback',len([e for e in events if e['name']=='ui_open'])==1,events)
    for tab in ['mat','gem','equip','pending']:
        click(bag,control(bag,'Tab_'+tab))
        bag=perform('native_bag_'+tab)
    click(bag,control(bag,'ReturnButton'))
    returned=perform('native_bag_return')
    record('native bag closes and returns home',any(c['path'].endswith('/Rail_bag') for c in returned['final']['controls']),returned['final']['audio']['events'])
    click(returned,control(returned,'Navigation_设置'))
    settings=perform('native_settings')
    mute=[c for c in settings['final']['controls'] if c['text']=='静音' and not c['clipped']]
    if not mute:raise LookupError('Mute switch')
    click(settings,mute[-1])
    muted=perform('native_mute_on')
    record('A02 native mute switch on',muted['final']['audio']['mute'])
    click(muted,[c for c in muted['final']['controls'] if c['text']=='静音' and not c['clipped']][-1])
    unmuted=perform('native_mute_off')
    record('A02 native mute switch off',not unmuted['final']['audio']['mute'])
    record('A04 native total UI events',True,unmuted['final']['audio']['events'])

if __name__=='__main__':main()
