"""Check the actual ambient WAVs for clipping and discontinuous loop seams."""
import json
import wave
from pathlib import Path
import numpy as np
root = Path(__file__).resolve().parents[1]
rows = []
for path in sorted((root / 'assets/audio').glob('ambient_*.wav')):
    with wave.open(str(path), 'rb') as stream:
        assert stream.getnchannels() == 1 and stream.getsampwidth() == 2
        rate = stream.getframerate()
        signal = np.frombuffer(stream.readframes(stream.getnframes()), dtype='<i2').astype(float) / 32768
    peak = float(np.max(np.abs(signal)))
    rms = float(np.sqrt(np.mean(signal*signal)))
    seam = float(abs(signal[0]-signal[-1]))
    assert rate == 22050 and len(signal)/rate == 8
    assert .003 < rms < .25 and peak < .98 and seam < .03, path.name
    rows.append({'file':path.name,'seconds':8,'peak':peak,'rms':rms,'loop_seam':seam})
assert len(rows) == 10
(root / 'tools/_logs/ambient_wave_audit.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
print('AMBIENT_WAVES_OK ten unclipped loops; listening review remains separate')
