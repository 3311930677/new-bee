package my.model;

/**
 * 技能buff创建的时机
 */
public class skillItemCreateMoment {
    //不需要创建
    public static int isNoCreate = -999;
    //是否在战斗准备阶段创建
    public static int isReadyCreate = 0;
    //是否在遍历攻击者技能中包含的buff时创建
    public static int isEachAttackerCreate = 1;
    //命中时创建
    public static int isMZCreate = 2;
    //目标发生闪躲时创建
    public static int isSDCreate = 3;
    //对目标造成伤害时创建（主动）
    public static int isHurtCreate = 4;
    //遭受伤害时创建
    public static int isSufferHurtCreate = 5;
    //技能发动时创建
    //public static int isSkillCreate = 6;
    //动作开始时创建
    public static int isAttackStartCreate = 7;
    //回合开始时创建
    public static int isHuiheStartCreate = 8;
    //低血量时创建
    public static int isLowXueCreate = 9;
    //反击时创建
    public static int isFanjiCreate = 10;
    //触发不死时创建
    public static int isNoDieCreate = 11;
    //暴击时创建
    public static int isBaojiCreate = 12;
    //遭受暴击时创建
    public static int isSufferBaojiCreate = 13;
    //未命中时创建（是为control创建，闪躲时创建是为target创建）
    public static int isNoMZCreate = 14;
    //死亡时创建
    public static int isDieCreate = 15;
    //技能发动前
    public static int isSklShiFangBefCreate = 16;
}
