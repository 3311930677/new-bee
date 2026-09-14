package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.jsonMapper;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.List;

public class zhuanpanService {
    /**
     * 垂钓
     */
    public result viewCDTimes(@paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> js = dao.getChuiDiao(name);
        if (js.size() == 0) {
            dao.addChuiDiao(name);
            js = dao.getChuiDiao(name);
        }
        return new result(200, js.get(0));
    }

    public result putCDProgress(JSONObject j,
                                @paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lv = user.msg.getInteger("lever");
        Integer index = j.getInteger("index");
        Integer type = j.getInteger("type");//免费、付费
        if (index == null || type == null || (type != 0 && type != 1)) return new result(0);
        //判断次数是否充足
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> js = dao.getChuiDiao(name);
        if (js.size() == 0) return new result(0);
        int times = 0;
        if (type == 0) {
            times = js.get(0).getInteger("free_times");
        } else {
            times = js.get(0).getInteger("fufei_times");
            //是否存在道具
            if (startBef.packageService.cutPlayerGoodsNumByKey("10000179", 1, name, con) != 1) {
                return new result(0);
            }
        }
        if (times <= 0) return new result(610);
        //次数--
        if (type == 0) {
            dao.updateChuiDiao(name, times - 1 + "", null);
        } else {
            dao.updateChuiDiao(name, null, times - 1 + "");
        }
        float k = 1;
        if (index == 0) k = 1f;
        else if (index == 1) k = 0.8f;
        else if (index == 2) k = 0.7f;
        else if (index == 3) k = 0.6f;
        else if (index == 4) k = 0.5f;
        else if (index == 5) k = 0.4f;
        else k = 0.3f;
        int exp = (int) ((12000 + lv * 200) * k);
        JSONArray res = rewardUtils.getExpReward(exp);
        startBef.rewardService.saveRewards(res, name, con);
        return new result(200, res);
    }

    /**
     * 启动转盘
     */
    public result putZPProgress(@paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lv = startBef.manService.getRole(name, con).getInteger("lever");
        if (lv < 20) {
            return new result(0);
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> js = jsonMapper.selectZhuanpanNum(name);
        boolean b = false;
        //不存在则插入
        if (js.size() == 0) {
            b = jsonMapper.insertZhuanpan(name, "1");
        } else {
            int num = js.get(0).getInteger("num");
            if (num >= 2) {
                return new result(0);
            }
            b = jsonMapper.updateZhuanpan(name, num + 1 + "");
        }
        if (b) {
            int index = strUtils.getRandom(0, 8);
            //获取奖励
            JSONArray list = startBef.rewardService.getActivityReward(lv, name, "2017", index, con);
            ChannelSupervise.noticeClientByName(list, name, "10000");
            return new result(200, index + 1);
        }
        return new result(0);
    }

    /**
     * 获取转盘进度
     */
    public result getZPProgress(@paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lv = startBef.manService.getRole(name, con).getInteger("lever");
        if (lv < 20) {
            return new result(0);
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectZhuanpanNum(name);
        if (list.size() == 0) {
            jsonMapper.insertZhuanpan(name, "0");
            JSONObject a = new JSONObject();
            a.put("num", 0);
            list.add(a);
        }
        if (list.size() == 0) return new result(200, 0);
        return new result(200, list.get(0));
    }
}
