package my.data;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;

import java.util.ArrayList;
import java.util.List;

import static my.data.npcKeyToMonKey.npcKeyMatchMonsterKey;
import static my.fightUtils.fightUtils.isInOneMonsterMap;

public class monsterData {

    /**
     * (遇怪)npcKey对应的怪物
     */
    public static List<String> getMonsterKeysByNpcKey(String npcKey, int num, String name) {
        String key = npcKeyMatchMonsterKey(npcKey);
        //1-(1,2) 2(2,4) 3(3,5) 4(4-6)
        List<String> arr = new ArrayList<>();

        if (isInOneMonsterMap(name)) {
            //判断是否在在深渊\帮派（深渊只允许一只）
            arr.add(key);
            return arr;
        }

        if (key.contains("mshuwei_")) {//魔神护卫
            arr.add(key);
            arr.add("mshuwei_8");
            arr.add("mshuwei_8");
            return arr;
        } else if (key.contains("xhxy_")) {//仗剑除魔
            arr.add(key);
            for (int i = 0; i < 9; i++) {
                arr.add("xhxy_2");
            }
            return arr;
        }

        //根据玩家数量计算怪物数量
        if (strUtils.isHappend(0, 100, 0.5f)) {
            num += 1;
        }
        num = num > 10 ? 10 : num;
        //num = 10;
        for (int i = 0; i < num; i++) {
            arr.add(key);
        }
        return arr;
    }

    /**
     * 由key获取怪物
     * fixme 注意：捕捉时会用到怪物的key，因此petKey跟monsKey要一致
     * 按等级调整难度在fightUtils.addDifficulty控制
     */
    public static JSONObject getMonsterByKey(String key, String projRootDir) {
        monster mon = null;
        //普通怪
        mon = getSimpleMonster(key, projRootDir);
        if (mon != null) return staticCollection.copyObj(mon);
        //boss怪
        mon = bossMonster(key);
        if (mon != null) return staticCollection.copyObj(mon);
        //活动怪物
        mon = acMonster(key);
        if (mon != null) return staticCollection.copyObj(mon);
        //副本怪
        mon = fbMonster(key);
        if (mon != null) return staticCollection.copyObj(mon);
        //一些怪物是在战斗创建时自定义构建的，这里会找不到
        if (key.contains("yhmkms_")) return null;

        System.out.println("未找到怪物" + key);
        return null;
    }

    private static monster fbMonster(String key) {
        monster mon = null;
        if (key.contains("fb_50_")) {//副本
            String[] arr = {
                    "噬人妖", "噬魂魔将", "魔帅", "游离鬼魂", "暴怒尸鬼", "太古真魔", "太古真魔分身"
            };
            String[] ms = {
                    "fb_50_1", "fb_50_2", "fb_50_3", "fb_50_4", "fb_50_5", "fb_50_6", "fb_50_7",
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            if (index == 1 || index == 4 || index == 5) {
                mon.addProp(2000, 1000, 500, 200, 200, 300, 5000, 1, 600);
            } else if (index == 2) {
                mon.addProp(3000, 1000, 800, 200, 200, 301, 5000, 1, 600);
            } else if (index == 3) {
                mon.addProp(4000, 1000, 1000, 300, 300, 301, 5000, 1, 600);
                mon.addSkl("100210000002", 20);//猛虎纵
            } else if (index == 6) {
                mon.addProp(6000, 1000, 1200, 400, 400, 301, 5000, 1, 600);
                mon.addSkl("100210000029", 20);//淬毒
            } else if (index == 7) {
                mon.addProp(4000, 1000, 1000, 300, 300, 300, 5000, 1, 600);
            }
            return mon;
        } else if (key.contains("fb_60_")) {//副本
            String[] arr = {
                    "亡灵刀兵", "亡灵戟兵", "亡灵裨将", "亡灵弓手", "亡灵斧兵", "亡灵统帅", "亡灵副将",
            };
            String[] ms = {
                    "fb_60_1", "fb_60_2", "fb_60_3", "fb_60_4", "fb_60_5", "fb_60_6", "fb_60_7",
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            if (index == 1 || index == 2 || index == 4 || index == 5) {
                mon.addProp(5000, 1000, 1000, 200, 200, 300, 5000, 1, 600);
            } else if (index == 3) {
                mon.addProp(10000, 1000, 2000, 300, 300, 301, 5000, 1, 600);
                mon.addSkl("100210000002", 20);//猛虎纵
            } else if (index == 6) {
                mon.addProp(15000, 1000, 2500, 1000, 1000, 301, 5000, 1, 600);
                mon.addSkl("100210000013", 20);//挫骨
            } else if (index == 7) {
                mon.addProp(12000, 1000, 2200, 800, 800, 300, 5000, 1, 600);
                mon.setAttackType(1);
                mon.addSkl("100210000025", 20);//天籁
            }
            return mon;
        } else if (key.contains("fb_70_")) {//副本
            String[] arr = {
                    "巨山熊", "守谷老人", "隐月宗二弟子", "猛山虎", "隐月宗大弟子", "倩倩", "月尘化身",
            };
            String[] ms = {
                    "fb_70_1", "fb_70_2", "fb_70_3", "fb_70_4", "fb_70_5", "fb_70_6", "fb_70_7",
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            if (index == 1 || index == 4) {
                mon.addProp(10000, 1000, 1000, 500, 500, 300, 5000, 1, 600);
            } else if (index == 2) {
                mon.addProp(20000, 1000, 3000, 1000, 1000, 301, 5000, 1, 600);
                mon.addSkl("100210000013", 20);//挫骨
            } else if (index == 3) {
                mon.addProp(25000, 1000, 4000, 1500, 1500, 301, 5000, 1, 600);
                mon.addSkl("100210000018", 20);//魔魂
            } else if (index == 5) {
                mon.addProp(30000, 1000, 4000, 1500, 1500, 300, 5000, 1, 600);
                mon.addSkl("100210000013", 20);//挫骨
            } else if (index == 6) {
                mon.addProp(30000, 1000, 4000, 1500, 1500, 300, 5000, 1, 600);
                mon.setAttackType(1);
                mon.addSkl("100210000021", 20);//荡魔
                mon.addSkl("100210000026", 20);//返魂
                mon.addSkl("100210000025", 20);//天籁
            } else if (index == 7) {
                mon.addProp(50000, 1000, 5000, 2000, 2000, 300, 5000, 1, 600);
                mon.addSkl("100210010270", 1);//连环背刺
                mon.addSkl("100210010294", 1);//真魔吸血
                mon.addSkl("100210010267", 1);//灭世战魂
            }
            return mon;
        } else if (key.contains("fb_80_")) {//副本
            String[] arr = {
                    "前世之灵", "今生之魂", "来世之魄", "三生兽", "轮回", "前世", "今生", "来世"
            };
            String[] ms = {
                    "fb_80_1", "fb_80_2", "fb_80_3", "fb_80_4", "fb_80_5", "fb_80_6", "fb_80_7", "fb_80_8",
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            if (index == 1 || index == 2 || index == 3) {
                mon.addProp(15000, 1000, 1500, 800, 800, 300, 5000, 1, 600);
            } else if (index == 5) {
                mon.addProp(30000, 1000, 3000, 2000, 2000, 301, 5000, 1, 600);
                mon.setAttackType(1);
            } else if (index == 4) {
                mon.addProp(50000, 1000, 5000, 2500, 2500, 301, 5000, 1, 600);
                mon.setAttackType(1);
                mon.addSkl("100210000035", 20);//淬毒
            } else if (index == 6) {
                mon.addProp(80000, 1000, 6000, 3000, 3000, 300, 5000, 1, 600);
                mon.addSkl("100210000011", 20);//破甲
            } else if (index == 8) {
                mon.addProp(70000, 1000, 5000, 2500, 2500, 300, 5000, 1, 600);
                mon.setAttackType(1);
                mon.addSkl("100210000035", 20);//淬毒
            } else if (index == 7) {
                mon.addProp(80000, 1000, 5000, 2500, 2500, 300, 5000, 1, 600);
                mon.addSkl("100210000012", 20);//战魂歌
                mon.addSkl("100210000032", 1);//断脉
            }
            return mon;
        } else if (key.contains("fb_90_")) {//副本
            String[] arr = {
                    "青丘之灵", "打手", "瑞南羽", "九尾幻影", "六尾", "九尾异兽",
            };
            String[] ms = {
                    "fb_90_1", "fb_90_2", "fb_90_3", "fb_90_4", "fb_90_5", "fb_90_6"
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            if (index == 1 || index == 2 || index == 4 || index == 5) {
                mon.addProp(20000, 1000, 2000, 200, 200, 300, 5000, 1, 600);
            } else if (index == 3) {
                mon.addProp(80000, 1000, 5000, 3000, 3000, 301, 5000, 1, 600);
                mon.addSkl("100210000013", 20);//挫骨
                mon.addSkl("100210000011", 20);//破甲
            } else if (index == 6) {
                mon.addProp(100000, 1000, 6000, 3500, 3500, 301, 5000, 1, 600);
                mon.setAttackType(1);
                mon.addSkl("100210010293", 1);//浴火重生
                mon.addSkl("100210010179", 1);//轰天狂雷
            }
            return mon;
        } else if (key.contains("fb_100_")) {//副本
            String[] arr = {
                    "恶灵", "洞渊战魂", "洞渊战魔", "魔影", "百鬼之王",
            };
            String[] ms = {
                    "fb_100_1", "fb_100_2", "fb_100_3", "fb_100_4", "fb_100_5",
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            mon.addKangXing(0, 0, 3000, 3000);
            if (index == 1 || index == 4) {
                mon.addProp(30000, 1000, 3000, 200, 200, 300, 5000, 1, 600);
                mon.setAttackType(1);
            } else if (index == 2) {
                mon.addProp(130000, 1000, 6000, 3000, 3000, 301, 5000, 1, 600);
                mon.addSkl("100210000026", 20);//返魂
                mon.addSkl("100210010267", 1);//灭世战魂
            } else if (index == 3) {
                mon.addProp(100000, 1000, 6000, 3000, 3000, 301, 5000, 1, 600);
                mon.setAttackType(1);
                mon.addSkl("100210000026", 20);//返魂
                mon.addSkl("100210000035", 20);//淬毒
            } else if (index == 5) {
                mon.addProp(200000, 1000, 7000, 3000, 3000, 301, 5000, 1, 600);
                mon.addSkl("100210010294", 1);//真魔吸血
                mon.addSkl("100210000035", 20);//淬毒
            }
            return mon;
        } else if (key.contains("fb_ls_")) {//精英副本1
            String[] arr = {
                    "煞阴尸鬼", "虐杀之鬼", "幽蓝狼魔", "暗影杀手", "怨杀魔狼",
            };
            String[] ms = {
                    "fb_ls_1", "fb_ls_2", "fb_ls_3", "fb_ls_4", "fb_ls_5",
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            mon.addKangXing(0, 0, 20000, 20000);
            if (index == 1 || index == 3 || index == 5) {
                mon.addProp(100000, 1000, 5000, 2000, 2000, 300, 5000, 500, 600);
                mon.addSkl("100210010178", 4);//狂舞乱击
            } else if (index == 2) {
                mon.addProp(150000, 1000, 7000, 3000, 3000, 301, 5000, 500, 600);
                mon.addSkl("100210010178", 4);//狂舞乱击
            } else if (index == 4) {
                mon.addProp(200000, 1000, 8000, 3000, 3000, 301, 5000, 500, 600);
                mon.setAttackType(1);
                //mon.addSkl("100210010314", 1);//魔神降临
                mon.addSkl("100210010298", 1);//强势反击
                //mon.addSkl("100210010316", 1);//永恒背刺
                mon.addSkl("100210000026", 20);//返魂
            }
            return mon;
        } else if (key.contains("fb_hh_")) {//精英副本2
            String[] arr = {
                    "巨角魔牛", "震岳巨熊", "灭城将军", "心魔", "碎魂阴尸",
            };
            String[] ms = {
                    "fb_hh_1", "fb_hh_2", "fb_hh_3", "fb_hh_4", "fb_hh_5",
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            mon.addKangXing(0, 0, 20000, 20000);
            if (index == 1 || index == 2) {
                mon.addProp(100000, 1000, 5000, 2000, 2000, 300, 5000, 1000, 600);
                mon.addSkl("100210010178", 4);//狂舞乱击
            } else if (index == 3) {
                mon.addProp(150000, 1000, 7000, 3000, 3000, 301, 5000, 1000, 600);
                mon.addSkl("100210010178", 4);//狂舞乱击
                //mon.addSkl("100210010314", 1);//魔神降临
            } else if (index == 5) {
                mon.addProp(200000, 1000, 6000, 3000, 3000, 301, 5000, 1000, 600);
                mon.setAttackType(1);
                mon.addSkl("100210000035", 20);//淬毒
                mon.addSkl("100210000026", 20);//返魂
                //mon.addSkl("100210010314", 1);//魔神降临
            } else if (index == 4) {
                mon.addProp(200000, 1000, 7000, 3000, 3000, 301, 5000, 1000, 600);
                mon.addSkl("100210010178", 4);//狂舞乱击
                mon.addSkl("100210010319", 1);//凶残
            }
            return mon;
        } else if (key.contains("fb_ys_")) {//精英副本3
            String[] arr = {
                    "黑煞木妖", "苍岚狮鹫", "龙女", "君皇", "通天眼", "影行护卫",
            };
            String[] ms = {
                    "fb_ys_1", "fb_ys_2", "fb_ys_3", "fb_ys_4", "fb_ys_5", "fb_ys_6",
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            mon.addKangXing(0, 0, 20000, 20000);
            if (index == 1 || index == 2) {
                mon.addProp(100000, 1000, 5000, 2000, 2000, 300, 5000, 2000, 600);
                mon.setAttackType(1);
                mon.addSkl("100210010178", 4);//狂舞乱击
                mon.addSkl("100210010319", 1);//凶残
            } else if (index == 3) {
                mon.addProp(200000, 1000, 6000, 3000, 3000, 301, 5000, 2000, 600);
                mon.setAttackType(1);
                mon.addSkl("100210000035", 20);//淬毒
                mon.addSkl("100210000026", 20);//返魂
            } else if (index == 4) {
                mon.addProp(200000, 1000, 7000, 2000, 2000, 301, 5000, 2000, 600);
                mon.addSkl("100210010178", 4);//狂舞乱击
            } else if (index == 5) {
                mon.addProp(200000, 1000, 7000, 2000, 2000, 301, 5000, 2000, 600);
                mon.setAttackType(1);
                mon.addSkl("100210000035", 20);//淬毒
                mon.addSkl("100210010320", 1);//免伤
            } else if (index == 6) {
                mon.addProp(300000, 1000, 8000, 3000, 3000, 301, 5000, 2000, 600);
                mon.addSkl("100210010178", 4);//狂舞乱击
            }
            return mon;
        } else if (key.contains("fb_zx_")) {//精英副本4
            String[] arr = {
                    "冥罗妖", "熔骨尸煞", "蜃兽", "魔化天星子", "天鹰护卫", "白虎护卫",
            };
            String[] ms = {
                    "fb_zx_1", "fb_zx_2", "fb_zx_3", "fb_zx_4", "fb_zx_5", "fb_zx_6",
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            mon.addKangXing(0, 0, 20000, 20000);
            if (index == 1 || index == 2) {
                mon.addProp(100000, 1000, 5000, 2000, 2000, 300, 5000, 2000, 600);
                mon.addSkl("100210010178", 4);//狂舞乱击
                mon.addSkl("100210010319", 1);//凶残
            } else if (index == 3) {
                mon.addProp(200000, 1000, 6000, 2000, 2000, 301, 5000, 2000, 600);
                mon.setAttackType(1);
                mon.addSkl("100210010178", 4);//狂舞乱击
                mon.addSkl("100210010319", 1);//凶残
            } else if (index == 4) {
                mon.addProp(300000, 1000, 7000, 3000, 3000, 301, 5000, 2000, 600);
                mon.setAttackType(1);
                mon.addSkl("100210010318", 1);//魔神之力
                mon.addSkl("100210010267", 1);//灭世战魂
            } else if (index == 5) {
                mon.addProp(200000, 1000, 8000, 2000, 2000, 301, 5000, 2000, 600);
                mon.setAttackType(1);
                mon.addSkl("100210010317", 1);//风雷之力
                mon.addSkl("100210010181", 1);//真魔血破
            } else if (index == 6) {
                mon.addProp(250000, 1000, 7000, 3000, 3000, 301, 5000, 2000, 600);
                mon.addSkl("100210010178", 4);//狂舞乱击
                mon.addSkl("100210010280", 1);//真灵返血
            }
            return mon;
        } else if (key.contains("fb_yzj_")) {//隐藏
            String[] arr = {
                    "灵通仙兽", "饕餮", "青玄仙人", "梼杌", "陆吾", "夔牛", "沧海仙龙", "天机老人", "道家门主", "墨家门主", "阴阳家门主",
            };
            String[] ms = {
                    "fb_yzj_1", "fb_yzj_2", "fb_yzj_3", "fb_yzj_4",
                    "fb_yzj_5", "fb_yzj_6", "fb_yzj_7", "fb_yzj_8",
                    "fb_yzj_9", "fb_yzj_10", "fb_yzj_11",
            };
            int index = Integer.parseInt(key.split("_")[2]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            mon.addKangXing(0, 0, 20000, 20000);
            if (index == 1 || index == 3 || index == 7) {
                mon.addProp(400000, 10000, 3000, 2000, 2000, 3000, 8000, 1000, 1000);
                mon.addSkl("100210010178", 4);//狂舞乱击
                //mon.addSkl("100210010319", 1);//凶残
            } else if (index == 2) {
                mon.addProp(800000, 10000, 4000, 2500, 2500, 3000, 10000, 1000, 1000);
                mon.addSkl("100210010178", 4);//狂舞乱击
                //mon.addSkl("100210010319", 1);//凶残
            } else if (index == 4) {
                mon.addProp(1000000, 10000, 10000, 3000, 3000, 3000, 10000, 1000, 1000);
                mon.setAttackType(1);
                mon.addSkl("100210010294", 1);//真吸
                mon.addSkl("100210010267", 1);//灭世战魂
                mon.addSkl("100210010243", 1);//裂骨
            } else if (index == 5) {
                mon.addProp(800000, 10000, 5000, 3000, 3000, 3000, 10000, 1000, 1000);
                mon.addSkl("100210010178", 4);//狂舞乱击
                //mon.addSkl("100210010319", 1);//凶残
            } else if (index == 6) {
                mon.addProp(800000, 10000, 5000, 3000, 3000, 3000, 10000, 1000, 1000);
                mon.addSkl("100210000025", 20);//天籁
                mon.addSkl("100210010243", 1);//裂骨
            } else if (index == 8) {
                mon.addProp(1200000, 10000, 8000, 3000, 3000, 3000, 10000, 1000, 1000);
                mon.setAttackType(1);
                mon.addSkl("100210010243", 1);//裂骨
                mon.addSkl("100210010267", 1);//灭世战魂
                //mon.addSkl("100210010319", 1);//凶残
            } else if (index == 9) {
                mon.addProp(800000, 10000, 8000, 4000, 4000, 3000, 10000, 1000, 1000);
                mon.setAttackType(1);
                mon.addSkl("100210000018", 20);//魔魂
                mon.addSkl("100210000025", 20);//天籁
            } else if (index == 10) {
                mon.addProp(800000, 10000, 8000, 3000, 3000, 3000, 10000, 1000, 1000);
                mon.addSkl("100210000002", 20);//猛虎纵
                mon.addSkl("100210000011", 20);//破甲
                mon.addSkl("100210010294", 1);//真吸
            } else if (index == 11) {
                mon.addProp(800000, 10000, 10000, 3000, 3000, 3000, 10000, 1000, 1000);
                mon.addSkl("100210000035", 20);//淬毒
                mon.addSkl("100210000032", 20);//断脉
            }
            return mon;
        }
        return null;
    }

    private static monster bossMonster(String key) {
        monster mon = null;

        switch (key) {
            case "mozun_boss": {
                mon = new monster("魔尊", 1, 0, "mozun_boss")
                        .addProp(40, 200, 20, 1, 1, 1000, 1000, 0, 100);
                break;
            }
            case "world_boss": {
                mon = new monster("灭世魔龙", 1, 0, "world_boss")
                        .addProp(900000000, 1000, 3000, 1000, 1000, 1000, 1000, 100, 100);
                mon.addSkl("100210010314", 1)
                        .addSkl("100210010292", 1);//魔神降临、仙回
                break;
            }
            case "bp_boss": {
                mon = new monster("帮派boss", 1, 0, "bp_boss")
                        .addProp(100000000, 1000, 3000, 100, 100, 1000, 1000, 1000, 100);
                mon.addSkl("3058", 1);
                break;
            }
            case "bp_robber": {
                mon = new monster("强盗", 1, 0, "bp_robber")
                        .addProp(10000, 1000, 3000, 100, 100, 100, 100, 100, 100);
                break;
            }
            case "houzi": {
                mon = new monster("顽皮的猴子", 1, 0, "houzi")
                        .addProp(10000, 1000, 3000, 100, 100, 100, 100, 100, 100);
                break;
            }
            case "wzyc": {//王者遗产怪物
                mon = new monster("藏边小丑", 1, 0, "houzi")
                        .addProp(10000, 1000, 3000, 100, 100, 100, 100, 100, 100);
                break;
            }

            case "boss_0": {
                mon = new monster("展护卫", 1, 0, "tianbing")
                        .addAutoProp(0);
                break;
            }
            case "boss_1": {
                mon = new monster("心魔", 1, 0, "1001")
                        .addAutoProp(0);
                mon.addSkl("100210000029", 1);
                break;
            }
            case "boss_1_0": {
                mon = new monster("贪婪", 1, 0, "1001")
                        .addAutoProp(0);
                break;
            }
            case "boss_1_1": {
                mon = new monster("嫉妒", 1, 0, "1001")
                        .addAutoProp(0);
                break;
            }
            case "boss_1_2": {
                mon = new monster("懒惰", 1, 0, "1001")
                        .addAutoProp(0);
                break;
            }
            case "boss_1_3": {
                mon = new monster("暴食", 1, 0, "1001")
                        .addAutoProp(0);
                break;
            }
            case "boss_1_4": {
                mon = new monster("色欲", 1, 0, "1001")
                        .addAutoProp(0);
                break;
            }
            case "boss_2": {
                mon = new monster("神秘强者", 1, 0, "1003")
                        .addAutoProp(1);
                break;
            }
            case "boss_3": {
                mon = new monster("邪月", 1, 0, "1004")
                        .addAutoProp(2);
                break;
            }
            case "boss_4": {
                mon = new monster("韩信", 1, 0, "tianbing")
                        .addAutoProp(3);
                break;
            }
            case "boss_5": {
                mon = new monster("暗影魔将", 1, 0, "1008")
                        .addAutoProp(4);
                break;
            }
            case "boss_6": {
                mon = new monster("梦渊尸魔", 1, 0, "1008")
                        .addAutoProp(5);
                break;
            }
            case "boss_7": {
                mon = new monster("天星子", 1, 0, "fb_zx_4")
                        .addAutoProp(6);
                mon.addSkl("100210000029", 1);
                break;
            }
            case "boss_7_0": {
                mon = new monster("喽啰", 1, 0, "1008")
                        .addAutoProp(3);
                break;
            }
            case "boss_8": {
                mon = new monster("尸王", 1, 0, "1008")
                        .addAutoProp(7);
                break;
            }
            case "boss_9": {
                mon = new monster("猴王", 1, 0, "1010")
                        .addAutoProp(8);
                break;
            }
            case "boss_10": {
                mon = new monster("狂暴兽王", 1, 0, "1016")
                        .addAutoProp(9);
                break;
            }
            case "boss_11": {
                mon = new monster("炎狼", 1, 0, "1011")
                        .addAutoProp(10);
                break;
            }
            case "boss_12": {
                mon = new monster("炎狼", 1, 0, "1011")
                        .addAutoProp(11);
                break;
            }
            case "boss_12_0": {
                mon = new monster("喽啰", 1, 0, "1008")
                        .addAutoProp(5);
                break;
            }
            case "boss_13": {
                mon = new monster("手下", 1, 0, "1059")
                        .addAutoProp(8);
                break;
            }
            case "boss_14": {
                mon = new monster("刘大刀", 1, 0, "1059")
                        .addAutoProp(12);
                mon.addSkl("100210000005", 1);
                break;
            }
            case "boss_14_0": {
                mon = new monster("手下", 1, 0, "1059")
                        .addAutoProp(10);
                break;
            }
            case "boss_15": {
                mon = new monster("天星子", 1, 0, "fb_zx_4")
                        .addAutoProp(13);
                mon.addSkl("100210000029", 10);
                break;
            }
            case "boss_15_0": {
                mon = new monster("喽啰", 1, 0, "1017")
                        .addAutoProp(10);
                break;
            }
            case "boss_16": {
                mon = new monster("喽啰", 1, 0, "1017")
                        .addAutoProp(10);
                break;
            }
            case "boss_17": {
                mon = new monster("啸月", 1, 0, "1018")
                        .addAutoProp(14);
                break;
            }
            case "boss_18": {
                mon = new monster("牛头怪", 1, 0, "1021")
                        .addAutoProp(15);
                break;
            }
            case "boss_19": {
                mon = new monster("修罗分身", 1, 0, "mozun_boss")
                        .addAutoProp(16);
                mon.addSkl("100210000018", 5);
                break;
            }
            case "boss_20": {
                mon = new monster("心魔", 1, 0, "1023")
                        .addAutoProp(15);
                break;
            }
            case "boss_21": {
                mon = new monster("村民", 1, 0, "1033")
                        .addAutoProp(13);
                break;
            }
            case "boss_21_0": {
                mon = new monster("村民", 1, 0, "1033")
                        .addAutoProp(13);
                break;
            }
            case "boss_22": {
                mon = new monster("修罗之神", 1, 0, "mozun_boss")
                        .addAutoProp(17);
                mon.addSkl("100210000018", 10);
                break;
            }

            case "boss_23": {
                mon = new monster("狗腿子", 1, 0, "1025")
                        .addAutoProp(15);
                break;
            }
            case "boss_23_0": {
                mon = new monster("狗腿子", 1, 0, "1025")
                        .addAutoProp(15);
                break;
            }
            case "boss_24": {
                mon = new monster("狗王", 1, 0, "1025")
                        .addAutoProp(17);
                break;
            }
            case "boss_25": {
                mon = new monster("湛蓝领主", 1, 0, "1025")
                        .addAutoProp(18);
                mon.addSkl("100210000013", 5);
                break;
            }
            case "boss_26": {
                mon = new monster("喽啰", 1, 0, "1030")
                        .addAutoProp(15);
                break;
            }
            case "boss_26_0": {
                mon = new monster("喽啰", 1, 0, "1030")
                        .addAutoProp(15);
                break;
            }
            case "boss_27": {
                mon = new monster("水晶守卫", 1, 0, "1036")
                        .addAutoProp(15);
                break;
            }
            case "boss_28": {
                mon = new monster("钥匙守卫", 1, 0, "1037")
                        .addAutoProp(15);
                break;
            }

            case "boss_29": {
                mon = new monster("蚩尤", 1, 0, "fb_100_5")
                        .addAutoProp(19);
                mon.addSkl("100210000013", 10);
                break;
            }
            case "boss_29_0": {
                mon = new monster("喽啰", 1, 0, "1039")
                        .addAutoProp(15);
                break;
            }
            case "boss_30": {
                mon = new monster("偷听者", 1, 0, "1039")
                        .addAutoProp(15);
                break;
            }
            case "boss_31": {
                mon = new monster("蚩尤", 1, 0, "fb_100_5")
                        .addAutoProp(20);
                mon.addSkl("100210000013", 20);
                break;
            }
            case "boss_31_0": {
                mon = new monster("喽啰", 1, 0, "1039")
                        .addAutoProp(15);
                break;
            }
            case "boss_32": {
                mon = new monster("妖兽", 1, 0, "1039")
                        .addAutoProp(15);
                break;
            }
            case "boss_33": {
                mon = new monster("龙啸天", 1, 0, "1042")
                        .addAutoProp(21);
                mon.addSkl("100210000013", 10);
                break;
            }
            case "boss_34": {
                mon = new monster("子尔邑", 1, 0, "1034")
                        .addAutoProp(22);
                break;
            }
            case "boss_35": {
                mon = new monster("龙姣王", 1, 0, "1034")
                        .addAutoProp(23);
                break;
            }
            case "boss_36": {
                mon = new monster("子尔邑", 1, 0, "1034")
                        .addAutoProp(24);
                break;
            }
            case "boss_36_0": {
                mon = new monster("分身", 1, 0, "1034")
                        .addAutoProp(24);
                break;
            }
            case "boss_37": {
                mon = new monster("子尔邑", 1, 0, "1034")
                        .addAutoProp(25);
                break;
            }
            case "boss_38": {
                mon = new monster("子尔邑", 1, 0, "1034")
                        .addAutoProp(26);
                break;
            }
            case "boss_39": {
                mon = new monster("子尔邑", 1, 0, "1034")
                        .addAutoProp(27);
                break;
            }
            case "boss_40": {
                mon = new monster("范小弟", 1, 0, "1040")
                        .addAutoProp(28);
                mon.addSkl("100210000011", 10);
                break;
            }


            default: {
                //System.out.println("未找到boss怪物" + key);
                return null;
            }
        }
        return mon;
    }

    public static monster getSimpleMonster(String key, String projRootDir) {
        if (!strUtils.isMatch(key, "1([0-9]{3})")) return null;
        JSONObject pet = petData.get(key, projRootDir);
        if (pet == null) {
            System.err.println("monsterData:未找到怪物" + key);
            return null;
        }

        int fightLv = pet.getInteger("fightLv");
        //测试怪，血量+5000
        monster mon = new monster(pet.getString("nickName"),
                fightLv,
                pet.getInteger("type"),
                pet.getString("model")).addAutoProp(fightLv);
        if (key.contains("1000")) {
            mon.prop.put("max_xue", 150000);
            mon.prop.put("xue", 150000);
            mon.prop.put("wg", 5000);
            mon.prop.put("fg", 5000);
            mon.prop.put("mz", 50000);
            //mon.addSkl("100210010292", 1);
            //mon.addSkl("100210010299", 1);

        }
        /*if (fightLv >= 60) {
            //附带技能
            List<String> ks = new ArrayList<>();
            for (int i = 0; i < 5; i++) {
                String k = "1002" + strUtils.getRandom(10010210, 10010245);
                boolean b = false;
                for (String a : ks) {
                    if (a.equals(k)) {
                        b = true;
                        break;
                    }
                }
                //重复则重新选
                if (b) {
                    i--;
                    continue;
                }
                mon.addSkl(k, 1);
            }
        }*/
        return mon;
    }

    private static monster acMonster(String key) {
        monster mon = null;
        if (key.contains("abyss_")) {
            String[] arr = {
                    "龙血玄蛛", "赤灵妖狼", "霸灵巨兽", "食魂梦", "烈焰燃火虫",
                    "洞穴巨猿", "苍灵妖狼", "飞羽战鹰", "战魄玄兽", "赤焰铁甲兽",
                    "龙渊盘蛇", "吸血妖鼠", "喋血妖蝠", "夺魂魔兽", "长爪越兽",
                    "鹰头兽人", "护龙灵兽", "震空巨熊", "浴火凤凰", "破虚苍龙",

                    "六尾魔狐", "双头魔犬", "噬魂花妖", "残天凶兽", "狂尸蝎怪",
                    "裂魂鬼灵", "凶煞妖蛟", "魔焰煞魂", "上古灾兽", "吞日海魂",
                    "噬魂尸虫", "魅蛛魔女", "赤焰甲兽", "啸天巨犼", "金角大王",
                    "覆海鲛人", "幻境鹿妖", "齐天大圣", "万年树妖", "赤焰金龙"
            };
            String[] ms = new String[40];
            for (int i = 0; i < arr.length; i++) {
                ms[i] = "abyss_" + (i + 1);
            }

            int index = Integer.parseInt(key.split("_")[1]);
            //100级攻击达到4000即可
            mon = new monster(arr[index - 1], 1, 1, ms[index - 1])
                    .setPropByAbyss(100f * (1f + index / 40f) *
                            (0.5f + 0.5f * (index / 40f)));//lv100时fy属性3*100*1.5*100*0.15
            if (index > 20) {
                if (index == 21) mon.addSkl("100210000029", 20);//淬毒
                else if (index == 22) mon.addSkl("100210010294", 1);//真吸
                else if (index == 23) mon.addSkl("100210000029", 20);//淬毒
                else if (index == 24) mon.addSkl("100210010294", 1);//真吸
                else if (index == 25) mon.addSkl("100210010280", 1);//真返
                else if (index == 26) mon.addSkl("100210010281", 1)
                        .addSkl("100210010298", 1);//天命不死、强势反击
                else if (index == 27) mon.addSkl("100210010284", 1)
                        .addSkl("100210010298", 1);//霸气反震、强势反击
                else if (index == 28) mon.addSkl("100210000018", 20)
                        .addSkl("100210010297", 1);//魔魂曲、裂骨鬼刃
                else if (index == 29) mon.addSkl("100210010292", 1)
                        .addSkl("100210010286", 1)
                        .addSkl("100210010267", 1);//仙术回血、血魔缚命、灭世战魂
                else if (index == 30) mon.addSkl("100210030036", 1)
                        .addSkl("100210010297", 1)
                        .addSkl("100210010284", 1)
                        .addSkl("100210010298", 1)
                        .addSkl("100210010294", 1);//回光、裂骨鬼刃、霸气反震、强势反击、真吸
                else if (index == 31) mon.addSkl("100210000029", 20);//淬毒
                else if (index == 32) mon.addSkl("100210010294", 1);//真吸
                else if (index == 33) mon.addSkl("100210000029", 20);//淬毒
                else if (index == 34) mon.addSkl("100210010294", 1);//真吸
                else if (index == 35) mon.addSkl("100210010280", 1);//真返
                else if (index == 36) mon.addSkl("100210010281", 1)
                        .addSkl("100210010298", 1);//天命不死、强势反击
                else if (index == 37) mon.addSkl("100210010284", 1)
                        .addSkl("100210010298", 1);//霸气反震、强势反击
                else if (index == 38) mon.addSkl("100210000018", 20)
                        .addSkl("100210010297", 1);//魔魂曲、裂骨鬼刃
                else if (index == 39) mon.addSkl("100210010292", 1)
                        .addSkl("100210010286", 1)
                        .addSkl("100210010267", 1);//仙术回血、血魔缚命、灭世战魂
                else if (index == 40) mon.addSkl("100210030036", 1)
                        .addSkl("100210010297", 1)
                        .addSkl("100210010284", 1)
                        .addSkl("100210010298", 1)
                        .addSkl("100210010294", 1);//回光、裂骨鬼刃、霸气反震、强势反击、真吸
            }
            return mon;
        } else if (key.contains("petxl_")) {
            String[] arr = {
                    "牛头怪", "夜刃豹", "魅惑蛇妖", "地狱犬", "魔狼", "狂暴巨熊", "赤炼魔蜥", "追魂猎鹰", "剧毒魔蛛", "千年灵猿",
                    "暗影邪神", "幽魂", "摄魂天狐", "碧眼苍狼", "上古魔将", "魔兵", "斩首者", "暗影猎杀者", "轮回恶灵", "怨灵聚体",
                    "真·暗影邪神", "真·幽魂", "真·摄魂天狐", "真·碧眼苍狼", "真·上古魔将", "真·魔兵", "真·斩首者", "真·暗影猎杀者", "真·轮回恶灵", "真·怨灵聚体",
                    "乱世逆仙", "幻化魔影", "白虎分身", "玄武分身", "朱雀分身", "金雕", "青龙分身", "玄蛇", "灭世妖皇", "冥界邪灵",
                    "真·乱世逆仙", "真·幻化魔影", "真·白虎分身", "真·玄武分身", "真·朱雀分身", "真·金雕", "真·青龙分身", "真·玄蛇", "真·灭世妖皇", "真·冥界邪灵"
            };
            String[] ms = new String[50];
            for (int i = 0; i < ms.length; i++) {
                ms[i] = "petxl_" + (i + 1);
            }
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            if (index < 11) {
                mon.addProp(1000 + 1000 * index, 10000, 1000 + 150 * index, 100 + 100 * index, 100 + 100 * index, 5000, 10000, 100 + 10 * index, 100 + 20 * index);
                mon.addSkl("100210010315", 1);//开场秒
            } else if ((index > 10 && index < 21) || (index > 30 && index < 41)) {
                //单数是主怪
                if (index % 2 != 0) {
                    mon.addProp(10000 + 500 * index, 10000, 2000 + 50 * index, 100 + 70 * index, 100 + 70 * index, 5000, 10000, 100 + 10 * index, 100 + 10 * index);
                    mon.addSkl("100210010315", 1);//开场秒
                } else {
                    //混2两个都是主怪
                    if (index == 34) {
                        mon.addProp(10000 + 500 * index, 10000, 2000 + 50 * index, 100 , 100, 5000, 10000, 100 + 10 * index, 100 + 10 * index);
                    } else {
                        mon.addProp((10000 + 500 * index) / 2f, 10000, (2000 + 50 * index) / 2f, 100, 100, 3000, 5000, (100 + 10 * index) / 2f, (100 + 10 * index) / 2f);
                    }
                }
            } else {//精英怪
                if (index % 2 != 0) {
                    mon.addProp(10000 + 1000 * index/2, 10000, 2000 + 100 * index/2, 100 , 100 , 5000, 13000, 100 + 10 * index, 100 + 10 * index);
                    mon.addSkl("100210010315", 1);//开场秒
                } else {
                    if (index == 44) {
                        mon.addProp(10000 + 1000 * index/2, 10000, 2000 + 100 * index/2, 100 , 100 , 5000, 13000, 100 + 10 * index, 100 + 10 * index);
                    } else {
                        mon.addProp((10000 + 1000 * index) / 4f, 10000, (2000 + 100 * index) / 4f, 100, 100, 3000, 8000, (100 + 10 * index) / 2f, (100 + 10 * index) / 2f);
                    }
                }
                mon.addSkl("100210010319", 1);//凶残 10回合后攻击上升
                mon.addSkl("100210010286", 1);//血魔缚命

                if (index == 21) mon.addSkl("100210010320", 1);
                else if (index == 23) mon.addSkl("100210010318", 1);//魔神之力
                else if (index == 25) mon.addSkl("100210010321", 1);//神避
                else if (index == 27) mon.addSkl("100210010314", 1);//魔神降临
                else if (index == 29) mon.addSkl("100210010179", 1);//狂雷

                else if (index == 43) mon.addSkl("100210010317", 1);//风雷之力
                else if (index == 44) mon.addSkl("100210010316", 1);//永恒背刺
                else if (index == 46) mon.addSkl("100210010314", 2);//魔神降临
                else if (index == 47) mon.addSkl("100210010317", 2);//风雷之力
                else if (index == 49) mon.addSkl("100210010318", 2);//魔神之力
            }
            return mon;
        } else if (key.contains("blxt_")) {//百炼玄塔
            String[] arr = {
                    "离火剑", "散瘟鞭", "落宝金钱", "列瘟印", "紫金铃", "撞心杵", "风火轮", "酱油瓶", "乾坤针", "斩仙飞刀",

                    "风袋", "梅花镖", "六根清净竹", "雾露乾坤网", "戳目珠", "照妖鉴", "长生根", "伤不旗", "逆鳞枪", "宝莲灯",

                    "万里起云烟", "钻心钉", "万鸦壶", "紫金钵", "定风珠", "魔神甲", "穿天弩", "咆哮梯", "金光锉", "五行旗",

                    "乱心尘", "阴阳二气瓶", "劈地珠", "杏黄旗", "阴阳刃", "穿心锁", "三尖两刃枪", "浮云", "金霞冠", "伏羲琴",

                    "落魂钟", "焰光旗", "化血神刀", "日月珠", "定海珠", "破军", "开天珠", "混元锤", "火星帖", "翻天印",

                    "四象塔", "天荡", "降魔杵", "乾坤圈", "如意乾坤袋", "捆仙绳", "招妖幡", "杯具", "水火锋", "苍刑逆天枪",

                    "黑砂", "混元幡", "乾坤弓", "落魄镜", "听谛印", "照天印", "遁龙桩", "鸭梨", "缚龙索", "混沌钟",
            };
            String[] ms = new String[70];
            for (int i = 0; i < arr.length; i++) {
                ms[i] = "blxt_" + (i + 1);
            }

            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1], 210 + index * 20, 1, ms[index - 1])
                    .addProp(1000 + 3000f * (1f + index / 10f), 10000,
                            100 + 1500 * (1f + index / 10f), 750 * (1f + index / 10f), 750 * (1f + index / 10f),
                            100 + 100 * index, 1000 + 300 * index,
                            100 + 20 * index, 100 + 50 * index);

            return mon;
        } else if (key.contains("mjxw_")) {//摸金校尉
            String[] arr = {
                    "尸妖王", "剑魂", "凶灵"
            };
            String[] ms = {
                    "mjxw_1", "mjxw_2", "mjxw_3"
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1])
                    .addProp(1000 + 1000 * index, 10000, 100 + 300 * index, 100 + 150 * index, 100 + 150 * index, 100 + 150 * index, 1000 + 500 * index, 100 + 250 * index, 100 + 150 * index);
            return mon;
        } else if (key.contains("mprw_")) {//门派任务
            String[] arr = {
                    "风笑天", "唐镇", "李立","震天战魂","阿布"
            };
            String[] ms = {
                    "mprw_1", "mprw_2", "mprw_3", "mprw_4", "mprw_5"
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1])
                    .addProp(1000 + 1000 * index, 10000, 100 + 300 * index, 100 + 150 * index, 100 + 150 * index, 100 + 150 * index, 1000 + 500 * index, 100 + 250 * index, 100 + 150 * index);
            return mon;
        } else if (key.contains("shitu_")) {//师徒扫塔
            String[] arr = {
                    "叽叽", "嘎嘎", "咔咔", "叭叭", "哈哈", "哦哦", "嚯嚯", "呵呵"
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1] + "", 1, 0, "shitu_" + index)
                    .addProp(1000 + 1000 * index, 10000, 100 + 300 * index, 100 + 150 * index, 100 + 150 * index, 100 + 150 * index, 1000 + 500 * index, 100 + 250 * index, 100 + 150 * index);
            return mon;
        } else if (key.contains("smbz_")) {//神秘宝藏
            String[] arr = {
                    "花生舞", "伴生灵", "邪童子"
            };
            String[] ms = {
                    "smbz_1", "smbz_2", "smbz_3"
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1])
                    .addProp(1000 + 600 * index, 10000, 100 + 200 * index, 100 + 150 * index, 100 + 150 * index, 100 + 150 * index, 1000 + 500 * index, 100 + 250 * index, 100 + 150 * index);
            return mon;
        } else if (key.contains("qlhd_")) {//潜力黑洞
            String[] arr = {
                    "赤岩魔狼", "寒冰魔狼", "震天利爪兽", "灵魂舔舐者"
            };
            String[] ms = {
                    "qlhd_1", "qlhd_2", "qlhd_3", "qlhd_4", "qlhd_5"
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1])
                    .addProp(1000 + 5000 * index, 10000, 100 + 200 * index, 100 + 150 * index, 100 + 150 * index, 100 + 150 * index, 1000 + 500 * index, 100 + 250 * index, 100 + 150 * index);
            return mon;
        } else if (key.contains("mshuwei_")) {
            String[] arr = {
                    "狂攻之护卫", "铁壁之护卫", "生命之护卫", "神速之护卫", "射手之护卫", "法术之护卫", "暴怒之护卫", "喽啰",
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1] + "", 1, 0, "mshuwei_" + index)
                    .simpleToProp(1000f);
            return mon;
        } else if (key.contains("ztzs_")) {
            String[] ks = key.split("_");
            int index = Integer.parseInt(ks[1]);
            String[] arr = {
                    "玄甲神卫", "落音仙灵", "幽冥剑灵", "破天剑客", "玉弦仙灵", "玄冥紫魂", "震天战神", "傀儡"
            };
            String[] ms = {
                    "ztzs_1", "ztzs_2", "ztzs_3", "ztzs_4", "ztzs_5", "ztzs_6", "ztzs_7", "ztzs_8",
            };
            mon = new monster(arr[index - 1], 1, 0, ms[index - 1]);
            if (index == 1) {
                mon.addProp(12000, 12000, 800,
                        500, 500, 600, 1500, 10, 100);
                mon.addSkl("100210000012", 20)
                        .addSkl("100210000011", 20)
                        .addSkl("100210000013", 20);//战魂歌、破甲、挫骨
            } else if (index == 2) {
                mon.addProp(12000, 12000, 800,
                        300, 300, 600, 1500, 10, 100);
                mon.addSkl("100210000025", 20)
                        .addSkl("100210000026", 20)
                        .addSkl("100210000021", 20);//天籁、返魂、荡魔
            } else if (index == 3) {
                mon.addProp(12000, 12000, 800,
                        300, 300, 600, 1500, 300, 100);
                mon.addSkl("100210000029", 20)
                        .addSkl("100210000032", 20)
                        .addSkl("100210000033", 20);//淬毒、断脉、凝钢
            } else if (index == 4) {
                mon.addProp(12000, 12000, 1200,
                        300, 300, 600, 1500, 10, 100);
                mon.addSkl("100210000005", 20)
                        .addSkl("100210000002", 20)
                        .addSkl("100210000007", 20);//连斩、猛虎、狂龙
            } else if (index == 5) {
                mon.addProp(12000, 12000, 1000,
                        300, 300, 600, 1500, 10, 1000);
                mon.addSkl("100210000018", 20)
                        .addSkl("100210000019", 20);//魔魂、夺魂
            } else if (index == 6) {
                mon.addProp(12000, 12000, 1000,
                        300, 300, 2000, 1500, 500, 100);
                mon.addSkl("100210000035", 20)
                        .addSkl("100210000039", 20)
                        .addSkl("100210000037", 20);//淬毒、碎魂、定身
            } else if (index == 7) {
                mon.addProp(500000, 500000, 20000,
                                20000, 20000, 2000, 25000, 500, 1000)
                        .addKangXing(0, 0, 5000, 5000);
                mon.addSkl("100210000035", 20)
                        .addSkl("100210010298", 1)
                        .addSkl("100210010294", 1)
                        .addSkl("100210030037", 1)
                        .addSkl("100210010314", 1);//淬毒、强反、真吸、强腐、魔神降临
            } else if (index == 8) {
                mon.addProp(6000, 6000, 500,
                        100, 100, 100, 1500, 10, 100);
            }
            return mon;
        } /*else if (key.contains("tianbing")) {
            mon = new monster("天兵", 1, 0, "tianbing")
                    .addProp(50000, 1000, 1000, 500, 500, 600, 5000, 10, 100);
            return mon;
        }*/ else if (key.contains("tupo_")) {
            mon = new monster("心魔", 1, 0, "tianbing")
                    .addProp(500, 1000, 100, 100, 100, 600, 5000, 10, 100);
            return mon;
        } else if (key.contains("jianxi_")) {
            mon = new monster("奸细", 1, 0, "tianbing")
                    .addProp(5000, 1000, 1000, 100, 100, 600, 5000, 10, 100);
            return mon;
        } else if (key.contains("xhxy_")) {
            String nm = "吸魂小妖";
            if (key.contains("_2")) nm = "小鬼";
            mon = new monster(nm, 1, 0, key)
                    .addProp(5000, 1000, 1000, 100, 100, 600, 5000, 10, 100);
            return mon;
        } else if (key.contains("hhbk_")) {
            String[] arr = {
                    "机关恶兽", "迷路恶兽", "神龙后裔",
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1] + "", 1, 0, key)
                    .addProp(50000, 10000, 2000, 1000, 1000, 600, 5000, 10, 100);
            return mon;
        } else if (key.contains("dmkj_")) {
            String[] arr = {
                    "破天巨熊", "隐梦云豹", "噬梦虫", "化梦鬼木", "入梦双蛇", "赤痕梦蛛", "吞梦妖龙"
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1] + "", 70 + index * 5, 0, key)
                    .addProp(2000 + index * 1000, 10000, 100 + index * 200, 20 + index * 20, 20 + index * 20, 600, 5000, 10, 100);
            return mon;
        }else if (key.contains("xxzd_")) {
            String[] arr = {
                    "旺财", "小强",
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1] + "", 70 + index * 5, 0, key)
                    .addProp(20000 + index * 1000, 10000, 1000 + index * 200, 200 + index * 20, 200 + index * 20, 600, 5000, 10, 100);
            return mon;
        } else if (key.contains("cyby_")) {//采阴补阳
            mon = new monster("狐萌萌", 1, 0, key)
                    .addProp(5000, 1000, 1000, 100, 100, 600, 5000, 10, 100);
            return mon;
        } else if (key.contains("jyfy_")) {
            String[] arr = {
                    "太二真人", "西门好色", "鲁光光", "东方必败", "完颜失色",
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1] + "", 1, 0, key)
                    .addProp(5000, 1000, 1000, 100, 100, 600, 5000, 10, 100);
            return mon;
        } else if (strUtils.isMatch(key, "yzj_([0-9]{1})")) {
            String[] arr = {
                    "玄铁石精", "炼神木灵",
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1] + "", 1, 0, key)
                    .simpleToProp(500f);
            return mon;
        } else if (key.contains("mpbwz_")) {
            String[] arr = {
                    "鸡毛兽人", "长尾兽人", "短腿兽人",
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1] + "", 1, 0, key)
                    .simpleToProp(500f);
            return mon;
        } else if (key.contains("bprw_")) {
            String[] arr = {
                    "寒风破", "冰啼", "千户花", "江陵幕", "凯玄",
            };
            int index = Integer.parseInt(key.split("_")[1]);
            mon = new monster(arr[index - 1] + "", 1, 0, key)
                    .simpleToProp(500f);
            return mon;
        }
        return null;
    }
}

class monster {
    public String name;
    public int lever;
    public int type;//物理、法术
    public String model;
    public JSONObject prop;
    public JSONArray skill;

    public monster(String name, int lever, int type, String model) {
        this.name = name;
        this.lever = lever;
        this.type = type;
        this.model = model;
        this.prop = new JSONObject();
        this.skill = new JSONArray();
    }

    public monster setAttackType(int type) {
        this.type = type;
        return this;
    }

    /**
     * 单k值来控制战斗属性
     */
    public monster simpleToProp(float k) {
        return this.addProp(25 * k, 25 * k, 5 * k, 1 * k, 1 * k, 10 * k, 20 * k, 0.5f * k, 1 * k);
    }

    public monster setPropByAbyss(float k) {
        return this.addProp(80 * k, 80 * k, 10 * k, 4f * k, 4f * k, 10 * k, 10 * k, 0.5f * k, 1 * k);
    }

    public monster addAutoProp(float lv) {
        return this.addProp(300 + 200 * lv, 10000,
                10 + lv * 20, 1 + lv,
                1 + lv, 1 + 10 * lv,
                500 + 20 * lv, 1 + lv , 1 + lv * 2);
    }

    public monster addProp(float xue, float lan, float wg, float wf, float ff, float css, float mz, float sd, float bj) {
        prop.put("max_xue", xue);
        prop.put("xue", xue);
        prop.put("max_lan", lan);
        prop.put("lan", lan);
        prop.put("wg", wg);
        prop.put("fg", wg);
        prop.put("wf", wf);
        prop.put("ff", ff);
        prop.put("css", css);
        prop.put("mz", mz);
        prop.put("sd", sd);
        prop.put("bj", bj);
        prop.put("lxkx", 0);
        prop.put("bjkx", 0);
        prop.put("hlkx", 0);
        prop.put("hskx", 0);
        return this;
    }

    public monster addKangXing(float lxkx, float bjkx, float hlkx, float hskx) {
        prop.put("lxkx", lxkx);
        prop.put("bjkx", bjkx);
        prop.put("hlkx", hlkx);
        prop.put("hskx", hskx);
        return this;
    }

    public monster addSkl(String key, int lv) {
        JSONObject skl = new JSONObject();
        skl.put("key", key);
        skl.put("lv", lv);
        skill.add(skl);
        return this;
    }
}

