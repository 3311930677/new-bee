import subprocess

scenes = [
    ('fishing', 'Version_3.8_before_fishing.png'),
    ('stele_rooms_entry', 'Version_3.8_before_stele_entry.png'),
    ('stele_shadow_mid', 'Version_3.8_before_stele_shadow.png'),
    ('order_preview', 'Version_3.8_before_order_preview.png'),
    ('mentor_choice', 'Version_3.8_before_mentor_choice.png'),
    ('side_city_accept', 'Version_3.8_before_side_accept.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
