package my.data;

import com.alibaba.fastjson2.JSONArray;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.startBef;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

public class pkData {

    /**
     * 发放周日排位奖励（武勋、仙绝、注灵石奖励）
     */
    public static void sendPaiWeiRewardWeekDay(String name, int a, DefaultSqlSession con) {
        JSONArray list = null;
        if (a == 1) {//无双第一名
            list = rewardUtils.getWxReward(1400);
            //注灵石、高级仙绝
            list = rewardUtils.getGoodsReward("1068", 10, 1,list);
            list = rewardUtils.getGoodsReward("1103", 1, 1,list);
        } else if (a == 2) {
            list = rewardUtils.getWxReward(700);
            //低级仙绝
            list = rewardUtils.getGoodsReward("1068", 5, 1,list);
            list = rewardUtils.getGoodsReward("1104", 1,1, list);
        } else if (a == 3) {
            list = rewardUtils.getWxReward(300);
            list = rewardUtils.getGoodsReward("1068", 3,1, list);
            list = rewardUtils.getGoodsReward("1104", 1,1, list);
        } else {
            list = rewardUtils.getWxReward(100);
            list = rewardUtils.getGoodsReward("1068", 3,1, list);
        }
        startBef.rewardService.saveRewards(list, name, con);
        //通知获得奖励
        ChannelSupervise.noticeClientByName(list, name, "10000");
    }

    /**
     * 发放竞技排行奖励
     */
    public static void sendJJRewardEveryDay(String name, int jd, DefaultSqlSession con) {
        //没打的不发
        if (jd <= 1000) {
            return;
        }
        //根据段位发放积分，让玩家自己去积分商店兑换
        int dw = getDw(jd);
        JSONArray list = null;
        if (dw == 0) {
            list=rewardUtils.getJFReward(100);
        } else if (dw == 1) {
            list=rewardUtils.getJFReward(150);
        } else if (dw == 2) {
            list=rewardUtils.getJFReward(200);
        } else if (dw == 3) {
            list=rewardUtils.getJFReward(400);
        } else if (dw == 4) {
            list=rewardUtils.getJFReward(600);
        } else if (dw == 5) {
            list=rewardUtils.getJFReward(800);
        } else if (dw == 6) {
            list=rewardUtils.getJFReward(1000);
        } else if (dw == 7) {
            list=rewardUtils.getJFReward(1200);
        }
        startBef.rewardService.saveRewards(list, name, con);
        //通知获得奖励
        ChannelSupervise.noticeClientByName(list, name, "10000");
    }

    /**
     * 获取上个段位初始绩点
     */
    public static int getPreDwJd(int jd) {
        if (jd < 2000) {
            return 1000;
        } else if (jd < 2500) {
            return 1500;
        } else if (jd < 3000) {
            return 2000;
        } else if (jd < 3500) {
            return 2500;
        } else if (jd < 4500) {
            return 3000;
        } else if (jd < 5500) {
            return 3500;
        } else if (jd >= 5500) {
            return 4500;//'无双';
        }
        return 1000;
    }

    /**
     * 获取段位
     */
    public static int getDw(int jd) {
        if (jd < 1500) {
            return 0;//'入门';
        } else if (jd < 2000) {
            return 1;//'熟练';
        } else if (jd < 2500) {
            return 2;//'精通';
        } else if (jd < 3000) {
            return 3;//'大成';
        } else if (jd < 3500) {
            return 4;//'大师';
        } else if (jd < 4500) {
            return 5;//'宗师';
        } else if (jd < 5500) {
            return 6;//'超凡';
        } else if (jd >= 5500) {
            return 7;//'无双';
        }
        return -1;
    }
}
