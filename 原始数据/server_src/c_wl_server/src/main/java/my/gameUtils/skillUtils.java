package my.gameUtils;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.model.skill;
import my.model.skillItem;
import my.model.skillItemCreateMoment;
import my.model.skillItemTriggerMoment;
import my.utils.strUtils;
import my.utils.systemUtils;
import org.apache.commons.lang3.SystemUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.Vector;

import static my.model.skillItemBaseRule.*;
import static my.model.skillItemRuleType.*;
import static my.model.skillItemTxRule.*;

/**
 * 技能相关
 */
public class skillUtils {
    private static skillUtils skillUtils;

    /**
     * 获取技能 fixme （战斗计算时的技能，不是计算属性时的技能数据，计算属性时到skillData获取）
     * 1.调用fixedParamsByLv初始化技能参数
     * 2.调用fixedAttackValue获取最终的攻击、防御、伤害值
     */
    public skill getSkill(String key) {
        skill skl = null;
        switch (key) {
            case "100210000001": {//墨家心法
                skl = new skill(key).addMaxLv(2);
                skl.bindSkillData(0, "ms/dj/zs");
                skl.putLearnResultRule("ll", 16, 0, 0)
                        .putLearnResultRule("nl", 16, 0, 0);
                break;
            }
            case "100210000002": {//猛虎纵
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ms");
                skl.putLearnResultRule("wg", 3, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.78f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                //流血
                item = new skillItem(4);
                item.addTxRule(
                        createLiuXueRule(0f, 0.3f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000003": {//破天吼
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ms");
                skl.putLearnResultRule("max_xue", 6, 100, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 2f);
                Vector<skillItem> list = new Vector<>();
                //诅咒敌方单体
                skillItem item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("sufferHurt", 0.06f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(4, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("sufferCure", 0f, -0.3f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(4, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000004": {//杀气诀
                skl = new skill(key).addMaxLv(8);
                skl.bindSkillData(0, "ms");
                skl.putLearnResultRule("ll", 36f, 0, 0)
                        .putLearnResultRule("nl", 12f, 0, 0);
                break;
            }
            case "100210000005": {// 连斩
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ms");
                skl.putLearnResultRule("ff", 3, 0, 0);
                skl.bindTriggerCondition(0f, 0f, 0, 0f, 0.03f, 1);
                skl.bindCoolingRule(0f, 2f);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 1.02f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                //第二次攻击
                item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.51f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                //第三次攻击
                item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.3f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                //受伤增加30%
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("sufferHurt", 0f, 0.3f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000006": {//血祭
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ms");
                skl.putLearnResultRule("wf", 3, 0, 0);
                skl.bindTriggerCondition(0f, 0f, 0, 0f, 0.03f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.5f, 20f, 200f),
                        createAttackUpRule(4, 0.03f, 1.97f, 40f, 400f, "*"));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000007": {//狂龙吼
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ms");
                skl.putLearnResultRule("bj", 6, 20, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 2f);
                Vector<skillItem> list = new Vector<>();
                //增加攻击伤害
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0.05f, 0.55f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                //降低物防
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("wf", 0f, -0.8f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                //降低法防
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("ff", 0f, -0.8f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            /*case "3007": {//荡魂吼
                skl = new skill(key);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 1f);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.bindAttackRule(false, 0.03f, 0.5f, 20f, 200f);
                //目标数量
                item.bindTargetRule(2, 0f, 1f, 1f);
                //触发概率
                item.bindProbabilityRule(0f, 1f);
                list.add(item);

                item = new skillItem(2);
                item.bindCurseRule("sufferCure", 0f, -0.3f, 1);
                item.bindEffectRule(5, null);
                item.isEachAttackerCreate = 1;
                item.isEachAttackerTriggre = 1;
                item.bindTargetRule(2, 0f, 1f, 1f);
                item.bindProbabilityRule(0f, 1f);
                list.add(item);
                skl.skillItems = list;
                break;
            }*/
            case "100210000008": {//猛虎纵（遁甲）
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "dj");
                skl.putLearnResultRule("wg", 3, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.78f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000009": {//破天吼(遁甲)
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "dj");
                skl.putLearnResultRule("max_xue", 6, 100, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 2f);
                Vector<skillItem> list = new Vector<>();
                //诅咒敌方全体
                skillItem item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("sufferHurt", 0.01f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 100f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(4, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000010": {//杀气诀
                skl = new skill(key).addMaxLv(8);
                skl.bindSkillData(0, "dj");
                skl.putLearnResultRule("ll", 12f, 0, 0)
                        .putLearnResultRule("nl", 36f, 0, 0);
                break;
            }
            case "100210000011": {//破甲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "dj");
                skl.putLearnResultRule("wg", 3, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.015f, 0.2f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                //减防
                item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("wf", -0.01f, -0.04f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(4, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("ff", -0.01f, -0.04f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(4, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                //增伤
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("sufferHurt", 0.01f, 0.05f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(4, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000012": {//战魂歌
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "dj");
                skl.putLearnResultRule("wg", 3, 0, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 4f);
                Vector<skillItem> list = new Vector<>();
                //诅咒敌方全体
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0.01f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(1, 0f, 100f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(1);
                item.addTxRule(
                        createGainRule("sufferHurt", -0.02f, -0.1f, 1));
                item.addBaseRules(
                        createTargetRule(1, 0f, 100f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000013": {//挫骨
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "dj");
                skl.putLearnResultRule("wg", 3, 0, 0);
                skl.bindTriggerCondition(0f, 0f, 0, 0f, 0.03f, 1);
                skl.bindCoolingRule(0f, 2f);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.93f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                //吸血
                item = new skillItem(6);
                item.addTxRule(
                        createXiXueRule(0f, 0.3f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            /*case "3014": {//玄武护体
                skl = new skill(key);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 1f);
                Vector<skillItem> list = new Vector<>();
                //诅咒敌方全体
                skillItem item = new skillItem(1);
                item.bindGainRule("sufferHurt", 0f, 0.4f, 1);
                item.bindEffectRule(2, null);
                item.isEachAttackerCreate = 1;
                item.isEachAttackerTriggre = 1;
                item.bindTargetRule(1, 0f, 6f, 6f);
                item.bindProbabilityRule(0f, 1f);
                list.add(item);
                skl.skillItems = list;
                break;
            }*/
            case "100210000014": {//
                skl = new skill(key).addMaxLv(2);
                skl.bindSkillData(0, "qm/ty/fs");
                skl.putLearnResultRule("zl", 16f, 0, 0)
                        .putLearnResultRule("js", 16f, 0, 0);
                break;
            }
            case "100210000015": {//荡魔曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "qm");
                skl.putLearnResultRule("fg", 3f, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.02f, 1.05f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000016": {//灵脉曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "qm");
                skl.putLearnResultRule("max_xue", 6f, 100f, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindCoolingRule(0f, 2f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //解除一个中毒状态
                skillItem item = new skillItem(12);
                item.addTxRule(
                        createRemoveRule(2, 3, 4, 9, 10));
                item.addBaseRules(
                        createTargetRule(1, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000017": {//
                skl = new skill(key).addMaxLv(8);
                skl.bindSkillData(0, "qm");
                skl.putLearnResultRule("zl", 36f, 0, 0)
                        .putLearnResultRule("js", 12f, 0, 0);
                break;
            }
            case "100210000018": {//魔魂曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "qm");
                skl.putLearnResultRule("max_xue", 6f, 100, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.015f, 0.38f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 1f, 0f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(MoHuaRule);
                item.addTxRule(
                        createEmptyRule(MoHuaRule));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000019": {//夺魂曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "qm");
                skl.putLearnResultRule("fg", 3f, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.52f, 20f, 200f),
                        createAttackUpRule(9, 0.03f, 1.97f, 40f, 400f, "*"));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000020": {//缚灵曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "qm");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.3f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                //降低出手速和闪避
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("css", -0.02f, -0.1f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("sd", -0.02f, -0.1f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            /*case "3022": {//洗心曲
                skl = new skill(key);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //解除所有负面状态
                skillItem item = new skillItem(12);
                List<Integer> statusTypeList = new ArrayList<>();
                statusTypeList.add(2);
                statusTypeList.add(3);
                statusTypeList.add(4);
                statusTypeList.add(9);
                statusTypeList.add(10);
                item.bindRemoveRule(statusTypeList);
                item.bindTargetRule(0, 0f, 1f, 1f);
                item.bindProbabilityRule(0f, 1f);
                list.add(item);

                skl.skillItems = list;
                break;
            }*/
            case "100210000021": {//荡魔曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ty");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.02f, 1.05f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000022": {//灵脉曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ty");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindCoolingRule(0f, 2f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //解除一个中毒、流血、蛊状态
                skillItem item = new skillItem(12);
                item.addTxRule(
                        createRemoveRule(2, 3, 10));
                item.addBaseRules(
                        createTargetRule(1, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);

                item = new skillItem(1);
                item.addTxRule(
                        createGainRule("sufferHurt", -0.03f, -0.1f, 1));
                item.addBaseRules(
                        createTargetRule(1, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000023": {//
                skl = new skill(key).addMaxLv(8);
                skl.bindSkillData(0, "ty");
                skl.putLearnResultRule("zl", 12f, 0, 0)
                        .putLearnResultRule("js", 36f, 0, 0);
                break;
            }
            case "100210000024": {//养生曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ty");
                skl.putLearnResultRule("ff", 3f, 0, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(true, 0.03f, 0.8f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(1, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000025": {//天籁曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ty");
                skl.putLearnResultRule("ff", 3f, 0, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(true, 0.015f, 0.3f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(1, 0f, 100f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                //回血
                item = new skillItem(HuiXueRule);
                item.addTxRule(
                        createHuiXueRule(0f, 0.35f, 0));
                item.addBaseRules(
                        createTargetRule(1, 0f, 100f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(4, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            /*case "3028": {//魔音壁
                skl = new skill(key);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //诅咒敌方全体
                skillItem item = new skillItem(1);
                item.bindGainRule("sufferHurt", 0.05f, 0.1f, 1);
                item.bindEffectRule(5, null);
                item.isEachAttackerCreate = 1;
                item.isEachAttackerTriggre = 1;
                item.bindTargetRule(0, 0f, 1f, 1f);
                item.bindProbabilityRule(0f, 1f);
                list.add(item);
                skl.skillItems = list;
                break;
            }*/
            case "100210000026": {//返魂曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ty");
                skl.putLearnResultRule("fg", 3f, 0, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 4f);
                Vector<skillItem> list = new Vector<>();
                //复活
                skillItem item = new skillItem(13);
                item.addTxRule(
                        createFuHuoRule(0.04f, 0.2f));
                item.addBaseRules(
                        createTargetRule(1, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000027": {//
                skl = new skill(key).addMaxLv(2);
                skl.bindSkillData(0, "ym/lc/fz");
                skl.putLearnResultRule("ll", 16f, 0, 0)
                        .putLearnResultRule("mj", 16f, 0, 0);
                break;
            }
            case "100210000028": {//
                skl = new skill(key).addMaxLv(8);
                skl.bindSkillData(0, "ym");
                skl.putLearnResultRule("ll", 36f, 0, 0)
                        .putLearnResultRule("mj", 12f, 0, 0);
                break;
            }
            case "100210000029": {//淬毒
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ym");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.15f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 1f, 0f, 5, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(10);
                item.addTxRule(
                        createZhongDuRule(0f, 1f));
                item.addBaseRules(
                        createTargetRule(2, 1f, 0f, 5, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                //吸血
                item = new skillItem(6);
                item.addTxRule(
                        createXiXueRule(0f, 0.1f));
                item.addBaseRules(
                        createTargetRule(0, 1f, 0f, 5, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000030": {//扬沙
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ym");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindCoolingRule(0f, 4f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //降低命中
                skillItem item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("mz", -0.03f, -0.05f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000031": {//影袭
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ym");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.83f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                //减少目标一定比例血量
                item = new skillItem(CutXueRule);
                item.addTxRule(
                        createCutXueRule(0f, 0.05f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);

                item = new skillItem(3);
                item.addTxRule(
                        createGuRule(0, 0f, 1f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0.01f, 0.2f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isActionStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000032": {//断脉
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ym");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.3f, 20f, 200f),
                        createAttackUpRule(2, 0.03f, 1.97f, 40f, 400f, "*"));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                //出现混乱
                item = new skillItem(3);
                item.addTxRule(
                        createGuRule(2, 0f, 0f, 0f, 1f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0.01f, 0.2f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isActionStartTriggre);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            /*case "3036": {//凝血咒
                skl = new skill(key);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 1f);
                Vector<skillItem> list = new Vector<>();
                //50%概率使敌方无法行动
                skillItem item = new skillItem(3);
                item.bindGuRule(0, 0f, 1f, 0f, 0f);
                item.bindEffectRule(2, null);
                item.isEachAttackerCreate = 1;
                item.isActionStartTriggre = 1;
                item.bindTargetRule(2, 0f, 1f, 1f);
                item.bindProbabilityRule(0.05f, 0.45f);
                list.add(item);
                skl.skillItems = list;
                break;
            }*/
            case "100210000033": {//凝钢决
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "ym");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindCoolingRule(0f, 3f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //减少50%所受伤害，免疫混乱、昏睡
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("sufferHurt", -0.02f, -0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(15);
                item.addTxRule(
                        createImmuneBuffRule(3));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000034": {//
                skl = new skill(key).addMaxLv(8);
                skl.bindSkillData(0, "lc");
                skl.putLearnResultRule("ll", 12f, 0, 0)
                        .putLearnResultRule("mj", 36f, 0, 0);
                break;
            }
            case "100210000035": {//淬毒(罗刹)
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "lc");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.15f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(10);
                item.addTxRule(
                        createZhongDuRule(0f, 1f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000036": {//扬沙
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "lc");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindCoolingRule(0f, 4f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //降低命中
                skillItem item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("mz", -0.04f, -0.2f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000037": {//定身蛊
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "lc");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 4f);
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(3);
                item.addTxRule(
                        createGuRule(0, 0f, 1f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0.04f, 0.2f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isActionStartTriggre);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            /*case "100210000038": {//昏睡
                skl = new skill(key);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 1f);
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(3);
                item.bindGuRule(1, 0f, 1f, 0f, 0f);
                item.bindEffectRule(2, null);
                item.isEachAttackerCreate = 1;
                item.isActionStartTriggre = 1;
                item.bindTargetRule(2, 0f, 1f, 1f);
                item.bindProbabilityRule(0.05f, 0.3f);
                list.add(item);
                skl.skillItems = list;
                break;
            }*/
            case "100210000038": {//混乱
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "lc");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 4f);
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(3);
                item.addTxRule(
                        createGuRule(2, 0f, 0f, 0f, 0.5f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0.04f, 0.2f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isActionStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000039": {//碎魂
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "lc");
                skl.putLearnResultRule("wf", 3f, 0, 0);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.3f, 20f, 200f),
                        createAttackUpRule(ZhongDuRule, 0.03f, 1.97f, 40f, 400f, "*"));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(3);
                item.addTxRule(
                        createGuRule(1, 0f, 1f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0.02f, 0.1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isActionStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            //6个基本门派技能
            case "100210000040": {//猛虎纵
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "zs");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.78f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000041": {//破天吼
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "zs");
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 2f);
                Vector<skillItem> list = new Vector<>();
                //诅咒敌方单体
                skillItem item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("sufferHurt", 0.06f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(4, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000042": {//荡魔曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "fs");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0.02f, 1.05f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000043": {//灵脉曲
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "fs");
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindCoolingRule(0f, 2f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //解除一个中毒状态
                skillItem item = new skillItem(RemoveRule);
                item.addTxRule(
                        createRemoveRule(ZhongDuRule, LiuXueRule));
                item.addBaseRules(
                        createTargetRule(1, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000044": {//淬毒
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "fz");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //以一定比例攻击+附加攻击
                skillItem item = new skillItem(0);
                item.addTxRule(
                        createAttackRule(false, 0.03f, 0.15f, 20f, 200f));
                item.addBaseRules(
                        createTargetRule(2, 1f, 0f, 5, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(10);
                item.addTxRule(
                        createZhongDuRule(0f, 1f));
                item.addBaseRules(
                        createTargetRule(2, 1f, 0f, 5, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210000045": {//扬沙
                skl = new skill(key).addMaxLv(20);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "fz");
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindCoolingRule(0f, 4f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //降低命中
                skillItem item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("mz", -0.03f, -0.05f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210000046": {//防御
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(0, "*");
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindTriggerCondition(0f, 0f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //降低15%受伤
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.15f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }

            //寻秦部分宠物技能、仙绝
            case "100210010178": {//狂舞乱击
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //以自身105%的物攻随机一个敌方目标进行攻击，命中则必然暴击，未命中则增加25%攻击。
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1.05f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 1),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(BiRanBaoJiRule);
                item.addTxRule(
                        createEmptyRule(BiRanBaoJiRule));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("wg", 0.25f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("fg", 0.25f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010179": {//轰天狂雷
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对6个目标造成80%的法术伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 0.8f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 6f, 6, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010180": {//真灵火攻
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对目标造成160%的法术伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1.6f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010181": {//真魔血破
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对同一排的敌方目标造成90%的物理伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 0.9f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 5f, 5, 2),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010182": {//烈焰焚野
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //随机对敌方3个目标造成80%的法术伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 0.8f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 3f, 3, 1),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010183": {//坚盾援护
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //当前回合替一名友方目标承受伤害，自身承受80%，友方受30%，最多生效2次
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(DiDangRule);
                item.addTxRule(
                        createDiDangRule(0.8f, 0.3f, true));
                item.addBaseRules(
                        createTargetRule(1, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 2),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isSufferHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010184": {//神鬼俱焚
                skl = new skill(key);
                skl.bindSkillData(4, "1225");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //死亡时点燃生命，对所有敌方目标造成相当于自己最大生命值15%的伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 0.2f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010185": {//双龙逆天
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(4, "1225");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.putLearnResultRule("bj", 0, 0.5f, 1);
                //拥有此技能将提高50%暴击，以自身攻击力的115%斩向敌人单体，如果暴击,
                // 则下回合增加10%的免伤,可以叠加3次，持续3回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1.8f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.15f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(4, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isBaojiCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010186": {//仙魔真诀
                skl = new skill(key);
                skl.bindSkillData(4, "1225");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //自身每受伤一次，攻击力增加10%，可叠加3次，持续3回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(4));
                item.addCreateMoment(skillItemCreateMoment.isSufferHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010187": {//真武御体
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.isAllowedSD = 0;
                skl.bindCoolingRule(0f, 5f);
                skl.bindSkillData(4, "1225");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //给自己加持血盾，当受到攻击时，把伤害转化成治疗吸收，盾当前回合有效且生效2次，冷却5回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(BeiCiRule);
                item.addTxRule(
                        createBeiCiRule(0f, 1f, 0, true));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 2),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }

            case "100210010188": {//乾坤逆转
                skl = new skill(key);
                skl.bindSkillData(4, "1221");
                skl.triggerType = 0;
                skl.bindCoolingRule(0f, 4f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //25%血量转化为1.5倍攻击
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1.1f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                List<String> attrNames = new ArrayList<>();
                attrNames.add("wg");
                item = new skillItem(AttrChangeRule);
                item.addTxRule(
                        createAttrChangeRule("max_xue", 0.15f, 1.5f, attrNames));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isSklShiFangBefCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                /*item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("wg", -0.15f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(5, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isHuiheStartCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);*/
                skl.skillItems = list;
                break;
            }
            case "100210010189": {//万魔归宗
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.isAllowedSD = 0;
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //当自身生命低于30%时，增加20%攻击
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("wg", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1),
                        createConditionRule(-1, 0.3f));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("fg", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1),
                        createConditionRule(-1, 0.3f));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010190": {//邪龙附体
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.isAllowedSD = 0;
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //死亡时为主人增加20%的攻击力
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("wg", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(3, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isDieCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("fg", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(3, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isDieCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010191": {//碎元剑诀
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(4, "1222");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //攻击会减少对方3%的生命上限，以攻击的150%对目标造成伤害，
                // 目标损失的上限会给目标造成额外伤害，存在万剑归宗时，技能伤害增加30%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 2f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(addOrCutAttrRule);
                item.addTxRule(
                        createAddOrCutAttrRule("max_xue", -0.05f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);
                item = new skillItem(CutXueRule);
                item.addTxRule(
                        createCutXueRule(0f, 0.05f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010192": {//绝杀咒印
                skl = new skill(key);
                skl.bindSkillData(4, "1222");
                skl.isAllowedSD = 0;
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //致死时无敌一回合，伤害增加50%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(WuDiRule);
                item.addTxRule(
                        createWuDiRule(0.5f, -1, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isDieTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010193": {//万剑归宗
                skl = new skill(key);
                skl.bindSkillData(4, "1222");
                skl.isAllowedSD = 0;
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //伤害额外提升30%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.3f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }


            case "100210010194": {//天魔噬魂
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(4, "1224");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //以105%的攻击给3个目标造成伤害，并有60%的几率以60%攻击连续攻击一次
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 0.8f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 10f, 10, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("wf", 0f, -0.3f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("ff", 0f, -0.3f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                /*List<Float> hurtKList = new ArrayList<>();
                hurtKList.add(0.6f);
                item = new skillItem(LianJiRule);
                item.addTxRule(
                        createLianJiRule(hurtKList, true, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 3f, 3, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);*/
                skl.skillItems = list;
                break;
            }
            case "100210010195": {//移魂转命
                skl = new skill(key);
                skl.bindSkillData(4, "1224");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //致死时100%触发不死，不死触发后获得3次反弹伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(NoDieRule);
                item.addTxRule(
                        createNoDieRule(0f, 1f, 1, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isDieTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("fg", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoDieCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010196": {//九天魔甲
                skl = new skill(key);
                //skl.triggerType = 0;//主动
                skl.bindCoolingRule(0f, 5f);
                skl.bindSkillData(4, "1224");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.putLearnResultRule("sd", 0, 0.2f, 1);
                //给友方一个抵消25%伤害的盾，持续3回合，冷却5回合，拥有该技能永久提高20%的闪避
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.4f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010200": {//天火燎原
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindCoolingRule(0f, 5f);
                skl.bindSkillData(4, "1226");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //消耗身上的霸体给敌方造成400%的法术伤害，每消耗一层霸体伤害提升10%，冷却5回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 4f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(CutBaTiRule);
                item.addTxRule(
                        createEmptyRule(CutBaTiRule));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010201": {//混元霸体
                skl = new skill(key);
                skl.bindSkillData(4, "1226");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //每回合获得1层霸体，受伤时也获得1层，每获得一次增加10%的减伤，持续5回合，可叠加5次，
                // 受到致死伤害时立即消耗身上的所有霸体，每个恢复10%的血量（该效果一场只能触发一次）
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(BaTiRule);
                item.addTxRule(
                        createEmptyRule(BaTiRule));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(5, -1),
                        createAddRule(5));
                item.addCreateMoment(skillItemCreateMoment.isHuiheStartCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(5, -1),
                        createAddRule(5));
                item.addCreateMoment(skillItemCreateMoment.isHuiheStartCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(5, -1),
                        createAddRule(5));
                item.addCreateMoment(skillItemCreateMoment.isSufferHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(BaTiRule);
                item.addTxRule(
                        createEmptyRule(BaTiRule));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(5, -1),
                        createAddRule(5));
                item.addCreateMoment(skillItemCreateMoment.isSufferHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(NoDieRule);
                item.addTxRule(
                        createNoDieRule(0f, 0.6f, 1, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isDieTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010202": {//都天炎爆
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(4, "1226");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对目标造成250%的法术伤害，并使其进入天罚状态（受伤增加10%，攻击下降10%，叠加2次），同时给自己加1层霸体
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 2.5f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(BaTiRule);
                item.addTxRule(
                        createEmptyRule(BaTiRule));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(5, -1),
                        createAddRule(5));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("sufferHurt", 0f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(2));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("wg", 0f, -0.1f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(2));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("fg", 0f, -0.1f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(2));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010203": {//九域神威
                skl = new skill(key);
                skl.bindSkillData(4, "1226");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //每受到一次伤害，攻击增加10%攻击，效果持续3回合，可叠加10次
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("fg", 0f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(10));
                item.addCreateMoment(skillItemCreateMoment.isSufferHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010204": {//烈战狂歌
                skl = new skill(key);
                skl.bindSkillData(4, "1226");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.putLearnResultRule("wg", 0f, 0.3f, 1).putLearnResultRule("fg", 0f, 0.3f, 1);
                //开场立即获得5层霸体，拥有此技能攻击增加30%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(BaTiRule);
                item.addTxRule(
                        createEmptyRule(BaTiRule));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(5, -1),
                        createAddRule(5, 5));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }


            case "100210010205": {//神龙摆尾
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(4, "1227");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对目标造成250%的攻击伤害，同时使对方进入恐惧状态（叠加3层）
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 2.5f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(KongJuRule);
                item.addTxRule(
                        createEmptyRule(KongJuRule));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("wf", 0f, -0.1f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010206": {//龙族本能
                skl = new skill(key);
                skl.bindSkillData(4, "1227");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.putLearnResultRule("wg", 0f, 0.35f, 1)
                        .putLearnResultRule("fg", 0f, 0.35f, 1);
                //对于处于恐惧状态下的目标，伤害提升30%，拥有此技能攻击提升35%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("sufferHurt", 0f, 0.3f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1),
                        createConditionRule(KongJuRule));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010207": {//亢龙有悔
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindCoolingRule(0f, 5f);
                skl.bindSkillData(4, "1227");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对目标造成400%的攻击伤害，并在下回合燃烧目标魔法，冷却5回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 4f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(CutLanRule);
                item.addTxRule(
                        createCutLanRule(0.1f, 0));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010208": {//神龙祝福
                skl = new skill(key);
                skl.bindSkillData(4, "1224");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //致死时恢复60%生命，一场战斗仅生效一次，每次攻击有15%几率造成双倍伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(NoDieRule);
                item.addTxRule(
                        createNoDieRule(0f, 0.6f, 1, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isDieTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 0.15f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010209": {//龙鳞护体
                skl = new skill(key);
                skl.bindCoolingRule(0f, 5f);
                skl.bindSkillData(4, "1224");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //降低60%受伤，死亡后降低所有敌方目标物理防御，一场战斗仅生效一次
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.6f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("wf", 0f, -0.3f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 10f, 10, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isDieCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }

            case "100210010210": {//铁命
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //当自身生命低于30%时，降低自身所受伤害的20%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1),
                        createConditionRule(-1, 0.3f));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010211": {//血杀
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.putLearnResultRule("mz", 0, 0.1f, 1);
                //增加10%命中，以130%的攻击对目标造成伤害，自身会额外遭受40%的伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1.3f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("sufferHurt", 0f, 0.4f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010212": {//焚野
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //随机对敌方3个目标造成60%的攻击伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 0.6f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 3f, 3, 1),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010213": {//战魂
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindCoolingRule(0f, 3f);
                skl.bindSkillData(5, "*");
                skl.bindCoolingRule(0f, 4f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //以180%的攻击对目标造成伤害，战魂会让下回合的伤害提高10%，冷却3回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1.8f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010214": {//忘我
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.putLearnResultRule("sd", 0, -0.3f, 1)
                        .putLearnResultRule("wf", 0, -0.4f, 1)
                        .putLearnResultRule("ff", 0, -0.4f, 1);
                //攻击时有20%几率增加20%的攻击，拥有此技能后闪避降低30%，防御降低40%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 0.2f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010215": {//猛力
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.08f, 1)
                        .putLearnResultRule("fg", 0, 0.08f, 1)
                        .putLearnResultRule("sd", 0, -0.4f, 1)
                        .putLearnResultRule("wf", 0, -0.35f, 1)
                        .putLearnResultRule("ff", 0, -0.35f, 1);
                //增加8%攻击，拥有此技能后闪避降低40%，防御降低35%
                break;
            }
            case "100210010216": {//背刺
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.bindCoolingRule(0f, 5f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //当前回合反弹1次伤害，且自身不受伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(BeiCiRule);
                item.addTxRule(
                        createBeiCiRule(0f, 1f, 2, false));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010217": {//猛攻
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.1f, 1)
                        .putLearnResultRule("fg", 0, 0.1f, 1)
                        .putLearnResultRule("wf", 0, -0.5f, 1)
                        .putLearnResultRule("ff", 0, -0.5f, 1);
                //增加10%攻击，拥有此技能后防御降低50%
                break;
            }
            case "100210010218": {//回灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //每回合自动恢复5%的蓝量
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HuiLanRule);
                item.addTxRule(
                        createHuiLanRule(0f, 0.05f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010219": {//护体
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.isAllowedSD = 0;
                skl.bindCoolingRule(0f, 3f);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //降低自身15%所受伤害，持续2回合，冷却2回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.15f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010220": {//绝影
                skl = new skill(key);
                skl.addSavvy(150);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.15f, 1)
                        .putLearnResultRule("fg", 0, 0.15f, 1)
                        .putLearnResultRule("sd", 0, 0.1f, 1);
                //提高15%攻击和10%闪避
                break;
            }
            case "100210010221": {//玄心
                skl = new skill(key);
                skl.addSavvy(150);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.15f, 1)
                        .putLearnResultRule("fg", 0, 0.15f, 1)
                        .putLearnResultRule("mz", 0, 0.1f, 1);
                //提高15%攻击和10%命中
                break;
            }
            case "100210010222": {//狂暴
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.1f, 1)
                        .putLearnResultRule("max_xue", 0, -0.15f, 1);
                //提高10%暴击，同时降低15%的生命上限
                break;
            }
            case "100210010223": {//体术
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("max_xue", 0, 0.12f, 1)
                        .putLearnResultRule("wf", 0, -0.08f, 1)
                        .putLearnResultRule("ff", 0, -0.08f, 1);
                //提高12%的生命上限，同时降低8%的防御
                break;
            }
            case "100210010224": {//血击
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //生命低于30%时，反击概率增加25%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(50);
                item.addTxRule(
                        createRateRule("fanji", 0.25f, 0.3f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010225": {//刚体
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.triggerType = 0;//主动
                skl.bindCoolingRule(0f, 5f);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //降低80%所受的伤害，冷却4回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.8f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010226": {//返血
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //受到暴击后有20%的几率恢复自身生命上限10%的血量
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HuiXueRule);
                item.addTxRule(
                        createHuiXueRule(0f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0.2f),
                        createEffectRule(99, -1, 3),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isSufferBaojiTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010227": {//不死
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //50%几率受到致死伤害时保留1点血，仅触发1次
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(NoDieRule);
                item.addTxRule(
                        createNoDieRule(0f, 1f, 0, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0.5f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isDieTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010228": {//狂化
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.08f, 1)
                        .putLearnResultRule("wf", 0, -0.3f, 1)
                        .putLearnResultRule("ff", 0, -0.3f, 1);
                //提高8%的暴击，同时降低30%防御
                break;
            }
            case "100210010229": {//反扑
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //生命低于30%时，暴击提升15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("bj", 0f, 0.15f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1),
                        createConditionRule(-1, 0.3f));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010230": {//反震
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //受伤时有10%几率将50%伤害反震给对方
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(FanZhenRule);
                item.addTxRule(
                        createFanZhenRule(0f, 0.5f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0.1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010231": {//沉甲
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wf", 0, 0.12f, 1)
                        .putLearnResultRule("ff", 0, 0.12f, 1)
                        .putLearnResultRule("sd", 0, -0.2f, 1);
                //增加12%防御，同时降低20%闪避
                break;
            }
            case "100210010232": {//缚命
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对带有回血buff的目标伤害增加30%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HurtUpRule);
                item.addTxRule(
                        createHurtUpRule(HuiXueRule, 0f, 0.3f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010233": {//奔雷
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.08f, 1)
                        .putLearnResultRule("css", 0, 0.05f, 1);
                //提高8%的暴击和5%的速度
                break;
            }
            case "100210010234": {//爆斩
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //暴击后伤害增加10%（2回合有效）
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HurtUpRule);
                item.addTxRule(
                        createHurtUpRule(-1, 0f, 0.1f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isBaojiCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isBaojiTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010235": {//神速
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("css", 0, 0.15f, 1)
                        .putLearnResultRule("mz", 0, 0.15f, 1)
                        .putLearnResultRule("wf", 0, -0.35f, 1)
                        .putLearnResultRule("ff", 0, -0.35f, 1)
                        .putLearnResultRule("sd", 0, -0.3f, 1);
                //提高15%的手速跟15%的命中，同时防御降低35%，闪避降低30%
                break;
            }
            case "100210010236": {//体魄
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("max_xue", 0, 0.1f, 1)
                        .putLearnResultRule("wg", 0, -0.2f, 1)
                        .putLearnResultRule("fg", 0, -0.2f, 1);
                //提高20%的生命上限，同时降低20%的攻击
                break;
            }
            case "100210010237": {//残影
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("sd", 0, 0.2f, 1);
                //增加20%的闪避
                break;
            }
            case "100210010238": {//疗血
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                //每回合恢复最大生命6%的血量
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HuiXueRule);
                item.addTxRule(
                        createHuiXueRule(0.06f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010239": {//重生
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                //死亡后有20%几率以70%生命复活，一场战斗仅一次
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(NoDieRule);
                item.addTxRule(
                        createNoDieRule(0f, 0.7f, 1, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0.2f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isDieTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010240": {//吸血
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 2f);
                //以100%的攻击对目标造成伤害，并吸取该伤害的70%恢复血量
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(XiXueRule);
                item.addTxRule(
                        createXiXueRule(0f, 0.7f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210010241": {//石肤
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wf", 0, 0.15f, 1)
                        .putLearnResultRule("ff", 0, 0.15f, 1);
                //防御提升15%
                break;
            }
            case "100210010242": {//命术
                skl = new skill(key);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("max_xue", 0, 0.07f, 1);
                //提升7%生命上限
                break;
            }
            case "100210010243": {//裂骨
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                //对敌方造成攻击伤害时，对方每回合以该伤害的8%持续掉血（持续2回合）
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(LiuXueRule);
                item.addTxRule(
                        createLiuXueRule(0f, 0.08f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010244": {//反击
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(100);
                skl.bindSkillData(5, "*");
                //被攻击时有15%几率反击对方
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(FanJiRule);
                item.addTxRule(
                        createEmptyRule(FanJiRule));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0.15f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isCountXueDoneTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010245": {//木灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("max_xue", 0, 0.1f, 1);
                //增加10%生命，同时被治疗效果增加10%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferCure", 0.1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010246": {//火灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.1f, 1)
                        .putLearnResultRule("fg", 0, 0.1f, 1);
                //增加10%攻击，同时造成伤害后攻击提升10%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010247": {//土灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wf", 0, 0.1f, 1)
                        .putLearnResultRule("ff", 0, 0.1f, 1);
                //增加10%防御，同时受到伤害时防御增加10%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("wf", 0f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isSufferHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("ff", 0f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isSufferHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010248": {//金灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("sd", 0, 0.1f, 1);
                //增加10%闪避，同时造成伤害后降低对方10%攻击
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("wg", -0.1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("fg", -0.1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210010249": {//水灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.1f, 1);
                //增加10%暴击，同时暴击后暴击提升10%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("bj", 0.1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isBaojiCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210010250": {//迅捷
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("css", 0, 0.1f, 1)
                        .putLearnResultRule("wf", 0, -0.4f, 1)
                        .putLearnResultRule("ff", 0, -0.4f, 1);
                //增加10%出手速，降低40%防御

                break;
            }
            case "100210010251": {//厚甲
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("max_xue", 0, -0.1f, 1)
                        .putLearnResultRule("wf", 0, 0.1f, 1)
                        .putLearnResultRule("ff", 0, 0.1f, 1);
                //增加10%防御，降低10%生命

                break;
            }
            case "100210010252": {//鲁莽
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.1f, 1)
                        .putLearnResultRule("mz", 0, -0.2f, 1);
                //增加10%暴击，降低20%命中

                break;
            }
            case "100210010253": {//援护
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //当前回合替一名友方目标承受伤害，自身承受80%，友方受30%，最多生效1次
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(DiDangRule);
                item.addTxRule(
                        createDiDangRule(0.8f, 0.3f, true));
                item.addBaseRules(
                        createTargetRule(1, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isSufferHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010254": {//灵噬
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 3f);
                //以攻击的40%燃烧敌方魔法，冷却2回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(CutLanRule);
                item.addTxRule(
                        createCutLanRule(0.4f, 0));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010255": {//强攻
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.1f, 1)
                        .putLearnResultRule("fg", 0, 0.1f, 1)
                        .putLearnResultRule("max_xue", 0, -0.15f, 1);
                //增加10%攻击，降低15%生命

                break;
            }
            case "100210010256": {//暴怒
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.04f, 1);
                //增加4%暴击，造成伤害后增加2%暴击
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("bj", 0.02f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010257": {//乱击
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //以自身85%的物攻随机一个敌方目标进行攻击，命中则必然暴击，未命中则增加15%攻击。
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 0.85f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 1),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(BiRanBaoJiRule);
                item.addTxRule(
                        createEmptyRule(BiRanBaoJiRule));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("wg", 0.15f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("fg", 0.15f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;

                break;
            }
            case "100210010258": {//狂雷
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对6个目标造成60%的法术伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 0.6f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 6f, 6, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010259": {//火攻
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对目标造成120%的法术伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1.2f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010260": {//血破
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对同一排的敌方目标造成60%的物理伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 0.6f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 5f, 5, 2),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010261": {//嗜血
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.04f, 1)
                        .putLearnResultRule("fg", 0, 0.04f, 1);
                //增加4%攻击，造成伤害后增加2%攻击
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("wg", 0.02f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(1);
                item.addTxRule(
                        createGainRule("fg", 0.02f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010262": {//铁骨
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                //受到的伤害降低8%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("sufferHurt", -0.08f, 0, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                break;
            }
            case "100210010263": {//锐爪
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.05f, 1)
                        .putLearnResultRule("fg", 0, 0.05f, 1);
                //增加5%攻击%

                break;
            }
            case "100210010264": {//精准
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("mz", 0, 0.05f, 1);
                //增加5%命中%

                break;
            }
            //================四字======================
            case "100210010265": {//真魔铁命
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //当自身生命低于30%时，降低自身所受伤害的30%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.3f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1),
                        createConditionRule(-1, 0.3f));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010266": {//真魔血杀
                skl = new skill(key);
                skl.addSavvy(120);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.putLearnResultRule("mz", 0, 0.2f, 1);
                //增加20%命中，以170%的攻击对目标造成伤害，自身会额外遭受20%的伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1.7f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("sufferHurt", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010267": {//灭世战魂
                skl = new skill(key);
                skl.addSavvy(150);
                skl.triggerType = 0;//主动
                skl.bindCoolingRule(0f, 3f);
                skl.bindSkillData(5, "*");
                skl.bindCoolingRule(0f, 4f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //以220%的攻击对目标造成伤害，战魂会让下回合的伤害提高25%，冷却3回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 2.2f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.25f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010268": {//忘我强攻
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.putLearnResultRule("sd", 0, -0.2f, 1)
                        .putLearnResultRule("wf", 0, -0.3f, 1)
                        .putLearnResultRule("ff", 0, -0.3f, 1);
                //攻击时有50%几率增加35%的攻击，拥有此技能后闪避降低20%，防御降低30%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.35f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 0.5f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010269": {//摧山猛力
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.15f, 1)
                        .putLearnResultRule("fg", 0, 0.15f, 1)
                        .putLearnResultRule("sd", 0, -0.3f, 1)
                        .putLearnResultRule("wf", 0, -0.25f, 1)
                        .putLearnResultRule("ff", 0, -0.25f, 1);
                //增加15%攻击，拥有此技能后闪避降低30%，防御降低25%
                break;
            }
            case "100210010270": {//连环背刺
                skl = new skill(key);
                skl.addSavvy(150);
                skl.triggerType = 0;//主动
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.bindCoolingRule(0f, 5f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //当前回合反弹2次伤害，且自身不受伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(BeiCiRule);
                item.addTxRule(
                        createBeiCiRule(0f, 1f, 2, false));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 2),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010271": {//天生猛攻
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.2f, 1)
                        .putLearnResultRule("fg", 0, 0.2f, 1)
                        .putLearnResultRule("wf", 0, -0.4f, 1)
                        .putLearnResultRule("ff", 0, -0.4f, 1);
                //增加20%攻击，拥有此技能后防御降低40%
                break;
            }
            case "100210010272": {//仙术回灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(150);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //每回合自动恢复5%的蓝量
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HuiLanRule);
                item.addTxRule(
                        createHuiLanRule(0f, 0.1f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010273": {//神盾护体
                skl = new skill(key);
                skl.addSavvy(120);
                skl.triggerType = 0;//主动
                skl.isAllowedSD = 0;
                skl.bindCoolingRule(0f, 3f);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //降低自身30%所受伤害，持续2回合，冷却2回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.3f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010274": {//踏雪绝影
                skl = new skill(key);
                skl.addSavvy(200);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.3f, 1)
                        .putLearnResultRule("fg", 0, 0.3f, 1)
                        .putLearnResultRule("sd", 0, 0.2f, 1);
                //提高30%攻击和20%闪避
                break;
            }
            case "100210010275": {//玄心破霄
                skl = new skill(key);
                skl.addSavvy(200);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.3f, 1)
                        .putLearnResultRule("fg", 0, 0.3f, 1)
                        .putLearnResultRule("mz", 0, 0.2f, 1);
                //提高30%攻击和20%命中
                break;
            }
            case "100210010276": {//天生狂暴
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.2f, 1)
                        .putLearnResultRule("max_xue", 0, -0.15f, 1);
                //提高20%暴击，同时降低15%的生命上限
                break;
            }
            case "100210010277": {//真魔体术
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("max_xue", 0, 0.22f, 1)
                        .putLearnResultRule("wf", 0, -0.04f, 1)
                        .putLearnResultRule("ff", 0, -0.04f, 1);
                //提高22%的生命上限，同时降低4%的防御
                break;
            }
            case "100210010278": {//绝命血击
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //生命低于30%时，反击概率增加35%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(50);
                item.addTxRule(
                        createRateRule("fanji", 0.35f, 0.3f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010279": {//天魔刚体
                skl = new skill(key);
                skl.addSavvy(120);
                skl.isAllowedSD = 0;
                skl.triggerType = 0;//主动
                skl.bindCoolingRule(0f, 5f);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //降低90%所受的伤害，冷却4回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.9f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010280": {//真灵返血
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //受到暴击后有50%的几率恢复自身生命上限20%的血量
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HuiXueRule);
                item.addTxRule(
                        createHuiXueRule(0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0.5f),
                        createEffectRule(99, -1, 3),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isSufferBaojiTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010281": {//天命不死
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //100%几率受到致死伤害时保留1点血，仅触发1次
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(NoDieRule);
                item.addTxRule(
                        createNoDieRule(0f, 1f, 0, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isDieTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010282": {//真魔狂化
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.15f, 1)
                        .putLearnResultRule("wf", 0, -0.3f, 1)
                        .putLearnResultRule("ff", 0, -0.3f, 1);
                //提高15%的暴击，同时降低30%防御
                break;
            }
            case "100210010283": {//绝境反扑
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //生命低于30%时，暴击提升30%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("bj", 0f, 0.3f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1),
                        createConditionRule(-1, 0.3f));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010284": {//霸气反震
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //受伤时有20%几率将50%伤害反震给对方
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(FanZhenRule);
                item.addTxRule(
                        createFanZhenRule(0f, 0.5f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0.2f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010285": {//天生沉甲
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wf", 0, 0.25f, 1)
                        .putLearnResultRule("ff", 0, 0.25f, 1)
                        .putLearnResultRule("sd", 0, -0.2f, 1);
                //增加25%防御，同时降低20%闪避
                break;
            }
            case "100210010286": {//血魔缚命
                skl = new skill(key);
                skl.addSavvy(150);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //对带有回血buff的目标伤害增加60%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HurtUpRule);
                item.addTxRule(
                        createHurtUpRule(HuiXueRule, 0f, 0.6f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010287": {//疾电奔雷
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.15f, 1)
                        .putLearnResultRule("css", 0, 0.1f, 1);
                //提高15%的暴击和10%的速度
                break;
            }
            case "100210010288": {//狂乱爆斩
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //暴击后伤害增加20%（2回合有效）
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HurtUpRule);
                item.addTxRule(
                        createHurtUpRule(-1, 0f, 0.2f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isBaojiCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isBaojiTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010289": {//飞影神速
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("css", 0, 0.25f, 1)
                        .putLearnResultRule("mz", 0, 0.25f, 1)
                        .putLearnResultRule("wf", 0, -0.35f, 1)
                        .putLearnResultRule("ff", 0, -0.35f, 1)
                        .putLearnResultRule("sd", 0, -0.3f, 1);
                //提高25%的手速跟25%的命中，同时防御降低35%，闪避降低30%
                break;
            }
            case "100210010290": {//天生体魄
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("max_xue", 0, 0.2f, 1)
                        .putLearnResultRule("wg", 0, -0.2f, 1)
                        .putLearnResultRule("fg", 0, -0.2f, 1);
                //提高20%的生命上限，同时降低20%的攻击
                break;
            }
            case "100210010291": {//逐风残影
                skl = new skill(key);
                skl.addSavvy(150);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("sd", 0, 0.5f, 1);
                //增加50%的闪避
                break;
            }
            case "100210010292": {//仙术回血
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(150);
                skl.bindSkillData(5, "*");
                //每回合恢复最大生命10%的血量
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HuiXueRule);
                item.addTxRule(
                        createHuiXueRule(0.1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010293": {//浴火重生
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                //死亡后有50%几率以100%生命复活，一场战斗仅一次
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(NoDieRule);
                item.addTxRule(
                        createNoDieRule(0f, 1f, 1, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0.5f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isDieTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010294": {//真魔吸血
                skl = new skill(key);
                skl.addSavvy(120);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 2f);
                //以100%的攻击对目标造成伤害，并吸取该伤害的100%恢复血量
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(XiXueRule);
                item.addTxRule(
                        createXiXueRule(0f, 1f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210010295": {//坚壁石肤
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wf", 0, 0.2f, 1)
                        .putLearnResultRule("ff", 0, 0.2f, 1);
                //防御提升20%
                break;
            }
            case "100210010296": {//仙灵命术
                skl = new skill(key);
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("max_xue", 0, 0.1f, 1);
                //提升10%生命上限
                break;
            }
            case "100210010297": {//裂骨鬼刃
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(150);
                skl.bindSkillData(5, "*");
                //对敌方造成攻击伤害时，对方每回合以该伤害的15%持续掉血（持续2回合）
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(LiuXueRule);
                item.addTxRule(
                        createLiuXueRule(0f, 0.15f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHuiheStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010298": {//强势反击
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(150);
                skl.bindSkillData(5, "*");
                //被攻击时有30%几率反击对方
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(FanJiRule);
                item.addTxRule(
                        createEmptyRule(FanJiRule));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0.3f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isCountXueDoneTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010299": {//天赐木灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("max_xue", 0, 0.2f, 1);
                //增加20%生命，同时被治疗效果增加20%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferCure", 0.2f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010300": {//天赐火灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.2f, 1)
                        .putLearnResultRule("fg", 0, 0.2f, 1);
                //增加20%攻击，同时造成伤害后攻击提升20%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010301": {//天赐土灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wf", 0, 0.2f, 1)
                        .putLearnResultRule("ff", 0, 0.2f, 1);
                //增加20%防御，同时受到伤害时防御增加20%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("wf", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isSufferHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("ff", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isSufferHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010302": {//天赐金灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("sd", 0, 0.2f, 1);
                //增加20%闪避，同时造成伤害后降低对方20%攻击
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("wg", -0.2f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("fg", -0.2f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isHurtCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210010303": {//天赐水灵
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.2f, 1);
                //增加20%暴击，同时暴击后暴击提升20%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("bj", 0.2f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isBaojiCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210010304": {//天生迅捷
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("css", 0, 0.25f, 1)
                        .putLearnResultRule("wf", 0, -0.4f, 1)
                        .putLearnResultRule("ff", 0, -0.4f, 1);
                //增加25%出手速，降低40%防御

                break;
            }
            case "100210010305": {//天生厚甲
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("max_xue", 0, -0.1f, 1)
                        .putLearnResultRule("wf", 0, 0.25f, 1)
                        .putLearnResultRule("ff", 0, 0.25f, 1);
                //增加25%防御，降低10%生命

                break;
            }
            case "100210010306": {//天生鲁莽
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.2f, 1)
                        .putLearnResultRule("mz", 0, -0.2f, 1);
                //增加20%暴击，降低20%命中

                break;
            }
            case "100210010307": {//妙法灵噬
                skl = new skill(key);
                skl.addSavvy(150);
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.bindCoolingRule(0f, 3f);
                //以攻击的80%燃烧敌方魔法，冷却2回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(CutLanRule);
                item.addTxRule(
                        createCutLanRule(0.8f, 0));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010308": {//天生强攻
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.2f, 1)
                        .putLearnResultRule("fg", 0, 0.2f, 1)
                        .putLearnResultRule("max_xue", 0, -0.15f, 1);
                //增加20%攻击，降低15%生命

                break;
            }
            case "100210010309": {//真魔暴怒
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("bj", 0, 0.08f, 1);
                //增加8%暴击，造成伤害后增加5%暴击
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("bj", 0.05f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010310": {//真魔嗜血
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.08f, 1)
                        .putLearnResultRule("fg", 0, 0.08f, 1);
                //增加8%攻击，造成伤害后增加5%攻击
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("wg", 0.05f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(1);
                item.addTxRule(
                        createGainRule("fg", 0.05f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010311": {//铜皮铁骨
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                //受到的伤害降低10%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("sufferHurt", -0.1f, 0, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                break;
            }
            case "100210010312": {//裂空锐爪
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("wg", 0, 0.1f, 1)
                        .putLearnResultRule("fg", 0, 0.1f, 1);
                //增加10%攻击

                break;
            }
            case "100210010313": {//神目精准
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(120);
                skl.bindSkillData(5, "*");
                skl.putLearnResultRule("mz", 0, 0.1f, 1);
                //增加10%命中

                break;
            }
            case "100210010314": {//魔神降临
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.addSavvy(300);
                skl.bindSkillData(5, "*");
                //每回合攻击上升10%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("wg", 0.1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(99));
                item.addCreateMoment(skillItemCreateMoment.isHuiheStartCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("fg", 0.1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(99));
                item.addCreateMoment(skillItemCreateMoment.isHuiheStartCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010315": {//天下无双
                skl = new skill(key);
                skl.triggerType = 0;
                skl.addSavvy(300);
                skl.bindCoolingRule(0f, 99f);
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //开场秒杀全部角色
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(KillRoleRule);
                item.addTxRule(
                        createEmptyRule(KillRoleRule));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, 1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isEachAttackerTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010316": {//永恒背刺
                skl = new skill(key);
                skl.addSavvy(300);
                skl.afterHuiheUse = 5;
                skl.isAllowedSD = 0;
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindCoolingRule(0f, 5f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //当前回合反弹所有伤害，且自身不受伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(BeiCiRule);
                item.addTxRule(
                        createBeiCiRule(0f, 1f, 2, false));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(1, 99),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010317": {//风雷之力
                skl = new skill(key);
                skl.addSavvy(300);
                skl.afterHuiheUse = 5;
                skl.isAllowedSD = 0;
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindCoolingRule(0f, 5f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //提升暴击、伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0.1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(99));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(1);
                item.addTxRule(
                        createGainRule("bj", 0.1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(99));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010318": {//魔神之力
                skl = new skill(key);
                skl.addSavvy(300);
                skl.afterHuiheUse = 5;
                skl.isAllowedSD = 0;
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindCoolingRule(0f, 5f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //提升伤害、攻击
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("wg", 1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("fg", 1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010319": {//凶残
                skl = new skill(key);
                skl.afterHuiheCreate = 10;
                skl.isAllowedSD = 0;
                skl.addSavvy(300);
                skl.bindSkillData(5, "*");
                //每回合攻击上升100%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("wg", 1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(99));
                item.addCreateMoment(skillItemCreateMoment.isHuiheStartCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("fg", 1f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(99));
                item.addCreateMoment(skillItemCreateMoment.isHuiheStartCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010320": {//免伤
                skl = new skill(key);
                skl.addSavvy(300);
                skl.afterHuiheUse = 5;
                skl.isAllowedSD = 0;
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindCoolingRule(0f, 6f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //受伤减100%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010321": {//神避
                skl = new skill(key);
                skl.addSavvy(300);
                skl.afterHuiheUse = 5;
                skl.isAllowedSD = 0;
                skl.triggerType = 0;//主动
                skl.bindSkillData(5, "*");
                skl.bindCoolingRule(0f, 6f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //闪避+10000
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sd", 0f, 100000f, 0));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(3, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010322": {//奇术定身
                skl = new skill(key);
                skl.addSavvy(150);
                skl.triggerType = 0;//主动
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //以攻击的80%燃烧敌方魔法，冷却2回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(3);
                item.addTxRule(
                        createGuRule(0, 0f, 1f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 0.4f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isActionStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010323": {//奇术混乱
                skl = new skill(key);
                skl.addSavvy(150);
                skl.triggerType = 0;//主动
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //以攻击的80%燃烧敌方魔法，冷却2回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(3);
                item.addTxRule(
                        createGuRule(2, 0f, 0f, 0f, 0.5f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0, 0.4f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isActionStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010324": {//奇术睡眠
                skl = new skill(key);
                skl.addSavvy(150);
                skl.triggerType = 0;//主动
                skl.isAllowedSD = 0;
                skl.bindSkillData(5, "*");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //以攻击的80%燃烧敌方魔法，冷却2回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(3);
                item.addTxRule(
                        createGuRule(1, 0f, 1f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 0.4f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isActionStartTriggre);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            //狐狸
            case "100210010325": {//灵风咒
                skl = new skill(key);
                skl.triggerType = 0;//主动
                skl.bindSkillData(4, "1220");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //以120%的攻击对目标造成伤害，对方每次闪避，自身伤害将提高50%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(AttackRule);
                item.addTxRule(
                        createAttackRule(false, 0f, 1.8f, 0f, 0f));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f));
                list.add(item);
                item = new skillItem(CurseRule);
                item.addTxRule(
                        createCurseRule("sd", 0f, -0.2f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010326": {//幻影
                skl = new skill(key);
                skl.bindSkillData(4, "1220");
                skl.isAllowedSD = 0;
                skl.bindCoolingRule(0f, 4f);
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //一友方目标闪避提升25%，持续2回合，冷却4回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sufferHurt", 0f, -0.4f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010327": {//灵动
                skl = new skill(key);
                skl.bindSkillData(4, "1220");
                skl.triggerType = 0;
                skl.isAllowedSD = 0;
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                //自身每次闪避，攻击提升8%，叠加2层，持续2回合，拥有此技能闪避提升15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("sd", 0f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(1, 0f, 10f, 10, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(3));
                item.addCreateMoment(skillItemCreateMoment.isEachAttackerCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010328": {//幻身
                skl = new skill(key);
                skl.bindSkillData(4, "1220");
                skl.isAllowedSD = 0;
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.putLearnResultRule("sd", 0f, 0.2f, 1);
                //自身每次闪避，攻击提升8%，叠加2层，持续2回合，拥有此技能闪避提升15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("fg", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(2));
                item.addCreateMoment(skillItemCreateMoment.isSDCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210010329": {//破天一剑
                skl = new skill(key);
                skl.bindSkillData(4, "1222");
                skl.bindTriggerCondition(5f, 10f, 0, 0f, 0f, 1);
                skl.putLearnResultRule("sd", 0f, 0.2f, 1);
                //对援护的目标造成3倍伤害
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HurtUpRule);
                item.addTxRule(
                        createHurtUpRule(29, 0f, 3f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            //=========5个经脉技能============
            case "100210020000": {//青木长生
                skl = new skill(key);
                skl.bindSkillData(6, "*");
                skl.putLearnResultRule("nl", 4, 36, 0)
                        .putCountWay(1);
                break;
            }
            case "100210020001": {//赤火蛮力
                skl = new skill(key);
                skl.bindSkillData(6, "*");
                skl.putLearnResultRule("ll", 4, 36, 0)
                        .putCountWay(1);
                break;
            }
            case "100210020002": {//精金疾风
                skl = new skill(key);
                skl.bindSkillData(6, "*");
                skl.putLearnResultRule("mj", 4, 36, 0)
                        .putCountWay(1);
                break;
            }
            case "100210020003": {//玄水明智
                skl = new skill(key);
                skl.bindSkillData(6, "*");
                skl.putLearnResultRule("zl", 4, 36, 0)
                        .putCountWay(1);
                break;
            }
            case "100210020004": {//戊土精元
                skl = new skill(key);
                skl.bindSkillData(6, "*");
                skl.putLearnResultRule("js", 4, 36, 0)
                        .putCountWay(1);
                break;
            }
            //=========寻秦仙绝技能===============
            case "100210030027": {//凝神静息
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(1, "*");
                skl.putLearnResultRule("mz", 0, 0.15f, 1);
                //受到的治疗效果提升24%，同时命中上升15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("sufferCure", 0.06f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030028": {//绝地反击
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(2, "*");
                skl.putLearnResultRule("css", 0, 0.15f, 1);
                //生命低于50%时，雷霆震击的反击概率提高12%，同时出手速增加15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(50);
                item.addTxRule(
                        createRateRule("fanji", 0.03f, 0.5f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030029": {//如风迅击
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0, 0.13f, 1)
                        .putLearnResultRule("fg", 0, 0.13f, 1)
                        .putLearnResultRule("bj", 0, -0.06f, 1);
                //攻击增加13%，同时暴击下降6%
                break;
            }
            case "100210030030": {//无极淬体
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("max_xue", 0, 0.1f, 1);
                //生命提高10%
                break;
            }
            case "100210030031": {//八玄锻脉
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("max_xue", 0, 0.13f, 1)
                        .putLearnResultRule("bj", 0, -0.05f, 1);
                //生命提高13%，暴击降低5%
                break;
            }
            case "100210030032": {//金身硬化
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("max_xue", 0, 0.08f, 1)
                        .putLearnResultRule("mz", 0, 0.2f, 1);
                //生命提高8%，命中提升20%
                break;
            }
            case "100210030033": {//集思凝力
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0, 0.1f, 1)
                        .putLearnResultRule("fg", 0, 0.1f, 1);
                //人物攻击提升10%
                break;
            }
            case "100210030034": {//精金血刃
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0, 0.08f, 1)
                        .putLearnResultRule("fg", 0, 0.08f, 1)
                        .putLearnResultRule("mz", 0, 0.2f, 1);
                //增加8%的攻击，命中提升20%
                break;
            }
            case "100210030035": {//冰凌锋锐
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0, 0.06f, 1)
                        .putLearnResultRule("fg", 0, 0.06f, 1);
                //增加6%的攻击，伤害提升12%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.12f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030036": {//回光反照
                skl = new skill(key);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindSkillData(3, "*");
                skl.bindTriggerCondition(0f, 0f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //受到致死伤害时，无敌两回合（允许回血），伤害提升50%
                skillItem item = new skillItem(WuDiRule);
                item.addTxRule(
                        createWuDiRule(0.5f, -1, 2));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isDieTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210030037": {//强烈腐蚀
                skl = new skill(key);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindSkillData(3, "*");
                skl.bindTriggerCondition(0f, 0f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //命中敌人后降低对方35%防御，持续2回合
                skillItem item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("wf", -0.35f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("ff", -0.35f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210030038": {//勇士之怒
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(1, "*");
                skl.putLearnResultRule("mz", 0, 0.15f, 1);
                //暴击后伤害提升至210%，同时命中提升15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(BjKChangeRule);
                item.addTxRule(
                        createBjKChange(0.1f, 2f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210030039": {//邪神附体
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(2, "*");
                skl.putLearnResultRule("css", 0, 0.15f, 1);
                //每暴击一次暴击率增加1%，最多20%，同时出手速上升15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("bj", 0.01f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(20));
                item.addCreateMoment(skillItemCreateMoment.isBaojiCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210030040": {//嗜血狂攻
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0, 0.15f, 1)
                        .putLearnResultRule("fg", 0, 0.15f, 1)
                        .putLearnResultRule("wf", 0, -0.05f, 1)
                        .putLearnResultRule("ff", 0, -0.05f, 1)
                        .putLearnResultRule("mz", 0, -0.1f, 1);
                //增加15%的攻击，同时降低5%防御和10%命中

                break;
            }
            case "100210030041": {//仙灵庇佑
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(1, "*");
                skl.putLearnResultRule("mz", 0, 0.15f, 1);
                //打出暴击时，恢复1%的生命，同时命中上升15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(5);
                item.addTxRule(
                        createHuiXueRule(0.01f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isBaojiTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030042": {//聚精会神
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(1, "*");
                skl.putLearnResultRule("mz", 0.5f, 0f, 1);
                //命中上升5%

                break;
            }
            case "100210030043": {//舍命七伤
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0.3f, 0f, 1)
                        .putLearnResultRule("fg", 0.3f, 0f, 1)
                        .putLearnResultRule("sd", -0.6f, 0f, 1);
                //增加30%攻击，同时降低60%闪避

                break;
            }
            case "100210030044": {//玄火炼骨
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("max_xue", 0.26f, 0f, 1)
                        .putLearnResultRule("wf", -0.03f, 0f, 1)
                        .putLearnResultRule("ff", -0.03f, 0f, 1)
                        .putLearnResultRule("sd", -0.05f, 0f, 1);
                //人物生命提升26%，防御降低3%，闪避降低5%

                break;
            }
            case "100210030045": {//孤身铁胆
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("max_xue", 0.15f, 0f, 1)
                        .putLearnResultRule("sd", -0.2f, 0f, 1);
                //人物生命提升15%，闪避降低20%

                break;
            }
            case "100210030046": {//混元诱杀
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                //当目标被援护时伤害提升至200%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HurtUpRule);
                item.addTxRule(
                        createHurtUpRule(29, 0f, 2f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030047": {//惊恐噩梦
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                //命中目标后敌方有25%的几率进入噩梦状态（释放技能时蓝消耗增加至400%，持续2回合）
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(ErMengRule);
                item.addTxRule(
                        createErMengRule(0, 4));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 100, 0),
                        createProbabilityRule(0f, 0.25f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030048": {//雷霆震击
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(1, "*");
                skl.putLearnResultRule("mz", 0.15f, 0f, 1);
                //受到伤害时有3%的几率进行反击，同时人物命中上升15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(FanJiRule);
                item.addTxRule(
                        createEmptyRule(FanJiRule));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 0.03f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isCountXueDoneTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030049": {//血腥愤怒
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                //未命中敌人则增加15%攻击，持续2回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.15f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030050": {//巨力碾压
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                //50%几率打出碾压效果，伤害提升20%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 0.5f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030051": {//乘胜追击
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(1, "*");
                skl.putLearnResultRule("mz", 0.15f, 0f, 1);
                //攻击目标时可能会打出残废效果（持续伤害，持续2回合，目标生命越低越容易触发），同时人物命中上升15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(CanFeiRule);
                item.addTxRule(
                        createEmptyRule(CanFeiRule));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 100, 0),
                        createProbabilityRule(0.1f, 0f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030052": {//恃强凌弱
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(2, "*");
                skl.putLearnResultRule("css", 0.15f, 0f, 1);
                //对残废状态下的目标伤害增加24%，同时出手速上升15%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(GainRule);
                item.addTxRule(
                        createGainRule("attackHurt", 0.06f, 0.2f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1),
                        createConditionRule(CanFeiRule));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030053": {//飞驰电挚
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(2, "*");
                skl.putLearnResultRule("css", 0.05f, 0f, 1);
                //出手速上升5%

                break;
            }
            //二字
            case "100210030054": {//迅击
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0, 0.08f, 1)
                        .putLearnResultRule("fg", 0, 0.08f, 1)
                        .putLearnResultRule("bj", 0, -0.03f, 1);
                //攻击增加8%，同时暴击下降3%
                break;
            }
            case "100210030055": {//淬体
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("max_xue", 0, 0.08f, 1);
                //生命提高8%
                break;
            }
            case "100210030056": {//锻脉
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("max_xue", 0, 0.1f, 1)
                        .putLearnResultRule("bj", 0, -0.03f, 1);
                //生命提高10%，暴击降低3%
                break;
            }
            case "100210030057": {//硬化
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("max_xue", 0, 0.06f, 1)
                        .putLearnResultRule("mz", 0, 0.15f, 1);
                //生命提高6%，命中提升15%
                break;
            }
            case "100210030058": {//凝力
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0, 0.06f, 1)
                        .putLearnResultRule("fg", 0, 0.06f, 1);
                //人物攻击提升6%
                break;
            }
            case "100210030059": {//血刃
                skl = new skill(key);
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0, 0.04f, 1)
                        .putLearnResultRule("fg", 0, 0.04f, 1)
                        .putLearnResultRule("mz", 0, 0.15f, 1);
                //增加4%的攻击，命中提升15%
                break;
            }
            case "100210030060": {//锋锐
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0, 0.03f, 1)
                        .putLearnResultRule("fg", 0, 0.03f, 1);
                //增加3%的攻击，伤害提升6%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.06f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030061": {//腐蚀
                skl = new skill(key);
                skl.isAllowedSD = 0;//是否允许闪避
                skl.bindSkillData(3, "*");
                skl.bindTriggerCondition(0f, 0f, 0, 0f, 0f, 1);
                Vector<skillItem> list = new Vector<>();
                //命中敌人后降低对方15%防御，持续2回合
                skillItem item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("wf", -0.15f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                item = new skillItem(2);
                item.addTxRule(
                        createCurseRule("ff", -0.15f, 0f, 1));
                item.addBaseRules(
                        createTargetRule(2, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);

                skl.skillItems = list;
                break;
            }
            case "100210030062": {//狂攻
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0, 0.1f, 1)
                        .putLearnResultRule("fg", 0, 0.1f, 1)
                        .putLearnResultRule("wf", 0, -0.03f, 1)
                        .putLearnResultRule("ff", 0, -0.03f, 1)
                        .putLearnResultRule("mz", 0, -0.05f, 1);
                //增加10%的攻击，同时降低3%防御和5%命中
                break;
            }
            case "100210030063": {//七伤
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("wg", 0.15f, 0f, 1)
                        .putLearnResultRule("fg", 0.15f, 0f, 1)
                        .putLearnResultRule("sd", -0.3f, 0f, 1);
                //增加15%攻击，同时降低30%闪避
                break;
            }
            case "100210030064": {//炼骨
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("max_xue", 0.13f, 0f, 1)
                        .putLearnResultRule("wf", -0.03f, 0f, 1)
                        .putLearnResultRule("ff", -0.03f, 0f, 1)
                        .putLearnResultRule("sd", -0.05f, 0f, 1);
                //人物生命提升13%，防御降低3%，闪避降低5%

                break;
            }
            case "100210030065": {//铁胆
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("max_xue", 0.08f, 0f, 1)
                        .putLearnResultRule("sd", -0.1f, 0f, 1);
                //人物生命提升15%，闪避降低10%
                break;
            }
            case "100210030066": {//诱杀
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                //当目标被援护时伤害提升至150%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(HurtUpRule);
                item.addTxRule(
                        createHurtUpRule(29, 0f, 1.5f));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 100, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(99, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isReadyCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isHurtTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030067": {//噩梦
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                //命中目标后敌方有10%的几率进入噩梦状态（释放技能时蓝消耗增加至400%，持续2回合）
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(27);
                item.addTxRule(
                        createErMengRule(0, 4));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 100, 0),
                        createProbabilityRule(0f, 0.1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030068": {//愤怒
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                //未命中敌人则增加8%攻击，持续2回合
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.08f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 1f, 0f, 1f),
                        createEffectRule(2, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isNoMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030069": {//碾压
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                //50%几率打出碾压效果，伤害提升10%
                Vector<skillItem> list = new Vector<>();
                skillItem item = new skillItem(1);
                item.addTxRule(
                        createGainRule("attackHurt", 0f, 0.1f, 1));
                item.addBaseRules(
                        createTargetRule(0, 0f, 1f, 1, 0),
                        createProbabilityRule(0f, 0.5f, 0f, 1f),
                        createEffectRule(1, -1),
                        createAddRule(1));
                item.addCreateMoment(skillItemCreateMoment.isMZCreate)
                        .addTriggerMoment(skillItemTriggerMoment.isNoTrigger);
                list.add(item);
                skl.skillItems = list;
                break;
            }
            case "100210030070": {//游龙闪击
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("sd", 0.16f, 0f, 1)
                        .putLearnResultRule("mz", 0.06f, 0f, 1);
                //人物闪避提升16%，命中增加6%
                break;
            }
            case "100210030071": {//游龙
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("sd", 0.12f, 0f, 1)
                        .putLearnResultRule("mz", 0.04f, 0f, 1);
                //人物闪避提升8%，命中增加3%
                break;
            }
            case "100210030072": {//轻影锐攻
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("sd", 0.1f, 0f, 1)
                        .putLearnResultRule("wg", 0.08f, 0f, 1)
                        .putLearnResultRule("fg", 0.08f, 0f, 1)
                        .putLearnResultRule("css", 0.02f, 0f, 1);
                //人物闪避提升10%，攻击增加8%，速度增加4%
                break;
            }
            case "100210030073": {//轻影
                skl = new skill(key);
                skl.isAllowedSD = 0;
                skl.bindSkillData(3, "*");
                skl.putLearnResultRule("sd", 0.08f, 0f, 1)
                        .putLearnResultRule("wg", 0.06f, 0f, 1)
                        .putLearnResultRule("fg", 0.06f, 0f, 1)
                        .putLearnResultRule("css", 0.02f, 0f, 1);
                //人物闪避提升5%，攻击增加4%，速度增加2%
                break;
            }

            //
            //生活技能
            case "100210060000": {
                skl = new skill(key);
                skl.bindSkillData(9, "*");
                skl.putLearnResultRule("max_xue", 30, 0, 0);
                break;
            }
            case "100210060001": {
                skl = new skill(key);
                skl.bindSkillData(9, "*");
                skl.putLearnResultRule("max_lan", 10, 0, 0);
                break;
            }
            case "100210060002": {
                skl = new skill(key);
                skl.bindSkillData(9, "*");
                skl.putLearnResultRule("wg", 5, 0, 0);
                break;
            }
            case "100210060003": {
                skl = new skill(key);
                skl.bindSkillData(9, "*");
                skl.putLearnResultRule("fg", 5, 0, 0);
                break;
            }
            case "100210060004": {
                skl = new skill(key);
                skl.bindSkillData(9, "*");
                skl.putLearnResultRule("wf", 6, 0, 0);
                break;
            }
            case "100210060005": {
                skl = new skill(key);
                skl.bindSkillData(9, "*");
                skl.putLearnResultRule("ff", 6, 0, 0);
                break;
            }
            case "100210060006": {
                skl = new skill(key);
                skl.bindSkillData(9, "*");
                skl.putLearnResultRule("mz", 30, 0, 0);
                break;
            }
            case "100210060007": {
                skl = new skill(key);
                skl.bindSkillData(9, "*");
                skl.putLearnResultRule("sd", 23, 0, 0);
                break;
            }
            case "100210060008": {
                skl = new skill(key);
                skl.bindSkillData(9, "*");
                skl.putLearnResultRule("bj", 12, 0, 0);
                break;
            }
            case "100210060009": {
                skl = new skill(key);
                skl.bindSkillData(9, "*");
                skl.putLearnResultRule("css", 5, 0, 0);
                break;
            }

            default: {
                if (systemUtils.isWindows()) {
                    System.err.println("找不到该技能：" + key);
                }
                break;
            }
        }
        return skl;
    }

    public static skillUtils getInstance() {
        if (skillUtils == null) {
            skillUtils = new skillUtils();
        }
        return skillUtils;
    }
}

/**
 * 战斗技能
 * 输入：key，lever
 * 根据输入的key获取具体的技能，根据技能等级获得效果强度。
 */
