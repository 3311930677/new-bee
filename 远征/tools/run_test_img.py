import subprocess
godot = r'C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe'
with open(r'd:\new bee\远征\tools\test_img_load.gd', 'w', encoding='utf-8') as f:
    f.write('''extends SceneTree
func _init():
\tvar p := ProjectSettings.globalize_path("res://image/main_world/broken_slope_ground_v4.png")
\tvar img := Image.load_from_file(p)
\tprint("Loaded image: ", img != null, " size: ", img.get_size() if img else "null")
\tvar tex := ImageTexture.create_from_image(img)
\tprint("Created ImageTexture: ", tex != null)
\tquit()
''')
res = subprocess.run([godot, '--path', r'd:\new bee\远征', '--headless', '-s', 'tools/test_img_load.gd'], capture_output=True, text=True)
print('OUTPUT:\n', res.stdout)
