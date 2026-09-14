package my.model;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;

import java.util.List;
import java.util.Vector;

/**
 * 技能
 * 一个技能由多个buff组成
 */
public class skill {
    public String key;
    //0门派1天2地3人4宠物专属5宠物普通6经脉 7装备技能 8武将技能 9生活技能
    public int type;
    //职业
    public String job = "*";
    //需要达到的最低悟性
    public int savvy = 80;
    //可学习的最大等级
    public int maxLv = 1;
    //是否允许闪躲
    public int isAllowedSD;
    //0主动、1被动(默认)  释放技能时需要验证
    public int triggerType;
    //发动的前提条件(消耗mp、hp，不够时转普攻)
    public triggerCondition triggerCondition;
    //冷却规则
    public coolingRule coolingRule;
    //绑定的buff
    public Vector<skillItem> skillItems;
    //学习后对属性的提升
    public learnResultRule learnResultRule;
    //在某个回合之后才允许释放（怪物技能选择时使用）
    public int afterHuiheUse=0;
    //在某回合之后才允许创建
    public int afterHuiheCreate=0;

    public skill(String key) {
        this.key = key;
        this.isAllowedSD = 1;
        this.triggerType = 1;
    }

    public skill addMaxLv(int max) {
        this.maxLv = max;
        return this;
    }

    public skillItem getSkillItemByStatusType(int statusType) {
        for (int i = 0; i < this.skillItems.size(); i++) {
            if (this.skillItems.get(i).statusType == statusType)
                return this.skillItems.get(i);
        }
        return null;
    }

    public skill addSavvy(int savvy) {
        this.savvy = savvy;
        return this;
    }

    public skill bindSkillData(int type, String job) {
        this.type = type;
        this.job = job;
        return this;
    }

    public JSONArray getAttrs() {
        if (this.learnResultRule == null) {
            return new JSONArray();
            //System.err.println("技能learnResultRule=null => " + this.key);
        }
        return this.learnResultRule.attrs;
    }

    /**
     * 计算方式
     * 0线性 1n项和
     */
    public int countWay = 0;

    public skill putCountWay(int countWay) {
        this.countWay = countWay;
        return this;
    }

    public skill putLearnResultRule(String name, float k, float b, int valueType) {
        if (this.learnResultRule == null || this.learnResultRule.attrs == null) {
            this.learnResultRule = new learnResultRule(new JSONArray());
        }
        JSONObject o = new JSONObject();
        o.put("name", name);
        o.put("k", k);
        o.put("b", b);
        o.put("valueType", valueType);//0固定值1原值的倍数
        JSONArray list = this.learnResultRule.attrs;
        list.add(o);
        return this;
    }

    //mp,hp
    public skill bindTriggerCondition(Float k0, Float b0, Integer mpValueType,
                                      Float k1, Float b1, Integer hpValueType) {
        this.triggerCondition = new triggerCondition(k0, b0, mpValueType,
                k1, b1, hpValueType);
        return this;
    }

    //冷却回合
    public skill bindCoolingRule(Float k, Float b) {
        this.coolingRule = new coolingRule(k, b);
        return this;
    }

}

class learnResultRule {
    //属性名数组{name, k, b, valueType}
    public JSONArray attrs;

    public learnResultRule(JSONArray attrs) {
        this.attrs = attrs;
    }

    public JSONObject getResult(int lv) {
        //如杀气决，固定力量的基础数是36，耐力12，
        //每个技能的b、k是固定的，只有lv能改变
        JSONObject res = new JSONObject();
        for (Object o : this.attrs) {
            JSONObject obj = (JSONObject) o;
            res.put(obj.getString("name"),
                    obj.getFloat("b") + obj.getFloat("k") * lv);
        }


        return res;
    }

    public int count(int lv, JSONObject obj) {
        return (int) (obj.getFloat("b") + obj.getFloat("k") * lv);
    }

    public int countByK(int lv, JSONObject obj, JSONObject attr) {
        float k = obj.getFloat("k") * lv + obj.getFloat("b");
        float value = attr.getFloat(obj.getString("name")) * k;
        return (int) (value);
    }
}

class triggerCondition {
    public fixedRule mp;
    public fixedRule hp;

    public triggerCondition(Float k0, Float b0, Integer mpValueType,
                            Float k1, Float b1, Integer hpValueType) {
        this.mp = new fixedRule(k0, b0, mpValueType);
        this.hp = new fixedRule(k1, b1, hpValueType);
    }

    public Float getMpValue(Integer lv) {
        return this.mp.k * lv + this.mp.b;
    }

    public Float getHpValue(Integer lv) {
        return this.hp.k * lv + this.hp.b;
    }

}

class coolingRule extends fixedRule {

    public coolingRule(Float k, Float b) {
        super(k, b, 0);
    }

    public Integer getVal(Integer lv) {
        return (int) (k * lv + b);
    }
}


