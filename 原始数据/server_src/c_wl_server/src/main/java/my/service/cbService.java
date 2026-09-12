package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.gangsMapper;
import my.dao.roleMapper;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;

import static my.utils.staticCollection.bMap;

public class cbService {
    /**
     * 获取白、蓝、紫、橙璧排行
     */
    public result getBiOrder(JSONObject obj,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int type = obj.getInteger("type");
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = null;
        if (type == 0) {
            list = activityMapper.getCbOrderByJf1(0L, 10L);
        } else if (type == 1) {
            list = activityMapper.getCbOrderByJf2(0L, 10L);
        } else if (type == 2) {
            list = activityMapper.getCbOrderByJf3(0L, 10L);
        } else if (type == 3) {
            list = activityMapper.getCbOrderByJf4(0L, 10L);
        } else if (type == 4) {//帮派
            list = activityMapper.getCbBpOrderByJf(0L, 10L);
        }
        JSONArray al = new JSONArray();
        if (type < 4 && list.size() > 0) {
            //获取职业、等级
            roleMapper rm = mybatisConfig.getMapper(con, roleMapper.class);
            List names = new ArrayList<>();
            for (int i = 0; i < list.size(); i++) {
                names.add(list.get(i).getString("name"));
            }
            List<JSONObject> roles = rm.selectRoleByNames(names);
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                for (int j = 0; j < roles.size(); j++) {
                    JSONObject b = roles.get(j);
                    if (a.getString("name").equals(b.getString("name")) &&
                            a.getInteger("jf" + (type + 1)) > 0) {
                        JSONObject temp = new JSONObject();
                        temp.put("name", a.get("name"));
                        temp.put("models", b.get("models"));
                        temp.put("lever", b.get("lever"));
                        temp.put("jf", a.get("jf" + (type + 1)));
                        temp.put("order", i + 1);
                        al.add(temp);
                    }
                }
            }
        } else if (type == 4 && list.size() > 0) {
            //获取帮派名
            gangsMapper gm = mybatisConfig.getMapper(con, gangsMapper.class);
            List ids = new ArrayList<>();
            for (int i = 0; i < list.size(); i++) {
                ids.add(list.get(i).getString("bpId"));
            }
            List<JSONObject> gangsList = gm.selectGangsByIds(ids);
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                for (int j = 0; j < gangsList.size(); j++) {
                    JSONObject b = gangsList.get(j);
                    if (a.getString("bpId").equals(b.getString("Id"))) {
                        JSONObject temp = new JSONObject();
                        temp.put("name", b.get("name"));
                        temp.put("jf", a.get("jf"));
                        temp.put("lever", b.get("lever"));
                        temp.put("order", i + 1);
                        al.add(temp);
                    }
                }
            }
        }
        JSONObject res = new JSONObject();
        res.put("totalPage", 1);
        res.put("list", al);
        return new result(200, res);
    }

    /**
     * 周末积分结算
     * （第一名30供香 20 10）
     */
    public void countCb() {
        if (!strUtils.isWKS(2)) {
            return;
        }
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper am = mybatisConfig.getMapper(con, activityMapper.class);
            //获取排行前三的玩家
            List<JSONObject> list = am.getCbOrderByZongJf(0L, 3L);
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                String name = a.getString("name");
                int num = 10;
                String key = "10000143";
                if (i == 0) num = 30;
                else if (i == 1) num = 20;
                JSONArray res = startBef.rewardService.createGoods(key, num, 1, name, con);
                ChannelSupervise.noticeClientByName(res, name, "10000");
            }
            //清理个人、帮派排行
            am.clearCbOrder();
            am.clearCbBpOrder();
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 传壁成功获得奖励
     */
    public JSONArray uploadBSuc(String name, String key, DefaultSqlSession con) {
        JSONArray rewards = new JSONArray();
        String goodsName = null;
        int type = 1;
        //根据key派发武勋
        if (key.equals("10000144")) {
            goodsName = "白壁";
            //低级逆转、固元
            rewardUtils.getGoodsReward("10000168", 1, 1, rewards);
            rewardUtils.getGoodsReward(rewardUtils.getRandomPetDan(1), 1, 1, rewards);
        } else if (key.equals("10000145")) {
            type = 2;
            goodsName = "蓝壁";
            //一级石头、初段、低级逆转、固元
            rewardUtils.getGoodsReward(rewardUtils.getRandomBaoShi(1), 1, 1, rewards);
            rewardUtils.getGoodsReward("10000104", 1, 1, rewards);
            rewardUtils.getGoodsReward("10000168", 1, 1, rewards);
            rewardUtils.getGoodsReward(rewardUtils.getRandomPetDan(1), 1, 1, rewards);
            if (strUtils.isHappend(0, 1000, 0.4f)) {
                rewardUtils.getGoodsReward(rewardUtils.getRandomZhongzi(1), 1, 1, rewards);
            }
        } else if (key.equals("10000146")) {
            type = 3;
            goodsName = "紫壁";
            //聚灵石、二级石头、锻造宝石、低级逆转、概率获得元魂丹/固元
            rewardUtils.getGoodsReward("10000125", 1, 1, rewards);
            rewardUtils.getGoodsReward(rewardUtils.getRandomBaoShi(2), 1, 1, rewards);
            rewardUtils.getGoodsReward("10000105", 1, 1, rewards);
            rewardUtils.getGoodsReward("10000168", 1, 1, rewards);
            if (strUtils.isHappend(0, 1000, 0.2f)) {
                rewardUtils.getGoodsReward(rewardUtils.getRandomPetDan(2), 1, 1, rewards);
            } else {
                rewardUtils.getGoodsReward(rewardUtils.getRandomPetDan(1), 1, 1, rewards);
            }
            if (strUtils.isHappend(0, 1000, 0.4f)) {
                rewardUtils.getGoodsReward(rewardUtils.getRandomZhongzi(2), 1, 1, rewards);
            }
        } else if (key.equals("10000147")) {
            type = 4;
            goodsName = "橙壁";
            //化婴玉
            rewardUtils.getGoodsReward("10000181", 1, 1, rewards);
            //随机三级石头
            rewardUtils.getGoodsReward(rewardUtils.getRandomBaoShi(3), 1, 1, rewards);
            //精锻
            rewardUtils.getGoodsReward("10000106", 1, 1, rewards);
            //中级逆转
            rewardUtils.getGoodsReward("10000169", 1, 1, rewards);
            //仙丹礼包碎片x1
            rewardUtils.getGoodsReward(rewardUtils.getRandomXianDanLiBaoSuiPian(), 1, 1, rewards);
            if (strUtils.isHappend(0, 1000, 0.4f)) {
                rewardUtils.getGoodsReward(rewardUtils.getRandomZhongzi(3), 1, 1, rewards);
            }
        }
        //积分
        //rewardUtils.getCbjfReward(cbjf, rewards);
        //将积分增加到积分榜
        addJf(type, name, con);


        startBef.chatService.putSysMsg("玩家" + name + "上传" + goodsName + "成功！");
        return startBef.rewardService.saveRewards(rewards, name, con);
    }

    private void addJf(int type, String name, DefaultSqlSession con) {
        int jf = 0;
        if (type == 1) jf = 10;
        else if (type == 2) jf = 20;
        else if (type == 3) jf = 50;
        else if (type == 4) jf = 100;
        activityMapper acm = mybatisConfig.getMapper(con, activityMapper.class);
        //个人榜积分
        List<JSONObject> al = acm.getCbOrder(name);
        if (al.size() == 0) {
            acm.addCbOrder(name);
            al = acm.getCbOrder(name);
        }
        long perJf = al.get(0).getLong("jf" + type) + jf;
        if (type == 1)
            acm.updateCbOrder(name, perJf + "", null, null, null);
        else if (type == 2)
            acm.updateCbOrder(name, null, perJf + "", null, null);
        else if (type == 3)
            acm.updateCbOrder(name, null, null, perJf + "", null);
        else if (type == 4)
            acm.updateCbOrder(name, null, null, null, perJf + "");

        //所属帮派的传壁积分也要增加
        user u = staticCollection.getUserByName(name);
        if (u == null || strUtils.isNull(u.msg.get("bp"))) return;
        String bpId = u.msg.getJSONObject("bp").getString("Id");
        al = acm.getCbBpOrder(bpId);
        if (al.size() == 0) {
            acm.addCbBpOrder(bpId);
            al = acm.getCbBpOrder(bpId);
        }
        long bpjf = al.get(0).getLong("jf");
        acm.updateCbBpOrder(bpId, bpjf + jf + "");
    }

    /**
     * 抢壁结果
     */
    public Integer qbRes(String name, String playerName, int win) {
        //将失败者壁交给胜利者
        if (playerName == null || name == null) {
            return 0;
        }
        //抢夺者胜利
        if (win == 1) {
            JSONObject bi = bMap.get(playerName);
            DefaultSqlSession con = null;
            try {
                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                JSONArray list = startBef.rewardService.createGoods(bi.getString("key"), 1, 1, name, con);
                mybatisConfig.commit(con);
                bMap.remove(playerName);
                ChannelSupervise.noticeClientByName(list, name, "10000");
                String bN = getBiName(bi.getString("key"));
                startBef.chatService.putSysMsg("玩家" + playerName + "实力不济，被" + name + "成功夺取" + bN + "一枚！");
            } catch (Exception e) {
                loggerUtils.error("结算抢壁错误：" + e.getMessage(), this.getClass());
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        } else {//抢夺者失败
            //壁恢复可抢夺状态 0表示不允许抢夺
            bMap.get(playerName).put("isQiang", 1);
            //loggerUtils.error(bMap.get(playerName)+"/抢夺失败/ 抢夺者："+name+"   被抢夺者："+playerName,this.getClass());
        }
        return 1;
    }

    /**
     * 传壁定时执行的方法
     */
    public void upResult() {
        long now = strUtils.getTime();
        for (String name : bMap.keySet()) {
            try {
                JSONObject m = bMap.get(name);
                //处于不允许抢的情况，20分钟还没传完就算成功
                if (m.getInteger("isQiang") == 0 && now - m.getLong("created") < 1000 * 60 * 20) {
                    //loggerUtils.error(name+"处于被抢夺中/"+m,this.getClass());
                    continue;
                }
                //用户不在线就将上传的壁退回
                if (!staticCollection.userIsOnline(name) || !staticCollection.isInMap("cbd", name)) {
                    String key = bMap.get(name).getString("key");
                    DefaultSqlSession con = null;
                    try {
                        con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                        if (startBef.rewardService.createGoods(key, 1, 1, name, con) != null) {
                            bMap.remove(name);
                        }
                        mybatisConfig.commit(con);
                    } catch (Exception e) {
                        e.printStackTrace();
                        mybatisConfig.rollback(con);
                    } finally {
                        mybatisConfig.close(con);
                        loggerUtils.info("壁被退还【原因：不在传壁地图/不在线】", this.getClass());
                    }
                    continue;
                }
                //超过5分钟则算成功
                if (now - m.getLong("created") > 1000 * 60 * 5) {
                    DefaultSqlSession con = null;
                    try {
                        con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                        //用线程，不要因为延迟导致10s内未执行完
                        boolean b = false;
                        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
                        //验证是否还有上传次数
                        List<JSONObject> aL = activityMapper.getB(name);
                        if (aL.size() == 0 || aL.get(0).getInteger("uptimes") <= 0) {

                        } else {
                            //上传次数-1
                            if (!activityMapper.updateBUptimes(name, aL.get(0).getInteger("uptimes") - 1 + "")) {

                            } else {
                                b = true;
                            }
                        }
                        if (b) {
                            JSONArray list = uploadBSuc(name, m.getString("key"), con);
                            if (list != null) {
                                bMap.remove(name);
                                //通知奖励
                                ChannelSupervise.noticeClientByName(list, name, "10000");
                            }
                        }
                        mybatisConfig.commit(con);
                    } catch (Exception e) {
                        e.printStackTrace();
                        mybatisConfig.rollback(con);
                    } finally {
                        mybatisConfig.close(con);
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    /**
     * 查看正在上传的壁
     */
    public result viewUpB() {
        int sum = bMap.keySet().size() < 10 ? bMap.keySet().size() : 10;
        int i = 0;
        List list = new ArrayList();
        //long now = strUtils.getTime();
        //随机取，取sum个
        for (String name : bMap.keySet()) {
            if (i < sum) {
                JSONObject m = new JSONObject();
                m.put("key", bMap.get(name).getString("key"));
                //时间戳转距离当前时间的时差
                //long d = bMap.get(name).getLong("created") + 1000 * 60 * 5 - now;
                m.put("created", bMap.get(name).getLong("created") + 1000 * 60 * 5);
                m.put("name", name);
                list.add(m);
                i++;
            }
        }
        return new result(200, list);
    }

    /**
     * 领取壁
     */
    public result gainB(@paramsAnno(key = "user") user user,
                        @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lever = user.msg.getInteger("lever");
        if (lever < 30) return new result(613);

        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getB(name);
        //已领取
        if (list.size() == 0 || list.get(0).getInteger("isget") == 1) {
            return new result(0);
        }
        //设置为已领取
        if (!activityMapper.setBIsGet(name)) {
            return new result(0);
        }
        //生成道具
        int lv = list.get(0).getInteger("lv");
        return new result(200, createB(name, lv, con));
    }

    /**
     * 创建壁
     */
    public JSONArray createB(String name, int lv, DefaultSqlSession con) {
        if (lv > 4 || lv <= 0) return null;
        String key = null;
        if (lv == 1) key = "10000144";
        else if (lv == 2) key = "10000145";
        else if (lv == 3) key = "10000146";
        else key = "10000147";

        JSONArray list = rewardUtils.getGoodsReward(key, 1, 1);
        return startBef.rewardService.saveRewards(list, name, con);
    }

    /**
     * 抢壁
     */
    public result qb(JSONObject j,
                     @paramsAnno(key = "user") user user,
                     @paramsAnno(key = "con") DefaultSqlSession con) {

        final String name = user.name;
        if (!staticCollection.isInMap("cbd", name)) {
            return new result(862);
        }
        //不允许组队
        if (startBef.teamService.getTeamByName(name) != null) {
            return new result(0);
        }
        String playerName = j.getString("playerName");
        //不允许抢夺自己\自己正在传壁
        if (name.equals(playerName) || bMap.get(name) != null || bMap.get(playerName) == null) {
            return new result(200, 0);
        }
        //判断是否允许抢夺
        if (bMap.get(playerName).getInteger("isQiang") == 0 ||
                strUtils.getTime() - bMap.get(playerName).getLong("created") > 5 * 60 * 1000) {
            return new result(200, 0);
        }

        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getB(name);
        if (list.size() == 0) {
            //先插入
            list.add((JSONObject) getB(user, con).getMsg());
        }
        if (list.get(0).getInteger("qbtimes") <= 0)
            return new result(200, 0);
        if (!activityMapper.updateBQbtimes(name, list.get(0).getInteger("qbtimes") - 1 + "")) {
            return new result(200, 0);
        }

        //调取战斗
        int i = startBef.fightRpcService.createFightByCb(name, playerName, con);
        if (i == 0) {
            return new result(200, 0);
        }
        //标记正在抢夺 0表示不允许抢夺
        bMap.get(playerName).put("isQiang", 0);
        return new result(200, 1);
    }

    /**
     * 判断是否是壁
     */
    private boolean isBi(String key) {
        if (key.equals("10000144") || key.equals("10000145") ||
                key.equals("10000146") || key.equals("10000147")) return true;
        return false;
    }

    /**
     * 获取壁的名字
     */
    private String getBiName(String key) {
        if (key.equals("10000144")) return "白璧";
        else if (key.equals("10000145")) return "蓝璧";
        else if (key.equals("10000146")) return "紫璧";
        else if (key.equals("10000147")) return "橙璧";
        return null;
    }

    /**
     * 传壁
     */
    public result uploadB(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {

        final String name = user.name;
        //是否在传壁点
        if (!staticCollection.isInMap("cbd", name)) {
            return new result(862);
        }
        //不允许组队
        if (startBef.teamService.getTeamByName(name) != null) {
            return new result(0);
        }
        String key = j.getString("key");
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        //判断是否有壁正在上传
        if (bMap.get(name) != null) {
            return new result(200, 0);
        }
        //验证是否还有上传次数
        List<JSONObject> list = activityMapper.getB(name);
        if (list.size() == 0 || list.get(0).getInteger("uptimes") <= 0) {
            return new result(200, 0);
        }
        if (!isBi(key)) {
            return new result(0);
        }
        //删除
        int i = startBef.packageService.cutPlayerGoodsNumByKey(key, 1, name, con);
        if (i == 0) {
            return new result(0);
        }
        //将其壁放入缓存
        JSONObject obj = new JSONObject();
        obj.put("key", key);
        obj.put("created", strUtils.getTime());
        //注意：处于抢夺时不允许移除壁
        obj.put("isQiang", 1);//是否允许抢
        bMap.put(name, obj);
        String bN = getBiName(key);
        startBef.chatService.putSysMsg("玩家[" + name + "]正在上传" + bN);
        return new result(200, 1);
    }

    /**
     * 刷新壁
     */
    public result updateB(@paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lever = user.msg.getInteger("lever");
        if (lever < 30) return new result(613);
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getB(name);
        if (list.size() == 0) {
            return new result(200, -1);
        }
        //已领取、刷新次数为0
        if (list.get(0).getInteger("isget") == 1 ||
                list.get(0).getInteger("times") <= 0) {
            return new result(200, -1);
        }
        int end = 2;
        if (lever <= 59) end = 2;
        else if (lever <= 79) end = 3;
        else if (lever <= 99) end = 4;
        else end = 5;
        int lv = strUtils.getRandom(1, end);
        if (activityMapper.updateBLv(name, lv + "", list.get(0).getInteger("times") - 1 + "")) {
            return new result(200, lv);
        }
        return new result(0);
    }

    /**
     * 查看壁
     */
    public result getB(@paramsAnno(key = "user") user user,
                       @paramsAnno(key = "con") DefaultSqlSession con) {

        final String name = user.name;
        //判断玩家等级是否>30级
        JSONObject role = startBef.manService.getRole(name, con);
        int lever = role.getInteger("lever");
        if (lever < 30) {
            return new result(613);
        }
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        //判断是否获取过壁
        List<JSONObject> list = activityMapper.getB(name);
        if (list.size() > 0) {
            return new result(200, list.get(0));
        }
        //1白2蓝3紫4橙
        int end = 2;
        if (lever < 40) {
            end = 2;
        } else if (lever < 60) {
            end = 3;
        } else if (lever < 80) {
            end = 4;
        } else if (lever <= 100) {
            end = 5;
        }
        int lv = strUtils.getRandom(1, end);
        activityMapper.createB(name, lv + "");
        JSONObject res = new JSONObject();
        res.put("name", name);
        res.put("times", 2);
        res.put("qbtimes", 2);
        res.put("uptimes", 2);
        res.put("isget", 0);
        res.put("lv", lv);
        return new result(200, res);
    }
}
