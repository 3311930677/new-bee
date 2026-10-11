import subprocess

scenes = [
    ('settings', 'Version_3.9_before_settings.png'),
    ('settings2', 'Version_3.9_before_settings2.png'),
    ('chapter_archive', 'Version_3.9_before_chapter_archive.png'),
    ('story_intro', 'Version_3.9_before_story_intro.png'),
    ('story_outro', 'Version_3.9_before_story_outro.png'),
    ('gm_open', 'Version_3.9_before_gm_open.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
