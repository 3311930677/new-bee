import subprocess

scenes = [
    ('gacha', 'Version_3.6_before_gacha.png'),
    ('exchange', 'Version_3.6_before_exchange.png'),
    ('trade_warden_dialog', 'Version_3.6_before_trade_contracts.png'),
    ('rare_ceremony', 'Version_3.6_before_rare_ceremony.png'),
    ('act1_blue_weapon', 'Version_3.6_before_act1_blue_weapon.png'),
    ('pet_claim', 'Version_3.6_before_pet_claim.png'),
]
for sc, out_fn in scenes:
    subprocess.run(['python', 'tools/batch_capture.py', sc, out_fn], cwd=r'D:\new bee\远征')
