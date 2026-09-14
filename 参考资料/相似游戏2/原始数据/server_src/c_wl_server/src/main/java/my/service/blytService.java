package my.service;

import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.db.mybatisConfig;
import my.model.result;
import my.model.user;
import my.startBef;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.List;

/**
 * 百炼妖塔
 */
public class blytService {
    /**
     * 获取当前挑战层数
     */
    public result getLever(@paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getBLYT(name);
        if (list.size() == 0) {
            activityMapper.addBLYT(name);
            list = activityMapper.getBLYT(name);
        }
        return new result(200, list.get(0).get("lever"));
    }

    /**
     * 挑战
     */
    public result tz(JSONObject jb,
                     @paramsAnno(key = "user") user user,
                     @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if(user.msg.getInteger("lever")<50) return new result(613);

        int lever = jb.getInteger("lever");
        //验证是否达到该层
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getBLYT(name);
        JSONObject one = list.get(0);
        if (one.getInteger("lever") != lever || lever > 70) {
            return new result(934);//已击败
        }
        //调用战斗
        return startBef.fightRpcService.createFightBLYT(lever, user, con);
    }


}
