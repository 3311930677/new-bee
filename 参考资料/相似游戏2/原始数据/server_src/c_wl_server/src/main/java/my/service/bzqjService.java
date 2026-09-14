package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.db.mybatisConfig;
import my.fightUtils.fightUtils;
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

import static my.utils.staticCollection.whjxMap;

/**
 * 百战千军
 */
public class bzqjService {

    /**
     * 报名
     * 步兵（0）、骑士（150）、先锋（300）、将军（600）、元帅（1000）
     * 每日5场 赢一场20积分 输10积分 7*5*20=700
     */
    public result signUpWHJX(@paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        //22点-23点
        if (!strUtils.isInTime(12, 0, 1, 0) &&
                !strUtils.isInTime(22, 0, 23, 0)) {
            return new result(696);
        }
        final String name = user.name;
        int lever = user.msg.getInteger("lever");
        if (lever < 30) {
            return new result(200, 2);
        }
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> al = activityMapper.getWHJX(name);
        if (al.size() == 0) {
            activityMapper.addWHJX(name, "0", "5");
            JSONObject o = new JSONObject();
            o.put("jf", 0);
            o.put("times", 5);
            al.add(o);
        }
        //判断是否有次数（调起战斗后会减少次数）
        if (al.get(0).getInteger("times") <= 0) {
            return new result(200, 3);
        }
        int jf = al.get(0).getInteger("jf");
        //积分转段位
        String key = null;
        if (jf < 150) {//步兵
            key = "d0";
        } else if (jf < 300) {//骑士
            key = "d1";
        } else if (jf < 600) {//先锋
            key = "d2";
        } else if (jf < 1000) {//将军
            key = "d3";
        } else {//元帅
            key = "d4";
        }

        JSONObject nameMap = whjxMap.get(key);
        if (nameMap == null) {
            whjxMap.put(key, new JSONObject());
            nameMap = whjxMap.get(key);
        }
        //判断是否已经报过名了
        if (nameMap.get(name) != null) {
            return new result(200, 0);
        }
        nameMap.put(name, 1);
        return new result(200, 1);
    }

    /**
     * 获取王侯将相的积分等信息
     */
    public result getMsgWHJX(@paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> al = activityMapper.getWHJX(name);
        if (al.size() == 0) {
            JSONObject o = new JSONObject();
            o.put("jf", 0);
            o.put("times", 5);
            al.add(o);
        }
        return new result(200, al.get(0));
    }

    /**
     * 执行竞技匹配
     */
    public Integer doWHJXFight() {
        //每日指定时间内才会匹配
        if (!strUtils.isInTime(12, 0, 1, 0) &&
                !strUtils.isInTime(22, 0, 23, 0)) {
            return 0;
        }
        for (String lv : whjxMap.keySet()) {
            JSONObject names = whjxMap.get(lv);
            String a0 = null;
            String a1 = null;
            List<String> removeNames = new ArrayList<>();
            for (String name : names.keySet()) {
                if (!staticCollection.userIsOnline(name)) {
                    //对于不在线的移除
                    removeNames.add(name);
                }
                //两个玩家进行匹配，当玩家不在线\正处于队伍时\处于战斗中时跳过
                boolean b = fightUtils.isAllowedFight(name);
                JSONObject team = startBef.teamService.getTeamByName(name);
                if (team != null || !b) {
                    continue;
                }
                if (a0 == null) a0 = name;
                else if (a1 == null) a1 = name;

                if (a0 != null && a1 != null) {
                    //对于匹配上的移除
                    removeNames.add(a0);
                    removeNames.add(a1);
                    DefaultSqlSession con = null;
                    try {
                        con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                        int i = startBef.fightRpcService.createFightByWHJX(a0, a1, con);
                        if (i == 1) {
                            //次数--
                            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
                            List<JSONObject> al = activityMapper.getWHJX(a0);
                            int times = al.get(0).getInteger("times");
                            activityMapper.updateWHJX(a0, null, times - 1 + "");

                            al = activityMapper.getWHJX(a1);
                            times = al.get(0).getInteger("times");
                            activityMapper.updateWHJX(a1, null, times - 1 + "");
                        }
                        mybatisConfig.commit(con);
                    } catch (Exception e) {
                        loggerUtils.error(a0 + "/" + a1 + "[王侯将相]玩家出错：" + e.getMessage(), this.getClass());
                        mybatisConfig.rollback(con);
                    } finally {
                        a0 = null;
                        a1 = null;
                        mybatisConfig.close(con);
                    }
                }
            }
            //移除被标记的name
            for (String a : removeNames) {
                names.remove(a);
            }
            removeNames.clear();
        }
        return 1;
    }

    /**
     * 周日结算（王侯将相）奖励武勋
     */
    public void countWHJX() {
        if (!strUtils.isWKS(2)) {
            return;
        }
        //todo：奖励官爵称号、按官爵给予武勋（兑换道具）
        //步兵（0）、骑士（150）、先锋（300）、将军（600）、元帅（1000） 赢+20输+10
        //一周7天，20*7*5=700 每次结算都会掉一个段位
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            JSONArray rewards = rewardUtils.getJungongReward(50);
            List<JSONObject> list = activityMapper.getSomeWHJX(150, 0);
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(0);
                //降低一个段位
                activityMapper.updateWHJX(a.getString("name"), "0", null);
                startBef.rewardService.saveRewards(rewards, a.getString("name"), con);
                mybatisConfig.commit(con);
                //通知获得奖励
                ChannelSupervise.noticeClientByName(rewards, a.getString("name"), "10000");
            }

            rewards = rewardUtils.getJungongReward(200);
            //获取某个积分段的数据
            list = activityMapper.getSomeWHJX(300, 149);
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(0);
                //降低一个段位
                activityMapper.updateWHJX(a.getString("name"), "0", null);
                startBef.rewardService.saveRewards(rewards, a.getString("name"), con);
                mybatisConfig.commit(con);
                //通知获得奖励
                ChannelSupervise.noticeClientByName(rewards, a.getString("name"), "10000");
            }

            rewards = rewardUtils.getJungongReward(400);
            list = activityMapper.getSomeWHJX(600, 299);
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(0);
                //降低一个段位
                activityMapper.updateWHJX(a.getString("name"), "150", null);
                startBef.rewardService.saveRewards(rewards, a.getString("name"), con);
                mybatisConfig.commit(con);
                //通知获得奖励
                ChannelSupervise.noticeClientByName(rewards, a.getString("name"), "10000");
            }

            rewards = rewardUtils.getJungongReward(800);
            list = activityMapper.getSomeWHJX(1000, 599);
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(0);
                //降低一个段位
                activityMapper.updateWHJX(a.getString("name"), "300", null);
                startBef.rewardService.saveRewards(rewards, a.getString("name"), con);
                mybatisConfig.commit(con);
                //通知获得奖励
                ChannelSupervise.noticeClientByName(rewards, a.getString("name"), "10000");
            }

            rewards = rewardUtils.getJungongReward(1200);
            list = activityMapper.getSomeWHJX(12000, 999);
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(0);
                //降低一个段位
                activityMapper.updateWHJX(a.getString("name"), "600", null);
                startBef.rewardService.saveRewards(rewards, a.getString("name"), con);
                mybatisConfig.commit(con);
                //通知获得奖励
                ChannelSupervise.noticeClientByName(rewards, a.getString("name"), "10000");
            }

        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }
}
