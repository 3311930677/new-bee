import subprocess

scenes = [
    ('world_hud_field', 'Version_3.4_after_world_hud_field.png'),
    ('stele_rooms_entry', 'Version_3.4_after_broken_slope.png'),
    ('waystone_world', 'Version_3.4_after_waystone_world.png'),
    ('world_minimap_expanded', 'Version_3.4_after_world_minimap_expanded.png'),
    ('route', 'Version_3.4_after_route.png'),
    ('map', 'Version_3.4_after_map.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
