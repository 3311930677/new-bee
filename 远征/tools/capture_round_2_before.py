import subprocess

scenes = [
    ('home', 'Version_3.2_before_home.png'),
    ('equip', 'Version_3.2_before_equip.png'),
    ('bag', 'Version_3.2_before_bag.png'),
    ('shop', 'Version_3.2_before_shop.png'),
    ('quests', 'Version_3.2_before_quests.png'),
    ('avatar', 'Version_3.2_before_avatar.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
