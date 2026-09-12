package my.service.ac;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.gameUtils.rewardUtils;
import my.model.result;
import my.model.user;
import my.startBef;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

/**
 * 采阴补阳、神兽祭
 */
public class cybyService {
    /**兽神祭*/
    public result shoushenji(@paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //消耗1美人香
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000201", 1, name, con) != 1) {
            return new result(0);
        }
        //随机开道具
        JSONArray list= rewardUtils.getBoxReward();
        startBef.rewardService.saveRewards(list,name,con);
        return new result(200,list);
    }
    /**
     * 接取采阴补阳任务
     */
    public result getCybyTask(@paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lv = user.msg.getInteger("lever");
        if (lv < 30) return new result(613);
        //消耗3个美人香
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000201", 3, name, con) != 1) {
            return new result(0);
        }
        String taskKey = "3282";
        //清理之前的任务
        if (startBef.taskService.isGetTaskList(name, con, taskKey) == 1) {
            return new result(853);
        }
        if (startBef.taskService.isCommit(taskKey, name, con) == 1) {
            startBef.taskService.removeSubmitTask(name, con, taskKey);
        }
        //创建一个战斗任务
        JSONObject task = startBef.taskService.createAcTask(taskKey, name, con);
        return new result(200, 1);
    }
}
