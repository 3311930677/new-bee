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

import static my.utils.staticCollection.jingjiMap;

/**
 * 旧竞技
 */
public class jingjiService {
    /**
     * 获取积分排行
     */
    public result getJingjiOrder(JSONObject j,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        if (j.get("pageNum") == null) return new result(0);
        int pageNum = j.getInteger("pageNum");
        int pageSum = 10;
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        int sum = dao.getJingjiSum().get(0).getInteger("n");
        sum = sum % pageSum == 0 ? (sum / pageSum) : (sum / pageSum + 1);
        List<JSONObject> list = dao.getJingjiOrderByJf((pageNum - 1) * 10L, 10L);
        JSONObject res = new JSONObject();
        res.put("totalPage", sum);
        res.put("list", list);
        return new result(200, res);
    }

    /**
     * 竞技场报名
     */
    public result signUpJingji(@paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        //每日12-14 20-22点
        if ((!strUtils.isInTime(12, 0, 14, 0) &&
                !strUtils.isInTime(20, 0, 22, 0))) {
            //活动未开启
            return new result(696);
        }
        final String name = user.name;
        int lever = startBef.manService.getRole(name, con).getInteger("lever");
        if (lever < 30) {
            return new result(613);
        }
        String key = null;
        if (lever < 100) {
            key = (lever + "").charAt(0) + "0";
        } else {
            key = (lever - 10 + "").charAt(0) + "0";
        }
        JSONObject nameMap = jingjiMap.get(key);
        if (nameMap == null) {
            jingjiMap.put(key, new JSONObject());
            nameMap = jingjiMap.get(key);
        }
        //判断是否已经报过名了
        if (nameMap.get(name) != null) {
            return new result(667);
        }

        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getJingji(name);
        boolean b = false;
        if (list.size() == 0) {
            b = dao.addJingji(name);
        } else {
            //判断次数是否足够
            int num = list.get(0).getInteger("times");
            if (num >= 20) return new result(854);
            b = true;
        }
        if (!b || startBef.packageService.cutPlayerGoodsNumByKey("10000185", 1, name, con) == 0) {
            return new result(637);
        }
        nameMap.put(name, 1);
        return new result(200, 1);
    }

    /**
     * 执行竞技匹配
     */
    public Integer doFight() {
        for (String lv : jingjiMap.keySet()) {
            JSONObject names = jingjiMap.get(lv);
            String a0 = null;
            String a1 = null;
            List<String> removeNames = new ArrayList<>();
            for (String name : names.keySet()) {
                if (!staticCollection.userIsOnline(name)) {
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
                    removeNames.add(a0);
                    removeNames.add(a1);
                    DefaultSqlSession con = null;
                    try {
                        con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                        //开始触发战斗
                        //System.err.println("开始战斗：\n"+a0+" "+a1);
                        //webSocket.noticeClient(a1, a0, "901");
                        startBef.fightRpcService.createFightByJingji(a0, a1, con);
                    } catch (Exception e) {
                        loggerUtils.error(a0 + "/" + a1 + "[竞技场]玩家出错：" + e.getMessage(), this.getClass());
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
     * 周日结算
     */
    public void countJingji() {
        if (!strUtils.isWKS(2)) {
            return;
        }
        //20*20*7=2800
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);

            int pageSum = 10;
            int sum = activityMapper.getJingjiSum().get(0).getInteger("n");
            sum = sum % pageSum == 0 ? (sum / pageSum) : (sum / pageSum + 1);
            for (int i = 0; i < sum; i++) {
                List<JSONObject> list = activityMapper.getJingjiOrderByJf(i * 10L, 10L);
                for (int j = 0; j < list.size(); j++) {
                    JSONObject a = list.get(j);
                    int jf = a.getInteger("jf") / 28;
                    JSONArray rewards = rewardUtils.getJFReward(jf);
                    startBef.rewardService.saveRewards(rewards,a.getString("name"),con);
                    mybatisConfig.commit(con);
                    //通知获得奖励
                    ChannelSupervise.noticeClientByName(rewards, a.getString("name"), "10000");
                }
            }
            activityMapper.remJingji();
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }
}
