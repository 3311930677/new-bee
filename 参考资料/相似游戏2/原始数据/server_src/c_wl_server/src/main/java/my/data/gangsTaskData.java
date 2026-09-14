package my.data;

import com.alibaba.fastjson2.JSONObject;
import my.utils.strUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * 帮派任务
 */
public class gangsTaskData {
    public static List<JSONObject> createBpdzzTask() {
        //从任务数据集中挑60个
        List<JSONObject> list = getTasks();
        list.addAll(new ArrayList<>(list));
        Collections.shuffle(list);
        if (list.size() < 60) return list;
        list=list.subList(0, 60);
        for(int i=0;i<list.size();i++){
            list.get(i).put("Id", strUtils.getId());
        }
        return list;
    }
    /**随机取一个*/
    public static JSONObject getRandomTask() {
        List<JSONObject> list = getTasks();
        Collections.shuffle(list);
        JSONObject a=list.subList(0, 1).get(0);
        a.put("Id", strUtils.getId());
        return a;
    }

    public static JSONObject getTaskByKey(String key) {
        List<JSONObject> list = getTasks();
        for (JSONObject l : list) {
            if (key.equals(l.getString("key"))) {
                return l;
            }
        }
        return null;
    }

    /**
     * 将将怪物key转换成大作战对应任务key
     */
    public static String monsterKeyToDzzKey(String monsterKey) {
        switch (monsterKey) {
            case "1071":
                return "a15";

        }
        return null;
    }

    /**
     * 将任务key转换成大作战对应任务key
     */
    public static String taskKeyToDzzKey(String taskKey) {
        int i = Integer.parseInt(taskKey);
        if (i >= 3100 && i <= 3110) {
            return "a19";
        }
        switch (taskKey) {
            case "3004":
                return "a21";
            case "3009":
                return "a22";
            case "3014":
                return "a23";
            case "3019":
                return "a24";
            case "3039":
                return "a25";
            case "3053":
                return "a1";
            case "3057":
                return "a26";
            case "3074":
                return "a2";
            case "3078":
                return "a3";
            case "3081":
                return "a4";
            case "3085":
                return "a5";
            case "3089":
                return "a6";
            case "3093":
                return "a7";
        }
        return null;
    }

    public static List<JSONObject> getTasks() {
        List<JSONObject> list = new ArrayList<>();
        list.add(getObj("a1", 5, 10000, "普通副本", "60副本完成2次", 0, "fb60", 2));
        list.add(getObj("a2", 5, 20000, "普通副本", "70副本完成2次", 0, "fb70", 2));
        list.add(getObj("a3", 5, 30000, "普通副本", "80副本完成2次", 0, "fb80", 2));
        list.add(getObj("a4", 5, 40000, "普通副本", "90副本完成2次", 0, "fb90", 2));
        list.add(getObj("a5", 5, 50000, "普通副本", "100副本完成2次", 0, "fb100", 2));
        list.add(getObj("a6", 5, 60000, "精英副本", "三国副本完成2次", 0, "fbls", 2));
        list.add(getObj("a7", 5, 70000, "精英副本", "洪荒副本完成2次", 0, "fbhh", 2));
        //list.add(getObj("a8",120,"精英副本","妖兽副本完成2次",0,"fbys",2));
        //list.add(getObj("a9",150,"精英副本","诛仙副本完成2次",0,"fbzx",2));
        list.add(getObj("a10", 5, 10000, "排位", "排位胜利20次", 1, "pw", 20));
        list.add(getObj("a11", 5, 10000, "竞技", "个人竞技胜利16次", 1, "jj", 16));
        list.add(getObj("a12", 10, 50000, "寻宝", "珠光宝器法宝搜寻10次", 2, "fb", 10));
        list.add(getObj("a13", 10, 50000, "寻宝", "珠光宝器技能搜寻10次", 2, "jn", 10));
        list.add(getObj("a14", 10, 50000, "寻宝", "珠光宝器装备搜寻10次", 2, "zb", 10));
        list.add(getObj("a15", 5, 20000, "收集", "击败300只腾蛇玄武", 3, "1071", 300));
        list.add(getObj("a16", 5, 10000, "比赛", "宠物论贱胜利一次（官办）", 4, "lj", 1));
        list.add(getObj("a17", 5, 10000, "比赛", "武状元大赛胜利一次（官办）", 4, "wzy", 1));
        list.add(getObj("a18", 5, 10000, "boss", "世界boss伤害超过10000", 5, "boss", 1));
        list.add(getObj("a19", 5, 10000, "门派", "职业跑环完成20次", 6, "mpph", 20));
        //list.add(getObj("a20", 50, "帮派", "帮派任务完成20次", 7, "bpph", 20));
        list.add(getObj("a21", 5, 20000, "宠物修炼", "完成修罗之狱5", 8, "xl5", 1));
        list.add(getObj("a22", 5, 40000, "宠物修炼", "完成修罗之狱5(精)", 8, "xl5j", 1));
        list.add(getObj("a23", 5, 20000, "宠物修炼", "完成混沌之狱5", 8, "hd5", 1));
        list.add(getObj("a24", 5, 40000, "宠物修炼", "完成混沌之狱5(精)", 8, "hd5j", 1));
        list.add(getObj("a25", 5, 20000, "天渊", "完成天渊20层", 9, "ty", 1));
        list.add(getObj("a26", 5, 10000, "宝库", "完成1次洪荒宝库", 10, "bk", 1));
        list.add(getObj("a27", 5, 10000, "传壁", "传橙壁2次", 11, "cb", 2));
        list.add(getObj("a28", 10, 10000, "召唤", "使用龙蛇姬女兵帝童召唤道具", 12, "zh", 1));
        list.add(getObj("a29", 10, 10000, "合成", "合成1颗紫云丹", 13, "hc", 1));
        list.add(getObj("a30", 10, 10000, "成长", "使用1颗淬体丹", 14, "cz", 1));
        list.add(getObj("a31", 10, 10000, "道具", "使用1个技能宝匣", 15, "jn", 1));
        list.add(getObj("a32", 10, 10000, "道具", "使用1个仙绝宝匣", 15, "xj", 1));
        list.add(getObj("a33", 10, 10000, "道具", "使用1个宠物礼袋", 15, "ld", 1));
        return list;
    }

    public static JSONObject getObj(String key, int jf, int exp, String name, String des,
                                    int type, String targetKey, int sum) {
        JSONObject obj = new JSONObject();
        obj.put("key", key);
        obj.put("jf", jf);
        obj.put("exp", exp);
        obj.put("name", name);
        obj.put("des", des);
        JSONObject target = getTargetObj(type, targetKey, sum);
        obj.put("target", target);
        //个人信息
        JSONObject person = new JSONObject();
        person.put("name", null);
        person.put("status", 0);
        person.put("num", 0);
        obj.put("person", person);
        return obj;
    }

    public static JSONObject getTargetObj(int type, String targetKey, int sum) {
        JSONObject obj = new JSONObject();
        obj.put("type", type);
        obj.put("targetKey", targetKey);
        obj.put("sum", sum);
        return obj;
    }
}
