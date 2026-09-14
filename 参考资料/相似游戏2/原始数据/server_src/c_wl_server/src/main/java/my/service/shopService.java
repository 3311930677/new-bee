package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.data.equipData;
import my.data.goodsData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.gameUtils.skillUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;
import org.jpedal.parser.shape.J;

import java.util.*;
import java.util.concurrent.TimeUnit;

import static my.utils.staticCollection.*;

/**
 * 商城服务
 */
public class shopService {
    /**
     * 接受出价
     */
    public result agreeOffer(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String buyName = j.getString("name");
        if (buyName == null) {
            return new result(0);
        }
        JSONArray list = jingPaiGoodsMap.get(name);
        if (list == null || list.size() == 0) {
            return new result(0);
        }
        JSONObject shop = (JSONObject) list.get(0);
        JSONObject offers = shop.getJSONObject("offers");
        for (Object n : offers.keySet()) {
            //找到出价者
            if (buyName.equals(n)) {
                String Id = shop.getString("Id");
                int priceType = shop.getInteger("priceType");
                long price = offers.getLong(n.toString());
                int num = shop.getInteger("num");
                int jptype = shop.getInteger("jptype");
                if ((priceType != 0 && priceType != 1) || price <= 0 || num <= 0) {
                    return new result(0);
                }
                //宠物、道具判断位置是否够
                if (jptype == 0) {
                    if (!startBef.packageService.isEnough(buyName, con)) {
                        return new result(200, 0);
                    }
                } else {
                    if (startBef.petService.isOverLimitNum(buyName, con)) {
                        return new result(200, 0);
                    }
                }
                //判断货币是否充足 price开的是总价
                int enough = startBef.manService.saveMoney(priceType, -price, buyName, con);
                if (enough == 0) {
                    //买家钱不够
                    return new result(200, -1);
                }
                //判断卖家道具是否存在
                if (jptype == 0) {
                    JSONObject one = startBef.packageService.getOne(Id, name, con);
                    //道具
                    if (one == null || startBef.packageService.cutPlayerGoodsNum(
                            Id, num, name, con) != 1) {
                        //卖家没有该商品，移除缓存
                        jingPaiGoodsMap.remove(name);
                        //回滚扣除玩家的钱
                        mybatisConfig.rollback(con);
                        return new result(200, -2);
                    }
                    jingPaiGoodsMap.remove(name);
                    //将物品发送给购买者
                    one.put("num", num);
                    int r = startBef.packageService.goodsToPackage(one, buyName, con);
                    if (r != 1) {
                        mybatisConfig.rollback(con);
                        return new result(0);
                    }
                    //将获得的钱打给商家
                    r = startBef.manService.saveMoney(priceType, price, name, con);
                    if (r != 1) {
                        mybatisConfig.rollback(con);
                        return new result(0);
                    }
                    startBef.logService.insertOp("3", buyName, "购买竞拍商品" + shop.getString("key") +
                            " x" + shop.getInteger("num") + " / 价格：" + price +
                            " / 价格类型：" + (priceType == 0 ? "元宝" : "银两") +
                            " / " + (jptype == 0 ? "道具" : "宠物"), name, "1");
                    try {
                        JSONObject msg = new JSONObject();
                        msg.put("moneyType", priceType);
                        msg.put("money", price);
                        msg.put("list", rewardUtils.getGoodsReward(one));
                        //通知商品到账
                        ChannelSupervise.noticeClientByName(msg, buyName, "841");
                        //通知商家货币到账以及刷新道具数量
                        msg.clear();
                        msg.put("Id", Id);
                        msg.put("num", num);
                        msg.put("moneyType", priceType);
                        msg.put("money", price);
                        msg.put("type", jptype);
                        ChannelSupervise.noticeClientByName(msg, name, "826");
                    } catch (Exception e) {
                        loggerUtils.error("通知失败：" + e.getMessage(), this.getClass());
                    }
                    return new result(200, 1);
                } else if (jptype == 1) {
                    //宠物
                    //判断是否存在该宠物
                    JSONArray pets = startBef.petService.getList(name, con);
                    for (Object o : pets) {
                        JSONObject pet = (JSONObject) o;
                        if (pet.getString("Id").equals(Id)) {
                            String key = pet.getString("key");
                            if (pet.get("growLv") == null || pet.getInteger("growLv") >= 6) {
                                //卖家商品有问题，移除缓存
                                jingPaiGoodsMap.remove(name);
                                //退回资金
                                mybatisConfig.rollback(con);
                                return new result(200, 0);
                            }
                            jingPaiGoodsMap.remove(name);
                            JSONObject petCopy = JSON.parseObject(JSON.toJSONString(pet));
                            pets.remove(o);
                            //移除卖家宠物
                            int r = startBef.petService.savePetList(pets, name, con);
                            if (r != 1) {
                                mybatisConfig.rollback(con);
                                return new result(0);
                            }
                            //将宠物发送到买家
                            r = startBef.petService.addOnePet(petCopy, buyName, con);
                            if (r != 1) {
                                mybatisConfig.rollback(con);
                                return new result(0);
                            }
                            //将获得的钱打给商家
                            r = startBef.manService.saveMoney(priceType, price, name, con);
                            if (r != 1) {
                                mybatisConfig.rollback(con);
                                return new result(0);
                            }
                            startBef.logService.insertOp("3", buyName, "购买竞拍商品" + shop.getString("key") +
                                    " x" + shop.getInteger("num") + " / 价格：" + price +
                                    " / 价格类型：" + (priceType == 0 ? "元宝" : "银两") +
                                    " / " + (jptype == 0 ? "道具" : "宠物"), name, "1");
                            //通知
                            try {
                                JSONObject msg = new JSONObject();
                                msg.put("moneyType", priceType);
                                msg.put("money", price);
                                msg.put("list", rewardUtils.getPetReward(petCopy));
                                //通知商品到账
                                ChannelSupervise.noticeClientByName(msg, buyName, "841");
                                //通知商家货币到账以及刷新道具数量
                                msg.clear();
                                msg.put("Id", Id);
                                msg.put("num", num);
                                msg.put("moneyType", priceType);
                                msg.put("money", price);
                                msg.put("type", jptype);
                                ChannelSupervise.noticeClientByName(msg, name, "826");
                            } catch (Exception e) {
                                loggerUtils.error("通知失败：" + e.getMessage(), this.getClass());
                            }
                            return new result(200, 1);
                        }
                    }
                    //能执行到这里说明找不到这个宠物，之前扣除的前需要退还
                    mybatisConfig.rollback(con);
                    jingPaiGoodsMap.remove(name);
                    return new result(200, 0);
                }

            }
        }
        return new result(0);
    }

    /**
     * 出价
     */
    public result offerJingpai(JSONObject j,
                               @paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (j.get("Id") == null || j.getInteger("offer") <= 0) {
            return new result(0);
        }
        for (String n : jingPaiGoodsMap.keySet()) {
            JSONArray list = jingPaiGoodsMap.get(n);
            for (Object o : list) {
                JSONObject obj = (JSONObject) o;
                if (obj.getString("Id").equals(j.getString("Id"))) {
                    //玩家自己不允许对自己竞拍的商品出价
                    if (n.equals(name)) {
                        return new result(200, 0);
                    }
                    obj.getJSONObject("offers").put(name, j.get("offer"));
                    //todo 通知卖家收到出价
                    JSONObject msg = new JSONObject();
                    msg.put("code", "804");
                    msg.put("channel", 0);
                    ChannelSupervise.noticeClientByName(msg, n, "700");
                    return new result(200, 1);
                }
            }
        }
        return new result(200, 0);
    }

    /**
     * 获取玩家竞拍的商品id
     */
    public result findJingPaiByName(@paramsAnno(key = "user") user user) {
        JSONArray list = jingPaiGoodsMap.get(user.name);
        if (list == null) {
            return new result(200);
        }
        JSONArray ids = new JSONArray();
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            ids.add(obj.getString("Id"));
        }
        return new result(200, ids);
    }

    /**
     * 获取竞拍商品
     */
    public result findJPByName(@paramsAnno(key = "user") user user) {
        return new result(200, jingPaiGoodsMap.get(user.name));
    }

    /**
     * 按页查找竞拍商品
     */
    public result findJingPai(JSONObject j) {
        int pageNum = j.getInteger("pageNum");
        int i = 0;
        JSONArray aList = new JSONArray();
        for (String name : jingPaiGoodsMap.keySet()) {
            JSONArray list = jingPaiGoodsMap.get(name);
            for (Object o : list) {
                JSONObject obj = (JSONObject) o;
                if ((pageNum - 1) * 10 <= i && i < pageNum * 10) {
                    JSONObject copy = JSON.parseObject(JSON.toJSONString(obj));
                    copy.put("name", name);
                    aList.add(copy);
                    if (aList.size() >= 10) break;
                }
                i++;
            }
        }
        //判断是否存在下一页
        int pageSum = aList.size() < 10 ? pageNum : pageNum + 1;
        JSONObject res = new JSONObject();
        res.put("list", aList);
        res.put("totalPage", pageSum);
        return new result(200, res);
    }

    /**
     * 下架竞拍
     */
    public result undercarriageJingpai(JSONObject j,
                                       @paramsAnno(key = "user") user user) {
        final String name = user.name;
        String Id = j.getString("Id");
        JSONArray list = jingPaiGoodsMap.get(name);
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            if (obj.getString("Id").equals(Id)) {
                list.remove(o);
                if (list.size() == 0) {
                    jingPaiGoodsMap.remove(name);
                }
                return new result(200, 1);
            }
        }
        return new result(200, 0);
    }

    /**
     * 发布竞拍
     */
    public result pubJingPai(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        //0道具1宠物
        int jptype = j.getInteger("jptype");
        int price = j.getInteger("price");
        int priceType = j.getInteger("priceType");
        int num = j.getInteger("num");
        if ((jptype != 0 && jptype != 1) || price <= 0 || num <= 0 ||
                Id == null || (priceType != 0 && priceType != 1) || name == null) {
            return new result(0);
        }
        if (jingPaiGoodsMap.get(name) == null) {
            jingPaiGoodsMap.put(name, new JSONArray());
        }
        //超过1个架位
        if (jingPaiGoodsMap.get(name).size() >= 1) {
            return new result(902);
        }
        JSONArray list = jingPaiGoodsMap.get(name);
        for (Object l : list) {
            JSONObject o = (JSONObject) l;
            //该物品已经上过了
            if (o.getString("Id").equals(Id)) {
                return new result(200, 0);
            }
        }
        String gKey = null;
        if (jptype == 0) {
            JSONObject g = startBef.packageService.getOne(Id, name, con);
            //不允许邮寄
            if (goodsData.isNoAllowedSend(g)) {
                return new result(200, 0);
            }
            //并没有该物品时
            if (g == null || g.getInteger("num") < num || g.getInteger("num") <= 0) {
                return new result(200, 0);
            }
            gKey = g.getString("key");
        } else {
            //宠物不能超过x6,神宠不允许邮寄
            JSONArray pets = startBef.petService.getList(name, con);
            for (Object o : pets) {
                JSONObject pet = (JSONObject) o;
                if (pet.getString("Id").equals(Id)) {
                    String key = pet.getString("key");
                    if (pet.get("growLv") == null || pet.getInteger("growLv") >= 6) {
                        return new result(200, 0);
                    }
                    gKey = pet.getString("key");
                    break;
                }
            }
        }
        if (strUtils.isNull(gKey)) {
            return new result(0);
        }
        JSONObject obj = new JSONObject();
        obj.put("key", gKey);
        obj.put("Id", Id);
        obj.put("num", num);
        obj.put("price", price);
        obj.put("priceType", priceType);
        //0道具1宠物
        obj.put("jptype", jptype);
        //收到的出价 name=>price
        obj.put("offers", new JSONObject());
        jingPaiGoodsMap.get(name).add(obj);
        //插入操作日志
        startBef.logService.insertOp("3", name, "上架竞拍商品" + obj.getString("key") +
                " x" + obj.getInteger("num") + " / 价格：" + price +
                " / 价格类型：" + (priceType == 0 ? "元宝" : "银两") +
                " / " + (jptype == 0 ? "道具" : "宠物"), null, "1");
        JSONObject msg = new JSONObject();
        msg.put("code", "803");
        msg.put("params", name);
        msg.put("channel", 0);
        ChannelSupervise.noticeAllClient(msg, "700");
        return new result(200, 1);
    }


    /**
     * 抢购商品
     */
    public result reqRushToBuy(JSONObject j,
                               @paramsAnno(key = "user") user user) {
        if (!startBef.activityService.isOpen("qianggou")) {
            return new result(696);
        }
        j.put("name", user.name);
        String key = j.getString("key");
        //判断队列中是否已经存在 -防止炸内存
        for (JSONObject c : players) {
            if (c.getString("name").equals(j.getString("name")) &&
                    c.getString("key").equals(key)) {
                return new result(200, 1);
            }
        }
        //先判断商品是否被抢了，没有则加入抢购队列
        if (goodsMap.get(key) == null || goodsMap.get(key).getInteger("isBuy") == 1) {
            return new result(200, 0);
        }
        players.add(j);
        return new result(200, 1);
    }

    /**
     * 开启抢购活动
     */
    public void initQiangGou() {
        //每5分钟一轮，当选一轮开启时需要清空（因为可能上一轮的每抢完）
        clear();
        List<JSONObject> list = new ArrayList<>();
        list.add(getGoods("10000029", 1, 2000, 1));
        list.add(getGoods("10000030", 1, 5000, 1));
        list.add(getGoods("10000031", 1, 10000, 1));
        list.add(getGoods("10000032", 1, 20000, 1));
        list.add(getGoods("10000104", 1, 1000, 1));
        list.add(getGoods("10000105", 1, 3000, 1));
        list.add(getGoods("10000106", 1, 5000, 1));
        list.add(getGoods("10000109", 1, 10000, 1));
        list.add(getGoods("10000111", 1, 100, 0));
        list.add(getGoods("10000114", 1, 100, 0));
        Collections.shuffle(list);
        //时间段，判断当前时间段是否在晚上8-11.50点，是的话就开启
        for (int i = 0; i < 10; i++) {
            goodsMap.put("a" + (i + 1), list.get(i));
        }
    }

    /**
     * 抢购活动-推送给客户端
     */
    public void rushToBuy() {
        //System.err.println("该轮抢购活动开启！");
        //开启将抢购的物品推送给玩家
        Runnable runnable0 = () -> {
            try {
                //将抢购的商品推送给客户端
                for (String key : staticCollection.pushUser.keySet()) {
                    //对于已经离线的就要移除
                    if (!staticCollection.userIsOnline(key)) {
                        staticCollection.pushUser.remove(key);
                    }
                }
                //选举出需要推送的用户
                for (String key : staticCollection.userMap.keySet()) {
                    //对于在线且没有推送的就要推送
                    user u = staticCollection.userMap.get(key);
                    if (u != null && staticCollection.pushUser.get(u.name) == null) {
                        staticCollection.pushUser.put(u.name, 1);
                        ChannelSupervise.noticeClientByName(goodsMap, u.name, "797");
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        };
        //开启一个对抢购物品的监听(当抢购活动结束这个线程也会停止)
        Runnable runnable1 = () -> {
            try {
                //是否全部售罄
                boolean isOver = true;
                for (String key : goodsMap.keySet()) {
                    JSONObject obj = goodsMap.get(key);
                    if (obj.getInteger("isBuy") == 0) {
                        isOver = false;//未全部售罄
                    }
                }
                if (isOver) {
                    while (!players.isEmpty()) {
                        try {
                            //通知后续队列已售罄
                            ChannelSupervise.noticeClientByName(668,
                                    players.poll().getString("name"), "799");
                        } catch (Exception e) {
                            loggerUtils.error(e.getMessage(), this.getClass());
                        }
                    }
                    JSONObject end = JSON.parseObject(JSON.toJSONString(goodsMap));
                    clear();
                    //全部售罄后表示该时间段的抢购已结束，不在推送给前端
                    //最后一次同步推送物品状态
                    ChannelSupervise.noticeAllClient(end, "797");
                    return;
                }
                //fixme:可能会出现开脚本刷导致同一个商品多次出现相同玩家购买
                //为售罄时遍历抢购玩家
                while (!players.isEmpty()) {
                    DefaultSqlSession con = null;
                    try {
                        //包含商品 key 玩家 name
                        JSONObject obj = players.poll();
                        if (obj == null || obj.getString("key") == null) continue;
                        JSONObject goods = goodsMap.get(obj.getString("key"));
                        if (goods == null || goods.getInteger("isBuy") == 1) {
                            //通知已被购买
                            ChannelSupervise.noticeClientByName(obj.getString("key"), obj.getString("name"), "795");
                            continue;
                        }
                        goods.put("isBuy", 1);
                        con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                        //请求付款
                        int res = startBef.manService.saveMoney(goods.getInteger("priceType"), -goods.getLong("price"), obj.getString("name"), con);
                        if (res != 1) {
                            goods.put("isBuy", 0);
                        } else {
                            try {
                                //支付成功
                                //调用奖励的接口
                                JSONArray list = startBef.rewardService.createGoods(goods.getString("key"), goods.getInteger("num"), 0, obj.getString("name"), con);
                                //通知抢购成功
                                JSONObject result = new JSONObject();
                                result.put("key", obj.getString("key"));
                                result.put("priceType", goods.getInteger("priceType"));
                                result.put("price", goods.getInteger("price"));
                                result.put("list", list);
                                ChannelSupervise.noticeClientByName(result, obj.getString("name"), "796");
                            } catch (Exception e) {
                                loggerUtils.error("抢购付款失败" + e.getMessage(), this.getClass());
                                mybatisConfig.rollback(con);
                            }
                        }
                        mybatisConfig.commit(con);
                    } catch (Exception e) {
                        loggerUtils.error(e.getMessage(), this.getClass());
                        mybatisConfig.rollback(con);
                    } finally {
                        mybatisConfig.close(con);
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        };
        staticCollection.startQGTimes = strUtils.getTime();
        Runnable runnable = () -> {
            //晚上8点-9点
            if (!startBef.activityService.isOpen("qianggou")) {
                return;
            }
            if (goodsMap.size() == 0) {
                return;
            }
            //每5分钟一轮新的
            if (strUtils.getTime() - staticCollection.startQGTimes > 30 * 60 * 1000) {
                staticCollection.startQGTimes = strUtils.getTime();
                initQiangGou();
                startBef.chatService.putSysMsg("新一轮商城秒杀开始！");
                return;
            }
            runnable0.run();
            runnable1.run();

        };
        //每10s公布抢购结果
        //每10s推送一次
        staticCollection.putTask(runnable, 10, 10, TimeUnit.SECONDS);
    }

    private JSONObject getGoods(String key, Integer num, Integer price, Integer priceType) {
        JSONObject obj = new JSONObject();
        obj.put("key", key);
        obj.put("num", num);
        obj.put("price", price);
        obj.put("priceType", priceType);
        obj.put("isBuy", 0);
        return obj;
    }

    private void clear() {
        goodsMap.clear();
        //清空玩家抢购队列
        if (!players.isEmpty()) {
            players.clear();
        }
        //清除推送用户
        if (!staticCollection.pushUser.isEmpty()) {
            staticCollection.pushUser.clear();
        }
    }

    /**
     * 购买优惠商品
     */
    public result buyYouhui(JSONObject obj,
                            @paramsAnno(key = "user") user user) {
        if (!startBef.activityService.isOpen("youhui")) {
            return new result(696);
        }
        obj.put("name", user.name);
        //判断是否已经加入队列了
        for (JSONObject c : staticCollection.cutPriceQue) {
            if (c.getString("name").equals(obj.getString("name")) &&
                    c.getString("Id").equals(obj.getString("Id"))) {
                return new result(200, 1);
            }
        }
        //判断价格是否变动
        JSONObject goods = staticCollection.cutPriceGoodsMap.get(obj.getString("Id"));
        if (goods == null) {
            return new result(200, 0);
        }
        int n = goods.getInteger("kan");
        float d = goods.getFloat("d");
        int a = goods.getInteger("a");
        //int nowPrice = (int) (n * 100 + n * (n - 1) * d / 2);
        int nowPrice = (int) (a + (n - 1) * d);
        if (nowPrice != obj.getInteger("price") || goods.getInteger("sale") == 1) {
            //价格发生变动
            return new result(200, 0);
        }
        //加入砍价队列
        staticCollection.cutPriceQue.add(obj);
        return new result(200, 1);
    }

    /**
     * 获取优惠商品列表
     */
    public result getYouhui() {
        if (!startBef.activityService.isOpen("youhui")) {
            return new result(696);
        }
        Map<String, Object> map = new HashMap<>();
        for (String k : staticCollection.cutPriceGoodsMap.keySet()) {
            JSONObject obj = staticCollection.cutPriceGoodsMap.get(k);
            int n = obj.getInteger("kan");
            float d = obj.getFloat("d");
            //int nowPrice = (int) (n * 100 + n * (n - 1) * d / 2);
            int a = obj.getInteger("a");
            int nowPrice = (int) (a + (n - 1) * d);
            JSONObject res = new JSONObject();
            res.put("price", nowPrice);
            res.put("goods", obj.get("goods"));
            res.put("Id", obj.get("Id"));
            res.put("kan", n);
            res.put("times", obj.get("times"));
            res.put("sale", obj.get("sale"));
            res.put("priceType", obj.get("priceType"));
            map.put(obj.getString("Id"), res);
        }
        return new result(200, map);
    }

    /**
     * 上架优惠商品
     */
    public void publishCutPrice() {
        //30分钟一轮
        //发布前清理
        staticCollection.cutPriceGoodsMap.clear();
        //技能宝匣
        publishCutPrice("系统", "1044", 1, 20000, 0);
        //仙绝宝匣
        publishCutPrice("系统", "1045", 1, 20000, 0);

        startBef.chatService.putSysMsg("优惠商品已刷新！每10分钟1轮！");

    }

    /**
     * 开启砍价的定时器
     */
    public void startCutPriceTimer() {
        Runnable runnable1 = () -> {
            try {
                if (staticCollection.cutPriceGoodsMap.size() == 0) {
                    return;
                }
                boolean isOver = true;
                for (String id : staticCollection.cutPriceGoodsMap.keySet()) {
                    if (staticCollection.cutPriceGoodsMap.get(id).getInteger("sale") == 0) {
                        //存在未售罄的商品
                        isOver = false;
                    }
                }
                if (isOver) {
                    //已全部售罄
                    while (!staticCollection.cutPriceQue.isEmpty()) {
                        try {
                            JSONObject obj = staticCollection.cutPriceQue.poll();
                            ChannelSupervise.noticeClientByName(710, obj.getString("name"), "827");
                        } catch (Exception e) {
                            loggerUtils.error(e.getMessage(), this.getClass());
                        }
                    }
                    return;
                }
                //为售罄时遍历抢购玩家
                while (!staticCollection.cutPriceQue.isEmpty()) {
                    try {
                        //包含商品 id 玩家 name 当前 price
                        JSONObject obj = staticCollection.cutPriceQue.poll();
                        JSONObject goods = staticCollection.cutPriceGoodsMap.get(obj.getString("Id"));
                        if (goods.getInteger("sale") == 1) {
                            //已出售
                            ChannelSupervise.noticeClientByName(710, obj.getString("name"), "827");
                            continue;
                        }
                        int n = goods.getInteger("kan");
                        float d = goods.getFloat("d");
                        int a = goods.getInteger("a");
                        long nowPrice = (long) (a + (n - 1) * d);
                        if (nowPrice <= 0) {
                            continue;
                        }
                        //价格未变动
                        if (nowPrice == obj.getLong("price")) {
                            //一定是付款完成才设置
                            //请求付款
                            DefaultSqlSession con = null;
                            try {
                                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                                int i = startBef.manService.saveMoney(goods.getInteger("priceType"), -nowPrice, obj.getString("name"), con);
                                if (i == 0) {
                                    //付款失败
                                    ChannelSupervise.noticeClientByName(634, obj.getString("name"), "827");
                                    continue;
                                }
                                goods.put("kan", n + 1);
                                if (goods.getInteger("times") < goods.getInteger("kan")) {
                                    //成功拿下
                                    goods.put("sale", 1);
                                    //调用奖励的接口
                                    JSONObject g = goods.getJSONObject("goods");
                                    JSONArray list = startBef.rewardService.createGoods(g.getString("key"), g.getInteger("num"), 1, obj.getString("name"), con);
                                    ChannelSupervise.noticeClientByName(list, obj.getString("name"), "10000");
                                    ChannelSupervise.noticeClientByName(712, obj.getString("name"), "827");
                                } else {
                                    ChannelSupervise.noticeClientByName(711, obj.getString("name"), "827");
                                }
                                mybatisConfig.commit(con);
                                //通知刷新余额缓存
                                JSONObject result = new JSONObject();
                                result.put("v", -nowPrice);
                                result.put("i", goods.getInteger("priceType"));
                                ChannelSupervise.noticeClientByName(result, obj.getString("name"), "828");
                            } catch (Exception e) {
                                e.printStackTrace();
                                mybatisConfig.rollback(con);
                            } finally {
                                mybatisConfig.close(con);
                            }
                        } else {//已变动
                            ChannelSupervise.noticeClientByName(710, obj.getString("name"), "827");
                        }
                    } catch (Exception e) {
                        loggerUtils.error(e.getMessage(), this.getClass());
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        };
        //每6s公布抢购结果
        staticCollection.putTask(runnable1, 6, 6, TimeUnit.SECONDS);
    }

    /**
     * 砍价规则
     * 每个人都可以砍，并且只会发给最后一刀的玩家。实际收到的钱会大于发布的钱
     * 计算：10000元宝 第一刀100元宝 第二刀200元宝。。。
     * n*a1+n(n-1)d/2    n(a1+an)/2
     * (price-n*a1)*2/(n(n-1))=d
     */
    public static Integer publishCutPrice(String name, String key, Integer num, Integer price, Integer priceType) {
        JSONObject obj = new JSONObject();
        obj.put("key", key);
        obj.put("num", num);
        long created = strUtils.getTime();
        String id = strUtils.getId();
        JSONObject res = new JSONObject();
        res.put("Id", id);
        res.put("goods", obj);
        res.put("price", price);//总价格
        res.put("priceType", priceType);
        res.put("created", created);
        res.put("type", 0);
        res.put("name", name);
        res.put("sale", 0);//是否出售了
        res.put("kan", 1);//砍了多少次
        //最后一次一定是超过
        int n = strUtils.getRandom(3, 7);
        res.put("times", n + 1);//3-7次砍完
        //n*a1+n(n-1)d/2=price
        //2(price-n*a1)/(n(n-1))=d
        int a = price / (2 * n);
        float d = (price - n * a) * 2f / (n * (n - 1));
        res.put("d", d);
        res.put("a", a);
        //System.err.println(d + "/" + n);
        staticCollection.cutPriceGoodsMap.put(id, res);
        return 1;
    }

    /**
     * 购买玉帛商品
     */
    /*public result buyYbGoods(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        JSONObject obj = getGoodsMsg(key);
        if (obj == null || obj.getInteger("type") != 0) {
            return new result(0);
        }
        if (startBef.packageService.cutPlayerGoodsNumByKey("1052", obj.getInteger("price"), name, con) == 0) {
            return new result(0);
        }
        JSONArray list = startBef.rewardService.createGoods(key, obj.getInteger("num"), 1, name, con);
        return new result(200, list);
    }*/

    /**
     * 购买帮贡商品
     */
    /*public result buyBgGoods(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        JSONObject obj = getGoodsMsg(key);
        if (obj == null || obj.getInteger("type") != 1) {
            return new result(0);
        }
        JSONObject msg = startBef.manService.getMsgData(name, con);
        if (msg.getInteger("bg") - obj.getInteger("price") < 0) {
            return new result(0);
        }
        int i = startBef.manService.saveMoney(5, -obj.getInteger("price"), name, con);
        if (i == 1) {
            JSONArray list = startBef.rewardService.createGoods(key, obj.getInteger("num"), 1, name, con);
            return new result(200, list);
        }
        return new result(0);
    }*/

    /**
     * 获取帮贡、玉帛商品详情
     */
    /*private JSONObject getGoodsMsg(String key) {
        JSONObject obj = new JSONObject();
        switch (key) {
            case "1009": {
                obj.put("price", 10);
                obj.put("num", 10);
                obj.put("type", 0);//0玉帛1帮贡
                return obj;
            }
            case "1010": {
                obj.put("price", 10);
                obj.put("num", 1);
                obj.put("type", 0);
                return obj;
            }
            case "1011": {
                obj.put("price", 50);
                obj.put("num", 1);
                obj.put("type", 0);
                return obj;
            }
            case "1013": {
                obj.put("price", 1000);
                obj.put("num", 1);
                obj.put("type", 1);
                return obj;
            }
        }
        return null;
    }*/
    private boolean isOpenServerLimitBuy(String key) {
        if (key.equals("10000257") || key.equals("10000258")) return true;
        return false;
    }

    /**
     * 购买道具
     */
    public result buyGoods(JSONObject j,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer num = j.getInteger("num");
        Integer moneyType = j.getInteger("moneyType");
        if (num == null || moneyType == null || num <= 0) {
            return new result(0);
        }
        JSONObject goods = goodsData.getGoodsPrice(j.getString("key"), moneyType);
        if (goods == null) {
            return new result(0);
        }
        //装备数量只能等于1
        if (equipData.get(j.getString("key")) != null && num > 1) {
            return new result(0);
        }
        String k = rewardUtils.moneyTypeToStr(goods.getInteger("moneyType"));
        if (k == null) return new result(0);

        JSONObject msg = startBef.manService.getMsgData(name, con);
        long price = num * goods.getLong("value");
        if(price<0) return new result(0);
        long ye = msg.getLong(k) - price;
        if (ye < 0) {
            return new result(0);
        }
        //判断背包是否已满
        if (!startBef.packageService.isEnough(name, con)) {
            return new result(200, 0);
        }
        //是否为开服限购商品
        /*if (isOpenServerLimitBuy(j.getString("key"))) {
            if (!strUtils.isInDay("2026-02-11 00:00:00", "2026-02-18 23:55:00")) {
                return new result(696);
            }
            activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
            List<JSONObject> list = ac.getOpenServerBuyGift(name);
            if (list.size() == 0) {
                ac.addOpenServerBuyGift(name);
                list = ac.getOpenServerBuyGift(name);
            }
            if (j.getString("key").equals("10000257")) {
                int n = list.get(0).getInteger("g0");
                if (n != 0) return new result(0);
                if (!ac.updateOpenServerBuyGift(name, "1", null)) {
                    return new result(0);
                }
            } else if (j.getString("key").equals("10000258")) {
                int n = list.get(0).getInteger("g1");
                if (n != 0) return new result(0);
                if (!ac.updateOpenServerBuyGift(name, null, "1")) {
                    return new result(0);
                }
            }
        }*/
        float rate = 1;
        //判断是否存在折扣,金票类不允许折扣
        /*if (!strUtils.isNull(j.getString("zkKey")) &&
                !j.getString("key").equals("1000") &&
                !j.getString("key").equals("1001") &&
                !j.getString("key").equals("1002") &&
                (j.getString("zkKey").equals("1074") ||
                        j.getString("zkKey").equals("1075") ||
                        j.getString("zkKey").equals("1076") ||
                        j.getString("zkKey").equals("1077") ||
                        j.getString("zkKey").equals("1078")) &&
                startBef.packageService.cutPlayerGoodsNumByKey(j.getString("zkKey"), 1, name, con) == 1) {
            rate = (Integer.parseInt(j.getString("zkKey").charAt(3) + "") + 1f) * 0.1f;
        }*/
        int r = startBef.manService.saveMoney(goods.getInteger("moneyType"), -Float.valueOf(price * rate + "").longValue(), name, con);
        if (r == 1) {
            //通知客户端获得奖励
            JSONArray list = startBef.rewardService.createGoods(j.getString("key"), num, 0, name, con);
            //累计元宝消费
            if (!j.getString("key").equals("1000") &&
                    !j.getString("key").equals("1001") &&
                    !j.getString("key").equals("1002")) {
                //startBef.sjjlService.recordYBTimes(Float.valueOf(price * rate + "").intValue(), name, con);
            }

            //插入操作日志
            startBef.logService.insertOp("3", name, "购买商城商品/" + j.getString("key") + " x" + num + " 价格:" + price + " 类型：" + k, null, "1");
            return new result(200, list);
        }
        return new result(0);
    }
}
