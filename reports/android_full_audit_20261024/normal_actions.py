from pathlib import Path
import sys,time,json
from run_deep_audit import adb,text,ROOT,PACKAGE,COMPONENT
D=ROOT/"normal_flow"
def cap(name):
    (D/(name+".png")).write_bytes(adb("exec-out","screencap","-p"))
def tap(x,y):
    adb("shell","input","tap",str(x),str(y));time.sleep(.8)
def main():
    mode=sys.argv[1]
    if mode=="capture":cap(sys.argv[2])
    elif mode=="tap":
        tap(*map(int,sys.argv[2:4]));cap(sys.argv[4])
    elif mode=="key":
        adb("shell","input","keyevent",sys.argv[2]);time.sleep(1);cap(sys.argv[3])
    elif mode=="shell":
        print(text("shell",*sys.argv[2:]))
    elif mode=="restart":
        adb("shell","am","force-stop",PACKAGE);adb("shell","am","start","-n",COMPONENT)
    elif mode=="save":
        (D/(sys.argv[2]+".json")).write_bytes(adb("exec-out","run-as",PACKAGE,"cat","files/save.json"))
    elif mode=="log":
        (D/"normal_logcat.txt").write_bytes(adb("logcat","-d"))
    else:raise ValueError(mode)
if __name__=="__main__":main()

