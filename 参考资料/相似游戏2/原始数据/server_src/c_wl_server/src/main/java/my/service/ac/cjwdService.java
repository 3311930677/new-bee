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

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * 锄奸卫道
 */
public class cjwdService {
    /**
     * 核实是否为奸细
     */
    public result isJianxi(JSONObject j,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String npcKey = j.getString("key");
        if (startBef.taskService.isCommit("3272", name, con) == 1) {
            return new result(0);
        }
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getCjwd(name);
        //过12点任务已经刷新
        if (list.size() == 0) return new result(1021);
        JSONObject a = list.get(0);
        if (a.getInteger("times") <= 0) return new result(854);
        int index = a.getInteger("list_index");
        JSONObject msg = createData().get(index);
        if (!npcKey.equals(msg.getString("npcKey"))) {
            //猜错，次数--
            int times = a.getInteger("times") - 1;
            if (times < 0) times = 0;
            dao.updateCjwd(name, times);
            return new result(200, 0);
        }
        return new result(200, 1);
    }

    /**
     * 查看任务描述
     */
    public result viewCjwdTask(
            @paramsAnno(key = "user") user user,
            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getCjwd(name);
        //过12点任务已经刷新
        if (list.size() == 0) return new result(1021);
        JSONObject a = list.get(0);
        int index = a.getInteger("list_index");
        JSONObject msg = createData().get(index);
        msg.put("times", a.getInteger("times"));
        return new result(200, msg);
    }

    /**
     * 接取锄奸卫道任务
     */
    public result getCjwdTask(
            @paramsAnno(key = "user") user user,
            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (user.msg.getInteger("lever") < 80) return new result(613);
        //创建一个战斗任务，但任务toKey对象随机
        JSONObject task = startBef.taskService.createAcTask("3272", name, con);
        //存在任务时返回未完成
        if (task == null) return new result(853);
        //创建锄奸的相关信息，3个门主的提示内容
        int index = getDataIndex();
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        dao.addCjwd(name, index);
        return new result(200, 1);
    }

    /**
     * 随机取一个
     */
    private int getDataIndex() {
        List<JSONObject> al = createData();
        return strUtils.getRandom(0, al.size());
    }

    private List<JSONObject> createData() {
        List<JSONObject> al = new ArrayList<>();

        JSONObject msg = getMsgOne("10000027",
                "子曾经曰过......",
                "他搬家的时候尽是书。",
                "要是你收了个不乖的徒弟，就知道那个人有多重要了。");
        al.add(msg);
        //todo:增加其他的

        return al;
    }

    private JSONObject getMsgOne(String npcKey, String... str) {
        JSONObject msg = new JSONObject();
        List<String> list = new ArrayList<>(Arrays.asList(str));
        msg.put("list", list);
        msg.put("npcKey", npcKey);
        return msg;
    }

}
