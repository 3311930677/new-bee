package my.service.ac;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.data.cangbaotuData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * 王者遗产
 */
public class wzycService {
    /**
     * 使用藏宝图触发任务
     */
    public JSONObject userCangBaoTu(String key, String name, DefaultSqlSession con) {
        //触发任务创建（3种 对话、找boss攻击、收集一定数量的怪物）
        int r = strUtils.getRandom(3288, 3291);
        //接取过
        if (startBef.taskService.isGetTaskList(name, con, r + "") == 1) {
            return null;
        }
        //先清理
        startBef.taskService.removeNoSubmitTask(name, con, "3288", "3289", "3290");
        startBef.taskService.removeSubmitTask(name, con, "3288", "3289", "3290");

        if (startBef.taskService.createTask(r + "", name, con) == 1) {
            //记录藏宝图的key，当任务完成时需要把这个藏宝图的key给清除
            activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
            dao.updateWzyc(name, null, null, null, null, null, key);
            JSONObject res = new JSONObject();
            res.put("key", r + "");
            return res;
        }
        return null;
    }

    /**
     * 获取王者遗产的奖励
     */
    public JSONArray getWzycReward(String name, DefaultSqlSession con) {
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getWzyc(name);
        JSONObject a = list.get(0);
        String key = a.getString("cbt_key");
        int n = Integer.parseInt(key.substring(4));
        int lv = n / 4 + 1;//从1开始
        int qua = n % 4;
        JSONArray res = new JSONArray();
        if (lv == 15) {
            List<String> arr = new ArrayList<>();
            arr.add("10000032");//超级宠物口粮
            arr.add("10000107");//锻皇
            arr.add("10000148");//圣锻碎片
            arr.add("10000149");//绑定宝石
            arr.add("10000151");//千年玄铁
            arr.add("10000170");//高级天命逆转散
            arr.add("10000174");//封赏玉帛
            arr.add("10000118");//仙灵悟性丹
            if (qua == 3) {
                arr.add(rewardUtils.getRandomBaoShi(4));
                arr.add("10000159");//金锻皇
                arr.add("10000150");//刻印宝石
            }
            Collections.shuffle(arr);
            res = rewardUtils.getGoodsReward(arr.get(0), 1, 1);
        } else if (lv > 10) {
            res = rewardUtils.getBoxReward();
        } else if (lv > 5) {
            List<String> arr = new ArrayList<>();
            arr.add("10000029");//低级宠物口粮
            arr.add("10000104");//初锻宝石
            arr.add("10000130");//明心悟性丹
            arr.add("10000168");//低级天命逆转散
            Collections.shuffle(arr);
            res = rewardUtils.getGoodsReward(arr.get(0), 1, 1);
        } else {

        }
        rewardUtils.getExpReward(10000 * lv, res);
        rewardUtils.getYinPiaoReward(10000 * lv, res);
        return res;
    }

    /**
     * 查询基本信息
     */
    public result viewMsg(@paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getWzyc(name);
        if (list.size() == 0) {
            dao.addWzyc(name);
            list = dao.getWzyc(name);
        }
        JSONObject a = list.get(0);
        return new result(200, a);
    }

    /**
     * 领取
     */
    public result gain(@paramsAnno(key = "user") user user,
                       @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getWzyc(name);
        JSONObject a = list.get(0);
        int gain_times = a.getInteger("gain_times");
        if (gain_times <= 0) {
            return new result(0);
        }
        gain_times--;
        dao.updateWzyc(name, gain_times + "", null, null, "0", "1", null);
        //生成道具
        String k = cangbaotuData.getKey(a.getInteger("type"), a.getInteger("lv"));
        JSONArray res = rewardUtils.getGoodsReward(k, 1, 1);
        startBef.rewardService.saveRewards(res, name, con);
        return new result(200, res);
    }

    /**
     * 清洗
     * 精致、名贵、珍稀、绝世，每日可领取3次，
     * 每次领取后需还原成1星，清洗后改变品质跟星级，最高15星，
     */
    public result qingxi(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int isFree = j.getInteger("isFree");
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = dao.getWzyc(name);
        JSONObject a = list.get(0);
        if (isFree == 1) {
            //验证免费次数
            if (a.getInteger("free_sx_times") <= 0) return new result(0);
        } else {
            //验证道具
            return new result(0);
        }
        //是否有免费的清洗次数
        int lv = a.getInteger("lv");
        if (a.getInteger("type") == 3) {
            //绝世品质直接加1星
            lv++;
        }
        int type = 0;
        if (strUtils.isHappend(0, 1000, 0.5f)) {
            type = 2;
        } else if (strUtils.isHappend(0, 1000, 0.2f)) {
            type = 3;
        } else {
            type = strUtils.getRandom(0, 2);
        }
        int sx_times = a.getInteger("sx_times") + 1;
        int free_sx_times = a.getInteger("free_sx_times") - 1;

        dao.updateWzyc(name, null, sx_times + "", free_sx_times + "", type + "", lv + "", null);

        return new result(200, 1);
    }
}
