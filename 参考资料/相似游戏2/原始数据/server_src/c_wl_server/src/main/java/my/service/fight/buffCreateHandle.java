package my.service.fight;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.fightUtils.fightBuffHandUtils;
import my.gameUtils.skillUtils;
import my.model.*;
import my.utils.strUtils;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Vector;

import static my.fightUtils.fightBuffHandUtils.getBuffInStatusType;
import static my.fightUtils.fightUtils.*;
import static my.model.skillItemCreateMoment.*;
import static my.model.skillItemRuleType.*;

/**
 * buff的创建（所有创建buff的时机）
 * 仅仅只是向缓存中放buff，不涉及action
 */
public class buffCreateHandle {
    private static buffCreateHandle one;

    public static buffCreateHandle getOne() {
        if (one == null) one = new buffCreateHandle();
        return one;
    }

    /**
     * 攻击开始时创建
     */
    public void attackStartCreateBuff(String id, String control, String target, List<action> list) {
        action ac = new action(control, null);
        createBuffToTarget(id, isAttackStartCreate, target, control, ac, 0, 0);
        if (ac.actionItems.size() > 0) {
            list.add(ac);
        }
    }

    /**
     * control打出暴击时创建
     */
    public void baojiCreateBuff(String id, String control, String target, action ac, float sumHurt) {
        createBuffToTarget(id, isBaojiCreate, control, target, ac, sumHurt, 0);
    }

    /**
     * target受到暴击时创建
     */
    public void sufferBaojiCreateBuff(String id, String control, String target, action ac, float sumHurt) {
        createBuffToTarget(id, isSufferBaojiCreate, target, control, ac, sumHurt, 0);
    }

    /**
     * 低血量时创建
     */
    public void lowXueCreateBuff(String id, String control, String target, action ac, float sumHurt) {
        //如触发不死后创建一个攻击提升的buff
        createBuffToTarget(id, isLowXueCreate, target, control, ac, sumHurt, 0);
    }

    /**
     * 目标触发不死时创建
     */
    public void noDieCreateBuff(String id, String control, String target, action ac) {
        //如触发不死后创建一个攻击提升的buff
        createBuffToTarget(id, isNoDieCreate, target, control, ac, 0, 0);
    }

    /**
     * 目标死亡时创建
     */
    public void isDieCreateBuff(String id, String control, String target, action ac, float sumHurt) {
        //
        createBuffToTarget(id, isDieCreate, target, control, ac, sumHurt, 0);
    }

    /**
     * 目标反击时创建
     */
    public void fanjiCreateBuff(String id, String control, String target, action ac) {
        //比如反击时创建一个伤害提升的buff
        createBuffToTarget(id, isFanjiCreate, target, control, ac, 0, 0);
    }

    /**
     * 目标遭受伤害后创建
     */
    public void sufferHurtCreateBuff(String id, String control, String target, action ac, float sumHurt) {
        //针对的是目标受伤，不是控制方造成伤害
        createBuffToTarget(id, isSufferHurtCreate, target, control, ac, sumHurt, 0);
    }

    /**
     * 对目标造成伤害时创建
     * 由control对target造成伤害，至于buff承受者取决于技能点的target类型，
     * 为0就是control，1友方，2就是target
     * 比如：造成伤害时，自身攻击增加（技能点目标类型设置为自己）
     * 或目标防御下降（技能点目标类型设置为敌方）等
     */
    public void hurtCreateBuff(String id, String control, String target, action ac, float sumHurt) {
        createBuffToTarget(id, isHurtCreate, control, target, ac, sumHurt, 0);
    }

    /**
     * 命中时创建
     * 由control命中target，至于buff承受者取决于技能点的target类型，
     * 为0就是control，1友方，2就是target
     */
    public void mzCreateBuff(String id, String control, String target, action ac) {
        createBuffToTarget(id, isMZCreate, control, target, ac, 0, 0);
    }

    /**
     * 闪避时创建
     * 由control攻击target，target发生闪躲，至于buff承受者取决于技能点的target类型，
     * 为0就是control，1友方，2就是target
     * 因为是target发生闪躲，所以要交换位置，遍历的是发生闪躲方的技能，从中获取闪躲后创建的buff
     */
    public void sdCreateBuff(String id, String control, String target, action ac) {
        createBuffToTarget(id, isSDCreate, target, control, ac, 0, 0);
    }

    /**
     * 未命中时创建
     */
    public void noMzCreateBuff(String id, String control, String target, action ac) {
        createBuffToTarget(id, isNoMZCreate, control, target, ac, 0, 0);
    }

    public void sklShiFangBefCreateBuff(String id, String control, action ac) {
        createBuffToTarget(id, isSklShiFangBefCreate, control, control, ac, 0, 0);
    }

    /**
     * 在战斗准备阶段创建buff
     */
    public void readyCreateBuff(String id) {
        createBuffNoTarget(id, isReadyCreate, null);
    }

    /**
     * 在回合开始时创建buff
     */
    public void huiheStartCreateBuff(String id, List<action> list) {
        createBuffNoTarget(id, isHuiheStartCreate, list);
    }

    /**
     * 创建buff并添加到缓存
     */
    public buff addBuffToMap(String id, String control, JSONObject skl, String target, skillItem item, action ac, float sumHurt, float sumAttack) {
        buff bf = new buff(control, skl.getString("key"), skl.getInteger("lv"), target, item);
        bf.addSumHurt(sumHurt, sumAttack);
        //叠加处理
        if (!updateSameStatusType(id, bf)) {
            //未找到相同状态的buff时
            buffMap.get(id).add(bf);
        }
        return bf;
    }

    /**
     * 针对有技能项直接输入的
     */
    public boolean createBuffToTarget(String id, int createMoment, String control, String target, JSONObject skl, skillItem item, action ac, float sumHurt, float sumAttack) {
        if (item.createBuffMoment != createMoment) return false;
        //buff承受者取决于技能点的target类型，为0就是control，1友方，2就是target
        List<String> targetList = new ArrayList<>();
        //String a = target;//对目标产生一个buff
        if (item.getTarget() == 0) {//技能点目标要求是自己
            //对自己产生一个buff
            targetList.add(control);
        } else if (item.getTarget() == 1) {//友方
            //多个不确定目标所以要跳过
            if (!isMyFriend(target, control)) return false;
            targetList.add(target);
        } else if (item.getTarget() == 2) {
            //技能对象目标是对方时，但选择的目标是自己或友方就不允许创建
            if (target.equals(control) || isMyFriend(target, control)) return false;
            targetList.add(target);
            /*int lv = skl.getInteger("lv");
            int num = item.getTargetNum(lv);
            if (num > 1) {
                String lOrR = "r";
                if (control.contains("r")) lOrR = "l";
                targetList = getLeftOrRightPosKeysByNum(id, lOrR, num);
            } else {
                targetList.add(target);
            }*/
        } else if (item.getTarget() == 3) {
            //技能对象为操控方主角站位
            int r = Integer.parseInt(control.substring(1));
            if (r > 4) {
                r -= 5;
                targetList.add(control.charAt(0) + "" + r);
            }
        }
        for (int i = 0; i < targetList.size(); i++) {
            String a = targetList.get(i);
            //创建buff前对一些参数进行验证及设置
            if (!addBeforeHandle(id, createMoment, control, a, skl, item, ac)) {
                continue;
            }

            buff bf = addBuffToMap(id, control, skl, a, item, ac, sumHurt, sumAttack);
            //一些buff在创建时需要给前端一个提示
            if (bf.statusType == GainRule || bf.statusType == CurseRule ||
                    bf.statusType == HurtUpRule) {
                actionItem aci = new actionItem(bf.target);
                aci.statusType = bf.statusType;
                aci.tipKey = bf.txRule.paramStr;
                aci.value = bf.txRule.getValToTip(100, bf.lever, 0);
                ac.putActionItem(aci);
            } else if (bf.statusType == LiuXueRule || bf.statusType == ZhongDuRule ||
                    bf.statusType == MoHuaRule || bf.statusType == HuiXueRule ||
                    bf.statusType == ImmuneBuffRule || bf.statusType == CanFeiRule ||
                    bf.statusType == DiDangRule || bf.statusType == BeiCiRule ||
                    bf.statusType == KongJuRule || bf.statusType == BaTiRule) {
                actionItem aci = new actionItem(bf.target);
                aci.statusType = bf.statusType;
                aci.isNoShowBuff = 1;
                aci.statusKeep = bf.getEffectHuihe();
                aci.buffNowAddNum = bf.getNowAddNum();
                ac.putActionItem(aci);
            } else if (bf.statusType == GuRule) {
                actionItem aci = new actionItem(bf.target);
                aci.statusType = bf.statusType;
                aci.tipKey = bf.txRule.paramInt == 0 ? "dingshen" : (bf.txRule.paramInt == 1 ? "shuimian" : "hunluan");
                aci.isNoShowBuff = 1;
                ac.putActionItem(aci);
            } else if (bf.statusType == AttrChangeRule) {
                int lv = bf.lever;
                skillItemTxRule changeRule = bf.txRule;
                //消耗上限比例 没有则为0
                float k0 = changeRule.getVal(lv, 0);
                //转化比例
                float k1 = changeRule.getVal(lv, 1);
                String attrName = changeRule.paramStr;

                JSONObject controlAttr = getAttrByPosKey(id, control);
                float attr0 = controlAttr.getJSONObject("prop").getFloat(attrName);
                List<String> attrNameList = changeRule.paramStrList;
                JSONObject changeAttr = new JSONObject();
                for (String o : attrNameList) {
                    changeAttr.put(o, attr0 * k0 * k1);
                }
                bf.valueObj = changeAttr;
                if (attrName.equals("max_xue")) {
                    //将上限减少
                    changeAttr.put("max_xue", attr0 * (1 - k0));
                    float xue = controlAttr.getJSONObject("prop").getFloat("xue");
                    float max_xue = changeAttr.getFloat("max_xue");
                    //当前血量超过最大血量时，要减去超出的这个部分
                    float v = xue - max_xue;
                    if (v > 0) {
                        controlAttr.getJSONObject("prop").put("xue", max_xue);
                        int targetIsDie = isDieByPosKey(id, bf.target);
                        actionItem aci = new actionItem(bf.target);
                        aci.statusType = bf.statusType;
                        aci.value = -(int) v;
                        aci.isDie = targetIsDie;
                        ac.putActionItem(aci);
                    }
                }
            }
        }


        return true;
    }

    /**
     * 判断buff的状态类型是否是同一种
     */
    private boolean updateSameStatusType(String id, buff inputBuff) {
        Vector<buff> vs = buffMap.get(id);
        synchronized (vs) {
            Iterator<buff> its = vs.iterator();
            while (its.hasNext()) {
                buff b = its.next();
                //过滤目标、状态补一致的buff
                if (!b.target.equals(inputBuff.target) ||
                        b.statusType != inputBuff.statusType) continue;
                if (b.updateStatus(inputBuff)) {
                    //将外部的叠加进行同步
                    inputBuff.addRule = b.addRule;
                    //System.err.println("更新buff:" + inputBuff.statusType);
                    return true;
                }
            }
        }
        //System.err.println("创建buff:" + inputBuff.statusType);
        return false;
    }

    /**
     * buff创建前需要判断以下哪些需要被免疫等
     */
    private boolean addBeforeHandle(String id, int createMoment, String control, String target, JSONObject skl, skillItem item, action ac) {
        if (item.createBuffMoment == isLowXueCreate) {
            //低血量创建的buff需要验证血量
            JSONObject j = getAttrByPosKey(id, control);
            JSONObject prop = j.getJSONObject("prop");
            JSONObject temp = (JSONObject) item.temp;
            if (temp.getFloat("k") * prop.getFloat("max_xue") < prop.getFloat("xue")) {
                return false;
            }
        }

        int lv = skl.getInteger("lv");
        float pv = item.getCreateBuffProbability(lv);
        if (item.statusType == GuRule) {
            //蛊的概率会根据目标的抗性变化
            buff b0 = getBuffInStatusType(id, target, ImmuneBuffRule);
            //免疫蛊则不继续往下创建buff
            if (b0 != null && b0.txRule.isImmune(GuRule)) {
                actionItem aci = new actionItem(target);
                aci.statusType = b0.statusType;
                aci.tipKey = "immune";
                ac.putActionItem(aci);
                return false;
            }
            int guType = item.getTxRule(GuRule).paramInt;
            JSONObject targetAttr = getAttrByPosKey(id, target);
            JSONObject prop = targetAttr.getJSONObject("prop");
            if (guType == 2 && prop.get("hlkx") != null) {
                pv = pv - prop.getFloat("hlkx") / 10000f;
            } else if (guType == 1 && prop.get("hskx") != null) {
                pv = pv - prop.getFloat("hskx") / 10000f;
            }
            if (pv < 0) pv = 0f;
        }
        if (!strUtils.isHappend(0, 100, pv)) {
            //System.err.println("pv未发生-创建buff失败:" + item.statusType);
            if (item.statusType == GuRule) {
                //提示抵抗
                actionItem aci = new actionItem(target);
                aci.statusType = 1000;
                aci.tipKey = "fail";
                ac.putActionItem(aci);
            }
            return false;
        }
        return true;
    }


    /**
     * 针对需要输入目标的
     * control方遍历技能点创建buff作用于target方
     */
    public void createBuffToTarget(String id, int createMoment, String control, String target, action ac, float sumHurt, float sumAttack) {
        //源于control的技能，buff承受者为target
        JSONObject j = getAttrByPosKey(id, control);
        if (j == null || j.get("skill") == null) return;

        JSONArray sklList = j.getJSONArray("skill");
        //遍历技能
        for (Object s : sklList) {
            JSONObject ss = (JSONObject) s;
            //一些是技能的空槽位
            if (!ss.containsKey("key")) continue;
            //int lv = ss.getInteger("lv");
            //获取具体技能
            skill skl = skillUtils.getInstance().getSkill(ss.getString("key"));
            if (skl == null || skl.skillItems == null) continue;
            //如果是主动技能，必须判断释放的技能是否跟其一致。被动技能则不需要
            if ((skl.triggerType == 0 && ac.skillKey != null
                    && ac.skillKey.equals(skl.key))
                    || skl.triggerType == 1) {
                for (skillItem item : skl.skillItems) {
                    createBuffToTarget(id, createMoment, control, target, ss, item, ac, sumHurt, sumAttack);
                }
            }

        }
    }

    /**
     * 针对不需要输入目标的
     */
    public void createBuffNoTarget(String id, int createMoment, List<action> list) {
        int huihe = fightMap.get(id).getInteger("huihe");
        //遍历所有站位的技能，从中取出准备阶段的
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String posKey = t.getString("posKey");
            //死亡的目标不需要再执行
            if (isBreak(id, posKey)) continue;

            JSONObject j = getAttrByPosKey(id, posKey);
            if (j.get("skill") == null) continue;
            JSONArray sklList = j.getJSONArray("skill");
            //遍历技能
            for (Object s : sklList) {
                JSONObject ss = (JSONObject) s;
                //一些是技能的空槽位
                if (!ss.containsKey("key")) continue;
                int lv = ss.getInteger("lv");
                //获取具体技能
                skill skl = skillUtils.getInstance().getSkill(ss.getString("key"));
                //判断是否处于某个回合之后才允许创建
                if (skl == null || skl.skillItems == null ||
                        skl.afterHuiheCreate > huihe) continue;
                //主动技能 要求使用过才允许创建其中的buff
                if (skl.triggerType == 0 &&
                        !fightBuffHandUtils.isUsedZhuDongSkill(id, posKey, skl.key)) continue;

                action ac = new action(posKey, skl.key);
                for (skillItem item : skl.skillItems) {
                    if (item.statusType == 0 ||
                            item.createBuffMoment != createMoment) continue;

                    if (item.createBuffMoment == isReadyCreate ||
                            item.createBuffMoment == isHuiheStartCreate) {
                        //准备阶段、回合开始创建的buff要求目标是自己
                        if (item.getTarget() == 0) {
                            buff buff = new buff(posKey, skl.key, lv, posKey, item);
                            //叠加处理
                            if (!updateSameStatusType(id, buff)) {
                                //未找到相同状态的buff时
                                buffMap.get(id).add(buff);
                            }
                            //一些buff在创建时需要给前端一个提示
                            if (buff.statusType == GainRule ||
                                    buff.statusType == CurseRule) {
                                actionItem aci = new actionItem(buff.target);
                                aci.statusType = buff.statusType;
                                aci.tipKey = buff.txRule.paramStr;
                                aci.value = (int) (buff.txRule.getVal(buff.lever, 0) * 100);
                                ac.putActionItem(aci);
                            } else if (buff.statusType == BaTiRule) {
                                actionItem aci = new actionItem(buff.target);
                                aci.statusType = buff.statusType;
                                aci.isNoShowBuff = 1;
                                aci.statusKeep = buff.getEffectHuihe();
                                aci.buffNowAddNum = buff.getNowAddNum();
                                ac.putActionItem(aci);
                            }

                        }
                    }

                }
                //只有当actionItems有东西时才加入list
                if (list != null && ac.actionItems.size() > 0) {
                    list.add(ac);
                }
            }
        }
    }
}
