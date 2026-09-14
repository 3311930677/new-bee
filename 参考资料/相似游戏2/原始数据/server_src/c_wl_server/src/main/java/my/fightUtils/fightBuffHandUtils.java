package my.fightUtils;


import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.gameUtils.skillUtils;
import my.model.*;
import my.utils.staticCollection;
import my.utils.strUtils;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Vector;

import static my.fightUtils.fightUtils.*;
import static my.model.skillItemTriggerMoment.isEachAttackerTriggre;
import static my.utils.classUtils.invokeFnByFnName;


/**
 * 对技能、技能点处理
 */
public class fightBuffHandUtils {
    /**
     * 是否使用过该主动技能
     */
    public static boolean isUsedZhuDongSkill(String id, String target, String sklKey) {
        Vector<buff> buffs = buffMap.get(id);
        synchronized (buffs) {
            for (buff b : buffs) {
                if (b.target.equals(target) && b.key.equals(sklKey)) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * 进行回合数更新，并移除无效的buff
     */
    public static void updateBuffHuihe(String id) {
        Vector<buff> vs = buffMap.get(id);
        synchronized (vs) {
            Iterator<buff> its = vs.iterator();
            while (its.hasNext()) {
                buff b = its.next();
                //判断buff是否有效
                if (b.isNoEffect() || isCatch(id, b.target)
                        || isTao(id, b.target) ) {
                    //被抓捕、逃跑的就移除
                    its.remove();
                    continue;
                }
                //死亡的就跳过
                if(isDie(id, b.target)){
                    continue;
                }
                //更新回合，当没有效果时删除
                b.updateEffect();
                if (b.isNoEffect()) {
                    its.remove();
                }
            }
        }
    }

    /**
     * 遍历转化buff，判断属性是否被转化，转化了就返回转化后的属性，没有则返回原属性
     */
    public static Float getReplaceGJ(String id, String target, String attrName) {
        Vector<buff> buffs = buffMap.get(id);
        synchronized (buffs) {
            for (buff b : buffs) {
                if (b.statusType == 16 && b.target.equals(target)) {
                    JSONObject changeAttr = (JSONObject) b.valueObj;
                    if (changeAttr.getFloat(attrName) != null)
                        return changeAttr.getFloat(attrName);
                }
            }
        }

        //返回原属性
        JSONObject attr = getAttrByPosKey(id, target);
        return attr.getJSONObject("prop").getFloat(attrName);
    }

    /**
     * 非伤害，计算站位身上的增益（只适合 攻击增益-攻击诅咒）
     * attrName:wg\fg\ff\wf
     */
    public static float getObjFinalZy(String id, String posKey, String attrName) throws Exception {
        float value = 0f;
        Vector<buff> bfs = buffMap.get(id);
        synchronized (bfs) {
            Iterator<buff> buffList = bfs.iterator();
            while (buffList.hasNext()) {
                buff b = buffList.next();
                //遍历攻击者技能中包含的buff
                if (b.target.equals(posKey)) {
                    //遍历攻击者技能中包含的buff时生效的，并且是增益的
                    if (b.statusType == 1 && b.txRule.paramStr.equals(attrName)) {
                        //验证是否处于某个buff下才能参与计算(比如残废状态下伤害会提高)
                        int conditionStatusType = b.getConditionStatusType();
                        if (conditionStatusType > 0 &&
                                !isInBuff(id, posKey, conditionStatusType)) {
                            continue;
                        }
                        //低血量判断，需要有低血量条件并且血量低于某个值
                        if (b.isNeedConditionRuleXueK() && !b.isLowXue(id)) {
                            continue;
                        }
                        if (attrName.equals("sufferHurt")) {
                            //要求buff必须是有效的
                            if (b.isNoEffect()) {
                                continue;
                            }
                            //刷新有效次数
                            b.updateEffectTimes();
                            //value -= (obj.getFloat("value") * k);
                        } /*else {
                                value += (obj.getFloat("value") * k);
                            }*/
                        //凡增加的用正数，减少的用负数
                        int num = b.getNowAddNum();
                        value += (b.txRule.getVal(b.lever, 0) * num);
                    } else if (b.statusType == 2 && b.txRule.paramStr.equals(attrName)) {
                        int num = b.getNowAddNum();
                        //凡增加的用正数，减少的用负数
                        value += (b.txRule.getVal(b.lever, 0) * num);
                            /*if (attrName.equals("sufferHurt")) {
                                value += (obj.getFloat("value") * k);
                            } else {
                                value -= (obj.getFloat("value") * k);
                            }*/
                    }

                }
            }
        }

        return value;
    }

    /**
     * 获取对象身上的buff
     */
    public static List<buff> getObjBuffs(String id, String posKey) {
        List<buff> buffs = new ArrayList<>();
        Vector vs = buffMap.get(id);
        synchronized (vs) {
            Iterator<buff> buffList = vs.iterator();
            while (buffList.hasNext()) {
                buff b = buffList.next();
                //遍历攻击者技能中包含的buff
                if (b.target.equals(posKey)) {
                    buffs.add(b);
                }
            }
        }
        return buffs;
    }
//todo 改成添加buff后就必须显示buff特效，如天籁曲释放后就要显示其特效，不要等到下一回合


    /**
     * 获取某个状态的buff
     */
    public static buff getBuffInStatusType(String id, String target, int statusType) {
        Vector vs = buffMap.get(id);
        synchronized (vs) {
            Iterator<buff> its = vs.iterator();
            while (its.hasNext()) {
                buff b = its.next();
                if (b.statusType == statusType && b.target.equals(target)) {
                    return b;
                }
            }
        }
        return null;
    }

    public static buff getBuffInStatusTypeByAttrName(String id, String target, int statusType, String attrName) {
        Vector vs = buffMap.get(id);
        synchronized (vs) {
            Iterator<buff> its = vs.iterator();
            while (its.hasNext()) {
                buff b = its.next();
                if (b.statusType == statusType && b.target.equals(target) &&
                        b.txRule.paramStr.equals(attrName)) {
                    return b;
                }
            }
        }
        return null;
    }

    /**
     * 判断释放处于某个状态并且层数一致
     */
    public static boolean isInBuffWithAdds(String id, String target, Integer statusType, int adds, boolean isRem) {
        Vector vs = buffMap.get(id);
        synchronized (vs) {
            Iterator<buff> its = vs.iterator();
            while (its.hasNext()) {
                buff b = its.next();
                if (b.statusType == statusType && b.target.equals(target) &&
                        b.isSameAdds(adds)) {
                    if (isRem) {
                        its.remove();
                    }
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * 判断是否处于某个状态
     */
    public static boolean isInBuff(String id, String target, int statusType) {
        Vector<buff> vs = buffMap.get(id);
        synchronized (vs) {
            Iterator<buff> its = vs.iterator();
            while (its.hasNext()) {
                buff b = its.next();
                if (b.statusType == statusType && b.target.equals(target)) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * 判断某些属性是否可被忽略
     */
    public static boolean isIgnoreAttr(String id, String target, String attrName) {
        buff b = getBuffInStatusType(id, target, 25);
        if (b == null) return false;
        for (String key : b.txRule.paramJObj.keySet()) {
            if (key.equals(attrName)) return true;
        }
        return false;
    }

    /**
     * 判断是否处于某个状态,并且是同一个技能发出
     */
    public static boolean isInBuff(String id, String target, String sklKey) {
        Vector<buff> bfs = buffMap.get(id);
        synchronized (bfs) {
            Iterator<buff> its = bfs.iterator();
            while (its.hasNext()) {
                buff b = its.next();
                if (b.target.equals(target)
                        && sklKey.equals(b.key)) {
                    return true;
                }
            }
        }
        return false;
    }

}
