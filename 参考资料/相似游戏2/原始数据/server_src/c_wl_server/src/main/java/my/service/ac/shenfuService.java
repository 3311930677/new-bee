package my.service.ac;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.data.shenFuData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.shenfu;
import my.model.user;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;

/**
 * 神符相关
 */
public class shenfuService {
    /**
     * 对超时的神符进行处理
     */
    private boolean isOverTimeHandle = false;

    public void overTimeHandle() {
        if (isOverTimeHandle) return;
        isOverTimeHandle = true;
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
            List<JSONObject> list = ac.getShenFuOverTime(strUtils.getTime() + "");
            List ns = new ArrayList<>();
            if (list.size() > 0) {
                for (JSONObject a : list) {
                    ns.add(a.getString("name"));
                }
                ac.remShenFuByNames(ns);
            }
            mybatisConfig.commit(con);
            for (Object n : ns) {
                user u = staticCollection.getUserByName(n.toString());
                if (u != null) u.msg.put("shenfu", null);
                //通知变身效果到期
                ChannelSupervise.noticeClientByName(null, n.toString(), "110");
            }
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
            isOverTimeHandle = false;
        }
    }

    public JSONObject getShenFu(String name, DefaultSqlSession con) {
        activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = ac.getShenFuView(name);
        if (list.size() > 0) {
            JSONObject a = list.get(0);
            a.remove("name");
            return a;
        }
        return null;
    }

    /**
     * 使用神符
     */
    public result useShenFu(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String sfKey = j.getString("key");
        shenfu sf = shenFuData.get(sfKey);
        if (sf == null) return new result(0);
        //减少数量
        if (startBef.packageService.cutPlayerGoodsNumByKey(sfKey, 1, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = ac.getShenFu(name);
        String end = (strUtils.getTime() + sf.effectTime * 60 * 1000) + "";
        if (list.size() == 0) {
            ac.addShenFu(name, sfKey, end);
        } else {
            ac.updateShenFu(name, sfKey, end);
        }
        JSONObject a = new JSONObject();
        a.put("sf_key", sfKey);
        a.put("end", end);
        user.msg.put("shenfu", a);
        return new result(200, a);
    }

    /**
     * 兑换神符
     */
    public result dhSfByPet(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String petKey = j.getString("key");
        //由petKey找出对应的神符key

        return new result(0);
    }

    /**
     * 由材料兑换
     */
    public result dhSfByCaiLiao(JSONObject j,
                                @paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //神符key
        String sfKey = j.getString("key");
        //由神符key找出对应所需的材料
        shenfu sf = shenFuData.get(sfKey);
        if (sf == null) return new result(0);
        //减去需要消耗的材料
        JSONArray clList = sf.cailiaoList;
        if (clList == null) return new result(225);
        for (int i = 0; i < clList.size(); i++) {
            JSONObject a = clList.getJSONObject(i);
            String k = a.getString("key");
            int num = a.getInteger("num");
            if (startBef.packageService.cutPlayerGoodsNumByKey(k, num, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        JSONArray rs = rewardUtils.getGoodsReward(sf.key, 1, 0);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }
}
