import subprocess

scenes = [
    ('battle', 'Version_3.3_before_battle.png'),
    ('battle_cast', 'Version_3.3_before_battle_cast.png'),
    ('beast_break', 'Version_3.3_before_beast_break.png'),
    ('beast_windup', 'Version_3.3_before_beast_windup.png'),
    ('arena', 'Version_3.3_before_arena.png'),
    ('skillbook', 'Version_3.3_before_skillbook.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
