package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.jsonMapper;
import my.data.equipData;
import my.data.monsterData;
import my.data.petData;
import my.data.skillData;
import my.db.mybatisConfig;
import my.fightUtils.fightUtils;
import my.gameUtils.rewardUtils;
import my.gameUtils.roleUtils;
import my.gameUtils.skillUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.skill;
import my.model.user;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * 宠物服务
 */
public class petService {


    /**
     * 炼化
     */
    public result lianhuaPet(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (Id == null) return new result(0);
        JSONObject pet = null;
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(Id)) {
                pet = obj;
                break;
            }
        }
        if (pet == null) return new result(0);
        int lv = pet.getInteger("lever");
        if (lv < 40) return new result(0);
        //获得一定的宠物口粮
        int num = 1;
        String key = null;
        if (lv < 50) {
            num = 1;
            key = "10000030";
        } else if (lv < 60) {
            num = 2;
            key = "10000030";
        } else if (lv < 70) {
            num = 1;
            key = "10000031";
        } else if (lv < 80) {
            num = 2;
            key = "10000031";
        } else if (lv < 90) {
            num = 1;
            key = "10000032";
        } else if (lv <= 100) {
            num = 2;
            key = "10000032";
        }
        JSONArray res = new JSONArray();
        rewardUtils.getGoodsReward(key, num, 0, res);
        startBef.rewardService.saveRewards(res, name, con);
        //移除该宠物
        list.remove(pet);
        if (savePetList(list, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, res);
    }

    /**
     * 放生
     */
    public result fangshengPet(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (Id == null) return new result(0);
        JSONObject pet = null;
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(Id)) {
                pet = obj;
                break;
            }
        }
        if (pet == null) return new result(0);
        int lv = pet.getInteger("lever");
        int quality = pet.getInteger("quality");
        if (lv < 40) return new result(0);
        //验证是否今日已经放生了 xq_ac_day_limit
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> arr = activityMapper.getAcDayLimit(name);
        if (arr.size() == 0) {
            activityMapper.insertAcDayLimit(name);
            JSONObject obj = new JSONObject();
            obj.put("fangsheng", 1);
            arr.add(obj);
        }
        int n = arr.get(0).getInteger("fangsheng");
        if (n <= 0) {
            return new result(610);
        }
        //标记已放生
        if (!activityMapper.updateAcDayLimit(name, null, null, null, n - 1)) {
            return new result(0);
        }
        //恢复一定的人气值
        int sez = 0;
        if (lv < 60) sez = 1;
        else if (lv < 80) sez = 2;
        else if (lv <= 100) sez = 3;
        if (quality >= 3) sez += 1;
        else if (quality == 2) sez += 2;
        else if (quality == 1) sez += 3;
        if (startBef.manService.updateSez(name, sez, con) != 1) {
            return new result(0);
        }
        //移除该宠物
        list.remove(pet);
        if (savePetList(list, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, sez);
    }

    /**
     * 洗点，属性重置
     */
    public result resetPoint(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (Id == null) return new result(0);
        JSONObject pet = null;
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(Id)) {
                pet = obj;
                break;
            }
        }
        if (pet == null) return new result(0);
        int lv = pet.getInteger("lever");
        int oldPropPoint = pet.getInteger("propPoint");
        JSONObject baseProp = pet.getJSONObject("baseProp");
        //等级+5=不使用任何逆转散时的属性
        int sum = 0;//累计转出属性
        for (String k : baseProp.keySet()) {
            //使用逆转散转出
            if (baseProp.getInteger(k) > 5 + (lv - 1)) {
                sum += (baseProp.getInteger(k) - (5 + (lv - 1)));
                baseProp.put(k, 5 + (lv - 1));
            }
        }
        //累计转出的+未使用的属性点
        int point = oldPropPoint + sum;
        /*if (pet.getInteger("growBreachLv") >= 1) {//突破则多50
            point += 50;
        }*/
        pet.put("propPoint", point);
        if (pet.getInteger("lever") >= 50) {
            if (startBef.packageService.cutPlayerGoodsNumByKey("10000171", 1, name, con) != 1) {
                return new result(0);
            }
        }
        if (savePetList(list, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, 1);
    }

    /**
     * 吃悟性丹
     */
    public result eatPetWxd(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        String danKey = j.getString("danKey");
        if (Id == null || danKey == null ||
                (!danKey.equals("10000130") && !danKey.equals("10000118") && !danKey.equals("10000119")))
            return new result(0);
        JSONObject pet = null;
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(Id)) {
                pet = obj;
                break;
            }
        }
        if (pet == null) return new result(0);
        int savvy = pet.getInteger("savvy");
        if (savvy >= 200 || (savvy >= 100 && danKey.equals("10000130")) ||
                (savvy >= 150 && danKey.equals("10000118"))) return new result(0);
        if (startBef.packageService.cutPlayerGoodsNumByKey(danKey, 1, name, con) != 1) {
            return new result(0);
        }
        int num = 0;
        if (danKey.equals("10000130")) num = strUtils.getRandom(0, 3);
        else if (danKey.equals("10000118")) num = strUtils.getRandom(1, 4);
        else if (danKey.equals("10000119")) num = strUtils.getRandom(2, 5);
        if (savvy + num > 200) num = 200 - savvy;
        pet.put("savvy", savvy + num);
        if (savePetList(list, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, num);
    }

    /**
     * 吃逆转散
     */
    public result eatPetNzs(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        String danKey = j.getString("danKey");
        String attrKey = j.getString("attrKey");
        if (Id == null || danKey == null || attrKey == null ||
                (!danKey.equals("10000168") && !danKey.equals("10000169") && !danKey.equals("10000170")))
            return new result(0);
        JSONObject pet = null;
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(Id)) {
                pet = obj;
                break;
            }
        }
        if (pet == null) return new result(0);
        JSONObject baseProp = pet.getJSONObject("baseProp");
        if (!baseProp.containsKey(attrKey)) return new result(0);
        //是否已经达到最低的属性 5
        if (baseProp.getInteger(attrKey) <= 5) return new result(0);
        if (startBef.packageService.cutPlayerGoodsNumByKey(danKey, 1, name, con) != 1) {
            return new result(0);
        }
        int num = 0;
        if (danKey.equals("10000168")) num = 1;
        else if (danKey.equals("10000169")) num = 2;
        else num = 3;
        int sy = baseProp.getInteger(attrKey) - num;
        baseProp.put(attrKey, sy);
        if (sy < 5) baseProp.put(attrKey, 5);
        int point = num - (sy < 5 ? (5 - sy) : 0);
        pet.put("propPoint", pet.getInteger("propPoint") + point);
        if (pet.getInteger("isFight") == 1) {
            //重新计算战力
            startBef.orderService.countZlOrder(name);
        }
        return new result(200, savePetList(list, name, con));
    }

    /**
     * 吃健骨丹
     */
    public result eatPetDan(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        String danKey = j.getString("danKey");
        if (Id == null || danKey == null || !danKey.substring(0, 4).equals("1011")) return new result(0);

        //需要一个字段记录增加的点数
        JSONObject pet = null;
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(Id)) {
                pet = obj;
                break;
            }
        }
        if (pet == null) return new result(0);

        String[] attrs = petData.getPetDanAttrKeys();

        JSONObject danAttr = pet.getJSONObject("danAttr");
        int type = Integer.parseInt(danKey.substring(4).charAt(3) + "");
        int lv = Integer.parseInt(danKey.substring(4).charAt(2) + "") + 1;
        int p = petData.getPetDanAttr(type, lv);
        String attrKey = attrs[type];
        //验证丹是否已经吃满 固元50颗 元魂100颗 仙元200颗
        int max = petData.getMaxPetDanAttr(attrKey, lv);
        if (lv == 1) {//固元丹
            JSONObject d1 = danAttr.getJSONObject("d1");
            if (d1.getInteger(attrKey) >= max) {
                return new result(0);
            }
        } else if (lv == 2) {//元魂丹
            JSONObject d2 = danAttr.getJSONObject("d2");
            if (d2.getInteger(attrKey) >= max) {
                return new result(0);
            }
        } else if (lv == 3) {//仙元丹
            JSONObject d3 = danAttr.getJSONObject("d3");
            if (d3.getInteger(attrKey) >= max) {
                return new result(0);
            }
        }
        if (startBef.packageService.cutPlayerGoodsNumByKey(danKey, 1, name, con) != 1) {
            return new result(0);
        }
        if (lv == 1) {//固元丹
            JSONObject d1 = danAttr.getJSONObject("d1");
            d1.put(attrKey, d1.getInteger(attrKey) + p);
            if (d1.getInteger(attrKey) >= max) {
                d1.put(attrKey, max);
            }
        } else if (lv == 2) {//元魂丹
            JSONObject d2 = danAttr.getJSONObject("d2");
            d2.put(attrKey, d2.getInteger(attrKey) + p);
            if (d2.getInteger(attrKey) >= max) {
                d2.put(attrKey, max);
            }
        } else if (lv == 3) {//仙元丹
            JSONObject d3 = danAttr.getJSONObject("d3");
            d3.put(attrKey, d3.getInteger(attrKey) + p);
            if (d3.getInteger(attrKey) >= max) {
                d3.put(attrKey, max);
            }
        }
        if (pet.getInteger("isFight") == 1) {
            //重新计算战力
            startBef.orderService.countZlOrder(name);
        }
        return new result(200, savePetList(list, name, con));
    }

    /**
     * 判断宠物数量是否超过限制
     */
    public boolean isOverLimitNum(String name, DefaultSqlSession con) {
        if (this.getList(name, con).size() >= 20) {
            return true;
        }
        return false;
    }

    /**
     * 捕捉宠物
     */
    public boolean catchPet(String controlPosKey, String posKey, JSONObject fgMsg) {
        if (fgMsg == null || fgMsg.getInteger("type") != 0 ||
                fgMsg.getInteger("isCatch") == 0) {
            return false;
        }
        JSONArray monsterList = fgMsg.getJSONArray("monsterList");
        String key = null;
        int quality = 0;
        for (Object m : monsterList) {
            JSONObject a = (JSONObject) m;
            if (a.getString("posKey").equals(posKey)) {
                key = a.getString("key");
                quality = a.getInteger("quality");
                break;
            }
        }
        JSONObject data = petData.get(key, fgMsg.getString("projRootDir"));
        if (data == null || isNoCatchPet(key, fgMsg.getString("projRootDir"))) {
            return false;
        }
        JSONArray roleList = fgMsg.getJSONArray("roleList");
        String name = null;
        for (Object m : roleList) {
            JSONObject a = (JSONObject) m;
            if (a.getString("posKey").equals(controlPosKey)) {
                name = a.getString("name");
                break;
            }
        }
        if (name == null) return false;
        //等级是否达到
        if (data.getInteger("fightLv") > staticCollection.getUserByName(name).msg.getInteger("lever")) {
            return false;
        }
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            if (startBef.petService.isOverLimitNum(name, con)) {
                return false;
            }
            JSONObject pet = createPet(key, quality, name, con);
            //ws将生成的宠物数据回送
            JSONArray ps = rewardUtils.getPetReward(pet);
            ChannelSupervise.noticeClientByName(ps, name, "10000");
            mybatisConfig.commit(con);
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        return false;
    }

    /*public result catchPet(JSONObject j,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        JSONObject data = petData.get(key, user.projRootDir);
        //判断所处的战斗是否允许捕捉
        JSONObject fgMsg = fightUtils.getFightMsgByName(name);
        if (fgMsg == null || fgMsg.getInteger("type") != 0) {
            return new result(200, 0);
        }
        if (isNoCatchPet(key) || data.get("model") == null) {
            return new result(200, 0);
        }
        if (startBef.petService.isOverLimitNum(name, con)) {
            return new result(200, 0);
        }
        //todo:从fgMsg中拿到怪物品质
        JSONObject pet = createPet(key, j.getInteger("type"), name, con);
        return new result(200, pet);
    }*/

    /**
     * 是否为不能捕获的宠物
     */
    private boolean isNoCatchPet(String key, String projRootDir) {
        //key不为4个数字或者是特殊宠物则不允许捕捉
        if (!strUtils.isMatch(key, "[0-9]{4}")
                || isSpecialPet(key, projRootDir)) return true;

        return false;
    }

    /**
     * 特殊宠物（稀有、神兽）
     */
    private boolean isSpecialPet(String key, String projRootDir) {
        if (projRootDir.equals("wl") &&
                (key.equals("1052") || key.equals("1053") || key.equals("1054") || key.equals("1055") || key.equals("1056")
                        || key.equals("1057") || key.equals("1058") || key.equals("1059") || key.equals("1060"))) {
            return true;
        } else if (projRootDir.equals("xq2d") &&
                (key.equals("1215") || key.equals("1216") || key.equals("1217") || key.equals("1218") || key.equals("1219")
                        || key.equals("1220") || key.equals("1221") || key.equals("1222") || key.equals("1223") || key.equals("1224")
                        || key.equals("1225") || key.equals("1226") || key.equals("1227") || key.equals("1228"))) {
            return true;
        }
        return false;
    }

    /**
     * 更新宠物属性点
     */
    public result updatePetPropPointAndBaseAttr(JSONObject obj,
                                                @paramsAnno(key = "user") user user,
                                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (obj.get("Id") == null) return new result(0);

        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject lbj = (JSONObject) l;
            if (obj.getString("Id").equals(lbj.getString("Id"))) {

                JSONObject baseProp = lbj.getJSONObject("baseProp");
                JSONObject newBaseProp = obj.getJSONObject("baseProp");
                for (String b : baseProp.keySet()) {
                    //判断是否低于初始的属性，不允许低于原数据
                    if (newBaseProp.getInteger(b) < baseProp.getInteger(b))
                        return new result(200, 0);
                }
                lbj.put("propPoint", obj.get("propPoint"));
                lbj.put("baseProp", newBaseProp);
                //获取等级
                int lv = lbj.getInteger("lever");
                //该等级的总点数(每级5点自由属性点+1级的5点固定属性点（5*5）+后续每级+1固定属性)
                int sum = (lv - 1) * 5 + 5 * 5 + (lv - 1) * 5;
                //突破6则多个50
                if (lbj.getInteger("growBreachLv") > 0) {
                    sum += 50;
                }
                int pSum = newBaseProp.getInteger("ll") +
                        newBaseProp.getInteger("nl") +
                        newBaseProp.getInteger("zl") +
                        newBaseProp.getInteger("js") +
                        newBaseProp.getInteger("mj");
                if (sum != lbj.getInteger("propPoint") + pSum) {
                    return new result(200, 0);
                }
                if (lbj.getInteger("isFight") == 1) {
                    //重新计算战力
                    startBef.orderService.countZlOrder(name);
                }
                return new result(200, savePetList(list, name, con));
            }
        }
        return new result(200, 0);
    }

    /**
     * 为宠物改名
     */
    public result setPetName(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        String petName = j.getString("petName");
        String petId = j.getString("petId");
        final String name = user.name;
        if (strUtils.isNull(petName) || strUtils.isNull(name) || petName.length() > 6) {
            return new result(0);
        }
        //获取出战宠物并为其改名
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(petId)) {
                obj.put("nickName", petName);
                break;
            }
        }

        //消耗改名卡
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000004", 1, name, con) == 0) {
            return new result(0);
        }
        return new result(200, savePetList(list, name, con));
    }

    /**
     * 宠物进化
     */
    public result evolution(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (Id == null) return new result(0);

        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(Id)) {
                //是否达到进化条件
                if (obj.getInteger("lever") < 60 ||
                        obj.getInteger("growLv") != 8 ||
                        obj.getInteger("growBreachLv") != 1) {
                    return new result(0);
                }
                obj.put("growBreachLv", 2);
                //进化后多一个技能槽
                JSONArray sklList = obj.getJSONObject("attr").getJSONArray("skill");
                if (sklList.size() < 11) {
                    JSONObject pos = new JSONObject();
                    pos.put("isOpen", 1);
                    sklList.add(pos);
                }
                //消耗进化石x1
                if (startBef.packageService.cutPlayerGoodsNumByKey("10000121", 1, name, con) == 0) {
                    return new result(0);
                }
                if (obj.getInteger("isFight") == 1) {
                    //重新计算战力
                    startBef.orderService.countZlOrder(name);
                }
                return new result(200, savePetList(list, name, con));
            }
        }
        return new result(0);
    }

    /**
     * 宠物突破
     */
    public result breach(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (Id == null) return new result(0);

        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(Id)) {
                //是否达到突破条件
                if (obj.getInteger("lever") < 60 ||
                        obj.getInteger("growLv") != 6 ||
                        obj.getInteger("growBreachLv") != 0) {
                    return new result(0);
                }
                //消耗人参果x5
                if (startBef.packageService.cutPlayerGoodsNumByKey("10000122", 5, name, con) == 0) {
                    return new result(0);
                }
                obj.put("growBreachLv", 1);
                //多50点属性点
                obj.put("propPoint", obj.getInteger("propPoint") + 50);
                if (obj.getInteger("isFight") == 1) {
                    //重新计算战力
                    startBef.orderService.countZlOrder(name);
                }
                return new result(200, savePetList(list, name, con));
            }
        }
        return new result(0);
    }

    /**
     * 宠物强化
     */
    public result petQiangHua(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String projName = staticCollection.getProjRootDirByName(name);
        String petId = j.getString("petId");
        JSONArray list = getList(name, con);
        JSONObject mainPet = null;
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(petId)) {
                mainPet = obj;
                break;
            }
        }
        //至少60级
        if (mainPet == null || mainPet.getInteger("lever") < 60) {
            return new result(0);
        }
        int growLv1 = mainPet.getInteger("growLv");
        int growBreachLv1 = mainPet.getInteger("growBreachLv");
        //最高10级，成6以上需要进行一次突破才允许，成8以上需要进化
        if (growLv1 >= 10 || (growLv1 >= 6 && growBreachLv1 < 1) ||
                (growLv1 >= 8 && growBreachLv1 < 2)) {
            return new result(0);
        }
        //每次消耗500元宝
        if (startBef.manService.saveMoney(0, -500L, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //根据vip判断是否允许强化
        if (!startBef.vipService.isAllowedQiangHua(growLv1, name, con)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        int value = startBef.vipService.getQiangHuaZhi(growLv1, name, con);
        if (value == 0) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        if (!upGrow(mainPet, value, projName)) {
            mybatisConfig.rollback(con);
            return new result(206);
        }
        JSONObject res = new JSONObject();
        if (growLv1 != mainPet.getInteger("growLv")) {
            res.put("qualityValue", mainPet.get("qualityValue"));
            res.put("growLv", mainPet.get("growLv"));
        }
        res.put("growValue", mainPet.get("growValue"));

        if (mainPet.getInteger("isFight") == 1) {
            //重新计算战力
            startBef.orderService.countZlOrder(name);
        }
        if (savePetList(list, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, res);
    }

    /**
     * 吞噬宠物、成长
     */
    public result eatPet(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String projName = staticCollection.getProjRootDirByName(name);
        String petId = j.getString("petId");
        String fuId = j.getString("fuId");
        if (strUtils.isNull(petId) || strUtils.isNull(fuId)) return new result(0);
        JSONArray list = getList(name, con);
        JSONObject mainPet = null;
        JSONObject eatPet = null;
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(petId)) {
                mainPet = obj;
            }
            if (obj.getString("Id").equals(fuId)) {
                eatPet = obj;
            }
            if (mainPet != null && eatPet != null) {
                break;
            }
        }
        //主宠最低60级，副宠最低40级，不允许自己吃自己
        if (mainPet == null || eatPet == null ||
                mainPet.getInteger("lever") < 60 ||
                eatPet.getInteger("lever") < 40 ||
                mainPet.getString("Id").equals(eatPet.getString("Id"))) {
            return new result(0);
        }
        //根据主宠当前成长等级和副宠成长等级计算加的成长度，成长率决定总资质限制的提升
        int growLv1 = mainPet.getInteger("growLv");
        //成5以上需要vip
        if (growLv1 >= 5) {
            //根据vip判断是否允许强化
            if (!startBef.vipService.isAllowedQiangHua(growLv1, name, con)) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        int growValue1 = mainPet.getInteger("growValue");
        int growBreachLv1 = mainPet.getInteger("growBreachLv");
        int growLv2 = eatPet.getInteger("growLv");
        //最高10级，最低要求吃等级相差2的,成6以上需要进行一次突破才允许吃，成8以上需要进化
        if (growLv1 >= 10 || growLv1 - growLv2 > 2 || (growLv1 >= 6 && growBreachLv1 < 1) ||
                (growLv1 >= 8 && growBreachLv1 < 2)) {
            return new result(0);
        }
        //吞噬同等级获得200成长度，吞噬高1等级的就+500，2等级以上的就+1k
        int value = 0;
        if (growLv2 - growLv1 == 0) {
            value = 200;
        } else if (growLv2 - growLv1 == 1) {
            value = 500;
        } else if (growLv2 - growLv1 >= 2) {
            value = 1000;
        } else if (growLv2 - growLv1 == -1) {
            value = 10;
        } else if (growLv2 - growLv1 == -2) {
            value = 1;
        } else {
            return new result(0);
        }
        //fixme 注意限制每日吃虫
        //超过每日吃宠的数量
        if (mainPet.getInteger("eatPet") >= 10) {
            return new result(826);
        }
        if (!upGrow(mainPet, value, projName)) {
            mybatisConfig.rollback(con);
            return new result(206);
        }
        mainPet.put("eatPet", mainPet.getInteger("eatPet") + 1);
        list.remove(eatPet);

        JSONObject res = new JSONObject();
        if (growLv1 != mainPet.getInteger("growLv")) {
            res.put("qualityValue", mainPet.get("qualityValue"));
            res.put("growLv", mainPet.get("growLv"));
        }
        res.put("growValue", mainPet.get("growValue"));

        if (mainPet.getInteger("isFight") == 1) {
            //重新计算战力
            startBef.orderService.countZlOrder(name);
        }
        if (savePetList(list, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, res);
    }

    private boolean upGrow(JSONObject mainPet, int value, String projRootDir) {
        int growLv1 = mainPet.getInteger("growLv");
        int growValue1 = mainPet.getInteger("growValue");
        if (growValue1 + value >= 1000) {
            mainPet.put("growValue", 0);
            mainPet.put("growLv", growLv1 + 1);
            JSONObject r = petData.get(mainPet.getString("key"), projRootDir);
            //根据成长等级获取最大资质
            JSONObject zizhi = r.getJSONObject("zizhi");
            int quality = mainPet.getInteger("quality");
            float grow = mainPet.getFloat("grow");
            int growLv = mainPet.getInteger("growLv");
            JSONObject groundMap = petData.getRealQualityGround(zizhi, quality, grow, growLv);
            JSONObject qualityValue = mainPet.getJSONObject("qualityValue");
            //用原成长等级的资质跟最大资质比例来确定成长后的提升值
            JSONObject oldGroundMap = petData.getRealQualityGround(zizhi, quality, grow, growLv1);
            //算出每个资质的比例系数
            JSONObject rateMap = petData.getNowAndMaxZiZhiRate(qualityValue, oldGroundMap);
            //判断比例是否超额
            for (String k : qualityValue.keySet()) {
                if (rateMap.getFloat(k) > 1) {
                    return false;
                }
                int max = groundMap.getJSONObject(k).getInteger("max");
                //让新资质保持旧的比例不变
                int now = (int) (max * rateMap.getFloat(k));
                qualityValue.put(k, now);
            }
        } else {
            mainPet.put("growValue", growValue1 + value);
        }
        return true;
    }

    /**
     * 添加技能槽
     */
    public result addCao(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (j.getString("Id") == null) return new result(0);
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(j.getString("Id"))) {
                //初始是10个槽位，5个开启，5个关闭，当成8加一个技能位置
                JSONArray sklList = obj.getJSONObject("attr").getJSONArray("skill");
                for (Object skl : sklList) {
                    JSONObject sklObj = (JSONObject) skl;
                    if (sklObj.getInteger("isOpen") == 0) {
                        sklObj.put("isOpen", 1);
                        int i = startBef.packageService.cutPlayerGoodsNumByKey("10000123", 1, name, con);
                        if (i == 1)
                            return new result(200, savePetList(list, name, con));
                        return new result(0);
                    }
                }
                //没有槽位
                return new result(200, 0);
            }
        }
        return new result(0);
    }

    /**
     * 遗忘技能
     * Id宠物id
     * key技能
     */
    public result forgetPetSkill(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        String Id = j.getString("Id");
        JSONObject obj = null;
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            if (item.getString("Id").equals(Id)) {
                obj = item;
                break;
            }
        }
        if (obj == null) {
            return new result(0);
        }

        JSONArray skill = obj.getJSONObject("attr").getJSONArray("skill");
        for (int i = 0; i < skill.size(); i++) {
            JSONObject ss = skill.getJSONObject(i);
            if (ss.get("key") != null && ss.getString("key").equals(key)) {
                if (i == 0) {//天生技能不能被遗忘
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
                ss.remove("key");
                ss.remove("lv");
                break;
            }
        }
        //耗费
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000165", 1, name, con) == 0) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //重新计算战力
        startBef.orderService.countZlOrder(name);
        return new result(200, savePetList(list, name, con));
    }

    /**
     * 学习宠物技能
     */
    public result learnSkill(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        String Id = j.getString("Id");
        if (key == null || Id == null) return new result(0);
        //宠物专属技能、普通技能
        skill data = skillUtils.getInstance().getSkill(key);
        if (data == null) return new result(979);
        //是宠物普通技能才允许学习
        if (data.type != 5) {
            return new result(0);
        }
        //判断是否有槽位
        //判断是否已经学过
        JSONObject pet = null;
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            //由id找宠物
            if (Id.equals(item.getString("Id"))) {
                pet = item;
                break;
            }
        }
        if (pet == null) return new result(0);
        //是否为禁止学习的技能
        if (isNoLearnSkill(pet.getString("key"), key)) {
            return new result(0);
        }
        JSONArray js = pet.getJSONObject("attr").getJSONArray("skill");
        for (Object s : js) {
            JSONObject ss = (JSONObject) s;
            //已经学习过了
            if (ss.getString("key") != null &&
                    ss.getString("key").equals(key)) {
                return new result(0);
            }
        }
        //判断悟性是否满足
        if (data.savvy > pet.getInteger("savvy")) return new result(963);

        //判断回天书处理中是否存在需要处理的任务
        for (int i = 0; i < skillData.HuitianSkillCache.size(); i++) {
            JSONObject a = skillData.HuitianSkillCache.get(i);
            if (a.getString("name").equals(name) &&
                    a.getInteger("roleType") == 1) {
                JSONObject res = new JSONObject();
                res.put("index", a.getInteger("index"));
                res.put("sure", 1);//表示需要弹出询问
                return new result(200, res);
            }
        }
        //第一项为天生技能槽，除了它以外的才随机
        List<Integer> indexs = new ArrayList<>();
        for (int i = 1; i < js.size(); i++) {
            JSONObject ss = (JSONObject) js.get(i);
            //获取所有能打技能的槽位
            if (ss.getInteger("isOpen") == 1) {
                indexs.add(i);
            }
        }
        //随机取一个位置打
        int index = indexs.get(strUtils.getRandom(0, indexs.size()));
        //判断是否存在道具
        if (startBef.packageService.cutPlayerGoodsNumByKey(key, 1, name, con) == 0) {
            return new result(0);
        }
        JSONObject item = js.getJSONObject(index);
        if (item.containsKey("key")) {//已经打过技能的情况
            //需要询问是否使用回天书
            //将其延迟放入缓存
            JSONObject cache = new JSONObject();
            cache.put("name", name);
            cache.put("key", key);
            cache.put("index", index);
            cache.put("created", strUtils.getTime());
            cache.put("roleType", 1);//0角色1宠物
            cache.put("petId", Id);
            skillData.HuitianSkillCache.add(cache);

            JSONObject res = new JSONObject();
            res.put("index", index);
            res.put("sure", 1);//表示需要弹出询问
            return new result(200, res);
        } else {
            item.put("key", key);
            item.put("lv", 1);
            if (savePetList(list, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            if (pet.getInteger("isFight") == 1) {
                //重新计算战力
                startBef.orderService.countZlOrder(name);
            }
            //将技能所在的位置返回
            JSONObject res = new JSONObject();
            res.put("index", index);
            res.put("sure", 0);//表示不需要弹出询问
            return new result(200, res);
        }
    }

    /**
     * 是否为该宠物不能学习的技能
     */
    private boolean isNoLearnSkill(String petKey, String skillKey) {
        //逆天魔龙不允许学习金刚霸体
        /*if (petKey.equals("1003") && skillKey.equals("3127")) {
            return true;
        }*/
        return false;
    }

    /**
     * 对超时未确认的技能进行处理
     */
    public void handleSklSureOverTime(String petId, String key, int index, String name, DefaultSqlSession con) {
        JSONObject pet = null;
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            //由id找宠物
            if (petId.equals(item.getString("Id"))) {
                pet = item;
                break;
            }
        }
        if (pet == null) return;
        JSONArray js = pet.getJSONObject("attr").getJSONArray("skill");
        JSONObject skl = js.getJSONObject(index);
        skl.put("key", key);
        skl.put("lv", 1);
        if (savePetList(list, name, con) != 1) {
            mybatisConfig.rollback(con);
        }
    }

    /**
     * 取消/确认技能覆盖
     */
    public result sureSkillCover(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer sure = j.getInteger("sure");
        if (sure == null || (sure != 0 && sure != 1)) return new result(0);

        JSONObject item = null;
        for (int i = 0; i < skillData.HuitianSkillCache.size(); i++) {
            JSONObject a = skillData.HuitianSkillCache.get(i);
            if (a.getString("name").equals(name) &&
                    a.getInteger("roleType") == 1) {
                item = a;
                skillData.HuitianSkillCache.remove(i);
                break;
            }
        }
        if (item == null) {
            //已经超时未处理，交由系统处理了
            return new result(200, -1);
        }
        int roleType = item.getInteger("roleType");
        int index = item.getInteger("index");
        String key = item.getString("key");
        String xhKey = null;
        if (roleType == 0) xhKey = "10000128";
        else xhKey = "10000120";

        if (sure == 1) {
            //确认覆盖
            if (roleType == 0) {

            } else {
                //宠物
                String petId = item.getString("petId");
                handleSklSureOverTime(petId, key, index, name, con);
            }
            return new result(200, 1);
        } else {
            //取消覆盖
            if (startBef.packageService.cutPlayerGoodsNumByKey(xhKey, 1, name, con) == 1) {
                //取消覆盖成功
                return new result(200, 0);
            } else {
                //发生覆盖
                if (roleType == 0) {

                } else {
                    //宠物
                    String petId = item.getString("petId");
                    handleSklSureOverTime(petId, key, index, name, con);
                }
                return new result(200, 1);
            }
        }
    }

    /**
     * 是否超过每日限制吃宠数量
     */

    /*public Integer isOverLimitEatPet(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectActivityByName(name);
        if (list.size() == 0) {
            jsonMapper.insertActivity(name);
            jsonMapper.updateActivity(null, "1", null, name);
        } else {
            JSONObject ac = list.get(0);
            if (ac.getInteger("eatpet") >= 10) {
                return 1;
            }
            jsonMapper.updateActivity(null, ac.getInteger("eatpet") + 1 + "", null, name);
        }
        return 0;
    }*/

    /**
     * 更新出战宠物的prop
     * attrMap包含prop里需要更改的属性 如：xue
     */
    public Integer updatePetXueByIsFight(JSONObject attrMap, String name, DefaultSqlSession con) {
        for (String p : attrMap.keySet()) {
            if (!p.equals("xue") && !p.equals("lan")) {
                System.err.println(name + "/updatePetXueByIsFight出现异常字段\n" + attrMap);
                return 0;
            }
            if (attrMap.get(p) == null) {
                System.err.println(name + "/updatePetXueByIsFight出现值为null\n" + attrMap);
                return 0;
            }
        }
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject pet = (JSONObject) l;
            Integer isFight = pet.getInteger("isFight");
            if (isFight == 1) {
                JSONObject prop = pet.getJSONObject("attr").getJSONObject("prop");
                for (String p : prop.keySet()) {
                    if (!attrMap.containsKey(p)) continue;
                    prop.put(p, attrMap.get(p));
                }
                break;
            }
        }
        return savePetList(list, name, con);
    }

    /**
     * 获取宠物战斗属性
     */
    public JSONObject getFightAttr(String name, DefaultSqlSession con) {
        //找到出战的那只
        JSONArray list = getList(name, con);
        if (list == null) return null;
        JSONObject one = null;
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            if (obj.getInteger("isFight") == 1) {
                one = obj;
                break;
            }
        }
        if (one == null) {
            return null;
        }
        int attackType = petData.get2dData(one.getString("key")).getInteger("type");
        one.getJSONObject("attr").getJSONObject("prop").put("type", attackType);
        JSONObject attr = one.getJSONObject("attr");
        //筛选有效技能
        JSONArray arr = attr.getJSONArray("skill");
        //去除空槽位
        JSONArray skill = new JSONArray();
        for (Object o : arr) {
            JSONObject obj = (JSONObject) o;
            if (obj.containsKey("key")) {
                skill.add(obj);
            }
        }
        attr.put("skill", skill);
        //5个基础属性
        JSONObject baseProp = one.getJSONObject("baseProp");
        JSONObject r = new JSONObject();
        r.put("attr", attr);
        r.put("lever", one.getInteger("lever"));
        r.put("baseProp", baseProp);
        r.put("qualityValue", one.get("qualityValue"));
        r.put("growLv", one.getInteger("growLv"));
        r.put("danAttr", one.get("danAttr"));
        r.put("xrmf", startBef.manService.getXrmf(name, con));
        r.put("petEquip", startBef.packageService.getPetEquip(name, con));
        JSONObject prop = countProp(r);

        JSONObject res = new JSONObject();
        res.put("prop", prop);
        res.put("skill", attr.get("skill"));
        res.put("type", attr.getJSONObject("prop").getInteger("type"));
        return res;
    }

    /**
     * 吃淬体丹
     */
    public Integer eatCTD(String name, DefaultSqlSession con) {
        JSONArray list = getList(name, con);
        JSONObject fightPet = null;
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getInteger("isFight") == 1) {
                fightPet = obj;
                break;
            }
        }
        //根据主宠当前成长等级和副宠成长等级计算加的成长度，成长率决定总资质限制的提升
        int growLv1 = fightPet.getInteger("growLv");
        int growValue1 = fightPet.getInteger("growValue");
        int growBreachLv1 = fightPet.getInteger("growBreachLv");
        //最高10级，最低要求吃等级相差2的,成6以上需要进行一次突破才允许吃，成8以上需要进化
        if (growLv1 >= 10 || (growLv1 >= 6 && growBreachLv1 < 1) ||
                (growLv1 >= 8 && growBreachLv1 < 2)) {
            mybatisConfig.rollback(con);
            return 0;
        }
        //吞噬同等级获得200成长度，吞噬高1等级的就+500，2等级以上的就+1k
        int value = 200;
        //超过每日吃宠的数量
        if (fightPet.getInteger("eatPet") >= 10) {
            mybatisConfig.rollback(con);
            return 0;
        }
        if (growValue1 + value >= 1000) {
            fightPet.put("growValue", 0);
            fightPet.put("growLv", growLv1 + 1);
        } else {
            fightPet.put("growValue", growValue1 + value);
        }
        fightPet.put("eatPet", fightPet.getInteger("eatPet") + 1);
        //重新计算战力
        startBef.orderService.countZlOrder(name);
        return savePetList(list, name, con);
    }

    /**
     * 重置资质,返回新资质数据
     */
    public result reZizhi(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (Id == null || startBef.packageService.cutPlayerGoodsNumByKey("10000113", 1, name, con) != 1) {
            return new result(0);
        }
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            if (item.getString("Id").equals(Id)) {
                resetZiZhi(item, user);
                if (savePetList(list, name, con) == 1) {
                    //重新计算战力
                    if (item.getInteger("isFight") == 1) {
                        startBef.orderService.countZlOrder(name);
                    }
                    return new result(200, item.getJSONObject("qualityValue"));
                }
                return new result(0);
            }
        }
        return new result(0);
    }

    /**
     * 重置资质
     */
    private void resetZiZhi(JSONObject item, user user) {
        JSONObject r = petData.get(item.getString("key"), user.projRootDir);
        r.put("quality", item.getInteger("quality"));
        //根据品质获取实际资质范围
        JSONObject groundMap = petData.getRealQualityGround(r);
        int lv = item.getInteger("growLv");
        for (String k : groundMap.keySet()) {
            JSONObject limit = groundMap.getJSONObject(k);
            int max = limit.getInteger("max");
            int real = Float.valueOf(max + (max / 10 * item.getFloat("grow") / 1000 * (0.8f + 0.1f * lv)) * lv / 2.5f + "").intValue();
            limit.put("max", real);
        }
        //生成具体资质
        item.put("qualityValue", petData.getFinalQuality(groundMap));
    }

    /**
     * 重置属性点
     */
    /*public result resetAttrPoint(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000112", 1, name, con) != 1) {
            return new result(0);
        }
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            if (item.getString("Id").equals(Id)) {
                item.put("propPoint", (item.getInteger("lever") - 1) * 5);
                JSONObject baseProp = item.getJSONObject("baseProp");
                baseProp.put("ll", 5);
                baseProp.put("nl", 5);
                baseProp.put("zl", 5);
                baseProp.put("js", 5);
                baseProp.put("mj", 5);

                JSONObject role = new JSONObject();
                role.put("lever", item.getInteger("lever"));
                role.put("attr", item.getJSONObject("attr"));
                role.put("baseProp", baseProp);
                role.put("qualityValue", item.get("qualityValue"));
                role.put("growLv", item.getInteger("growLv"));
                role.put("danAttr", item.get("danAttr"));
                role.put("xrmf", startBef.manService.getXrmf(name, con));
                JSONObject obj = countProp(role);
                JSONObject prop = item.getJSONObject("attr").getJSONObject("prop");
                prop.put("xue", obj.getInteger("max_xue"));
                prop.put("lan", obj.getInteger("max_lan"));

                if (savePetList(list, name, con) == 1) {
                    if (item.getInteger("isFight") == 1) {
                        //重新计算战力
                        startBef.orderService.countZlOrder(name);
                    }
                    return new result(200, 1);
                }
                return new result(0);
            }
        }
        return new result(0);
    }
*/

    /**
     * 重生(返回成长率)
     */
    public result reLive(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        //两种方式 0保留技能 1重置技能
        Integer type = j.getInteger("type");
        if (Id == null || type == null) {
            return new result(0);
        }
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000124", 1, name, con) != 1) {
            return new result(0);
        }
        JSONObject res = reLive(Id, type, user, con);
        if (res == null) return new result(0);
        return new result(200, res);
    }

    /**
     * 重生(返回宠物信息)
     */
    private JSONObject reLive(String Id, int type, user u, DefaultSqlSession con) {
        if (u == null) return null;
        final String name = u.name;
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            if (item.getString("Id").equals(Id)) {
                item.put("lever", 1);
                item.put("propPoint", 0);
                JSONObject baseProp = item.getJSONObject("baseProp");
                baseProp.put("ll", 5);
                baseProp.put("nl", 5);
                baseProp.put("zl", 5);
                baseProp.put("js", 5);
                baseProp.put("mj", 5);
                //重置成长率
                item.put("grow", petData.getGrow(item.getInteger("quality")));
                item.put("growValue", 0);
                item.put("growLv", 0);
                item.put("growBreachLv", 0);
                //重置吃的属性丹
                JSONObject danAttr = item.getJSONObject("danAttr");
                JSONObject d1 = danAttr.getJSONObject("d1");//固元
                JSONObject d2 = danAttr.getJSONObject("d2");//元魂
                JSONObject d3 = danAttr.getJSONObject("d3");//仙元
                String[] attrs = petData.getPetDanAttrKeys();
                for (String a : attrs) {
                    d1.put(a, 0);
                    d2.put(a, 0);
                    d3.put(a, 0);
                }
                //重置资质
                resetZiZhi(item, u);

                if (type == 1) {//重置技能
                    JSONArray skls = item.getJSONObject("attr").getJSONArray("skill");
                    for (int i = 0; i < skls.size(); i++) {
                        //天生技能不能重置
                        if (i == 0) continue;
                        JSONObject s = skls.getJSONObject(i);
                        if (s.containsKey("key")) s.remove("key");
                        if (s.containsKey("lv")) s.remove("lv");
                    }
                }

                JSONObject role = new JSONObject();
                role.put("lever", item.getInteger("lever"));
                role.put("attr", item.getJSONObject("attr"));
                role.put("baseProp", baseProp);
                role.put("qualityValue", item.get("qualityValue"));
                role.put("growLv", item.getInteger("growLv"));
                role.put("danAttr", item.get("danAttr"));
                role.put("xrmf", startBef.manService.getXrmf(name, con));
                role.put("petEquip", startBef.packageService.getPetEquip(name, con));
                JSONObject obj = countProp(role);
                JSONObject prop = item.getJSONObject("attr").getJSONObject("prop");
                prop.put("xue", obj.getInteger("max_xue"));
                prop.put("lan", obj.getInteger("max_lan"));
                prop.put("exp", 0);
                prop.put("type", petData.get2dData(item.getString("key")).getInteger("type"));

                if (savePetList(list, name, con) == 1) {
                    //重新计算战力
                    startBef.orderService.countZlOrder(name);

                    JSONObject res = new JSONObject();
                    res.put("qualityValue", item.get("qualityValue"));
                    res.put("grow", item.get("grow"));
                    return res;
                }
                mybatisConfig.rollback(con);
                return null;
            }
        }
        return null;
    }

    /**
     * 吃经验丹
     */
    public result eatDan(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String danKey = j.getString("danKey");
        String petId = j.getString("petId");
        int times = j.getInteger("times");
        if (!danKey.equals("10000029") && !danKey.equals("10000030") &&
                !danKey.equals("10000031") && !danKey.equals("10000032")) {
            return new result(0);
        }
        JSONObject dan = startBef.packageService.getOneByKey(danKey, name, con);
        if (dan == null) return new result(0);
        int sum = dan.getInteger("num");

        int jy = 1000;
        if (danKey.equals("10000030")) jy = 10000;
        else if (danKey.equals("10000031")) jy = 50000;
        else if (danKey.equals("10000032")) jy = 200000;

        JSONObject pet = getPetById(petId, name, con);
        int petLv = pet.getInteger("lever");
        int roleLv = startBef.manService.getRoleLv(name, con);
        if (petLv >= roleLv + 10) return new result(631);
        int n = 0;
        if (times == -1) {//一键升级
            //角色等级+10为最大等级，计算宠物等级与最大等级的差距，计算所需经验
            int exp = countExpFromALvToBLv(petLv, roleLv + 10);
            if (exp == 0) return new result(631);
            int nowExp = pet.getJSONObject("attr").getJSONObject("prop").getInteger("exp");
            exp = exp - nowExp;
            //所需经验/jy=所需口粮数量，判断所需口粮数量是否超过拥有的口粮数
            int num = exp / jy == 0 ? (exp / jy) : (exp / jy + 1);
            //超过则全部使用，小于则拥有的减去所需的
            if (sum - num >= 0) n = num;
            else n = sum;
        } else {//使用1次
            n = 1;
        }
        if (startBef.packageService.cutPlayerGoodsNumByKey(danKey, n, name, con) != 1) {
            return new result(0);
        }
        JSONArray skls = upLv(petId, name, n * jy, con);
        return new result(200, skls);
    }

    /**
     * 提升出战宠物的等级
     */
    public JSONArray upLv(String name, int exp, DefaultSqlSession con) {
        Object pet = getIsFightPet(name, con);
        if (pet == null) return new JSONArray();
        String petId = ((JSONObject) pet).getString("Id");
        return upLv(petId, name, exp, con);
    }

    /**
     * 提升宠物等级,返回领悟的技能列表
     */
    public JSONArray upLv(String petId, String name, int exp, DefaultSqlSession con) {
        JSONObject role = startBef.manService.getRole(name, con);
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            //对出战的宠物添加经验
            if (item.getString("Id").equals(petId)) {
                int oldLv = item.getInteger("lever");
                //对于大于等于110级的就不再添加经验了
                if (oldLv >= 110) {
                    return null;
                }
                JSONObject prop = item.getJSONObject("attr").getJSONObject("prop");
                JSONObject temp = new JSONObject();
                temp.put("inputExp", prop.getInteger("exp") + exp);
                temp.put("lever", item.getInteger("lever"));
                temp.put("propPoint", item.getInteger("propPoint"));
                temp.put("baseProp", item.get("baseProp"));
                countLv(temp, role.getInteger("lever") + 10);
                prop.put("exp", temp.getInteger("inputExp"));
                item.put("propPoint", temp.getInteger("propPoint"));
                item.put("lever", temp.getInteger("lever"));
                item.put("baseProp", temp.get("baseProp"));
                //领悟技能列表
                JSONArray lwSkill = new JSONArray();
                //提升几级发生几次领悟
                for (int i = 0; i < item.getInteger("lever") - oldLv; i++) {
                    //30%发生领悟
                    //savvy<100是普通技能（二字） <200高级 200是神技（超级），宠物学习技能时需要限制
                    float pv = item.getInteger("savvy") / 200f;
                    if (strUtils.isHappend(0, 1000, pv)) {
                        String sklKey = null;
                        //未满5个位置的情况才发生领悟
                        if (!petData.isEnoughFive(item)) {
                            //对于专属大于10的宠物则从专属中取
                            if (petData.getZsSklSize(item, name) > 10) {
                                //领悟专属技能
                                sklKey = petData.getNoLearnZsSkl(item, name);
                                if (sklKey == null) {
                                    sklKey = petData.getNoLearnLwSkl(item);
                                }
                            } else {
                                //60%领悟专属 40%其他技能
                                if (strUtils.isHappend(0, 1000, 0.3f)) {
                                    sklKey = petData.getNoLearnLwSkl(item);
                                } else {
                                    //领悟专属技能
                                    sklKey = petData.getNoLearnZsSkl(item, name);
                                    if (sklKey == null) {
                                        sklKey = petData.getNoLearnLwSkl(item);
                                    }
                                }
                            }
                        }
                        if (sklKey != null) {
                            //添加到槽位
                            petData.addSkill(item, sklKey);
                            //添加到领悟列表
                            lwSkill.add(sklKey);
                        }
                    }
                }
                //血量、蓝补满
                if (oldLv < temp.getInteger("lever")) {
                    JSONObject r = new JSONObject();
                    r.put("attr", item.getJSONObject("attr"));
                    r.put("lever", temp.getInteger("lever"));
                    r.put("baseProp", item.getJSONObject("baseProp"));
                    r.put("qualityValue", item.get("qualityValue"));
                    r.put("growLv", item.getInteger("growLv"));
                    r.put("danAttr", item.get("danAttr"));
                    r.put("xrmf", startBef.manService.getXrmf(name, con));
                    r.put("petEquip", startBef.packageService.getPetEquip(name, con));
                    JSONObject base = countProp(r);
                    prop.put("xue", base.getInteger("max_xue"));
                    prop.put("lan", base.getInteger("max_lan"));
                }
                if (savePetList(list, name, con) == 1) {
                    //重新计算战力
                    if (item.getInteger("isFight") == 1)
                        startBef.orderService.countZlOrder(name);
                    return lwSkill;
                }
                break;
            }
        }
        return new JSONArray();
    }

    /**
     * 计算a到b等级所需经验
     */
    public int countExpFromALvToBLv(int aLv, int bLv) {
        if (aLv >= bLv) return 0;
        int max_exp = 0;
        for (int i = aLv; i <= bLv; i++) {
            Double jy = i * 100 + 2 * Math.pow(5, 0.09f * i);
            max_exp += new Double(jy).intValue();
        }
        return max_exp;
    }

    /**
     * 宠物等级计算,极限是人物等级+10
     */
    public void countLv(JSONObject j, int limitLv) {
        int lv = j.getInteger("lever");
        int inputExp = j.getInteger("inputExp");
        Double jy = lv * 100 + 2 * Math.pow(5, 0.09f * lv);
        int max_exp = jy.intValue();

        if (lv >= limitLv) {
            //当经验溢出时，最多可存放5倍
            if (inputExp >= max_exp * 5) {
                j.put("inputExp", max_exp * 5);
            }
            return;
        }

        int propPoint = j.getInteger("propPoint");
        if (inputExp >= max_exp) {
            inputExp -= max_exp;
            lv += 1;
            propPoint += 5;
            j.put("inputExp", inputExp);
            j.put("lever", lv);
            j.put("propPoint", propPoint);
            //基础属性也要+1，因为逆转散需要
            JSONObject baseProp = j.getJSONObject("baseProp");
            for (String k : baseProp.keySet()) {
                baseProp.put(k, baseProp.getInteger(k) + 1);
            }
            this.countLv(j, limitLv);
        }
    }

    /**
     * 增加一个宠物
     */
    public int addOnePet(JSONObject pet, String name, DefaultSqlSession con) {
        pet.put("isFight", 0);
        return savePet(pet, name, con);
    }

    /**
     * 吃突破丹
     */
    public Integer eatTupoDan(String name, DefaultSqlSession con) {
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            if (item.getInteger("isFight") == 1) {
                //判断是否达到成6并且总技能数量为10 6->10 8->11 10->12
                JSONArray sklList = item.getJSONObject("attr").getJSONArray("skill");
                boolean b = false;
                JSONObject obj = new JSONObject();
                obj.put("key", null);
                obj.put("lv", null);
                obj.put("isOpen", 1);
                if (item.getInteger("growLv") >= 6 &&
                        item.getInteger("growLv") < 8
                        && sklList.size() == 10) {
                    sklList.add(obj);
                    b = true;
                } else if (item.getInteger("growLv") >= 8 &&
                        item.getInteger("growLv") < 10
                        && sklList.size() <= 11) {
                    sklList.add(obj);
                    b = true;
                } else if (item.getInteger("growLv") == 10 &&
                        sklList.size() <= 12) {
                    sklList.add(obj);
                    b = true;
                }
                if (b && savePetList(list, name, con) == 1) {
                    return 1;
                }
                return 0;
            }
        }
        return 0;
    }

    /**
     * 生成宠物
     */
    public JSONObject createPet(String key, String name, DefaultSqlSession con) {
        //由key来区分稀有（1品）、神兽（1品）、野怪（1-4品）
        return createPet(key, getPetType(key), name, con);
    }

    private boolean isXiYou(String key) {
        String[] arr = {"1052", "1053", "1054", "1055",};
        for (int i = 0; i < arr.length; i++) {
            if (arr[i].equals(key)) return true;
        }
        return false;
    }

    private boolean isShenShou(String key) {
        int type = 0;
        String[] arr = {"1056", "1057", "1058", "1059",};
        for (int i = 0; i < arr.length; i++) {
            if (arr[i].equals(key)) return true;
        }
        return false;
    }

    private int getPetType(String key) {
        if (isShenShou(key) || isXiYou(key)) return 4;//神兽1品\珍兽1品
        else return strUtils.getRandom(1, 5);
    }

    public JSONObject createPet(String key, Integer type, String name, DefaultSqlSession con) {
        JSONObject r = petData.get(key, staticCollection.getProjRootDirByName(name));
        //没有该宠物
        if (r == null) {
            return null;
        }

        r.put("Id", strUtils.getId());
        r.put("loyal", 1000);//忠诚度
        r.put("lever", 1);
        r.put("eatPet", 0);
        JSONObject baseProp = new JSONObject();
        baseProp.put("ll", 5);
        baseProp.put("zl", 5);
        baseProp.put("nl", 5);
        baseProp.put("js", 5);
        baseProp.put("mj", 5);
        r.put("baseProp", baseProp);
        //根据type确定品质
        r.put("quality", petData.getQuality(type));
        //根据品质生成悟性
        r.put("savvy", petData.getSavvy(r.getInteger("quality")));
        //生成成长率
        r.put("grow", petData.getGrow(r.getInteger("quality")));
        //根据品质获取实际资质范围
        JSONObject groundMap = petData.getRealQualityGround(r);
        //生成具体资质
        r.put("qualityValue", petData.getFinalQuality(groundMap));
        //为5个基础属性初始值都是5
        //根据具体资质、加点数计算高级属性，将血量、蓝、exp等赋值
        JSONObject attr = new JSONObject();
        JSONObject prop = new JSONObject();
        prop.put("xue", 0);
        prop.put("lan", 0);
        prop.put("exp", 0);
        prop.put("type", r.getInteger("type"));//物理、法术
        attr.put("prop", prop);
        JSONObject role = new JSONObject();
        role.put("attr", attr);
        role.put("lever", r.getInteger("lever"));
        role.put("baseProp", r.getJSONObject("baseProp"));
        role.put("qualityValue", r.get("qualityValue"));
        role.put("growLv", 0);
        role.put("xrmf", startBef.manService.getXrmf(name, con));
        role.put("petEquip", startBef.packageService.getPetEquip(name, con));
        JSONObject base = countProp(role);
        prop.put("xue", base.getInteger("max_xue"));
        prop.put("lan", base.getInteger("max_lan"));

        JSONArray skill = new JSONArray();
        for (int i = 0; i < 10; i++) {
            JSONObject obj = new JSONObject();
            obj.put("key", null);
            obj.put("lv", null);
            if (i < 5) {
                obj.put("isOpen", 1);
            } else {
                obj.put("isOpen", 0);
            }
            skill.add(obj);
        }
        attr.put("skill", skill);
        r.put("attr", attr);
        r.put("propPoint", 0);
        r.put("isFight", 0);

        r.put("growValue", 0);//成长度
        r.put("growLv", 0);//成长等级
        r.put("growBreachLv", 0);//突破等级 1已突破2进化
        if (!r.containsKey("danAttr")) {//吃属性丹的字段
            JSONObject danAttr = new JSONObject();
            JSONObject d1 = new JSONObject();//固元
            JSONObject d2 = new JSONObject();//元魂
            JSONObject d3 = new JSONObject();//仙元
            String[] attrs = petData.getPetDanAttrKeys();
            for (String a : attrs) {
                d1.put(a, 0);
                d2.put(a, 0);
                d3.put(a, 0);
            }
            danAttr.put("d1", d1);
            danAttr.put("d2", d2);
            danAttr.put("d3", d3);
            r.put("danAttr", danAttr);
        }
        //保存，筛选需要保存的字段
        r.remove("type");
        r.remove("zizhi");
        r.remove("fightLv");
        r.remove("zsSkls");
        //给一个天生技能
        String sklKey = petData.getTsSkl(r, name);
        JSONObject one = skill.getJSONObject(0);
        one.put("key", sklKey);
        one.put("lv", 1);

        int i = this.savePet(r, name, con);
        //将宠物信息返回给玩家
        if (i == 1) return r;

        return null;
    }

    /**
     * 保存新增的宠物（仅用于创建一个新宠物，而不是修改原有的宠物）
     */
    private Integer savePet(JSONObject pet, String name, DefaultSqlSession con) {
        JSONArray list = getList(name, con);
        for (Object l : list) {
            //处理id重复
            if (pet.getString("Id").equals(((JSONObject) l).getString("Id"))) {
                pet.put("Id", strUtils.getId());
                break;
            }
        }
        list.add(pet);
        return savePetList(list, name, con);
    }

    /**
     * 计算宠物属性
     */
    public JSONObject countProp(JSONObject role) {
        int lever = role.getInteger("lever");
        JSONObject baseProp = role.getJSONObject("baseProp");
        JSONObject qualityValue = role.getJSONObject("qualityValue");
        int growLv = role.getInteger("growLv");
        JSONObject danAttr = role.getJSONObject("danAttr");

        JSONObject base = new JSONObject();
        base.put("ll", baseProp.getFloat("ll"));
        base.put("zl", baseProp.getFloat("zl"));
        base.put("mj", baseProp.getFloat("mj"));
        base.put("nl", baseProp.getFloat("nl"));
        base.put("js", baseProp.getFloat("js"));

        if (role.containsKey("petEquip")) {
            JSONObject zb = role.getJSONObject("petEquip");
            for (String k : zb.keySet()) {
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods == null || strUtils.getTime() > playerGoods.getLong("endTime") ||
                        !equipData.isPetEquip(playerGoods.getString("key"))) continue;
                JSONObject equip = equipData.getPetEquipProp(playerGoods.getString("key"));
                //遍历包含的固定高级属性
                for (String e : equip.keySet()) {
                    if (!roleUtils.isBaseProp(e) || equip.get(e) == null) {
                        continue;
                    }
                    base.put(e, base.getFloat(e) + equip.getFloat(e));
                }
            }
        }


        base.put("max_xue", Math.pow(1.6f, growLv) * 400 + lever * 20 +
                lever * 80 * (1 + base.getFloat("nl") / 2000)
                        * (1 + qualityValue.getFloat("max_xue") / 50000) +
                base.getFloat("nl") * 3 * qualityValue.getFloat("max_xue")
                        / 1000 + base.getFloat("js") * 3 * qualityValue.getFloat("max_xue") / 1000);
        base.put("max_lan", qualityValue.getFloat("max_lan") / 2 + 50 + lever * 20 + base.getFloat("js") * 5 * qualityValue.getFloat("max_lan") / 1000);
        base.put("wg", Math.pow(1.4f, growLv) * 100 +
                lever * 10 + lever * 8 * (1 + qualityValue.getFloat("wg") / 10000)
                + base.getFloat("ll") * 1.3 * qualityValue.getFloat("wg") / 4000);
        base.put("fg", Math.pow(1.4f, growLv) * 100 +
                lever * 10 + lever * 8 * (1 + qualityValue.getFloat("fg") / 10000)
                + base.getFloat("zl") * 1.3 * qualityValue.getFloat("fg") / 4000);
        base.put("wf", Math.pow(1.3f, growLv) * 50 +
                lever * 5 + lever * 6 * (1 + qualityValue.getFloat("wf") / 10000)
                + base.getFloat("nl") * 0.8 * qualityValue.getFloat("wf") / 4000);
        base.put("ff", Math.pow(1.3f, growLv) * 50 +
                lever * 5 + lever * 6 * (1 + qualityValue.getFloat("ff") / 10000)
                + base.getFloat("nl") * 0.8 * qualityValue.getFloat("ff") / 4000);
        base.put("mz", Math.pow(1.4f, growLv) * 30 +
                lever * 8 + lever * 8 * (1 + qualityValue.getFloat("mz") / 10000)
                + base.getFloat("ll") * 1.2 * qualityValue.getFloat("mz") / 4000);
        base.put("sd", Math.pow(1.4f, growLv) * 15 +
                lever * 3 + lever * 3 * (1 + qualityValue.getFloat("sd") / 10000)
                + base.getFloat("mj") * 0.6 * qualityValue.getFloat("sd") / 4000);
        base.put("bj", Math.pow(1.4f, growLv) * 20 +
                lever * 5 + lever * 5 * (1 + qualityValue.getFloat("bj") / 10000)
                + base.getFloat("zl") * 2 * qualityValue.getFloat("bj") / 4000);
        base.put("css", Math.pow(1.4f, growLv) * 20 +
                lever * 5 + lever * 10 * (1 + qualityValue.getFloat("css") / 10000)
                + base.getFloat("mj") * 1.5 * qualityValue.getFloat("css") / 4000);
        JSONObject prop = role.getJSONObject("attr").getJSONObject("prop");
        base.put("xue", prop.getFloat("xue"));
        base.put("lan", prop.getFloat("lan"));
        base.put("exp", prop.getFloat("exp"));
        base.put("lxkx", 0);
        base.put("bjkx", 0);
        base.put("hlkx", 0);
        base.put("hskx", 0);

        if (role.containsKey("petEquip")) {
            JSONObject zb = role.getJSONObject("petEquip");
            for (String k : zb.keySet()) {
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods == null || strUtils.getTime() > playerGoods.getLong("endTime") ||
                        !equipData.isPetEquip(playerGoods.getString("key"))) continue;
                JSONObject equip = equipData.getPetEquipProp(playerGoods.getString("key"));
                //遍历包含的固定高级属性
                for (String e : equip.keySet()) {
                    if (roleUtils.isBaseProp(e) || equip.get(e) == null) {
                        continue;
                    }
                    base.put(e, base.getFloat(e) + equip.getFloat(e));
                }
            }
        }
        //仙人秘法
        JSONObject xrmf = role.getJSONObject("xrmf");
        if (xrmf != null) {
            int xfLv = xrmf.getInteger("xfLv");
            float d = (float) (xfLv * 20f + Math.pow(1.41f, xfLv) / 3f);
            base.put("max_xue", base.getFloat("max_xue") + d);
            role.remove("xrmf");
        }
        //计算属性丹
        if (danAttr != null) {
            JSONObject d1 = danAttr.getJSONObject("d1");
            JSONObject d2 = danAttr.getJSONObject("d2");
            JSONObject d3 = danAttr.getJSONObject("d3");
            for (String k : d1.keySet()) {
                int max = petData.getMaxPetDanAttr(k, 1);
                int v = d1.getInteger(k);
                if (v > max) v = max;
                base.put(k, base.getFloat(k) + v);
            }
            for (String k : d2.keySet()) {
                int max = petData.getMaxPetDanAttr(k, 2);
                int v = d2.getInteger(k);
                if (v > max) v = max;
                base.put(k, base.getFloat(k) + v);
            }
            for (String k : d3.keySet()) {
                int max = petData.getMaxPetDanAttr(k, 3);
                int v = d3.getInteger(k);
                if (v > max) v = max;
                base.put(k, base.getFloat(k) + v);
            }
        }
        //计算技能
        JSONArray jn = role.getJSONObject("attr").getJSONArray("skill");
        if (jn != null) {
            //固定值类型的计算一遍（基数），非固定值的类型计算一遍（增量）
            for (Object obj : jn) {
                if (obj == null) continue;
                JSONObject jb = (JSONObject) obj;
                if (jb.getString("key") == null) continue;
                //获取技能的加成属性
                JSONArray arr = skillData.getAttrs(jb.getString("key"));
                for (Object a : arr) {
                    JSONObject aa = (JSONObject) a;
                    //不是固定值的去掉
                    if (aa.getInteger("valueType") == 1) continue;
                    String attr = aa.getString("name");
                    //去掉是5个基础属性的
                    if (roleUtils.isBaseProp(attr)) continue;
                    float v = skillData.count(jb.getInteger("lv"), aa);
                    base.put(attr, base.getFloat(attr) + v);
                }
            }
        }
        //由某个属性加持另一个属性
        if (jn != null) {
            //固定值类型的计算一遍（基数），非固定值的类型计算一遍（增量）
            for (Object obj : jn) {
                if (obj == null) continue;
                JSONObject jb = (JSONObject) obj;
                if (jb.getString("key") == null) continue;
                JSONObject aTob = skillData.getAtoBAttr(jb.getString("key"));
                if (aTob == null) continue;
                if (aTob.getString("bKey").equals("wf&ff")) {
                    float t = base.getFloat(aTob.getString("aKey")) * aTob.getFloat("k");
                    base.put("wf", base.getFloat("wf") + t);
                    base.put("ff", base.getFloat("ff") + t);
                } else {
                    base.put(aTob.getString("bKey"),
                            base.getFloat(aTob.getString("bKey")) +
                                    (base.getFloat(aTob.getString("aKey")) * aTob.getFloat("k")));
                }
            }
        }
        //至此固定的属性基数已经计算完成，开始计算增益
        String[] rateKeys = {"max_xue", "max_lan",
                "wg", "fg", "wf", "ff",
                "mz", "sd", "bj", "css",
                "bjkx", "hskx", "hlkx", "lxkx"};
        //存储每个属性的增益比例
        JSONObject rateMap = new JSONObject();
        for (String k : rateKeys) {
            rateMap.put(k, 1);
        }
        if (jn != null) {
            //至此固定的属性基数已经计算完成
            //JSONObject copyBase = JSON.parseObject(JSON.toJSONString(base));
            for (Object obj : jn) {
                if (obj == null) continue;
                JSONObject jb = (JSONObject) obj;
                if (jb.getString("key") == null) continue;
                //获取技能的加成属性
                JSONArray arr = skillData.getAttrs(jb.getString("key"));
                for (Object a : arr) {
                    JSONObject aa = (JSONObject) a;
                    //不是比例值的去掉
                    if (aa.getInteger("valueType") != 1) continue;
                    String attr = aa.getString("name");
                    //去掉是5个基础属性的
                    if (roleUtils.isBaseProp(attr)) continue;
                    /*float v = skillData.countByK(jb.getInteger("lv"), aa, copyBase);
                    base.put(attr, base.getFloat(attr) + v);*/
                    rateMap.put(attr, rateMap.getFloat(attr) +
                            skillData.count(jb.getInteger("lv"), aa));
                }
            }
        }
        //计算最终增益后的结果
        for (String p : rateKeys) {
            base.put(p, base.getFloat(p) * rateMap.getFloat(p));
        }

        float xue = prop.getFloat("xue");
        if (xue > base.getFloat("max_xue")) {
            xue = base.getFloat("max_xue");
        }
        base.put("xue", xue);
        float lan = prop.getFloat("lan");
        if (lan > base.getFloat("max_lan")) {
            lan = base.getFloat("max_lan");
        }
        base.put("lan", lan);
        //对属性小于0的处理
        for (String k : base.keySet()) {
            if (base.get(k) == null) {
                System.err.println("宠物计算属性出现空 k：" + k);
                System.err.println("role：" + role);
            }
            float v = base.getFloat(k);
            if (v < 0) v = 0f;
            base.put(k, v);
        }
        return base;
    }

    /**
     * 放生宠物
     */
    public result abandonPet(JSONObject obj,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (strUtils.isNull(obj.get("Id"))) return new result(0);
        return new result(200, remPet(obj.getString("Id"), name, con));
    }

    public int remPet(String Id, String name, DefaultSqlSession con) {
        JSONArray list = getList(name, con);
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            if (Id.equals(item.getString("Id"))) {
                list.remove(l);
                return savePetList(list, name, con);
            }
        }
        return 0;
    }

    /**
     * 保存布阵时使用，更新出战状态，id为null表示没有出战宠物
     */
    public void setPetFightStatusByFormation(String Id, user user, DefaultSqlSession con) {
        JSONArray list = getList(user.name, con);
        setFightByPetId(list, Id, user);
        savePetList(list, user.name, con);
    }

    /**
     * 设置指定id的宠物为出战状态
     */
    private int setFightByPetId(JSONArray list, String petId, user user) {
        boolean b = false;
        for (Object l : list) {
            JSONObject temp = (JSONObject) l;
            if (temp.getString("Id").equals(petId)) {
                //判断出战等级是否足够，是否超过10级
                JSONObject pd = petData.get(temp.getString("key"), user.projRootDir);
                if ((pd.getInteger("fightLv") > user.msg.getInteger("lever")) ||
                        (temp.getInteger("lever") > user.msg.getInteger("lever") + 10)) {
                    return 0;
                }
                temp.put("isFight", 1);
                JSONObject m = new JSONObject();
                m.put("key", temp.getString("key"));
                if (temp.getInteger("growLv") >= 8) m.put("isX8", true);
                else m.put("isX8", false);
                user.msg.put("pet", m);
                b = true;
            } else {
                temp.put("isFight", 0);
            }
        }
        if (!b) {
            //不存在出战宠物时
            user.msg.put("pet", null);
        }
        return 1;
    }

    /**
     * 设置宠物出战状态
     */
    public result updateIsFightById(JSONObject obj,
                                    @paramsAnno(key = "user") user user,
                                    @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray list = getList(name, con);
        int isFight = obj.getInteger("isFight");
        if (isFight == 1) {//将该id对应的宠物设置为已出战
            int status = setFightByPetId(list, obj.getString("Id"), user);
            if (status == 0) return new result(224);
            JSONObject team = startBef.teamService.getTeamByName(name);
            if (team != null) {
                //重新安排站位
                startBef.teamService.reloadTeamFormation(team);
            } else {
                //修改数据库的站位（非组队）
                startBef.teamService.updateSelfFormation(name, con);
            }
        } else {//未出战
            for (Object l : list) {
                JSONObject temp = (JSONObject) l;
                if (obj.getString("Id").equals(temp.getString("Id"))) {
                    temp.put("isFight", 0);
                    user.msg.put("pet", null);
                    break;
                }
            }
            JSONObject team = startBef.teamService.getTeamByName(name);
            if (team != null) {
                //重新安排站位
                startBef.teamService.reloadTeamFormation(team);
            } else {
                //清理该站位
                startBef.teamService.updateSelfFormation(name, con);
            }

        }
        //重新计算战力
        startBef.orderService.countZlOrder(name);
        return new result(200, savePetList(list, name, con));
    }

    /**
     * 保存宠物列表
     */
    public Integer savePetList(JSONArray list, String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.updatePetByName(JSON.toJSONString(list), name) ? 1 : 0;
    }

    /**
     * 查看玩家出战宠物信息
     */
    public result getPlayerPet(JSONObject obj,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        String playerName = obj.getString("playerName");
        if (strUtils.isNull(playerName)) return new result(0);
        if (!staticCollection.userIsOnline(playerName)) return new result(831);
        Object o = getIsFightPet(obj.getString("playerName"), con);
        JSONArray list = new JSONArray();
        if (o != null) {
            JSONObject a = (JSONObject) o;
            a.put("xrmf", startBef.manService.getXrmf(obj.getString("playerName"), con));
            a.put("petEquip", startBef.packageService.getPetEquip(obj.getString("playerName"), con));
            list.add(a);
        }
        return new result(200, list);
    }

    /**
     * 由id查看玩家宠物
     */
    public result getPlayerPetById(JSONObject obj,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        JSONArray rlist = new JSONArray();
        JSONArray list = getListView(obj.getString("playerName"), con);
        for (Object l : list) {
            JSONObject o = (JSONObject) l;
            if (o.getString("Id").equals(obj.getString("Id"))) {
                JSONObject xrmf = startBef.manService.getXrmf(obj.getString("playerName"), con);
                o.put("xrmf", xrmf);
                rlist.add(o);
                break;
            }
        }
        return new result(200, rlist);
    }

    /**
     * 不叠加仙人模式时的宠物
     */
    public Object getPetViewById(String Id, String name, DefaultSqlSession con) {
        Object obj = null;
        JSONArray list = getListView(name, con);
        if (list == null) return obj;
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            if (item.getString("Id").equals(Id)) {
                obj = l;
                break;
            }
        }
        return obj;
    }

    public JSONObject getPetById(String Id, String name, DefaultSqlSession con) {
        JSONObject obj = null;
        JSONArray list = getList(name, con);
        if (list == null) return obj;
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            if (item.getString("Id").equals(Id)) {
                obj = (JSONObject) l;
                break;
            }
        }
        return obj;
    }

    /**
     * 获取出战宠物
     */
    public Object getIsFightPet(String name, DefaultSqlSession con) {
        Object obj = null;
        JSONArray list = getListView(name, con);
        for (Object l : list) {
            JSONObject item = (JSONObject) l;
            if (item.getInteger("isFight") == 1) {
                obj = l;
                break;
            }
        }
        return obj;
    }

    /**
     * 获取宠物列表
     */
    public JSONArray getList(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectPetByName(name);
        if (list.size() == 0) return null;
        return list.get(0).getJSONArray("pet");
    }

    /**
     * 获取视图
     */
    public JSONArray getListView(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectPetByNameNoForUpdate(name);
        if (list.size() == 0) return null;
        return list.get(0).getJSONArray("pet");
    }
}
