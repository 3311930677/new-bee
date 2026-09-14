package my.service.ac;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.result;
import my.model.user;
import my.startBef;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;

/**
 * 天晶石、玉魄石
 */
public class tjypService {
    /**
     * 兑换天晶
     */
    public result exchangeTianJing(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int type = j.getInteger("type");
        String xhKey = null;
        int num = 3;
        int exp = 0;
        int tale = 0;
        if (type == 0) {
            xhKey = "10000190";
            num = 5;
            exp = 34751;
            tale = 8641;
        } else if (type == 1) {
            xhKey = "10000190";
            num = 10;
            exp = 144550;
            tale = 35947;
        } else return new result(0);
        if (startBef.packageService.cutPlayerGoodsNumByKey(xhKey, num, name, con) != 1) {
            return new result(0);
        }
        JSONArray res = rewardUtils.getExpReward(exp);
        rewardUtils.getTaleReward(tale, res);
        startBef.rewardService.saveRewards(res, name, con);
        return new result(200, res);
    }

    /**
     * 玉魄石兑换
     */
    public result exchangeYuPo(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int type = j.getInteger("type");
        List<String> xhKeys = new ArrayList<>();
        List<Integer> nums = new ArrayList<>();
        int exp = 0;
        long xhTale = 0;
        String dhKey = null;
        if (type == 0) {
            xhKeys.add("10000191");
            nums.add(5);
            exp = 43424;
        } else if (type == 1) {
            xhKeys.add("10000191");
            nums.add(10);
            exp = 43424 * 2;
        } else if (type == 2) {
            xhKeys.add("10000191");
            nums.add(30);
            exp = 43424 * 6;
        } else if (type == 3) {
            xhKeys.add("10000191");
            xhKeys.add("10000002");
            nums.add(1);
            nums.add(1);
            xhTale = 8000;
            dhKey = "10000192";
        } else if (type == 4) {
            xhKeys.add("10000191");
            xhKeys.add("10000192");
            nums.add(99);
            nums.add(12);
            dhKey = "10000193";
        } else return new result(0);
        if (xhTale > 0) {
            startBef.manService.saveMoney(1, -xhTale, name, con);
        }
        if (xhKeys.size() > 0) {
            for (int i = 0; i < xhKeys.size(); i++) {
                if (startBef.packageService.cutPlayerGoodsNumByKey(xhKeys.get(i), nums.get(i), name, con) != 1) {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
            }
        }
        JSONArray res = null;
        if (exp > 0) {
            res = rewardUtils.getExpReward(exp);
        }
        if (dhKey != null) {
            res = rewardUtils.getGoodsReward(dhKey, 1, 1);
        }
        if (res != null) {
            startBef.rewardService.saveRewards(res, name, con);
        }
        return new result(200, res);
    }

    /**
     * 兑换物品
     */
    public result exchangeGoods(JSONObject j,
                                @paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        String key = j.getString("key");
        final String name = user.name;
        Object params = j.get("params");
        switch (key) {
            case "1035": {//天晶石
                //查找数量是否充足
                if (params == null) return new result(0);//0exp 1银两
                //兑换成人物技能
                int r = startBef.packageService.cutPlayerGoodsNumByKey("1035", 100, name, con);
                if (r == 0) {
                    return new result(0);
                }
                JSONArray list = null;
                //按等级计算奖励
                int lever = user.msg.getInteger("lever");
                if ((int) params == 0) {
                    list = rewardUtils.getExpReward(1000 * lever);
                } else {
                    list = rewardUtils.getTaleReward(1000);
                }
                return new result(200, startBef.rewardService.saveRewards(list, name, con));
            }
        }
        return new result(0);
    }
}
