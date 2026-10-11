import subprocess

scenes = [
    ('title', 'Version_3.10_before_title.png'),
    ('home', 'Version_3.10_before_home.png'),
    ('forge_enhance', 'Version_3.10_before_forge.png'),
    ('rare_ceremony', 'Version_3.10_before_rare_ceremony.png'),
    ('city', 'Version_3.10_before_city.png'),
    ('battle', 'Version_3.10_before_battle.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
