import subprocess

scenes = [
    ('title', 'Version_3.10_after_title.png'),
    ('home', 'Version_3.10_after_home.png'),
    ('forge_enhance', 'Version_3.10_after_forge.png'),
    ('rare_ceremony', 'Version_3.10_after_rare_ceremony.png'),
    ('city', 'Version_3.10_after_city.png'),
    ('battle', 'Version_3.10_after_battle.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
