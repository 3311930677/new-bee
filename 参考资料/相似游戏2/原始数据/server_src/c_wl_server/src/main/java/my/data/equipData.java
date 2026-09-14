package my.data;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.gameUtils.roleUtils;
import my.model.fbResult;
import my.utils.strUtils;

import java.util.ArrayList;
import java.util.List;

/**
 * 装备数据
 */
public class equipData {
    /**
     * 获取刻印基础属性
     */
    public static JSONObject getKyAttr(String key) {
        //1力量、2敏捷、3耐力、4智力、5精神、6血量、7蓝量、8物攻、9法攻、10物防、11法防、
        //12命中、13闪避、14暴击、15速度、16爆抗、17血抗、18混抗、19昏抗
        int i = Integer.parseInt(key.substring(4));
        String[] arr = {
                "ll", "mj", "nl", "zl", "js", "max_xue",
                "max_lan", "wg", "fg", "wf", "ff",
                "mz", "sd", "bj", "css", "bjkx", "lxkx",
                "hlkx", "hskx",
        };
        float[] brr = {
                30, 15, 30, 30, 60, 200, 200, 60, 60, 80, 80,
                50, 30, 60, 30, 100, 100, 100, 100,
        };

        String k = null;
        float v = 0;
        if (i >= 19 && i < 38) {
            k = arr[i - 19];
            v = brr[i - 19] * 1.5f;
        } else if (i >= 38 && i < 57) {
            k = arr[i - 38];
            v = brr[i - 38] * 2;
        } else {
            k = arr[i];
            v = brr[i];
        }
        JSONObject obj = new JSONObject();
        obj.put("k", k);
        obj.put("v", v);
        return obj;
    }

    /**
     * 补刻印字段
     */
    public static void putKeyin(JSONObject equip) {
        JSONObject obj = new JSONObject();
        obj.put("a", null);
        obj.put("b", null);
        obj.put("c", null);
        obj.put("d", null);
        obj.put("e", null);
        equip.put("keyin", obj);
    }

    /**
     * 是否为镶嵌石
     */
    public static boolean isInlayBaoshi(String key) {
        if (key.substring(0, 4).equals("1003")) {
            return true;
        }
        return false;
    }

    /**
     * 是否为装备(不包含法宝此类)
     */
    public static boolean isEquip(String key) {
        if (key.substring(0, 4).equals("1001")) {
            //0-5是装备5以上就是补给包、法宝等
            if (strUtils.isMatch(key.substring(4, 8), "100([0-5]{1})"))
                return true;
        }
        return false;
    }

    /**
     * 是否为法宝
     */
    public static boolean isFaBao(String key) {
        if (key.substring(0, 4).equals("1001")) {
            if (key.substring(4, 8).equals("1007"))
                return true;
        }
        return false;
    }

    /**
     * 获取模板最大魔力
     */
    public static int getMbMaxMoLi(String mbKey) {
        JSONObject mb = getMoban(mbKey);
        int lv = mb.getInteger("lvIndex");
        int ml = 570;
        if (lv == 1) ml = 1130;
        else if (lv == 2) ml = 1590;
        return ml;
    }

    public static JSONObject getMoBanMaxAttr(String key) {
        JSONObject mb = getMoban(key);
        int part = mb.getInteger("partIndex");
        int job = mb.getInteger("jobIndex");
        int lv = mb.getInteger("lvIndex");
        JSONObject attr = new JSONObject();
        if (part == 0)//按职业分
        {
            if (job == 2 || job == 3) attr.put("fg", 1374);
            else attr.put("wg", 1374);
        } else if (part == 1)//不区分职业、门派
        {
            attr.put("wg", 685);
            attr.put("fg", 685);
            attr.put("css", 451);
        } else if (part == 2)//不区分职业、门派
        {
            attr.put("max_xue", 2846);
        } else if (part == 3)//3及以上是按门派分
        {
            if (job == 7) {
                attr.put("max_xue", 1460);
                attr.put("wg", 328);
            } else if (job == 8) {
                attr.put("max_xue", 1460);
                attr.put("fg", 328);
            } else {
                attr.put("max_xue", 1840);
                attr.put("wg", 225);
            }
        } else if (part == 4) {
            if (job == 7) {
                attr.put("max_xue", 860);
                attr.put("ff", 534);
            } else if (job == 8) {
                attr.put("max_xue", 1460);
                attr.put("ff", 410);
            } else {
                attr.put("css", 218);
                attr.put("ff", 584);
            }
        } else if (part == 5) {
            attr.put("max_xue", 4775);
        } else if (part == 6) {
            attr.put("max_xue", 860);
            attr.put("wf", 534);
            if (job == 8) {
                attr.put("max_xue", 1460);
                attr.put("wf", 410);
            }
        } else if (part == 7) {
            attr.put("max_xue", 1460);
            attr.put("wf", 328);
            if (job == 8) {
                attr.put("max_xue", 1460);
                attr.put("max_lan", 422);
            }
        } else if (part == 8) {
            attr.put("css", 764);
            attr.put("max_lan", 284);
        }
        float k = 0.3f;
        if (lv == 1) k = 0.6f;
        else if (lv == 2) k = 1f;
        for (String p : attr.keySet()) {
            float v = attr.getFloat(p) * k;
            attr.put(p, v);
        }
        return attr;
    }

    /**
     * 判断模板跟装备的职业、部位是否一致
     */
    public static boolean isSameJobAndPartByMb(String epKey, String mbKey) {
        JSONObject ep = get(epKey);
        JSONObject mb = getMoban(mbKey);
        if (ep.getInteger("jobIndex") == mb.getInteger("jobIndex") &&
                ep.getInteger("partIndex") == mb.getInteger("partIndex")) return true;
        /*String equipKey = epKey.substring(4);
        int b = Integer.parseInt(equipKey.substring(4));
        int part = b % 9;//分9份确定部位
        int job = (b / 9) % 6;//按9个为一组分，每组6个职业，确定所在职业
        String key = mbKey.substring(4);
        int b1 = Integer.parseInt(key);
        int part1 = b1 % 9;//分9份确定部位
        int job1 = (b1 / 9) % 6;//按9个为一组分，每组6个职业，确定所在职业
        if (job == job1 && part == part1) return true;*/
        return false;
    }

    /**
     * 获取模板信息
     */
    public static JSONObject getMoban(String mbKey) {
        String key = mbKey.substring(4);
        int b = Integer.parseInt(key);
        int part = 0;
        int job = 0;
        int lv = 0;
        //6职业，3等级魔板 9个部位 3*6*9=162种
        //武器 1部位6职业3等级 1*6*3
        //项链、戒指 1部位1职业3等级 1*1*3
        //其他 1部位3职业3等级 1*3*3
        if (b < 18) {
            part = 0;
            job = b % 6;
            lv = (b / 6) % 3;
        } else if (b < 18 + 3 * 2) {
            int index = (b - 18) / 3;
            part = 1 + index;
            job = 6;
            lv = ((b - (18 + 3 * index))) % 3;
        } else if (b < 18 + 3 * 2 + 9 * 6) {
            int index = (b - (18 + 3 * 2)) / 9;
            part = 3 + index;
            job = 7 + (b - (18 + 3 * 2 + 9 * index)) % 3;
            lv = ((b - (18 + 3 * 2 + 9 * index)) / 3) % 3;
        }
        JSONObject res = new JSONObject();
        res.put("partIndex", part);
        res.put("jobIndex", job);
        res.put("lvIndex", lv);
        return res;
    }

    /**
     * 是否为魔板
     */
    public static boolean isMoBan(String key) {
        if (key.substring(0, 4).equals("1010")) return true;
        return false;
    }

    /**
     * 判断是否为橙装
     */
    public static boolean isGoldEquip(String key) {
        int quality = get(key).getInteger("quality");
        if (quality == 3) return true;
        return false;
    }

    /**
     * 判断是否为亮金装
     */
    public static boolean isLiangGoldEquip(String key) {
        int quality = get(key).getInteger("quality");
        if (quality == 4) return true;
        return false;
    }

    /**
     * 判断是否为神装
     */
    public static boolean isShenEquip(String key) {
        JSONObject e = get(key);
        if (e == null) return false;
        int quality = e.getInteger("quality");
        if (quality == 5) return true;
        return false;
    }

    /**
     * 获取法宝、护符、功法等效果
     */
    public static List<fbResult> getFabaoResult(String key) {
        List<fbResult> list = new ArrayList<>();
        switch (key) {
            case "20070000": {
                list.add(new fbResult("final_hurt_add", 0.01f, 0f));
                return list;
            }
            case "20070001": {
                list.add(new fbResult("final_cure_add", 0.007f, 0f));
                return list;
            }
            case "20070002": {
                list.add(new fbResult("wf&ff", 0.007f, 0f));
                return list;
            }
            case "20070003": {
                list.add(new fbResult("final_hurt_cut", 0.009f, 0f));
                return list;
            }
            case "20070004": {
                list.add(new fbResult("wg", 70f, 0f, 80));
                return list;
            }
            case "20070005": {
                list.add(new fbResult("fg", 70f, 0f, 80));
                return list;
            }
            case "20070006": {
                list.add(new fbResult("wf", 50f, 0f, 80));
                return list;
            }
            case "20070007": {
                list.add(new fbResult("bj", 100f, 0f, 80));
                return list;
            }
            case "20070008": {
                list.add(new fbResult("ff", 50f, 0f, 80));
                return list;
            }
            case "20070009": {
                list.add(new fbResult("max_xue", 200f, 0f, 80));
                return list;
            }
            case "20070010": {
                list.add(new fbResult("final_hurt_add", 0.005f, 0f, 60));
                return list;
            }
            case "20070011": {
                list.add(new fbResult("final_hurt_cut", 0.005f, 0f, 60));
                return list;
            }
            case "20080000": {
                list.add(new fbResult("bjkx", 80, 0f, 60));
                return list;
            }
            case "20080001": {
                list.add(new fbResult("lxkx", 80, 0f, 60));
                return list;
            }
            case "20080002": {
                list.add(new fbResult("hlkx", 80, 0f, 60));
                return list;
            }
            case "20080003": {
                list.add(new fbResult("hskx", 80, 0f, 60));
                return list;
            }
            case "20090000": {
                list.add(new fbResult("final_wg", 0.008f, 0f, 60));
                list.add(new fbResult("final_fg", 0.008f, 0f, 60));
                return list;
            }
            case "20090001": {
                list.add(new fbResult("final_wf", 0.008f, 0f, 60));
                list.add(new fbResult("final_ff", 0.008f, 0f, 60));
                return list;
            }
        }
        return list;
    }

    /**
     * 获取护符的抗性
     */
    public static List<fbResult> getHuFuResult(String key) {
        List<fbResult> list = new ArrayList<>();
        if (key.equals("100110080000")) {
            list.add(new fbResult("bjkx", 100f / 20, 0f, 20));
        } else if (key.equals("100110080001")) {
            list.add(new fbResult("hlkx", 100f / 20, 0f, 20));
        } else if (key.equals("100110080002")) {
            list.add(new fbResult("hskx", 100f / 20, 0f, 20));
        } else if (key.equals("100110080003")) {
            list.add(new fbResult("lxkx", 100f / 20, 0f, 20));
        } else if (key.equals("100110080004")) {
            list.add(new fbResult("bjkx", 300f / 40, 0f, 40));
            list.add(new fbResult("hlkx", 300f / 40, 0f, 40));
        } else if (key.equals("100110080005")) {
            list.add(new fbResult("hskx", 300f / 40, 0f, 40));
            list.add(new fbResult("lxkx", 300f / 40, 0f, 40));
        } else if (key.equals("100110080006")) {
            list.add(new fbResult("bjkx", 900f / 70, 0f, 70));
            list.add(new fbResult("hlkx", 900f / 70, 0f, 70));
            list.add(new fbResult("hskx", 900f / 70, 0f, 70));
        } else if (key.equals("100110080007")) {
            list.add(new fbResult("lxkx", 900f / 70, 0f, 70));
            list.add(new fbResult("hlkx", 900f / 70, 0f, 70));
            list.add(new fbResult("hskx", 900f / 70, 0f, 70));
        } else if (key.equals("100110080008")) {
            list.add(new fbResult("bjkx", 1400f / 100, 0f, 100));
            list.add(new fbResult("lxkx", 1400f / 100, 0f, 100));
            list.add(new fbResult("hlkx", 1400f / 100, 0f, 100));
            list.add(new fbResult("hskx", 1400f / 100, 0f, 100));
        }
        return list;
    }


    /**
     * 初始化法宝属性
     */
    public static void putFaBaoAttr(JSONObject equip) {
        JSONObject msg = get(equip.getString("key"));
        if (!msg.getString("part").equals("fb")) {
            return;
        }
        //fixme 法宝影响攻击加持、减免、最终计算结果缩小倍数等
        JSONObject obj = new JSONObject();
        obj.put("lv", 0);//强化等级
        obj.put("type", 0);//针对的类型 人物、宠物、怪物
        equip.put("forging", obj);
        obj = new JSONObject();
        obj.put("lqz", 0);//灵气值 最高1000 每分钟消耗4点
        obj.put("v", 0);//满1000则熟练度+250
        obj.put("sld", 0);//熟练度 最高 1000*lv+4000
        obj.put("lv", 0);//阶级
        obj.put("quality", 1);//蓝品5个阶 紫品10个 橙品15个
        equip.put("zhuling", obj);
        //升阶到紫品有一个镶嵌孔，橙2个
    }

    /**
     * 初始化护符属性
     */
    public static void putHuFuAttr(JSONObject equip) {
        JSONObject msg = get(equip.getString("key"));
        if (!msg.getString("part").equals("hf")) {
            return;
        }
        //fixme 暴击、流血、昏睡、混乱等抗性
        JSONObject obj = new JSONObject();
        obj.put("lv", 0);//阶，通过吞噬护符来提升
        obj.put("exp", 0);//当前阶所存在的经验
        equip.put("forging", obj);
    }

    /**
     * 初始化功法属性
     */
    public static void putGongfaAttr(JSONObject equip) {
        JSONObject msg = get(equip.getString("key"));
        if (!msg.getString("part").equals("gf")) {
            return;
        }
        //fixme 决定人物基础属性转扩展属性所增加的比例
        JSONObject obj = new JSONObject();
        obj.put("lv", 0);//阶，通过道具提升
        obj.put("exp", 0);//当前阶所存在的经验
        equip.put("forging", obj);
    }

    /**
     * 放置锻造\镶嵌、潜力属性
     */
    public static void putForging(JSONObject equip) {
        JSONObject msg = get(equip.getString("key"));
        //补给包、法宝、护符、功法不需要生成
        if (msg == null
                || msg.getString("part").equals("bjb") ||
                msg.getString("part").equals("fb") ||
                msg.getString("part").equals("hf") ||
                msg.getString("part").equals("gf")) {
            return;
        }
        JSONObject obj = new JSONObject();
        obj.put("lv", 0);
        equip.put("forging", obj);
        obj = new JSONObject();
        obj.put("num", 0);
        obj.put("list", new JSONArray());
        equip.put("inlay", obj);
        obj = new JSONObject();
        obj.put("num", 0);
        obj.put("max", 0);
        equip.put("potential", obj);
    }

    public static void putCapacity(JSONObject equip) {
        JSONObject msg = get(equip.getString("key"));
        if (msg == null || !msg.getString("part").equals("bjb")) {
            return;
        }
        JSONObject capacity = new JSONObject();
        capacity.put("num", getCapacity(msg.getInteger("quality")));
        equip.put("capacity", capacity);
    }

    public static Integer getCapacity(Integer quality) {
        Integer sum = 0;
        switch (quality) {
            case 0: {
                sum = 10000;
                break;
            }
            case 1: {
                sum = 150000;
                break;
            }
            case 2: {
                sum = 200000;
                break;
            }
            case 3: {
                sum = 3000000;
                break;
            }
            case 4: {
                sum = 5000000;
                break;
            }
            case 5: {
                sum = 10000000;
                break;
            }
        }
        return sum;
    }

    /**
     * 刻印属性
     * 刻印最初的时候只有固有属性，随机属性需要聚灵产生
     * 根据品质决定随机值大小，一共可聚灵8次（即8条）
     * 注意随机属性不允许增幅，增幅的只能是固有属性
     * 雕文 12生肖雕文 2、3、5件有不同的效果（金品才有）
     * 一件装备只能容纳5个雕纹
     */
    public static void putKyAttr(JSONObject ky) {
        int i = getKyQuality(ky.getString("key"));
        //金品生成雕纹
        if (i == 3) {
            if (strUtils.isHappend(0, 100, 0.1f)) {
                //0-11个 鼠牛虎。。。
                ky.put("dw", strUtils.getRandom(0, 12));
            }
        }
    }

    /**
     * 设置过期时间
     */
    public static void putEndTime(JSONObject gd) {
        gd.put("endTime", strUtils.getTime() + 15 * 24 * 60 * 60 * 1000);
    }

    /**
     * 神装随机技能
     */
    public static void putSzSkill(JSONObject equip) {
        JSONObject msg = get(equip.getString("key"));
        //补给包、法宝、护符、功法不需要生成
        if (msg == null ||
                msg.getString("part").equals("bjb") ||
                msg.getString("part").equals("fb") ||
                msg.getString("part").equals("hf") ||
                msg.getString("part").equals("gf")) {
            return;
        }
        //要求必须是神装 0白1蓝2紫3金4亮金5红
        if (msg.getInteger("quality") != 5) {
            return;
        }
        randomPutZbSkill(equip);
    }

    /**
     * 随机放置一个装备技能
     */
    public static void randomPutZbSkill(JSONObject equip) {
        JSONArray list = new JSONArray();
        JSONObject skl = new JSONObject();
        skl.put("lv", 1);
        //随机装备技能
        //todo 分3品 蓝、紫、金
        int r = strUtils.getRandom(3600, 3609);
        skl.put("key", r + "");
        list.add(skl);
        equip.put("skill", list);
    }

    /**
     * 判断是否为装备技能
     */
    public static boolean isEquipSkill(String key) {
        if (Integer.parseInt(key) >= 3600 && Integer.parseInt(key) < 3609) {
            return true;
        }
        return false;
    }

    /**
     * 放置一个学习的装备技能
     */
    public static void putZbSkill(JSONObject equip, String sklKey) {
        if (equip.get("skill") == null) {
            equip.put("skill", new JSONArray());
        }
        JSONArray list = equip.getJSONArray("skill");
        //神装3个位置 普通1个位置
        if (list.size() >= 3 && isShenEquip(equip.getString("key"))) {
            list.remove(strUtils.getRandom(0, 3));
        } else if (list.size() == 1 && !isShenEquip(equip.getString("key"))) {
            list.remove(0);
        }
        JSONObject skl = new JSONObject();
        skl.put("lv", 1);
        //随机装备技能
        //todo 分3品 蓝、紫、金
        skl.put("key", sklKey);
        list.add(skl);
        equip.put("skill", list);

    }

    /**
     * 判断装备是否为套装
     */
    public static boolean isTaoZhuang(String equipKey) {
        int b = Integer.parseInt(equipKey.substring(8));
        int taoz = b / (10 * 6 * 9);
        if (taoz == 5) return true;
        return false;
    }

    /**
     * 装备随机属性
     * 包含属性：num，key
     */
    public static void putRandomAttr(JSONObject equip) {
        String epKey = equip.getString("key");
        JSONObject msg = get(epKey);
        //补给包、法宝、护符、功法不需要生成
        if (msg == null ||
                msg.getString("part").equals("bjb") ||
                msg.getString("part").equals("fb") ||
                msg.getString("part").equals("hf") ||
                msg.getString("part").equals("gf")) {
            return;
        }
        JSONObject obj = getJingLianBaseAttr(epKey);
        //按品质随机保留属性
        equip.put("randomAttr", new JSONArray());
        String arr[] = {"ll", "zl", "nl", "js", "mj", "wg", "fg",
                "wf", "ff", "mz", "sd", "bj", "css", "max_xue", "max_lan"};
        int len = getMaxJingLianTiaoNum(epKey);
        JSONArray randomAttr = equip.getJSONArray("randomAttr");
        for (int i = 0; i < len; i++) {
            int index = strUtils.getRandom(0, obj.keySet().size() - 1);
            String propName = arr[index];
            int end = obj.getInteger(propName);
            if (end < 2) continue;
            int v = strUtils.getRandom(1, end);
            JSONObject a = new JSONObject();
            a.put("k", propName);
            a.put("v", v);
            randomAttr.add(a);
        }
    }

    /**
     * 根据key获取最大精炼属性
     */
    public static int getMaxJingLianAttr(String key, String attrK) {
        JSONObject attr = getJingLianMaxAttr(key);
        return attr.getInteger(attrK);
    }

    /**
     * 获取精炼的最大属性
     */
    public static JSONObject getJingLianMaxAttr(String key) {
        JSONObject a = getJingLianBaseAttr(key);
        for (String k : a.keySet()) {
            if (roleUtils.isBaseProp(k)) {
                a.put(k, a.getFloat(k) * 2f);
            } else {
                a.put(k, a.getFloat(k) * 2.83f);
            }
        }
        return a;
    }

    /**
     * 获取精炼基础属性
     */
    public static JSONObject getJingLianBaseAttr(String key) {
        JSONObject msg = get(key);
        //每个品质提升20%
        float k = msg.getInteger("lv") * (1 + msg.getInteger("quality") * 0.2f);
        //对于套装还要提升10%
        if (isTaoZhuang(key)) {
            k = k * 1.1f;
        }
        JSONObject obj = new JSONObject();
        obj.put("ll", 10 * k / 50);//2
        obj.put("zl", 10 * k / 50);
        obj.put("nl", 10 * k / 50);
        obj.put("js", 10 * k / 50);
        obj.put("mj", 10 * k / 50);

        obj.put("wg", 20 * k / 50);//2.83
        obj.put("fg", 20 * k / 50);
        obj.put("wf", 10 * k / 50);
        obj.put("ff", 10 * k / 50);
        obj.put("mz", 25 * k / 50);
        obj.put("sd", 18 * k / 50);
        obj.put("bj", 19 * k / 50);
        obj.put("css", 20 * k / 50);

        obj.put("max_xue", 60 * k / 50);
        obj.put("max_lan", 60 * k / 50);
        return obj;
    }

    /**
     * 获取最大的精炼条数
     */
    public static int getMaxJingLianTiaoNum(String key) {
        JSONObject msg = get(key);
        int len = 0;
        if (msg.getInteger("quality") == 1) {
            len = 1;
        } else if (msg.getInteger("quality") > 1 && msg.getInteger("quality") <= 4) {
            len = 2;
        } else if (msg.getInteger("quality") == 5) {//神装
            len = 4;
        }
        return len;
    }

    /**
     * 判断是否超过最大属性
     */
    public static boolean isOverLimitAttr(String key, String attrK1, int attrV1) {
        int max = getMaxJingLianAttr(key, attrK1);
        if (max == 0) {
            return true;
        }
        if (attrV1 >= max) {
            return true;
        }
        return false;
    }


    /**
     * 判断两个装备是否满足精炼条件
     * 必须同品质、等级
     * 品质>3的允许2以上的进行精炼
     */
    public static boolean isEnoughJL(String key1, String key2) {
        JSONObject e1 = get(key1);
        if (e1 == null) return false;
        JSONObject e2 = get(key2);
        if (e2 == null) return false;
        if (e1.getInteger("lv") != e2.get("lv")) return false;
        //紫品以下要求质量一致，紫品及以上要求副装也是紫品以上
        if ((e1.getInteger("quality") < 2 && e2.getInteger("quality") == e1.getInteger("quality")) ||
                (e1.getInteger("quality") >= 2 && e2.getInteger("quality") >= 2)) {
            return true;
        }
        return false;
    }

    /**
     * 判断是否为刻印石
     */
    public static boolean isKeyin(String k) {
        if (strUtils.isMatch(k, "1009([0-9]{8})")) {
            return true;
        }
        return false;
    }

    /**
     * 判断是否为宠物装备
     */
    public static boolean isPetEquip(String k) {
        if (strUtils.isMatch(k, "1016([0-9]{4})")) {
            return true;
        }
        return false;
    }

    /**
     * 获取刻印品质
     */
    public static int getKyQuality(String k) {
        int i = Integer.parseInt(k);
        if (i >= 10900000 && i < 10900019) {
            return 1;//蓝
        } else if (i >= 10900019 && i < 10900038) {
            return 2;//紫
        } else if (i >= 10900038 && i < 10900057) {
            return 3;//金
        }
        return 1;
    }

    /**
     * 根据职业、等级、部位、品质获取装备（不包含药囊、法宝等）
     * part "wq", "jb", "sz", "wb", "tb", "xb", "yb", "tuib", "jiaob"
     * job "ms", "dj", "qm", "ty", "ym", "lc","*","ms/dj", "qm/ty", "ym/lc"
     * quality 0白、1蓝、2紫、3金、4亮金、5红
     * lv 0=>1-10 1=>11-20 2=>21-30 3=>31-40...
     * taoz 0|1|2|3|4|（散装）  5（套装）
     * 注意：部位sz之后的job要+7（"ms/dj", "qm/ty", "ym/lc"）
     */
    public static String getEquipKey(Integer quality, Integer part, Integer job, Integer lv, Integer taoz) {
        //装备的标志
        String bz = "1001";
        //前四位
        int a = strUtils.getRandom(1000, 1006);
        if (quality != null) a = 1000 + quality;
        //9部位6职业10等级5散装1套装=9*6*10*6=3240 * 6品质=19440种
        /*if (b < 360) {//wq
            part = 0;
            job = b % 6;//6个职业，确定所在职业
            lv = (b / 6) % 10 * 10 + lvs[part];//6个职业，又每组10个等级，确定所在等级
            taoz = b / (10 * 6);//确定散装
        } else if (b < 360 + 60 * 2) {//jb/sz
            int index = (b - (360 + 60 * 2)) / 60;
            part = 1 + index;
            job = 6;
            lv = (b - 360 - 60 * index) % 10 * 10 + lvs[part];//10个等级，确定所在等级
            taoz = (b - 360 - 60 * index) / 10;//确定散装
        } else if (b < 360 + 60 * 2 + 180 * 6) {//wb
            int index = (b - (360 + 60 * 2)) / 180;
            part = 3 + index;
            job = 7 + (b - 360 - 60 * 2 - 180 * index) % 3;//相当于只有3个职业
            lv = ((b - 360 - 60 * 2 - 180 * index) / 3) % 10 * 10 + lvs[part];//3职业10个等级，确定所在等级
            taoz = (b - 360 - 60 * 2 - 180 * index) / (10 * 3);//确定散装
        }*/
        //根据参数来创造一个装备key
        // part,  job,  lv,  taoz
        //首先按部位来确定划分的区间
        int start = 0;
        int end = 360 + 60 * 2 + 180 * 6;//区间的极限
        if (part == null) {
            //部位必须要存在，因为部位关系到装备的职业，如武器只能是6个职业，戒指无职业
            part = strUtils.getRandom(0, 9);
        }
        if (part == 0) end = 360;
        else if (part == 1 || part == 2) {
            start = 360 + 60 * (part - 1);
            end = 360 + 60 * part;
        } else {
            start = 360 + 60 * 2 + 180 * (part - 3);
            end = 360 + 60 * 2 + 180 * (part - 2);
        }
        List<Integer> list = new ArrayList<>();
        for (int i = start; i < end; i++) {
            list.add(i);
        }
        //在此区间中筛选出该职业对应的数
        if (job != null) {
            if (part == 0) {
                for (int i = 0; i < list.size(); i++) {
                    if ((list.get(i) - start) % 6 != job) {
                        list.remove(i);
                        i--;
                    }
                }
            } else if (part == 1 || part == 2) {
                //项链、戒指都是无职业一种，所以不用筛选
            } else {
                //传入的职业为标准职业时，需要处理
                if (job == 0 || job == 1) job = 7;
                else if (job == 2 || job == 3) job = 8;
                else if (job == 4 || job == 5) job = 9;
                else if (job == 6) job = strUtils.getRandom(7, 10);
                if (job < 7) {
                    System.err.println("手指之后的部位job需要+7来表示墨、道、阳");
                }
                //7 + (b - 360 - 60 * 2 - 180 * index) % 3;
                for (int i = 0; i < list.size(); i++) {
                    if (7 + (list.get(i) - start) % 3 != job) {
                        list.remove(i);
                        i--;
                    }
                }
            }
        }
        //在此区间找等级一致的
        if (lv != null) {
            if (part == 0) {
                //lv = (b / 6) % 10 * 10 + lvs[part];
                for (int i = 0; i < list.size(); i++) {
                    if (((list.get(i) - start) / 6) % 10 != lv) {
                        list.remove(i);
                        i--;
                    }
                }
            } else if (part == 1 || part == 2) {
                //(b - 360 - 60 * index) % 10 * 10 + lvs[part];
                for (int i = 0; i < list.size(); i++) {
                    if ((list.get(i) - start) % 10 != lv) {
                        list.remove(i);
                        i--;
                    }
                }
            } else {
                //((b - 360 - 60 * 2 - 180 * index) / 3) % 10 * 10 + lvs[part];
                for (int i = 0; i < list.size(); i++) {
                    if (((list.get(i) - start) / 3) % 10 != lv) {
                        list.remove(i);
                        i--;
                    }
                }
            }
        }
        if (taoz != null) {
            if (part == 0) {
                //b / (10 * 6)
                for (int i = 0; i < list.size(); i++) {
                    if ((list.get(i) - start) / (10 * 6) != taoz) {
                        list.remove(i);
                        i--;
                    }
                }
            } else if (part == 1 || part == 2) {
                //(b - 360 - 60 * index) / 10;
                for (int i = 0; i < list.size(); i++) {
                    if ((list.get(i) - start) / 10 != taoz) {
                        list.remove(i);
                        i--;
                    }
                }
            } else {
                //(b - 360 - 60 * 2 - 180 * index) / (10 * 3);
                for (int i = 0; i < list.size(); i++) {
                    if ((list.get(i) - start) / (10 * 3) != taoz) {
                        list.remove(i);
                        i--;
                    }
                }
            }
        }

        String c = null;
        if (list.size() == 1) {
            //完全确定的装备
            c = list.get(0) + "";
        } else {
            //需要随机
            c = list.get(strUtils.getRandom(0, list.size())) + "";
        }
        //不满4位需要在前面补0
        if (c.length() < 4) {
            int len = 4 - c.length();
            for (int i = 0; i < len; i++) {
                c = "0" + c;
            }
        }
        return bz + a + c;
    }
    /*public static String getEquipKey(Integer quality, Integer part, Integer job, Integer lv, Integer taoz) {
        //装备的标志
        String bz = "1001";
        //前四位
        int a = strUtils.getRandom(1000, 1006);
        if (quality != null) a = 1000 + quality;
        //9部位6职业10等级5散装1套装=9*6*10*6=3240 * 6品质=19440种
        List<Integer> list = new ArrayList<>();
        for (int i = 0; i < 3240; i++) {
            list.add(i);
        }
        //后四位
        if (part != null) {//是索引0\1\2...
            //限定为指定部位的装备
            for (int i = 0; i < list.size(); i++) {
                if (list.get(i) % 9 != part) {
                    list.remove(i);
                    i--;
                }
            }
        }
        if (job != null) {//是索引0\1\2...
            //限定为指定职业的装备
            for (int i = 0; i < list.size(); i++) {
                if ((list.get(i) / 9) % 6 != job) {
                    list.remove(i);
                    i--;
                }
            }
        }
        if (lv != null) {//是索引0\1\2...
            //限定为指定等级的装备
            for (int i = 0; i < list.size(); i++) {
                if ((list.get(i) / (9 * 6)) % 10 != lv) {
                    list.remove(i);
                    i--;
                }
            }
        }
        if (taoz != null) {//是索引0\1\2...
            //限定为指定5散装1套装
            for (int i = 0; i < list.size(); i++) {
                if (list.get(i) / (10 * 6 * 9) != taoz) {
                    list.remove(i);
                    i--;
                }
            }
        }

        String c = null;
        if (list.size() == 1) {
            //完全确定的装备
            c = list.get(0) + "";
        } else {
            //需要随机
            c = list.get(strUtils.getRandom(0, list.size())) + "";
        }
        //不满4位需要在前面补0
        if (c.length() < 4) {
            int len = 4 - c.length();
            for (int i = 0; i < len; i++) {
                c = "0" + c;
            }
        }
        return bz + a + c;
    }
*/

    /**
     * 获取品质提升到下一等级后的装备key
     */
    public static String getQualityUpEquipKey(JSONObject epMsg) {
        String[] jobs = {"ms", "dj", "qm", "ty", "ym", "lc", "*",
                "ms/dj/zs", "qm/ty/fs", "ym/lc/fz"};
        String[] parts = {"wq", "jb", "sz", "wb", "tb", "xb", "yb", "tuib",
                "jiaob", "bjb", "fb", "hf", "gf"};

        int quality = epMsg.getInteger("quality");
        String partStr = epMsg.getString("part");
        int part = strUtils.getArrContainIndex(partStr, parts);
        String jobStr = epMsg.getString("job");
        int job = strUtils.getArrContainIndex(jobStr, jobs);
        int lv = (epMsg.getInteger("lv") - 1) / 10;
        int taoz = epMsg.getInteger("taoz");
        //0=>1-10 1=>11-20 2=>21-30 3=>31-40...
        return getEquipKey(quality + 1, part, job, lv, taoz);
    }

    /**
     * 获取装备基本信息（法宝、功法、护符也视为装备）
     * 1000-1005开头的是按品质区分的装备（白装0 蓝装1 紫装2 橙装3 金装4 神装5）
     * 1006开头的是药囊（白装0 蓝装1 紫装2 橙装3）
     * 1007开头的是法宝
     * 1008开头的是护符
     * 1009开头的是功法
     */
    public static JSONObject get(String equipKey) {
        //装备1001开头
        if (equipKey.length() < 12 ||
                !equipKey.substring(0, 4).equals("1001")) return null;
        //共12位 标志4位 前四位 后四位
        int a = Integer.parseInt(equipKey.substring(4, 8));
        if (a < 1000 || a > 1009) return null;
        int b = Integer.parseInt(equipKey.substring(8));
        int part = 0;
        int job = 0;
        int lv = 0;
        int taoz = 0;
        int quality = 0;
        int[] lvs = {10, 8, 2, 6, 4, 10, 3, 7, 1};
        String[] jobs = {"ms", "dj", "qm", "ty", "ym", "lc", "*",
                "ms/dj/zs", "qm/ty/fs", "ym/lc/fz"};
        String[] parts = {"wq", "jb", "sz", "wb", "tb", "xb", "yb", "tuib",
                "jiaob", "bjb", "fb", "hf", "gf"};
        if (a < 1006) {
            //部位wq才区分职业，jb、sz是无职业，其他是按墨、道、阳区分
            //按部位来配搭  品质是a决定，不由b计算，所以不参与
            //首先武器 1部位、6职业、10等级、6件套（5散1套） 1*6*10*6=360 （前360个数字占位）
            //颈部 1部位、1职业（即无）、10等级、6件套（5散1套） 1*1*10*6=60 （360后又占60）
            //手指 跟颈部一样 1*1*10*6=60
            //其他部位 1部位、3职业（即墨、道、阳）、10等级、6件套（5散1套） 1*3*10*6=180
            //合计 360+60*2+180*6=1560
            if (b < 360) {//wq
                part = 0;
                job = b % 6;//6个职业，确定所在职业
                lv = (b / 6) % 10 * 10 + lvs[part];//6个职业，又每组10个等级，确定所在等级
                taoz = b / (10 * 6);//确定散装
            } else if (b < 360 + 60 * 2) {//jb/sz
                int index = (b - 360) / 60;
                part = 1 + index;
                job = 6;
                lv = (b - 360 - 60 * index) % 10 * 10 + lvs[part];//10个等级，确定所在等级
                taoz = (b - 360 - 60 * index) / 10;//确定散装
            } else if (b < 360 + 60 * 2 + 180 * 6) {//wb
                int index = (b - (360 + 60 * 2)) / 180;
                part = 3 + index;
                job = 7 + (b - 360 - 60 * 2 - 180 * index) % 3;//相当于只有3个职业
                lv = ((b - 360 - 60 * 2 - 180 * index) / 3) % 10 * 10 + lvs[part];//3职业10个等级，确定所在等级
                taoz = (b - 360 - 60 * 2 - 180 * index) / (10 * 3);//确定散装
            }
            quality = a - 1000;//白装0 蓝装1 紫装2 橙装3 金装4 神装5
        }


        if (a == 1006) {//药囊
            lv = 1;
            part = 9;
            job = 6;
            quality = b;
        } else if (a == 1007) {//法宝
            lv = 60;
            part = 10;
            job = 6;
            quality = 0;
        } else if (a == 1008) {//护符
            lv = 60;
            part = 11;
            job = 6;
            quality = 0;
        } else if (a == 1009) {//功法
            lv = 60;
            part = 12;
            job = 6;
            quality = 0;
        }
        JSONObject obj = new JSONObject();
        obj.put("key", equipKey);
        obj.put("lv", lv);
        obj.put("job", jobs[job]);
        obj.put("part", parts[part]);
        obj.put("jobIndex", job);
        obj.put("partIndex", part);
        obj.put("quality", quality);
        obj.put("taoz", taoz);
        return obj;
    }

    /*public static JSONObject get(String equipKey) {
        //装备1001开头
        if (equipKey.length() < 12 ||
                !equipKey.substring(0, 4).equals("1001")) return null;
        //共12位 标志4位 前四位 后四位
        int a = Integer.parseInt(equipKey.substring(4, 8));
        if (a < 1000 || a > 1009) return null;
        int b = Integer.parseInt(equipKey.substring(8));

        String[] jobs = {"ms", "dj", "qm", "ty", "ym", "lc", "*"};
        String[] parts = {"wq", "jb", "sz", "wb", "tb", "xb", "yb", "tuib",
                "jiaob", "bjb", "fb", "hf", "gf"};
        //部位wq才区分职业，jb、sz是无职业，其他是按墨、道、阳区分

        int[] lvs = {10, 8, 2, 6, 4, 10, 3, 7, 1};
        int part = b % 9;//分9份确定部位
        int job = (b / 9) % 6;//按9个为一组分，每组6个职业，确定所在职业
        int lv = (b / (9 * 6)) % 10 * 10 + lvs[part];//按54个为一组分，每组10个等级，确定所在等级
        int taoz = b / (10 * 6 * 9);//按540个为一组分，确定散装
        int quality = a - 1000;//白装0 蓝装1 紫装2 橙装3 金装4 神装5

        if (a == 1006) {//药囊
            lv = 1;
            part = 9;
            job = 6;
            quality = b;
        } else if (a == 1007) {//法宝
            lv = 60;
            part = 10;
            job = 6;
            quality = 0;
        } else if (a == 1008) {//护符
            lv = 60;
            part = 11;
            job = 6;
            quality = 0;
        } else if (a == 1009) {//功法
            lv = 60;
            part = 12;
            job = 6;
            quality = 0;
        }
        JSONObject obj = new JSONObject();
        obj.put("key", equipKey);
        obj.put("lv", lv);
        obj.put("job", jobs[job]);
        obj.put("part", parts[part]);
        obj.put("quality", quality);
        obj.put("taoz", taoz);
        return obj;
    }*/
    public static JSONObject getPetEquipProp(String key) {
        int index = Integer.parseInt(key.substring(4));
        JSONObject res = new JSONObject();
        if (index == 0) {
            res.put("nl", 88);
        } else if (index == 1) {
            res.put("nl", 144);
        } else if (index == 2) {
            res.put("bj", 660);
            res.put("mz", 330);
        } else if (index == 3) {
            res.put("bj", 961);
            res.put("mz", 481);
        }
        return res;
    }

    public static JSONObject getProp(String key) {
        return count(get(key));
    }

    /**
     * 锻造叠加的属性
     */
    public static JSONObject getAddAttrByForgingLv(JSONObject equip) {
        JSONObject g = get(equip.getString("key"));
        JSONObject res = new JSONObject();
        if (g == null) return res;
        float k = g.getInteger("lv") * 0.3f * equip.getJSONObject("forging").getInteger("lv");

        switch (g.getString("part")) {
            case "wq": {//武器 影响法攻、物攻 fg、wg
                res.put("wg", k);
                res.put("fg", k);
                break;
            }
            case "jb": {//颈部
                res.put("wg", 0.5f * k);
                res.put("fg", 0.5f * k);
                res.put("max_lan", 3f * k);
                break;
            }
            case "sz": {//手指
                res.put("wg", 0.8f * k);
                res.put("fg", 0.8f * k);
                break;
            }
            case "wb": {//腕部
                res.put("wf", 0.5f * k);
                res.put("ff", 0.5f * k);
                break;
            }
            case "tb": {//头部
                res.put("max_xue", 7f * k);
                break;
            }
            case "xb": {//胸部
                res.put("max_xue", 9f * k);
                break;
            }
            case "yb": {//腰部
                res.put("wf", k / 3.5f);
                res.put("ff", k / 3.5f);
                break;
            }
            case "tuib": {//腿部
                res.put("wf", k / 2.7f);
                res.put("ff", k / 2.7f);
                break;
            }
            case "jiaob": {//脚部
                res.put("css", 1.8f * k);
                res.put("wf", k / 2.3f);
                res.put("ff", k / 2.3f);
                break;
            }
            case "bjb": {//补给包

                break;
            }
        }
        switch (g.getString("job")) {
            case "ms": {
                //物攻、物防翻倍
                if (res.getFloat("wg") != null)
                    res.put("wg", res.getFloat("wg") * 2f);
                if (res.getFloat("wf") != null)
                    res.put("wf", res.getFloat("wf") * 2f);
                break;
            }
            case "dj": {
                //物攻、物防翻倍
                if (res.getFloat("wg") != null)
                    res.put("wg", res.getFloat("wg") * 2f);
                if (res.getFloat("wf") != null)
                    res.put("wf", res.getFloat("wf") * 2f);
                break;
            }
            case "qm": {
                if (res.getFloat("fg") != null)
                    res.put("fg", res.getFloat("fg") * 2f);
                if (res.getFloat("ff") != null)
                    res.put("ff", res.getFloat("ff") * 2f);
                break;
            }
            case "ty": {
                if (res.getFloat("fg") != null)
                    res.put("fg", res.getFloat("fg") * 2f);
                if (res.getFloat("ff") != null)
                    res.put("ff", res.getFloat("ff") * 2f);
                break;
            }
            case "ym": {
                if (res.getFloat("wg") != null)
                    res.put("wg", res.getFloat("wg") * 2f);
                if (res.getFloat("css") != null)
                    res.put("css", res.getFloat("css") * 2f);
                break;
            }
            case "lc": {
                if (res.getFloat("wg") != null)
                    res.put("wg", res.getFloat("wg") * 2f);
                if (res.getFloat("css") != null)
                    res.put("css", res.getFloat("css") * 2f);
                break;
            }
            default: {

            }
        }
        //转整数
        /*for (String key : res.keySet()) {
            res.put(key, res.getInteger(key));
        }*/
        return res;
    }

    /**
     * 计算装备固有属性
     */
    public static JSONObject count(JSONObject obj) {
        JSONObject res = new JSONObject();
        if (obj == null) return res;

        //每个部位都有自己确定的基础值，等级为该基础值得倍数，品质影响倍数
        float k = obj.getFloat("lv") *
                (1f + obj.getFloat("quality") * 0.2f) * 0.35f;//每个品质提升20%
        //对于套装还要提升10%
        if (isTaoZhuang(obj.getString("key"))) {
            k += 0.1f;
        }
        //对于物理职业的物攻就需要增加2倍
        switch (obj.getString("part")) {
            case "wq": {//武器 影响法攻、物攻 fg、wg
                res.put("wg", 100f * k / 50f);
                res.put("fg", 100f * k / 50f);
                break;
            }
            case "jb": {//颈部
                res.put("wg", 50f * k / 50f);
                res.put("fg", 50f * k / 50f);
                res.put("max_lan", 200f * k / 50f);
                break;
            }
            case "sz": {//手指
                res.put("wg", 50f * k / 50f);
                res.put("fg", 50f * k / 50f);
                break;
            }
            case "wb": {//腕部
                res.put("wf", 30f * k / 50f);
                res.put("ff", 30f * k / 50f);
                break;
            }
            case "tb": {//头部
                res.put("max_xue", 600f * k / 50f);
                break;
            }
            case "xb": {//胸部
                res.put("max_xue", 800f * k / 50f);
                break;
            }
            case "yb": {//腰部
                res.put("wf", 30f * k / 50f);
                res.put("ff", 30f * k / 50f);
                break;
            }
            case "tuib": {//腿部
                res.put("wf", 30f * k / 50f);
                res.put("ff", 30f * k / 50f);
                break;
            }
            case "jiaob": {//脚部
                res.put("css", 150f * k / 50f);
                res.put("wf", 20f * k / 50f);
                res.put("ff", 20f * k / 50f);
                break;
            }
            case "bjb": {//补给包
                res.put("max_xue", obj.getFloat("quality") * 100f);
                break;
            }
        }
        switch (obj.getString("job")) {
            case "ms": {
                //物攻、物防翻倍
                if (res.getFloat("wg") != null)
                    res.put("wg", res.getFloat("wg") * 2f);
                if (res.getFloat("wf") != null)
                    res.put("wf", res.getFloat("wf") * 2f);
                break;
            }
            case "dj": {
                //物攻、物防翻倍
                if (res.getFloat("wg") != null)
                    res.put("wg", res.getFloat("wg") * 2f);
                if (res.getFloat("wf") != null)
                    res.put("wf", res.getFloat("wf") * 2f);
                break;
            }
            case "qm": {
                if (res.getFloat("fg") != null)
                    res.put("fg", res.getFloat("wg") * 2f);
                if (res.getFloat("ff") != null)
                    res.put("ff", res.getFloat("ff") * 2f);
                break;
            }
            case "ty": {
                if (res.getFloat("fg") != null)
                    res.put("fg", res.getFloat("wg") * 2f);
                if (res.getFloat("ff") != null)
                    res.put("ff", res.getFloat("ff") * 2f);
                break;
            }
            case "ym": {
                if (res.getFloat("wg") != null)
                    res.put("wg", res.getFloat("wg") * 2f);
                if (res.getFloat("css") != null)
                    res.put("css", res.getFloat("css") * 2f);
                break;
            }
            case "lc": {
                if (res.getFloat("wg") != null)
                    res.put("wg", res.getFloat("wg") * 2f);
                if (res.getFloat("css") != null)
                    res.put("css", res.getFloat("css") * 2f);
                break;
            }
            default: {

            }
        }
        return res;
    }
}
