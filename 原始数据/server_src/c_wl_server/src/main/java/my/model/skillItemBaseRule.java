package my.model;

import java.util.ArrayList;

/**
 * 这里适配基本的几个规则
 * skillItem里面用一个数组来存储skillItemBaseRule，每增加一个新规则旧存放一个
 */
public class skillItemBaseRule extends skillItemRule {

    //-1目标规则 -2效果规则 -3触发的概率规则 -4叠加规则 -5条件规则

    public static skillItemBaseRule createTargetRule(int target, float k, float b, int targetMaxNum, int targetChoose) {
        skillItemBaseRule rule = new skillItemBaseRule();
        rule.ruleType = -1;
        rule.valList = new ArrayList<>();
        //目标对象 0自己、1己方、2敌方、3目标控制方所操控的主角站位
        rule.valList.add(new val(0, target, 0));
        //目标数量规则 0-6
        rule.valList.add(new val(k, b, 0));
        //目标最大数量限制
        rule.valList.add(new val(0, targetMaxNum, 0));
        //0不随机 1随机 2同一排 3同一列
        rule.valList.add(new val(0, targetChoose, 0));
        return rule;
    }

    public int getTarget() {
        return (int) getVal(1, 0);
    }

    public int getTargetChoose() {
        return (int) getVal(1, 3);
    }

    public int getTargetNum(int lv) {
        int n = (int) getVal(lv, 1);
        int max = (int) getVal(lv, 2);
        if (n > max) n = max;
        return n;
    }

    public static skillItemBaseRule createEffectRule(int huihe, int times) {
        return createEffectRule(huihe, times, -1);
    }

    public static skillItemBaseRule createEffectRule(int huihe, int times, int efCoolHuihe) {
        skillItemBaseRule rule = new skillItemBaseRule();
        rule.ruleType = -2;
        rule.valList = new ArrayList<>();
        //有效回合
        rule.valList.add(new val(0, huihe, 0));
        //有效次数
        rule.valList.add(new val(0, times, 0));
        //效果冷却规则
        rule.valList.add(new val(0, efCoolHuihe, 0));
        return rule;
    }

    public float getHuihe(int lv) {
        return getVal(lv, 0);
    }

    public float getTimes(int lv) {
        return getVal(lv, 1);
    }

    public float getEfCoolHuihe(int lv) {
        return getVal(lv, 2);
    }

    public static skillItemBaseRule createProbabilityRule(float k0, float b0, float k1, float b1) {
        skillItemBaseRule rule = new skillItemBaseRule();
        rule.ruleType = -3;
        rule.valList = new ArrayList<>();
        //创建buff的概率
        rule.valList.add(new val(k0, b0, 1));
        rule.valList.add(new val(k1, b1, 1));
        return rule;
    }

    public float getCreateBuffProbability(int lv) {
        float p = getVal(lv, 0);
        if (p - 1 > 0) return 1f;
        return p;
    }

    public float getTriggerBuffProbability(int lv) {
        float p = getVal(lv, 1);
        if (p - 1 > 0) return 1f;
        return p;
    }
    public static skillItemBaseRule createAddRule(int maxAddNum){
        return  createAddRule(maxAddNum,1);
    }
    public static skillItemBaseRule createAddRule(int maxAddNum,int initAddNum) {
        skillItemBaseRule rule = new skillItemBaseRule();
        rule.ruleType = -4;
        //设置初始叠加层数
        rule.paramIntList=new ArrayList<>();
        rule.paramIntList.add(initAddNum);
        //最大叠加数
        rule.paramInt = maxAddNum;
        return rule;
    }

    public int getMaxAddNum() {
        return this.paramInt;
    }

    public static skillItemBaseRule createConditionRule(int statusType) {
        return createConditionRule(statusType, -1);
    }

    public static skillItemBaseRule createConditionRule(int statusType, float xueK) {
        skillItemBaseRule rule = new skillItemBaseRule();
        rule.ruleType = -5;
        //需要处于某种状态 不用就设置为-1
        rule.paramInt = statusType;
        rule.valList = new ArrayList<>();
        //低于多少血量，不用就设置为-1
        rule.valList.add(new val(0, xueK, 1));
        return rule;
    }
}
