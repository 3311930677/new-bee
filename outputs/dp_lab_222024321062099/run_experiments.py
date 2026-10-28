from pathlib import Path
import subprocess, json, hashlib, platform, time
ROOT = Path(__file__).resolve().parent
E = ROOT / 'evidence'
cases = [
 ('matrix','矩阵连乘','6\n30 35 15 5 10 20 25\n'),
 ('lcs','最长公共子序列','ABCBDAB\nBDCABA\n'),
 ('knapsack','0-1 背包','5 10\n2 6\n2 3\n6 5\n5 4\n4 6\n'),
 ('equipment','设备更新','6 5 100\n10 20 40 70 110\n60 45 30 20 10\n'),
 ('verify','随机对照与边界验证','')]
records=[]
for mode,title,inp in cases:
    (E/f'{mode}_input.txt').write_text(inp,encoding='utf-8')
    r=subprocess.run([str(ROOT/'dp_lab.exe'), mode],input=inp,text=True,capture_output=True,check=True)
    (E/f'{mode}_output.txt').write_text(r.stdout,encoding='utf-8')
    records.append(dict(mode=mode,title=title,input=inp,output=r.stdout,returncode=r.returncode))
# Dedicated regression cases: expected values are independently calculated.
extra=[('matrix','1\n3 4\n','Minimum scalar multiplications: 0'),
 ('matrix','2\n50000 50000 50000\n','Minimum scalar multiplications: 125000000000000'),
 ('lcs','\nABC\n','LCS length: 0'),('lcs','AAAA\nAA\n','LCS length: 2'),
 ('knapsack','1 4\n2 3\n','Maximum value: 3'),
 ('knapsack','2 0\n2 3\n3 5\n','Maximum value: 0'),
 ('equipment','0 1 100\n10\n60\n','Minimum total cost: 0'),
 ('equipment','3 1 100\n10\n60\n','Minimum total cost: 150')]
boundary=[]
for mode,inp,want in extra:
    r=subprocess.run([str(ROOT/'dp_lab.exe'),mode],input=inp,text=True,capture_output=True)
    assert r.returncode==0 and want in r.stdout,(mode,inp,r.stdout)
    boundary.append(f'PASS | {mode:10} | {want}')
for mode,inp in [('matrix','1\n0 4\n'),('knapsack','1 5\n0 9\n'),
                 ('equipment','1 1 100\n-1\n60\n')]:
    r=subprocess.run([str(ROOT/'dp_lab.exe'),mode],input=inp,text=True,capture_output=True)
    assert r.returncode==1 and 'ERROR:' in r.stderr
    boundary.append(f'PASS | {mode:10} | rejected: {r.stderr.strip()}')
records.append(dict(mode='boundary',title='独立边界与非法输入测试',input='8 valid boundary cases + 3 invalid-input cases',output='\n'.join(boundary)+'\nTOTAL: 11/11 PASS\n',returncode=0))
(E/'records.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
env={'os':platform.platform(),'compiler':'g++ (GCC) 13.2.0','standard':'C++17',
     'compile_flags':'-std=c++17 -O2 -Wall -Wextra -pedantic',
     'source_sha256':hashlib.sha256((ROOT/'src/dp_lab.cpp').read_bytes()).hexdigest(),
     'random_seed':20261027,'automated_checks':808,'additional_cli_checks':11}
(E/'environment.json').write_text(json.dumps(env,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(records,ensure_ascii=False,indent=2))
