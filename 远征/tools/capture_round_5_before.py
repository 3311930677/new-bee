import subprocess

scenes = [
    ('growth', 'Version_3.5_before_growth.png'),
    ('talent', 'Version_3.5_before_talent.png'),
    ('forge_enhance', 'Version_3.5_before_forge_enhance.png'),
    ('forge_gem', 'Version_3.5_before_forge_gem.png'),
    ('pet_raise', 'Version_3.5_before_pet_raise.png'),
    ('mount', 'Version_3.5_before_mount.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
