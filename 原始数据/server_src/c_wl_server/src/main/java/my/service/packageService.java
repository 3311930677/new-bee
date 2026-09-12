package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.jsonMapper;
import my.data.equipData;
import my.data.goodsData;
import my.db.mybatisConfig;
import my.gameUtils.baoshiUtils;
import my.gameUtils.rewardUtils;
import my.gameUtils.roleUtils;
import my.model.ChannelSupervise;
import my.model.fbResult;
import my.model.result;
import my.model.user;
import my.service.hds.useGoodsHandle;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import static my.data.equipData.*;
import static my.data.goodsData.*;

public class packageService {
    /**
     * 获取宠物装备
     */
    public JSONObject getPetEquip(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> arr = jsonMapper.selectPetEquipView(name);
        if (arr.size() == 0) {
            JSONObject a = new JSONObject();
            a.put("wq", "");
            a.put("fj", "");
            a.put("sp", "");
            return a;
        }
        return arr.get(0).getJSONObject("equip");
    }

    /**
     * 卸下宠物装备
     */
    public result downPetEquip(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String partKey = j.getString("partKey");
        if (!partKey.equals("wq") && !partKey.equals("fj") && !partKey.equals("sp")) return new result(0);
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> arr = jsonMapper.selectPetEquip(name);
        JSONObject one = arr.get(0);
        JSONObject equip = one.getJSONObject("equip");
        if (equip.getString(partKey).equals("")) return new result(0);
        JSONObject old = null;
        if (!equip.getString(partKey).equals("")) {
            old = equip.getJSONObject(partKey);
            if (goodsToPackage(old, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        equip.put(partKey, "");
        if (!jsonMapper.updatePetEquip(name, JSON.toJSONString(equip))) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONObject res = new JSONObject();
        res.put("equip", equip);
        if (old != null) {
            res.put("old", old);
        }
        return new result(200, res);
    }

    /**
     * 给宠物上装备
     */
    public result upPetEquip(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        JSONObject one = startBef.packageService.getOne(Id, name, con);
        String key = one.getString("key");
        if (key == null || !strUtils.isMatch(key, "1016([0-9]{4})")) {
            return new result(0);
        }
        if (startBef.packageService.cutPlayerGoodsNum(Id, 1, name, con) != 1) {
            return new result(0);
        }
        //是否过期
        long endTime = one.getLong("endTime");
        if (strUtils.getTime() > endTime) {
            return new result(218);
        }

        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> arr = jsonMapper.selectPetEquip(name);
        if (arr.size() == 0) {
            JSONObject a = new JSONObject();
            a.put("wq", "");
            a.put("fj", "");
            a.put("sp", "");
            jsonMapper.addPetEquip(name, JSON.toJSONString(a));
            arr = jsonMapper.selectPetEquip(name);
        }
        String partKey = null;
        if (key.equals("10160000") || key.equals("10160001")) {
            partKey = "fj";
        } else if (key.equals("10160002") || key.equals("10160003")) {
            partKey = "sp";
        } else return new result(0);
        JSONObject equip = arr.get(0).getJSONObject("equip");
        //将旧的装备卸下
        JSONObject old = null;
        if (!equip.getString(partKey).equals("")) {
            old = equip.getJSONObject(partKey);
            if (goodsToPackage(old, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        //记录key和过期时间
        equip.put(partKey, one);
        if (!jsonMapper.updatePetEquip(name, JSON.toJSONString(equip))) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONObject res = new JSONObject();
        res.put("equip", equip);
        if (old != null) {
            res.put("old", old);
        }
        return new result(200, res);
    }

    /**
     * 一键出售白装
     */
    public result saleBaiEquip(@paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int sum = 0;
        JSONArray js = this.getGoods(name, con);
        Iterator<Object> al = js.iterator();
        while (al.hasNext()) {
            JSONObject obj = (JSONObject) al.next();
            if (obj.getInteger("pos") == 1 ||
                    !isEquip(obj.getString("key"))) continue;
            JSONObject ep = equipData.get(obj.getString("key"));
            if (ep.getInteger("quality") == 0) {
                al.remove();
                sum++;
            }
        }
        if (sum == 0 || savePackage(js, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rs = rewardUtils.getYinPiaoReward(1000 * sum);
        startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    /**
     * 每分钟减少4点法宝灵气值
     */
    public void cutFaBaoLqz() {
        //todo:上线时需要把灵气值放入user中，卸下和装备法宝时要重新给user的灵气值同步

        //todo:注意每分钟减少直接修改数据库的话可能会太频繁，
        // 一但玩家修改其他装备可能会冲突，所以在user中记录总灵气值，
        // 每分钟修改只改user里的，当卸下法宝或者离线时才写入数据库

        //todo: 战斗计算时只取user中的灵气值

        //只对在线的玩家并且装备了法宝的才进行减少

    }

    /**
     * 查看道具/宠物信息
     */
    public result getPlayerGoodsOrPetMsgById(JSONObject j,
                                             @paramsAnno(key = "user") user user,
                                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer type = j.getInteger("type");
        String Id = j.getString("Id");
        String playerName = j.getString("playerName");
        if (!staticCollection.userIsOnline(playerName)) {
            return new result(831);
        }
        if (Id == null || playerName == null || type == null || (type != 0 && type != 1)) return new result(0);
        if (type == 0) {
            JSONArray list = getPackView(playerName, con).getJSONArray("package");
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.getJSONObject(i);
                if (a.getString("Id").equals(Id)) {
                    a.put("num", 1);
                    return new result(200, a);
                }
            }
        } else {
            Object a = startBef.petService.getPetViewById(Id, playerName, con);
            if (a != null) return new result(200, a);
        }

        return new result(219);
    }
    /**
     * 客户端创建道具
     */
    /*public result TestCreateGoods(JSONObject j,
                                  @paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        int num = j.getInteger("num");
        JSONArray list = startBef.rewardService.createGoods(key, num, 0, name, con);
        ChannelSupervise.noticeClientByName(list, name, "10000");
        return new result(200, 1);
    }*/

    /**
     * 存储银两
     */
    public result cunchuTale(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lv = user.msg.getInteger("lever");
        if (lv < 30) return new result(0);
        long tale = j.getLong("tale");
        if (tale <= 0) return new result(0);
        if (startBef.manService.saveMoney(1, -tale, name, con) != 1)
            return new result(0);
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        long cc = jsonMapper.selectPackageTale(name).get(0).getLong("tale");
        tale = tale + cc;
        long max = (long) (10000000000f * (lv / 100f));
        if (tale > max) return new result(0);
        if (!jsonMapper.updatePackageByName(null, null, null, tale + "", name)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, 1);
    }

    /**
     * 取出银两
     */
    public result quchuTale(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        long tale = j.getLong("tale");
        if (tale <= 0) return new result(0);
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        long cc = jsonMapper.selectPackageTale(name).get(0).getLong("tale");
        if (cc - tale < 0) return new result(0);
        jsonMapper.updatePackageByName(null, null, null, cc - tale + "", name);
        if (startBef.manService.saveMoney(1, tale, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, 1);
    }

    /**
     * 背包/仓库扩容
     */
    public result bbKr(JSONObject j,
                       @paramsAnno(key = "user") user user,
                       @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int type = j.getInteger("type");
        JSONObject obj = getGoodsBBNAndCKN(name, con);
        int bbn = obj.getInteger("bbn");
        int ckn = obj.getInteger("ckn");
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        if (type == 0) {//背包扩容
            if (bbn >= 400) {
                return new result(0);
            }
            //每格200元宝
            if (startBef.manService.saveMoney(0, -200L, name, con) == 0) {
                return new result(0);
            }
            jsonMapper.updatePackageByName(null, bbn + 1 + "", null, null, name);
        } else {//仓库扩容
            if (ckn >= 400) {
                return new result(0);
            }
            //每20000银两一格
            if (startBef.manService.saveMoney(1, -20000L, name, con) == 0) {
                return new result(0);
            }
            jsonMapper.updatePackageByName(null, null, ckn + 1 + "", null, name);
        }
        return new result(200, 1);
    }

    /**
     * 强化刻印
     */
    public result forgingKy(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //刻印石id
        String Id = j.getString("Id");
        if (strUtils.isNull(Id)) {
            return new result(0);
        }
        JSONObject ky = getOne(Id, name, con);
        //判断是否为刻印
        if (ky == null || !isKeyin(ky.getString("key"))) {
            return new result(0);
        }
        //是否有锻造字段，没有就加上
        if (ky.get("forging") == null) {
            JSONObject forging = new JSONObject();
            forging.put("lv", 0);
            ky.put("forging", forging);
        }
        //判断是否达到100级
        JSONObject forging = ky.getJSONObject("forging");
        int lv = forging.getInteger("lv");
        if (lv >= 100) {
            return new result(0);
        }
        //按等级消耗材料
        if (lv < 50) {
            if (cutPlayerGoodsNumByKey("109500", (lv + 1) * 5, name, con) == 0 ||
                    cutPlayerGoodsNumByKey("109501", (lv + 1) * 2, name, con) == 0) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        } else {
            if (cutPlayerGoodsNumByKey("109501", (lv + 1) * 5, name, con) == 0 ||
                    cutPlayerGoodsNumByKey("109502", (lv + 1) * 2, name, con) == 0) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        //按等级计算成功几率，成功+1，失败-1（最低0）
        if (strUtils.isHappend(0, 100, 1 - lv * 0.01f)) {
            lv += 1;
            forging.put("lv", lv);
        } else {
            lv -= 1;
            if (lv < 0) {
                lv = 0;
            }
            forging.put("lv", lv);
        }
        //保存，注意数量置为0
        ky.put("num", 0);
        saveGoods(ky, name, con);
        //返回成功/失败
        return new result(200, 1);
    }

    /**
     * 卸下刻印
     */
    public result unloadKeyin(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String part = j.getString("part");
        //刻印位置a\b\c\d\e
        String pos = j.getString("pos");
        JSONObject equipD = startBef.manService.getEquipDataView(name, con);
        if (equipD.get(part).equals("")) {
            return new result(0);
        }
        JSONObject equip = equipD.getJSONObject(part);
        //判断是否为装备
        if (equip == null || !isEquip(equip.getString("key"))) {
            return new result(0);
        }
        //卸下装载的刻印
        JSONObject a = equip.getJSONObject("keyin");
        if (a.get(pos) != null) {
            JSONObject oldKy = JSON.parseObject(JSON.toJSONString(a.getJSONObject(pos)));

            a.put(pos, "");
            JSONObject obj = new JSONObject();
            obj.put(part, equip);
            if (startBef.manService.saveEquip(name, obj, con) == 0) {
                return new result(0);
            }
            //将刻印返还背包，构建物品结构
            oldKy.put("num", 1);
            oldKy.put("pos", 0);
            oldKy.put("isBad", 0);
            oldKy.put("isBind", 1);//默认摘下就变成绑定
            oldKy.put("Id", strUtils.getId());
            goodsToPackage(oldKy, name, con);
            //返回旧刻印
            JSONObject res = new JSONObject();
            res.put("oldKy", oldKy);
            //重新计算战力
            startBef.orderService.countZlOrder(name);
            return new result(200, res);
        }
        return new result(0);
    }

    /**
     * 刻印
     */
    public result keyin(JSONObject j,
                        @paramsAnno(key = "user") user user,
                        @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //上刻印的部位
        String part = j.getString("part");
        //刻印石id
        String Id = j.getString("Id");
        //刻印的位置 a,b,c,d,e
        String pos = j.getString("pos");
        if (strUtils.isNull(Id) || strUtils.isNull(part) ||
                strUtils.isNull(pos) ||
                (!pos.equals("a") && !pos.equals("b")
                        && !pos.equals("c") && !pos.equals("d")
                        && !pos.equals("e"))) {
            return new result(0);
        }
        JSONObject equipD = startBef.manService.getEquipDataView(name, con);
        if (equipD.get(part).equals("")) {
            return new result(0);
        }
        JSONObject equip = equipD.getJSONObject(part);
        //判断是否为装备
        if (equip == null || !isEquip(equip.getString("key"))) {
            return new result(0);
        }
        //获取刻印
        JSONObject ky = getOne(Id, name, con);
        //判断是否为刻印
        if (ky == null || !isKeyin(ky.getString("key"))) {
            return new result(0);
        }
        //去掉刻印石
        if (cutPlayerGoodsNum(Id, 1, name, con) == 0) {
            return new result(0);
        }
        //帅选刻印的关键字段 key,randomAttr
        JSONObject kyObj = new JSONObject();
        kyObj.put("key", ky.get("key"));
        kyObj.put("randomAttr", ky.get("randomAttr"));
        kyObj.put("forging", ky.get("forging"));

        JSONObject oldKy = null;
        //是否有刻印字段，没有就补上
        if (equip.get("keyin") == null) {
            equipData.putKeyin(equip);
        } else {
            //卸下装载的刻印
            JSONObject a = equip.getJSONObject("keyin");
            if (a.get(pos) != null && !a.getString(pos).equals("")) {
                oldKy = JSON.parseObject(JSON.toJSONString(a.getJSONObject(pos)));
                //将刻印返还背包，构建物品结构
                oldKy.put("num", 1);
                oldKy.put("pos", 0);
                oldKy.put("isBad", 0);
                oldKy.put("Id", strUtils.getId());
                goodsToPackage(oldKy, name, con);
            }
        }
        JSONObject keyin = equip.getJSONObject("keyin");
        keyin.put(pos, kyObj);

        JSONObject obj = new JSONObject();
        obj.put(part, equip);
        if (startBef.manService.saveEquip(name, obj, con) == 0) {
            return new result(0);
        }
        //返回旧刻印
        JSONObject res = new JSONObject();
        res.put("oldKy", oldKy);
        //重新计算战力
        startBef.orderService.countZlOrder(name);
        return new result(200, res);
    }

    /**
     * 学习装备技能
     */
    public result learnEquipSkill(JSONObject j,
                                  @paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String skillKey = j.getString("skillKey");
        String part = j.getString("part");
        if (strUtils.isNull(skillKey) || strUtils.isNull(part)) {
            return new result(0);
        }
        //判断是否为装备技能
        if (!equipData.isEquipSkill(skillKey)) {
            return new result(0);
        }
        JSONObject equipD = startBef.manService.getEquipDataView(name, con);
        if (equipD.get(part).equals("")) {
            return new result(0);
        }
        JSONObject equip = equipD.getJSONObject(part);
        if (equip == null || !equipData.isEquip(equip.getString("key"))) {
            return new result(0);
        }
        //判断是否为金装，或者是否为神装
        if (!equipData.isLiangGoldEquip(equip.getString("key")) &&
                !equipData.isShenEquip(equip.getString("key"))) {
            return new result(0);
        }
        //减少技能书数量
        if (cutPlayerGoodsNumByKey(skillKey, 1, name, con) == 0) {
            return new result(0);
        }
        equipData.putZbSkill(equip, skillKey);
        JSONObject obj = new JSONObject();
        obj.put(part, equip);
        if (startBef.manService.saveEquip(name, obj, con) == 0) {
            return new result(0);
        }
        //重新计算战力
        startBef.orderService.countZlOrder(name);
        //将技能列表返回
        return new result(200, equip.get("skill"));
    }

    /**
     * 亮金飞升（需穿戴）
     */
    public result upLiangGold(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String part = j.getString("part");
        if (strUtils.isNull(part)) return new result(0);
        //需要已经升金+1模板 模板要求与装备职业对应

        JSONObject equips = startBef.manService.getEquipDataView(name, con);
        if (equips.get(part).equals("")) {
            return new result(0);
        }
        //获取该部位的装备
        JSONObject item = equips.getJSONObject(part);
        //判断是否为装备
        JSONObject equip = equipData.get(item.getString("key"));
        if (equip == null || equipData.isEquip(item.getString("key"))) {
            return new result(0);
        }
        //要求必须为金（橙）装才能升亮金
        if (!equipData.isGoldEquip(item.getString("key")) ||
                equipData.isLiangGoldEquip(item.getString("key"))) {
            return new result(0);
        }

        String job = equip.getString("job");
        //模板key
        String mbKey = null;
        if (job.equals("ms")) {
            mbKey = "109300";
        } else if (job.equals("dj")) {
            mbKey = "109301";
        } else if (job.equals("qm")) {
            mbKey = "109302";
        } else if (job.equals("ty")) {
            mbKey = "109303";
        } else if (job.equals("ym")) {
            mbKey = "109304";
        } else if (job.equals("lc")) {
            mbKey = "109305";
        }
        //消耗1个模板
        if (cutPlayerGoodsNumByKey(mbKey, 1, name, con) == 0) {
            return new result(0);
        }
        //多一个技能位置
        equipData.randomPutZbSkill(item);
        //亮金  9件亮金套装属性增加50%
        //todo:key变更成亮金装的key

        item.put("isLj", 1);
        JSONObject obj = new JSONObject();
        obj.put(part, item);
        //重新计算战力
        startBef.orderService.countZlOrder(name);
        return new result(200, startBef.manService.saveEquip(name, obj, con));
    }

    /**
     * 护符兑换声望
     */
    public result exchangeShengwang(JSONObject j,
                                    @paramsAnno(key = "user") user user,
                                    @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (Id == null) return new result(0);
        JSONObject a = getOne(Id, name, con);
        //判断是否为护符
        if (a.getString("key").length() != 12 || !a.getString("key").substring(0, 8).equals("10011008"))
            return new result(0);
        if (cutPlayerGoodsNum(Id, 1, name, con) == 1) {
            int n = Integer.parseInt(a.getString("key").substring(8));
            int num = 0;
            if (n < 4) num = 120;
            else if (n < 6) num = 150;
            else if (n < 8) num = 200;
            else if (n < 9) num = 250;
            JSONArray res = rewardUtils.getSwExpReward(n);
            startBef.rewardService.saveRewards(res, name, con);
            return new result(200, 1);
        }

        return new result(0);
    }

    /**
     * 领取护符
     */
    public result getHf(@paramsAnno(key = "user") user user,
                        @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断进入是否已经领取过
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getAcDayLimit(name);
        if (list.size() == 0) {
            activityMapper.insertAcDayLimit(name);
            JSONObject obj = new JSONObject();
            obj.put("hf", 1);
            list.add(obj);
        }
        int n = list.get(0).getInteger("hf");
        if (n <= 0) {
            return new result(950);
        }
        if (activityMapper.updateAcDayLimit(name, null, n - 1, null, null)) {
            if (strUtils.isHappend(0, 100, 0.3f)) {
                //炼制成功获得护符一枚
                String arr[] = {
                        "100110080000", "100110080001", "100110080002",
                        "100110080003", "100110080004", "100110080005",
                        "100110080006", "100110080007", "100110080008",
                };
                int index = 0;
                if (strUtils.isHappend(0, 1000, 0.5f)) {
                    index = strUtils.getRandom(4, 6);
                } else if (strUtils.isHappend(0, 1000, 0.3f)) {
                    index = strUtils.getRandom(6, 8);
                } else if (strUtils.isHappend(0, 1000, 0.1f)) {
                    index = 8;
                } else {
                    index = strUtils.getRandom(0, 4);
                }
                JSONArray goods = startBef.rewardService.createGoods(arr[index], 1, 1, name, con);
                return new result(200, goods);
            } else {
                //炼制失败得到60点声望
                JSONArray res = rewardUtils.getSwExpReward(60);
                startBef.rewardService.saveRewards(res, name, con);
                return new result(200, 0);
            }
        }
        return new result(0);
    }

    /**
     * 护符注灵
     */
    public result hfZl(JSONObject j,
                       @paramsAnno(key = "user") user user,
                       @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        JSONObject equips = startBef.manService.getEquipDataView(name, con);
        if (strUtils.isNull(Id) || strUtils.isNull(equips.getString("hf"))) {
            return new result(0);
        }
        //验证该id的物品是否为护符类型
        JSONObject one = getOne(Id, name, con);
        if (one == null || one.getInteger("key") < 2600
                || one.getInteger("key") > 2603) {
            return new result(0);
        }
        //数量-1
        if (cutPlayerGoodsNum(Id, 1, name, con) != 1) {
            return new result(0);
        }
        JSONObject hf = equips.getJSONObject("hf");
        JSONObject forging = hf.getJSONObject("forging");
        int exp = forging.getInteger("exp");
        int lv = forging.getInteger("lv");
        List<fbResult> fbResults = equipData.getFabaoResult(hf.getString("key"));
        if (fbResults.size() == 0) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        for (fbResult f : fbResults) {
            if (lv >= f.limitLv) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        //判断是否足够升级
        Double d = (lv + 1) * 100 + 2 * Math.pow(3, 0.1 * (lv + 1));
        int max_exp = d.intValue();
        if (exp + 10 >= max_exp) {
            forging.put("exp", exp + 10 - max_exp);
            forging.put("lv", lv + 1);
        } else {
            forging.put("exp", exp + 10);
        }
        JSONObject e = new JSONObject();
        e.put("hf", hf);
        if (startBef.manService.saveEquip(name, e, con) == 1) {
            return new result(200, forging);
        }
        return new result(0);
    }

    /**
     * 功法注灵
     */
    public result gfZl(@paramsAnno(key = "user") user user,
                       @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONObject equips = startBef.manService.getEquipDataView(name, con);
        if (strUtils.isNull(equips.getString("gf"))) {
            return new result(0);
        }
        //数量-1
        if (cutPlayerGoodsNumByKey("1073", 1, name, con) != 1) {
            return new result(0);
        }
        JSONObject gf = equips.getJSONObject("gf");
        JSONObject forging = gf.getJSONObject("forging");
        int exp = forging.getInteger("exp");
        int lv = forging.getInteger("lv");
        List<fbResult> fbResults = equipData.getFabaoResult(gf.getString("key"));
        if (fbResults.size() == 0) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        for (fbResult f : fbResults) {
            if (lv >= f.limitLv) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        //判断是否足够升级
        Double d = (lv + 1) * 100 + 2 * Math.pow(3, 0.1 * (lv + 1));
        int max_exp = d.intValue();
        if (exp + 10 >= max_exp) {
            forging.put("exp", exp + 10 - max_exp);
            forging.put("lv", lv + 1);
        } else {
            forging.put("exp", exp + 10);
        }
        JSONObject e = new JSONObject();
        e.put("gf", gf);
        if (startBef.manService.saveEquip(name, e, con) == 1) {
            return new result(200, forging);
        }
        return new result(0);
    }

    /**
     * 洗练法宝
     */
    public result xilianFb(JSONObject j,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer type = j.getInteger("type");
        if (type != 0 && type != 1 && type != 2) return new result(0);
        JSONObject equips = startBef.manService.getEquipDataView(name, con);
        if (strUtils.isNull(equips.getString("fb"))) {
            return new result(0);
        }
        JSONObject fb = equips.getJSONObject("fb");
        JSONObject forging = fb.getJSONObject("forging");
        if (cutPlayerGoodsNumByKey("10000166", 1, name, con) == 0 ||
                startBef.manService.saveMoney(1, -200L, name, con) == 0) {
            return new result(0);
        }
        forging.put("type", type);
        JSONObject e = new JSONObject();
        e.put("fb", fb);
        startBef.manService.saveEquip(name, e, con);
        return new result(200, 1);
    }

    /**
     * 法宝强化
     */
    public result upFbLv(@paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONObject equips = startBef.manService.getEquipDataView(name, con);
        if (strUtils.isNull(equips.getString("fb"))) {
            return new result(0);
        }
        JSONObject fb = equips.getJSONObject("fb");
        JSONObject forging = fb.getJSONObject("forging");
        int lv = forging.getInteger("lv");
        if (lv >= 50) return new result(0);
        int[] nums = {
                3, 3, 3, 4, 5, 5, 6, 8, 9, 11,
                12, 13, 15, 16, 17, 19, 21, 23, 26, 29,
                32, 37, 42, 48, 54, 60, 64, 68, 73, 77,
                83, 90, 97, 104, 111, 119, 127, 135, 144, 155,
                166, 178, 191, 204, 217, 232, 247, 263, 279, 294,
        };
        int num = nums[lv];
        if (cutPlayerGoodsNumByKey("10000127", num, name, con) == 0) {
            return new result(0);
        }
        float p = 1;
        /*if (lv < 30) p = 1;
        else p = (float) Math.pow(0.9f, lv - 29) * (1 + 0.1f);*/
        if (strUtils.isHappend(0, 1000, p)) {
            forging.put("lv", lv + 1);
            JSONObject e = new JSONObject();
            e.put("fb", fb);
            startBef.manService.saveEquip(name, e, con);
            return new result(200, 1);
        } else {
            //失败
            return new result(200, 0);
        }
    }

    /**
     * 法宝注灵
     */
    public result zhulingFb(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer type = j.getInteger("type");
        String equipId = j.getString("equipId");
        if (type != 0 && type != 1) return new result(0);

        JSONObject equips = startBef.manService.getEquipDataView(name, con);
        if (strUtils.isNull(equips.getString("fb"))) {
            return new result(0);
        }

        int exp = 0;
        if (type == 0) {
            if (cutPlayerGoodsNumByKey("10000167", 1, name, con) != 1) {
                return new result(0);
            }
            exp = 250;
        } else {
            if (strUtils.isNull(equipId)) return new result(0);
            JSONObject a = getOne(equipId, name, con);
            if (a == null || !equipData.isEquip(a.getString("key"))) return new result(0);
            int lv = equipData.get(a.getString("key")).getInteger("lv");
            if (lv < 60) return new result(0);
            //每日限制10次装备注灵
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            List<JSONObject> list = activityMapper.getAcDayLimit(name);
            if (list.size() == 0) {
                activityMapper.insertAcDayLimit(name);
                JSONObject obj = new JSONObject();
                obj.put("zhuling", 10);
                list.add(obj);
            }
            int n = list.get(0).getInteger("zhuling");
            if (n <= 0) {
                return new result(955);
            }
            if (cutPlayerGoodsNum(equipId, 1, name, con) != 1) {
                return new result(0);
            }
            //注灵次数-1
            activityMapper.updateAcDayLimit(name, null, null, n - 1, null);
            exp = (int) (lv * 1.5f);
        }
        JSONObject fb = equips.getJSONObject("fb");
        JSONObject zhuling = fb.getJSONObject("zhuling");
        zhuling.put("lqz", zhuling.getInteger("lqz") + exp);
        if (zhuling.getInteger("lqz") >= 1000) zhuling.put("lqz", 1000);
        zhuling.put("v", zhuling.getInteger("v") + exp);
        if (zhuling.getInteger("v") >= 1000) {
            zhuling.put("v", zhuling.getInteger("v") - 1000);
            zhuling.put("sld", zhuling.getInteger("sld") + 250);
            int lv = zhuling.getInteger("lv");
            int maxSld = 1000 * lv + 4000;
            if (zhuling.getInteger("sld") >= maxSld) {
                zhuling.put("lv", lv + 1);
                zhuling.put("sld", zhuling.getInteger("sld") - maxSld);
                if (zhuling.getInteger("quality") == 1 && zhuling.getInteger("lv") > 5) {//蓝品 5个阶
                    zhuling.put("quality", zhuling.getInteger("quality") + 1);
                } else if (zhuling.getInteger("quality") == 2 && zhuling.getInteger("lv") > 10) {//紫品 10个阶
                    zhuling.put("quality", zhuling.getInteger("quality") + 1);
                } else if (zhuling.getInteger("quality") == 3 && zhuling.getInteger("lv") > 15) {//橙品 15个阶
                    zhuling.put("lv", zhuling.getInteger("lv") - 1);
                    zhuling.put("sld", maxSld);
                }
            }
        }
        JSONObject e = new JSONObject();
        e.put("fb", fb);
        if (startBef.manService.saveEquip(name, e, con) == 1) {
            return new result(200, 1);
        }
        mybatisConfig.rollback(con);
        return new result(0);
    }


    /**
     * 获取玩家某件道具的详细信息
     */
    public result getGoodsById(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        String Id = j.getString("Id");
        String businessName = j.getString("businessName");
        if (strUtils.isNull(Id) || strUtils.isNull(businessName)) return new result(0);
        JSONObject obj = getOne(Id, businessName, con);
        return new result(200, obj);
    }

    /**
     * 潜力点转换成能力,并获得陨石碎片
     * 返回陨石碎片数量
     */
    public int turnToPotential(Integer point, String name, DefaultSqlSession con) {
        String equipId = my.utils.staticCollection.potentialEquipMap.get(name);
        if (equipId == null) {
            return 0;
        }
        JSONObject equip = getOne(equipId, name, con);
        if (equip == null || point > 50 || point <= 0) {
            return 0;//异常
        }
        //21点-22点双倍
        if (strUtils.isInTime(21, 0, 22, 0)) {
            point *= 2;
        }
        //多倍练潜状态
        if (startBef.manService.isStatusOpen("dblq", name)) {
            point *= 2;
        }
        equip.put("num", 0);
        JSONObject potential = equip.getJSONObject("potential");
        //是否还剩潜力
        if (potential.getInteger("num") <= 0) {
            return 0;
        }
        potential.put("num", potential.getInteger("num") - point);
        if (potential.getInteger("num") < 0) {
            potential.put("num", 0);
        }
        //怪物数
        int sum = point / 10;
        //实际能力点
        JSONObject inlay = equip.getJSONObject("inlay");
        JSONArray list = inlay.getJSONArray("list");
        boolean b = false;
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            //获取能力上限点进行对比
            int max = baoshiUtils.getBaoshiAttr(obj.getString("key").substring(4));
            if (max > obj.getInteger("num")) {
                obj.put("num", obj.getInteger("num") +
                        Integer.parseInt(point / 10 + ""));
                point = 0;
                b = true;
            } else {
                continue;
            }
            int a = obj.getInteger("num") - max;
            if (a > 0) {
                obj.put("num", max);
                point = a * 10;
            }
        }
        //全部超过最大能力值
        if (!b) {
            return 0;
        }
        saveGoods(equip, name, con);
        JSONObject res = new JSONObject();
        res.put("Id", equipId);
        res.put("potential", potential);
        res.put("inlay", inlay);
        ChannelSupervise.noticeClientByName(res, name, "109");
        return sum;

    }

    /**
     * 道具转移（偷袭）
     */
    public int aGoodToB(String aName, String bName, DefaultSqlSession con) {
        if (strUtils.isHappend(0, 100, 0.2f)) {
            //转移装备
            return aEquipToBPackage(aName, bName, con);
        } else {
            //转移道具
            return aToBPackage(aName, bName, con);
        }
    }

    /**
     * 只在偷袭战斗中使用
     * 将装备转移到玩家背包
     */
    private int aEquipToBPackage(String aName, String bName, DefaultSqlSession con) {
        //1%银两
        long tale = 0;
        tale = startBef.manService.getMsgData(aName, con).getInteger("tale");
        tale = (long) (tale * 0.01f);
        if (tale <= 0) tale = 0;
        if (tale > 0) {
            //扣除
            startBef.manService.saveMoney(1, -tale, aName, con);
        }
        JSONObject equips = startBef.manService.getEquipData(aName, con);
        //String[] parts = {"wq", "jb", "sz", "wb", "tb", "xb", "yb", "tuib", "jiaob", };
        List<String> ps = new ArrayList<>();
        for (String k : equips.keySet()) {
            if (strUtils.isNull(equips.getString(k))) continue;
            JSONObject a = equips.getJSONObject(k);
            if (goodsData.isNoAllowedSend(a)) {
                continue;
            }
            //查找哪些是未绑定的
            ps.add(k);
        }
        //随机一个部位
        if (ps.size() == 0) {
            if (tale == 0) return 0;
            JSONArray ens = new JSONArray();
            startBef.emailService.sendSysEmail(bName, "偷袭获得对方道具", ens.toArray(), tale, con);
            //通知该道具被抢走
            JSONObject msg = new JSONObject();
            msg.put("name", bName);
            msg.put("tale", tale);
            ChannelSupervise.noticeClientByName(msg, aName, "829");
            startBef.logService.insertOp("4", aName, tale + "/道具被夺走 " + ens.toArray(), bName, "1");
            return 1;
        }
        String part = ps.get(strUtils.getRandom(0, ps.size()));
        JSONObject ep = equips.getJSONObject(part);
        ep.put("Id", strUtils.getId());
        ep.put("enType", 0);
        JSONArray ens = new JSONArray();
        ens.add(ep);
        //将转移者的装备置空
        JSONObject rp = new JSONObject();
        rp.put(part, "");
        startBef.manService.saveEquip(aName, rp, con);
        //发送邮件
        startBef.emailService.sendSysEmail(bName, "偷袭获得对方道具", ens.toArray(), tale, con);
        //通知该道具被抢走
        JSONObject msg = new JSONObject();
        msg.put("part", part);//装备就包含part，背包的道具就包含Id
        msg.put("name", bName);
        ChannelSupervise.noticeClientByName(msg, aName, "829");
        startBef.logService.insertOp("4", aName, "道具被夺走 " + ep, bName, "1");
        return 1;
    }

    /**
     * 只在偷袭战斗中使用
     * 由a玩家背包转移到b玩家背包(随机转移一个道具)
     */
    private int aToBPackage(String aName, String bName, DefaultSqlSession con) {
        //1%银两
        long tale = 0;
        tale = startBef.manService.getMsgData(aName, con).getInteger("tale");
        tale = (long) (tale * 0.01f);
        if (tale <= 0) tale = 0;
        if (tale > 0) {
            //扣除
            startBef.manService.saveMoney(1, -tale, aName, con);
        }
        JSONArray js = this.getGoods(aName, con);
        //对于在仓库跟不允许邮件的物品进行清理
        Iterator<Object> al = js.iterator();
        while (al.hasNext()) {
            JSONObject obj = (JSONObject) al.next();
            if (obj.getInteger("pos") == 1 ||
                    obj.getString("key").equals("10000000") ||
                    obj.getString("key").equals("10000001") ||
                    obj.getString("key").equals("10000002") ||
                    obj.getString("key").substring(0, 4).equals("1002") ||
                    goodsData.isNoAllowedSend(obj)) {
                al.remove();
            }
        }
        if (js.size() == 0) {
            if (tale == 0) return 0;
            JSONArray ens = new JSONArray();
            startBef.emailService.sendSysEmail(bName, "偷袭获得对方道具", ens.toArray(), tale, con);
            //通知该道具被抢走
            JSONObject msg = new JSONObject();
            msg.put("name", bName);
            msg.put("tale", tale);
            ChannelSupervise.noticeClientByName(msg, aName, "829");
            startBef.logService.insertOp("4", aName, tale + "/道具被夺走 " + ens.toArray(), bName, "1");
            return 1;
        }
        int index = strUtils.getRandom(0, js.size());
        JSONObject goods = (JSONObject) js.get(index);

        String id = goods.getString("Id");
        if (cutPlayerGoodsNum(id, 1, aName, con) == 0) {
            return 0;
        }
        goods.put("num", 1);
        goods.put("enType", 0);
        //goodsToPackage(goods, bName, con);
        JSONArray ens = new JSONArray();
        ens.add(goods);
        //发送邮件
        startBef.emailService.sendSysEmail(bName, "偷袭获得对方道具", ens.toArray(), tale, con);
        //通知该道具被抢走
        JSONObject msg = new JSONObject();
        msg.put("Id", id);
        msg.put("name", bName);
        msg.put("tale", tale);
        ChannelSupervise.noticeClientByName(msg, aName, "829");
        startBef.logService.insertOp("4", aName, tale + "/道具被夺走 " + ens.toArray(), bName, "1");
        //通知道具获得
        //JSONArray list = rewardUtils.getGoodsReward(goods);
        //ChannelSupervise.noticeClientByName(list, bName, "10000");
        return 1;
    }

    /**
     * 将一个已经生成好的物品放入玩家背包(背包道具原封转移)
     */
    public Integer goodsToPackage(JSONObject goods, String name, DefaultSqlSession con) {
        JSONArray js = this.getGoods(name, con);
        //重新生成一个id
        goods.put("Id", getId(js, goods.getString("Id")));
        JSONObject g = equipData.get(goods.getString("key"));
        if (g != null) {
            //装备，不能叠加
            js.add(goods);
            return savePackage(js, name, con);
        }
        //刻印不能叠加
        if (equipData.isKeyin(goods.getString("key"))) {
            js.add(goods);
            return savePackage(js, name, con);
        }
        //宠物装备不能叠加
        if (equipData.isPetEquip(goods.getString("key"))) {
            js.add(goods);
            return savePackage(js, name, con);
        }
        //不是装备，判断是否需要叠加
        boolean b = false;
        Iterator<Object> list = js.iterator();
        while (list.hasNext()) {
            JSONObject j = (JSONObject) list.next();
            //存在叠加的key
            if (j.getString("key").equals(goods.getString("key"))) {
                b = true;
                j.put("num", j.getInteger("num") + goods.getInteger("num"));
                goods.put("Id", j.getString("Id"));
                break;
            }
        }
        if (!b) {
            js.add(goods);
        }
        return savePackage(js, name, con);
    }

    /**
     * 获取一个一定不会重复的id
     */
    public String getId(JSONArray js, String Id) {
        if (isRepeatId(js, Id)) {
            getId(js, strUtils.getId());
        }
        return Id;
    }

    /**
     * 判断id是否出现重复
     */
    private boolean isRepeatId(JSONArray js, String Id) {
        Iterator<Object> list = js.iterator();
        while (list.hasNext()) {
            JSONObject j = (JSONObject) list.next();
            //id出现重复
            if (j.getString("Id").equals(Id)) {
                return true;
            }
        }
        return false;
    }


    /**
     * 摘除镶嵌石（返还）
     */
    public result zhaixiaInlay(JSONObject data,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //装备Id
        String Id = data.getString("Id");
        int index = data.getInteger("index");
        JSONObject equip = getOne(Id, name, con);
        //判断是否为装备
        if (equip == null || !isEquip(equip.getString("key"))) {
            return new result(0);
        }
        JSONObject inlay = equip.getJSONObject("inlay");
        JSONArray list = inlay.getJSONArray("list");
        String bsKey = list.getJSONObject(index).getString("key");
        list.remove(index);
        equip.put("num", 0);
        if (saveGoods(equip, name, con) == 0) {
            return new result(0);
        }
        //返还宝石key
        JSONArray res = startBef.rewardService.createGoods(bsKey, 1, 1, name, con);
        return new result(200, res);
    }

    /**
     * 精炼
     */
    public result jinglian(JSONObject data,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        if (data.get("Id1") == null || data.get("index1") == null ||
                data.get("Id2") == null || data.get("index2") == null) {
            return new result(901);
        }
        final String name = user.name;
        String Id1 = data.getString("Id1");
        int index1 = data.getInteger("index1");
        String Id2 = data.getString("Id2");
        int index2 = data.getInteger("index2");

        if (Id1.equals(Id2)) return new result(0);
        //确保装备、属性是真实存在
        JSONObject equip1 = getOne(Id1, name, con);
        JSONArray randomAttr1 = equip1.getJSONArray("randomAttr");
        if (equip1 == null || index1 >= randomAttr1.size() ||
                randomAttr1.get(index1) == null)
            return new result(0);
        //判断是否为装备
        if (!isEquip(equip1.getString("key"))) {
            return new result(0);
        }
        JSONObject equip2 = getOne(Id2, name, con);
        JSONArray randomAttr2 = equip2.getJSONArray("randomAttr");
        if (equip2 == null || index2 >= randomAttr2.size() ||
                randomAttr2.get(index2) == null)
            return new result(0);
        //判断是否为装备
        if (!isEquip(equip2.getString("key"))) {
            return new result(0);
        }
        //要求等级、品质要一致
        if (!equipData.isEnoughJL(equip1.getString("key"),
                equip2.getString("key"))) {
            return new result(900);
        }

        int isUser = data.getInteger("isUser");
        if (isUser == 1) {
            int cutSuc = cutPlayerGoodsNumByKey("10000109", 1, name, con);
            if (cutSuc == 0) {
                //使用精炼石但是扣除失败
                return new result(200, -2);
            }
        }
        //未使用精炼宝石
        if (isUser != 1) {
            //随机选择一个属性附加
            index2 = strUtils.getRandom(0, randomAttr2.size());
        }
        //精炼项
        JSONObject it1 = randomAttr1.getJSONObject(index1);
        JSONObject it2 = randomAttr2.getJSONObject(index2);
        String k1 = it1.getString("k");
        int v1 = it1.getInteger("v");
        String k2 = it2.getString("k");
        int v2 = it2.getInteger("v");
        if (k1.equals(k2)) {//属性往上叠加
            //超出等级限制的最大属性
            if (equipData.isOverLimitAttr(equip1.getString("key"), k1, v1)) {
                mybatisConfig.rollback(con);
                return new result(200, -1);
            }
            int value = 0;
            int add = v2 / 10;
            if (add == 0) add = 1;
            if (v2 > v1) {
                value = v2 + add;
            } else {
                value = v1 + add;
            }
            int max = getMaxJingLianAttr(equip1.getString("key"), k1);
            if (value > max) value = max;
            it1.put("k", k2);
            it1.put("v", value);
        } else {//属性替换
            //k,v
            int value = v2;
            int max = getMaxJingLianAttr(equip1.getString("key"), k2);
            if (value > max) value = max;
            it1.put("k", k2);
            it1.put("v", value);
        }

        //保存装备，移除副装备
        if (cutPlayerGoodsNum(Id2, 1, name, con) == 0) {
            mybatisConfig.rollback(con);
            return new result(200, -3);
        }
        equip1.put("num", 0);
        if (saveGoods(equip1, name, con) == 0) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //返回变更的属性
        return new result(200, randomAttr1);
    }

    /**
     * 抗性提升（增加抗性字段）
     */
    public result upKangxing(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (strUtils.isNull(Id)) return new result(0);
        JSONObject equip = getOne(Id, name, con);
        if (equip == null || equip.getInteger("isBad") == 1 ||
                !isEquip(equip.getString("key"))) return new result(0);
        //戒指和鞋对应暴击抗性，护腕和腿对应混乱抗性，项链和胸甲对应流血抗性，头部和腰带对应睡眠抗性。
        //90级以上且锻10以上的紫装，不能是武器
        JSONObject epMsg = equipData.get(equip.getString("key"));
        JSONObject forging = equip.getJSONObject("forging");
        if (epMsg.getInteger("quality") < 2 ||
                epMsg.getInteger("lv") < 91 ||
                forging.getInteger("lv") < 10 ||
                epMsg.getString("part").equals("wq"))
            return new result(0);
        if (equip.get("kxlv") == null) {
            //四个抗性等级
            JSONObject a = new JSONObject();
            a.put("bjlv", 0);
            a.put("hslv", 0);
            a.put("hllv", 0);
            a.put("lxlv", 0);
            equip.put("kxlv", a);
        }
        String kxKey = null;
        String part = epMsg.getString("part");
        if (part.equals("sz") || part.equals("jiaob")) kxKey = "bjlv";
        else if (part.equals("wb") || part.equals("tuib")) kxKey = "hllv";
        else if (part.equals("jb") || part.equals("xb")) kxKey = "lxlv";
        else if (part.equals("tb") || part.equals("yb")) kxKey = "hslv";
        JSONObject kxlv = equip.getJSONObject("kxlv");
        if (kxlv.get(kxKey) == null || kxlv.getInteger(kxKey) >= 10) return new result(0);
        //获取抗性等级
        int lv = kxlv.getInteger(kxKey) + 1;
        //int kx = 50 * lv + (int)Math.Pow(2d, lv);
        int num = 6 * lv + (int) Math.pow(1.5d, lv);
        long tale = 2000 + (lv - 1) * 20000 + (long) Math.pow(3d, lv);
        //消耗银两
        if (startBef.manService.saveMoney(1, -tale, name, con) == 0) {
            return new result(0);
        }
        String xhKey = null;
        if (kxKey.equals("bjlv")) xhKey = "10000152";
        else if (kxKey.equals("hllv")) xhKey = "10000153";
        else if (kxKey.equals("lxlv")) xhKey = "10000154";
        else if (kxKey.equals("hslv")) xhKey = "10000155";
        // 消耗一定的抗性玉石
        if (cutPlayerGoodsNumByKey(xhKey, num, name, con) == 0) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //抗性等级+1
        kxlv.put(kxKey, lv);
        equip.put("isBind", 1);//变为绑定
        equip.put("num", 0);//避免数量++

        if (saveGoods(equip, name, con) == 1)
            return new result(200, lv);

        mybatisConfig.rollback(con);
        return new result(0);
    }

    /**
     * 橙装血契
     */
    public result xueqiChengEquip(JSONObject j,
                                  @paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (strUtils.isNull(Id)) return new result(0);
        JSONObject equip = getOne(Id, name, con);
        if (equip == null || equip.getInteger("isBad") == 1 ||
                !isEquip(equip.getString("key"))) return new result(0);
        //需要橙装，锻造20
        if (!isGoldEquip(equip.getString("key")) ||
                equip.getJSONObject("forging").getInteger("lv") != 20) return new result(0);
        JSONObject epMsg = equipData.get(equip.getString("key"));
        if (epMsg.getInteger("lv") < 91) return new result(0);
        //未刻印的不允许血契\是否已经血契了
        if (!equip.containsKey("kybs") || equip.containsKey("xqbs")) return new result(0);
        //消耗血契之石
        if (cutPlayerGoodsNumByKey("10000161", 1, name, con) == 0) {
            return new result(0);
        }
        //增加一个孔，同时基础属性增加60%
        JSONObject inlay = equip.getJSONObject("inlay");
        inlay.put("num", inlay.getInteger("num") + 1);
        //增加一个表示已经血契的字段
        equip.put("xqbs", 1);
        equip.put("num", 0);//为了不影响数量，所以设置为0

        if (saveGoods(equip, name, con) == 1)
            return new result(200, 1);
        mybatisConfig.rollback(con);
        return new result(0);
    }

    /**
     * 锻造橙装
     */
    public result forgingChengEquip(JSONObject j,
                                    @paramsAnno(key = "user") user user,
                                    @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        String bsKey = j.getString("bsKey");
        if (strUtils.isNull(Id) || strUtils.isNull(bsKey)) return new result(0);
        JSONObject equip = getOne(Id, name, con);
        if (equip == null || equip.getInteger("isBad") == 1 ||
                !isEquip(equip.getString("key"))) return new result(0);
        //需要橙装
        if (!isGoldEquip(equip.getString("key")) ||
                equip.getJSONObject("forging").getInteger("lv") >= 20) return new result(0);
        JSONObject epMsg = equipData.get(equip.getString("key"));
        if (epMsg.getInteger("lv") < 91) return new result(0);
        //需要金锻皇或者轻锻宝石
        boolean isQing = true;
        if (bsKey.equals("10000159")) isQing = false;
        else if (bsKey.equals("10000160")) isQing = true;
        else return new result(0);

        equip.put("num", 0);//为了不影响数量，所以设置为0

        int lv = equip.getJSONObject("forging").getInteger("lv") + 1;
        JSONObject msg = getForgingMsg(bsKey, lv);

        //判断银两是否充足
        JSONObject roleMsg = startBef.manService.getMsgData(name, con);
        int tale = roleMsg.getInteger("tale") - msg.getInteger("tale");
        if (tale >= 0) {
            //保存银两
            JSONObject obj = new JSONObject();
            obj.put("tale", tale);
            startBef.manService.saveMsg(name, obj, con);
        } else {//银两不足
            return new result(200, 2);
        }
        //消耗宝石
        if (cutPlayerGoodsNumByKey(bsKey, 1, name, con) == 0) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //判断是否锻造成功
        if (strUtils.isHappend(0, 1000, msg.getFloat("p"))) {
            //成功则锻造等级++，当等级等于3，6，9，12，15时，镶嵌槽数++
            JSONObject forging = equip.getJSONObject("forging");
            forging.put("lv", lv);
            if (forging.getInteger("lv") == 3 || forging.getInteger("lv") == 6 ||
                    forging.getInteger("lv") == 9 || forging.getInteger("lv") == 12 ||
                    forging.getInteger("lv") == 15 || forging.getInteger("lv") == 18) {
                JSONObject inlay = equip.getJSONObject("inlay");
                //当镶嵌数小于5时刻印，再锻造道15时，孔不会超过5
                //未刻印的装备只能达到5，刻印过的装备可以达到6，升橙7，锻18 8
                int maxNum = 7;
                if (isKyEquip(equip)) {
                    maxNum = 8;
                }
                if (inlay.getInteger("num") < maxNum) {
                    inlay.put("num", inlay.getInteger("num") + 1);
                }
            }
            if (saveGoods(equip, name, con) == 1)
                return new result(200, 1);
            mybatisConfig.rollback(con);
            return new result(0);
        }
        if (isQing) {
            //轻锻则不损坏,等级-1
            JSONObject forging = equip.getJSONObject("forging");
            forging.put("lv", forging.getInteger("lv") - 1);
        } else {
            //失败则要将装备设置损毁
            equip.put("isBad", 1);
        }

        if (saveGoods(equip, name, con) == 1)
            return new result(200, 0);
        mybatisConfig.rollback(con);
        return new result(0);
    }

    /**
     * 橙装注魔
     */
    public result czZhuMo(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        String xhKey = j.getString("xhKey");
        if (strUtils.isNull(Id) || strUtils.isNull(xhKey)) return new result(0);
        JSONObject equip = getOne(Id, name, con);
        if (equip == null || equip.getInteger("isBad") == 1 ||
                !isEquip(equip.getString("key"))) return new result(0);
        //需要橙装\判断是否打了魔板
        if (!isGoldEquip(equip.getString("key")) ||
                !equip.containsKey("czmb")) return new result(0);
        JSONObject epMsg = equipData.get(equip.getString("key"));
        if (epMsg.getInteger("lv") < 91) return new result(0);
        JSONObject czmb = equip.getJSONObject("czmb");
        //已经满了
        if (czmb.getInteger("num") >= getMbMaxMoLi(czmb.getString("key"))) {
            return new result(0);
        }
        int n = 0;
        if (xhKey.equals("10000156")) n = 10;
        else if (xhKey.equals("10000157")) n = 20;
        else if (xhKey.equals("10000158")) n = 30;
        else return new result(0);
        if (cutPlayerGoodsNumByKey(xhKey, 1, name, con) == 0) return new result(0);
        //超过最大时处理
        czmb.put("num", czmb.getInteger("num") + n);
        if (czmb.getInteger("num") > getMbMaxMoLi(czmb.getString("key"))) {
            czmb.put("num", getMbMaxMoLi(czmb.getString("key")));
        }
        equip.put("num", 0);//避免数量++

        if (saveGoods(equip, name, con) == 1)
            return new result(200, 1);

        mybatisConfig.rollback(con);
        return new result(0);
    }

    /**
     * 橙装重铸（重铸后才有注魔字段）
     */
    public result zbChongzhu(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        String mbKey = j.getString("mbKey");
        if (strUtils.isNull(Id) || strUtils.isNull(mbKey)) return new result(0);
        JSONObject equip = getOne(Id, name, con);
        if (equip == null || equip.getInteger("isBad") == 1 ||
                !isEquip(equip.getString("key"))) return new result(0);
        //需要橙装\判断是否是魔板
        if (!isGoldEquip(equip.getString("key")) ||
                !isMoBan(mbKey)) return new result(0);
        JSONObject epMsg = equipData.get(equip.getString("key"));
        if (epMsg.getInteger("lv") < 91) return new result(0);
        //判断职业、部位是否一致
        if (!isSameJobAndPartByMb(equip.getString("key"), mbKey)) return new result(0);

        if (cutPlayerGoodsNumByKey(mbKey, 1, name, con) == 0) return new result(0);


        //每次重铸都会重置魔力
        JSONObject a = new JSONObject();
        a.put("key", mbKey);//模板的key
        a.put("num", 0);//当前魔力，上限由模板key决定，分3、6、10级
        equip.put("czmb", a);
        equip.put("num", 0);//避免数量++

        if (saveGoods(equip, name, con) == 1)
            return new result(200, 1);

        mybatisConfig.rollback(con);
        return new result(0);
    }

    /**
     * 装备升橙
     */
    public result upGold(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (strUtils.isNull(Id)) return new result(0);
        JSONObject equip = getOne(Id, name, con);
        if (equip == null || equip.getInteger("isBad") == 1 ||
                !isEquip(equip.getString("key"))) return new result(0);
        //90级以上且锻10以上的紫装，
        JSONObject epMsg = equipData.get(equip.getString("key"));
        JSONObject forging = equip.getJSONObject("forging");
        //todo:bug 升橙后品质还是2（保存装备那里没有将key设置为保存字段）
        if (epMsg.getInteger("quality") != 2 ||
                epMsg.getInteger("lv") < 91 ||
                forging.getInteger("lv") < 10 ||
                forging.getInteger("lv") > 15)
            return new result(0);

        String part = epMsg.getString("part");
        int xhNum = 0;
        if (part.equals("wq")) xhNum = 9;
        else if (part.equals("jb")) xhNum = 6;
        else if (part.equals("sz")) xhNum = 2;
        else if (part.equals("wb")) xhNum = 4;
        else if (part.equals("tb")) xhNum = 4;
        else if (part.equals("xb")) xhNum = 6;
        else if (part.equals("yb")) xhNum = 3;
        else if (part.equals("tuib")) xhNum = 3;
        else if (part.equals("jiaob")) xhNum = 2;
        long tale = 50000L * xhNum;
        if (tale == 0) return new result(0);
        //消耗银两
        if (startBef.manService.saveMoney(1, -tale, name, con) == 0) {
            return new result(0);
        }
        // 消耗一定的千年玄铁即可升为橙装，
        if (cutPlayerGoodsNumByKey("10000151", xhNum, name, con) == 0) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        // 升级橙装后锻造等级+1，孔数+1，装备将自动绑定。
        forging.put("lv", forging.getInteger("lv") + 1);

        //当锻15 未刻印则5+1（完成刻印则为7） 当锻15刻印则6+1
        //当锻10 3+1（4+1）无论刻印与否最多是5 升锻12则为6 升锻15则为7
        JSONObject inlay = equip.getJSONObject("inlay");
        inlay.put("num", inlay.getInteger("num") + 1);
        //刚好从11升12、14升15需要加孔
        if (forging.getInteger("lv") == 12 || forging.getInteger("lv") == 15) {
            //未刻印的装备只能达到6，刻印过的装备可以达到7
            int maxNum = 6;
            if (isKyEquip(equip)) {
                maxNum = 7;
            }
            if (inlay.getInteger("num") < maxNum) {
                inlay.put("num", inlay.getInteger("num") + 1);
            }
        }
        equip.put("isBind", 1);
        //品质改变，key改变
        String nextKey = getQualityUpEquipKey(epMsg);
        equip.put("key", nextKey);
        equip.put("num", 0);//避免数量++

        if (saveGoods(equip, name, con) == 1)
            return new result(200, nextKey);

        mybatisConfig.rollback(con);
        return new result(0);
    }

    /**
     * 合成锻造宝石
     */
    public result composeForgingBaoshi(JSONObject j,
                                       @paramsAnno(key = "user") user user,
                                       @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        //验证是否为宝石key
        if (key.equals("10000104") || !isDuanzaoBaoshi(key)) return new result(0);
        //获取需要消耗的key
        String xhKey = null;
        long tale = 0;
        int needNum = 0;
        float p = 0;
        if (key.equals("10000108")) {
            xhKey = "10000148";//圣锻需要消耗圣锻碎片
            tale = 2000;
            needNum = 20;
            p = 1;
        } else {
            xhKey = Integer.parseInt(key) - 1 + "";
            tale = (Integer.parseInt(key) - 10000105) * 1000L + 1000;
            needNum = 5;
            p = 0.1f;
        }
        if (startBef.manService.saveMoney(1, -tale, name, con) == 0) {
            return new result(0);
        }
        if (strUtils.isHappend(0, 100, p)) {
            if (cutPlayerGoodsNumByKey(xhKey, needNum, name, con) == 0) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            //合成成功
            JSONArray res = startBef.rewardService.createGoods(key, 1, 1, name, con);
            return new result(200, res);
        } else {
            //失败则消耗3个
            if (cutPlayerGoodsNumByKey(xhKey, 3, name, con) == 0) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            return new result(200, 0);
        }
    }

    /**
     * 合成镶嵌宝石
     * 传入key
     */
    public result composeInlayBaoshi(JSONObject j,
                                     @paramsAnno(key = "user") user user,
                                     @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        if (strUtils.isNull(key) ||
                !strUtils.isMatch(key, "1003([0-9]{4})")) return new result(0);
        //JSONObject baoshi = getOneByKey(key, name, con);
        JSONArray viewList = this.getPackView(name, con).getJSONArray("package");
        int bsSum = getGdNumInPackByKey(key, viewList);
        boolean isBind = outIsBind(key, 5, viewList);
        //判断数量是否足够
        if (bsSum < 5) {
            return new result(0);//数据异常
        }
        //由key解析其宝石等级
        //1003开头，由后4位来解析
        String sub = key.substring(4);
        int bsLv = Integer.parseInt(sub.charAt(2) + "") + 1;
        //暂时只开放到3级合成
        if (bsLv > 3) return new result(656);
        float k = 0f;
        String bsKey = "10030" + (bsLv < 10 ? ("0" + bsLv) : bsLv) + sub.charAt(3);
        if (bsLv == 1) {
            k = 0.9f;
        } else if (bsLv == 2) {
            k = 0.8f;
        } else if (bsLv == 3) {
            k = 0.7f;
        } else if (bsLv == 4) {
            k = 0.1f;
        } else if (bsLv == 5) {
            k = 0.05f;
        } else if (bsLv == 6) {
            k = 0.05f / 2f;
        } else if (bsLv == 7) {
            k = 0.05f / 2f / 2f;
        } else if (bsLv == 8) {
            k = 0.05f / 2f / 2f / 2f;
        } else if (bsLv == 9) {
            k = 0.05f / 2f / 2f / 2f / 2f;
        } else if (bsLv == 10) {
            k = 0.05f / 2f / 2f / 2f / 2f / 2f;
        } else {
            return new result(0);//数据异常
        }
        if (strUtils.isHappend(0, 1000, k)) {
            //合成成功，数量-5
            if (cutPlayerGoodsNumByKey(key, 5, name, con) == 0) {
                return new result(0);
            }
            //不论背包有没有该道具，都作为奖励发放
            JSONArray resList = rewardUtils.getGoodsReward(bsKey, 1, isBind ? 1 : 0, null);
            resList = startBef.rewardService.saveRewards(resList, name, con);
            //返回奖励
            return new result(200, resList);
        }
        //合成失败，数量-3
        if (cutPlayerGoodsNumByKey(key, 3, name, con) == 0) {
            return new result(0);
        }
        return new result(200, 0);
    }

    /**
     * 摘除镶嵌石
     */
    public result clearInlay(JSONObject data,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //装备Id
        String Id = data.getString("Id");
        int index = data.getInteger("index");
        JSONObject equip = getOne(Id, name, con);
        if (equip == null) return new result(0);
        //判断是否为装备\法宝
        if (!isEquip(equip.getString("key"))
                && !isFaBao(equip.getString("key"))) {
            return new result(0);
        }
        if (!equip.containsKey("inlay")) return new result(0);
        JSONObject inlay = equip.getJSONObject("inlay");
        JSONArray list = inlay.getJSONArray("list");
        list.remove(index);
        equip.put("num", 0);
        if (saveGoods(equip, name, con) == 0) {
            return new result(0);
        }
        return new result(200, 1);
    }

    /**
     * 对法宝镶嵌宝石的处理
     */
    public boolean inlayFb(JSONObject equip, JSONObject baoshi) {
        //根据当前的品质来判断是否需要增加镶嵌字段
        if (equip.containsKey("zhuling")) {
            JSONObject zhuling = equip.getJSONObject("zhuling");
            int quality = zhuling.getInteger("quality");
            int num = 0;
            if (quality == 2) num = 1;
            else if (quality == 3) num = 2;
            if (!equip.containsKey("inlay")) {
                JSONObject a = new JSONObject();
                a.put("num", num);
                a.put("list", new JSONArray());
                equip.put("inlay", a);
            }
            JSONObject inlay = equip.getJSONObject("inlay");
            inlay.put("num", num);
            //判断是否有位置
            if (inlay.getInteger("num") <= 0 ||
                    inlay.getJSONArray("list").size() >= inlay.getInteger("num")) {
                return false;
            }
            //将宝石放入
            equip.put("num", 0);
            JSONArray list = inlay.getJSONArray("list");
            JSONObject obj = new JSONObject();
            obj.put("key", baoshi.getString("key"));
            int max = baoshiUtils.getBaoshiAttr(baoshi.getString("key").substring(4));
            obj.put("num", max);//直接获得最大点数
            list.add(obj);
            return true;
        }
        return false;
    }

    /**
     * 镶嵌宝石
     */
    public result inlayBaoshi(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String baoshiId = j.getString("baoshiId");
        String equipId = j.getString("equipId");
        JSONObject baoshi = getOne(baoshiId, name, con);
        JSONObject equip = getOne(equipId, name, con);
        //是否为宝石
        if (baoshi == null || !isInlayBaoshi(baoshi.getString("key"))
                || baoshi.getInteger("num") <= 0) {
            return new result(0);
        }

        //对法宝的处理
        if (equip != null && isFaBao(equip.getString("key"))) {
            //消耗一个宝石
            if (cutPlayerGoodsNum(baoshiId, 1, name, con) == 0) {
                return new result(0);
            }
            if (inlayFb(equip, baoshi))
                return new result(200, saveGoods(equip, name, con));
            mybatisConfig.rollback(con);
            return new result(0);
        }

        //判断是否为装备
        if (equip == null || !isEquip(equip.getString("key"))) {
            return new result(0);
        }

        JSONObject inlay = equip.getJSONObject("inlay");
        //判断是否有位置
        if (inlay.getInteger("num") <= 0 ||
                inlay.getJSONArray("list").size() >= inlay.getInteger("num")) {
            return new result(0);
        }
        //判断装备部位是否适合镶嵌该宝石
        JSONObject ed = equipData.get(equip.getString("key"));
        if (!baoshiUtils.isAllowedInlay(baoshi.getString("key"),
                ed.getString("part"))) {
            return new result(0);
        }

        //todo 判断是否装备达到镶嵌的最低等级  装备等级获取不到
        //Integer bsLv=Integer.parseInt(baoshi.getString("key").charAt(2)+"");

        //消耗一个宝石
        if (cutPlayerGoodsNum(baoshiId, 1, name, con) == 0) {
            return new result(0);
        }
        //将宝石放入
        equip.put("num", 0);
        JSONArray list = inlay.getJSONArray("list");
        JSONObject obj = new JSONObject();
        obj.put("key", baoshi.getString("key"));
        obj.put("num", 0);
        list.add(obj);
        //保存装备
        return new result(200, saveGoods(equip, name, con));
    }

    /**
     * 装备开孔
     */
    public result kaikong(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String equipId = j.getString("equipId");
        JSONObject equip = getOne(equipId, name, con);
        if (equip == null) {
            return new result(0);//异常
        }
        //判断是否为装备
        if (!isEquip(equip.getString("key"))) {
            return new result(0);
        }
        JSONObject inlay = equip.getJSONObject("inlay");
        //+15 为5个孔 超过5个孔则不允许使用
        //不论是否为神装，开孔都不允许超过5
        if (inlay == null || inlay.getInteger("num") >= 5) {
            return new result(0);
        }
        int b = cutPlayerGoodsNumByKey("10000115", 1, name, con);
        if (b == 0) {
            return new result(0);
        }
        inlay.put("num", inlay.getInteger("num") + 1);
        equip.put("num", 0);
        return new result(200, saveGoods(equip, name, con));
    }


    /**
     * 获取当前正在练潜的装备
     */
    public result getPotentialEquip(@paramsAnno(key = "user") user user) {
        final String name = user.name;
        return new result(200, my.utils.staticCollection.potentialEquipMap.get(name));
    }

    /**
     * 取消练潜装备
     */
    public result canclePotentialEquip(@paramsAnno(key = "user") user user) {
        final String name = user.name;
        my.utils.staticCollection.potentialEquipMap.remove(name);
        return new result(200, 1);
    }

    /**
     * 设置练潜装备
     */
    public result setPotentialEquip(JSONObject j,
                                    @paramsAnno(key = "user") user user,
                                    @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONObject equip = getOne(j.getString("equipId"), name, con);
        if (equip == null || equipData.get(equip.getString("key")) == null) {
            return new result(0);
        }
        my.utils.staticCollection.potentialEquipMap.put(name, equip.getString("Id"));
        return new result(200, 1);
    }

    /**
     * 注入潜力
     */
    public result joinPotential(JSONObject j,
                                @paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int num = j.getInteger("num");
        String equipId = j.getString("equipId");
        //获取潜力符石
        JSONObject fs = getOneByKey("10000114", name, con);
        if (fs == null || (num <= 0 || num > 99) || fs.getInteger("num") < num) {
            return new result(0);//参数有误
        }
        if (cutPlayerGoodsNumByKey(fs.getString("key"), num, name, con) == 0) {
            return new result(0);
        }
        //将潜力注入
        JSONObject equip = getOne(equipId, name, con);
        equip.put("num", 0);
        //判断是否为装备
        if (!isEquip(equip.getString("key"))) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONObject potential = equip.getJSONObject("potential");
        potential.put("max", potential.getInteger("max") + num * 100);
        potential.put("num", potential.getInteger("num") + num * 100);
        if (potential.getInteger("num") > potential.getInteger("max")) {
            potential.put("num", potential.getInteger("max"));
        }
        return new result(200, saveGoods(equip, name, con));
    }

    /**
     * 开启装备刻印
     */
    public result kyEquip(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String equipId = j.getString("equipId");
        JSONObject equip = getOne(equipId, name, con);
        if (equip == null) {
            return new result(0);
        }
        //判断是否为装备
        if (!isEquip(equip.getString("key")) || isKyEquip(equip)) {
            return new result(0);
        }
        //消耗刻印宝石
        if (cutPlayerGoodsNumByKey("10000150", 1, name, con) == 0) {
            return new result(0);
        }
        //增加一个刻印字段，同时设置isBind=1
        equip.put("isBind", 1);
        equip.put("kybs", 1);
        //镶嵌数+1
        JSONObject inlay = equip.getJSONObject("inlay");
        //当镶嵌数小于5时刻印，再锻造道15时，孔不会超过5，在锻造处处理
        inlay.put("num", inlay.getInteger("num") + 1);
        equip.put("num", 0);//为了不影响数量，所以设置为0
        if (saveGoods(equip, name, con) == 1)
            return new result(200, 1);
        return new result(0);
    }

    /**
     * 判断装备是否使用过刻印宝石
     */
    private boolean isKyEquip(JSONObject equip) {
        if (equip.get("kybs") != null && equip.getInteger("kybs") == 1) return true;
        return false;
    }

    /**
     * 判断装备是否使用过绑定宝石
     */
    private boolean isBindEquip(JSONObject equip) {
        if (equip.get("bdbs") != null && equip.getInteger("bdbs") == 1) return true;
        return false;
    }

    /**
     * 装备解绑
     */
    public result unBindEquip(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String equipId = j.getString("equipId");
        JSONObject equip = getOne(equipId, name, con);
        if (equip == null) {
            return new result(0);
        }
        //非装备\非绑定的\对于刻印的不允许解绑\已经打过抗性的\
        if (!isEquip(equip.getString("key")) || !isBindEquip(equip) ||
                isKyEquip(equip) || equip.get("kxlv") != null) {
            return new result(0);
        }
        //紫品以上的\
        int quality = equipData.get(equip.getString("key")).getInteger("quality");
        if (quality > 2) return new result(0);

        //消耗5000银两
        if (startBef.manService.saveMoney(1, -5000L, name, con) == 0) {
            return new result(0);
        }
        equip.put("isBind", 0);
        equip.put("bdbs", 0);
        equip.put("num", 0);//为了不影响数量，所以设置为0
        if (saveGoods(equip, name, con) == 1)
            return new result(200, 1);
        return new result(0);
    }

    /**
     * 装备绑定
     */
    public result bindEquip(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String equipId = j.getString("equipId");
        JSONObject equip = getOne(equipId, name, con);
        if (equip == null) {
            return new result(0);
        }
        //判断是否为装备
        if (!isEquip(equip.getString("key")) || isBindEquip(equip)) {
            return new result(0);
        }
        //消耗绑定宝石
        if (cutPlayerGoodsNumByKey("10000149", 1, name, con) == 0) {
            return new result(0);
        }
        //增加一个绑定字段，同时设置isBind=1
        equip.put("isBind", 1);
        equip.put("bdbs", 1);
        equip.put("num", 0);//为了不影响数量，所以设置为0
        if (saveGoods(equip, name, con) == 1)
            return new result(200, 1);
        return new result(0);
    }

    /**
     * 修复装备
     */
    public result fixEquip(JSONObject j,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String equipId = j.getString("equipId");
        JSONObject equip = getOne(equipId, name, con);
        if (equip == null) {
            return new result(0);
        }
        //判断是否为装备
        if (!isEquip(equip.getString("key"))) {
            return new result(0);
        }
        int lv = equip.getJSONObject("forging").getInteger("lv");
        //获取所需数量
        int num = Double.valueOf(Math.pow(1.3, lv)).intValue();
        if (lv >= 15) {
            int[] nums = {42, 56, 74, 92, 110};
            num = nums[lv - 15];
        }
        //宝石消耗
        if (cutPlayerGoodsNumByKey("10000111", num, name, con) == 0) {
            return new result(0);
        }
        //装备isBad设置为0
        equip.put("isBad", 0);
        equip.put("num", 0);//为了不影响数量，所以设置为0
        if (saveGoods(equip, name, con) == 1)
            return new result(200, 1);
        return new result(0);
    }

    /**
     * 合成锻造宝石
     */
    public result composeBaoshi(JSONObject j,
                                @paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bsKey = j.getString("key");
        if (!bsKey.equals("1008") && !bsKey.equals("1009") &&
                !bsKey.equals("1010") && !bsKey.equals("1011") &&
                !bsKey.equals("1012")) {
            return new result(0);//数据异常
        }
        //合成一个高级的
        String key = null;
        float k = 0f;
        if (bsKey.equals("1008")) {
            key = "1009";
            k = 0.8f;
        } else if (bsKey.equals("1009")) {
            key = "1010";
            k = 0.5f;
        } else if (bsKey.equals("1010")) {
            k = 0.3f;
            key = "1011";
        }
        if (key == null) {
            return new result(0);//数据异常
        }
        //宝石消耗
        if (cutPlayerGoodsNumByKey(bsKey, 5, name, con) == 0) {
            return new result(0);//数据异常
        }
        if (!strUtils.isHappend(0, 100, k)) {
            //合成失败
            return new result(200, 0);
        }

        JSONArray resList = rewardUtils.getGoodsReward(key, 1, 1, null);
        resList = startBef.rewardService.saveRewards(resList, name, con);
        return new result(200, resList);
    }

    /**
     * 判断是否为锻造宝石
     */
    private boolean isDuanzaoBaoshi(String bsKey) {
        if (!bsKey.equals("10000104") && !bsKey.equals("10000105") &&
                !bsKey.equals("10000106") && !bsKey.equals("10000107") &&
                !bsKey.equals("10000108")) return false;
        return true;
    }

    /**
     * 锻造装备
     */
    public result forgingEquip(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bsKey = j.getString("bsKey");
        String equipId = j.getString("equipId");
        JSONObject equip = getOne(equipId, name, con);
        String equipKey = equip.getString("key");
        //判断是否为装备
        if (equip == null || !isEquip(equipKey)) {
            return new result(0);
        }
        //只要求锻造等级<=15
        //JSONObject eqMsg = equipData.get(equipKey);
        //if (eqMsg.getInteger("quality") > 2) return new result(0);
        //不存在该物品或已经损坏
        if ((!isDuanzaoBaoshi(bsKey))
                || equip.getInteger("isBad") == 1 ||
                equip.getJSONObject("forging").getInteger("lv") >= 15) {
            return new result(200, 2);
        }

        equip.put("num", 0);//为了不影响数量，所以设置为0

        int lv = equip.getJSONObject("forging").getInteger("lv") + 1;
        JSONObject msg = getForgingMsg(bsKey, lv);

        //判断银两是否充足
        JSONObject roleMsg = startBef.manService.getMsgData(name, con);
        int tale = roleMsg.getInteger("tale") - msg.getInteger("tale");
        if (tale >= 0) {
            //保存银两
            JSONObject obj = new JSONObject();
            obj.put("tale", tale);
            startBef.manService.saveMsg(name, obj, con);
        } else {//银两不足
            return new result(200, 2);
        }
        //消耗锻造宝石
        if (cutPlayerGoodsNumByKey(bsKey, 1, name, con) == 0) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //判断是否锻造成功
        if (strUtils.isHappend(0, 1000, msg.getFloat("p"))) {
            //成功则锻造等级++，当等级等于3，6，9，12，15时，镶嵌槽数++
            JSONObject forging = equip.getJSONObject("forging");
            forging.put("lv", lv);
            if (forging.getInteger("lv") == 3 || forging.getInteger("lv") == 6 ||
                    forging.getInteger("lv") == 9 || forging.getInteger("lv") == 12 ||
                    forging.getInteger("lv") == 15) {
                JSONObject inlay = equip.getJSONObject("inlay");
                //当镶嵌数小于5时刻印，再锻造道15时，孔不会超过5
                //未刻印的装备只能达到5，刻印过的装备可以达到6
                int maxNum = 5;
                if (isKyEquip(equip)) {
                    maxNum = 6;
                }
                if (inlay.getInteger("num") < maxNum) {
                    inlay.put("num", inlay.getInteger("num") + 1);
                }

            }
            if (saveGoods(equip, name, con) == 1)
                return new result(200, 1);
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //失败则要将装备设置损毁
        equip.put("isBad", 1);
        if (saveGoods(equip, name, con) == 1)
            return new result(200, 0);
        mybatisConfig.rollback(con);
        return new result(0);
    }


    /**
     * 由宝石key获取成功率，耗费银两等信息
     * forgingLv 为要锻造到的等级
     */
    private JSONObject getForgingMsg(String baoshiKey, Integer forgingLv) {
        float k = 0f;
        boolean isQing = false;
        boolean isJin = false;
        if (baoshiKey.equals("10000104")) k = 0.1f;
        else if (baoshiKey.equals("10000105")) k = 0.2f;
        else if (baoshiKey.equals("10000106")) k = 0.3f;
        else if (baoshiKey.equals("10000107")) k = 0.4f;
        else if (baoshiKey.equals("10000108")) k = 1f;
            //橙装
        else if (baoshiKey.equals("10000159")) {
            k = 0.5f;
            isJin = true;
        } else if (baoshiKey.equals("10000160")) {
            k = 0.5f;
            isQing = true;
        } else k = 0f;
        Double p = 0d;
        if (k == 1f) {
            p = 1d;
        } else {
            p = Math.pow(0.9, forgingLv) * (1 + k) + 0.11f;
        }
        if (isJin) {
            p = 0.41d;
        }
        if (isQing) {
            p = 0.8d - 0.1d * (forgingLv - 15);
        }
        if (p > 1) p = 1d;
        int tale = forgingLv * 1000;
        JSONObject j = new JSONObject();
        j.put("tale", tale);
        j.put("p", p.floatValue());
        return j;
    }

    /**
     * 神装锻造几率
     */
    private JSONObject getShenForgingMsg(String baoshiKey, Integer forgingLv) {
        float k = 0f;
        if (baoshiKey.equals("1008")) k = 0.1f;
        else if (baoshiKey.equals("1009")) k = 0.2f;
        else if (baoshiKey.equals("1010")) k = 0.3f;
        else if (baoshiKey.equals("1011")) k = 0.4f;
        else if (baoshiKey.equals("1012")) k = 1f;
        else k = 0f;
        Double p = 0d;
        if (k == 1f) {
            p = 1d;
        } else {
            p = Math.pow(0.3, forgingLv) * (1 + k);
        }
        if (p > 1) p = 1d;
        Integer tale = forgingLv * 1000 * 2;
        JSONObject j = new JSONObject();
        j.put("tale", tale);
        j.put("p", p.floatValue());
        return j;
    }

    /**
     * 道具转装备
     */
    public result goodsToEquip(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        //从物品中找到此装备
        JSONObject one = getOne(Id, name, con);
        JSONObject msg = null;
        //判断key的范围
        if (one == null || (msg = equipData.get(one.getString("key"))) == null) {
            return new result(0);
        }
        /*String part = baseData.getString("part");
        JSONObject msg = equipData.get(one.getString("key"));
        if (msg == null || !part.equals(msg.getString("part"))) {
            return new result(0);
        }*/
        JSONObject role = startBef.manService.getRole(name, con);
        int lv = role.getInteger("lever");
        if (msg.getInteger("lv") > lv) {
            return new result(200, "-1");
        }
        String model = roleUtils.getModel(role);
        if (!msg.getString("job").equals("*")
                && (model == null || !msg.getString("job").contains(model.substring(0, 2)))) {
            return new result(200, "-1");
        }
        String part = msg.getString("part");
        //long a0 = new Date().getTime();
        //判断玩家是否有装备在该部位，有则先卸下
        String eqId = equipToGoods(part, name, con);
        //System.err.println("耗时:" + (new Date().getTime() - a0));
        //将物品转为装备,保存人物装备数据
        JSONObject equip = new JSONObject();
        equip.put(part, one);
        if (startBef.manService.saveEquip(name, equip, con) == 1) {
            //物品数量--
            cutPlayerGoodsNum(Id, 1, name, con);
            //判断是否为补给包，补给包则需要更新人物血量等数据
            addStatus(name, part, con);
            //刷新橙装特效
            if (!part.equals("bjb") && !part.equals("fb")
                    && !part.equals("hf") && !part.equals("gf")) {
                user.msg.put("goldType", startBef.manService.getGoldType(name, con));
            }
        }
        //重新计算战力
        startBef.orderService.countZlOrder(name);
        return new result(200, eqId);
    }

    /**
     * 补给状态
     */
    public Integer addStatus(String name, String part, DefaultSqlSession con) {
        //不是补给包就不用计算
        if (!part.equals("bjb")) {
            return 0;
        }
        //获取人物装备信息
        JSONObject equipData = startBef.manService.getEquipDataView(name, con);
        //未装备补给包
        if (equipData == null || equipData.get("bjb") == null || equipData.getString("bjb").equals(""))
            return 0;
        //装备了补给包的话就补血补篮
        JSONObject bjb = equipData.getJSONObject("bjb");
        JSONObject capacity = bjb.getJSONObject("capacity");
        //容量不足
        if (capacity.getInteger("num") <= 0) {
            return 0;
        }
        //获取人物装备、技能叠加后的属性
        JSONObject base = startBef.manService.getFightAttr(name, con).getJSONObject("prop");
        JSONObject prop = countCapacity(base, capacity);
        //保存角色属性
        startBef.manService.saveProp(name, prop, con);
        JSONObject petAttr = startBef.petService.getFightAttr(name, con);
        //存在出战宠物时
        if (petAttr != null) {
            base = petAttr.getJSONObject("prop");
            prop = countCapacity(base, capacity);
            startBef.petService.updatePetXueByIsFight(prop, name, con);
        }
        //保存容量
        JSONObject equip = new JSONObject();
        equip.put("bjb", bjb);
        return startBef.manService.saveEquip(name, equip, con);
    }

    /**
     * 更新补给包
     * manXue补满最大血量所需的差值
     */
    public void updateBJB(String name, float manXue, float manLan, float petXue, float petLan, DefaultSqlSession con) {
        //这里需要验证补给包容量是否充足
        JSONObject equipData = startBef.manService.getEquipDataView(name, con);
        //获取人物装备、技能叠加后的属性
        JSONObject base = startBef.manService.getFightAttr(name, con).getJSONObject("prop");
        JSONObject petAttr = startBef.petService.getFightAttr(name, con);
        //未装备补给包
        if (equipData == null || equipData.get("bjb") == null || equipData.getString("bjb").equals("")) {
            JSONObject res = cutPropHPOrMP(base, petAttr, manXue, manLan, petXue, petLan, name, con);
            ChannelSupervise.noticeClientByName(res, name, "848");
            return;
        }
        //装备了补给包的话就补血补篮
        JSONObject bjb = equipData.getJSONObject("bjb");
        JSONObject capacity = bjb.getJSONObject("capacity");
        //容量不足
        if (capacity.getInteger("num") <= 0) {
            //直接扣除hp、mp
            JSONObject res = cutPropHPOrMP(base, petAttr, manXue, manLan, petXue, petLan, name, con);
            ChannelSupervise.noticeClientByName(res, name, "848");
            return;
        }
        //还有容量
        base.put("xue", base.getFloat("xue") - manXue);
        base.put("lan", base.getFloat("lan") - manLan);
        JSONObject prop = countCapacity(base, capacity);
        //保存角色属性
        startBef.manService.saveProp(name, prop, con);

        JSONObject res = new JSONObject();
        res.put("mxue", prop.getInteger("xue"));
        res.put("mlan", prop.getInteger("lan"));
        //存在出战宠物时
        if (petAttr != null) {
            base = petAttr.getJSONObject("prop");
            base.put("xue", base.getFloat("xue") - petXue);
            base.put("lan", base.getFloat("lan") - petLan);
            prop = countCapacity(base, capacity);
            startBef.petService.updatePetXueByIsFight(prop, name, con);
            res.put("pxue", prop.getInteger("xue"));
            res.put("plan", prop.getInteger("lan"));
        }
        //保存容量
        JSONObject equip = new JSONObject();
        equip.put("bjb", bjb);
        startBef.manService.saveEquip(name, equip, con);
        res.put("capacity", capacity.getInteger("num"));
        ChannelSupervise.noticeClientByName(res, name, "848");
    }

    /**
     * 直接扣除血量
     * 返回最终hp、mp
     * manXue是与最大血量的距离
     */
    private JSONObject cutPropHPOrMP(JSONObject base, JSONObject petAttr, float manXue, float manLan, float petXue, float petLan, String name, DefaultSqlSession con) {
        JSONObject res = new JSONObject();
        //用当前血量-需要补的血量=剩余血量，外部经过补给包填补后需要补的血量就为负值
        //直接扣除hp、mp
        JSONObject prop = startBef.manService.getProp(name, con);
        prop.put("xue", prop.getFloat("xue") - manXue);
        if (prop.getFloat("xue") > base.getFloat("max_xue")) {
            prop.put("xue", base.getFloat("max_xue"));
        } else if (prop.getFloat("xue") < 0) {
            prop.put("xue", 1);
        }
        prop.put("lan", prop.getFloat("lan") - manLan);
        if (prop.getFloat("lan") > base.getFloat("max_lan")) {
            prop.put("lan", base.getFloat("max_lan"));
        } else if (prop.getFloat("lan") < 0) {
            prop.put("lan", 1);
        }
        startBef.manService.saveProp(name, prop, con);
        res.put("mxue", prop.getInteger("xue"));
        res.put("mlan", prop.getInteger("lan"));
        //宠物
        if (petAttr != null) {
            JSONObject pet = (JSONObject) startBef.petService.getIsFightPet(name, con);
            JSONObject petProp = pet.getJSONObject("attr").getJSONObject("prop");
            base = petAttr.getJSONObject("prop");
            petProp.put("xue", petProp.getFloat("xue") - petXue);
            if (petProp.getFloat("xue") > base.getFloat("max_xue")) {
                petProp.put("xue", base.getFloat("max_xue"));
            } else if (petProp.getFloat("xue") < 0) {
                petProp.put("xue", 1);
            }
            petProp.put("lan", petProp.getFloat("lan") - petLan);
            if (petProp.getFloat("lan") > base.getFloat("max_lan")) {
                petProp.put("lan", petProp.getFloat("max_lan"));
            } else if (prop.getFloat("lan") < 0) {
                petProp.put("lan", 1);
            }
            JSONObject petA = new JSONObject();
            petA.put("xue", petProp.get("xue"));
            petA.put("lan", petProp.get("lan"));
            startBef.petService.updatePetXueByIsFight(petA, name, con);

            res.put("pxue", petProp.getInteger("xue"));
            res.put("plan", petProp.getInteger("lan"));
        }
        return res;
    }

    /**
     * 计算容量
     */
    public JSONObject countCapacity(JSONObject base, JSONObject capacity) {
        JSONObject prop = new JSONObject();
        prop.put("xue", base.get("xue"));
        prop.put("lan", base.get("lan"));
        int cut = base.getInteger("max_xue") - base.getInteger("xue");
        if (cut > 0) {
            //减去容量
            if (capacity.getInteger("num") >= cut) {
                //人物血量补满
                prop.put("xue", base.getInteger("max_xue"));
                capacity.put("num", capacity.getInteger("num") - cut);
            } else {
                //人物血量加上剩余容量
                prop.put("xue", base.getInteger("xue") + capacity.getInteger("num"));
                capacity.put("num", 0);
            }
        }
        cut = base.getInteger("max_lan") - base.getInteger("lan");
        if (cut > 0) {
            //减去容量
            if (capacity.getInteger("num") >= cut) {
                //人物血量补满
                prop.put("lan", base.getInteger("max_lan"));
                capacity.put("num", capacity.getInteger("num") - cut);
            } else {
                //人物血量加上剩余容量
                prop.put("lan", base.getInteger("lan") + capacity.getInteger("num"));
                capacity.put("num", 0);
            }
        }
        return prop;
    }

    /**
     * 装备转道具
     */
    public result equipToGoods(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String part = j.getString("part");
        String id = equipToGoods(part, name, con);
        if (id != null) {
            //刷新橙装特效
            user.msg.put("goldType", startBef.manService.getGoldType(name, con));
        } else {
            return new result(0);
        }
        //重新计算战力
        startBef.orderService.countZlOrder(name);
        return new result(200, id);
    }

    private String equipToGoods(String part, String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        JSONObject equip = startBef.manService.getEquipData(name, con);
        //未装备
        if (equip == null || part == null || equip.getString(part) == null) {
            loggerUtils.error("[参数缺失]name:" + name + " equip:" + equip + " part:" + part, this.getClass());
        }
        if (equip.getString(part) == null || equip.getString(part).equals("")) {
            return null;
        }
        //将装备放入背包
        JSONObject partEquip = equip.getJSONObject(part);
        //替换id
        partEquip.put("Id", strUtils.getId());
        //保存
        this.saveGoods(partEquip, name, con);
        //保存当前部位
        equip.put(part, "");
        jsonMapper.updateEquip(JSON.toJSONString(equip), name);
        //todo 重新人物计算属性 xue,lan
        //返回道具id
        return partEquip.getString("Id");
    }


    /**
     * 判断背包是否有足够空间
     */
    public boolean isEnough(String name, DefaultSqlSession con) {
        JSONObject msg = getGoodsMsg(name, con);
        int bb = 0;
        int ck = 0;
        int sumBB = msg.getInteger("bbn");
        int sumCK = msg.getInteger("ckn");
        JSONArray list = msg.getJSONArray("package");
        for (Object o : list) {
            JSONObject l = (JSONObject) o;
            if (l.getInteger("pos") == 0) {
                bb++;
            } else {
                ck++;
            }
        }
        //最多100 背包60、仓库40
        if (bb >= sumBB || (bb + ck) >= (sumCK + sumBB)) {
            return false;
        }
        return true;
    }

    /**
     * 丢弃物品
     */
    public result giveUpGoods(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray list = getGoods(name, con);
        for (Object o : list) {
            JSONObject l = (JSONObject) o;
            if (l.getString("Id").equals(j.getString("Id"))) {
                list.remove(o);
                return new result(200, savePackage(list, name, con));
            }
        }
        return new result(0);
    }

    /**
     * 取出、放入仓库
     */
    public result opWarehouse(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray list = getGoods(name, con);
        for (Object o : list) {
            JSONObject l = (JSONObject) o;
            if (l.getString("Id").equals(j.getString("Id"))) {
                if (l.getInteger("pos") == 1) {
                    l.put("pos", 0);
                } else {
                    l.put("pos", 1);
                }
                return new result(200, savePackage(list, name, con));
            }
        }
        return new result(0);
    }


    /**
     * 创建道具
     * good至少包含 {key,num,isBind}
     */
    public JSONObject createGoods(JSONObject goods, String name, DefaultSqlSession con) {
        //需要检测物品是否带有绑定字段
        if (goods.get("key") == null || goods.get("num") == null ||
                goods.get("isBind") == null) {
            loggerUtils.error("createGoods:道具缺失字段:" + goods.get("key") +
                    "/" + goods.get("num") + "/" + goods.get("isBind"), this.getClass());
            return null;
        }
        //创建前判断物品是否超出上限 背包140+仓库20 共60
        JSONObject msg = this.getGoodsMsg(name, con);
        JSONArray list = msg.getJSONArray("package");
        int i = countPos0(list);
        int bbSum = msg.getInteger("bbn");
        int ckSum = msg.getInteger("ckn");
        if (list.size() >= (bbSum + ckSum) || i >= bbSum) {
            System.err.println(name + "/背包数量超出");
            return null;
        }
        goods.put("pos", 0);
        goods.put("isBad", 0);
        goods.put("Id", strUtils.getId());
        //是否允许叠加
        boolean isAdd = true;
        //判断是否为一件装备
        JSONObject obj = equipData.get(goods.getString("key"));
        if (obj != null) {
            isAdd = false;
            //生成随机属性
            equipData.putRandomAttr(goods);
            //对于补给包要记录容量
            equipData.putCapacity(goods);
            //初始化锻造属性
            equipData.putForging(goods);
            //初始化法宝属性
            equipData.putFaBaoAttr(goods);
            //护符
            equipData.putHuFuAttr(goods);
            //功法
            equipData.putGongfaAttr(goods);
            //初始化神装技能 3个槽位，随机生成一个技能
            equipData.putSzSkill(goods);
        }
        //刻印石
        if (equipData.isKeyin(goods.getString("key"))) {
            isAdd = false;
            equipData.putKyAttr(goods);
        }
        //宠物装备
        if (equipData.isPetEquip(goods.getString("key"))) {
            isAdd = false;
            //设置过期时间
            equipData.putEndTime(goods);
        }
        if (isAdd) {
            //允许叠加时需要判断是否已经有重复的key
            for (Object l : list) {
                JSONObject ol = (JSONObject) l;
                //这些都是非装备类型的道具，由key跟isBind获取id
                if (ol.getString("key").equals(goods.getString("key")) &&
                        ol.getInteger("isBind") == goods.getInteger("isBind")) {
                    //存在相同的时不需要再生成id
                    goods.put("Id", ol.getString("Id"));
                    break;
                }
            }
        }
        if (saveGoods(goods, name, con) == 1)
            return goods;
        return null;
    }

    /**
     * 统计在背包的数量
     */
    private int countPos0(JSONArray list) {
        int i = 0;
        for (Object o : list) {
            if (((JSONObject) o).getInteger("pos") == 0) {
                i++;
            }
        }
        return i;
    }


    /**
     * 使用道具
     */
    public result userGoods(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        final String Id = j.getString("Id");
        Integer num = j.getInteger("num");
        if (strUtils.isNull(Id) || num == null || num <= 0) {
            return new result(0);
        }
        JSONObject one = getOne(Id, name, con);
        //是否允许使用
        if (one == null) {
            return new result(0);
        }
        String k = one.getString("key");
        //是否能被使用
        if (!isAllowedUse(k)) {
            return new result(0);
        }
        //是否允许超过数量1
        if (!isAllowedUseMulNum(k)) {
            num = 1;
        }
        //令牌类型需要判断宠物数量
        if (isPetZhaoHuanGoods(k)) {
            if (startBef.petService.isOverLimitNum(name, con)) {
                return new result(0);
            }
        }
        if (cutPlayerGoodsNum(Id, num, name, con) == 0) {
            return new result(0);
        }

        return new result(200, useGoodsHandle.getOne().triggerUser(k, num, name, con));
    }


    /**
     * 减少道具数量（只会消耗id相同的道具）
     * 传入正数是减少
     */
    public int cutPlayerGoodsNum(String Id, int num, String name, DefaultSqlSession con) {
        JSONObject goods = new JSONObject();
        goods.put("Id", Id);
        goods.put("num", -num);
        return saveGoods(goods, name, con);
    }

    /**
     * 使用这个会先消耗绑定的道具，然后再消耗非绑定的道具
     */
    public int cutPlayerGoodsNumByKey(String key, int num, String name, DefaultSqlSession con) {
        JSONObject goods = new JSONObject();
        goods.put("key", key);
        goods.put("num", -num);
        return saveGoods(goods, name, con);
    }

    /*public Integer removeGoodsList(JSONArray list, String name, DefaultSqlSession con) {
        JSONArray js = this.getGoods(name, con);
        int sum = 0;
        for (Object l : list) {
            JSONObject j0 = (JSONObject) l;
            for (Object o : js) {
                JSONObject j1 = (JSONObject) o;
                if (j1.getString("key").equals(j0.getString("key"))) {
                    j1.put("num", j1.getInteger("num") + j0.getInteger("num"));
                    if (j1.getInteger("num") < 0) {
                        return 0;
                    }
                    if (j1.getInteger("num") == 0) {
                        js.remove(o);
                    }
                    sum++;
                    break;
                }
            }
        }
        //当需要减数量的都已经减过了
        if (sum == list.size()) {
            return savePackage(js, name, con);
        }
        return 0;
    }
*/

    /**
     * 将某个物品保存到背包
     * 一个新道具会在此之前找到一个id
     */
    public int saveGoods(JSONObject goods, String name, DefaultSqlSession con) {
        //绑定的物品需要跟不绑定的id分开
        //消耗物品时先消耗绑定的，不够时再消耗非绑定的（注意绑定的id跟非绑定的id不同）
        JSONArray js = this.getGoods(name, con);
        //消耗物品时只有key/Id跟num，其他情况则多包含isBind
        //先找相同key，有相同key的就对比isBind，key一样并且isBind一致就可以叠加

        //1.先判断是否为消耗道具
        if (goods.getInteger("num") < 0) {
            int need = goods.getInteger("num");
            //fixme 注意：装备类是单件的，用id来找，如果用key找就会导致删的不是同一件
            //装备类型道具不允许叠加
            boolean isEquipType = false;
            if (goods.get("Id") != null) {
                for (int i = 0; i < js.size(); i++) {
                    JSONObject j = (JSONObject) js.get(i);
                    String key = j.getString("key");
                    if ((j.getString("Id").equals(goods.getString("Id")))) {
                        if (equipData.get(key) != null ||
                                equipData.isKeyin(key) ||
                                equipData.isPetEquip(key)) {
                            isEquipType = true;
                        }
                        //假如删除的不是一件装备，传入的是id，而后面的判断，就会导致有问题
                        if (goods.get("key") == null) {
                            goods.put("key", j.get("key"));
                        }
                        break;
                    }
                }
            }
            //对于装备、刻印需要id，其他则只需要key
            if (isEquipType) {
                for (int i = 0; i < js.size(); i++) {
                    JSONObject j = (JSONObject) js.get(i);
                    if (j.getString("Id").equals(goods.getString("Id"))) {
                        j.put("num", j.getInteger("num") + goods.getInteger("num"));
                        if (j.getInteger("num") < 0) {
                            loggerUtils.error("装备类型的道具数量不够", packageService.class);
                            return 0;
                        } else if (j.getInteger("num") == 0) {
                            js.remove(i);
                        }
                        break;
                    }
                }
                return savePackage(js, name, con);
            }
            //非装备类型的处理（分有id和有key）
            //对于有id的只会消耗该id的道具，对于有key的先消耗绑定后消耗未绑定的道具
            if (goods.get("Id") != null) {
                for (int i = 0; i < js.size(); i++) {
                    JSONObject j = (JSONObject) js.get(i);
                    String Id = j.getString("Id");
                    int num = j.getInteger("num");
                    if (Id.equals(goods.getString("Id"))) {
                        //当num<0说明id对应的不够，当num=0说明刚好消耗完绑定的
                        num = num + goods.getInteger("num");
                        j.put("num", num);
                        if (num <= 0) {
                            //消耗完毕或者不够时就要移除
                            js.remove(i);
                            need = num;
                        } else {
                            //足够消耗
                            need = 0;
                        }
                        break;
                    }
                }
            } else {
                //先消耗绑定的
                for (int i = 0; i < js.size(); i++) {
                    JSONObject j = (JSONObject) js.get(i);
                    int isBind = j.getInteger("isBind");
                    String key = j.getString("key");
                    int num = j.getInteger("num");
                    if (key.equals(goods.getString("key")) && isBind == 1) {
                        //当num<0说明绑定的不够，仍需要消耗非绑定的。当num=0说明刚好消耗完绑定的
                        num = num + goods.getInteger("num");
                        j.put("num", num);
                        if (num <= 0) {
                            //消耗完毕或者不够时就要移除
                            js.remove(i);
                            need = num;
                        } else {
                            //足够消耗
                            need = 0;
                        }
                        break;
                    }
                }
                //再消耗不绑定的
                if (need < 0) {
                    for (int i = 0; i < js.size(); i++) {
                        JSONObject j = (JSONObject) js.get(i);
                        int isBind = j.getInteger("isBind");
                        String key = j.getString("key");
                        int num = j.getInteger("num");
                        if (key.equals(goods.getString("key")) && isBind == 0) {
                            num = num + need;
                            j.put("num", num);
                            if (num <= 0) {
                                //消耗完毕或者不够时就要移除
                                js.remove(i);
                                need = num;
                            } else {
                                //足够消耗
                                need = 0;
                            }
                            break;
                        }
                    }
                }
            }

            if (need == 0) {
                //能被消耗
                return savePackage(js, name, con);
            } else {
                //不足数量
                //loggerUtils.error("没有足够数量", packageService.class);
                //throw new RuntimeException("没有足够数量");
                System.err.println("没有足够数量=" + name);
                return 0;
            }
        }

        //2.其他转移、创建的情况
        if (goods.get("Id") == null || goods.get("isBind") == null) {
            System.err.println("没有Id、isBind属性");
            return 0;
        }
        //几种情况：
        // 1.创建（背包内有的就会沿用【由key跟isBind选取，这样就保证isBind会有两个不同的id】）
        // 2.查找后修改部分属性（id跟背包道具的一致）
        boolean b = false;
        for (int i = 0; i < js.size(); i++) {
            JSONObject j = (JSONObject) js.get(i);
            //因绑定和非绑定的id传入之前已经区分开了，所以直接用id判断
            if (j.getString("Id").equals(goods.getString("Id"))) {
                //注意：修改一下属性时，最后需要设置数量为0，否则会导致叠加
                j.put("num", j.getInteger("num") + goods.getInteger("num"));
                //当获得新道具时可能把原先存在仓库的道具给置入背包
                if (goods.get("pos") != null && goods.getInteger("num") == 0) {
                    //只有数量为0，纯属仓库背包相互转移时才按道具的pos属性，否则不变
                    j.put("pos", goods.get("pos"));
                }
                //保存损毁
                if (goods.getInteger("isBad") != null &&
                        j.getInteger("isBad") != goods.getInteger("isBad")) {
                    j.put("isBad", goods.get("isBad"));
                }
                if (goods.get("forging") != null) {
                    j.put("forging", goods.get("forging"));
                }
                if (goods.get("inlay") != null) {
                    j.put("inlay", goods.get("inlay"));
                }
                if (goods.get("potential") != null) {
                    j.put("potential", goods.get("potential"));
                }
                if (goods.get("randomAttr") != null) {
                    j.put("randomAttr", goods.get("randomAttr"));
                }
                if (goods.get("isBind") != null) {
                    j.put("isBind", goods.get("isBind"));
                }
                if (goods.get("bdbs") != null) {
                    j.put("bdbs", goods.get("bdbs"));
                }
                if (goods.get("kybs") != null) {
                    j.put("kybs", goods.get("kybs"));
                }
                if (goods.get("key") != null) {//升橙的时候需要改变key
                    j.put("key", goods.get("key"));
                }
                if (goods.get("kxlv") != null) {
                    j.put("kxlv", goods.get("kxlv"));
                }
                if (goods.get("czmb") != null) {
                    j.put("czmb", goods.get("czmb"));
                }
                if (goods.get("xqbs") != null) {
                    j.put("xqbs", goods.get("xqbs"));
                }
                b = true;
                break;
            }
        }
        if (!b) {
            //不存在时就直接添加
            js.add(goods);
        }
        return savePackage(js, name, con);
    }

    /**
     * 验证数据必要字段
     */
    private boolean isSureFormat(JSONObject goods) {
        if (goods.getString("key") != null && goods.getString("pos") != null) {
            return true;
        }
        return false;
    }

    /**
     * 由id获取指定道具
     */
    public JSONObject getOne(String Id, String name, DefaultSqlSession con) {
        JSONArray js = this.getPackView(name, con).getJSONArray("package");
        for (Object o : js) {
            JSONObject j = (JSONObject) o;
            if (j.getString("Id").equals(Id)) {
                return j;
            }
        }
        return null;
    }

    /**
     * 由key获取道具
     */
    public JSONObject getOneByKey(String key, String name, DefaultSqlSession con) {
        JSONArray js = this.getPackView(name, con).getJSONArray("package");
        for (Object o : js) {
            JSONObject j = (JSONObject) o;
            if (j.getString("key").equals(key)) {
                return j;
            }
        }
        return null;
    }

    /**
     * 获取道具在背包中的数量
     */
    public int getGdNumInPackByKey(String key, JSONArray js) {
        int sum = 0;
        for (Object o : js) {
            JSONObject j = (JSONObject) o;
            if (j.getString("key").equals(key) && j.getInteger("pos") == 0) {
                sum += j.getInteger("num");
            }
        }
        return sum;
    }

    /**
     * 判断合成后输出的道具是否为绑定
     */
    public boolean outIsBind(String key, int needNum, JSONArray js) {
        int aNum = 0;
        int bNum = 0;
        for (Object o : js) {
            JSONObject j = (JSONObject) o;
            if (j.getString("key").equals(key)
                    && j.getInteger("pos") == 0) {
                if (j.getInteger("isBind") == 0) aNum += j.getInteger("num");
                else if (j.getInteger("isBind") == 1) bNum += j.getInteger("num");
            }
        }
        //当绑定的数量小于一次合成需要消耗的数量时，必然绑定
        if (bNum != 0 && bNum < needNum) return true;
        return false;
    }


    /**
     * 保存背包
     */
    public Integer savePackage(JSONArray goods, String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.updatePackageByName(JSON.toJSONString(goods), null, null, null, name) ? 1 : 0;
    }

    /**
     * 获取玩家背包
     */
    public JSONArray getGoods(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.selectPackage(name).get(0).getJSONArray("package");
    }

    /**
     * 背包视图
     */
    public JSONObject getPackView(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.selectPackageView(name).get(0);
    }

    public JSONObject getGoodsBBNAndCKN(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.selectPackageBC(name).get(0);
    }

    public JSONObject getGoodsMsg(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        JSONObject n = jsonMapper.selectPackage(name).get(0);
        JSONObject res = new JSONObject();
        res.put("bbn", n.getInteger("bbn"));
        res.put("ckn", n.getInteger("ckn"));
        res.put("tale", n.getLong("tale"));
        res.put("package", n.getJSONArray("package"));
        return res;
    }

    /**
     * 获取当前道具在背包中的数目
     */
    public int getNowBbn(JSONArray list) {
        int num = 0;
        for (int i = 0; i < list.size(); i++) {
            JSONObject a = list.getJSONObject(i);
            if (a.getInteger("pos") == 0) num++;
        }
        return num;
    }
}
