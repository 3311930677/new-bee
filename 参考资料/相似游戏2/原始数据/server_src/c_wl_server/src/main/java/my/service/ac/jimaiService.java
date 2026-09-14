package my.service.ac;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.roleMapper;
import my.data.goodsData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.strUtils;
import my.utils.systemUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;

/**
 * 寄卖
 */
public class jimaiService {
    /**
     * 过期处理
     */
    private boolean doOverHandle = false;

    public void overTimeHandle() {
        if (doOverHandle) return;
        doOverHandle = true;
        Function<DefaultSqlSession, Object> fn = (con) -> {
            activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
            long now = strUtils.getTime();
            //将超时的商品退回
            //超过24小时的
            //long t = now;
            long t = now - 24 * 60 * 60 * 1000;
            List<JSONObject> list = ac.getJiMaiIdsByCreated(t, "0");
            //超过48小时的
            t = now - 24 * 60 * 60 * 1000 * 2;
            List<JSONObject> list1 = ac.getJiMaiIdsByCreated(t, "1");
            //合并
            list.addAll(list1);
            if (systemUtils.isWindows()) {
                System.err.println("开始清理寄卖超时/" + list1);
            }
            if (list.size() > 0) {
                for (JSONObject a : list) {
                    String Id = a.getString("Id");
                    //先锁行再删除
                    List<JSONObject> al = ac.getJiMai(Id);
                    if (al.size() == 0) continue;//说明此刻被玩家删除了
                    //将道具回退
                    JSONObject one = al.get(0);
                    if (one.getInteger("num") <= 0) continue;
                    JSONObject gd = one.getJSONObject("gd");
                    gd.put("num", one.getInteger("num"));
                    gd.put("enType", one.getInteger("gdType"));
                    String name = one.getString("name");
                    int bzj = one.getInteger("bzj");
                    Object[] ens = {gd};
                    if (!ac.remJiMaiById(Id)) {
                        mybatisConfig.rollback(con);
                        continue;
                    }
                    try {
                        startBef.emailService.sendSysEmail(name, "寄卖过期退回", ens, bzj, con);
                        mybatisConfig.commit(con);
                    } catch (Exception e) {
                        System.err.println("玩家邮件已满" + name);
                        e.printStackTrace();
                        mybatisConfig.rollback(con);
                    }
                    //todo:解决：复制多份邮件一同退回，这时客户端会请求多次post，导致系统忙

                }
            }
            return null;
        };
        mybatisConfig.putTask(fn);
        doOverHandle = false;
    }

    /**
     * 购买上架的商品
     */
    public result buyGrounding(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        Integer num = j.getInteger("num");
        if (strUtils.isNull(Id) || num == null || num <= 0) return new result(0);
        activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = ac.getJiMai(Id);
        if (list.size() == 0) return new result(205);
        JSONObject one = list.get(0);
        //不能购买自己的商品
        String busName = one.getString("name");
        if (busName.equals(name)) return new result(0);
        if (startBef.emailService.isOverMaxEmail(name, con)) {
            return new result(222);
        }
        //商品数量是否足够
        if (one.getInteger("num") - num < 0) {
            mybatisConfig.rollback(con);
            return new result(205);
        }
        long price = one.getLong("price");
        int priceType = one.getInteger("priceType");
        if ((priceType != 0 && priceType != 1) || price <= 0) return new result(0);
        JSONArray rewards = new JSONArray();

        one.put("num", one.getInteger("num") - num);
        if (one.getInteger("num") == 0) {
            //删除商品
            if (!ac.remJiMaiById(Id)) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            //当所有数量卖完时才退还保证金
            //扣除1%保证金银两作为代理费
            int bzj = one.getInteger("bzj");
            int glf = (int) (bzj * 0.01f);
            if (glf <= 0) glf = 1;
            int backBzj = bzj - glf;
            //当有剩余保证金时返还
            if (backBzj > 0) {
                rewardUtils.getTaleReward(backBzj, rewards);
            }
        } else {
            if (!ac.updateJiMai(Id, one.getInteger("num") + "")) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        long zong = price * num;
        if (zong <= 0) return new result(0);
        //判断钱是否充足
        if (startBef.manService.saveMoney(priceType, -zong, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }


        if (priceType == 0) {
            int gold = startBef.manService.getMsgData(busName, con).getInteger("gold");
            if (gold + zong > Integer.MAX_VALUE) {
                mybatisConfig.rollback(con);
                return new result(203);
            }
            rewardUtils.getGoldReward(zong, rewards);
        } else {
            int tale = startBef.manService.getMsgData(busName, con).getInteger("tale");
            if (tale + zong > Integer.MAX_VALUE) {
                mybatisConfig.rollback(con);
                return new result(203);
            }
            rewardUtils.getTaleReward(zong, rewards);
        }

        //通知打款
        startBef.rewardService.saveRewards(rewards, busName, con);
        //给购买放发送邮件
        JSONObject gd = one.getJSONObject("gd");
        gd.put("enType", one.getInteger("gdType"));
        gd.put("num", num);
        Object[] ens = {gd};
        startBef.emailService.sendSysEmail(name, "寄卖购买道具", ens, 0, con);

        //通知奖励
        ChannelSupervise.noticeClientByName(rewards, busName, "10000");
        startBef.logService.insertOp("5", busName, price + "*" + num + " [寄卖]道具被玩家购买 " + gd, name, "1");

        return new result(200, 1);
    }


    /**
     * 下架商品
     */
    public result undercarriage(JSONObject j,
                                @paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (strUtils.isNull(Id)) return new result(0);
        if (startBef.emailService.isOverMaxEmail(name, con)) {
            return new result(222);
        }
        activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = ac.getJiMai(Id);
        if (list.size() == 0) return new result(0);
        JSONObject one = list.get(0);
        //判断商品是否属于自己
        if (!one.getString("name").equals(name)) return new result(0);

        //下架则不退回保证金
        /*int tale = (int) (one.getInteger("price") * 0.01f*(one.getInteger("qx")+1));
        if (tale <= 0) tale = 1;*/
        //根据物品类别判断放入背包还是宠物列表
        int gdType = one.getInteger("gdType");
        JSONObject gd = one.getJSONObject("gd");
        if (gdType == 0) {
            //验证背包空间
            if (!startBef.packageService.isEnough(name, con)) {
                return new result(0);
            }
            if (one.getInteger("num") <= 0) return new result(0);
            //重新为其生成一个新id并保存\需要替换道具的num
            gd.put("num", one.getInteger("num"));
            gd.put("Id", strUtils.getId());
            gd.put("enType", 0);
        } else {
            //验证宠物列表空间
            if (startBef.petService.isOverLimitNum(name, con)) {
                return new result(0);
            }
            gd.put("Id", strUtils.getId());
            gd.put("enType", 1);
        }
        if (!ac.remJiMaiById(Id)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //通过邮件发送
        Object[] ens = {gd};
        startBef.emailService.sendSysEmail(name, "取回寄卖品", ens, 0, con);
        return new result(200, 1);
    }

    /**
     * 查找商品
     */
    public result findGrounding(JSONObject j,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        //类目
        Integer type = j.getInteger("type");
        Long pageNum = j.getLong("pageNum");
        String kword = j.getString("keywords");
        if (pageNum == null || pageNum < 1) return new result(0);
        if (kword != null) {
            kword = "%" + kword + "%";
        }
        long pageSum = 10;
        activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = ac.getJiMaiViewByPage(type + "", kword, (pageNum - 1) * pageSum, pageSum);
        long n = ac.countNumByPage(type + "", kword).get(0).getLong("n");
        long sum = n % pageSum == 0 ? n / pageSum : n / pageSum + 1;
        JSONObject res = new JSONObject();
        res.put("list", list);
        res.put("totalPage", sum);
        return new result(200, res);
    }

    /**
     * 查找自己上架的商品
     */
    public result findGroundingBySelf(@paramsAnno(key = "user") user user,
                                      @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = ac.getJiMaiViewByName(name);
        return new result(200, list);
    }

    /**
     * 玩家上架商品
     */
    public result grounding(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        //商品的类型 0道具1宠物
        int gdType = j.getInteger("gdType");
        int num = j.getInteger("num");
        int price = j.getInteger("price");
        int priceType = j.getInteger("priceType");
        String kword = j.getString("keywords");
        //期限 0一天 1两天
        int qx = j.getInteger("qx");
        if (strUtils.isNull(Id) || strUtils.isNull(kword) ||
                (gdType != 0 && gdType != 1) || num <= 0 || price <= 0 ||
                j.getInteger("price") > 999999999 ||
                (priceType != 0 && priceType != 1) || (qx != 0 && qx != 1)) return new result(0);
        activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
        //是否有足够的位置
        int n = ac.getNumByName(name).get(0).getInteger("n");
        if (n >= 10) return new result(902);
        if (startBef.emailService.isOverMaxEmail(name, con)) {
            return new result(222);
        }
        //消耗1%保证金，若卖不出则退,最少1银两
        long tale = (int) (num * price * 0.01f * (qx + 1));
        if (tale <= 0) tale = 1;
        if (startBef.manService.saveMoney(1, -tale, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONObject one = null;
        if (gdType == 0) {
            //验证是否允许邮寄
            one = startBef.packageService.getOne(Id, name, con);
            if (one == null || goodsData.isNoAllowedSend(one)) return new result(0);
            //验证物品数量
            if (startBef.packageService.cutPlayerGoodsNum(Id, num, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        } else {
            one = startBef.petService.getPetById(Id, name, con);
            //不能超过成6
            if (one == null || one.get("growLv") == null || one.getInteger("growLv") >= 6) return new result(0);
            if (startBef.petService.remPet(Id, name, con) == 0) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        int type = getTypeByGd(one.getString("key"), gdType);
        long created = strUtils.getTime();
        //物品尽管上架，当买的时候再去减少，一切以外部字段num为准，发送时要修改商品内的num字段
        boolean b = ac.addJiMai(strUtils.getId(), price + "", priceType + "",
                num + "", gdType + "", name, JSON.toJSONString(one),
                type + "", kword, created + "", qx + "", tale + "");
        if (b) {
            return new result(200, 1);
        }
        mybatisConfig.rollback(con);
        return new result(0);
    }

    /**
     * 只分三类 0全部 1宝石、2装备、3技能、4其他、5宠物
     */
    private int getTypeByGd(String key, int gdType) {
        if (gdType == 1) return 5;
        if (strUtils.isMatch(key, "1003([0-9]{4})")) {
            return 1;
        } else if (strUtils.isMatch(key, "1001([0-9]{8})")) {
            return 2;
        } else if (strUtils.isMatch(key, "1002([0-9]{8})")) {
            return 3;
        }
        return 4;
    }
}
