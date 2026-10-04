"""Reject empty renders and setup/runtime failures; only known engine diagnostics are exempt."""
import re
from pathlib import Path
from PIL import Image

def failures(log):
    problems=[]
    for line in log.splitlines():
        if re.search(r'SCRIPT ERROR|Parse Error|Compile Error|FATAL ERROR|SHOT_\w*(?:INVALID|FAILED)|存档写入失败',line):
            problems.append(line)
        elif 'ERROR:' in line:
            known=(line.strip()=='ERROR: Failed to read the root certificate store.'
                   or bool(re.fullmatch(r"ERROR: \d+ RID allocations of type '.+' were leaked at exit\.",line.strip()))
                   or bool(re.fullmatch(r'ERROR: Texture with GL ID of \d+: leaked \d+ bytes\.',line.strip()))
                   or 'resources still in use at exit' in line
                   or (line.strip()=='ERROR: Parameter "RenderingServer::get_singleton()" is null.'
                       and '~CompressedTexture2D' in log))
            if not known: problems.append(line)
    return problems

def capture_ok(code,log,image):
    if code or 'SHOT_SAVED' not in log or failures(log) or not Path(image).is_file(): return False
    with Image.open(image) as frame:
        # A screenshot of a failed setup used to consist solely of the gray clear color.
        return any(low!=high for low,high in frame.convert('RGB').getextrema())
