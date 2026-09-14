package my.service.fight;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.gameUtils.skillUtils;
import my.model.*;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import my.utils.systemUtils;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Vector;

import static my.fightUtils.fightBuffHandUtils.*;
import static my.fightUtils.fightUtils.*;
import static my.model.skillItemBaseRule.*;
import static my.model.skillItemBaseRule.createAddRule;
import static my.model.skillItemRuleType.*;
import static my.model.skillItemTriggerMoment.*;
import static my.model.skillItemTxRule.createGainRule;

/**
 * 所有buff触发时机的处理
 */
public class buffTriggerHandle {
    private static buffTriggerHandle one;

    public static buffTriggerHandle getOne() {
        if (one == null) one = new buffTriggerHandle();
        return one;
    }

    /**
     * 命中后触发
     */
    public float mzTriggerBuff(String id, String control, String target, List<action> acList, action ac) {
        return triggerBuff(id, control, target, isMzTriggre, acList, ac, 0, 0);
    }

    /**
     * control打出暴击时触发
     */
    public float baojiTriggerBuff(String id, String control, String target, List<action> acList, action ac, float sumHurt) {
        //control打出暴击所以遍历的buff目标应该是control
        return triggerBuff(id, target, control, isBaojiTrigger, acList, ac, sumHurt, 0);
    }

    /**
     * 遭受暴击时触发
     */
    public float sufferBaojiTriggerBuff(String id, String control, String target, List<action> acList, action ac, float sumHurt) {
        return triggerBuff(id, control, target, isSufferBaojiTrigger, acList, ac, sumHurt, 0);
    }

    /**
     * 血量计算完成时触发
     */
    public float countXueDoneTriggerBuff(String id, String control, String target, List<action> acList, action ac, boolean isQunG) {
        //如阻止对target的攻击（返回-1表示阻止成功）
        return triggerBuff(id, control, target, isCountXueDoneTrigger, acList, ac, 0, isQunG);
    }

    /**
     * 目标死亡时触发
     */
    public float dieTriggerBuff(String id, String control, String target, List<action> acList, action ac) {
        //如阻止对target的攻击（返回-1表示阻止成功）
        return triggerBuff(id, control, target, isDieTrigger, acList, ac, 0, 0);
    }

    /**
     * 对目标执行攻击之前触发
     */
    public float attackBeforeTriggerBuff(String id, String control, String target, List<action> acList, action ac) {
        //如阻止对target的攻击（返回-1表示阻止成功）
        return triggerBuff(id, control, target, isAttackBeforeTrigger, acList, ac, 0, 0);
    }

    /**
     * 对目标执行攻击之前触发
     */
    public float actionStartBeforeTriggerBuff(String id, String control, String target, List<action> acList, action ac) {
        //如阻止对target的攻击（返回-1表示阻止成功）
        return triggerBuff(id, control, target, isActionStartTriggre, acList, ac, 0, 0);
    }

    /**
     * target遭受伤害时触发
     */
    public float sufferHurtTriggerBuff(String id, String control, String target, List<action> acList, action ac, float sumHurt, boolean isQunG) {
        //如target受伤时反震一部分给control
        return triggerBuff(id, control, target, isSufferHurtTrigger, acList, ac, sumHurt, isQunG);
    }

    /**
     * 给target造成伤害时触发
     */
    public float hurtTriggerBuff(String id, String control, String target, List<action> acList, action ac, float sumHurt) {
        //如造成伤害后吸血
        return triggerBuff(id, control, target, isHurtTrigger, acList, ac, sumHurt, null);
    }

    /**
     * 技能发动前，控制方和目标都是自己
     */
    public float sklShiFangBefTriggerBuff(String id, String control, List<action> acList, action ac) {
        //如属性转换
        return triggerBuff(id, control, control, isSklShiFangBefTrigger, acList, ac, 0, null);
    }

    /**
     * 回合开始时触发
     */
    public float huiheStartTriggerBuff(String id, List<action> list) {
        action ac = new action(null, null);
        triggerBuff(id, null, null, isHuiheStartTriggre, list, ac, 0, null);
        if (ac.actionItems.size() != 0) {
            list.add(ac);
        }
        return 0;
    }

    /**
     * 触发buff的效果
     */
    private float triggerBuff(String id, String control, String target, int triggerMoment, List<action> acList, action ac, float sumHurt, Object param) {
        List<Runnable> runList = new ArrayList<>();
        //遍历buff
        Vector<buff> vs = buffMap.get(id);
        synchronized (vs) {
            buff b = null;
            Iterator<buff> its = vs.iterator();
            while (its.hasNext()) {
                try {
                    b = its.next();
                } catch (Exception e) {
                    //b的值是上一个buff，具体是哪个得看vs
                    System.err.println("遍历buff时被修改：" + b.statusType + "/" + b.key);
                    System.err.println(staticCollection.copyArr(vs));
                    break;
                    //throw new RuntimeException(e);
                }
                //要求作用对象和触发时机一致
                if ((target != null && !b.target.equals(target)) ||
                        b.triggerBuffMoment != triggerMoment) continue;

                //判断buff是否有效
                if (b.isNoEffect()) {
                    continue;
                }

                //回合开始时触发的buff对于buff目标已经死亡的情况下不再继续发挥效果
                if (!(isBreak(id, b.target) && b.triggerBuffMoment == isHuiheStartTriggre)) {
                    //效果是否处于冷却中
                    if (b.isEfCooling()) {
                        continue;
                    }
                    try {
                        sumHurt = triggerByStatusType(id, b, control, target, acList, ac, sumHurt, param, runList);
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }

                //减少次数
                b.updateEffectTimes();
                if (b.isNoEffect()) {
                    if (systemUtils.isWindows()) {
                        System.err.println(b.target + "/buff被移除/" + b.key);
                    }
                    its.remove();
                }
            }
        }
        //因为触发buff时可能出现创建buff的情况，所以为了避免遍历的过程中出现buffs被改动，
        // 就将增加buff的操作交由这里
        if (runList.size() > 0) {
            for (int i = 0; i < runList.size(); i++) {
                runList.get(i).run();
            }
        }
        return sumHurt;
    }

    /**
     * 直接根据技能项来触发
     */
    public void triggerBySkillItem(String id, JSONObject skl, skillItem item,
                                   String control, String target, List<action> acList, action ac,
                                   float sumHurt, float sumAttack) {
        String a = target;//对目标产生一个buff
        if (item.getTarget() == 0) {//技能点目标要求是自己
            a = control;//对自己产生一个buff
        } else if (item.getTarget() == 1) {//友方
            //多个不确定目标所以要跳过
            if (!isMyFriend(target, control)) return;
        }
        buff bf = new buff(control, skl.getString("key"), skl.getInteger("lv"), a, item);
        bf.addSumHurt(sumHurt, sumAttack);

        //这里仅构建一个buff而不放入缓存
        List<Runnable> runList = new ArrayList<>();
        try {
            triggerByStatusType(id, bf, control, target, acList, ac, sumHurt, null, runList);
        } catch (Exception e) {
            e.printStackTrace();
        }
        if (runList.size() > 0) {
            for (int i = 0; i < runList.size(); i++) {
                runList.get(i).run();
            }
        }

    }

    /***
     * @param sumHurt 是负值
     */
    private float triggerByStatusType(String id, buff b, String control, String target, List<action> acList, action ac, float sumHurt, Object param, List<Runnable> runList) throws Exception {
        String sklKey = b.key;
        int lv = b.lever;

        //根据buff的statusType来处理具体的效果
        if (b.statusType == skillItemRuleType.GuRule) {
            ac.skillKey = b.key;//因为在外面并没有设置
            int guType = b.txRule.paramInt;
            if (guType == 0 || guType == 1) {//定身、睡眠
                actionItem aci = new actionItem(b.target);
                aci.statusType = b.statusType;
                aci.isRest = 1;
                if (guType == 0) aci.tipKey = "dingshen";
                else aci.tipKey = "shuimian";
                ac.putActionItem(aci);
            } else if (guType == 2) {//混乱(50%伤害，随机目标)
                //随机一个除自身外的目标
                List<String> tg = getPosKeysByNumRemSelf(id, b.target, 1);
                if (tg.size() > 0) {
                    //里面可能会因为目标死亡而创建buff，所以作为run来执行
                    runList.add(() -> {
                        try {
                            attackHandle.getOne().noBuffAttackHandle(id, b.target, tg.get(0), acList, ac, GuRule, 1f);
                        } catch (Exception e) {
                            throw new RuntimeException(e);
                        }
                    });
                }
            }
            return -1;//仅表示成功，在行动开始前判断为-1时则不再继续往下执行
        } else if (b.statusType == skillItemRuleType.LiuXueRule) {
            //伤害*层数
            float value = b.txRule.getVal(b.lever, 0) * b.sumHurt * b.getNowAddNum();
            JSONObject targetAttr = getAttrByPosKey(id, b.target);
            float v = targetAttr.getJSONObject("prop").getFloat("xue") + value;
            if (v < 0) v = 0f;
            targetAttr.getJSONObject("prop").put("xue", v);
            if (v <= 0) {
                if (isInBuff(id, b.target, NoDieRule) || isInBuff(id, b.target, WuDiRule)) {
                    targetAttr.getJSONObject("prop").put("xue", 1);
                }
                runList.add(() -> {
                    buffCreateHandle.getOne().isDieCreateBuff(id, control, target, ac, 0);
                    dieTriggerBuff(id, control, b.target, acList, ac);
                });
            }
            int targetIsDie = isDieByPosKey(id, b.target);
            actionItem aci = new actionItem(b.target);
            aci.statusType = b.statusType;
            aci.value = (int) value;
            aci.isDie = targetIsDie;
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.HuiXueRule) {
            float k = b.txRule.getVal(lv, 0);
            int nowAddNum = b.getNowAddNum();
            int sumHurtOrMaxXue = b.txRule.paramInt;
            JSONObject controlAttr = getAttrByPosKey(id, b.target);
            JSONObject prop = controlAttr.getJSONObject("prop");
            float addXue = 0;
            if (sumHurtOrMaxXue == 0) {
                addXue = b.sumAttack * k * nowAddNum;
            } else {
                addXue = prop.getFloat("max_xue") * k * nowAddNum;
            }
            float xueZy = buffZyHandle.getOne().getSufferCureZy(id, b.target);
            addXue = addXue * (1 + xueZy);
            float xue = addXue + prop.getFloat("xue");
            if (xue > prop.getFloat("max_xue")) {
                xue = prop.getFloat("max_xue");
            }
            prop.put("xue", xue);
            actionItem it = new actionItem(b.target);
            it.statusType = b.statusType;
            it.isDie = 0;
            it.value = (int) addXue;
            ac.putActionItem(it);
        } else if (b.statusType == skillItemRuleType.XiXueRule) {
            float xx = b.txRule.getVal(lv, 0);
            float value = -sumHurt * xx;
            float xueZy = buffZyHandle.getOne().getSufferCureZy(id, b.target);
            //攻击方获得一定伤害的血量恢复
            JSONObject controlAttr = getAttrByPosKey(id, b.target);
            float xue = controlAttr.getJSONObject("prop").getFloat("xue") + value * (1 + xueZy);
            if (xue > controlAttr.getJSONObject("prop").getFloat("max_xue")) {
                xue = controlAttr.getJSONObject("prop").getFloat("max_xue");
            }
            controlAttr.getJSONObject("prop").put("xue", xue);

            actionItem aci = new actionItem(b.target);
            aci.statusType = b.statusType;
            aci.value = Float.valueOf(value * (1 + xueZy)).intValue();
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.FanZhenRule) {
            if (!strUtils.isHappend(0, 100, b.triggerPv)) return sumHurt;
            //攻击方遭受反伤
            JSONObject targetAttr = getAttrByPosKey(id, control);
            float value = sumHurt * b.txRule.getVal(b.lever, 0);
            float targetXue = targetAttr.getJSONObject("prop").getFloat("xue") + value;
            if (targetXue < 0) targetXue = 0f;
            targetAttr.getJSONObject("prop").put("xue", targetXue);
            actionItem aci = new actionItem(control);
            aci.statusType = b.statusType;
            aci.value = (int) value;
            aci.isDie = isDieByPosKey(id, control);
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.BeiCiRule) {
            if (!strUtils.isHappend(0, 100, b.triggerPv)) return sumHurt;
            //target受到伤害，变成target不受伤，并将伤害转移给control
            skillItemTxRule beiCiRule = b.txRule;
            String newTarget = target;
            if (beiCiRule.paramInt == 2) {//转移给敌方
                newTarget = control;
            } else if (beiCiRule.paramInt == 1) {
                //获取target队友站位
                newTarget = getNoSelfTargetPosKey(id, target);
                //无法将伤害转移给队友时
                if (newTarget == null) newTarget = target;
            }
            float k = beiCiRule.getVal(lv, 0);
            boolean isAddXue = beiCiRule.paramBool;
            float value = sumHurt * k;
            if (isAddXue) value = -sumHurt * k;

            JSONObject targetAttr = getAttrByPosKey(id, newTarget);
            float maxXue = targetAttr.getJSONObject("prop").getFloat("max_xue");
            float targetXue = targetAttr.getJSONObject("prop").getFloat("xue") + value;
            if (targetXue < 0) targetXue = 0f;
            else if (targetXue > maxXue) targetXue = maxXue;
            targetAttr.getJSONObject("prop").put("xue", targetXue);

            String mTarget = newTarget;
            if (targetXue <= 0) {
                if (isInBuff(id, mTarget, NoDieRule) || isInBuff(id, mTarget, WuDiRule)) {
                    targetAttr.getJSONObject("prop").put("xue", 1);
                }
                runList.add(() -> {
                    buffCreateHandle.getOne().isDieCreateBuff(id, target, control, ac, 0);
                    dieTriggerBuff(id, b.target, control, acList, ac);
                });
            }
            actionItem aci = new actionItem(newTarget);
            aci.statusType = b.statusType;
            aci.value = (int) value;
            aci.isDie = isDieByPosKey(id, newTarget);
            ac.putActionItem(aci);

            sumHurt = 0f;
        } else if (b.statusType == skillItemRuleType.ZhongDuRule) {
            //伤害*层数
            float value = b.txRule.getVal(b.lever, 0) * b.sumHurt * b.getNowAddNum();
            JSONObject targetAttr = getAttrByPosKey(id, b.target);
            float v = targetAttr.getJSONObject("prop").getFloat("xue") + value;
            if (v < 0) v = 0f;
            targetAttr.getJSONObject("prop").put("xue", v);
            if (v <= 0) {
                if (isInBuff(id, b.target, NoDieRule) || isInBuff(id, b.target, WuDiRule)) {
                    targetAttr.getJSONObject("prop").put("xue", 1);
                }
                runList.add(() -> {
                    buffCreateHandle.getOne().isDieCreateBuff(id, control, target, ac, 0);
                    dieTriggerBuff(id, control, b.target, acList, ac);
                });
            }
            int targetIsDie = isDieByPosKey(id, b.target);
            actionItem aci = new actionItem(b.target);
            aci.statusType = b.statusType;
            aci.value = (int) value;
            aci.isDie = targetIsDie;
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.RestRule) {
            ac.skillKey = b.key;
            actionItem aci = new actionItem(b.target);
            aci.isRest = 1;
            ac.putActionItem(aci);
            return -1;//仅表示成功，在行动开始前判断为-1时则不再继续往下执行
        } else if (b.statusType == skillItemRuleType.RemoveRule) {
            //找到缓存中状态、目标一致的buff进行移除
            List<buff> bs = buffMap.get(id);
            //获取移除规则
            List<Integer> statusTypes = b.txRule.paramIntList;
            for (int s : statusTypes) {
                Iterator<buff> bfs = bs.iterator();
                while (bfs.hasNext()) {
                    buff b0 = bfs.next();
                    //目标一致，并且跟所要移除的状态一致
                    if (b0.target.equals(b.target) && b0.statusType == s) {
                        bfs.remove();
                    }
                }
            }
            actionItem aci = new actionItem(b.target);
            aci.statusType = b.statusType;
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.FuHuoRule) {
            //将死亡的标记设置为0，并恢复生命值
            setPlayerDie(id, target, 0);
            //恢复血量
            float xx = b.txRule.getVal(lv, 0);
            JSONObject targetAttr = getAttrByPosKey(id, target);
            float value = targetAttr.getJSONObject("prop").getFloat("max_xue") * xx;
            float xue = targetAttr.getJSONObject("prop").getFloat("xue") + value;
            targetAttr.getJSONObject("prop").put("xue", xue);
            actionItem aci = new actionItem(target);
            aci.statusType = b.statusType;
            aci.value = (int) value;
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.HuiLanRule) {
            JSONObject targetAttr = getAttrByPosKey(id, b.target);
            float k = b.txRule.getVal(b.lever, 0);
            float maxLan = targetAttr.getJSONObject("prop").getFloat("max_lan");
            float v = targetAttr.getJSONObject("prop").getFloat("lan") + maxLan * k;
            if (v > targetAttr.getJSONObject("prop").getFloat("max_lan")) {
                v = targetAttr.getJSONObject("prop").getFloat("max_lan");
            }
            targetAttr.getJSONObject("prop").put("lan", v);
            actionItem aci = new actionItem(b.target);
            aci.statusType = b.statusType;
            aci.value = (int) (maxLan * k);
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.ZhanShaRule) {
            //低于一定血量触发斩杀
            JSONObject targetAttr = getAttrByPosKey(id, target);
            float bef_xue = targetAttr.getJSONObject("prop").getFloat("xue") - sumHurt;
            float k = b.txRule.getVal(lv, 0);
            //30%血量
            if (targetAttr.getJSONObject("prop").getFloat("max_xue") * k > bef_xue) {
                //发生斩杀
                targetAttr.getJSONObject("prop").put("xue", 0);
                int targetIsDie = isDieByPosKey(id, target);
                actionItem aci = new actionItem(target);
                aci.statusType = b.statusType;
                aci.isDie = targetIsDie;
                ac.putActionItem(aci);
            }
        } else if (b.statusType == skillItemRuleType.TouXueRule) {
            float xx = b.txRule.getVal(lv, 0);
            //目标血量减少百分比
            JSONObject targetAttr = getAttrByPosKey(id, target);
            float value = -targetAttr.getJSONObject("prop").getFloat("max_xue") * xx;
            float targetXue = targetAttr.getJSONObject("prop").getFloat("xue") + value;
            if (targetXue < 0) targetXue = 0f;
            targetAttr.getJSONObject("prop").put("xue", targetXue);
            int isDie = isDieByPosKey(id, target);
            actionItem aci = new actionItem(target);
            aci.statusType = b.statusType;
            aci.value = (int) value;
            aci.isDie = isDie;
            ac.putActionItem(aci);
            //转回血
            JSONObject controlAttr = getAttrByPosKey(id, control);
            float xue = controlAttr.getJSONObject("prop").getFloat("xue") - value;
            if (xue > controlAttr.getJSONObject("prop").getFloat("max_xue")) {
                xue = controlAttr.getJSONObject("prop").getFloat("max_xue");
            }
            controlAttr.getJSONObject("prop").put("xue", xue);

            aci = new actionItem(control);
            aci.statusType = b.statusType;
            aci.value = Float.valueOf(value).intValue();
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.HuanXueRule) {
            //按一定比例换取target的血量
            float xx = b.txRule.getVal(lv, 0);
            //是否需要扣除自身血量
            boolean isCutSelf = b.txRule.paramBool;
            boolean isFoe = b.txRule.paramBoolList.get(0);
            boolean isAll = b.txRule.paramBoolList.get(1);
            //control付出多少，目标承受多少
            float value = 0f;
            if (isCutSelf) {//这里是扣除自身血量并作用在一个指定的目标
                JSONObject controlAttr = getAttrByPosKey(id, control);
                value = -controlAttr.getJSONObject("prop").getFloat("max_xue") * xx;
                float xue = controlAttr.getJSONObject("prop").getFloat("xue") + value;
                if (xue < 0) {
                    xue = 0f;
                }
                controlAttr.getJSONObject("prop").put("xue", xue);
                actionItem aci = new actionItem(control);
                aci.statusType = b.statusType;
                aci.isDie = isDieByPosKey(id, control);
                aci.value = Float.valueOf(value).intValue();
                ac.putActionItem(aci);
            }
            if (isFoe && isAll) {//不扣除自身血量，作用在多个目标
                JSONObject controlAttr = getAttrByPosKey(id, b.target);
                value = -controlAttr.getJSONObject("prop").getFloat("max_xue") * xx;
                String lOrR = "r";
                if (target.contains("r")) lOrR = "l";
                List<String> tg = getLeftOrRightPosKeysByNum(id, lOrR, 10);
                if (tg.size() > 0) {
                    for (String t : tg) {
                        JSONObject targetAttr = getAttrByPosKey(id, t);
                        float targetXue = targetAttr.getJSONObject("prop").getFloat("xue") + value;
                        if (targetXue < 0) targetXue = 0f;
                        targetAttr.getJSONObject("prop").put("xue", targetXue);
                        if (targetXue <= 0) {
                            if (isInBuff(id, t, NoDieRule) || isInBuff(id, t, WuDiRule)) {
                                targetAttr.getJSONObject("prop").put("xue", 1);
                            }
                            runList.add(() -> {
                                buffCreateHandle.getOne().isDieCreateBuff(id, control, t, ac, 0);
                                dieTriggerBuff(id, control, t, acList, ac);
                            });
                        }
                        actionItem aci = new actionItem(t);
                        aci.statusType = b.statusType;
                        aci.value = (int) value;
                        aci.isDie = isDieByPosKey(id, t);
                        ac.putActionItem(aci);
                    }
                }
            } else {//扣除自身血量并作用在一个指定的目标

            }

        } else if (b.statusType == skillItemRuleType.CutXueRule) {
            float xx = b.txRule.getVal(lv, 0);
            JSONObject targetAttr = getAttrByPosKey(id, target);
            float value = targetAttr.getJSONObject("prop").getFloat("max_xue") * xx;
            float targetXue = targetAttr.getJSONObject("prop").getFloat("xue") - value;
            if (targetXue < 0) targetXue = 0f;
            targetAttr.getJSONObject("prop").put("xue", targetXue);
            if (targetAttr.getJSONObject("prop").getFloat("xue") <= 0) {
                if (isInBuff(id, b.target, NoDieRule) || isInBuff(id, b.target, WuDiRule)) {
                    targetAttr.getJSONObject("prop").put("xue", 1);
                }
                runList.add(() -> {
                    buffCreateHandle.getOne().isDieCreateBuff(id, control, target, ac, 0);
                    dieTriggerBuff(id, control, b.target, acList, ac);
                });
            }
            actionItem aci = new actionItem(target);
            aci.statusType = b.statusType;
            aci.value = -(int) value;
            aci.isDie = isDieByPosKey(id, target);
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.HurtUpRule) {
            if (b.txRule.paramInt != -1 &&
                    !isInBuff(id, target, b.txRule.paramInt)) return sumHurt;
            float xx = b.txRule.getVal(lv, 0);
            sumHurt += sumHurt * xx;
        } else if (b.statusType == skillItemRuleType.QiMenDunJiaRule) {

        } else if (b.statusType == skillItemRuleType.CutLanRule) {
            //伤害的一定比例对目标造成减蓝
            float xx = b.txRule.getVal(lv, 0);
            float value = sumHurt * xx;
            if (value < -4000) {
                value = -4000;//最多减少4000蓝
            }
            JSONObject targetAttr = getAttrByPosKey(id, target);
            float targetLan = targetAttr.getJSONObject("prop").getFloat("lan") + value;
            if (targetLan < 0) targetLan = 0f;
            targetAttr.getJSONObject("prop").put("lan", targetLan);
            actionItem aci = new actionItem(target);
            aci.statusType = b.statusType;
            aci.value = (int) value;
            aci.isDie = isDieByPosKey(id, target);
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.DiDangRule) {
            //target身上有抵挡伤害的buff，可由站位按比例承受，也可由傀儡承受（不存在的站位）
            //群攻并且由释放技能者承受伤害时不生效
            if ((boolean) param && b.txRule.paramBool) return sumHurt;
            if (!strUtils.isHappend(0, 100, b.triggerPv)) return sumHurt;

            skillItemTxRule ddRule = b.txRule;
            boolean isBuilderRev = ddRule.paramBool;
            if (isBuilderRev) {
                String newTarget = b.builderPosKey;
                //如果发动者已经死亡，则全部由target承受
                if (isDie(id, newTarget)) return sumHurt;
                //技能发动者要分担的伤害
                float value = sumHurt * ddRule.getVal(lv, 0);
                JSONObject targetAttr = getAttrByPosKey(id, newTarget);
                float targetXue = targetAttr.getJSONObject("prop").getFloat("xue") + value;
                if (targetXue < 0) targetXue = 0f;
                targetAttr.getJSONObject("prop").put("xue", targetXue);
                actionItem aci = new actionItem(newTarget);
                aci.statusType = b.statusType;
                aci.value = (int) value;
                aci.isDie = isDieByPosKey(id, newTarget);
                aci.helper = target;
                ac.putActionItem(aci);
            }
            //目标要分担伤害
            sumHurt = ddRule.getVal(lv, 1) * sumHurt;
        } else if (b.statusType == skillItemRuleType.NoAttackRule) {
            //对于友方不会阻止
            if (isMyFriend(control, target) || !strUtils.isHappend(0, 100, b.triggerPv)) return sumHurt;
            //target身上有禁止被攻击的buff,control阻止对target进行攻击
            actionItem aci = new actionItem(control);
            aci.target = control;
            aci.statusType = b.statusType;
            ac.putActionItem(aci);
            return -1;//-1表示阻止成功
        } else if (b.statusType == skillItemRuleType.NoDieRule) {
            //目标触发不死
            if (!strUtils.isHappend(0, 100, b.triggerPv)) return sumHurt;
            float k = b.txRule.getVal(b.lever, 0);
            int valueType = b.txRule.getValueType(0);
            JSONObject targetAttr = getAttrByPosKey(id, target);
            float xue = 0;
            if (valueType == 0) {//非比例加血
                xue = k;
            } else {
                xue = targetAttr.getJSONObject("prop").getFloat("max_xue") * k;
            }
            targetAttr.getJSONObject("prop").put("xue", xue);
            actionItem aci = new actionItem(target);
            aci.isDie = 0;
            aci.statusType = b.statusType;
            aci.value = (int) xue;
            ac.putActionItem(aci);
            //不死时创建
            runList.add(() -> {
                buffCreateHandle.getOne().noDieCreateBuff(id, control, target, ac);
            });
        } else if (b.statusType == skillItemRuleType.FanJiRule) {
            float pv = b.triggerPv;
            //增加反击几率
            buff bf0 = getBuffInStatusTypeByAttrName(id, b.target, RateRule, "fanji");
            if (bf0 != null) {
                //验证目标血量是否满足条件
                JSONObject targetAttr = getAttrByPosKey(id, b.target);
                if (targetAttr.getJSONObject("prop").getFloat("xue") <
                        targetAttr.getJSONObject("prop").getFloat("max_xue")
                                * bf0.txRule.getVal(bf0.lever, 1)) {
                    pv += bf0.txRule.getVal(bf0.lever, 0);
                }
            }
            //反击目标为自身\友方时或者概率不发生时禁止触发反击
            if (isMyFriend(target, control) ||
                    !strUtils.isHappend(0, 100, pv)) return sumHurt;
            //target受伤后做出反击
            //里面可能会因为目标死亡而创建buff，所以作为run来执行
            runList.add(() -> {
                try {
                    attackHandle.getOne().noBuffAttackHandle(id, target, control, acList, ac, FanJiRule, 1);
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            });
        } else if (b.statusType == skillItemRuleType.LianJiRule) {
            //群攻不允许连击
            //if ((boolean) param) return sumHurt;
            //禁止连击队员
            if (isMyFriend(target, control)) return sumHurt;
            int times = b.txRule.paramInt;
            float gjK = b.txRule.getVal(b.lever, 0);
            //里面可能会因为目标死亡而创建buff，所以作为run来执行
            runList.add(() -> {
                try {
                    for (int i = 0; i < times; i++) {
                        attackHandle.getOne().noBuffAttackHandle(id, control, target, acList, ac, LianJiRule, gjK);
                    }
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            });
        } else if (b.statusType == skillItemRuleType.BanShengRule) {
            //主角不死，宠物不死
            JSONObject fightMsg = fightMap.get(id);
            //判断是否为玩家参与的战斗，还是仅只有宠物
            if (fightMsg.getInteger("type") == 10 ||
                    fightMsg.getInteger("type") == 11) {
                return sumHurt;
            }
            int a = Integer.parseInt(String.valueOf(target.charAt(1))) - 5;
            if (isDie(id, String.valueOf(target.charAt(0)) + a)) {
                //玩家已死则不触发
                return sumHurt;
            }
            JSONObject targetAttr = getAttrByPosKey(id, target);
            float xue = targetAttr.getJSONObject("prop").getFloat("max_xue") * 0.1f;
            targetAttr.getJSONObject("prop").put("xue", xue);
            actionItem aci = new actionItem(target);
            aci.isDie = 0;
            aci.statusType = b.statusType;
            aci.value = (int) xue;
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.TouSkillRule) {
            //目标是怪物则不用筛选
            JSONObject a = getTargetByPosKey(id, target);
            if (a.getInteger("type") == 2) {
                return sumHurt;
            }
            //盗取目标技能（只能是主动技能）
            JSONObject prop = getAttrByPosKey(id, target);
            JSONArray skls = prop.getJSONArray("skill");
            //随机一个主动技能
            JSONArray arr = new JSONArray();
            for (Object sk : skls) {
                JSONObject skObj = (JSONObject) sk;
                skill sklObj = skillUtils.getInstance().getSkill(skObj.getString("key"));
                if (sklObj != null) {
                    for (skillItem it : sklObj.skillItems) {
                        if (it.statusType == 0) {
                            //主动则加入
                            arr.add(skObj);
                            break;
                        }
                    }
                }
            }
            if (arr.size() == 0) {
                return sumHurt;
            }
            //随机一个主动
            JSONObject finalSkl = (JSONObject) arr.get(strUtils.getRandom(0, arr.size()));

            //将该主动技能放入攻击者技能栏，注意要操作真实数据，不是复制数据
            JSONObject cObj = getAttrByPosKey(id, control);
            JSONArray myList = cObj.getJSONArray("skill");

            boolean isExist = false;
            for (Object m : myList) {
                JSONObject mm = (JSONObject) m;
                if (mm.getString("key").equals(finalSkl.getString("key"))) {
                    isExist = true;
                    break;
                }
            }
            if (!isExist) {
                //未携带该技能的就携带上
                myList.add(finalSkl);
                actionItem aci = new actionItem(control);
                aci.target = control;
                aci.statusType = b.statusType;
                aci.msg = finalSkl;
                ac.putActionItem(aci);
            }
        } else if (b.statusType == skillItemRuleType.WuDiRule) {
            //无敌则不受伤害，目标方不受伤害
            sumHurt = 0;
            JSONObject targetAttr = getAttrByPosKey(id, b.target);
            if (targetAttr.getJSONObject("prop").getFloat("xue") <= 0) {
                targetAttr.getJSONObject("prop").put("xue", 1);
            }
            if (b.txRule.paramBool) {//已经生效过了
                return sumHurt;
            }
            b.txRule.paramBool = true;
            //回合变更为2
            int huihe = b.txRule.paramIntList.get(1);
            int times = b.txRule.paramIntList.get(0);
            b.bindEffectRule(huihe, times, null);
            float k = b.txRule.getVal(b.lever, 0);
            if (k > 0) {
                //fixme：不能直接在这里增加buff，因为外面有一层buffs的遍历，一旦增加就出现集合被修改的错误
                //创建一个增加攻击的buff
                Runnable r = () -> {
                    skillItem item = new skillItem(GainRule);
                    item.addTxRule(
                            createGainRule("attackHurt", 0f, k, 1));
                    item.addBaseRules(
                            createTargetRule(0, 0f, 1f, 1, 0),
                            createProbabilityRule(0f, 1f, 0f, 1f),
                            createEffectRule(huihe, -1),
                            createAddRule(1));
                    item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                            .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                    JSONObject skl = new JSONObject();
                    skl.put("key", b.key);
                    skl.put("lv", b.lever);
                    buffCreateHandle.getOne().createBuffToTarget(id, skillItemCreateMoment.isNoCreate, b.target, b.target, skl, item, ac, 0, 0);
                };
                runList.add(r);
            }
        } else if (b.statusType == skillItemRuleType.KillRoleRule) {
            //开场秒杀人物
            //寻找玩家位置，对玩家给予固定伤害
            List<String> posKeys = getRoleListOfPosKey(id);
            float v = 99999999f;
            for (String l : posKeys) {
                JSONObject tAttr = getAttrByPosKey(id, l);
                if (tAttr != null) {
                    if (isSanDuo(id, control, l)) {
                        //闪躲动作
                        actionItem item = new actionItem(l);
                        item.isSd = 1;
                        ac.putActionItem(item);
                        sumHurt = 0;
                        continue;
                    }
                    float xue = tAttr.getJSONObject("prop").getFloat("xue") - v;
                    if (xue <= 0) {
                        xue = 0f;
                    }
                    tAttr.getJSONObject("prop").put("xue", xue);
                    if (xue <= 0) {
                        if (isInBuff(id, l, NoDieRule) || isInBuff(id, l, WuDiRule)) {
                            tAttr.getJSONObject("prop").put("xue", 1);
                        }
                        runList.add(() -> {
                            buffCreateHandle.getOne().isDieCreateBuff(id, control, target, ac, 0);
                            dieTriggerBuff(id, control, l, acList, ac);
                        });
                    }
                } else {
                    continue;
                }
                actionItem aci = new actionItem(l);
                aci.statusType = 0;
                aci.value = -(int) v;
                aci.isDie = isDieByPosKey(id, l);
                ac.putActionItem(aci);
            }
        } else if (b.statusType == skillItemRuleType.addOrCutAttrRule) {
            float xx = b.txRule.getVal(lv, 0);
            String attrName = b.txRule.paramStr;
            JSONObject targetAttr = getAttrByPosKey(id, target);
            float value = targetAttr.getJSONObject("prop").getFloat(attrName) * xx;
            float targetV = targetAttr.getJSONObject("prop").getFloat(attrName) + value;
            if (targetV < 0) targetV = 0f;
            targetAttr.getJSONObject("prop").put(attrName, targetV);
            if (attrName.equals("xue") && targetAttr.getJSONObject("prop").getFloat("xue") <= 0) {
                if (isInBuff(id, b.target, NoDieRule) || isInBuff(id, b.target, WuDiRule)) {
                    targetAttr.getJSONObject("prop").put("xue", 1);
                }
                runList.add(() -> {
                    buffCreateHandle.getOne().isDieCreateBuff(id, control, target, ac, 0);
                    dieTriggerBuff(id, control, b.target, acList, ac);
                });
            }
            actionItem aci = new actionItem(target);
            aci.statusType = b.statusType;
            aci.tipKey = attrName;
            aci.value = (int) value;
            aci.isDie = isDieByPosKey(id, target);
            ac.putActionItem(aci);
        } else if (b.statusType == skillItemRuleType.CutBaTiRule) {
            //获取霸体数量，移除霸体
            buff bf = getBuffInStatusType(id, control, BaTiRule);
            sumHurt = sumHurt * (bf.getNowAddNum() * 0.1f + 1f);
            List<buff> bs = buffMap.get(id);
            Iterator<buff> bfs = bs.iterator();
            while (bfs.hasNext()) {
                buff b0 = bfs.next();
                //目标一致，并且跟所要移除的状态一致
                if (b0.target.equals(control) && b0.statusType == BaTiRule) {
                    bfs.remove();
                }
            }
            actionItem aci = new actionItem(control);
            aci.statusType = b.statusType;
            aci.tipKey = "";
            aci.value = 0;
            aci.isDie = isDieByPosKey(id, control);
            ac.putActionItem(aci);
        }

        return sumHurt;
    }
}
