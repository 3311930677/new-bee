package my.service.ac;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.jsonMapper;
import my.data.equipData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.gameUtils.roleUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.function.Function;

/**
 * 开服活动
 */
public class openServerAcService {
    /**
     * 活动启动通知
     */
    public void startNotice() {
        startBef.chatService.putSysMsg("开服活动已开启");
    }

    /**
     * 对排名结算
     * 冲刺等级排名领礼物(7天)
     */
    public void endCount() {
        Function<DefaultSqlSession, Object> fn = (con) -> {
            jsonMapper am = mybatisConfig.getMapper(con, jsonMapper.class);
            List<JSONObject> list = am.selectLvOrderByPage(0L, 50L);
            if (list.size() == 0) return null;
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                String name = a.getString("name");
                JSONArray rewards = new JSONArray();
                if (i == 0) {//第一名
                    //刻印宝石、仙决宝箱、龙头金票*5、高级宠物蛋
                    rewardUtils.getGoodsReward("10000150", 1, 1, rewards);
                    rewardUtils.getGoodsReward("10000112", 1, 1, rewards);
                    rewardUtils.getGoodsReward("10000000", 5, 0, rewards);
                    rewardUtils.getGoodsReward("10000141", 1, 1, rewards);
                } else if (i == 1) {
                    //人物刻印卷轴x5、龙头金票*2、中级宠物蛋
                    rewardUtils.getGoodsReward("10000164", 5, 1, rewards);
                    rewardUtils.getGoodsReward("10000000", 2, 0, rewards);
                    rewardUtils.getGoodsReward("10000141", 1, 1, rewards);
                } else if (i == 2) {
                    //人物刻印卷轴x2、龙头金票*1、中级宠物蛋
                    rewardUtils.getGoodsReward("10000164", 2, 1, rewards);
                    rewardUtils.getGoodsReward("10000000", 1, 0, rewards);
                    rewardUtils.getGoodsReward("10000141", 1, 1, rewards);
                } else if (i < 10) {//前10
                    //锻造宝石x20、龙头银票*1、
                    rewardUtils.getGoodsReward("10000105", 20, 1, rewards);
                    rewardUtils.getGoodsReward("10000001", 1, 0, rewards);
                } else {//前50
                    //初锻x20、龙头小票*1、
                    rewardUtils.getGoodsReward("10000104", 20, 1, rewards);
                    rewardUtils.getGoodsReward("10000002", 1, 0, rewards);
                }
                startBef.rewardService.saveRewards(rewards, name, con);
                ChannelSupervise.noticeClientByName(rewards, name, "10000");
            }
            startBef.chatService.putSysMsg("开服活动已结束，奖励已发放至背包");
            return null;
        };
        mybatisConfig.putTask(fn);
    }

    /**
     * 签到助力升级礼（7天）
     */
    public result getQianDaoGift(@paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        if (!strUtils.isInDay("2026-02-11 00:00:00", "2026-02-18 23:55:00")) {
            return new result(696);
        }
        final String name = user.name;
        int lv = user.msg.getInteger("lever");
        if (lv < 30) return new result(0);
        //要求必须先选择职业
        JSONObject role = startBef.manService.getRole(name, con);
        int len = role.getJSONArray("models").size();
        if (len < 3) {
            return new result(0);
        }
        activityMapper am = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = am.getOpenServerQianDaoGift(name);
        if (list.size() == 0) {
            am.addOpenServerQianDaoGift(name);
            list = am.getOpenServerQianDaoGift(name);
        }
        JSONObject a = list.get(0);
        if (a.getInteger("gain") == 1) return new result(610);
        int day_sum = a.getInteger("day_sum");
        //超过7天的就不再赠送
        if (day_sum > 7) return new result(610);
        if (am.updateOpenServerQianDaoGift(name, "1", day_sum + 1 + "")) {
            JSONArray rewards = new JSONArray();
            String model = roleUtils.getModel(role);
            int index = roleUtils.jobToIndex(model);
            if (day_sum == 0) {
                //50级武器-紫套、天元精髓*5
                String eqKey = equipData.getEquipKey(2, 0, index, 4, 5);
                rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
                rewardUtils.getGoodsReward("10000126", 5, 1, rewards);
            } else if (day_sum == 1) {
                //50级项链-紫套、天元精髓*7
                String eqKey = equipData.getEquipKey(2, 1, index, 4, 5);
                rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
                rewardUtils.getGoodsReward("10000126", 7, 1, rewards);
            } else if (day_sum == 2) {
                //50级戒指-紫套、天元精髓*8
                String eqKey = equipData.getEquipKey(2, 2, index, 4, 5);
                rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
                rewardUtils.getGoodsReward("10000126", 8, 1, rewards);
            } else if (day_sum == 3) {
                //50级手链-紫套、天元精髓*9
                String eqKey = equipData.getEquipKey(2, 3, index, 4, 5);
                rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
                rewardUtils.getGoodsReward("10000126", 9, 1, rewards);
            } else if (day_sum == 4) {
                //50级帽子-紫套、天元精髓*10
                String eqKey = equipData.getEquipKey(2, 4, index, 4, 5);
                rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
                rewardUtils.getGoodsReward("10000126", 10, 1, rewards);
            } else if (day_sum == 5) {
                //50级胸甲-紫套、天元精髓*10
                String eqKey = equipData.getEquipKey(2, 5, index, 4, 5);
                rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
                rewardUtils.getGoodsReward("10000126", 10, 1, rewards);
            } else if (day_sum == 6) {
                //50级腰带-紫套、天元精髓*10
                String eqKey = equipData.getEquipKey(2, 6, index, 4, 5);
                rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
                rewardUtils.getGoodsReward("10000126", 10, 1, rewards);
            } else return new result(0);
            startBef.rewardService.saveRewards(rewards, name, con);
            return new result(200, rewards);
        }
        return new result(0);
    }

    /**
     * 等级礼包（7天）
     */
    public result getLvGift(JSONObject j, @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        if (!strUtils.isInDay("2026-02-11 00:00:00", "2026-02-18 23:55:00")) {
            return new result(696);
        }
        final String name = user.name;
        int type = j.getInteger("type");
        //30 40 50 60 70 80 90 100
        if (type < 0 || type > 7) return new result(0);
        int lv = user.msg.getInteger("lever");
        if ((type == 0 && lv < 30) || (type == 1 && lv < 40) || (type == 2 && lv < 50) ||
                (type == 3 && lv < 60) || (type == 4 && lv < 70) || (type == 5 && lv < 80) ||
                (type == 6 && lv < 90) || (type == 7 && lv < 100)) return new result(0);
        //要求必须先选择职业
        JSONObject role = startBef.manService.getRole(name, con);
        int len = role.getJSONArray("models").size();
        if (len < 3) {
            return new result(0);
        }
        //验证是否已经领取过
        activityMapper am = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = am.getOpenServerLvGift(name);
        if (list.size() == 0) {
            am.addOpenServerLvGift(name);
            list = am.getOpenServerLvGift(name);
        }
        JSONObject a = list.get(0);
        //已经领取
        if (a.getInteger("g" + type) != 0) return new result(1025);
        String model = roleUtils.getModel(role);
        int index = roleUtils.jobToIndex(model);
        //标志为已经领取
        JSONArray rewards = new JSONArray();
        boolean b = false;
        if (type == 0) {
            //初锻*5 30级蓝色套装-武器
            rewardUtils.getGoodsReward("10000104", 5, 1, rewards);
            String eqKey = equipData.getEquipKey(1, 0, index, 2, 5);
            rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
            b = am.updateOpenServerLvGift(name, "1", null, null, null,
                    null, null, null, null);
        } else if (type == 1) {
            //精炼宝石*5 40级蓝色套装-武器
            rewardUtils.getGoodsReward("10000109", 5, 1, rewards);
            String eqKey = equipData.getEquipKey(1, 0, index, 3, 5);
            rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
            b = am.updateOpenServerLvGift(name, null, "1", null, null,
                    null, null, null, null);
        } else if (type == 2) {
            //锻造宝石*5 潜力符石*1
            rewardUtils.getGoodsReward("10000105", 5, 1, rewards);
            rewardUtils.getGoodsReward("10000114", 1, 1, rewards);
            String eqKey = equipData.getEquipKey(1, 0, index, 4, 5);
            rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
            b = am.updateOpenServerLvGift(name, null, null, "1", null,
                    null, null, null, null);
        } else if (type == 3) {
            //宠物经验丹*5 诱敌*2
            rewardUtils.getGoodsReward("10000029", 5, 1, rewards);
            rewardUtils.getGoodsReward("10000184", 2, 1, rewards);
            String eqKey = equipData.getEquipKey(1, 0, index, 5, 5);
            rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
            b = am.updateOpenServerLvGift(name, null, null, null, "1",
                    null, null, null, null);
        } else if (type == 4) {
            //宠物经验丹*5 扬善*2
            rewardUtils.getGoodsReward("10000029", 5, 1, rewards);
            rewardUtils.getGoodsReward("10000187", 2, 1, rewards);
            String eqKey = equipData.getEquipKey(1, 0, index, 6, 5);
            rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
            b = am.updateOpenServerLvGift(name, null, null, null,
                    null, "1", null, null, null);
        } else if (type == 5) {
            //宠物经验丹*5 潜力激发*2
            rewardUtils.getGoodsReward("10000029", 5, 1, rewards);
            rewardUtils.getGoodsReward("10000210", 2, 1, rewards);
            String eqKey = equipData.getEquipKey(1, 0, index, 7, 5);
            rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
            b = am.updateOpenServerLvGift(name, null, null, null,
                    null, null, "1", null, null);
        } else if (type == 6) {
            //宠物经验丹*5 天元丹
            rewardUtils.getGoodsReward("10000029", 5, 1, rewards);
            rewardUtils.getGoodsReward("10000213", 1, 1, rewards);
            String eqKey = equipData.getEquipKey(1, 0, index, 8, 5);
            rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
            b = am.updateOpenServerLvGift(name, null, null, null,
                    null, null, null, "1", null);
        } else if (type == 7) {
            //宠物经验丹*5 明心悟性*5 宠物回天书*1
            rewardUtils.getGoodsReward("10000029", 5, 1, rewards);
            rewardUtils.getGoodsReward("10000130", 5, 1, rewards);
            rewardUtils.getGoodsReward("10000120", 1, 1, rewards);
            rewardUtils.getGoodsReward("10000128", 1, 1, rewards);
            String eqKey = equipData.getEquipKey(1, 0, index, 9, 5);
            rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
            b = am.updateOpenServerLvGift(name, null, null, null,
                    null, null, null, null, "1");
        } else return new result(0);
        if (!b) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //保存奖励
        startBef.rewardService.saveRewards(rewards, name, con);
        return new result(200, rewards);
    }


}
