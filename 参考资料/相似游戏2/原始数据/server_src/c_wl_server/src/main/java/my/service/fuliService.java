package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.roleMapper;
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
 * 福利
 */
public class fuliService {

    /**
     * 签到领元宝
     */
    public result qdGainYuanBao(@paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //vip等级是否达到7
        int lv = startBef.vipService.getVipLv(name, con);
        if (lv < 7) return new result(214);
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getQdGainShen(name);
        if (list.size() == 0) {
            activityMapper.addQdGainShen(name);
            list = activityMapper.getQdGainShen(name);
        }

        JSONObject one = list.get(0);
        if (one.getInteger("gain_yuanbao") != 0) return new result(213);
        int yb = 0;
        if (lv == 7) yb = strUtils.getRandom(100, 501);
        else if (lv == 8) yb = strUtils.getRandom(500, 1001);
        else if (lv == 9) yb = strUtils.getRandom(1000, 2001);
        else if (lv > 9) yb = strUtils.getRandom(1500, 3001);

        boolean b = activityMapper.updateQdGainShen(name, null, null, null, null, "1", null, null);
        if (b) {
            //推送道具
            JSONArray rewards = rewardUtils.getGoldReward(yb);
            rewards = startBef.rewardService.saveRewards(rewards, name, con);
            startBef.logService.insertOp("9", name, "领取元宝" + yb, null, "1");
            return new result(200, rewards);
        }
        return new result(0);
    }

    /**
     * 印象分领神宠
     */
    public result yxfGainShen(@paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //vip等级是否达到7
        int lv = startBef.vipService.getVipLv(name, con);
        if (lv < 7) return new result(214);
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getQdGainShen(name);
        if (list.size() == 0) {
            activityMapper.addQdGainShen(name);
            list = activityMapper.getQdGainShen(name);
        }

        JSONObject one = list.get(0);
        if (one.getInteger("gain_shen") != 0) {
            JSONObject res = new JSONObject();
            res.put("zong", one.getInteger("shen_jf"));
            return new result(200, res);
        }
        if (one.getInteger("is_shen_gd") != 0) return new result(213);
        int ysf = 0;
        if (lv == 7) ysf = strUtils.getRandom(1, 8);
        else if (lv == 8) ysf = strUtils.getRandom(3, 16);
        else if (lv == 9) ysf = strUtils.getRandom(5, 25);
        else if (lv > 9) ysf = strUtils.getRandom(8, 35);

        int sum = one.getInteger("shen_jf") + ysf;
        int gain = 0;
        if (sum >= 1000) gain = 1;
        boolean b = activityMapper.updateQdGainShen(name, sum + "", "1", null, null, null, gain + "", null);
        if (b) {
            startBef.logService.insertOp("9", name, "领取神印象分" + ysf, null, "1");
            JSONObject res = new JSONObject();
            if (gain == 1) {
                //推送道具
                JSONArray rewards = rewardUtils.getGoodsReward("10000300", 1, 0);
                rewards = startBef.rewardService.saveRewards(rewards, name, con);
                res.put("list", rewards);
                return new result(200, res);
            } else {
                //返回积分
                res.put("ysf", ysf);
                return new result(200, res);
            }
        }
        return new result(0);
    }

    /**
     * 印象分领童帝
     */
    public result yxfGainTong(@paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //vip等级是否达到7
        int lv = startBef.vipService.getVipLv(name, con);
        if (lv < 7) return new result(214);
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getQdGainShen(name);
        if (list.size() == 0) {
            activityMapper.addQdGainShen(name);
            list = activityMapper.getQdGainShen(name);
        }

        JSONObject one = list.get(0);
        if (one.getInteger("gain_tong") != 0) {
            JSONObject res = new JSONObject();
            res.put("zong", one.getInteger("tong_jf"));
            return new result(200, res);
        }
        if (one.getInteger("is_tong_gd") != 0) return new result(213);

        int ysf = 0;
        if (lv == 7) ysf = strUtils.getRandom(1, 8);
        else if (lv == 8) ysf = strUtils.getRandom(3, 16);
        else if (lv == 9) ysf = strUtils.getRandom(5, 25);
        else if (lv > 9) ysf = strUtils.getRandom(8, 35);

        int sum = one.getInteger("tong_jf") + ysf;
        int gain = 0;
        if (sum >= 1000) gain = 1;
        boolean b = activityMapper.updateQdGainShen(name, null, null, sum + "", "1", null, null, gain + "");
        if (b) {
            startBef.logService.insertOp("9", name, "领取童印象分" + ysf, null, "1");
            JSONObject res = new JSONObject();
            if (gain == 1) {
                //推送道具
                JSONArray rewards = rewardUtils.getGoodsReward("10000299", 1, 0);
                rewards = startBef.rewardService.saveRewards(rewards, name, con);
                res.put("list", rewards);
                return new result(200, res);
            } else {
                //返回积分
                res.put("ysf", ysf);
                return new result(200, res);
            }
        }
        return new result(0);
    }
    /**
     * 金手指-测试时用
     */
    /*public result gainJinShouZhi(JSONObject jb,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int type = jb.getInteger("type");
        JSONArray list = null;
        if (type == 0) {
            list = rewardUtils.getGoldReward(10000000);
        } else if (type == 1) {
            list = rewardUtils.getExpReward(10000000);
        } else if (type == 2) {
            list = rewardUtils.getTaleReward(10000000);
        } else if (type == 3) {
            list = rewardUtils.getYinPiaoReward(10000000);
        } else {
            return new result(0);
        }
        startBef.rewardService.saveRewards(list, name, con);
        return new result(200, list);
    }*/

    /**
     * 领取等级礼包
     */
    public result gainLvGift(JSONObject jb,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lv = jb.getInteger("lv");
        boolean b = false;
        //是否符合等级
        for (int i = 30; i < 101; i += 5) {
            if (lv == i) b = true;
        }
        if (!b) return new result(0);
        //玩家等级是否达到
        int l = startBef.manService.getRoleLv(name, con);
        if (l < lv) {
            return new result(0);
        }
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getLvGift(name);
        if (list.size() == 0) {
            return new result(0);
        }
        //判断是否已经领取过
        JSONArray arr = list.get(0).getJSONArray("gain");
        b = false;
        for (int i = 0; i < arr.size(); i++) {
            //该等级已经被领取
            if (lv == arr.getInteger(i)) {
                b = true;
                break;
            }
        }
        if (b) {
            return new result(0);
        } else {
            arr.add(lv);
            activityMapper.updateLvGift(JSON.toJSONString(arr), name);
            List<JSONObject> gs = getLvData();
            JSONArray al = null;
            for (JSONObject g : gs) {
                if (g.getInteger("lv") == lv) {
                    al = g.getJSONArray("list");
                    break;
                }
            }

            //下发奖励
            JSONArray rewards = new JSONArray();
            for (Object a : al) {
                JSONObject o = (JSONObject) a;
                rewardUtils.getGoodsReward(o.getString("key"), o.getInteger("num"), 1, rewards);
            }
            JSONArray res = startBef.rewardService.saveRewards(rewards, name, con);
            return new result(200, res);
        }

    }

    /**
     * 等级礼包
     */
    public result getLvGift(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //todo:查询哪些是领取过了(数据库记录下标)
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getLvGift(name);
        if (list.size() == 0) {
            activityMapper.addLvGift(name);
            JSONObject o = new JSONObject();
            o.put("gain", new JSONArray());
            list.add(o);
        }

        List<JSONObject> gs = getLvData();
        JSONArray arr = list.get(0).getJSONArray("gain");
        for (JSONObject g : gs) {
            boolean b = false;
            for (int i = 0; i < arr.size(); i++) {
                //该等级已经被领取
                if (g.getInteger("lv") == arr.getInteger(i)) {
                    b = true;
                    break;
                }
            }
            if (b) {
                g.put("isGain", 1);
            } else {
                g.put("isGain", 0);
            }
        }
        return new result(200, gs);
    }

    private List<JSONObject> getLvData() {
        List<JSONObject> arr = new ArrayList<>();
        List<JSONObject> list = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            //addOne("1000", 10, list);
        }
        for (int i = 30; i < 101; i += 5) {
            JSONObject obj = new JSONObject();
            obj.put("lv", i);
            obj.put("list", list);
            arr.add(obj);
        }
        return arr;
    }

    /**
     * ===================每日签到==================
     */
    /**
     * 进行每日签到
     */
    public result gainDayQd(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getDayQiandao(name);
        if (list.size() == 0) {
            return new result(0);
        }
        JSONObject l = list.get(0);
        if (l.getInteger("gain") == 0) {
            activityMapper.updateDayQiandao("1", name);
            //下发奖励
            JSONArray rewards = new JSONArray();
            rewardUtils.getGoodsReward("1000", 10, 1, rewards);
            JSONArray res = startBef.rewardService.saveRewards(rewards, name, con);
            return new result(200, res);
        }

        return new result(200, 0);
    }

    /**
     * 获取签到列表
     */
    public result getQdList(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //todo:查询哪些是签到过了(数据库记录下标)
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getDayQiandao(name);
        if (list.size() == 0) {
            activityMapper.addDayQiandao(name);
            JSONObject o = new JSONObject();
            o.put("gain", 0);
            list.add(o);
        }

        List<JSONObject> data = getQdData();
        JSONObject res = new JSONObject();
        res.put("list", data);
        res.put("gain", list.get(0).getInteger("gain"));
        return new result(200, res);
    }


    private List<JSONObject> getQdData() {
        int num = strUtils.getNowMonDays();
        List<JSONObject> list = new ArrayList<>();
        for (int i = 0; i < num; i++) {
            addOne("1000", 10, list);
        }
        return list;
    }

    private void addOne(String key, int num, List<JSONObject> list) {
        JSONObject a = new JSONObject();
        a.put("key", key);
        a.put("num", num);
        list.add(a);
    }
}
