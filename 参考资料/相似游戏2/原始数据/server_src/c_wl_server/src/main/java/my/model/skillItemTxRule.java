package my.model;

import com.alibaba.fastjson2.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static my.model.skillItemRuleType.AttrChangeRule;

/**
 * buff相关的规则
 */
public class skillItemTxRule extends skillItemRule {
    public static skillItemTxRule createAttackRule(boolean isAddHp, float k0, float b0, float k1, float b1) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 0;
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k0, b0, 1));
        rule.valList.add(new val(k1, b1, 0));
        //得到攻击后是否转加血（决定走伤害逻辑，还是走伤害逻辑）
        rule.paramBool = isAddHp;
        return rule;
    }

    public static skillItemTxRule createGainRule(String attrName, float k, float b, int valueType) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 1;
        //攻击伤害 attackHurt，受伤 sufferHurt，攻击治疗 attackCure，受治疗 sufferCure
        rule.paramStr = attrName;
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, valueType));
        return rule;
    }

    public static skillItemTxRule createCurseRule(String attrName, float k, float b, int valueType) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 2;
        rule.paramStr = attrName;
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, valueType));
        return rule;
    }

    public static skillItemTxRule createGuRule(int type, float k0, float b0, float k1, float b1) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 3;
        //蛊类型 定身（不能行动）、昏睡（不能行动，受到攻击时解除）、混乱（随机攻击，50%伤害，转向普攻）
        rule.paramInt = type;
        rule.valList = new ArrayList<>();
        //决定效果持续的回合数
        rule.valList.add(new val(k0, b0, 0));
        boolean isRemove = false;
        if (type != 2) {
            if (type == 1) {
                isRemove = true;
            }
            rule.paramBool = isRemove;
        } else {
            //决定普攻的百分比
            rule.valList.add(new val(k1, b1, 1));
        }
        return rule;
    }

    public static skillItemTxRule createLiuXueRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 4;
        //按伤害的一定比例扣血
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    public static skillItemTxRule createHuiXueRule(float k, float b, int sumHurtOrMaxXue) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 5;
        //0按伤害的百分比来计算 1按最大生命的百分比来计算
        rule.paramInt = sumHurtOrMaxXue;
        //按生命的一定比例回血
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }


    public static skillItemTxRule createXiXueRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 6;
        //按伤害的一定比例吸血
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    public static skillItemTxRule createFanZhenRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 7;
        //按伤害的一定比例反伤对方
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    public static skillItemTxRule createBeiCiRule(float k, float b, int targetType, boolean isAddXue) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 8;
        //转移的目标类型，己方或者敌方
        rule.paramInt = targetType;
        //是否转加血
        rule.paramBool = isAddXue;
        //将伤害按一定比例转移（自身不受伤）
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    /**
     * 一些空的状态，如魔化、休息等
     */
    public static skillItemTxRule createEmptyRule(int ruleType) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = ruleType;
        return rule;
    }

    public static skillItemTxRule createZhongDuRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 10;
        //将伤害按一定比例流血
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    /**
     * 解除某些buff
     */
    public static skillItemTxRule createRemoveRule(Integer... statusTypes) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 12;
        //需要移除的buff的状态值集合
        rule.paramIntList = new ArrayList<>();
        rule.paramIntList.addAll(Arrays.asList(statusTypes));
        return rule;
    }

    public static skillItemTxRule createFuHuoRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 13;
        //复活后恢复一定血量
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    public static skillItemTxRule createHuiLanRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 14;
        //恢复一定比例蓝量
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    /**
     * 免疫某些buff
     */
    public static skillItemTxRule createImmuneBuffRule(Integer... statusTypes) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 15;
        //需要移除的buff的状态值集合
        rule.paramIntList = new ArrayList<>();
        rule.paramIntList.addAll(Arrays.asList(statusTypes));
        return rule;
    }

    public boolean isImmune(int nowStatus) {
        for (int status : this.paramIntList) {
            if (status == nowStatus) {
                return true;
            }
        }
        return false;
    }

    /**
     * k0消耗上限比例 没有则为0
     * k1转化比例
     */
    public static skillItemTxRule createAttrChangeRule(String attrName, float k0, float k1, List<String> attrNameList) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = AttrChangeRule;
        //某属性转化成其他属性 如生命转物攻
        rule.paramStr = attrName;
        rule.paramStrList = attrNameList;
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k0, 0, 1));
        rule.valList.add(new val(k1, 0, 1));
        return rule;
    }

    public static skillItemTxRule createZhanShaRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 17;
        //低于一定血量的比例则斩杀
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    public static skillItemTxRule createBjKChange(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 18;
        //暴击系数调整
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    public static skillItemTxRule createTouXueRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 19;
        //按一定比例偷血
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    public static skillItemTxRule createHuanXueRule(float k, float b, boolean isCutSelf, boolean isFoe, boolean isAll) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 20;
        rule.paramBool = isCutSelf;
        rule.paramBoolList = new ArrayList<>();
        rule.paramBoolList.add(isFoe);//是否为敌方
        rule.paramBoolList.add(isAll);//目标是否为所有
        //按一定比例换血（双方都扣血）
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    public static skillItemTxRule createCutXueRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 21;
        //按一定比例减血血（如连斩等）
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    /**
     * 伤害扩大倍数
     */
    public static skillItemTxRule createHurtUpRule(int targetStatusType, float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 22;
        //目标处于某种状态下，攻击扩大倍数
        rule.paramInt = targetStatusType;//不需要目标处于某状态时设为-1即可
        //伤害扩大倍数
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    /**
     * 攻击提升
     */
    public static skillItemTxRule createAttackUpRule(int targetStatusType, float k0, float b0, float k1, float b1, String wgOrFg) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 23;
        //目标处于某种状态下，攻击扩大倍数
        rule.paramInt = targetStatusType;//不需要目标处于某状态时设为-1即可
        rule.paramStr = wgOrFg;
        rule.paramBool = false;//非加血
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k0, b0, 1));
        rule.valList.add(new val(k1, b1, 0));
        return rule;
    }

    public static skillItemTxRule createIgnoreRule(JSONObject map) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 25;
        //忽略某些属性 map{key=属性名 value=忽略的比例}
        rule.paramJObj = map;
        return rule;
    }

    public static skillItemTxRule createCutLanRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 26;
        //按比例减蓝
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    public static skillItemTxRule createErMengRule(float k, float b) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 27;
        //蓝量扣除增加
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, 1));
        return rule;
    }

    public static skillItemTxRule createBackRule(List<Integer> statusTypeList) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 28;
        //反弹效果
        rule.paramIntList = statusTypeList;
        return rule;
    }

    public static skillItemTxRule createDiDangRule(float k0, float k1, boolean isBuilderRev) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 29;
        //抵挡伤害
        //true为技能释放者进行承受 / false为空站位承受
        rule.paramBool = isBuilderRev;
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k0, 0, 1));//a方遭受该伤害的k值
        rule.valList.add(new val(k1, 0, 1));//b方遭受该伤害的k值
        return rule;
    }

    public static skillItemTxRule createMianShangRule(String attrName, int times, float k) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 30;
        //低于某个属性多少倍时免伤
        rule.paramStr = attrName;//不设置该属性时直接按次数减免
        //减免k伤害，times次
        rule.paramInt = times;
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, 0, 1));
        return rule;
    }

    public static skillItemTxRule createNoDieRule(float k, float b, int valueType, int times) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 34;
        //times次不死，保留1血或者百分比的血量
        rule.paramInt = times;
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, b, valueType));
        return rule;
    }

    public static skillItemTxRule createLianJiRule(List<Float> hurtKList, boolean isUserSkill, int times) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 36;
        //连击，每次伤害的递减，是否使用技能，连击次数
        rule.paramBool = isUserSkill;
        rule.paramInt = times;
        rule.valList = new ArrayList<>();
        for (int i = 0; i < hurtKList.size(); i++) {
            rule.valList.add(new val(hurtKList.get(i), 0, 1));
        }
        return rule;
    }

    public static skillItemTxRule createWuDiRule(float k, int times, int huihe) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 46;
        //是否已经生效过了
        rule.paramBool = false;
        //times次或一定回合内不受伤害，并增加一定比例的攻击
        rule.paramIntList = new ArrayList<>();
        rule.paramIntList.add(times);
        rule.paramIntList.add(huihe);
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(k, 0, 1));
        return rule;
    }

    public static skillItemTxRule createRateRule(String attrName, float rate, float xueK) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 50;
        //增加/减少几率（如暴击）
        rule.paramStr = attrName;
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(rate, 0, 1));
        //低于多少血量时才参与计算（不需要低于多少血量的条件时则不用理会）
        rule.valList.add(new val(0, xueK, 1));
        return rule;
    }

    public static skillItemTxRule createAddOrCutAttrRule(String attrName, float rate) {
        skillItemTxRule rule = new skillItemTxRule();
        rule.ruleType = 51;
        //增加/减少某个属性
        rule.paramStr = attrName;
        rule.valList = new ArrayList<>();
        rule.valList.add(new val(rate, 0, 1));
        return rule;
    }

}
