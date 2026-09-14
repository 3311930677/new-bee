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
import my.gameUtils.roleUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

import static my.utils.staticCollection.*;

public class rewardService {
    /**
     * 仙元丹自选礼包兑换指定仙元丹
     */
    public result xianYuanDanExchange(JSONObject j,
                                      @paramsAnno(key = "user") user user,
                                      @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int index = j.getInteger("type");
        if (index < 0 || index > 9) return new result(0);
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000301", 1, name, con) != 1) {
            return new result(0);
        }
        String k3 = "101100" + (index + 20);
        JSONArray rs = new JSONArray();
        rewardUtils.getGoodsReward(k3, 1, 1, rs);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    /**
     * 高级宠物技能自选兑换高级技能
     */
    public result gjPetSklExchange(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        if (true) return new result(0);
        final String name = user.name;
        String sklKey = j.getString("key");
        //判断兑换的key是否为允许的技能
        if (!isAllowedExchangePetSkl(sklKey)) {
            return new result(0);
        }
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000303", 1, name, con) != 1) {
            return new result(0);
        }
        JSONArray rs = rewardUtils.getGoodsReward(sklKey, 1, 0);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    /**
     * 小黄毛礼包
     */
    public JSONArray openXiaoHuangMaoBox(String name, DefaultSqlSession con) {
        String key = null;
        int num = 1;
        String[] arr = {"10000109", "10000159", "10000108", "10000260", "10000261"};
        int[] nums = {60, 10, 1, 1, 3};
        int index = strUtils.getRandom(0, arr.length);
        key = arr[index];
        num = nums[index];

        JSONArray rs = rewardUtils.getGoodsReward(key, num, 0);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return rs;
    }

    /**
     * 魔龙残影等五选一
     */
    public result shenYingExchange(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String dhKey = j.getString("key");
        String[] arr = {"10000284", "10000295", "10000296", "10000297", "10000298"};
        boolean b = false;
        for (String a : arr) {
            if (dhKey.equals(a)) {
                b = true;
                break;
            }
        }
        if (!b) return new result(0);
        //消耗一个神影自选
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000293", 1, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray list = rewardUtils.getGoodsReward(dhKey, 1, 0);
        list = startBef.rewardService.saveRewards(list, name, con);
        return new result(200, list);
    }

    public JSONArray openGaGaXiangBox(String name, DefaultSqlSession con) {
        String key = null;
        int num = 1;
        if (strUtils.isHappend(0, 1000, 0.2f)) {
            key = "10000293";
        } else {
            String[] arr = {"10000260", "10000261", "10000111", "10000143"};
            int[] nums = {1, 3, 30, 60};
            int index = strUtils.getRandom(0, arr.length);
            key = arr[index];
            num = nums[index];
        }

        JSONArray rs = rewardUtils.getGoodsReward(key, num, 0);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return rs;
    }

    /**
     * 技能碎片兑换
     */
    public result sklSpExchange(JSONObject j,
                                @paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String xhKey = j.getString("key");
        String dhKey = null;
        if (xhKey.equals("10000289")) {
            dhKey = "10000112";
        } else if (xhKey.equals("10000290")) {
            List<String> skls = new ArrayList<>();
            goodsData.getManTdSkillGoodsData(skls);
            Collections.shuffle(skls);
            dhKey = skls.get(0);
        } else if (xhKey.equals("10000291")) {
            List<String> skls = new ArrayList<>();
            if (strUtils.isHappend(0, 1000, 0.1f)) {
                goodsData.getAllPet4SkillGoodsData(skls);
            }
            goodsData.getAllPet2SkillGoodsData(skls);
            Collections.shuffle(skls);
            dhKey = skls.get(0);
        } else return new result(0);

        if (startBef.packageService.cutPlayerGoodsNumByKey(xhKey, 50, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rs = rewardUtils.getGoodsReward(dhKey, 1, 0);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    /**
     * 魔龙残影兑换名匠之魂
     */
    public result exchangByMlcy(@paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000284", 1, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rs = rewardUtils.getGoodsReward("10000236", 1000, 0);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    /**
     * 碎玉帛兑换道具
     */
    public result exchangBySyb(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String dhKey = j.getString("key");
        int price = getSybPrice(dhKey);
        if (price == 0) return new result(0);
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000180", price, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rs = rewardUtils.getGoodsReward(dhKey, 1, 1);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    private int getSybPrice(String key) {
        if (key.equals("10000104")) return 9;
        else if (key.equals("10000105")) return 38;
        else if (key.equals("10000175")) return 120;
        else if (key.equals("10000111")) return 120;
        else if (key.equals("10000106")) return 168;
        return 0;
    }

    public JSONArray useYinPiao(int value, String name, DefaultSqlSession con) {
        JSONArray rs = rewardUtils.getYinPiaoReward(value);
        return startBef.rewardService.saveRewards(rs, name, con);
    }

    public JSONArray openQiangZhuangGift(String name, DefaultSqlSession con) {
        String key = null;
        int num = 1;
        if (strUtils.isHappend(0, 1000, 0.9f)) {
            String[] arr = {"10000150", "10000109", "10000159",
                    "10000111", "10000143"};
            int[] arr1 = {1, 50, 2, 30, 60};
            int index = strUtils.getRandom(0, arr.length);
            key = arr[index];
            num = arr1[index];
        } else {
            String[] arr = {"10000160", "10000108"};
            int[] arr1 = {1, 1};
            int index = strUtils.getRandom(0, arr.length);
            key = arr[index];
            num = arr1[index];
        }
        JSONArray rs = rewardUtils.getGoodsReward(key, num, 0);
        rewardUtils.getGoodsReward("10000106", 20, 0, rs);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return rs;
    }

    /**
     * 兑换宠物装备
     */
    public result exchangePetEquip(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        if (key == null || !strUtils.isMatch(key, "1016([0-9]{4})")) {
            return new result(0);
        }
        int xhNum = 1;
        String xhKey = null;
        if (key.equals("10160000")) {
            xhNum = 10;
            xhKey = "10000234";
        } else if (key.equals("10160001")) {
            xhNum = 25;
            xhKey = "10000234";
        } else if (key.equals("10160002")) {
            xhNum = 12;
            xhKey = "10000235";
        } else if (key.equals("10160003")) {
            xhNum = 20;
            xhKey = "10000235";
        } else return new result(0);

        if (startBef.packageService.cutPlayerGoodsNumByKey(xhKey, xhNum, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rs = rewardUtils.getGoodsReward(key, 1, 1);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    /**
     * 玄铁残骸兑换千年玄铁
     */
    public result exchangeQNXT(@paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000219", 5, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rs = rewardUtils.getGoodsReward("10000151", 1, 1);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    /**
     * 名匠之魂兑换副本道具
     */
    public result exchangeFbGd(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int index = j.getInteger("index");
        if (index > 6 || index < 0) return new result(0);
        String[] arr = {
                "10000152", "10000155", "10000153", "10000154", "10000157", "10000151", "10000161"
        };
        int[] brr = {10, 10, 10, 10, 20, 200, 500};
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000236", brr[index], name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rs = rewardUtils.getGoodsReward(arr[index], 1, 1);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    public JSONArray openXianDanLiBao(String key, String name, DefaultSqlSession con) {
        int index = Integer.parseInt(key) - 10000237;
        String k1 = "1011000" + index;
        String k2 = "101100" + (index + 10);
        String k3 = "101100" + (index + 20);
        JSONArray rs = new JSONArray();
        rewardUtils.getGoodsReward(k1, 1, 1, rs);
        rewardUtils.getGoodsReward(k2, 1, 1, rs);
        rewardUtils.getGoodsReward(k3, 1, 1, rs);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return rs;
    }

    /**
     * 兑换仙丹礼包
     */
    public result exchangeXianDanLiBao(JSONObject j,
                                       @paramsAnno(key = "user") user user,
                                       @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String spKey = j.getString("key");
        String[] sp = {"10000247", "10000248", "10000249", "10000250", "10000251",
                "10000252", "10000253", "10000254", "10000255", "10000256",};
        int index = -1;
        for (int i = 0; i < sp.length; i++) {
            if (spKey.equals(sp[i])) {
                index = i;
                break;
            }
        }
        if (index == -1) return new result(0);
        String[] lb = {"10000237", "10000238", "10000239", "10000240", "10000241",
                "10000242", "10000243", "10000244", "10000245", "10000246",};
        String lbKey = lb[index];
        if (startBef.packageService.cutPlayerGoodsNumByKey(spKey, 3, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rs = rewardUtils.getGoodsReward(lbKey, 1, 1);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    public JSONArray openXiuFuGift(String name, DefaultSqlSession con) {
        JSONArray rs = rewardUtils.getGoodsReward("10000111", 398, 0);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return rs;
    }

    public JSONArray openGongXiangGift(String name, DefaultSqlSession con) {
        JSONArray rs = rewardUtils.getGoodsReward("10000143", 868, 0);
        rs = startBef.rewardService.saveRewards(rs, name, con);
        return rs;
    }

    /**
     * 节日礼物
     */
    public result gainHolidayGift(@paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (!strUtils.isInDay("2026-03-03 00:00:00", "2026-03-06 23:59:00")) {
            return new result(696);
        }
        if (user.msg.getInteger("lever") < 90) return new result(0);
        //验证是否领取
        activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = ac.getHolidayGift(name);
        if (list.size() == 0) {
            ac.addHolidayGift(name);
            list = ac.getHolidayGift(name);
        }
        int g0 = list.get(0).getInteger("g0");
        if (g0 == 1) {
            return new result(213);
        }
        if (ac.updateHolidayGift(name, "1")) {
            JSONArray resList = rewardUtils.getTaleReward(10 * 10000L);
            resList = startBef.rewardService.saveRewards(resList, name, con);
            return new result(200, resList);
        }
        return new result(0);
    }

    /**
     * 兑换潜力符石
     */
    public result exchangeQlfs(@paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断陨石碎片是否够
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000188", 100, name, con) != 1) {
            return new result(0);
        }
        //兑换潜力符石
        JSONArray resList = rewardUtils.getGoodsReward("10000114", 1, 1);
        resList = startBef.rewardService.saveRewards(resList, name, con);
        return new result(200, resList);
    }

    /**
     * 兑换神兽召唤令（魔龙残影这些+20金）
     */
    public result exchangeShenShou(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int type = j.getInteger("type");
        if (type > 4 || type < 0) return new result(0);
        String xhKey = null;
        String exKey = null;
        if (type == 0) {
            xhKey = "10000284";
            exKey = "10000133";
        } else if (type == 1) {
            xhKey = "10000295";
            exKey = "10000134";
        } else if (type == 2) {
            xhKey = "10000296";
            exKey = "10000136";
        } else if (type == 3) {
            xhKey = "10000297";
            exKey = "10000137";
        } else if (type == 4) {
            xhKey = "10000298";
            exKey = "10000142";
        } else return new result(0);
        //消耗道具
        if (startBef.packageService.cutPlayerGoodsNumByKey(xhKey, 1, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //消耗金票
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000000", 20, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rs = rewardUtils.getGoodsReward(exKey, 1, 1);
        startBef.rewardService.saveRewards(rs, name, con);
        return new result(200, rs);
    }

    /**
     * 天地技能箱子
     */
    public JSONArray openTianDiSkillBox(String name, DefaultSqlSession con) {
        JSONArray rs = null;
        List<String> list = new ArrayList<>();
        goodsData.getManTdSkillGoodsData(list);
        Collections.shuffle(list);
        rs = rewardUtils.getGoodsReward(list.get(0), 1, 0);
        startBef.rewardService.saveRewards(rs, name, con);
        return rs;
    }

    /**
     * 宠物/人物技能箱子
     * type 0人物 1宠物
     */
    public JSONArray openPetOrManSkillBox(int type, String name, DefaultSqlSession con) {
        JSONArray rs = null;
        List<String> list = new ArrayList<>();
        if (type == 0) {
            goodsData.getMan2SkillGoodsData(list);
            goodsData.getMan4SkillGoodsData(list);
        } else {
            goodsData.getAllPet2SkillGoodsData(list);
            goodsData.getAllPet4SkillGoodsData(list);
        }
        Collections.shuffle(list);
        rs = rewardUtils.getGoodsReward(list.get(0), 1, 0);
        startBef.rewardService.saveRewards(rs, name, con);
        return rs;
    }

    /**
     * vip礼包
     */
    public JSONArray getVipGift(int lv, String name, DefaultSqlSession con) {
        JSONArray rewards = rewardUtils.getVipGift(lv);
        startBef.rewardService.saveRewards(rewards, name, con);
        return rewards;
    }

    /**
     * 累计档礼包
     */
    public JSONArray getLeiJiGift(int lv, String name, DefaultSqlSession con) {
        JSONArray rewards = rewardUtils.getLeiJiGift(lv);
        startBef.rewardService.saveRewards(rewards, name, con);
        return rewards;
    }

    /**
     * 人物三技能合一技能
     */
    public result manSklThreeToOne(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray ens = j.getJSONArray("list");
        String sklKey = j.getString("key");
        //判断兑换的key是否为允许的技能
        if (!isAllowedExchangeManSkl(sklKey)) {
            return new result(0);
        }
        int sum = 0;
        //判断key是否为允许兑换的四字技能，数量小于0
        for (int i = 0; i < ens.size(); i++) {
            JSONObject a = ens.getJSONObject(i);
            if (a.getInteger("num") <= 0 ||
                    !isAllowedExchangeManSkl2(a.getString("key"))) return new result(0);
            sum += a.getInteger("num");
        }
        //只要累计的数量不等于3就不允许兑换
        if (sum != 3) return new result(0);
        //减少数量
        for (int i = 0; i < ens.size(); i++) {
            JSONObject a = ens.getJSONObject(i);
            String key = a.getString("key");
            int num = a.getInteger("num");
            if (startBef.packageService.cutPlayerGoodsNumByKey(key, num, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        JSONArray rs = rewardUtils.getGoodsReward(sklKey, 1, 0);
        startBef.rewardService.saveRewards(rs, name, con);
        startBef.logService.insertOp("6", name, "[仙绝三换一] " + ens + "=>" + sklKey, null, "1");

        return new result(200, rs);
    }

    public result petSklTwoToOne(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray ens = j.getJSONArray("list");

        int sum = 0;
        //判断key是否为允许兑换的四字技能，数量小于0
        for (int i = 0; i < ens.size(); i++) {
            JSONObject a = ens.getJSONObject(i);
            if (a.getInteger("num") <= 0 ||
                    !isAllowedExchangePetErZiSkl(a.getString("key"))) return new result(0);
            sum += a.getInteger("num");
        }
        //只要累计的数量不等于3就不允许兑换
        if (sum != 2) return new result(0);
        //减少数量
        for (int i = 0; i < ens.size(); i++) {
            JSONObject a = ens.getJSONObject(i);
            String key = a.getString("key");
            int num = a.getInteger("num");
            if (startBef.packageService.cutPlayerGoodsNumByKey(key, num, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        //随机一个二字
        List<String> arr = new ArrayList<>();
        goodsData.getAllPet2SkillGoodsData(arr);
        Collections.shuffle(arr);
        String sklKey = arr.get(0);
        JSONArray rs = rewardUtils.getGoodsReward(sklKey, 1, 0);
        startBef.rewardService.saveRewards(rs, name, con);
        startBef.logService.insertOp("6", name, "[宠物二字二换一] " + ens + "=>" + sklKey, null, "1");

        return new result(200, rs);
    }

    /**
     * 宠物三技能合一技能
     */
    public result petSklThreeToOne(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray ens = j.getJSONArray("list");
        String sklKey = j.getString("key");
        //判断兑换的key是否为允许的技能
        if (!isAllowedExchangePetSkl(sklKey)) {
            return new result(0);
        }
        int sum = 0;
        //判断key是否为允许兑换的四字技能，数量小于0
        for (int i = 0; i < ens.size(); i++) {
            JSONObject a = ens.getJSONObject(i);
            if (a.getInteger("num") <= 0 ||
                    !isAllowedExchangePetSkl(a.getString("key"))) return new result(0);
            sum += a.getInteger("num");
        }
        //只要累计的数量不等于3就不允许兑换
        if (sum != 3) return new result(0);
        //减少数量
        for (int i = 0; i < ens.size(); i++) {
            JSONObject a = ens.getJSONObject(i);
            String key = a.getString("key");
            int num = a.getInteger("num");
            if (startBef.packageService.cutPlayerGoodsNumByKey(key, num, name, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }
        JSONArray rs = rewardUtils.getGoodsReward(sklKey, 1, 0);
        startBef.rewardService.saveRewards(rs, name, con);
        startBef.logService.insertOp("6", name, "[宠物四字三换一] " + ens + "=>" + sklKey, null, "1");

        return new result(200, rs);
    }

    private boolean isAllowedExchangePetErZiSkl(String k) {
        String[] list = {
                "100210010210", "100210010211", "100210010212", "100210010213", "100210010214",
                "100210010215", "100210010216", "100210010217", "100210010218", "100210010219",
                "100210010220", "100210010221", "100210010222", "100210010223", "100210010224",
                "100210010225", "100210010226", "100210010227", "100210010228", "100210010229",
                "100210010230", "100210010231", "100210010232", "100210010233", "100210010234",
                "100210010235", "100210010236", "100210010237", "100210010238", "100210010239",
                "100210010240", "100210010241", "100210010242", "100210010243", "100210010244",
                "100210010250", "100210010251", "100210010252", "100210010253", "100210010254",
                "100210010255", "100210010256", "100210010257", "100210010258", "100210010259",
                "100210010260", "100210010261", "100210010262", "100210010263", "100210010264",
        };
        for (String s : list) {
            if (s.equals(k)) return true;
        }
        return false;
    }

    private boolean isAllowedExchangePetSkl(String k) {
        String[] list = {
                "100210010265", "100210010266", "100210010267", "100210010268", "100210010269",
                "100210010270", "100210010271", "100210010272", "100210010273", "100210010276",
                "100210010277", "100210010278", "100210010279", "100210010280", "100210010281",
                "100210010282", "100210010283", "100210010284", "100210010287",
                "100210010288", "100210010289", "100210010291", "100210010294",
                "100210010295", "100210010296", "100210010298", "100210010308",
                "100210010309", "100210010310", "100210010311", "100210010312", "100210010313",
                "100210010180", "100210010183",
        };
        for (String s : list) {
            if (s.equals(k)) return true;
        }
        return false;
    }

    /**
     * 可兑换的四字
     */
    private boolean isAllowedExchangeManSkl(String k) {
        String[] list = {
                "100210030029", "100210030030", "100210030031",
                "100210030032", "100210030033", "100210030034", "100210030035", "100210030036",
                "100210030037", "100210030040", "100210030043", "100210030044", "100210030045", "100210030046",
                "100210030047", "100210030049", "100210030050", "100210030070", "100210030072"
        };
        for (String s : list) {
            if (s.equals(k)) return true;
        }
        return false;
    }

    /**
     * 兑换时消耗的二字
     */
    private boolean isAllowedExchangeManSkl2(String k) {
        String[] list = {
                "100210030054", "100210030055", "100210030056",
                "100210030057", "100210030058", "100210030059", "100210030060", "100210030061",
                "100210030062", "100210030063", "100210030064", "100210030065", "100210030066", "100210030067",
                "100210030068", "100210030069", "100210030071", "100210030073"
        };
        for (String s : list) {
            if (s.equals(k)) return true;
        }
        return false;
    }

    /**
     * 活动大使处神技礼盒自选神技兑换
     */
    public result chooseSkillGain(JSONObject j,
                                  @paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int index = j.getInteger("index");
        String[] arr = {
                "100210010286", "100210010292", "100210010293",
                "100210010297", "100210010274", "100210010275",
                "100210010299", "100210010300",
                "100210010301", "100210010302", "100210010303",
        };
        if (index > arr.length || index < 0) return new result(0);
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000266", 1, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rs = rewardUtils.getGoodsReward(arr[index], 1, 0);
        saveRewards(rs, name, con);
        return new result(200, rs);
    }

    /**
     * 魔龙礼包
     */
    public JSONArray getMoLongGift(String name, DefaultSqlSession con) {
        JSONArray rewards = new JSONArray();
        rewardUtils.getGoodsReward("10000133", 1, 1, rewards);
        rewardUtils.getGoodsReward("10000266", 2, 1, rewards);
        rewardUtils.getGoodsReward("10000261", 4, 1, rewards);
        startBef.rewardService.saveRewards(rewards, name, con);
        return rewards;
    }

    /**
     * 锻造礼包
     */
    public JSONArray getDuanZaoGift(String name, DefaultSqlSession con) {
        JSONArray rewards = rewardUtils.getDuanZaoGift();
        startBef.rewardService.saveRewards(rewards, name, con);
        return rewards;
    }

    /**
     * 随机高级种子
     */
    public JSONArray rdGjZhongzi(String name, DefaultSqlSession con) {
        JSONArray rewards = rewardUtils.getGoodsReward(rewardUtils.getRandomZhongzi(3), 1, 1);
        startBef.rewardService.saveRewards(rewards, name, con);
        return rewards;
    }

    /**
     * 开福神礼袋
     */
    public JSONArray exchangeFuShenLiDai(String name, DefaultSqlSession con) {
        JSONArray rewards = rewardUtils.getGoodsReward("10000107", 1, 1);
        startBef.rewardService.saveRewards(rewards, name, con);
        return rewards;
    }

    /**
     * 兑换银两
     */
    public JSONArray exchangeTale(int v, String name, DefaultSqlSession con) {
        JSONArray rewards = rewardUtils.getTaleReward(v);
        rewards = startBef.rewardService.saveRewards(rewards, name, con);
        return rewards;
    }

    /**
     * 开技能礼包
     */
    public JSONArray openSkillGift(int type, String name, DefaultSqlSession con) {
        JSONArray rewards = rewardUtils.openSkillGift(type);
        startBef.rewardService.saveRewards(rewards, name, con);
        if (type == 0) rewardUtils.noticeReward(4, name, rewards);
        else if (type == 1) rewardUtils.noticeReward(5, name, rewards);
        return rewards;
    }

    /**
     * 打开储钱罐
     */
    public JSONArray openChuQianGuan(String name, DefaultSqlSession con) {
        long[] arr = {
                50000, 100000, 150000
        };
        int index = strUtils.getRandom(0, arr.length);
        JSONArray rewards = rewardUtils.getTaleReward(arr[index]);
        saveRewards(rewards, name, con);
        return rewards;
    }

    /**
     * 打开美人香
     */
    public JSONArray openMeiRenXiang(String name, DefaultSqlSession con) {
        String[] arr = {
                "10000106", "10000184", "10000183", "10000208", "10000209", "10000210",
                "10000030", "10000031", "10000120", "10000128", "10000259", "100110060003",
        };
        int index = strUtils.getRandom(0, arr.length);
        JSONArray rewards = rewardUtils.getGoodsReward(arr[index], 1, 1);
        saveRewards(rewards, name, con);
        return rewards;
    }



    //宴会奖励是否发送了
    private static boolean yhRewardIsSend = false;

    /**
     * 帮派宴会在线送礼
     */
    public void sendGiftByBpYh() {
        if (yhRewardIsSend) return;
        yhRewardIsSend = true;
        staticCollection.putTask(() -> {
            try {
                for (String sbh : userMap.keySet()) {
                    try {
                        user u = userMap.get(sbh);
                        if (u.getPos() == null
                                || u.getPos().getString("map") == null ||
                                !u.getPos().getString("map").contains("bp_")) {
                            continue;
                        }
                        JSONArray list = null;
                        if (strUtils.numInArea(31, 0, 100)) {
                            //4级宝石
                            String key = strUtils.getRandom(4030, 4040) + "";
                            list = rewardUtils.getGoodsReward(key, 1, 1);
                        } else {
                            list = rewardUtils.getBoxReward();
                        }
                        if (list != null) {
                            DefaultSqlSession con = null;
                            try {
                                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                                JSONArray l = saveRewards(list, u.name, con);
                                mybatisConfig.commit(con);
                                ChannelSupervise.noticeClientByName(l, u.name, "10000");
                            } catch (Exception e) {
                                e.printStackTrace();
                                mybatisConfig.rollback(con);
                            } finally {
                                mybatisConfig.close(con);
                            }
                        }
                    } catch (Exception e) {
                        loggerUtils.error("帮派宴会在线送礼活动:" + e.getMessage(), rewardService.class);
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
        staticCollection.putTask(() -> {
            try {
                yhRewardIsSend = false;
            } catch (Exception e) {
                e.printStackTrace();
            }
        }, 70, TimeUnit.SECONDS);
    }

    /**
     * 开摸金校尉宝箱
     */
    public JSONArray openMjxwBox(int i, String name, DefaultSqlSession con) {
        JSONArray list = rewardUtils.getMjxwRewardsKey(i);
        return saveRewards(list, name, con);
    }


    /**
     * 获取藏宝图奖励
     */
    public JSONArray getCBTReward(String name, int lv, DefaultSqlSession con) {
        JSONArray list = rewardUtils.getCBTReward(lv);
        return saveRewards(list, name, con);
    }

    /**
     * 查看任务奖励
     */
    public result findTaskRewards(JSONObject j,
                                  @paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String taskKey = j.getString("key");
        return new result(200, rewardUtils.getRewardByTaskKey(taskKey, con, name));
    }

    /**
     * 打开红包
     */
    public result openHongbao(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = j.getString("Id");
        int type = j.getInteger("type");
        //todo:分为世界、帮派
        JSONObject obj = null;
        if (type == 0) {
            obj = hongbaoList.get(Id);
        } else {
            String bpId = user.msg.getString("bpId");
            List<JSONObject> al = bpHongbaoList.get(bpId);
            for (JSONObject a : al) {
                if (a.getString("Id").equals(Id)) {
                    obj = a;
                    break;
                }
            }
        }
        if (obj == null) return new result(0);
        JSONArray pList = obj.getJSONArray("playerList");
        for (Object p : pList) {
            if (name.equals(p)) {
                //领取过
                return new result(200, 0);
            }
        }
        //无余额
        if (obj.getInteger("money") <= 0) {
            return new result(200, -1);
        }
        //放入到领取的名单
        pList.add(name);
        //随机一个20%一下的结果
        float r = strUtils.getRandom(1, 21) / 100f;
        //减去得到的余额
        float now = obj.getFloat("money") - obj.getFloat("sumMoney") * r;
        int moneyType = obj.getInteger("moneyType");
        float get;
        if (now < 0) {
            //最多拿到剩余的钱
            get = obj.getFloat("money");
        } else {
            //可以拿到这个百分比的钱
            get = obj.getFloat("sumMoney") * r;
        }
        obj.put("money", obj.getFloat("money") - get);
        //没有剩余了
        if (obj.getInteger("money") <= 0) {
            if (type == 0) {
                hongbaoList.remove(Id);
            } else {
                String bpId = user.msg.getString("bpId");
                List<JSONObject> al = bpHongbaoList.get(bpId);
                for (int i = 0; i < al.size(); i++) {
                    if (al.get(i).getString("Id").equals(Id)) {
                        al.remove(i);
                        break;
                    }
                }
            }

        }
        //通知钱奖励
        JSONArray rs = null;
        if (moneyType == 0) {
            rs = rewardUtils.getGoldReward((int) get);
        } else {
            rs = rewardUtils.getTaleReward((int) get);
        }
        saveRewards(rs, name, con);
        if (!strUtils.isNull(obj.get("talk"))) {
            startBef.chatService.putHongBaoKlMsg(obj.getString("talk"), user);
        }
        return new result(200, rs);
    }

    /**
     * 发红包
     */
    public result sendHongbao(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int moneyType = j.getInteger("moneyType");
        long money = j.getLong("money");
        String talk = j.getString("talk");
        int type = j.getInteger("type");
        if (moneyType > 1 || moneyType < 0 || money <= 0 || name == null) {
            return new result(0);
        }
        if (talk.length() > 20) {
            talk = talk.substring(0, 20);
        }
        //判断余额是否充足
        if (startBef.manService.saveMoney(moneyType, -money, name, con) == 0) {
            return new result(0);
        }
        JSONObject obj = new JSONObject();
        obj.put("name", name);
        obj.put("money", money);
        obj.put("moneyType", moneyType);
        obj.put("sumMoney", money);//总的money
        obj.put("talk", talk);//口令
        obj.put("playerList", new JSONArray());//领取过的玩家列表
        String Id = strUtils.getId();
        obj.put("Id", Id);
        if (type == 0) {
            hongbaoList.put(Id, obj);
            JSONObject res = new JSONObject();
            res.put("name", name);
            res.put("type", 0);
            ChannelSupervise.noticeAllClient(res, "104");
            //startBef.chatService.putSysMsg("玩家 " + name + " 发来一个红包！");
            //通知所有玩家刷新红包列表
        } else {
            String bpId = user.msg.getString("bpId");
            List<JSONObject> al = bpHongbaoList.get(bpId);
            if (al == null) {
                bpHongbaoList.put(bpId, new ArrayList<>());
                al = bpHongbaoList.get(bpId);
            }
            al.add(obj);
            JSONObject res = new JSONObject();
            res.put("name", name);
            res.put("type", 1);
            ChannelSupervise.noticeAllBpMember(bpId, res, "104");
            //startBef.chatService.putBpMsg();
            //通知同帮派玩家刷新红包列表
        }

        //startBef.chatService.putMsgWithHb(Id, talk, user);
        return new result(200, 1);
    }

    /**
     * 发送系统红包
     */
    public void sendSystemHongbao(int money, int moneyType, String talk) {
        JSONObject obj = new JSONObject();
        obj.put("name", "系统");
        obj.put("money", money);
        obj.put("moneyType", moneyType);
        obj.put("sumMoney", money);//总的money
        obj.put("talk", talk);//口令
        obj.put("playerList", new JSONArray());//领取过的玩家列表
        String Id = strUtils.getId();
        hongbaoList.put(Id, obj);
        startBef.chatService.putMsgWithSysHb(Id, talk);
        //startBef.chatService.putSysMsg("系统发了一个大红包，土匪们快抢他！");
    }

    /**
     * 获取红包列表
     */
    public result getHongbaoList(JSONObject j,
                                 @paramsAnno(key = "user") user user) {
        final String name = user.name;
        int type = j.getInteger("type");
        JSONArray list = new JSONArray();
        if (type == 0) {
            ConcurrentHashMap<String, JSONObject> map = hongbaoList;
            for (String Id : map.keySet()) {
                JSONArray pList = map.get(Id).getJSONArray("playerList");
                int b = 0;
                for (Object p : pList) {
                    if (name.equals(p)) {
                        b = 1;//已领取
                        break;
                    }
                }
                //只需要name、moneyType、isGet
                JSONObject a = new JSONObject();
                a.put("Id", Id);
                a.put("name", map.get(Id).getString("name"));
                a.put("moneyType", map.get(Id).getString("moneyType"));
                a.put("isGet", b);
                a.put("talk", map.get(Id).getString("talk"));
                list.add(a);
            }
        } else {
            String bpId = user.msg.getString("bpId");
            List<JSONObject> al = bpHongbaoList.get(bpId);
            if (al == null) {
                bpHongbaoList.put(bpId, new ArrayList<>());
                al = bpHongbaoList.get(bpId);
            }
            for (int i = 0; i < al.size(); i++) {
                JSONObject obj = al.get(i);
                JSONArray pList = obj.getJSONArray("playerList");
                int b = 0;
                for (Object p : pList) {
                    if (name.equals(p)) {
                        b = 1;//已领取
                        break;
                    }
                }
                //只需要name、moneyType、isGet
                JSONObject a = new JSONObject();
                a.put("Id", obj.getString("Id"));
                a.put("name", obj.getString("name"));
                a.put("moneyType", obj.getString("moneyType"));
                a.put("isGet", b);
                a.put("talk", obj.getString("talk"));
                list.add(a);
            }
        }


        return new result(200, list);
    }

    /**
     * 获取积分奖励
     */
    public Integer getJFReward(int win, String name) {
        int num = 20;
        if (win == 1) {
            num = 50;
        }
        JSONArray list = rewardUtils.getJFReward(num);
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            if (startBef.rewardService.saveRewards(list, name, con) != null) {
                //通知玩家获得奖励
                ChannelSupervise.noticeClientByName(list, name, "10000");
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

    /**
     * 战斗奖励
     */
    public Integer getFightReward(JSONObject obj) {
        String projRootDir = obj.getString("projRootDir");
        String monsterKey = obj.getString("monsterKey");
        Integer monsterNum = obj.getInteger("monsterNum");

        JSONArray names = obj.getJSONArray("names");
        //血腥之地怪物
        if (monsterKey.contains("xxzd_")) {
            //是否在血腥时段
            if (!startBef.xxzdService.isOpenAc) return 1;
            //积分++
            DefaultSqlSession con = null;
            try {
                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                startBef.xxzdService.addJfByMon(1, names.get(0).toString(), con);
                JSONArray list = rewardUtils.getFightReward(names.get(0).toString(), monsterKey, monsterNum, projRootDir, con);
                list = saveRewards(list, names.get(0).toString(), con);
                mybatisConfig.commit(con);
                ChannelSupervise.noticeClientByName(list, names.get(0).toString(), "10000");
            } catch (Exception e) {
                e.printStackTrace();
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
            return 1;
        }

        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            for (Object name : names) {
                //因为可能队员开了双倍经验
                JSONArray list = rewardUtils.getFightReward(name.toString(), monsterKey, monsterNum, projRootDir, con);
                //练潜
                if (monsterKey.contains("qlhd_")) {
                    int point = Integer.parseInt(monsterKey.replace("qlhd_", ""));
                    if (monsterNum < 3) point = 5 + point * 5;
                    else if (monsterNum < 5) point = 20 + point * 5;
                    else point = 30 + point * 5;
                    int num = startBef.packageService.turnToPotential(point, name.toString(), con);
                    if (num > 0) {
                        JSONArray gs = rewardUtils.getGoodsReward("10000188", num, 1);
                        list = list.fluentAddAll(gs);
                    }
                }

                //永恒魔窟怪物
                if (monsterKey.contains("yhmk_")) {
                    if (startBef.yhmkService.matchTimes((String) name, con) &&
                            startBef.yhmkService.setGain((String) name, con)) {
                        //供香
                        JSONArray gs = rewardUtils.getGoodsReward("10000135", 1, 1);
                        list = list.fluentAddAll(gs);
                    }
                }

                //注意:里面增加宠物经验会生成新技能导致list发生改变，所以要使用返回的这个list
                list = saveRewards(list, (String) name, con);
                mybatisConfig.commit(con);
                ChannelSupervise.noticeClientByName(list, (String) name, "10000");
            }
            startBef.stService.addQhd(1, names, con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        return 0;
    }


    /**
     * 创建道具奖励（所以奖励创建的入口）
     * 或者使用rewardUtils.getGoodsReward再调取saveRewards也是一样
     */
    public JSONArray createGoods(String key, int num, int isBind, String name, DefaultSqlSession con) {
        //对于装备类型的道具数量不能大于1
        if (equipData.isEquip(key) || equipData.isKeyin(key)) {
            if (num > 1) {
                System.err.println("数量大于1导致不能创建道具/" + key);
                return null;
            }
        }
        return saveRewards(rewardUtils.getGoodsReward(key, num, isBind), name, con);
    }

    /*public JSONArray createGoods(String key, int num, int isBind, JSONArray list, String name, DefaultSqlSession con) {
        return saveRewards(rewardUtils.getGoodsReward(key, num, isBind, list), name, con);
    }*/

    /**
     * 下发活动奖励
     */
    public JSONArray getActivityReward(int lv, String name, String key, Object params, DefaultSqlSession con) {
        JSONArray list = rewardUtils.getRewardByActivityKey(lv, key, params);
        return saveRewards(list, name, con);
    }

    /**
     * 幽谷秘宝随机一个技能
     */
    public JSONArray openBoxYGMB(String name, DefaultSqlSession con) {
        JSONArray list = rewardUtils.getBoxYGMB();
        return saveRewards(list, name, con);
    }

    /**
     * 开仙决宝箱
     */
    public JSONArray openBoxXianJue(String name, DefaultSqlSession con) {
        JSONArray list = rewardUtils.getBoxXianJue();
        saveRewards(list, name, con);
        rewardUtils.noticeReward(0, name, list);
        return list;
    }

    /**
     * 开神秘宝箱
     */
    public JSONArray openBox(String name, DefaultSqlSession con) {
        JSONArray list = rewardUtils.getBoxReward();
        return saveRewards(list, name, con);
    }

    public JSONArray openMeiLaoBanGift(String name, DefaultSqlSession con) {
        JSONArray rewards = new JSONArray();
        //锻造宝石x198、中级天元丹x18、人物刻印卷轴x36、修复宝石x398、供香x868（全绑定）
        rewardUtils.getGoodsReward("10000105", 198, 1, rewards);
        rewardUtils.getGoodsReward("10000214", 18, 1, rewards);
        rewardUtils.getGoodsReward("10000164", 36, 1, rewards);
        rewardUtils.getGoodsReward("10000111", 398, 1, rewards);
        rewardUtils.getGoodsReward("10000143", 868, 1, rewards);
        rewardUtils.noticeReward(2, name, rewards);
        return saveRewards(rewards, name, con);
    }

    public JSONArray openGuiJianChouGift(String name, DefaultSqlSession con) {
        //要求必须先选择职业
        JSONObject role = startBef.manService.getRole(name, con);
        int len = role.getJSONArray("models").size();
        if (role.getInteger("lever") < 30 || len < 3) {
            return null;
        }
        String model = roleUtils.getModel(role);
        int index = roleUtils.jobToIndex(model);
        JSONArray rewards = new JSONArray();
        //高级宠物口粮x98、天元精髓x98、60级橙品套装
        rewardUtils.getGoodsReward("10000031", 98, 1, rewards);
        rewardUtils.getGoodsReward("10000126", 98, 1, rewards);
        for (int i = 0; i < 9; i++) {
            String eqKey = equipData.getEquipKey(3, i, index, 5, 5);
            rewardUtils.getGoodsReward(eqKey, 1, 1, rewards);
        }
        rewardUtils.noticeReward(3, name, rewards);
        return saveRewards(rewards, name, con);
    }

    /**
     * 新年礼包
     */
    public JSONArray openXinNainGift(String name, DefaultSqlSession con) {
        JSONArray list = rewardUtils.getXNGiftReward();
        staticCollection.putTask(() -> {
            try {
                //世界通知奖励
                JSONObject rs = JSON.parseObject(JSON.toJSONString(list.get(0)));
                String key = rs.getJSONObject("goods").getString("key");
                String str = null;
                if (key.equals("1048")) {
                    str = "神兽礼袋";
                } else if (key.equals("1045")) {
                    str = "仙绝宝匣";
                } else if (key.equals("1046")) {
                    str = "金票刮刮卡";
                }
                if (str != null) {
                    startBef.chatService.putSysMsg("玩家 " + name + " 打开神兽礼包幸运的获得了 " + str + " x1");
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
        return saveRewards(list, name, con);
    }

    /**
     * 保存奖励
     */
    public JSONArray saveRewards(JSONArray list, String name, DefaultSqlSession con) {
        if (list == null) return null;
        JSONArray arr = new JSONArray();
        for (Object o : list) {
            //因为o是一个java内部类,注意：修改obj属性并不能使list也变化，原因 JSON.toJSON
            JSONObject obj = (JSONObject) JSON.toJSON(o);
            int type = obj.getInteger("type");
            if (type == 0) {
                //保存经验
                if (startBef.manService.upLv(name, obj.getInteger("exp"), con, 30)) {
                    //升级必然触发任务开启的检测
                    startBef.taskService.checkTaskStart(name, con);
                }
                int petExp = obj.getInteger("petExp");
                //startBef.huobanService.upLv(name, petExp, con);

                JSONArray skls = startBef.petService.upLv(name, petExp, con);
                obj.put("skls", skls);
            } else if (type == 1) {
                //保存货币
                Long m = obj.getLong("money");
                Integer moneyType = obj.getInteger("moneyType");
                startBef.manService.saveMoney(moneyType, m, name, con);
            } else if (type == 2) {
                //保存物品
                JSONObject g = startBef.packageService.createGoods(obj.getJSONObject("goods"), name, con);
                obj.put("goods", g);
            } else if (type == 4) {
                startBef.vipService.addVipExp(obj.getInteger("vip"), name, con);
            } else if (type == 5) {//声望
                startBef.manService.upShengwang(name, obj.getInteger("swExp"), con);
            }
            arr.add(obj);
        }
        return arr;
    }

    /**
     * 获得任务奖励
     */
    public JSONArray saveRewardsByTask(String taskKey, String name, DefaultSqlSession con) {
        JSONArray list = rewardUtils.getRewardByTaskKey(taskKey, con, name);
        return saveRewards(list, name, con);
    }
}
