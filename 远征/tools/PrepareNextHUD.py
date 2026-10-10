from pathlib import Path
p=Path(__file__).resolve().parent
s=(p/'VerifyReviewHUD.gd').read_text(encoding='utf8').replace('const OUT:="res://shots/full_review_fixes_20261009/"','const OUT:="res://shots/next_review_20261009/"')
(p/'VerifyNextHUD.gd').write_text(s,encoding='utf8')
(p/'VerifyNextHUD.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tools/VerifyNextHUD.gd" id="1"]\n[node name="VerifyNextHUD" type="Node"]\nscript=ExtResource("1")\n',encoding='utf8')
