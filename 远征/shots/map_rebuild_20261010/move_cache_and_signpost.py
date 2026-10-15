import re
import sys
from pathlib import Path

# 1) 枫林古道"旧路石匣"移出石桥东端（原 540,590 压在桥头），放到河北岸的岔路旁。
json_path = Path(sys.argv[1])
t = json_path.read_text(encoding='utf-8')
idx = t.index('"act1_waystone_cache"')
seg_start = t.index('"at"', idx)
seg_end = t.index(']', seg_start) + 1
seg = t[seg_start:seg_end]
new_seg, n = re.subn(r'540(,\s*)590', '590\\g<1>520', seg)
assert n == 1, seg
t = t[:seg_start] + new_seg + t[seg_end:]
json_path.write_text(t, encoding='utf-8', newline='\n')

# 2) 签牌回切测试：v4 边城北牌紧贴传送点，读档点会被既有规则推离触发区；断言改为不变量。
test_path = Path(sys.argv[2])
s = test_path.read_text(encoding='utf-8')
old = 'check(map._arrival_exit_blocks.has(id),mid + " resume inside sign guarded against return loop")'
assert s.count(old) == 1, 'signpost assertion not found'
new = ('var rect := map._world_exit_touch_rect(north)\n'
       '\t\t# 不变量：读档停在牌内时，要么已登记防回切，要么玩家已被推出触发区（传送点附近推开规则）。\n'
       '\t\tcheck(map._arrival_exit_blocks.has(id) or not rect.has_point(map._player.position),'
       'mid + " resume inside sign guarded against return loop")')
s = s.replace(old, new)
test_path.write_text(s, encoding='utf-8', newline='\n')
print('MOVE_AND_SIGNPOST_OK')
