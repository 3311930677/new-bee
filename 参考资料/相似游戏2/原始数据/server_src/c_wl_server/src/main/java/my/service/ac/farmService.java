package my.service.ac;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;

/**
 * 个人农场
 */
public class farmService {
    private List<JSONObject> getFarmViewData(String name, DefaultSqlSession con) {
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getFarmView(name);
        return list;
    }

    private List<JSONObject> getFarmData(String name, DefaultSqlSession con) {
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getFarm(name);
        if (list.size() == 0) {
            JSONObject td = new JSONObject();
            for (int i = 0; i < 6; i++) {
                JSONObject p = new JSONObject();
                p.put("isOpen", i == 0 ? 1 : 0);//第一块默认打开
                td.put("p" + i, p);
            }
            dao.addFarm(name, JSON.toJSONString(td), "0");
            list = dao.getFarm(name);
        }
        return list;
    }

    private boolean updateFarm(JSONObject td, String times, String gain, String name, DefaultSqlSession con) {
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        return dao.updateFarm(name, td == null ? null : td.toString(), times, gain);
    }

    private boolean isAllowPos(String pos) {
        if (!pos.equals("p0") && !pos.equals("p1") && !pos.equals("p2")
                && !pos.equals("p3") && !pos.equals("p4") && !pos.equals("p5")) {
            return false;
        }
        return true;
    }

    /**
     * 开位置
     * 6个开垦位置（第一个默认开启，其他的需要锄头解锁）
     */
    public result openPos(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //p0-5
        String pos = j.getString("pos");
        if (!isAllowPos(pos)) return new result(0);
        List<JSONObject> list = getFarmData(name, con);
        JSONObject td = list.get(0).getJSONObject("td");
        JSONObject pm = td.getJSONObject(pos);
        //判断是否开垦过
        if (pm.getInteger("isOpen") == 1) return new result(0);
        //消耗一定数量的锄头
        int num = 10;
        if (pos.equals("p2")) num = 20;
        else if (pos.equals("p3")) num = 30;
        else if (pos.equals("p4")) num = 40;
        else if (pos.equals("p5")) num = 50;
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000218", num, name, con) != 1) {
            return new result(0);
        }
        pm.put("isOpen", 1);
        if (!updateFarm(td, null, null, name, con)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, 1);
    }

    /**
     * 种植*
     */
    public result zhongzhi(JSONObject j,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String zzKey = j.getString("key");
        if (!zzKey.substring(0, 4).equals("1013")) return new result(0);
        String pos = j.getString("pos");
        if (!isAllowPos(pos)) return new result(0);
        List<JSONObject> list = getFarmData(name, con);
        JSONObject td = list.get(0).getJSONObject("td");
        JSONObject pm = td.getJSONObject(pos);
        if (pm.getInteger("isOpen") != 1) return new result(0);
        if (startBef.packageService.cutPlayerGoodsNumByKey(zzKey, 1, name, con) != 1) {
            return new result(0);
        }
        //判断位置是否已经被种植，种植则不允许覆盖
        if (pm.containsKey("key")) return new result(0);
        int[] tm = {3, 10, 24};
        int[] sum = {20, 40, 60};
        int lv = Integer.parseInt(zzKey.substring(4)) % 3;
        pm.put("key", zzKey);
        pm.put("created", strUtils.getTime());
        pm.put("tm", tm[lv] * 1000 * 60 * 60L);//收获需要的时长
        pm.put("num", sum[lv]);
        pm.put("sum", sum[lv]);
        if (!updateFarm(td, null, null, name, con)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, 1);
    }

    /**
     * 铲除*
     */
    public result chanchu(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;

        String pos = j.getString("pos");
        if (!isAllowPos(pos)) return new result(0);
        List<JSONObject> list = getFarmData(name, con);
        JSONObject td = list.get(0).getJSONObject("td");
        JSONObject pm = td.getJSONObject(pos);
        if (pm.getInteger("isOpen") != 1) return new result(0);
        //判断位置是否已经被种植，种植的才需要铲除
        if (!pm.containsKey("key")) return new result(0);
        //消耗一定数量的锄头
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000218", 10, name, con) != 1) {
            return new result(0);
        }
        clearTd(pm);
        if (!updateFarm(td, null, null, name, con)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, 1);
    }

    private void clearTd(JSONObject pm) {
        pm.remove("key");
        pm.remove("created");
        pm.remove("tm");
        pm.remove("num");
        pm.remove("sum");
    }

    /**
     * 领取种子
     */
    public result gainZhongZi(@paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断是否已经在线30分钟
        if (startBef.logService.isEnoughAccumulate(1000 * 60 * 30, name, con) != 1) {
            return new result(698);
        }
        List<JSONObject> list = getFarmData(name, con);
        int gain = list.get(0).getInteger("gain");
        if (gain == 1) return new result(784);
        if (updateFarm(null, null, "1", name, con)) {
            String k = strUtils.getRandom(0, 21) + "";
            if (k.length() == 1) k = "000" + k;
            else if (k.length() == 2) k = "00" + k;
            else if (k.length() == 3) k = "0" + k;
            JSONArray res = rewardUtils.getGoodsReward("1013" + k, 1, 1);
            startBef.rewardService.saveRewards(res, name, con);
            return new result(200, res);
        }
        return new result(0);
    }

    /**
     * 获取农场信息*
     */
    public result getMyFarmMsg(@paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        List<JSONObject> list = getFarmData(name, con);
        JSONObject a = list.get(0);
        a.remove("name");
        a.put("td", a.getJSONObject("td"));
        return new result(200, a);
    }

    public result getPlayerFarmMsg(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String playerName = j.getString("playerName");
        if (strUtils.isNull(playerName)) return new result(0);
        List<JSONObject> list = getFarmData(playerName, con);
        JSONObject a = list.get(0);
        a.remove("name");
        a.put("td", a.getJSONObject("td"));
        return new result(200, a);
    }

    /**
     * 摘取
     */
    public result zhaiqu(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String pos = j.getString("pos");
        if (!isAllowPos(pos)) return new result(0);
        List<JSONObject> list = getFarmData(name, con);
        JSONObject td = list.get(0).getJSONObject("td");
        JSONObject pm = td.getJSONObject(pos);
        if (pm.getInteger("isOpen") != 1) return new result(0);
        //判断位置是否已经被种植，种植的才需要铲除
        if (!pm.containsKey("key")) return new result(0);
        //是否成熟
        long now = strUtils.getTime();
        if ((now > pm.getLong("tm") + pm.getLong("created"))) {
            int num = pm.getInteger("num");
            String zzKey = pm.getString("key");
            clearTd(pm);
            if (!updateFarm(td, null, null, name, con)) {
                return new result(0);
            }
            JSONArray al = rewardUtils.getGoodsReward(zzKeyToGdKey(zzKey), num, 1);
            startBef.rewardService.saveRewards(al, name, con);
            return new result(200, al);
        }
        return new result(0);
    }

    /**
     * 种子的key转道具的key
     */
    private String zzKeyToGdKey(String zzKey) {
        //"玄铁矿", "炼神木", "锄头", "槐树叶", "银票", "丹青", "羊毛笔"
        String[] keys = {
                "10000173", "10000172", "10000218", "10150000",
                "10000220", "10150001", "10150002",
        };
        int index = Integer.parseInt(zzKey.substring(4)) / 3;
        return keys[index];
    }

    /**
     * 获取好友农场信息*
     */
    public result getMyFriendFarmMsg(@paramsAnno(key = "user") user user,
                                     @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //先获取好友列表，然后再标记哪些是开通了农场的，哪些可被偷取
        JSONArray list = startBef.friendService.getAllFriend(name, con);
        List<JSONObject> res = new ArrayList<>();
        long now = strUtils.getTime();
        for (int i = 0; i < list.size(); i++) {
            String n = list.getString(i);
            if (n.equals(name)) continue;//排除自己
            JSONObject a = new JSONObject();
            a.put("name", n);
            List<JSONObject> al = getFarmViewData(n, con);
            if (al.size() == 0) {
                a.put("isOpen", 0);//未开通
            } else {
                a.put("isOpen", 1);
                JSONObject m = al.get(0);
                JSONObject td = m.getJSONObject("td");
                for (String pos : td.keySet()) {
                    JSONObject pm = td.getJSONObject(pos);
                    //是否成熟
                    if (pm.containsKey("key") &&
                            (now > pm.getLong("tm") + pm.getLong("created"))) {
                        if (pm.getInteger("num") > pm.getInteger("sum") * 0.5f) {
                            a.put("isGet", 1);//表示可摘取
                            break;
                        }
                    }
                }
            }
            res.add(a);
        }
        return new result(200, res);
    }

    /**
     * 获取帮派成员农场列表*
     */
    public result getGangsMemberFarm(@paramsAnno(key = "user") user user,
                                     @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        if (bpId == null) return new result(0);
        List<JSONObject> list = startBef.gangsService.viewMembersNames(bpId, con);
        List<JSONObject> res = new ArrayList<>();
        long now = strUtils.getTime();
        for (int i = 0; i < list.size(); i++) {
            String n = list.get(i).getString("name");
            if (n.equals(name)) continue;//排除自己
            JSONObject a = new JSONObject();
            a.put("name", n);
            List<JSONObject> al = getFarmViewData(n, con);
            if (al.size() == 0) {
                a.put("isOpen", 0);//未开通
            } else {
                a.put("isOpen", 1);
                JSONObject m = al.get(0);
                JSONObject td = m.getJSONObject("td");
                for (String pos : td.keySet()) {
                    JSONObject pm = td.getJSONObject(pos);
                    //是否成熟
                    if (pm.containsKey("key") &&
                            (now > pm.getLong("tm") + pm.getLong("created"))) {
                        if (pm.getInteger("num") > pm.getInteger("sum") * 0.5f) {
                            a.put("isGet", 1);//表示可摘取
                            break;
                        }
                    }
                }
            }
            res.add(a);
        }
        return new result(200, res);
    }

    /**
     * 偷菜*
     */
    public result touCai(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //每日仅能偷取10次
        String pos = j.getString("pos");
        String playerName = j.getString("playerName");
        if (!isAllowPos(pos) || strUtils.isNull(playerName)) return new result(0);
        //是否还有次数
        int t = getFarmData(name, con).get(0).getInteger("times");
        if (t >= 10) return new result(610);

        List<JSONObject> list = getFarmData(playerName, con);
        JSONObject td = list.get(0).getJSONObject("td");
        JSONObject pm = td.getJSONObject(pos);
        if (pm.getInteger("isOpen") != 1) return new result(0);
        //判断位置是否已经被种植，种植的才需要铲除
        if (!pm.containsKey("key")) return new result(0);
        //是否成熟
        long now = strUtils.getTime();
        if ((now > pm.getLong("tm") + pm.getLong("created"))) {
            int num = pm.getInteger("num");
            String zzKey = pm.getString("key");
            //大于总数的50%才允许偷取
            int sum = pm.getInteger("sum");
            if (num <= sum / 2) {
                return new result(1020);
            }
            //每次只能拿1-5个
            int n = strUtils.getRandom(1, 6);
            if (num - n < sum / 2) n = sum / 2 - num;
            if (n < 1) n = 1;
            pm.put("num", num - n);
            //更改对方田地
            if (!updateFarm(td, null, null, playerName, con)) {
                return new result(0);
            }
            //更新自己的次数
            if (!updateFarm(null, t + 1 + "", null, name, con)) {
                return new result(0);
            }
            JSONArray al = rewardUtils.getGoodsReward(zzKeyToGdKey(zzKey), n, 1);
            startBef.rewardService.saveRewards(al, name, con);
            return new result(200, al);
        }
        return new result(0);
    }

}
