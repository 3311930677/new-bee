package my.model;

//状态类型 0攻击、1增益、2诅咒、3蛊、4流血、5回血、6吸血、7反震、8伤害转移（背刺）、9魔化、
// 10中毒、11休息、12解除、13复活、14回蓝、15免疫某些buff状态、16属性转化、17斩杀、
//18调整暴击系数、19偷血（指定目标换取血）、20换血（以自身多少血量给与目标伤害）、
//21减少一定比例的血量、22目标处于某状态时伤害扩大倍数、23目标处于某状态时攻击扩大倍数、
// 24奇门遁甲、25无视某些属性、26百分比减蓝、
//27噩梦、28反弹效果(将buff转移给对方)、29为目标抵挡伤害、30低于某个属性多少倍时免伤
//31禁止攻击、32必然暴击、33暴击后增伤（弃用）、34不死、35反击、36连击、37召唤(弃用)、38加血转减血、
//39玩家死亡宠物死亡、40撕裂、41雷电、42偷取对方技能、43禁活、44禁神佑、45保留1血（弃用，合并34）、
//46无敌、47开场秒人物、48减少一定比例的蓝量（弃用）、49残废、
//50增加/减少几率（如暴击）、51增加/减少某个属性、52恐惧、53霸体、54消耗霸体、
public class skillItemRuleType {
    public static int AttackRule = 0;
    public static int GainRule = 1;
    public static int CurseRule = 2;
    public static int GuRule = 3;
    public static int LiuXueRule = 4;
    public static int HuiXueRule = 5;
    public static int XiXueRule = 6;
    public static int FanZhenRule = 7;
    public static int BeiCiRule = 8;
    public static int MoHuaRule = 9;
    public static int ZhongDuRule = 10;

    public static int RestRule = 11;
    public static int RemoveRule = 12;
    public static int FuHuoRule = 13;
    public static int HuiLanRule = 14;
    public static int ImmuneBuffRule = 15;
    public static int AttrChangeRule = 16;
    public static int ZhanShaRule = 17;
    public static int BjKChangeRule = 18;
    public static int TouXueRule = 19;
    public static int HuanXueRule = 20;

    public static int CutXueRule = 21;
    public static int HurtUpRule = 22;
    public static int AttackUpRule = 23;
    public static int QiMenDunJiaRule = 24;
    public static int IgnoreRule = 25;
    public static int CutLanRule = 26;
    public static int ErMengRule = 27;
    public static int BackRule = 28;
    public static int DiDangRule = 29;
    public static int MianShangRule = 30;

    public static int NoAttackRule = 31;
    public static int BiRanBaoJiRule = 32;
    //public static int GainRule = 33;
    public static int NoDieRule = 34;
    public static int FanJiRule = 35;
    public static int LianJiRule = 36;
    //public static int GainRule = 37;
    public static int AddXueToCutXueRule = 38;
    public static int BanShengRule = 39;
    public static int SiLieRule = 40;

    public static int LeiDianRule = 41;
    public static int TouSkillRule = 42;
    public static int JinHuoRule = 43;
    public static int JinShenYouRule = 44;
    //public static int GainRule = 45;
    public static int WuDiRule = 46;
    public static int KillRoleRule = 47;
    //public static int WuDiRule = 48;
    public static int CanFeiRule = 49;
    public static int RateRule = 50;
    public static int addOrCutAttrRule = 51;
    public static int KongJuRule = 52;
    public static int BaTiRule = 53;
    public static int CutBaTiRule = 54;
}
