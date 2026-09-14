package my.model;

import java.util.ArrayList;
import java.util.List;

/**
 * 回送的步骤项
 * 客户端需要展示哪些信息？
 * 1.数值（伤害、加血，包括buff）
 * 2.buff（固定减血、增加、减少伤害，增加、减少防御等状态）
 * 3.动画，有技能则按技能动画，无技能时按默认动画
 * 4.对方是否死亡的动画，给个标志
 */
//fixme 是否完备？一个动作（a-b的整个过程）包含多个子行为
public class action extends fight {
    //动作的执行者
    public String control;
    //承受者（可以是自己也可以是目标） 多个（子动作）
    public List<actionItem> actionItems;
    //技能key 执行者播放技能时需要用
    public String skillKey;
    //客户端退出（所有控制的站位都逃跑了）
    public Integer isExist;
    public String clientId;
    //是否逃
    public Integer isTao;
    //是否捕捉
    public Integer isCatch;

    public action(String control, String skillKey) {
        this.actionItems = new ArrayList<>();
        this.control = control;
        this.skillKey = skillKey;
    }

    public action(String control, int isExist, String clientId) {
        this.control = control;
        this.isExist = isExist;
        this.clientId = clientId;
    }

    public action(Integer isSuccess) {
        this.isOver = 1;
        this.isSuccess = isSuccess;
    }

    public void putActionItem(actionItem actionItem) {
        this.actionItems.add(actionItem);
    }

    public void putActionItemFirst(actionItem actionItem) {
        this.actionItems.add(0, actionItem);
    }


}

class fight {
    //是否战斗结束
    public Integer isOver;
    //战斗胜负
    public Integer isSuccess;
    //奖励（经验、道具等）
    public Object reward;
}
