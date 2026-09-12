package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.db.mybatisConfig;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;

public class fbService {
    /**
     * 跳转副本地图
     * 地图为：
     * 50->m_3
     * 60->m_4
     * 70->m_8
     * 80->m_13
     * 90->m_17
     * 100->m_18
     * 跳转地图时有任务的才会显示相关的npc
     * 跳转前会判断是否接取了起始任务，没有会先接取（验证次数）
     */
    public result toFbMap(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String[] taskKeys = null;
        long tale = 0;
        int lv=50;
        String fbKey = j.getString("fbKey");
        if (fbKey.equals("fb50")) {
            taskKeys = addToList("3163", "3164", "3165", "3166", "3167", "3168");
            tale = 1000;
            lv=50;
        } else if (fbKey.equals("fb60")) {
            taskKeys = addToList("3169", "3170", "3171", "3172", "3173", "3174");
            tale = 2000;
            lv=60;
        } else if (fbKey.equals("fb70")) {
            taskKeys = addToList("3174", "3175", "3176", "3177", "3178", "3179", "3180", "3181", "3182", "3183");
            tale = 4000;
            lv=70;
        } else if (fbKey.equals("fb80")) {
            taskKeys = addToList("3184", "3185", "3186", "3187", "3188");
            tale = 6000;
            lv=80;
        } else if (fbKey.equals("fb90")) {
            taskKeys = addToList("3189", "3190", "3192", "3193", "3194", "3195");
            tale = 8000;
            lv=90;
        } else if (fbKey.equals("fb100")) {
            taskKeys = addToList("3196", "3197", "3198","3199","3200","3201", "3202");
            tale = 10000;
            lv=100;
        }else if (fbKey.equals("fbls")) {
            taskKeys = addToList("3203", "3204", "3205","3206","3207","3208","3209","3210","3211", "3212");
            tale = 10000;
            lv=95;
        }else if (fbKey.equals("fbhh")) {
            taskKeys = addToList("3213", "3214", "3215","3216","3217","3218","3219","3220");
            tale = 10000;
            lv=95;
        }else if (fbKey.equals("fbys")) {
            taskKeys = addToList("3221", "3222", "3223","3224","3225","3226","3227", "3228");
            tale = 15000;
            lv=100;
        }else if (fbKey.equals("fbzx")) {
            taskKeys = addToList("3229", "3230", "3231","3232","3233","3234");
            tale = 15000;
            lv=100;
        } else {
            return new result(0);
        }
        int res = 0;
        JSONObject team = startBef.teamService.getTeamByName(name);
        if (team != null) {
            //非队长不允许进入
            if (!team.getString("captain").equals(name))
                return new result(794);
            //银两是否充足
            if (startBef.manService.saveMoney(1, -1 * tale, name, con) != 1)
                return new result(634);
            //判断队员是否都满足等级
            JSONArray list = team.getJSONArray("list");
            for (Object a : list) {
                JSONObject l = (JSONObject) a;
                user u = staticCollection.getUserByName(l.getString("name"));
                if (u == null) {
                    mybatisConfig.rollback(con);
                    return new result(672);
                }
                if (u.msg.getInteger("lever") < lv) {
                    mybatisConfig.rollback(con);
                    return new result(825);
                }
                int r = createFbTask(fbKey, l.getString("name"), taskKeys, con);
                if (l.getString("name").equals(team.getString("captain"))) {
                    res = r;
                }
            }
        } else {
            //判断等级是否满足
            if (user.msg.getInteger("lever") < lv) return new result(825);
            //银两是否充足
            if (startBef.manService.saveMoney(1, -1 * tale, name, con) != 1)
                return new result(634);
            res = createFbTask(fbKey, name, taskKeys, con);
        }
        if (res == -1) {//没有次数
            return new result(200, -1);
        } else if (res == 0) {//数据库操作失败
            return new result(0);
        } else if (res == 1) {//创建任务成功
            return new result(200, 1);
        } else if (res == 2) {//已经存在任务
            return new result(200, 2);
        }
        return new result(200, 1);
    }

    private int createFbTask(String fbKey, String name, String[] taskKeys, DefaultSqlSession con) {
        //判断任务是否已经存在，存在则直接跳转，不存在则先验证次数再创建任务
        JSONArray list = startBef.taskService.getTaskList(name, con);
        boolean b = false;
        //进入前判断是否有任务
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            for (String taskKey : taskKeys) {
                if (obj.getString("key").equals(taskKey)) {
                    b = true;
                    break;
                }
            }
            if (b) {
                break;
            }
        }
        if (b) {
            //直接跳转
            return 2;
        } else {
            //验证次数
            activityMapper acMapper = mybatisConfig.getMapper(con, activityMapper.class);
            List<JSONObject> fbList = acMapper.getFb(name);
            //注册角色时已经插入了
            /*if (fbList.size() == 0) {
                if (!acMapper.insertFb(name)) {
                    mybatisConfig.rollback(con);
                    loggerUtils.error("插入失败", this.getClass());
                    return 0;
                }
                JSONObject obj = new JSONObject();
                obj.put("name", name);
                obj.put("fb50", 3);
                obj.put("fb60", 3);
                obj.put("fb70", 3);
                obj.put("fb80", 3);
                obj.put("fb90", 3);
                obj.put("fb100", 3);
                obj.put("fbls", 2);
                obj.put("fbhh", 2);
                obj.put("fbys", 2);
                obj.put("fbzx", 2);
                obj.put("fbyzj", 1);
                fbList.add(obj);
            }*/
            JSONObject fb = fbList.get(0);
            int n = fb.getInteger(fbKey) - 1;
            //没有次数
            if (n < 0) return -1;
            //fixme:注意，跳转地图时无需重新创建任务，责任交由任务开启检测或每次提交后处理次数--
            /*fb.put(fbKey, n);
            String fb50N = fb.getString("fb50");
            String fb60N = fb.getString("fb60");
            String fb70N = fb.getString("fb70");
            String fb80N = fb.getString("fb80");
            String fb90N = fb.getString("fb90");
            String fb100N = fb.getString("fb100");
            String fblsN = fb.getString("fbls");
            String fbhhN = fb.getString("fbhh");
            String fbysN = fb.getString("fbys");
            String fbzxN = fb.getString("fbzx");
            String fbyzjN = fb.getString("fbyzj");
            //更新副本次数
            if (!acMapper.updateFb(name, fb50N, fb60N, fb70N,
                    fb80N, fb90N, fb100N, fblsN, fbhhN, fbysN, fbzxN,fbyzjN)) {
                mybatisConfig.rollback(con);
                loggerUtils.error("更新失败", this.getClass());
                return 0;
            }
            //移除旧任务
            JSONArray subList = startBef.taskService.getCommitTask(name, con);
            for (String taskKey : taskKeys) {
                for (Object l : subList) {
                    String key = l.toString();
                    if (key.equals(taskKey)) {
                        subList.remove(l);
                        break;
                    }
                }
            }
            startBef.taskService.saveSubmitTask(subList, name, con);
            //生成新任务（前两个）
            String[] ts = {taskKeys[0], taskKeys[1]};
            startBef.taskService.createTasks(ts, name, con);

            //通知接取副本任务
            ChannelSupervise.noticeClientByName(fbKey, name, "813");*/
            return 1;
        }
    }

    private String[] addToList(String... k) {
        return k;
    }
    /*public result toFbMap(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String mapKey = j.getString("mapKey");
        JSONArray list = startBef.taskService.getTaskList(name, con);
        boolean b = false;
        int tale = 0;
        int lv = 1;
        String taskKey = null;
        switch (mapKey) {
            case "fb_50_1": {
                taskKey = "3040";
                tale = -2000;
                break;
            }
            case "fb_60_1": {
                taskKey = "3053";
                tale = -5000;
                lv = 60;
                break;
            }
            case "fb_70_1": {
                taskKey = "3074";
                tale = -8000;
                lv = 70;
                break;
            }
            case "fb_80_1": {
                taskKey = "3078";
                tale = -10000;
                lv = 80;
                break;
            }
            case "fb_90_1": {
                taskKey = "3081";
                tale = -15000;
                lv = 90;
                break;
            }
            case "fb_100_1": {
                taskKey = "3085";
                tale = -20000;
                lv = 100;
                break;
            }
            case "fb_ls_1": {
                taskKey = "3089";
                tale = -20000;
                lv = 100;
                break;
            }
            case "fb_hh_1": {
                taskKey = "3093";
                tale = -20000;
                lv = 100;
                break;
            }
            case "fb_ys_1": {
                taskKey = "3053";
                tale = -20000;
                lv = 100;
                break;
            }
            case "fb_zx_1": {
                taskKey = "3053";
                tale = -20000;
                lv = 100;
                break;
            }
        }
        if (taskKey == null) return new result(0);
        //进入前判断是否有任务
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("key").equals(taskKey)
                    && obj.getInteger("status") != 1) {
                b = true;
                break;
            }
        }
        if (!b) return new result(200, 0);
        int lever = startBef.manService.getRole(name, con).getInteger("lever");
        if (lever < lv || startBef.manService.saveMoney(1, tale, name, con) == 0) {
            return new result(200, 0);
        }
        //todo 验证副本剩余次数

        return new result(200, 1);
    }*/
}
