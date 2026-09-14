package my.model;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Vector;

import static my.utils.classUtils.getFieldValueByFieldName;

/**
 * 技能点（每一个技能点都是一个buff）
 */
public class skillItem {
    //一个用于传递的缓存对象（比如低血量时需要通过这个来获取血量百分比）
    public Object temp;
    //状态类型，具体值看skillItemTxRule
    public int statusType;
    //基本规则（如触发概率、目标数等）
    public List<skillItemBaseRule> baseRuleList;
    //buff相关规则
    public List<skillItemTxRule> txRuleList;
    //buff创建时机 skillItemCreateMoment
    public int createBuffMoment;
    //buff触发时机 skillItemTriggerMoment
    public int triggerBuffMoment;

    public skillItem(Integer statusType) {
        this.statusType = statusType;
    }

    public skillItem addCreateMoment(int createBuffMoment) {
        this.createBuffMoment = createBuffMoment;
        return this;
    }

    public skillItem addTriggerMoment(int triggerBuffMoment) {
        this.triggerBuffMoment = triggerBuffMoment;
        return this;
    }

    /*public skillItem addBaseRule(skillItemBaseRule rule) {
        if (baseRuleList == null) baseRuleList = new ArrayList<>();
        baseRuleList.add(rule);
        return this;
    }*/

    public skillItem addBaseRules(skillItemBaseRule... rules) {
        if (baseRuleList == null) baseRuleList = new ArrayList<>();
        baseRuleList.addAll(Arrays.asList(rules));
        return this;
    }

    /**
     * 基本规则点是不会出现多个相同的ruleType，所以返回一个即可
     * -1目标规则 -2效果规则 -3触发的概率规则 -4叠加规则
     */
    public skillItemBaseRule getBaseRule(int ruleType) {
        for (int i = 0; i < baseRuleList.size(); i++) {
            skillItemBaseRule rule = baseRuleList.get(i);
            if (rule.ruleType == ruleType) return rule;
        }
        return null;
    }

    public int getHuihe(int lv) {
        skillItemBaseRule rule = getBaseRule(-2);
        return (int) rule.getHuihe(lv);
    }

    public int getTimes(int lv) {
        skillItemBaseRule rule = getBaseRule(-2);
        return (int) rule.getTimes(lv);
    }

    public int getEfCoolHuihe(int lv) {
        skillItemBaseRule rule = getBaseRule(-2);
        return (int) rule.getEfCoolHuihe(lv);
    }

    /**
     * 要求处于某状态时buff才生效
     */
    public skillItemBaseRule getCondition() {
        skillItemBaseRule rule = getBaseRule(-5);
        return rule;
    }

    public int getMaxAddNum() {
        skillItemBaseRule rule = getBaseRule(-4);
        return rule.paramInt;
    }

    public int getInitAddNum() {
        skillItemBaseRule rule = getBaseRule(-4);
        return rule.paramIntList.get(0);
    }

    public float getCreateBuffProbability(int lv) {
        skillItemBaseRule rule = getBaseRule(-3);
        return rule.getCreateBuffProbability(lv);
    }

    public float getTriggerBuffProbability(int lv) {
        skillItemBaseRule rule = getBaseRule(-3);
        return rule.getTriggerBuffProbability(lv);
    }

    public int getTargetNum(int lv) {
        skillItemBaseRule rule = getBaseRule(-1);
        return rule.getTargetNum(lv);
    }

    public int getTargetChoose() {
        skillItemBaseRule rule = getBaseRule(-1);
        return rule.getTargetChoose();
    }

    public int getTarget() {
        skillItemBaseRule rule = getBaseRule(-1);
        return rule.getTarget();
    }

    /**
     * 只允许有一个
     */
    public skillItem addTxRule(skillItemTxRule... rules) {
        if (txRuleList == null) txRuleList = new ArrayList<>();
        txRuleList.addAll(Arrays.asList(rules));
        return this;
    }

    public skillItemTxRule getTxRule(int ruleType) {
        for (int i = 0; i < txRuleList.size(); i++) {
            skillItemTxRule rule = txRuleList.get(i);
            if (rule.ruleType == ruleType) return rule;
        }
        return null;
    }

    /**
     * 判断技能点是否存在某些状态
     */
    public static skillItem isExistSkillItem(Vector<skillItem> list, int statusType) {
        for (int i = 0; i < list.size(); i++) {
            if (list.get(i).statusType == statusType) return list.get(i);
        }
        return null;
    }

    /**
     * 获取内部属性
     * 针对不能给外部读取的内部类属性
     */
    /*public JSONObject getPropByName(String propName) throws Exception {
        Object obj = getFieldValueByFieldName(propName, this);
        return JSON.parseObject(JSON.toJSONString(obj));
    }*/
}

