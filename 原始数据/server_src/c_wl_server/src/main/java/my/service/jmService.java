package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.db.mybatisConfig;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.Iterator;

/**
 * 经脉（真元点）
 */
public class jmService {
    /**
     * 重置经脉
     */
    public result reset(@paramsAnno(key = "user") user user,
                        @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int point = 0;
        //统计技能消耗的点数
        JSONArray list = startBef.manService.getSkill(name, con);
        Iterator<Object> ls = list.iterator();
        while (ls.hasNext()) {
            JSONObject skl = (JSONObject) ls.next();
            if (!skl.containsKey("key") ||
                    !skl.getString("key").substring(0, 8).equals("10021002")) {
                continue;
            }
            int lv = skl.getInteger("lv");
            point += countPointByLv(lv);
            ls.remove();
        }
        int old= startBef.manService.getJmPoint(name,con);
        if(point+old>1160){
            int d=point+old-1160;
            point-=d;//将超出部分减去
        }
        if (point > 0) {
            //消耗洗髓草
            if (startBef.packageService.cutPlayerGoodsNumByKey("10000129", 1, name, con) == 0) {
                return new result(0);
            }
            if (startBef.manService.saveSkill(list, name, con) == 0) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            if (startBef.manService.saveJmPoint(name, point, con) == 0) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        //返回技能消耗的点数
        return new result(200, point);
    }

    private int countPointByLv(int lv) {
        //每个等级需要消耗的点数
        int[] xhn = {20, 20, 40, 40, 40, 60, 60, 60, 80, 80, 80, 100, 100, 100, 100};
        int sum = 0;
        for (int i = 0; i < lv; i++) {
            sum += xhn[i];
        }
        return sum;
    }

    /**
     * 使用丹药
     */
    public int userDan(String danKey, String name, DefaultSqlSession con) {
        String[] arr = {"10000213", "10000214", "10000215", "10000216", "10000217",};
        boolean b = false;
        for (String s : arr) {
            if (danKey.equals(s)) {
                b = true;
                break;
            }
        }
        if (!b) return 0;
        int num = 0;
        int max = 0;
        if (danKey.equals("10000213")) {
            num = 20;
            max = 40;
        } else if (danKey.equals("10000214")) {
            num = 40;
            max = 200;
        } else if (danKey.equals("10000215")) {
            num = 60;
            max = 440;
        } else if (danKey.equals("10000216")) {
            num = 80;
            max = 760;
        } else if (danKey.equals("10000217")) {
            num = 100;
            max = 1160;
        }

        //根据技能统计经脉点数
        int xh = 0;
        JSONArray list = startBef.manService.getSkill(name, con);
        for (int i = 0; i < list.size(); i++) {
            JSONObject obj = (JSONObject) list.get(i);
            if (obj.containsKey("key") &&
                    obj.getString("key").substring(0, 8).equals("10021002")) {
                int lv = obj.getInteger("lv");
                xh += countPointByLv(lv);
            }
        }
        //剩余点数+使用的点数
        int point = startBef.manService.getJmPoint(name, con) + xh;
        if (point >= max) {
            return -1;//超过当前丹药可使用的真元点
        }
        //最多是1160
        if(point+num>1160){
            num=1160-point;
        }
        int r = startBef.manService.saveJmPoint(name, num, con);
        return r;
    }

    /**
     * 合成丹药
     */
    public result compose(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //0修行药匣 1初 2中 3高 4超 5圣
        int type = j.getInteger("type");
        //只能传入0-4
        if (type < 0 || type > 4) return new result(0);
        String[] arr = {"10000212", "10000213", "10000214", "10000215", "10000216", "10000217",};
        String key = arr[type];

        int num = 5;
        if (type == 0) num = 5;
        else num = 3;

        float p = 0.1f;
        if (type == 0) p = 1f;
        else if (type == 1)  p = 0.6f;
        else if (type == 2)  p = 0.7f;
        else if (type == 3)  p = 0.8f;
        else p = 0.9f;
        JSONArray viewList = startBef.packageService.getPackView(name, con).getJSONArray("package");
        int bsSum=startBef.packageService.getGdNumInPackByKey(key, viewList);
        boolean isBind=startBef.packageService.outIsBind(key,num,viewList);
        if(bsSum<num){
            return new result(0);
        }
        //判断数量是否充足
        if (startBef.packageService.cutPlayerGoodsNumByKey(key, num, name, con) == 0) {
            return new result(0);
        }
        JSONObject res = new JSONObject();
        if (!strUtils.isHappend(0, 1000, p)) {
            //失败扣除2颗
            JSONArray list = startBef.rewardService.createGoods(key, 1, isBind?1:0, name, con);
            res.put("list", list);
            res.put("r", 0);
        } else {
            //获取下一个等级的丹
            JSONArray list = startBef.rewardService.createGoods(arr[type + 1], 1,  isBind?1:0, name, con);
            res.put("list", list);
            res.put("r", 1);
        }

        return new result(200, res);
    }

    /**
     * 领取灵力丹（修行药匣）
     */
    public result gainLLD(@paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //已经领取过了
        if (startBef.logService.isGetLLD(name, con) == 1) {
            return new result(784);
        }
        //判断今日在线累计时长，超过30分钟才能领取
        if (startBef.logService.isEnoughAccumulate(1000 * 60 * 30,name, con) == 1
                && startBef.logService.getLLD(name, con) == 1) {
            //发放灵力丹
            return new result(200, startBef.rewardService.createGoods("10000212", 1, 1, name, con));
        }
        return new result(698);
    }
}
