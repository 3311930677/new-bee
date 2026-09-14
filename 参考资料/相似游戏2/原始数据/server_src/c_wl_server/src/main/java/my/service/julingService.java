package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
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

import static my.utils.staticCollection.teamMap;

/**
 * 聚灵真火
 */
public class julingService {
    /**
     * 每30s处理一次结果
     */
    public void resHandle() {
        long time = strUtils.getTime();
        List<String> names = new ArrayList<>();
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            for (String name : staticCollection.julingMap.keySet()) {
                JSONObject a = staticCollection.julingMap.get(name);
                if (time > a.getLong("end")) {
                    names.add(name);
                    continue;
                }
                //是否掉线\是否在宠物乐园场景 cwly
                if (!staticCollection.userIsOnline(name) ||
                        !staticCollection.isInMap("cwly", name)) {
                    continue;
                }
                float k = 1f;
                //判断是否组队
                JSONObject team = null;
                if ((team = startBef.teamService.getTeamByName(name)) != null) {
                    team = staticCollection.copyObj(team);
                    JSONArray js = team.getJSONArray("list");
                    //遍历队伍成员，获取队伍id
                    for (Object o : js) {
                        JSONObject obj = (JSONObject) o;
                        if (!obj.getString("name").equals(name) &&
                                staticCollection.userIsOnline(name) &&
                                staticCollection.isInMap("cwly", obj.getString("name")) &&
                                staticCollection.julingMap.get(name) != null) {
                            k += 0.1f;
                        }
                    }
                }

                JSONArray rewards = rewardUtils.getExpReward((int) (a.getInteger("exp") * k));
                rewards = startBef.rewardService.saveRewards(rewards, name, con);
                mybatisConfig.commit(con);
                //通知奖励
                JSONObject res = new JSONObject();
                res.put("list", rewards);
                res.put("end", a.getLong("end"));
                ChannelSupervise.noticeClientByName(res, name, "851");
            }
            mybatisConfig.commit(con);
        } catch (Exception e) {
            mybatisConfig.rollback(con);
            e.printStackTrace();
        } finally {
            mybatisConfig.close(con);
            for (String s : names) {
                staticCollection.julingMap.remove(s);
                //通知聚灵结束
                ChannelSupervise.noticeClientByName("985", s, "799");
            }
        }
    }

    /**
     * 兑换聚灵道具
     */
    public result exchangeJuling(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer type = j.getInteger("type");
        if (type == null || (type < 0 || type > 4)) return new result(0);
        String xhKey = null;
        String dhKey = null;
        int num = 3;
        if (type == 0) {
            xhKey = "10000125";
            dhKey = "10000181";
            num = 3;
        } else if (type == 1) {
            xhKey = "10000181";
            dhKey = "10000182";
            num = 3;
        } else if (type == 2) {
            xhKey = "10000182";
            dhKey = "10000126";
            num = 3;
        } else if (type == 3) {
            xhKey = "10000125";
            dhKey = "10000126";
            num = 27;
        } else if (type == 4) {
            xhKey = "10000125";
            dhKey = "10000182";
            num = 9;
        }
        if (startBef.packageService.cutPlayerGoodsNumByKey(xhKey, num, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray res = rewardUtils.getGoodsReward(dhKey, 1, 1);
        startBef.rewardService.saveRewards(res, name, con);
        return new result(200, res);
    }

    /**
     * 使用道具后开始聚灵
     */
    public Integer startJuLing(String key, String name, DefaultSqlSession con) {
        if (!key.equals("10000125") && !key.equals("10000126") &&
                !key.equals("10000181") && !key.equals("10000182")) {
            return 0;
        }
        if (staticCollection.julingMap.containsKey(name)) {
            JSONObject old = staticCollection.julingMap.get(name);
            //不是同一个key不允许累计时长
            if (!old.getString("key").equals(key)) {
                return 0;
            }
        }
        //每日仅使用3次
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getJuling(name);
        if (list.size() == 0) {
            dao.addJuling(name);
            list = dao.getJuling(name);
        }
        int times = list.get(0).getInteger("times");
        if (times <= 0) {
            return -1;//次数不足
        }
        dao.updateJuling(name, times - 1 + "");

        int lv = startBef.manService.getRoleLv(name, con);
        int exp = 0;
        if (key.equals("10000125")) exp = 4794;
        else if (key.equals("10000181")) exp = 9588;
        else if (key.equals("10000182")) exp = 14382;
        else if (key.equals("10000126")) exp = 19176;

        exp = (int) (exp * (lv / 100f));
        //每半分钟下发一次经验，20分钟就是40次
        JSONObject a = new JSONObject();
        a.put("key", key);
        a.put("exp", exp);
        a.put("end", strUtils.getTime() + 20 * 60 * 1000);
        if (staticCollection.julingMap.containsKey(name)) {
            JSONObject old = staticCollection.julingMap.get(name);
            a.put("end", old.getLong("end") + 20 * 60 * 1000);
        }
        staticCollection.julingMap.put(name, a);

        return 1;
    }
}
