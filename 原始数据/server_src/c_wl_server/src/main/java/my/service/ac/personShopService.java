package my.service.ac;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.data.goodsData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import static my.utils.staticCollection.groundingGoodsMap;

/**个人商铺*/
public class personShopService {
    /**
     * 购买上架的商品
     */
    public result buyGrounding(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String businessName = j.getString("businessName");
        String Id = j.getString("Id");
        Integer num = j.getInteger("num");
        //不允许自己买自己
        if (businessName == null || Id == null || name == null || num == null ||
                businessName.equals(name) || num <= 0)
            return new result(0);
        JSONArray list = groundingGoodsMap.get(businessName);
        if (list == null) return new result(0);
        JSONObject gd = null;
        for (Object l : list) {
            JSONObject o = (JSONObject) l;
            if (o.getString("Id").equals(Id)) {
                gd = o;
                break;
            }
        }
        if (gd == null) return new result(0);

        JSONObject one = null;
        if (gd.getInteger("gdType") == 0) {
            //验证背包是否超出最大格子数
            if (!startBef.packageService.isEnough(name, con)) {
                return new result(0);
            }
            //验证商家是否真实存在该道具
            one = startBef.packageService.getOne(Id, businessName, con);
            if (one == null) {
                //没有改物品即是卖光了
                list.remove(gd);
                return new result(200, 0);
            }
            if (one.getInteger("num") < num) {
                //购买量大于商家拥有量
                gd.put("num", one.getInteger("num"));
                return new result(200, 0);
            }
            //不允许邮寄
            if (goodsData.isNoAllowedSend(one)) {
                return new result(200, 0);
            }
            //验证玩家余额是否充足
            if (startBef.manService.saveMoney(gd.getInteger("priceType"), -gd.getLong("price") * num, name, con) != 1) {
                return new result(0);
            }

            if (startBef.packageService.cutPlayerGoodsNum(Id, num, businessName, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            //将物品发送给购买者
            one.put("num", num);
            if (startBef.packageService.goodsToPackage(one, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            gd.put("num", gd.getInteger("num") - num);
            //通知商品到账
            ChannelSupervise.noticeClientByName(rewardUtils.getGoodsReward(one), name, "10000");
        } else {
            //验证是否超出最大宠物数
            if (startBef.petService.isOverLimitNum(name, con)) {
                return new result(0);
            }
            JSONArray pets = startBef.petService.getList(businessName, con);
            for (Object o : pets) {
                JSONObject pet = (JSONObject) o;
                if (pet.getString("Id").equals(Id)) {
                    one = pet;
                    break;
                }
            }
            if (one == null) {
                //没有改物品即是卖光了
                list.remove(gd);
                return new result(200, 0);
            }
            if (one.getInteger("isFight") == 1 || one.getInteger("growLv") >= 6) {
                return new result(200, 0);
            }
            //验证玩家余额是否充足
            if (startBef.manService.saveMoney(gd.getInteger("priceType"), -gd.getLong("price") * num, name, con) != 1) {
                return new result(0);
            }
            //将宠物删除并转移给买家
            JSONObject petCopy = JSON.parseObject(JSON.toJSONString(one));
            pets.remove(one);
            //移除卖家宠物
            if (startBef.petService.savePetList(pets, businessName, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            //将宠物发送到买家
            if (startBef.petService.addOnePet(petCopy, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            gd.put("num", gd.getInteger("num") - num);
            //通知商品到账
            ChannelSupervise.noticeClientByName(rewardUtils.getPetReward(one), name, "10000");
        }

        //将获得的钱打给商家
        long price = (long) (1f * gd.getInteger("price") * num);
        int priceType = gd.getInteger("priceType");
        if (startBef.manService.saveMoney(priceType, price, businessName, con) != 1) {
            gd.put("num", gd.getInteger("num") + num);
            mybatisConfig.rollback(con);
            return new result(0);
        }

        //对于卖光的要移除缓存
        if (gd.getInteger("num") <= 0) {
            list.remove(gd);
        }
        //插入操作日志
        startBef.logService.insertOp("3", name, "购买上架商品" + one.getString("key") + " x" + num, businessName, "1");
        try {
            //通知商家货币到账以及刷新道具数量
            JSONObject msg = new JSONObject();
            msg.put("type", 0);//0道具1宠物2接取邮件获利
            msg.put("Id", Id);
            msg.put("num", num);
            msg.put("moneyType", priceType);
            msg.put("money", price);
            ChannelSupervise.noticeClientByName(msg, businessName, "826");
        } catch (Exception e) {
            loggerUtils.error("通知失败：" + e.getMessage(), this.getClass());
        }
        return new result(200, 1);
    }

    /**
     * 下架商品
     */
    public result undercarriage(JSONObject j,
                                @paramsAnno(key = "user") user user) {
        final String name = user.name;
        String Id = j.getString("Id");
        JSONArray list = groundingGoodsMap.get(name);
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            if (obj.getString("Id").equals(Id)) {
                list.remove(o);
                if (list.size() == 0) {
                    groundingGoodsMap.remove(name);
                }
                return new result(200, 1);
            }
        }
        return new result(200, 0);
    }

    /**
     * 获取玩家上架的商品id
     */
    public result findGroundingByName(@paramsAnno(key = "user") user user) {
        JSONArray list = groundingGoodsMap.get(user.name);
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
     * 查找玩家上架的商品详情
     */
    public result findGroundingDes(JSONObject j,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        String Id = j.getString("Id");
        if (Id == null) return new result(0);
        for (String name : groundingGoodsMap.keySet()) {
            JSONArray list = groundingGoodsMap.get(name);
            for (Object o : list) {
                JSONObject obj = (JSONObject) o;
                if (obj.getString("Id").equals(Id)) {
                    int gdType = obj.getInteger("gdType");
                    if (gdType == 0) {
                        JSONObject res = startBef.packageService.getOne(Id, name, con);
                        if (res == null || res.getInteger("pos") == 1 ||
                                res.getInteger("isBind") == 1) {
                            list.remove(o);
                            return new result(200, 0);
                        }
                        return new result(200, res);
                    } else {
                        JSONObject res = (JSONObject) startBef.petService.getPetViewById(Id, name, con);
                        if (res == null || res.getInteger("isFight") == 1 ||
                                res.getInteger("growLv") >= 6) {
                            list.remove(o);
                            return new result(200, 0);
                        }
                        return new result(200, res);
                    }

                }
            }
        }
        return new result(200, 0);
    }

    /**
     * 查找上架的商品
     */
    public result findGrounding(JSONObject j) {
        String type = j.getString("type");
        Integer pageNum = j.getInteger("pageNum");
        if (type == null || pageNum == null || pageNum < 1) return new result(0);
        int i = 0;
        JSONArray aList = new JSONArray();
        for (String name : groundingGoodsMap.keySet()) {
            JSONArray list = groundingGoodsMap.get(name);
            for (Object o : list) {
                JSONObject obj = (JSONObject) o;
                if (type.equals("all") ||
                        obj.getString("type").equals(type)) {
                    if ((pageNum - 1) * 10 <= i && i < pageNum * 10) {
                        JSONObject copy = JSON.parseObject(JSON.toJSONString(obj));
                        copy.put("name", name);
                        aList.add(copy);
                        if (aList.size() >= 10) break;
                    }
                    i++;
                }
            }
        }
        //判断是否存在下一页
        int pageSum = aList.size()/10 < 10 ? pageNum : pageNum + 1;
        JSONObject res = new JSONObject();
        res.put("list", aList);
        res.put("totalPage", pageSum);
        return new result(200, res);
    }

    /**
     * 玩家上架商品
     */
    public result grounding(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        int price = j.getInteger("price");
        int priceType = j.getInteger("priceType");
        int num = j.getInteger("num");
        int gdType = j.getInteger("gdType");//0道具 1宠物
        if (price <= 0 || num <= 0 || Id == null || (gdType != 0 && gdType != 1) ||
                (priceType != 0 && priceType != 1) || name == null) {
            return new result(0);
        }
        if (groundingGoodsMap.get(name) == null) {
            groundingGoodsMap.put(name, new JSONArray());
        }
        //超过5个架位
        if (groundingGoodsMap.get(name).size() >= 25) {
            return new result(902);
        }
        JSONArray list = groundingGoodsMap.get(name);
        for (Object l : list) {
            JSONObject o = (JSONObject) l;
            //该物品已经上过了
            if (o.getString("Id").equals(Id)) {
                return new result(200, 0);
            }
        }
        JSONObject g = null;
        String type = null;
        Object params = null;
        if (gdType == 0) {
            g = startBef.packageService.getOne(Id, name, con);
            if (g == null) return new result(0);
            //当存在锻造等级字段时需将其放入
            if (g.containsKey("forging")) {
                JSONObject a = new JSONObject();
                a.put("forging", g.get("forging"));
                if (g.containsKey("inlay")) {
                    a.put("inlay", g.get("inlay"));
                }
                a.put("isBad", g.get("isBad"));
                params = a;
            }
            //不允许邮寄
            if (goodsData.isNoAllowedSend(g)) {
                return new result(0);
            }
            //并没有该物品时
            if (g.getInteger("num") < num || g.getInteger("num") <= 0) {
                return new result(0);
            }
            type = filterType(g.getString("key"), 0);
            //无分类时
            if (type == null) {
                return new result(0);
            }
        } else {//宠物
            g = (JSONObject) startBef.petService.getPetViewById(Id, name, con);
            //成6以上不允许
            if (g == null || g.getInteger("growLv") >= 6) {
                return new result(0);
            }
            type = filterType(g.getString("key"), 1);
            //无分类时
            if (type == null) {
                return new result(0);
            }
        }

        JSONObject obj = new JSONObject();
        obj.put("key", g.getString("key"));
        obj.put("Id", Id);
        obj.put("num", num);
        obj.put("price", price);
        obj.put("priceType", priceType);
        obj.put("type", type);
        obj.put("gdType", gdType);
        obj.put("params", params);
        groundingGoodsMap.get(name).add(obj);
        //插入操作日志
        startBef.logService.insertOp("3", name, "上架" + (gdType == 0 ? "物品" : "宠物") + obj.getString("key") + " x" + obj.getInteger("num"), null, "1");
        return new result(200, 1);
    }

    /**
     * 根据key分类
     */
    public String filterType(String key, int gdType) {
        if (gdType == 1) return "b0";//宠物
        if (key.matches("1000([0-9]{4})")) {
            return "a0";//普通道具
        } else if (key.matches("1001([0-9]{8})")) {
            return "a1";//装备
        } else if (key.matches("1003([0-9]{4})")) {
            return "a3";//镶嵌宝石
        } else if (key.matches("1008([0-9]{8})")) {
            return "a8";//技能书
        } else if (key.matches("1009([0-9]{8})")) {
            return "a9";//刻印
        } else if (key.matches("1010([0-9]{4})")) {
            return "a10";//模板
        }
        return null;
    }
}
