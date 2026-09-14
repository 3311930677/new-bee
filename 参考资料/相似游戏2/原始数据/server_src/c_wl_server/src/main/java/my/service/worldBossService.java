package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.data.mapData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.*;

import static my.utils.staticCollection.hurtMap;

public class worldBossService {
    /**
     * 开启世界boss
     */
    public void startWorldBoss() {
        hurtMap.clear();
        //推送boss刷新
        JSONArray list = new JSONArray();
        list.add(mapData.getOne("world_boss", mapData.getVc(188f, 162f, 65.91118f), null));
        startBef.mapService.pushNpcToClient(list, 2, "m_4", "m_4");
    }

    /**
     * 10分钟结算
     */
    public void worldBossResult() {
        //结算奖励
        List<Map.Entry<String, Integer>> list = new ArrayList<>(hurtMap.entrySet());
        Collections.sort(list, new Comparator<Map.Entry<String, Integer>>() {
            //升序排序
            public int compare(Map.Entry<String, Integer> o1,
                               Map.Entry<String, Integer> o2) {
                return -o1.getValue().compareTo(o2.getValue());
            }
        });
        //初级天元丹、随机一个宠物技能、锻皇宝石
        String sb = "世界boss已结算。恭喜玩家 ";
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            int len = list.size() > 10 ? 10 : list.size();
            for (int i = 0; i < len; i++) {
                String name = list.get(i).getKey();
                sb += name + "、";
                JSONArray rewards = null;
                if (i < 3) {
                    rewards = rewardUtils.getWorldBossReward(true);
                } else {
                    rewards = rewardUtils.getWorldBossReward(false);
                }
                JSONArray l = startBef.rewardService.saveRewards(rewards, name, con);
                ChannelSupervise.noticeClientByName(l, name, "10000");
            }
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }

        sb = sb.substring(0, sb.length() - 1) + " 荣获前三。";
        startBef.chatService.putSysMsg(sb);

        //hurtMap.clear();
    }

    /**
     * 一次战斗结束进行统计伤害
     */
    public Integer count(JSONObject obj) {
        //活动期间才会记载伤害
        if (obj == null || obj.size() == 0 ||
                !startBef.activityService.isOpen("worldBoss")) {
            return 0;
        }
        for (String name : obj.keySet()) {
            int hurt = -obj.getInteger(name);
            if (name.contains("_pet")) {
                name = name.substring(0, name.length() - 4);
            }
            if (hurtMap.get(name) == null) {
                hurtMap.put(name, 0);
            }
            hurtMap.put(name, hurtMap.get(name) + hurt);
        }
        return 1;
    }
}
