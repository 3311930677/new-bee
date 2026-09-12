package my.service.ac;

import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.db.mybatisConfig;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.List;

/**
 * 仗剑除魔
 */
public class zjcmService {
    /**
     * 获取任务所在地图
     */
    public result viewMapKey(@paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getZJCM(name);
        if (list.size() == 0) {
            return new result(1021);
        }
        return new result(200, list.get(0).getString("map_key"));
    }

    /**
     * 接取任务
     */
    public result getTask(@paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getZJCM(name);
        if (list.size() == 0) {
            dao.addZJCM(name, "");
            list = dao.getZJCM(name);
        }
        int times = list.get(0).getInteger("times");
        if (times <= 0) {
            return new result(610);
        }
        String taskKey = "3273";
        //清理之前的任务
        if (startBef.taskService.isGetTaskList(name, con, taskKey) == 1) {
            return new result(853);
        }
        if (startBef.taskService.isCommit(taskKey, name, con) == 1) {
            startBef.taskService.removeSubmitTask(name, con, taskKey);
        }
        //创建一个战斗任务
        JSONObject task = startBef.taskService.createAcTask(taskKey, name, con);
        //生成一个地图位置
        String mapKey = "m_" + strUtils.getRandom(1, 102);
        dao.updateZJCM(name, times - 1 + "", mapKey);
        return new result(200, 1);
    }
}
