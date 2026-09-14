package my.data;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.model.pet;
import my.utils.staticCollection;
import my.utils.strUtils;

import java.util.Arrays;
import java.util.Collections;

public class petData {
    /**
     * 获取健骨丹对应的属性
     */
    public static int getMaxPetDanAttr(String key, int lv) {
        String[] attrs = {"bj", "sd", "mz", "max_lan", "max_xue", "ff", "wf", "fg", "wg", "css",};
        int[] nums = {50, 100, 200};
        int type = 0;
        for (int i = 0; i < attrs.length; i++) {
            if (attrs[i].equals(key)) {
                type = i;
                break;
            }
        }
        int[] arr = {6, 3, 5, 67, 67, 4, 4, 8, 8, 2,};
        return arr[type] * nums[lv - 1] * lv;
    }

    public static int getPetDanAttr(int type, int lv) {
        //int[] arr = {6, 11, 15, 67, 67, 4, 4, 8, 8, 2,};
        int[] arr = {6, 3, 5, 67, 67, 4, 4, 8, 8, 2,};
        return arr[type] * lv;
    }

    public static String[] getPetDanAttrKeys() {
        String[] attrs = {"bj", "sd", "mz", "max_lan", "max_xue", "ff", "wf", "fg", "wg", "css",};
        return attrs;
    }

    /**
     * 将一个技能上槽
     */
    public static void addSkill(JSONObject pet, String sklKey) {
        JSONArray sklList = pet.getJSONObject("attr").getJSONArray("skill");
        for (Object s : sklList) {
            JSONObject obj = (JSONObject) s;
            if (obj.getString("key") == null && obj.getInteger("isOpen") == 1) {
                obj.put("key", sklKey);
                obj.put("lv", 1);
                break;
            }
        }
    }

    /**
     * 选出一个未学习的专属技能
     */
    public static String getNoLearnZsSkl(JSONObject pet, String name) {
        String projRootDir = staticCollection.getProjRootDirByName(name);
        JSONObject msg = get(pet.getString("key"), projRootDir);
        JSONArray list = msg.getJSONArray("zsSkls");
        if (list == null) return null;
        Collections.shuffle(list);
        for (Object p : list) {
            //存在没有领悟的专属技能
            if (!isExistSkill((String) p, pet)) {
                return (String) p;
            }
        }
        return null;
    }

    /**
     * 获取专属技能的数量
     */
    public static int getZsSklSize(JSONObject pet, String name) {
        String projRootDir = staticCollection.getProjRootDirByName(name);
        JSONObject msg = get(pet.getString("key"), projRootDir);
        JSONArray list = msg.getJSONArray("zsSkls");
        if (list == null) return 0;
        return list.size();
    }

    /**
     * 获取一个天生技能
     */
    public static String getTsSkl(JSONObject pet, String name) {
        String projRootDir = staticCollection.getProjRootDirByName(name);
        JSONObject msg = get(pet.getString("key"), projRootDir);
        JSONArray list = msg.getJSONArray("zsSkls");
        if (list == null) {
            //当没有天生技能的情况随机给一个技能
            return getNoLearnLwSkl(pet);
        }
        //天生技能就是第一个专属技能
        return list.get(0).toString();
    }

    /**
     * 五个技能位是否已经被占用
     */
    public static boolean isEnoughFive(JSONObject pet) {
        JSONArray sklList = pet.getJSONObject("attr").getJSONArray("skill");
        int sum = 0;
        for (Object s : sklList) {
            JSONObject obj = (JSONObject) s;
            if (obj.getString("key") != null && obj.getInteger("isOpen") == 1) {
                sum++;
            }
        }
        if (sum >= 5) return true;
        return false;
    }

    /**
     * 选出一个未学习的领悟技能
     */
    public static String getNoLearnLwSkl(JSONObject pet) {
        JSONArray list = getSelfLwSkill(pet.getInteger("savvy"));
        Collections.shuffle(list);
        for (Object p : list) {
            if (!isExistSkill((String) p, pet)) {
                return (String) p;
            }
        }
        return null;
    }

    /**
     * 判断专属技能是否领悟完毕
     */
    /*public static boolean isSavvyZsOk(JSONObject pet) {
        //获取可领悟的列表
        JSONObject obj = getSkillList(pet.getString("key"), null);
        JSONArray list = obj.getJSONArray("skl0");
        for (Object l : list) {
            //存在没有领悟的专属技能
            if (!isExistSkill((String) l, pet)) {
                return false;
            }
        }
        return true;
    }*/

    /**
     * 判断是否存在该技能
     */
    private static boolean isExistSkill(String sklKey, JSONObject pet) {
        JSONArray sklList = pet.getJSONObject("attr").getJSONArray("skill");
        for (Object s : sklList) {
            JSONObject obj = (JSONObject) s;
            if (obj.get("key") != null && obj.getString("key").equals(sklKey)) {
                return true;
            }
        }
        return false;
    }

    /**
     * 获取宠物可领悟的技能
     */
    private static JSONArray getSelfLwSkill(int savvy) {
        JSONArray list = new JSONArray();
        //二字
        list.addAll(Arrays.asList(getLwSkillBy2z()));
        if (savvy >= 95) {
            //可领悟四字
            list.addAll(Arrays.asList(getLwSkillBy4z()));
        }
        return list;
    }

    /**
     * 获取可领悟的二字技能
     */
    private static String[] getLwSkillBy2z() {
        String[] list = {
                "100210010210", "100210010211", "100210010212", "100210010213", "100210010214",
                "100210010215", "100210010271", "100210010218", "100210010219", "100210010223",
                "100210010224", "100210010225", "100210010227", "100210010228", "100210010229",
                "100210010230", "100210010233", "100210010234", "100210010235", "100210010237",
                "100210010239", "100210010240", "100210010241", "100210010242", "100210010244",
                "100210010253", "100210010256", "100210010257", "100210010258", "100210010259",
                "100210010260", "100210010261", "100210010262", "100210010263", "100210010264",
        };
        return list;
    }

    /**
     * 获取可领悟的四字技能
     */
    private static String[] getLwSkillBy4z() {
        String[] list = {
                "100210010265", "100210010266", "100210010269", "100210010277", "100210010278",
                "100210010179", "100210010280",
                "100210010282", "100210010283", "100210010284", "100210010287", "100210010288",
                "100210010289", "100210010291", "100210010295", "100210010296", "100210010309",
                "100210010310", "100210010311", "100210010312", "100210010313", "100210010211",

        };
        return list;
    }

    /**
     * 判断是否存在其他宠物的专属技能
     */
    public static boolean isExistElsePetZs(String petKey, String sklKey) {
        String[] petKeys = {
                "1002", "1003", "1010", "1011", "1014",
                "1015", "1017", "1026", "1037", "1038",
                "1077", "1105",
        };
        /*for (String k : petKeys) {
            if (k.equals(petKey)) continue;
            JSONArray list = getZsSkl(k);
            for (Object l : list) {
                if (l.equals(sklKey)) {
                    //出现其他宠物的专属技能
                    return true;
                }
            }
        }*/
        return false;
    }


    /**
     * 根据划分种类获取品质
     * type -1 - 3
     */
    public static int getQuality(int type) {
        int quality;
        if (type == -1 || type == 0 || type == 1) {//-1为精英 0、1为普通怪 3-4品
            if (strUtils.isHappend(0, 100, 0.5f)) {
                quality = 4;
            } else {
                quality = 3;
            }
        } else if (type == 2) {//宝宝1-3
            if (strUtils.isHappend(0, 1000, 0.2f)) {
                quality = 1;
            } else if (strUtils.isHappend(0, 1000, 0.2f)) {
                quality = 2;
            } else {
                quality = 3;
            }
        } else if (type == 3) {//变异 1、2
            if (strUtils.isHappend(0, 1000, 0.5f)) {
                quality = 1;
            } else {
                quality = 2;
            }
        } else {//神宠一定是1品
            quality = 1;
        }
        return quality;
    }

    /**
     * 根据品质生成悟性
     */
    public static int getSavvy(int quality) {
        int min = 100 - quality * 10;
        return strUtils.getRandom(min, min + 11);
    }

    /**
     * 成长率
     */
    public static int getGrow(int quality) {
        if (quality == 1)
            return strUtils.getRandom(1000, 1201);
        else if (quality == 2)
            return strUtils.getRandom(800, 1000);
        else
            return strUtils.getRandom(600, 800);
    }

    /**
     * 获取资质范围
     * r需要包含属性zizhi、quality
     */
    public static JSONObject getRealQualityGround(JSONObject r) {
        JSONObject map = r.getJSONObject("zizhi");
        if (map == null) {
            System.err.println("资质为null/" + r);
        }
        int quality = r.getInteger("quality");
        return getRealQualityGround(map, quality);
    }

    public static JSONObject getRealQualityGround(JSONObject zizhi, int quality) {
        JSONObject res = new JSONObject();
        JSONObject map = zizhi;
        for (String p : map.keySet()) {
            Integer q = map.getInteger(p);
            float min = q * (1 - quality * 0.2f);
            float max = q * (1 - (quality - 1) * 0.2f);
            JSONObject m = new JSONObject();
            m.put("min", min);
            m.put("max", max);
            res.put(p, m);
        }
        return res;
    }

    /**
     * 根据成长等级获取最大资质
     */
    public static JSONObject getRealQualityGround(JSONObject zizhi, int quality, float grow, int growLv) {
        JSONObject groundMap = getRealQualityGround(zizhi, quality);
        for (String k : groundMap.keySet()) {
            JSONObject limit = groundMap.getJSONObject(k);
            int max = limit.getInteger("max");
            int real = (int) (max + (max / 10 * grow / 1000 * (0.8f + 0.1f * growLv)) * growLv / 2.5f);
            limit.put("max", real);
        }
        return groundMap;
    }

    /**
     * 计算现有资质值跟当前成长下的最大资质之间的比例
     */
    public static JSONObject getNowAndMaxZiZhiRate(JSONObject qualityValue, JSONObject groundMap) {
        JSONObject rate = new JSONObject();
        for (String k : groundMap.keySet()) {
            float r = qualityValue.getFloat(k) / groundMap.getJSONObject(k).getFloat("max");
            rate.put(k, r);
        }
        return rate;
    }

    /**
     * 生成最终的资质
     */
    public static JSONObject getFinalQuality(JSONObject goundMap) {
        JSONObject obj = new JSONObject();
        for (String p : goundMap.keySet()) {
            int r = strUtils.getRandom(
                    goundMap.getJSONObject(p).getInteger("min"),
                    goundMap.getJSONObject(p).getInteger("max"));
            obj.put(p, r);
        }
        return obj;
    }

    /**
     * 获取宠物基本信息
     */
    public static JSONObject get(String key, String projRootDir) {
        if (projRootDir.equals("xq2d")) {
            return get2dData(key);
        }
        System.err.println("projRootDir导致无法获取宠物信息：" + projRootDir);
        return null;
    }

    public static JSONObject get2dData(String key) {
        int index = 0;
        try {
            index = Integer.parseInt(key) - 1000;
        } catch (Exception e) {
            System.err.println("get2dData宠物key无法转换成数字：" + key);
            return null;
        }
        pet pet = new pet(key);
        switch (key) {
            case "1000": {
                pet.init("赤翼蝠").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308", "100210010294");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1001": {
                pet.init("狼蛛", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1002": {
                pet.init("棕毛土狼").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1003": {
                pet.init("利爪幼虎").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010304");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1004": {
                pet.init("食尸虫", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1005": {
                pet.init("双头毒蛇", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1006": {
                pet.init("黑衣山贼").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271", "100210010294");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1007": {
                pet.init("焰火虫", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1008": {
                pet.init("异变尸煞").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1009": {
                pet.init("铁钩手").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1010": {
                pet.init("山野顽猴").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1011": {
                pet.init("赤眼霜狼", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1012": {
                pet.init("金仓鼠").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1013": {
                pet.init("苍鹰").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1014": {
                pet.init("赤灵", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1015": {
                pet.init("江鳇鱼").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1016": {
                pet.init("狂暴兽人").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1017": {
                pet.init("草藤妖", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1018": {
                pet.init("轻骑兵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010304");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1019": {
                pet.init("恶犬", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1020": {
                pet.init("大刀兵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010306", "100210010294");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1021": {
                pet.init("崩角牛").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010290");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1022": {
                pet.init("青竹怪", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1023": {
                pet.init("吸血蝙蝠").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300", "100210010294");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1024": {
                pet.init("懒熊").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010290");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1025": {
                pet.init("湛岚犬").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271", "100210010294");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1026": {
                pet.init("树精", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1027": {
                pet.init("食人狼", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1028": {
                pet.init("苍狼").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010276", "100210010294");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1029": {
                pet.init("鹰狮", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010304");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1030": {
                pet.init("蜥蜴", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1031": {
                pet.init("红羽凶鹰", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1032": {
                pet.init("青岩兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1033": {
                pet.init("狩猎者").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1034": {
                pet.init("龙蛟蛟", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1035": {
                pet.init("古牙兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1036": {
                pet.init("斧兵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010306");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1037": {
                pet.init("铁锤兵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010285");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1038": {
                pet.init("铁骑枪兵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1039": {
                pet.init("散仙", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1040": {
                pet.init("幽魂").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010276");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1041": {
                pet.init("泥石兵俑", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010285");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1042": {
                pet.init("盾甲兵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010251");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1043": {
                pet.init("熔骨血尸", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1044": {
                pet.init("开山力士").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010285");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1045": {
                pet.init("恶灵", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1046": {
                pet.init("摄魂使者", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1047": {
                pet.init("山贼哨兵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1048": {
                pet.init("黑煞甲士").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1049": {
                pet.init("赤炎甲虫", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1050": {
                pet.init("积怨行尸").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1051": {
                pet.init("黑风狼").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1052": {
                pet.init("阴魁猴").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1053": {
                pet.init("木精", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1054": {
                pet.init("利爪猛虎").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010304");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1055": {
                pet.init("褐甲蜥蜴", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1056": {
                pet.init("黑寡妇", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1057": {
                pet.init("擎斧恶汉").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1058": {
                pet.init("擎钩先锋").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1059": {
                pet.init("双刀大盗").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1060": {
                pet.init("绿食怪", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1061": {
                pet.init("沙虫", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1062": {
                pet.init("猎命鹫", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1063": {
                pet.init("古炽灵", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1064": {
                pet.init("千年树妖", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1065": {
                pet.init("魔怨雪狼", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1066": {
                pet.init("幼鳞鳇鱼").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1067": {
                pet.init("盘蛟兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1068": {
                pet.init("吸血妖木", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1069": {
                pet.init("叱炎犬", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1070": {
                pet.init("恶浪蛟", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1071": {
                pet.init("荒野僵尸").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1072": {
                pet.init("伴生妖蛇", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1073": {
                pet.init("火帘鹰", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1074": {
                pet.init("紫魂使魔").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1075": {
                pet.init("山越兽人").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1076": {
                pet.init("巨掌黑熊").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010290");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1077": {
                pet.init("破劫半仙", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1078": {
                pet.init("弓骑兵", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010304");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1079": {
                pet.init("冲锋斧手").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010306");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1080": {
                pet.init("蓝魔").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010276");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1081": {
                pet.init("虚魂犬").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1082": {
                pet.init("震岳荒兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010290");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1083": {
                pet.init("紫命玄魄").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1084": {
                pet.init("纳灵竹妖", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1085": {
                pet.init("白首兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010304");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1086": {
                pet.init("藤甲射手").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1087": {
                pet.init("啮齿鼠").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1088": {
                pet.init("狼人战士", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010276");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1089": {
                pet.init("飞廉骑兵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1090": {
                pet.init("大刀护卫").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010306");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1091": {
                pet.init("业火狼人", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1092": {
                pet.init("亡命逃兵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1093": {
                pet.init("飞羽死士", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010285");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1094": {
                pet.init("凶牙血蝠").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1095": {
                pet.init("长毛猛犸", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1096": {
                pet.init("血魄炼尸", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1097": {
                pet.init("吸魄魔蛛", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1098": {
                pet.init("啸冥犬").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1099": {
                pet.init("巨斧死士").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010285");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1100": {
                pet.init("冷血刀客").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1101": {
                pet.init("嗜血狂鹰", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1102": {
                pet.init("丧魂魔将").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010285");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1103": {
                pet.init("幽冥之狼", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1104": {
                pet.init("赤瞳魔俑", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010285");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1105": {
                pet.init("冥府守卫").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010251");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1106": {
                pet.init("阴风豹").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010304");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1107": {
                pet.init("夺命将军").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010285");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1108": {
                pet.init("吸魂木妖", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1109": {
                pet.init("夺魄护卫").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010306");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1110": {
                pet.init("阴火虫", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1111": {
                pet.init("游荡孤魂").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1112": {
                pet.init("青炎妖狼", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1113": {
                pet.init("巨灵守卫").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010306");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1114": {
                pet.init("引路使者", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1115": {
                pet.init("白魔猿").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1116": {
                pet.init("玄魄妖", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1117": {
                pet.init("丧魂魔尸").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1118": {
                pet.init("地狱犬", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1119": {
                pet.init("般涅雏凤", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1120": {
                pet.init("恋尘阴灵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1121": {
                pet.init("毒尸怪").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1122": {
                pet.init("阴阳界灵", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1123": {
                pet.init("幽玄枪客").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1124": {
                pet.init("枯煞木灵", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1125": {
                pet.init("白苍魔狼", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1126": {
                pet.init("奈河守将").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1127": {
                pet.init("厌世花", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1128": {
                pet.init("黑魇兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010290");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1129": {
                pet.init("吞魂兽").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1130": {
                pet.init("阴冥护卫").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1131": {
                pet.init("幽蓝匠魂").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010276");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1132": {
                pet.init("守魂兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1133": {
                pet.init("冥仙", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1134": {
                pet.init("通灵鼠").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1135": {
                pet.init("通玄鳇鱼").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1136": {
                pet.init("天煞老妖").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1137": {
                pet.init("化梦犬").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1138": {
                pet.init("沙化蜥蜴", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }

            case "1139": {
                pet.init("天刀护卫").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010251");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1140": {
                pet.init("破军猿王").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1141": {
                pet.init("苍刑飞骑").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010304");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1142": {
                pet.init("玄影妖灵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1143": {
                pet.init("诛灵天鹰", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1144": {
                pet.init("阴阳玄蛇", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1145": {
                pet.init("暗影妖狼").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1146": {
                pet.init("勾陈古树", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1147": {
                pet.init("龙胆将军").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010306");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1148": {
                pet.init("青莲竹妖", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1149": {
                pet.init("龙血鳇鱼").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1150": {
                pet.init("沧浪妖狼", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010276");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1151": {
                pet.init("翻江藤", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1152": {
                pet.init("镇川巨熊").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010290", "100210010284", "100210010292", "100210010183");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1153": {
                pet.init("赤影妖蝠").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1154": {
                pet.init("盘丝玄蛛", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1155": {
                pet.init("龙爪凶狼").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010276");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1156": {
                pet.init("穿天弩手").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1157": {
                pet.init("荡岳妖熊").autoFightLv().autoAddQualityByKey();
                pet.bindQualityGroundStruct(2533, 1899, 2111, 1688, 2955, 2533, 1474, 1474, 2955, 1072);
                pet.addZsSkls("100210010290", "100210010284", "100210010292", "100210010183");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1158": {
                pet.init("裂地将军").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010306");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1159": {
                pet.init("擎山兽人").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1160": {
                pet.init("混世散仙", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1161": {
                pet.init("玄幽魔匠").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010276");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1162": {
                pet.init("遁甲卫士").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010251");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1163": {
                pet.init("道化枪兵").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1164": {
                pet.init("千幻音蝠").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1165": {
                pet.init("不朽木灵", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1166": {
                pet.init("沧澜兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010304");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1167": {
                pet.init("震天将军").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010306");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1168": {
                pet.init("虎魄将军").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010306");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1169": {
                pet.init("离火蛟", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1170": {
                pet.init("钩玄统领").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1171": {
                pet.init("开荒兽人").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1172": {
                pet.init("七绝斧手").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1173": {
                pet.init("陨星妖灵", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010248");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1174": {
                pet.init("破岩天蛇", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1175": {
                pet.init("追风魔豹").autoFightLv();
                pet.bindQualityGroundStruct(2426, 1985, 2867, 1985, 2646, 2205, 1260, 1540, 2426, 1960);
                pet.addZsSkls("100210010304");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1176": {
                pet.init("霸荒战狼").autoFightLv().autoAddQualityByKey();
                pet.bindQualityGroundStruct(2646, 2205, 3087, 1985, 2426, 1985, 1960, 1540, 2205, 1260);
                pet.addZsSkls("100210010276", "100210010294", "100210010298");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1177": {
                pet.init("狂骨血魔", 1).autoFightLv().autoAddQualityByKey();
                pet.bindQualityGroundStruct(2205, 2205, 1985, 2867, 2205, 2646, 1960, 1260, 2646, 1400);
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1178": {
                pet.init("不灭炽灵", 1).autoFightLv().autoAddQualityByKey();
                pet.bindQualityGroundStruct(2205, 2646, 1985, 3087, 2205, 2648, 1960, 1400, 2205, 1120);
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1179": {
                pet.init("枯魂枪客").autoFightLv().autoAddQualityByKey();
                pet.bindQualityGroundStruct(2867, 1985, 2646, 1985, 2426, 2205, 1400, 1960, 2426, 1400);
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1180": {
                pet.init("噬川虫", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1181": {
                pet.init("流星猎手").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1182": {
                pet.init("穿江巨蜥", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1183": {
                pet.init("洞天鼠").autoFightLv().autoAddQualityByKey();
                pet.bindQualityGroundStruct(2443, 2221, 2665, 1999, 2665, 2443, 1833, 1551, 2443, 1269);
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1184": {
                pet.init("迷幻影狼", 1).autoFightLv();
                pet.bindQualityGroundStruct(1999, 2443, 1999, 2887, 2443, 2887, 1833, 1551, 2221, 1269);
                pet.addZsSkls("100210010303").addZsSkls("100210010322");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1185": {
                pet.init("覆海藤", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1186": {
                pet.init("不死秦俑", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010285");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1187": {
                pet.init("妖焰虫", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1188": {
                pet.init("古皇兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1189": {
                pet.init("风原妖狼", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1190": {
                pet.init("天鹰玄兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1191": {
                pet.init("惊鸿神鹰", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1192": {
                pet.init("太炎巨蜥", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1193": {
                pet.init("破虚兽").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1194": {
                pet.init("震苍兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1195": {
                pet.init("盘龙兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1196": {
                pet.init("射日飞骑").autoFightLv();
                pet.bindQualityGroundStruct(2948, 2268, 2722, 2041, 2722, 2268, 2016, 1152, 2495, 1440);
                pet.addZsSkls("100210010304").addZsSkls("100210010323");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1197": {
                pet.init("斩月铁骑").autoFightLv().autoAddQualityByKey();
                pet.bindQualityGroundStruct(2495, 2268, 3175, 1814, 2722, 2268, 2016, 1152, 2495, 1584);
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1198": {
                pet.init("尸煞妖王").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1199": {
                pet.init("两仪蛟", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1200": {
                pet.init("太乙散仙", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1201": {
                pet.init("真阳火凤", 1).autoFightLv().autoAddQualityByKey();
                pet.bindQualityGroundStruct(2070, 2529, 2300, 2759, 2529, 2989, 1606, 1898, 2300, 1314);
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1202": {
                pet.init("少阳兽").autoFightLv().autoAddQualityByKey();
                pet.bindQualityGroundStruct(2529, 2070, 3219, 2300, 2300, 2759, 1606, 1314, 2300, 1898);
                pet.addZsSkls("100210010271", "100210010294");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1203": {
                pet.init("虚阳古木", 1).autoFightLv();
                pet.bindQualityGroundStruct(2300, 2529, 2070, 2989, 2300, 2759, 2044, 1460, 2529, 1314);
                pet.addZsSkls("100210010299", "100210010294", "100210010292");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1204": {
                pet.init("太阴斧魔").autoFightLv();
                pet.bindQualityGroundStruct(2547, 2084, 3010, 2315, 2778, 2315, 1617, 1470, 3010, 1470);
                pet.addZsSkls("100210010271", "100210010294", "100210010281", "100210010270", "100210010216", "100210010227");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1205": {
                pet.init("玄阴古兽", 1).autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1206": {
                pet.init("化阴魔尸").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010299");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1207": {
                pet.init("天煞统领").autoFightLv().autoAddQualityByKey();
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1208": {
                pet.init("地魔统领").autoFightLv();
                pet.bindQualityGroundStruct(2564, 2098, 3263, 2098, 2797, 2331, 1332, 1628, 2564, 1924);
                pet.addZsSkls("100210010271");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1209": {
                pet.init("乾坤箭俑", 1).autoFightLv();
                pet.addZsSkls("100210010285").addZsSkls("100210010324");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1210": {
                pet.init("道玄赤灵", 1).autoFightLv();
                pet.bindQualityGroundStruct(2347, 2816, 2112, 3285, 2347, 2816, 2086, 1490, 2347, 1192);
                pet.addZsSkls("100210010300");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1211": {
                pet.init("无双刀客").autoFightLv();
                pet.bindQualityGroundStruct(2581, 2112, 3051, 2112, 2816, 2581, 2086, 1639, 2347, 1341);
                pet.addZsSkls("100210010308");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1212": {
                pet.init("兽神统领").autoFightLv();
                pet.bindQualityGroundStruct(3071, 2363, 2599, 2126, 2835, 2599, 1200, 1800, 2835, 1650);
                pet.addZsSkls("100210010306", "100210010294");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1213": {
                pet.init("太虚妖龙", 1).autoFightLv();
                pet.bindQualityGroundStruct(2126, 2599, 2126, 3071, 2363, 2835, 2100, 1500, 2835, 1350);
                pet.addZsSkls("100210010303");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1214": {
                pet.init("劈天霸王").autoFightLv();
                pet.bindQualityGroundStruct(2599, 2126, 3071, 2126, 3071, 2599, 1650, 1500, 3308, 1200);
                pet.addZsSkls("100210010285");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1215": {
                pet.init("剑圣").addFightLv(1);
                pet.bindQualityGroundStruct(2000, 2280, 2600, 1500, 2000, 1700, 1500, 1100, 1400, 1200);
                pet.addZsSkls("100210010178");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1216": {
                pet.init("梦瑶仙子", 1).addFightLv(1);
                pet.bindQualityGroundStruct(1500, 2780, 1570, 2450, 1750, 2100, 1100, 888, 2100, 1550);
                pet.addZsSkls("100210010179");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1217": {
                pet.init("青玄剑灵").addFightLv(1);
                pet.bindQualityGroundStruct(1400, 1600, 1900, 1150, 1530, 1270, 890, 810, 1020, 1130);
                pet.addZsSkls("100210010181");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1218": {
                pet.init("落羽仙子", 1).addFightLv(1);
                pet.bindQualityGroundStruct(1570, 2790, 1570, 2450, 1750, 2100, 1550, 999, 1750, 1220);
                pet.addZsSkls("100210010180");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1219": {
                pet.init("太虚之魂", 1).addFightLv(1);
                pet.bindQualityGroundStruct(1150, 2010, 1150, 1910, 1280, 1530, 890, 810, 1020, 1130);
                pet.addZsSkls("100210010182");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1220": {
                pet.init("玄晶天狐", 1).addFightLv(1);
                pet.bindQualityGroundStruct(2460, 2300, 2100, 3200, 2200, 2800, 1600, 1840, 3000, 1880);
                pet.addZsSkls( "100210010325", "100210010326", "100210010327", "100210010328");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1221": {
                pet.init("逆天魔龙").addFightLv(1);
                pet.bindQualityGroundStruct(2887, 1999, 2221, 1777, 2887, 2665, 1551, 1269, 3331, 1269);
                pet.addZsSkls("100210010188", "100210010189", "100210010190", "100210010183",
                        "100210010293", "100210010295", "100210010311", "100210010277",
                        "100210010296", "100210010284", "100210010239", "100210010241",
                        "100210010262", "100210010223", "100210010242", "100210010230");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1222": {
                pet.init("惑天玄姬").addFightLv(1);
                pet.bindQualityGroundStruct(2550, 2000, 3400, 2200, 3000, 2800, 2200, 1400, 3000, 1700);
                pet.addZsSkls("100210010191", "100210010192", "100210010193", "100210010329");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1223": {
                pet.init("小青娘子", 1).addFightLv(1);
                pet.bindQualityGroundStruct(2800, 2300, 2220, 3500, 2800, 2700, 2200, 2000, 3200, 2300);
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1224": {
                pet.init("九天玄女", 1).addFightLv(1);
                pet.bindQualityGroundStruct(2670, 2220, 2000, 3110, 2000, 2890, 1560, 1840, 2670, 1980);
                pet.addZsSkls("100210010194", "100210010195", "100210010196");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1225": {
                pet.init("龙翔天兵").addFightLv(1);
                pet.bindQualityGroundStruct(2450, 2000, 3110, 2000, 2900, 2000, 1980, 1410, 2450, 1560);
                pet.addZsSkls("100210010185", "100210010186", "100210010187", "100210010184");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1226": {
                pet.init("龙翔帝君", 1).addFightLv(1);
                pet.bindQualityGroundStruct(3050, 2500, 2220, 3900, 2850, 3000, 2200, 1300, 3600, 2800);
                pet.addZsSkls("100210010200", "100210010201", "100210010202", "100210010203", "100210010204");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1227": {
                pet.init("青龙仙童").addFightLv(1);
                pet.bindQualityGroundStruct(2990, 2220, 3910, 2220, 2180, 3310, 2330, 1410, 3780, 2160);
                pet.addZsSkls("100210010205", "100210010206", "100210010207", "100210010208", "100210010209");
                return JSON.parseObject(JSON.toJSONString(pet));
            }
            case "1228": {
                pet.init("幽玄魔俑").addFightLv(1);
                pet.bindQualityGroundStruct(2270, 2280, 1750, 1400, 2280, 2100, 1220, 1000, 2630, 1000);
                pet.addZsSkls("100210010183");
                return JSON.parseObject(JSON.toJSONString(pet));
            }

        }

        System.err.println("找不到对应的宠物" + key);
        return null;
    }



}
