package my.service.fight;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.gameUtils.skillUtils;
import my.model.*;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Vector;

import static my.fightUtils.fightBuffHandUtils.getBuffInStatusType;
import static my.fightUtils.fightUtils.*;
import static my.model.skillItemRuleType.*;
import static my.utils.classUtils.invokeFnByFnName;

public class skillHandle {
    private static skillHandle one;

    public static skillHandle getOne() {
        if (one == null) one = new skillHandle();
        return one;
    }

    /**
     * 回合开始时技能冷却--
     */
    public void cutSkillCool(String id) {
        Vector<skillCool> list = skillCoolMap.get(id);
        Iterator<skillCool> arr = list.iterator();
        while (arr.hasNext()) {
            skillCool c = arr.next();
            c.huihe--;
            if (c.huihe <= 0) {
                arr.remove();
            }
        }
    }

    /**
     * 判断技能是否处于冷却中
     * isAdd=true表示需要将判断的技能加入冷却集合
     */
    public boolean isCool(String id, JSONObject playerOrder, boolean isAdd) {
        String control = playerOrder.getString("control");
        JSONObject s = playerOrder.getJSONObject("skill");
        String sklKey = s.getString("key");
        return isCool(id, control, sklKey, isAdd);
    }

    public boolean isCool(String id, String control, String sklKey, boolean isAdd) {
        Vector<skillCool> list = skillCoolMap.get(id);
        synchronized (list) {
            for (skillCool c : list) {
                if (c.posKey.equals(control) && c.skillKey.equals(sklKey)) {
                    return true;
                }
            }
            if (isAdd) {
                //判断该技能是否需要添加冷却
                skill skl = skillUtils.getInstance().getSkill(sklKey);
                if (skl != null && skl.coolingRule != null) {
                    Integer huihe = null;
                    try {
                        huihe = invokeFnByFnName(skl.coolingRule, "getVal", 1);
                    } catch (Exception e) {
                        throw new RuntimeException(e);
                    }
                    skillCool c = new skillCool(control, sklKey, huihe);
                    list.add(c);
                }
            }
        }
        return false;
    }

    /**
     * 获取玩家、宠物冷却集
     */
    public JSONObject getPlayerCool(String id) {
        JSONObject map = new JSONObject();

        Vector<skillCool> alist = skillCoolMap.get(id);
        JSONObject fightMsg = fightMap.get(id);
        JSONArray rlist = fightMsg.getJSONArray("roleList");
        for (Object rl : rlist) {
            JSONObject r = (JSONObject) rl;
            String name = r.getString("name");
            String posKey = r.getString("posKey");
            if (r.getInteger("type") == 1) {
                //宠物的话就要选出人物站位
                for (Object t : rlist) {
                    JSONObject temp = (JSONObject) t;
                    if (temp.getString("name").equals(name.substring(0, name.length() - 4))) {
                        posKey = temp.getString("posKey");
                        break;
                    }
                }
            }
            if (map.get(posKey) == null) {
                map.put(posKey, new JSONArray());
            }
            for (skillCool a : alist) {
                //将冷却中的技能放入相关站位
                if (a.posKey.equals(r.getString("posKey"))) {
                    map.getJSONArray(posKey).add(a);
                }
            }
        }
        return map;
    }

    /**
     * 是否足够血
     */
    public boolean isEnoughXue(String id, String control, JSONObject s) {
        skill skl = skillUtils.getInstance().getSkill(s.getString("key"));
        if (skl.triggerCondition == null) {
            System.err.println("isEnoughXue出现触发条件为null：" + skl.key);
            return true;
        }
        int lv = s.getInteger("lv");
        float k = 0;
        try {
            k = invokeFnByFnName(skl.triggerCondition, "getHpValue", lv);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        if (k != 0) {
            //按比例扣除血量
            JSONObject controlAttr = getAttrByPosKey(id, control);
            float max_xue = controlAttr.getJSONObject("prop").getFloat("max_xue");
            float xue = controlAttr.getJSONObject("prop").getFloat("xue");
            float sh = max_xue * k;
            if (sh >= xue) {
                return false;
            }
        }
        return true;
    }

    /**
     * 是否足够蓝
     */
    public boolean isEnoughLan(String id, String control, JSONObject s) {
        skill skl = skillUtils.getInstance().getSkill(s.getString("key"));
        if (skl.triggerCondition == null) {
            System.err.println("isEnoughLan出现触发条件为null：" + skl.key);
            return true;
        }
        int lv = s.getInteger("lv");
        float mp = 0;
        try {
            mp = invokeFnByFnName(skl.triggerCondition, "getMpValue", lv);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        buff bf0 = getBuffInStatusType(id, control, ErMengRule);
        if (bf0 != null) {
            //噩梦状态，蓝量消耗增加
            mp = mp * bf0.txRule.getVal(bf0.lever, 0);
        }
        if (mp != 0) {
            JSONObject controlAttr = getAttrByPosKey(id, control);
            float lan = controlAttr.getJSONObject("prop").getFloat("lan");
            if (mp >= lan) return false;
        }
        return true;
    }

    /**
     * 对固定释放技能进行筛选（固定施法）
     */
    public JSONObject getAllowSkillKey(String id, String control, JSONArray list) {
        JSONObject res = new JSONObject();
        //获取携带的技能
        JSONArray skls = getSkills(id, control);
        //检验固定列表的技能是否存在于战斗缓存的技能中
        for (int i = 0; i < list.size(); i++) {
            String k = list.getString(i);
            skill skl = skillUtils.getInstance().getSkill(k);
            //去掉非主动
            if (skl == null || skl.triggerType != 0) {
                list.remove(i);
                i--;
                continue;
            }
            //去掉未学习的
            boolean b = false;
            for (Object o : skls) {
                JSONObject obj = (JSONObject) o;
                if (obj.getString("key").equals(k)) {
                    b = true;
                    break;
                }
            }
            if (!b) {
                list.remove(i);
                i--;
            }
        }
        //判断是否冷却，是否满足释放条件，否则往下延
        for (int i = 0; i < list.size(); i++) {
            String k = list.getString(i);
            if (isCool(id, control, k, false)) {
                list.remove(i);
                i--;
                continue;
            }
            JSONObject a = null;
            for (Object o : skls) {
                JSONObject obj = (JSONObject) o;
                if (obj.getString("key").equals(k)) {
                    a = obj;
                    break;
                }
            }
            //耗蓝、血验证
            if (!isEnoughLan(id, control, a)) {
                list.remove(i);
                i--;
                continue;
            }
            if (!isEnoughXue(id, control, a)) {
                list.remove(i);
                i--;
                continue;
            }
        }
        //最后得到的就是允许释放的
        if (list.size() > 0) {
            JSONObject a = null;
            for (Object o : skls) {
                JSONObject obj = (JSONObject) o;
                if (obj.getString("key").equals(list.getString(0))) {
                    a = obj;
                    break;
                }
            }
            res.put("skl", a);
            res.put("target", autoChooseTargetBySkillItem(id, control, a));
        }
        return res;
    }

    /**
     * 由技能首个item来选出target站位
     */
    private String autoChooseTargetBySkillItem(String id, String control, JSONObject skl) {
        int targetType = getSkillItem(skl.getString("key"), 0).getTarget();
        String target = null;
        if (targetType == 0) target = control;
        else if (targetType == 1) target = getRandomTarget(id, control.substring(0, 1));
        else target = getRandomTarget(id, control.contains("r") ? "l" : "r");
        return target;
    }

    /**
     * 获取自动释放的技能key（智能施法）
     */
    public JSONObject getAllowSkillKey(String id, String control) {
        int huihe = fightMap.get(id).getInteger("huihe");
        //需要根据玩家状态来选取
        JSONObject res = new JSONObject();
        String target = null;
        List<JSONObject> list = new ArrayList<>();
        //获取携带的技能
        JSONArray skls = getSkills(id, control);
        //判断技能是否可选择 可释放状态且是主动
        for (Object o : skls) {
            JSONObject obj = (JSONObject) o;
            if (!obj.containsKey("key")) continue;
            String k = obj.getString("key");
            skill skl = skillUtils.getInstance().getSkill(k);
            //去掉非主动\允许释放的回合大于当前回合
            if (skl == null || skl.triggerType != 0 ||
                    skl.afterHuiheUse > huihe) continue;
            //去掉冷却、蓝不足、血不足
            if (isCool(id, control, k, false) ||
                    !isEnoughLan(id, control, obj) ||
                    !isEnoughXue(id, control, obj)) {
                continue;
            }
            //满足释放条件的先加入
            list.add(obj);
        }

        List<JSONObject> al = new ArrayList<>();

        //是否有场技能（怪物）
        String[] cjArr = {
                "100210010315", "100210010316", "100210010317", "100210010318",
                "100210010320", "100210010321",
        };
        for (int j = 0; j < cjArr.length; j++) {
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                if (a.getString("key").equals(cjArr[j])) {
                    al.add(a);
                    target = autoChooseTargetBySkillItem(id, control, a);
                    break;
                }
            }
        }
        if (target == null) {
            //宠物技能
            String[] petArr = {
                    "100210010188",
            };
            for (int j = 0; j < petArr.length; j++) {
                for (int i = 0; i < list.size(); i++) {
                    JSONObject a = list.get(i);
                    if (a.getString("key").equals(petArr[j])) {
                        al.add(a);
                        target = autoChooseTargetBySkillItem(id, control, a);
                        break;
                    }
                }
            }
        }
        if (target == null) {
            //从技能中找是否有复活技能
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                skillItem item = getSkillItem(a.getString("key"), 0);
                if (item.statusType == FuHuoRule) {
                    //己方是否存在死亡目标
                    target = getOneIsDiePosKey(id, control.substring(0, 1));
                    if (target != null) {
                        al.add(a);
                        break;
                    }
                }
            }
        }
        if (target == null) {
            //从技能中找是否有恢复技能
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                skillItem item = getSkillItem(a.getString("key"), 0);
                if (item.statusType == 0) {
                    skillItemTxRule attackRule = item.getTxRule(AttackRule);
                    //是否为攻击加血
                    if (attackRule == null || !attackRule.paramBool) continue;
                    //己方是否存在低于50%血量的目标
                    target = getOneIsLowXuePosKey(id, control.substring(0, 1));
                    if (target != null) {
                        al.add(a);
                    }
                    break;
                }
            }
        }
        if (target == null) {
            //从技能中找是否有背刺技能
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                skillItem item = getSkillItem(a.getString("key"), 0);
                if (item.statusType == BeiCiRule) {
                    al.add(a);
                    target = autoChooseTargetBySkillItem(id, control, a);
                    break;
                }
            }
        }
        //群攻的优先
        if (target == null) {
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                skill skl = skillUtils.getInstance().getSkill(a.getString("key"));
                if (skl.skillItems.get(0).statusType == AttackRule) {
                    skillItem item = skl.skillItems.get(0);
                    //要求群攻
                    int num = item.getTargetNum(a.getInteger("lv"));
                    skillItemTxRule attackRule = item.getTxRule(AttackRule);
                    //是否为攻击加血
                    if (attackRule == null || attackRule.paramBool || num < 2) continue;
                    //敌方目标数量>1
                    int sum = getNoDieNum(id, control.contains("r") ? "l" : "r");
                    if (sum <= 1) continue;
                    al.add(a);
                    target = autoChooseTargetBySkillItem(id, control, a);
                    break;
                }
            }
        }
        //根据优先级来抉择技能
        if (target == null) {
            //猛 血祭>猛虎纵
            JSONObject a = null;
            if ((a = isExistSkl(list, "100210000006")) != null) {
                //是否存在流血状态
                target = getOneIsInBuffPosKey(id, control.substring(0, 1).equals("r") ? "l" : "r", LiuXueRule);
                if (target != null) {
                    al.add(a);
                }
            }
            if (target == null) {
                if ((a = isExistSkl(list, "100210000002")) != null) {
                    target = (control.substring(0, 1).equals("r") ? "l" : "r") + "0";
                    al.add(a);
                }
            }
            //盾 破甲>挫骨
            if ((a = isExistSkl(list, "100210000013")) != null) {
                target = (control.substring(0, 1).equals("r") ? "l" : "r") + "0";
                al.add(a);
            }
            if (target == null) {
                if ((a = isExistSkl(list, "100210000011")) != null) {
                    target = (control.substring(0, 1).equals("r") ? "l" : "r") + "0";
                    al.add(a);
                }
            }
            //琴 夺魂>荡魔
            if ((a = isExistSkl(list, "100210000019")) != null) {
                //是否存在魔化状态
                target = getOneIsInBuffPosKey(id, control.substring(0, 1).equals("r") ? "l" : "r", MoHuaRule);
                if (target != null) {
                    al.add(a);
                }
            }
            if (target == null) {
                if ((a = isExistSkl(list, "100210000015")) != null) {
                    target = (control.substring(0, 1).equals("r") ? "l" : "r") + "0";
                    al.add(a);
                }
            }
            //音 返魂>天籁>养生>荡魔
            //冥 断脉>影袭
            if ((a = isExistSkl(list, "100210000032")) != null) {
                //是否存在魔化状态
                target = getOneIsInBuffPosKey(id, control.substring(0, 1).equals("r") ? "l" : "r", ZhongDuRule);
                if (target != null) {
                    al.add(a);
                }
            }
            if (target == null) {
                if ((a = isExistSkl(list, "100210000031")) != null) {
                    target = (control.substring(0, 1).equals("r") ? "l" : "r") + "0";
                    al.add(a);
                }
            }
            //刹 淬毒>碎魂

        }
        //todo:判断是否有减伤技能，如果己方不存在该技能的buff则释放
        //判断是否有带诅咒/蛊惑/吸血效果的攻击技能，
        if (target == null) {
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                skill skl = skillUtils.getInstance().getSkill(a.getString("key"));
                if (skl.skillItems.size() > 1 &&
                        skl.skillItems.get(0).statusType == AttackRule &&
                        (skl.skillItems.get(1).statusType == CurseRule ||
                                skl.skillItems.get(1).statusType == GuRule ||
                                skl.skillItems.get(1).statusType == XiXueRule)) {
                    skillItem item = skl.skillItems.get(0);
                    skillItemTxRule attackRule = item.getTxRule(AttackRule);
                    //是否为攻击加血
                    if (attackRule == null || attackRule.paramBool) continue;
                    al.add(a);
                    target = autoChooseTargetBySkillItem(id, control, a);
                    break;
                }
            }
        }


        //给一个非加血的攻击技能
        if (target == null) {
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                skillItem item = getSkillItem(a.getString("key"), 0);
                if (item.statusType == 0) {
                    skillItemTxRule attackRule = item.getTxRule(AttackRule);
                    //是否为攻击加血
                    if (attackRule == null || attackRule.paramBool) continue;
                    al.add(a);
                    target = autoChooseTargetBySkillItem(id, control, a);
                    break;
                }
            }
        }

        if (al.size() > 0) {
            res.put("skl", al.get(0));
            res.put("target", target);
        }
        return res;
    }

    /**
     * 是否存在某个技能
     */
    private JSONObject isExistSkl(List<JSONObject> list, String key) {
        for (int i = 0; i < list.size(); i++) {
            JSONObject a = list.get(i);
            if (a.getString("key").equals(key)) return a;
        }
        return null;
    }

    /**
     * 允许自动释放的技能
     */
    private boolean isAllowedSkill(String key) {
        String[] arr = {
                "100210000002", "100210000013", "100210000018", "100210000021",
                "100210000029", "100210000035", "100210000040", "100210000042",
                "100210000044",
                //宠物部分
                "100210010178", "100210010179", "100210010180", "100210010181",
                "100210010182", "100210010211", "100210010212", "100210010213",
                "100210010240",

        };
        for (int p = 0; p < arr.length; p++) {
            if (arr[p].equals(key)) return true;
        }
        return false;
    }
}
