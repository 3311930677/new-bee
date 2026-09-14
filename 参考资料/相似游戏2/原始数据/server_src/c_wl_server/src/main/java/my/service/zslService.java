package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.db.mybatisConfig;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;

/**
 * 江湖追杀令
 */
public class zslService {
    /**
     * 定时清理过期追杀令
     */
    public void clear() {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            //每10条一组
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            long now = new Date().getTime();
            //fixme 注意：这里每次循环都删除数据库10条数据，这样分页读的时候就会导致跳过数据。
            //所以不要分页去操作
            List<JSONObject> list = activityMapper.getZslByDestroy(now + "");
            mybatisConfig.commit(con);
            JSONObject res = new JSONObject();
            for (JSONObject o : list) {
                if (now > o.getLong("destroy")) {
                    //过期移除，没有玩家接取时退回原悬赏，有玩家接取时退回悬赏+违约金
                    String getter = o.getString("getter");
                    String pubber = o.getString("name");
                    long price = o.getLong("price");
                    int priceType = o.getInteger("price_type");
                    //删除该悬赏
                    if (!activityMapper.remZsl(o.getString("Id"))) {
                        continue;
                    }
                    res.clear();
                    if (getter == null) {
                        //退钱
                        if (startBef.manService.saveMoney(priceType, price, pubber, con) != 1) {
                            continue;
                        }
                        //通知发布者
                        res.put("money", price);
                        res.put("moneyType", priceType);
                        res.put("type", 0);
                        ChannelSupervise.noticeClientByName(res, pubber, "844");
                    } else {
                        //退钱
                        long money = Float.valueOf(price * 1.1f + "").longValue();
                        if (startBef.manService.saveMoney(priceType, money, pubber, con) != 1) {
                            continue;
                        }
                        res.put("money", money);
                        res.put("moneyType", priceType);
                        res.put("type", 1);
                        //通知发布者、接取者
                        ChannelSupervise.noticeClientByName(res, pubber, "844");
                        ChannelSupervise.noticeClientByName("悬赏超时，赔付违约金" + price * 0.1 +
                                (priceType == 0 ? "元宝" : "银两"), getter, "794");
                    }
                    mybatisConfig.commit(con);
                }
            }
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 追杀结果
     */
    public int zslResult(int w, String name, String playerName) {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            if (w == 1) {
                //r方胜利
                List<JSONObject> list = activityMapper.getZsl(null, name, 0L, 1L);
                //身上没有悬赏任务则说明已经过期被系统删除了
                if (list.size() == 0) return 0;
                //追杀成功后获得悬赏+保证金，移除追杀令，通知玩家、发布者追杀完成
                JSONObject res = list.get(0);
                //过期/不是指定目标
                if (strUtils.getTime() > res.getLong("destroy")||
                       !res.getString("player").equals(playerName)) return 0;
                //被攻击方将物品转移到攻击方
                if (strUtils.isHappend(0, 100, 0.5f)) {
                    startBef.packageService.aGoodToB(playerName, name, con);
                }
                //发放悬赏
                int price = res.getInteger("price");
                int priceType = res.getInteger("price_type");
                long money = Float.valueOf(price * 1.1 + "").longValue();
                if (startBef.manService.saveMoney(priceType, money, name, con) != 1) {
                    mybatisConfig.rollback(con);
                    return 0;
                }
                //任务完成移除
                if (!activityMapper.remZsl(res.getString("Id"))) {
                    //回滚发放的悬赏
                    mybatisConfig.rollback(con);
                    return 0;
                }
                mybatisConfig.commit(con);
                //通知发布者
                String msg = "玩家[" + res.getString("getter") + "]完成了您针对玩家[" + res.getString("player") + "]发布的悬赏任务！";
                ChannelSupervise.noticeClientByName(msg, res.getString("name"), "794");
                //通知完成者
                JSONObject m = new JSONObject();
                m.put("money", money);
                m.put("moneyType", priceType);
                ChannelSupervise.noticeClientByName(m, res.getString("getter"), "843");
            } else {
                //r方失败
                if (!strUtils.isHappend(0, 100, 0.5f)) {
                    startBef.packageService.aGoodToB(name, playerName, con);
                }
                mybatisConfig.commit(con);
            }
            mybatisConfig.commit(con);
            return 1;
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        return 0;
    }

    private List<Integer> backShuffleList(int len) {
        List<Integer> list = new ArrayList<>();
        for (int i = 0; i < len; i++) {
            list.add(i);
        }
        //乱序
        Collections.shuffle(list);
        return list;
    }

    /**
     * 查询玩家接取的追杀令
     */
    public result findZslByName(@paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getZsl(null, name, 0L, 1L);
        if (list.size() == 0) {
            //没有任务
            return new result(1016);
        }
        JSONObject res = list.get(0);
        user u = staticCollection.getUserByName(res.getString("player"));
        if (u != null && u.getPos() != null) {
            res.put("map", u.getPos().getString("map"));
        }
        return new result(200, res);
    }

    /**
     * 判断是否为追杀的对象
     */
    public boolean isKillObj(String player, String name, DefaultSqlSession con) {
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        //查询name接取的追杀令
        List<JSONObject> list = activityMapper.getZsl(null, name, 0L, 1L);
        if (list.size() == 0) {
            return false;
        }
        JSONObject res = list.get(0);
        if (!res.getString("player").equals(player)) {
            return false;
        }
        //是否超时
        if (new Date().getTime() > res.getLong("destroy")) {
            return false;
        }
        return true;
    }


    /**
     * 接取追杀令
     * 要求每个玩家只能领取一个
     */
    public result gainZsl(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (strUtils.isNull(Id)) {
            return new result(0);
        }
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getZsl(null, name, 0L, 1L);
        if (list.size() != 0) {
            //身上已经有任务在身，不能接取多个
            return new result(200, -1);
        }
        list = activityMapper.getZsl(Id, null, 0L, 1L);
        if (list.size() == 0) {
            return new result(0);
        }
        JSONObject obj = list.get(0);
        int price = obj.getInteger("price");
        int priceType = obj.getInteger("price_type");
        if (price < 100 || (priceType != 0 && priceType != 1)) {
            return new result(0);
        }
        //已经被其他玩家接取
        if (obj.getString("getter") != null) {
            return new result(200, -2);
        }
        //自己接取自己、被追杀对象接取
        if (obj.getString("name").equals(name) ||
                obj.getString("player").equals(name)) {
            return new result(0);
        }
        //接取将扣除10%奖励金作为保证金
        if (startBef.manService.saveMoney(priceType, -Float.valueOf(price * 0.1 + "").longValue(), name, con) != 1) {
            return new result(0);
        }
        if (!activityMapper.updateZsl(name, obj.getString("Id"))) {
            //回退扣除的保证金
            mybatisConfig.rollback(con);
            return new result(0);
        }
        ChannelSupervise.noticeClientByName("玩家[" + name + "]接取了您针对玩家[" +
                obj.getString("player") + "]的江湖追杀令", obj.getString("name"), "794");
        return new result(200, 1);
    }

    /**
     * 查询追杀令
     */
    public result getZsl(JSONObject j,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        long pageNum = j.getLong("pageNum");
        if (pageNum < 1) {
            pageNum = 1;
        }
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        int num = activityMapper.getZslSumNoGetter().get(0).getInteger("num");
        int total = num % 10 == 0 ? (num / 10) : (num / 10 + 1);
        if (pageNum > total) {
            JSONObject res = new JSONObject();
            res.put("totalPage", total);
            res.put("list", new JSONArray());
            return new result(200, res);
        }
        long pageSum = 10;
        List<JSONObject> list = activityMapper.getZslByNoGetter((pageNum - 1) * pageSum, pageSum);
        for (JSONObject o : list) {
            o.remove("created");
        }
        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", list);
        return new result(200, res);

    }

    /**
     * 发布追杀令
     */
    public result pubZsl(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        long price = j.getLong("price");
        int priceType = j.getInteger("priceType");
        String player = j.getString("player");
        if (price < 100 || (priceType != 0 && priceType != 1) || strUtils.isNull(player)
                || player.equals(name)) {
            return new result(0);
        }
        //判断该玩家是否真实存在
        JSONObject role = startBef.manService.getRole(player, con);
        if (role == null) {
            return new result(0);
        }
        //扣除奖励金
        if (startBef.manService.saveMoney(priceType, -price, name, con) != 1) {
            return new result(0);
        }
        long created = new Date().getTime();
        //统一十小时内完成，超时退款，接取者赔偿10%违约金
        long destroy = created + 10 * 60 * 60 * 1000;
        //插入
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        if (!activityMapper.addZsl(strUtils.getId(), price + "", priceType + "", player, name,
                null, created + "", destroy + "")) {
            return new result(0);
        }
        startBef.chatService.putSysMsg("玩家[" + name + "]对玩家[" + player + "]发布了悬赏，赏金" +
                price + (priceType == 0 ? "元宝" : "银两"));
        return new result(200, 1);
    }
}
