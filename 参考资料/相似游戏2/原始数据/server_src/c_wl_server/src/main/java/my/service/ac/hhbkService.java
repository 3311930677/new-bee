package my.service.ac;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.data.mapData;
import my.data.taskData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * 洪荒宝库
 */
public class hhbkService {
    /***
     * 最多能待半个小时
     * 集齐3把钥匙才能进入下一层，
     * 第二层是生死门入口，1生9死，选对进入生门，否则进入死门，
     * 死门需要击败10个怪物才能进入下一层，
     * 生门10个宝箱开两个（有道具可多开一个）
     * 第三层三个宝箱（提交完任务才出现，三选一）
     */
    /**
     * 获取队员或个人
     */
    private JSONArray getTeamMembers(String per) {
        JSONArray list = null;
        JSONObject team = startBef.teamService.getTeamByName(per);
        if (team != null) {
            list = team.getJSONArray("list");
        } else {
            list = new JSONArray();
            JSONObject a = new JSONObject();
            a.put("isFollow", 1);
            a.put("name", per);
            list.add(a);
        }
        return list;
    }

    private boolean isInTeamAndNoCaptain(String per) {
        if (startBef.teamService.getTeamByName(per) != null &&
                !startBef.teamService.isCaptain(per)) {
            return true;
        }
        return false;
    }

    /**
     * 进入洪荒宝库
     */
    public result intoHhbk(@paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String per = user.name;
        //判断是否为队长，需要队长来操作
        if (isInTeamAndNoCaptain(per)) {
            return new result(794);
        }
        //判断队伍中是否存在队员没有道具
        JSONArray list = getTeamMembers(per);

        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        //搜寻的位置信息
        JSONObject search_res = new JSONObject();
        //随机生成3个不重复的藏钥匙的位置
        List<Integer> pos = new ArrayList<>();
        getRandomPos(pos, 3);
        for (int i = 0; i < pos.size(); i++) {
            search_res.put("m" + pos.get(i), 0);
        }
        int shengmenPos = strUtils.getRandom(0, 10);
        long created = strUtils.getTime();

        for (int n = 0; n < list.size(); n++) {
            //消耗一个虚幻之石
            JSONObject mem = list.getJSONObject(n);
            String name = mem.getString("name");
            if (mem.getInteger("isFollow") != 1 || !staticCollection.userIsOnline(name)) {
                mybatisConfig.rollback(con);
                return new result(993);
            }
            if (startBef.packageService.cutPlayerGoodsNumByKey("10000194", 1, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(994);
            }
            //删除之前的数据
            dao.remHHBK(name);
            //重新生成宝库数据
            if (!dao.addHHBK(name, JSON.toJSONString(search_res), "0", shengmenPos + "", "0", "0", "0", created + "")) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            //创建一个任务
            String taskKey = "3274";
            //清理之前的任务
            if (startBef.taskService.isGetTaskList(name, con, taskKey) == 1) {
                startBef.taskService.removeNoSubmitTask(name, con, taskKey);
            }
            if (startBef.taskService.isCommit(taskKey, name, con) == 1) {
                startBef.taskService.removeSubmitTask(name, con, taskKey);
            }
            //创建一个战斗任务
            JSONObject task = startBef.taskService.createAcTask(taskKey, name, con);
        }
        //通知客户端
        for (int n = 0; n < list.size(); n++) {
            JSONObject mem = list.getJSONObject(n);
            String name = mem.getString("name");
            ChannelSupervise.noticeClientByName(1, name, "852");
        }

        return new result(200, 1);
    }

    private void getRandomPos(List<Integer> pos, int len) {
        if (pos.size() >= len) return;
        int v = strUtils.getRandom(0, 10);
        boolean b = false;
        for (int i = 0; i < pos.size(); i++) {
            if (pos.get(i) == v) {
                b = true;
                break;
            }
        }
        if (!b) {
            pos.add(v);
        }
        getRandomPos(pos, len);
    }

    /**
     * 搜索此处
     * 传入当前npc的索引
     */
    public result searchHere(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String per = user.name;
        int index = j.getInteger("index");
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        //搜寻钥匙是共享进度
        JSONArray list = getTeamMembers(per);
        for (int n = 0; n < list.size(); n++) {
            String name = list.getJSONObject(n).getString("name");
            JSONObject a = dao.getHHBK(name).get(0);
            JSONObject search_res = a.getJSONObject("search_res");
            //根据npc的索引判断是否存在钥匙
            if (search_res.containsKey("m" + index)) {
                if (search_res.getInteger("m" + index) == 1) {
                    return new result(200, 1);
                }
                //标记已经找过，钥匙数量+1
                search_res.put("m" + index, 1);
                int num = a.getInteger("yaoshi_num") + 1;
                dao.updateHHBK(name, JSON.toJSONString(search_res), num + "", null, null, null, null, null);
            } else {
                return new result(200, 0);
            }
        }

        return new result(200, 1);
    }

    /**
     * 进入生死门入口
     */
    public result intoShengSiMen(@paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断是否为队长，需要队长来操作
        if (isInTeamAndNoCaptain(name)) {
            return new result(794);
        }
        //判断是否找到3把钥匙
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        JSONObject a = dao.getHHBK(name).get(0);
        int num = a.getInteger("yaoshi_num");
        if (num < 3) return new result(200, 0);
        return new result(200, 1);
    }

    /**
     * 选择生死门
     */
    public result chooseShengSiMen(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断是否为队长，需要队长来操作
        if (isInTeamAndNoCaptain(name)) {
            return new result(794);
        }
        int index = j.getInteger("index");
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        JSONObject a = dao.getHHBK(name).get(0);
        //10个门中选一个，仅一个生门
        if (a.getInteger("sheng_pos") == index) return new result(200, 1);
        return new result(200, 0);
    }

    /**
     * 清除所有死门
     */
    public result clearSiMen(@paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断是否为队长，需要队长来操作
        if (isInTeamAndNoCaptain(name)) {
            return new result(794);
        }
        //消耗一个明心镜
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000195", 1, name, con) != 1)
            return new result(0);
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        JSONObject a = dao.getHHBK(name).get(0);
        return new result(200, a.getInteger("sheng_pos"));
    }

    public void commitMonster(JSONObject j) {
        String monsterKey = j.getString("monsterKey");
        if (!monsterKey.equals("hhbk_2")) return;
        JSONArray ls = j.getJSONArray("names");
        //需要打10次才能进入
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
            for (Object l : ls) {
                JSONObject a = dao.getHHBK(l.toString()).get(0);
                int si_mon_num = a.getInteger("si_mon_num") + 1;
                if (si_mon_num >= 10) si_mon_num = 10;
                dao.updateHHBK(l.toString(), null, null, null, si_mon_num + "", null, null, null);
                mybatisConfig.commit(con);
                ChannelSupervise.noticeClientByName("需要清除的剩余怪物 " + si_mon_num + "/10", l.toString(), "794");
            }
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 进入神龙门（死门处进入）
     */
    public result intoShenLongMenFromSi(@paramsAnno(key = "user") user user,
                                        @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断是否为队长，需要队长来操作
        if (isInTeamAndNoCaptain(name)) {
            return new result(794);
        }
        //判断怪物是否均已消灭（每击败一个怪物数据表中怪物数-1）
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        JSONObject a = dao.getHHBK(name).get(0);
        if (a.getInteger("si_mon_num") >= 10) return new result(200, 1);
        return new result(200, 0);
    }

    /**
     * 生门处开宝箱
     */
    public result openBoxFromSheng(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int type = j.getInteger("type");
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        JSONObject a = dao.getHHBK(name).get(0);
        //0暴力 1钥匙 2再来一罐
        if (type == 0 || type == 1) {
            if (a.getInteger("open_box2") >= 2) return new result(610);
            if (type == 1 && startBef.packageService.cutPlayerGoodsNumByKey("10000196", 1, name, con) != 1) {
                return new result(0);
            }
        } else {
            if (a.getInteger("open_box2") >= 3) return new result(610);
            if (startBef.packageService.cutPlayerGoodsNumByKey("10000198", 1, name, con) != 1) {
                return new result(0);
            }
        }
        int open_box2 = a.getInteger("open_box2") + 1;
        if (!dao.updateHHBK(name, null, null, null, null, open_box2 + "", null, null)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray res = null;
        if (type == 0) {
            res = rewardUtils.getBox2FromHHBK(true);
        } else {
            res = rewardUtils.getBox2FromHHBK(false);
        }
        startBef.rewardService.saveRewards(res, name, con);
        rewardUtils.noticeReward(1, name, res);
        return new result(200, res);
    }

    /**
     * 神龙门处开宝箱
     */
    public result openBoxFromSLM(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int type = j.getInteger("type");
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        JSONObject a = dao.getHHBK(name).get(0);
        //0暴力 1钥匙
        if (type == 0 || type == 1) {
            if (a.getInteger("open_box3") >= 1) return new result(610);
            if (type == 1 && startBef.packageService.cutPlayerGoodsNumByKey("10000197", 1, name, con) != 1) {
                return new result(0);
            }
        } else {
            return new result(0);
        }
        int open_box3 = a.getInteger("open_box3") + 1;
        if (!dao.updateHHBK(name, null, null, null, null, null, open_box3 + "", null)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray res = null;
        if (type == 0) {
            res = rewardUtils.getBox3FromHHBK(true);
        } else {
            res = rewardUtils.getBox3FromHHBK(false);
        }
        startBef.rewardService.saveRewards(res, name, con);
        rewardUtils.noticeReward(1, name, res);
        return new result(200, res);
    }

    /**
     * 宝箱推送
     */
    public void sendBox(String key, List<JSONObject> list, String name, boolean isWsSend) {
        if (!key.equals("3274")) {
            return;
        }
        //推送宝箱
        for (int i = 0; i < 3; i++) {
            list.add(mapData.getOne("10000611", mapData.getVc(90, 100 + 30 * i), null));
        }

        if (isWsSend) {
            JSONArray res = JSONArray.parseArray(JSONObject.toJSONString(list));
            staticCollection.putTask(() -> {
                //ws通知地图生成npc
                startBef.mapService.pushNpcToClient(res, 0, name, "hhbk_3");
            }, 3, TimeUnit.SECONDS);
        }
    }
}
