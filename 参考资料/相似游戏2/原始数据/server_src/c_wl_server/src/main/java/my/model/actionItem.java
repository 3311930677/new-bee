package my.model;

import java.util.ArrayList;
import java.util.List;

public class actionItem {

    //群攻（众多目标之一）
    public String target;
    //发生的状态类型
    public Integer statusType;
    //展示的值
    public Integer value;
    //是否死亡
    public Integer isDie;
    //是否闪避
    public Integer isSd;
    //是否休息
    public Integer isRest;
    //提示的key（比如：物防、受伤等）
    public String tipKey;
    //是否捕捉成功
    public Integer isCatch;
    //是否暴击
    public Integer isBaoJi;
    //援护对象站位
    public String helper;
    //参数 可以是技能
    public Object msg;
    //客户端是否不提示该buff（如使用技能时耗蓝不需要提示）
    public Integer isNoShowBuff;
    //fixme 注意： 多个攻击值时就是多个子动作。所有站位都当作目标，再也没有执行者这一概念
    //技能的buff状态持续多久
    public Integer statusKeep;
    //buff当前叠加数目
    public Integer buffNowAddNum;

    public actionItem(String target) {
        this.target = target;
    }


}
