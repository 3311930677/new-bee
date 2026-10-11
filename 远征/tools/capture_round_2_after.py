import subprocess

scenes = [
    ('home', 'Version_3.2_after_home.png'),
    ('equip', 'Version_3.2_after_equip.png'),
    ('bag', 'Version_3.2_after_bag.png'),
    ('shop', 'Version_3.2_after_shop.png'),
    ('quests', 'Version_3.2_after_quests.png'),
    ('avatar', 'Version_3.2_after_avatar.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
