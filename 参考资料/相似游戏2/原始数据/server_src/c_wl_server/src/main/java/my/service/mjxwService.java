package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.jsonMapper;
import my.db.mybatisConfig;
import my.model.result;
import my.model.user;
import my.startBef;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.List;

/**
 * 摸金校尉活动
 */
public class mjxwService {
    /**
     * 开宝箱
     */
    public result openBox(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String npcKey = j.getString("npcKey");

        String k = null;
        if (npcKey.equals("box1000")) k = "r1";
        else if (npcKey.equals("box1001")) k = "r2";
        else if (npcKey.equals("box1002")) k = "r3";
        else return new result(0);
        //验证今日是否已经开启过了
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getMJXW(name);
        if (list.size() == 0) {
            activityMapper.addMJXW(name);
            JSONObject a = new JSONObject();
            a.put("r1", 0);
            a.put("r2", 0);
            a.put("r3", 0);
            list.add(a);
        }
        int r = list.get(0).getInteger(k);
        if (r == 1) {
            //已经开过
            return new result(200, 0);
        }
        //判断指定的任务是否完成了
        String taskKey = null;
        if (k.equals("r1")) taskKey = "3120";
        else if (k.equals("r2")) taskKey = "3121";
        else if (k.equals("r3")) taskKey = "3122";
        if (startBef.taskService.isCommit(taskKey, name, con) == 0) {
            return new result(200, -1);
        }
        int i = 0;
        //未开启过就生成奖励
        if (k.equals("r1")) {
            activityMapper.updateMJXW(name, "1", null, null);
        } else if (k.equals("r2")) {
            activityMapper.updateMJXW(name, null, "1", null);
        } else if (k.equals("r3")) {
            i = 1;
            activityMapper.updateMJXW(name, null, null, "1");
        }
        JSONArray res = startBef.rewardService.openMjxwBox(i, name, con);
        return new result(200, res);
    }
}
