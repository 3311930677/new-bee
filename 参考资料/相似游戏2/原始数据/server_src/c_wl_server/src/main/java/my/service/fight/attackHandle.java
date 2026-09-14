package my.service.fight;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import my.gameUtils.skillUtils;
import my.model.*;
import my.utils.loggerUtils;

import java.util.Iterator;
import java.util.List;
import java.util.Vector;

import static my.fightUtils.fightBuffHandUtils.*;
import static my.fightUtils.fightBuffHandUtils.getObjFinalZy;
import static my.fightUtils.fightUtils.*;
import static my.model.skillItemCreateMoment.isEachAttackerCreate;
import static my.model.skillItemRuleType.*;
import static my.model.skillItemTriggerMoment.isEachAttackerTriggre;
import static my.utils.classUtils.invokeFnByFnName;

/**
 * 攻击逻辑
 */
public class attackHandle {
    private static attackHandle one;

    public static attackHandle getOne() {
        if (one == null) one = new attackHandle();
        return one;
    }

    /**
     * 处理技能攻击
     */
    public void skillAttackHandle(String id, JSONObject playerOrder, List<action> list) throws Exception {
        String control = playerOrder.getString("control");
        String target = playerOrder.getString("target");
        //阻止前判断，要求技能目标不能为友方
        //攻击前触发的buff，-1阻止攻击 0则继续
        action ac0 = new action(control, null);
        if (buffTriggerHandle.getOne()
                .attackBeforeTriggerBuff(id, control, target, list, ac0) == -1) {
            list.add(ac0);
            return;
        }
        //获取技能
        //System.out.println("技能：" + playerOrder);
        JSONObject s = playerOrder.getJSONObject("skill");
        skill skl = skillUtils.getInstance().getSkill(s.getString("key"));

        //判断是否存在复活状态的item
        boolean isRelive = false;
        for (skillItem item : skl.skillItems) {
            if (item.statusType == FuHuoRule) {
                isRelive = true;
                break;
            }
        }
        //根据目标血量判断是否更换一个新目标 fixme: 注意对于复活技能就不需要再重选目标了
        if (!isRelive) {
            if (target == null) {
                loggerUtils.error("使用技能时目标出现null：" + playerOrder, this.getClass());
                return;
            }
            String target0 = getNewTarget(id, target);
            if (target0 == null) {
                return;
            }
            if (!target.equals(target0)) {
                target = target0;
            }
        }

        //action ac = new action(control, null);
        list.add(new action(control, null));
        action ac = list.get(list.size() - 1);
        //判断是否满足释放条件 mp\hp
        //扣除hp
        if (skl.triggerCondition == null) {
            System.err.println("triggerCondition为null/ key:" + s.getString("key"));
        }
        float k = invokeFnByFnName(skl.triggerCondition, "getHpValue", s.getInteger("lv"));
        if (k != 0) {
            //按比例扣除血量
            JSONObject controlAttr = getAttrByPosKey(id, control);
            float max_xue = controlAttr.getJSONObject("prop").getFloat("max_xue");
            float xue = controlAttr.getJSONObject("prop").getFloat("xue");
            float sh = max_xue * k;
            if (sh >= xue) {
                //注意：上面创建的ac还没有放入item，如果转为普攻会导致重新创建一个ac，而上面这个size=0
                //提示血不足
                actionItem item = new actionItem(control);
                item.statusType = 1000;
                item.tipKey = "hp_fail";
                ac.putActionItem(item);
                //血量不足，无法继续执行，转普攻(对象不能是自己)
                target = getDirection(control, false) + "0";
                simpleAttackHandle(id, control, target, list, false);
                return;
            }
            //血量充足，减血
            controlAttr.getJSONObject("prop").put("xue", xue - sh);
            //创建耗血动作
            actionItem item = new actionItem(control);
            item.statusType = 21;
            item.isDie = 0;
            item.value = -(int) sh;
            ac.putActionItem(item);
        }
        //怪物不需要扣除蓝量
        JSONObject conObj = getTargetByPosKey(id, control);
        if (conObj.getInteger("type") != 2) {
            //扣除mp
            float mp = invokeFnByFnName(skl.triggerCondition, "getMpValue", s.getInteger("lv"));
            buff bf0 = getBuffInStatusType(id, control, ErMengRule);
            if (bf0 != null) {
                //噩梦状态，蓝量消耗增加
                mp = mp * bf0.txRule.getVal(bf0.lever, 0);
            }
            if (mp != 0) {
                //按比例扣除血量
                JSONObject controlAttr = getAttrByPosKey(id, control);
                //Float max_lan = controlAttr.getJSONObject("prop").getFloat("max_lan");
                float lan = controlAttr.getJSONObject("prop").getFloat("lan");
                if (mp >= lan) {
                    //提示蓝不足
                    actionItem item = new actionItem(control);
                    item.statusType = 1000;
                    item.tipKey = "mp_fail";
                    ac.putActionItem(item);
                    //System.err.println(control + "蓝量不足！");
                    //蓝量不足，无法继续执行，转普攻(对象不能是自己)
                    target = getDirection(control, false) + "0";
                    simpleAttackHandle(id, control, target, list, false);
                    return;
                }
                //蓝量充足，减蓝
                controlAttr.getJSONObject("prop").put("lan", lan - mp);
                //创建耗蓝动作
                actionItem item = new actionItem(control);
                item.statusType = 26;
                item.isDie = 0;
                item.value = -(int) mp;
                item.isNoShowBuff = 1;
                ac.putActionItem(item);
            }
        }

        ac.skillKey = skl.key;
        //获取目标数量
        int num = skl.skillItems.get(0).getTargetNum(s.getInteger("lv"));
        Vector<String> targetList = null;
        //是否按排/列来选目标
        int horOrVer = skl.skillItems.get(0).getTargetChoose();
        if (horOrVer >= 2) {
            if (horOrVer == 2) {//排
                targetList = getPosKeysByAOrB(id, target, num - 1, true);
            } else {
                targetList = getPosKeysByAOrB(id, target, num - 1, false);
            }
            targetList.add(0, target);
        } else if (horOrVer == 0) {
            targetList = getPosKeysByNum(id, target, num - 1);
            targetList.add(0, target);
        } else if (horOrVer == 1) {
            //随机取
            targetList = getPosKeysByRandom(id, target, num);
        }

        //技能发动前
        buffCreateHandle.getOne().sklShiFangBefCreateBuff(id, control, ac);
        buffTriggerHandle.getOne().sklShiFangBefTriggerBuff(id, control, list, ac);

        boolean isQunG = num > 1 ? true : false;
        //对每一个目标进行操作
        for (String tn : targetList) {
            //判断该技能是否允许闪躲
            if (skl.isAllowedSD == 1) {
                //判断是否闪躲
                if (isSanDuo(id, control, tn)) {
                    //闪躲动作
                    actionItem item = new actionItem(tn);
                    item.isSd = 1;
                    ac.putActionItem(item);
                    buffCreateHandle.getOne().noMzCreateBuff(id, control, tn, ac);
                    buffCreateHandle.getOne().sdCreateBuff(id, control, tn, ac);
                    continue;
                }
            }
            //命中时创建的buff（指的是添加到缓存）
            buffCreateHandle.getOne().mzCreateBuff(id, control, target, ac);
            //命中后执行一些操作
            buffTriggerHandle.getOne().mzTriggerBuff(id, control, target, list, ac);
            //fixme 注意：包装类每次赋值都会都会变成一个新的对象，但放入handleByStatusType处理的要求是同一地址对象，所以导致操作的不是同一个值
            //用一个类对象，将其变量作为其属性即可解决不能修改同一个变量的问题
            JSONObject data = new JSONObject();
            data.put("sumAttack", 0f);
            data.put("sumHurt", 0f);
            //Lock lock=new ReentrantLock();
            JSONObject copyOrder = JSON.parseObject(JSON.toJSONString(playerOrder));
            copyOrder.put("target", tn);
            //遍历该技能下的所有buff
            Iterator<skillItem> its = skl.skillItems.iterator();
            while (its.hasNext()) {
                //每一个技能点都会修改同一个sumAttack、sumHurt
                skillItem item = its.next();
                handleByStatusType(item, data, id, copyOrder, ac, isQunG, list);
            }
        }
        //list.add(ac);
        oneActionOver(id, control, target, list);
    }

    /**
     * fixme 注意：这里是释放技能攻击时创建buff
     * 攻击时产生的buff处理
     * 有statusType处理不同的buff
     * fixme 注意：这里是处理单个对象，外面已经循环过了
     */
    private void handleByStatusType(skillItem item, JSONObject data,
                                    String id, JSONObject playerOrder, action ac, boolean isQunG, List<action> list) throws Exception {

        float sumAttack = data.getFloat("sumAttack");
        float sumHurt = data.getFloat("sumHurt");
        //skill需要包含key跟lv
        JSONObject skill = playerOrder.getJSONObject("skill");
        String control = playerOrder.getString("control");
        String target = playerOrder.getString("target");

        if (item.statusType == AttackRule) {
            //计算总伤害、总攻击（后面的状态都是在此攻击下触发的）
            JSONObject res = countFightValue(id, control, target, item, skill, ac, isQunG, list);
            sumAttack = res.getFloat("sumAttack");
            sumHurt = res.getFloat("sumHurt");
            data.put("sumAttack", sumAttack);
            data.put("sumHurt", sumHurt);
        } else {
            //像那种攻击-item跟buff-item合在一个技能内的技能，都不要创建buff，直接触发buff效果即可
            //要求遍历攻击时创建
            if (item.createBuffMoment == isEachAttackerCreate) {
                buffCreateHandle.getOne().createBuffToTarget(id, isEachAttackerCreate,
                        control, target, skill, item, ac, data.getFloat("sumHurt"), data.getFloat("sumAttack"));
            }
            //直接进行触发
            if (item.triggerBuffMoment == isEachAttackerTriggre) {
                //直接调取触发的方法，而不是遍历buffs找到它再触发
                buffTriggerHandle.getOne().triggerBySkillItem(id, skill, item, control,
                        target, list, ac, data.getFloat("sumHurt"), data.getFloat("sumAttack"));
            }

        }
    }

    private float countAttack(float sumAttack, float fy) {
        return -(sumAttack * sumAttack / (fy * 8f + sumAttack));
    }

    private float getFyRate(float gj, float fy) {
        //防御自带减伤效果，最高0.8的减伤，防御/10000来决定这个0.5的减伤发挥效果
        if (fy < 0) fy = 0;
        float rate = 1 - (0.8f * (fy * 1.5f / gj));
        if (rate < 0.2f) rate = 0.2f;
        else if (rate > 1) rate = 1;
        //比如5000防御，0.25，总伤害只能达到0.75
        return rate;
    }

    /**
     * 计算总攻击、总伤害
     */
    private JSONObject countFightValue(String id, String control, String target, skillItem item,
                                       JSONObject skill, action ac, boolean isQunG, List<action> list) throws Exception {
        float sumHurt = 0f;
        float sumAttack = 0f;
        int lv = skill.getInteger("lv");
        String skillKey = skill.getString("key");
        JSONObject controlAttr = getAttrByPosKey(id, control);
        JSONObject targetAttr = getAttrByPosKey(id, target);
        skillItemTxRule attackRule = item.getTxRule(AttackUpRule);
        //要求技能中存在提升战斗
        if (attackRule != null && isInBuff(id, target, attackRule.paramInt)) {

        } else {
            attackRule = item.getTxRule(AttackRule);
        }

        //以攻击的百分之几作为攻击
        boolean isAddHp = attackRule.paramBool;
        float fixedKV = attackRule.getVal(lv, 0);
        float fixedBV = attackRule.getVal(lv, 1);

        //遍历执行者攻击增益、诅咒buff
        String gjName = "wg";
        String fyName = "wf";
        if (controlAttr.getInteger("type") == 1) {//物理计算
            gjName = "fg";
            fyName = "ff";
        }
        float wg_zy = getObjFinalZy(id, control, gjName) + 1;
        float wf_zy = getObjFinalZy(id, target, fyName) + 1;
        if (wf_zy < 0) wf_zy = 0f;//防御增益最少只能为0
        //遍历转化buff，将原属性进行取代
        float gj = getReplaceGJ(id, control, gjName);
        float fy = getReplaceGJ(id, target, fyName);
        if (fy < 0) fy = 0;
        //判断是否存在忽略防御
        if (isIgnoreAttr(id, control, "wf") || isInBuff(id, control, "ff")) {
            fy = 0f;
        }
        sumAttack = fixedKV * gj * wg_zy;
        sumAttack += fixedBV;

        //1.作用在执行者身上的伤害总计（主动攻击的所有伤害）
        float hurt_wg = 0f;
        //2.作用在被攻击者身上的受伤总计
        float cut_hurt_wg = 0f;
        //当回血时不需要计算受伤增益,也不用减防御
        if (!isAddHp) {
            //fixme fy/gj的一个比率 防御越高减伤比率越高
            /*float rate = (1 - (fy / gj)) > 1 ? 1 : (1 - fy / gj);
            if (rate <= 0.01f) {
                rate = 0.01f;
            }*/
            sumHurt = countAttack(sumAttack, fy * wf_zy);
            //sumHurt = -(sumAttack - fy * wf_zy) * getFyRate(gj, fy);

            hurt_wg = getObjFinalZy(id, control, "attackHurt");
            cut_hurt_wg = getObjFinalZy(id, target, "sufferHurt");
        } else {
            sumAttack = sumAttack;
        }
        //3.得出最终的伤害加成
        float hurt_zy = hurt_wg + cut_hurt_wg;
        sumHurt = sumHurt * ((hurt_zy + 1) < 0.1 ? 0.1f : (hurt_zy + 1));

        actionItem aci = new actionItem(target);
        //是否发生暴击
        boolean isBao = false;
        if ((isBao = isBaoJi(id, control, target))) {
            aci.isBaoJi = 1;
            float bjk = 2f;
            buff bf0 = getBuffInStatusType(id, control, BjKChangeRule);
            if (bf0 != null) {
                bjk = bf0.txRule.getVal(bf0.lever, 0);
            }
            sumHurt = sumHurt * bjk;

            //control打出暴击时创建
            buffCreateHandle.getOne().baojiCreateBuff(id, control, target, ac, sumHurt);
            //target受到暴击时创建
            buffCreateHandle.getOne().sufferBaojiCreateBuff(id, control, target, ac, sumHurt);
            //control打出暴击时触发（里面遍历的control）
            sumHurt = buffTriggerHandle.getOne().baojiTriggerBuff(id, control, target, list, ac, sumHurt);
            //target受到暴击时触发
            sumHurt = buffTriggerHandle.getOne().sufferBaojiTriggerBuff(id, control, target, list, ac, sumHurt);
        }
        //System.err.println(control + "伤害：" + sumAttack + " 是否暴击：" + aci.isBaoJi);
        //是否转回血
        if (isAddHp) {
            float bjk = 1f;
            if (isBao) bjk = 2f;
            //判断是否有减回血的buff
            float xueZy = buffZyHandle.getOne().getSufferCureZy(id, target);
            sumAttack = sumAttack * (bjk + xueZy);
            //最终回血
            sumAttack = finalCureHandle(id, control, target, sumAttack);
            if (isInBuff(id, target, 38)) {
                //目标处于加血转减血
                sumAttack = -sumAttack;
            }
            int isDie = 0;
            //将攻击转回血
            float xue = targetAttr.getJSONObject("prop").getFloat("xue") + sumAttack;
            if (xue > targetAttr.getJSONObject("prop").getFloat("max_xue")) {
                xue = targetAttr.getJSONObject("prop").getFloat("max_xue");
            } else if (xue < 0) {
                xue = 0f;
                isDie = 1;
            }
            targetAttr.getJSONObject("prop").put("xue", xue);

            aci.isDie = isDie;
            aci.statusType = item.statusType;
            aci.value = Float.valueOf(sumAttack).intValue();
            ac.putActionItem(aci);
        } else {
            //打不动的情况
            if (sumHurt >= 0) sumHurt = -1f;
            //control对target造成伤害时创建buff
            buffCreateHandle.getOne().hurtCreateBuff(id, control, target, ac, sumHurt);
            //control对target造成伤害时触发buff
            sumHurt = buffTriggerHandle.getOne().hurtTriggerBuff(id, control, target, list, ac, sumHurt);
            //目标受伤后创建buff
            buffCreateHandle.getOne().sufferHurtCreateBuff(id, control, target, ac, sumHurt);
            //目标受伤后触发buff
            sumHurt = buffTriggerHandle.getOne().sufferHurtTriggerBuff(id, control, target, list, ac, sumHurt, isQunG);
            //获得最终伤害
            sumHurt = finalHurtHandle(id, control, target, sumHurt);
            //对法宝效果的处理
            sumHurt = fabaoHurtHandle(id, control, target, sumHurt);
            //满足某些特殊buff层数时处理
            //sumHurt = enoughBuffAddsHandle(id, control, target, ac, sumHurt);
            //加（减）血
            float xue = targetAttr.getJSONObject("prop").getFloat("xue") + sumHurt;
            if (xue < 0) {
                xue = 0f;
            } else if (xue > targetAttr.getJSONObject("prop").getFloat("max_xue")) {
                xue = targetAttr.getJSONObject("prop").getFloat("max_xue");
            }
            //因为json操作的是同一个对象，所以不需要逐一覆盖
            targetAttr.getJSONObject("prop").put("xue", xue);

            if (xue == 0) {
                buffCreateHandle.getOne().isDieCreateBuff(id, control, target, ac, sumHurt);
                buffTriggerHandle.getOne().dieTriggerBuff(id, control, target, list, ac);
            } else {
                //处理目标低血量创建buff
                buffCreateHandle.getOne().lowXueCreateBuff(id, control, target, ac, sumHurt);
            }
            //目标死亡状态的判断跟设置
            int targetIsDie = isDieByPosKey(id, target);
            aci.isDie = targetIsDie;
            aci.statusType = item.statusType;
            aci.value = Float.valueOf(sumHurt).intValue();
            ac.putActionItem(aci);

            buffTriggerHandle.getOne().countXueDoneTriggerBuff(id, control, target, list, ac, isQunG);
        }
        JSONObject res = new JSONObject();
        res.put("sumHurt", sumHurt);
        res.put("sumAttack", sumAttack);
        return res;
    }

    /**
     * 处理普通攻击
     */
    public void simpleAttackHandle(String id, String control, String target, List<action> list, boolean isNewAc) throws Exception {
        action ac0 = new action(control, null);
        if (buffTriggerHandle.getOne()
                .attackBeforeTriggerBuff(id, control, target, list, ac0) == -1) {
            list.add(ac0);
            return;
        }

        JSONObject controlAttr = getAttrByPosKey(id, control);
        JSONObject targetAttr = getAttrByPosKey(id, target);
        //根据目标血量判断是否更换一个新目标
        String target0 = getNewTarget(id, target);
        if (target0 == null) {
            return;
        }
        if (!target.equals(target0)) {
            target = target0;
            targetAttr = getAttrByPosKey(id, target);
        }
        //是否需要创建一个ac，蓝不足的情况会使用之前创建的ac
        if (isNewAc) {
            list.add(new action(control, null));
        }
        action ac = list.get(list.size() - 1);
        //判断是否闪躲
        if (isSanDuo(id, control, target)) {
            //闪躲动作
            actionItem item = new actionItem(target);
            item.isSd = 1;
            ac.putActionItem(item);

            buffCreateHandle.getOne().noMzCreateBuff(id, control, target, ac);
            buffCreateHandle.getOne().sdCreateBuff(id, control, target, ac);
            return;
        }
        //命中时创建的buff
        buffCreateHandle.getOne().mzCreateBuff(id, control, target, ac);
        //命中后执行一些操作
        buffTriggerHandle.getOne().mzTriggerBuff(id, control, target, list, ac);
        Float value = null;
        //fixme 注意：第一阶段先找执行的攻击buff，目标的防御buff
        String gjName = "wg";
        String fyName = "wf";
        if (controlAttr.getInteger("type") == 1) {//物理计算
            gjName = "fg";
            fyName = "ff";
        }
        //fixme 计算增益后的物攻
        float wg_zy = getObjFinalZy(id, control, gjName) + 1;
        float wf_zy = getObjFinalZy(id, target, fyName) + 1;
        if (wf_zy < 0) wf_zy = 0f;//防御增益最少只能为0
        //遍历转化buff，将原属性进行取代
        float gj = getReplaceGJ(id, control, gjName);
        float fy = getReplaceGJ(id, target, fyName);
        if (fy < 0) fy = 0;
        //判断是否存在忽略防御
        if (isIgnoreAttr(id, control, "wf") || isIgnoreAttr(id, control, "ff")) {
            fy = 0f;
        }

        /*float rate = (1 - (fy / gj)) > 1 ? 1 : (1 - fy / gj);
        if (rate <= 0.01f) {
            rate = 0.01f;
        }*/
        value = countAttack(gj * wg_zy, fy * wf_zy);
        //value = -(gj * wg_zy - fy * wf_zy) * getFyRate(gj, fy);

        float hurt_wg = getObjFinalZy(id, control, "attackHurt");
        //2.作用在被攻击者身上的受伤总计（注意：目标身上的增伤是诅咒，所以得负号）
        float cut_hurt_wg = getObjFinalZy(id, target, "sufferHurt");
        //3.得出最终的伤害加成
        float hurt_zy = hurt_wg + cut_hurt_wg;
        value = value * ((hurt_zy + 1) < 0.1 ? 0.1f : (hurt_zy + 1));
        //System.err.println("第二阶段伤害：" + value + " 伤害增益：" + (hurt_zy + 1));

        //打不动的情况
        if (value >= 0) value = -1f;
        actionItem item = new actionItem(target);
        //是否发生暴击
        if (isBaoJi(id, control, target)) {
            item.isBaoJi = 1;
            float bjk = 2f;
            buff bf0 = getBuffInStatusType(id, control, BjKChangeRule);
            if (bf0 != null) {
                bjk = bf0.txRule.getVal(bf0.lever, 0);
            }
            value *= bjk;
            //control打出暴击时创建
            buffCreateHandle.getOne().baojiCreateBuff(id, control, target, ac, value);
            //target受到暴击时创建
            buffCreateHandle.getOne().sufferBaojiCreateBuff(id, control, target, ac, value);
            //control打出暴击时触发
            value = buffTriggerHandle.getOne().baojiTriggerBuff(id, control, target, list, ac, value);
            //target受到暴击时触发
            value = buffTriggerHandle.getOne().sufferBaojiTriggerBuff(id, control, target, list, ac, value);
        }
        //control对target造成伤害时创建
        buffCreateHandle.getOne().hurtCreateBuff(id, control, target, ac, value);
        //control对target造成伤害时触发buff
        value = buffTriggerHandle.getOne().hurtTriggerBuff(id, control, target, list, ac, value);
        //目标受伤后创建buff
        buffCreateHandle.getOne().sufferHurtCreateBuff(id, control, target, ac, value);
        //目标受伤后触发buff
        value = buffTriggerHandle.getOne().sufferHurtTriggerBuff(id, control, target, list, ac, value, false);
        //最终伤害的增加、减少处理
        value = finalHurtHandle(id, control, target, value);
        //法宝伤害处理
        value = fabaoHurtHandle(id, control, target, value);
        //加（减）血
        float xue = targetAttr.getJSONObject("prop").getFloat("xue") + value;
        if (xue < 0) {
            xue = 0f;
        } else if (xue > targetAttr.getJSONObject("prop").getFloat("max_xue")) {
            xue = targetAttr.getJSONObject("prop").getFloat("max_xue");
        }
        //因为json操作的是同一个对象，所以不需要逐一覆盖
        targetAttr.getJSONObject("prop").put("xue", xue);

        if (xue == 0) {
            buffCreateHandle.getOne().isDieCreateBuff(id, control, target, ac, value);
            buffTriggerHandle.getOne().dieTriggerBuff(id, control, target, list, ac);
        } else {
            //处理目标低血量创建buff
            buffCreateHandle.getOne().lowXueCreateBuff(id, control, target, ac, value);
        }
        //目标死亡状态
        int targetIsDie = isDieByPosKey(id, target);
        item.isDie = targetIsDie;
        item.value = value.intValue();
        ac.putActionItem(item);

        buffTriggerHandle.getOne().countXueDoneTriggerBuff(id, control, target, list, ac, false);

        oneActionOver(id, control, target, list);
    }

    /**
     * 最终伤害结果处理
     */
    public float finalHurtHandle(String id, String control, String target, float value) {
        //判断是否存在最终增伤属性
        JSONObject prop1 = getAttrByPosKey(id, control).getJSONObject("prop");
        float addHurt = 0;
        if (prop1.get("final_hurt_add") != null) {
            addHurt = prop1.getFloat("final_hurt_add");
        }
        JSONObject prop2 = getAttrByPosKey(id, target).getJSONObject("prop");
        float cutHurt = 0;
        if (prop2.get("final_hurt_cut") != null) {
            cutHurt = prop2.getFloat("final_hurt_cut");
        }
        value += value * (addHurt - cutHurt);
        return value;
    }

    public float fabaoHurtHandle(String id, String control, String target, float value) {
        float k = 0f;
        float addHurt = 0f;
        float cutHurt = 0f;
        int type1 = -1;//针对的类型 人物、宠物、怪物
        int type2 = -1;
        int mdType1 = -1;//双方类型 0人物 1宠物 2怪物 4ai 5伙伴
        int mdType2 = -1;
        JSONObject prop1 = getAttrByPosKey(id, control).getJSONObject("prop");
        mdType1 = getTargetByPosKey(id, control).getInteger("type");
        if (prop1.containsKey("fbEffect")) {
            JSONObject fbEffect = prop1.getJSONObject("fbEffect");
            addHurt = fbEffect.getFloat("addHurt");
            type1 = fbEffect.getInteger("type");
        }
        JSONObject prop2 = getAttrByPosKey(id, target).getJSONObject("prop");
        mdType2 = getTargetByPosKey(id, target).getInteger("type");
        if (prop2.containsKey("fbEffect")) {
            JSONObject fbEffect = prop2.getJSONObject("fbEffect");
            cutHurt = fbEffect.getFloat("cutHurt");
            type2 = fbEffect.getInteger("type");
        }
        if (mdType1 == 0) {//攻击方为人物
            if (mdType2 == 0) {//被攻击方为人物
                //如果攻击方法宝是针对人物则计算增伤
                if (type1 == 0) k += addHurt;
                //如果被攻击方法宝是针对人物则计算减免
                if (type2 == 0) k -= cutHurt;
            } else if (mdType2 == 1) {//被攻击方为宠物
                //如果攻击方法宝是针对宠物则计算增伤
                if (type1 == 1) k += addHurt;
            } else if (mdType2 == 2) {//被攻击方为怪物
                //如果攻击方法宝是针对怪物物则计算增伤
                if (type1 == 2) k += addHurt;
            }
        } else if (mdType1 == 1) {//攻击方为宠物
            //被攻击方是人物并且法宝也是针对宠物的话，只需要减免
            if (mdType2 == 0 && type2 == 1) k -= cutHurt;
        } else if (mdType1 == 2) {//攻击方为怪物
            //被攻击方是人物并且法宝也是针对怪物的话，只需要减免
            if (mdType2 == 0 && type2 == 2) k -= cutHurt;
        }

        k = 1 + k;
        if (k < 0) k = 0;
        return value * k;
    }

    /**
     * 最终治疗结果处理
     */
    public Float finalCureHandle(String id, String control, String target, float value) {
        //判断是否存在最终增伤属性
        JSONObject prop1 = getAttrByPosKey(id, control).getJSONObject("prop");
        float addHurt = 0;
        if (prop1.get("final_cure_add") != null) {
            addHurt = prop1.getFloat("final_cure_add");
        }
        JSONObject prop2 = getAttrByPosKey(id, target).getJSONObject("prop");
        float cutHurt = 0;
        if (prop2.get("final_cure_cut") != null) {
            cutHurt = prop2.getFloat("final_cure_cut");
        }
        value += value * (addHurt - cutHurt);
        return value;
    }

    /**
     * 一个动作执行之后的处理
     */
    public void oneActionOver(String id, String control, String target, List<action> acList) throws Exception {

    }

    /**
     * 连击\反击\混乱 普攻
     */
    public void noBuffAttackHandle(String id, String control, String target, List<action> list, action ac, int statusType, float gjK) throws Exception {
        //目标已死无需攻击
        if (isDie(id, control) || isDie(id, target)) {
            return;
        }
        //攻击前触发的buff，-1阻止攻击 0则继续
        if (buffTriggerHandle.getOne()
                .attackBeforeTriggerBuff(id, control, target, list, ac) == -1) {
            return;
        }

        JSONObject controlAttr = getAttrByPosKey(id, control);
        JSONObject targetAttr = getAttrByPosKey(id, target);
        //根据目标血量判断是否更换一个新目标
        String target0 = getNewTarget(id, target);
        if (target0 == null) {
            return;
        }
        if (!target.equals(target0)) {
            target = target0;
            targetAttr = getAttrByPosKey(id, target);
        }
        actionItem item = null;

        if (statusType == FanJiRule) {
            //因为前端的结构是 l0打r0时，r0进行反击（子项,control为r0，target为l0），
            // ac的control是l0，要是这里设置为target（即子项目标为l0），就会导致前端显示l0打l0
            item = new actionItem(control);
            item.statusType = statusType;
        } else if (statusType == LianJiRule) {
            item = new actionItem(target);
            item.statusType = statusType;
        } else if (statusType == GuRule) {
            item = new actionItem(target);
            item.statusType = AttackRule;//只有混乱状态才是普攻
        }
        //判断是否闪躲
        if (isSanDuo(id, control, target)) {
            //闪躲动作
            item.isSd = 1;
            ac.putActionItem(item);
            return;
        }

        float value = 0;
        //fixme 注意：第一阶段先找执行的攻击buff，目标的防御buff
        String gjName = "wg";
        String fyName = "wf";
        if (controlAttr.getInteger("type") == 1) {//物理计算
            gjName = "fg";
            fyName = "ff";
        }
        //fixme 计算增益后的物攻
        float wg_zy = getObjFinalZy(id, control, gjName) + 1;
        float wf_zy = getObjFinalZy(id, target, fyName) + 1;
        if (wf_zy < 0) wf_zy = 0f;//防御增益最少只能为0
        //遍历转化buff，将原属性进行取代
        float gj = getReplaceGJ(id, control, gjName) * gjK;
        float fy = getReplaceGJ(id, target, fyName);
        if (fy < 0) fy = 0;
        //判断是否存在忽略防御
        if (isIgnoreAttr(id, control, "wf") || isIgnoreAttr(id, control, "ff")) {
            fy = 0f;
        }

        /*float rate = (1 - (fy / gj)) > 1 ? 1 : (1 - fy / gj);
        if (rate <= 0.01f) {
            rate = 0.01f;
        }*/
        value = countAttack(gj * wg_zy, fy * wf_zy);
        //value = -(gj * wg_zy - fy * wf_zy) * getFyRate(gj, fy);

        float hurt_wg = getObjFinalZy(id, control, "attackHurt");
        //2.作用在被攻击者身上的受伤总计（注意：目标身上的增伤是诅咒，所以得负号）
        float cut_hurt_wg = getObjFinalZy(id, target, "sufferHurt");
        //3.得出最终的伤害加成
        float hurt_zy = hurt_wg + cut_hurt_wg;
        //value = value * (hurt_zy + 1);
        //System.err.println("第二阶段伤害：" + value + " 伤害增益：" + (hurt_zy + 1));
        value = value * ((hurt_zy + 1) < 0.1 ? 0.1f : (hurt_zy + 1));
        //打不动的情况
        if (value > 0) value = 0f;

        //获得最终伤害
        //是否发生暴击
        if (isBaoJi(id, control, target)) {
            item.isBaoJi = 1;
            float bjk = 2f;
            buff bf0 = getBuffInStatusType(id, control, BjKChangeRule);
            if (bf0 != null) {
                bjk = bf0.txRule.getVal(bf0.lever, 0);
            }
            value *= bjk;
        }
        //加（减）血
        float xue = targetAttr.getJSONObject("prop").getFloat("xue") + value;
        if (xue < 0) {
            xue = 0f;
        } else if (xue > targetAttr.getJSONObject("prop").getFloat("max_xue")) {
            xue = targetAttr.getJSONObject("prop").getFloat("max_xue");
        }
        //因为json操作的是同一个对象，所以不需要逐一覆盖
        targetAttr.getJSONObject("prop").put("xue", xue);
        if (xue == 0) {
            buffCreateHandle.getOne().isDieCreateBuff(id, control, target, ac, value);
            buffTriggerHandle.getOne().dieTriggerBuff(id, control, target, list, ac);
        }

        if (statusType == FanJiRule) {
            //不要在这里创建任何buff
            //反击后创建的buff
            //buffCreateHandle.getOne().fanjiCreateBuff(id, control, target, ac);
        } else if (statusType == GuRule) {
            //只有混乱才会调取攻击
            item.tipKey = "hunluan";
        }
        //目标死亡状态
        int targetIsDie = isDieByPosKey(id, target);
        item.isDie = targetIsDie;
        item.value = (int) value;
        ac.putActionItem(item);
    }


}
