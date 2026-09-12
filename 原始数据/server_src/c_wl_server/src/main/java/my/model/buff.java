package my.model;

import com.alibaba.fastjson2.JSONObject;

import static my.fightUtils.fightUtils.getAttrByPosKey;
import static my.model.skillItemRuleType.*;


/**
 * buff一生成就独立于技能，效果通过statusType来区分
 * fixme 注意：buff一定是放到缓存上的，不用放入缓存的都不建立buff
 */
public class buff {
    //指定隶属于哪个技能
    public String key;
    //buff的创建者站位
    public String builderPosKey;
    //等级 创建buff时直接计算出来
    public int lever;
    //buff绑定的目标
    public String target;
    //状态类型 skillItem类中查看具体描述
    public int statusType;
    //直接引用原skillItemTxRule
    public skillItemTxRule txRule;
    //buff创建时机 skillItemCreateMoment
    public int createBuffMoment;
    //buff触发时机 skillItemTriggerMoment
    public int triggerBuffMoment;

    //缓存四个基本规则 -1目标规则 -2效果规则 -3触发的概率规则 -4叠加规则
    //有效期 需要缓存，每回合需要-- 或者 次数--
    public effectRule effectRule;
    //叠加 需要缓存，每次叠加buff时需要计数，不能超过最大计数
    public addRule addRule;
    //生效条件
    public conditionRule conditionRule;
    //创建buff时的概率
    public float createPv = 1;
    //触发buff时的概率
    public float triggerPv = 1;
    //需要缓存的对象（比如属性转化）
    public Object valueObj;
    //总伤害
    public float sumHurt;
    //总攻击
    public float sumAttack;


    /**
     * buff创建的入口
     */
    public buff(String builderPosKey, String key, int lever, String target, skillItem item) {
        this.builderPosKey = builderPosKey;
        this.key = key;
        this.lever = lever;
        this.target = target;
        this.statusType = item.statusType;
        this.createBuffMoment = item.createBuffMoment;
        this.triggerBuffMoment = item.triggerBuffMoment;

        this.txRule = item.getTxRule(item.statusType);
        this.createPv = item.getCreateBuffProbability(lever);
        this.triggerPv = item.getTriggerBuffProbability(lever);
        this.bindEffectRule(item.getHuihe(lever), item.getTimes(lever), item.getEfCoolHuihe(lever));
        this.bindAddRule(item.getMaxAddNum(), item.getInitAddNum());
        this.bindConditionRule(item.getCondition());
    }

    /**
     *
     */
    public buff addValueObj(Object valueObj) {
        this.valueObj = valueObj;
        return this;
    }

    public buff addSumHurt(float sumHurt, float sumAttack) {
        this.sumHurt = sumHurt;
        this.sumAttack = sumAttack;
        return this;
    }

    public void bindEffectRule(Integer huihe, Integer times, Integer efCoolHuihe) {
        if (huihe == null || huihe == -1) huihe = null;
        if (times == null || times == -1) times = null;
        if (efCoolHuihe == null || efCoolHuihe == -1) efCoolHuihe = null;
        this.effectRule = new effectRule(huihe, times, efCoolHuihe);
    }

    private void bindAddRule(int maxAddNum, int nowAddNum) {
        this.addRule = new addRule(maxAddNum, nowAddNum);
    }

    private void bindConditionRule(skillItemBaseRule baseRule) {
        if (baseRule == null) return;
        this.conditionRule = new conditionRule(baseRule.paramInt);
        this.conditionRule.xueK = baseRule.getVal(lever, 0);
    }

    public int getConditionStatusType() {
        if (this.conditionRule != null && this.conditionRule.statusType > 0)
            return this.conditionRule.statusType;
        return 0;
    }

    /**
     * 是否存在低血量条件
     */
    public boolean isNeedConditionRuleXueK() {
        if (this.conditionRule != null && this.conditionRule.xueK > 0) {
            return true;
        }
        return false;
    }

    /**
     * 是否低于某血量
     */
    public boolean isLowXue(String id) {
        float k = this.conditionRule.xueK;
        JSONObject attr = getAttrByPosKey(id, target);
        if (attr.getJSONObject("prop").getFloat("xue")
                < attr.getJSONObject("prop").getFloat("max_xue") * k) {
            return true;
        }
        return false;
    }

    /**
     * 回合数或次数--
     */
    public void updateEffect() {
        if (this.effectRule.huihe != null) {
            this.effectRule.huihe--;
        }
        if (this.effectRule.efCoolHuihe != null) {
            this.effectRule.efCoolHuihe--;
            if (this.effectRule.efCoolHuihe <= 0)
                this.effectRule.efCoolHuihe = 0;//为0表示冷却结束未触发
        }
    }

    /**
     * 更新次数
     */
    public boolean updateEffectTimes() {
        if (this.effectRule != null && this.effectRule.times != null) {
            if (this.effectRule.times <= 0) {
                return false;
            }
            this.effectRule.times--;
            return true;
        }
        return false;
    }

    /**
     * 是否失效
     */
    public boolean isNoEffect() {
        if ((this.effectRule.huihe != null && this.effectRule.huihe <= 0)
                || (this.effectRule.times != null && this.effectRule.times <= 0)) return true;
        return false;
    }

    /**
     * 是否处于冷却中
     */
    public boolean isEfCooling() {
        if ((this.effectRule.efCoolHuihe != null
                && this.effectRule.efCoolHuihe > 0)) return true;
        //发动后重置
        this.effectRule.efCoolHuihe = this.effectRule.efCoolHuiheSum;
        return false;
    }

    /**
     * 获取buff的有效回合数
     */
    public int getEffectHuihe() {
        if (this.effectRule.huihe != null) return this.effectRule.huihe;
        return 0;
    }

    /**
     * 同一个buff时刷新buff状态
     */
    public boolean updateStatus(buff bf) {
        //判断两buff是否属于同一类型，是就更新其值
        if (this.isSame(bf.key, bf.statusType, bf.target, bf.txRule.paramStr)) {
            this.update(bf.effectRule.huihe, bf.effectRule.times, bf.effectRule.efCoolHuihe, bf.valueObj, bf.sumHurt, bf.sumAttack);
            return true;
        }
        return false;
    }

    /**
     * 刷新该状态
     */
    private void update(Integer huihe, Integer times, Integer efCoolHuihe, Object valueObj, float sumHurt, float sumAttack) {
        if (this.effectRule != null) {
            this.effectRule.huihe = huihe;
            this.effectRule.times = times;
            this.effectRule.efCoolHuihe = efCoolHuihe;
            this.effectRule.efCoolHuiheSum = efCoolHuihe;
        }
        if (this.addRule != null) {
            this.addRule.nowAddNum++;
            //System.err.println("当前层数："+this.addRule.nowAddNum);
            if (this.addRule.nowAddNum > this.addRule.maxAddNum) {
                this.addRule.nowAddNum = this.addRule.maxAddNum;
            }
        }
        if (valueObj != null) {
            this.valueObj = valueObj;
        }
        this.sumHurt = sumHurt;
        this.sumAttack = sumAttack;
    }

    /*
     * 判断是否为同一个对象，同一中状态类型的buff*/

    private boolean isSame(String key, Integer statusType, String target, String attrName) {
        if (statusType == GainRule || statusType == CurseRule || statusType == HuiXueRule) {
            //增益\诅咒\回血（当技能key相同时才能算是同一个）
            if (!key.equals(this.key)) {
                return false;
            }
            //加持的属性名不同也不能算是同一个buff
            if (attrName != null && !attrName.equals(txRule.paramStr)) {
                return false;
            }
        }

        if (this.target.equals(target) && this.statusType == statusType) {
            return true;
        }
        return false;
    }

    /**
     * 是否达到指定层数
     */
    public boolean isSameAdds(int adds) {
        if (this.addRule.nowAddNum == adds) {
            return true;
        }
        return false;
    }

    public int getNowAddNum() {
        return this.addRule.nowAddNum;
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

class addRule {
    public int maxAddNum;
    //当前叠加层数
    public int nowAddNum;

    public addRule(int maxAddNum, int nowAddNum) {
        this.maxAddNum = maxAddNum;
        this.nowAddNum = nowAddNum;
    }
}

class effectRule {
    //因为times可能为null，所以用包装类方便处理
    public Integer huihe;
    public Integer times;
    public Integer efCoolHuihe;
    public Integer efCoolHuiheSum;

    public effectRule(Integer huihe, Integer times, Integer efCoolHuihe) {
        this.huihe = huihe;
        this.times = times;
        this.efCoolHuihe = 0;//初始时未触发过，所以标记为0，触发后设置为efCoolHuiheSum
        this.efCoolHuiheSum = efCoolHuihe;
    }
}

/**
 * 生效条件
 */
class conditionRule {
    //处于某种状态
    public int statusType;
    //血量低于
    public float xueK;

    public conditionRule(int statusType) {
        this.statusType = statusType;
    }

    public conditionRule(float xueK) {
        this.xueK = xueK;
    }
}
