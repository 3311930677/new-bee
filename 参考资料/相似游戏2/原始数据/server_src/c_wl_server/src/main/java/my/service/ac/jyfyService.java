package my.service.ac;

import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.model.result;
import my.model.user;
import my.startBef;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

/**
 * 监狱风云
 */
public class jyfyService {
    /**
     * 接取监狱风云任务
     */
    public result getJyfyTask(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lv = user.msg.getInteger("lever");
        if (lv < 30) return new result(613);
        int type = j.getInteger("type");
        //消耗1000元宝接取
        if (startBef.manService.saveMoney(0, -1000L, name, con) != 1) {
            return new result(0);
        }
        String taskKey = null;
        if (type == 0) taskKey = "3283";
        else if (type == 1) taskKey = "3284";
        else if (type == 2) taskKey = "3285";
        else if (type == 3) taskKey = "3286";
        else if (type == 4) taskKey = "3287";
        else return new result(0);
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
