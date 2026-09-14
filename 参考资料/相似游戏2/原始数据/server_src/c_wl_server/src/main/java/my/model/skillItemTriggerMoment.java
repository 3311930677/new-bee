package my.model;

/**
 * buff触发的时机
 */
public class skillItemTriggerMoment {
    //针对一些只参与计算而没有实际触发方法的buff
    public static int isNoTrigger = -999;
    //是否在回合开始时生效
    public static int isHuiheStartTriggre = 0;
    //动作开始前生效
    public static int isActionStartTriggre = 1;
    //遍历攻击者技能中包含的buff时生效
    public static int isEachAttackerTriggre = 2;
    //遍历目标身上的buff时生效
    public static int isEachTargetTriggre = 3;
    //受伤时生效
    public static int isMzTriggre = 4;
    //受伤时生效
    public static int isHurtTrigger = 5;
    //加血时生效
    public static int isJiaxueTriggre = 6;
    //打出暴击时触发
    public static int isBaojiTrigger = 7;
    //死亡时触发
    public static int isDieTrigger = 8;
    //触发不死后再触发
    public static int isNoDieTrigger = 9;
    //反击时触发
    public static int isFanjiTrigger = 10;
    //处于某个buff时触发
    public static int isInBuffTrigger = 11;
    //目标遭受伤害时触发
    public static int isSufferHurtTrigger = 12;
    //执行攻击前
    public static int isAttackBeforeTrigger = 13;
    //血量计算完成时触发
    public static int isCountXueDoneTrigger = 14;
    //遭受暴击时触发
    public static int isSufferBaojiTrigger = 15;
    //技能发动前触发（属性转化使用）
    public static int isSklShiFangBefTrigger = 16;
}
