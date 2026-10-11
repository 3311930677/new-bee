import subprocess

scenes = [
    ('worlds', 'Version_3.7_after_worlds.png'),
    ('codex', 'Version_3.7_after_codex.png'),
    ('road_mail_board', 'Version_3.7_after_road_mail.png'),
    ('city', 'Version_3.7_after_city.png'),
    ('city_repair', 'Version_3.7_after_city_repair.png'),
    ('city_built', 'Version_3.7_after_city_built.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
