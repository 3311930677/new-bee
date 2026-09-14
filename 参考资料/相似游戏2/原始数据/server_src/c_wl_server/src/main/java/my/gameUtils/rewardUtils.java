package my.gameUtils;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.data.*;
import my.model.ChannelSupervise;
import my.model.result;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import my.utils.systemUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.*;

public class rewardUtils {
    /**
     * vip礼包*
     */
    public static JSONArray getVipGift(int lv) {
        JSONArray rs = new JSONArray();
        if (lv == 1) {//v1礼包   10万银票
            getYinPiaoReward(10 * 10000, rs);
        } else if (lv == 2) {//v2礼包   锻造2 精炼3   修复1
            getGoodsReward("10000105", 2, 1, rs);
            getGoodsReward("10000109", 3, 1, rs);
            getGoodsReward("10000111", 1, 1, rs);
        } else if (lv == 3) {//v3    锻造5，精炼3，修复2
            getGoodsReward("10000105", 5, 1, rs);
            getGoodsReward("10000109", 3, 1, rs);
            getGoodsReward("10000111", 2, 1, rs);
        } else if (lv == 4) {//v4       锻造7，修复5
            getGoodsReward("10000105", 7, 1, rs);
            getGoodsReward("10000111", 5, 1, rs);
        } else if (lv == 5) {//v5  段皇1锻造5修复7  宠物普通技能礼包
            getGoodsReward("10000107", 1, 1, rs);
            getGoodsReward("10000105", 5, 1, rs);
            getGoodsReward("10000111", 7, 1, rs);
            getGoodsReward("10000262", 1, 1, rs);
        } else if (lv == 6) {//v6  段皇4修复10  宠物高级技能礼包
            getGoodsReward("10000107", 4, 1, rs);
            getGoodsReward("10000111", 10, 1, rs);
            getGoodsReward("10000261", 1, 1, rs);
        } else if (lv == 7) {//v7  段皇6，绑定2修复15   神技能盒子一个
            getGoodsReward("10000107", 6, 1, rs);
            getGoodsReward("10000149", 2, 1, rs);
            getGoodsReward("10000111", 15, 1, rs);
            getGoodsReward("10000260", 1, 1, rs);
        } else if (lv == 8) {//v8段皇10绑定4潜20修复30      魔龙召唤令
            getGoodsReward("10000107", 10, 1, rs);
            getGoodsReward("10000149", 4, 1, rs);
            getGoodsReward("10000114", 20, 1, rs);
            getGoodsReward("10000111", 30, 1, rs);
            getGoodsReward("10000133", 1, 1, rs);
        } else if (lv == 9) {//v9 段皇15绑定4潜25修复40扬善5封赏4圣天元丹4
            getGoodsReward("10000107", 15, 1, rs);
            getGoodsReward("10000149", 4, 1, rs);
            getGoodsReward("10000114", 25, 1, rs);
            getGoodsReward("10000111", 40, 1, rs);
            getGoodsReward("10000187", 5, 1, rs);
            getGoodsReward("10000174", 4, 1, rs);
            getGoodsReward("10000217", 4, 1, rs);
        } else if (lv == 10) {//v10 段皇20刻印2潜力50修复50扬善5封赏10        待定
            getGoodsReward("10000107", 20, 1, rs);
            getGoodsReward("10000150", 2, 1, rs);
            getGoodsReward("10000114", 50, 1, rs);
            getGoodsReward("10000111", 50, 1, rs);
            getGoodsReward("10000187", 5, 1, rs);
            getGoodsReward("10000174", 10, 1, rs);
        } else return null;
        return rs;
    }


    /**
     * 累计档礼包
     */
    public static JSONArray getLeiJiGift(int lv) {
        JSONArray rs = new JSONArray();
        String gdKey = null;
        int num = 0;
        if (lv == 0) {
            //黑铁宝箱✖️1(银两✖️20万，锻皇宝石✖️4人物技能箱✖️1，宠物技能箱✖️1，宠物进化石✖️1，人参果✖️1，宠物重生丹✖️4
            String[] a = {
                    "10000175", "10000107", "10000282", "10000283", "10000121", "10000122", "10000124"
            };
            int[] b = {20, 4, 1, 1, 1, 1, 4};
            int index = strUtils.getRandom(0, a.length);
            gdKey = a[index];
            num = b[index];
        } else if (lv == 1) {
            //青铜宝箱✖️1(银两✖️50万，锻皇宝石✖️8人物技能箱✖️1，宠物技能箱✖️1，宠物进化石✖️1，人参果✖️1，宠物重生丹✖️8
            String[] a = {
                    "10000175", "10000107", "10000282", "10000283", "10000121", "10000122", "10000124"
            };
            int[] b = {50, 8, 1, 1, 1, 1, 8};
            int index = strUtils.getRandom(0, a.length);
            gdKey = a[index];
            num = b[index];
        } else if (lv == 2) {
            //白银宝箱✖️1(锻皇宝石✖️15，人物技能箱✖️2，宠物技能箱✖️2，魔龙残影✖️1，中天元丹✖️10
            String[] a = {
                    "10000107", "10000282", "10000283", "10000284", "10000214",
            };
            int[] b = {15, 2, 2, 1, 10};
            int index = strUtils.getRandom(0, a.length);
            gdKey = a[index];
            num = b[index];
        } else if (lv == 3) {
            getGoodsReward("10000260", 1, 0, rs);
            //黄金宝箱✖️1(皇宝石✖️20人物技能箱✖️2，宠物技能箱✖️2，魔龙残影✖️1，高天元丹✖️5，修复✖️40
            String[] a = {
                    "10000107", "10000282", "10000283", "10000284", "10000215", "10000111",
            };
            int[] b = {20, 2, 2, 1, 5, 40};
            int index = strUtils.getRandom(0, a.length);
            gdKey = a[index];
            num = b[index];
        } else if (lv == 4) {
            getGoodsReward("10000284", 1, 0, rs);
            //1(皇宝石✖️30人物技能箱✖️4，宠物技能箱✖️4，魔龙残影✖️1，超级天元丹✖️2，修复✖️80
            String[] a = {
                    "10000107", "10000282", "10000283", "10000284", "10000216", "10000111",
            };
            int[] b = {30, 4, 4, 1, 2, 80};
            int index = strUtils.getRandom(0, a.length);
            gdKey = a[index];
            num = b[index];
        } else return null;

        getGoodsReward(gdKey, num, 0, rs);
        return rs;
    }

    /**
     * 锻造礼包
     */
    public static JSONArray getDuanZaoGift() {
        JSONArray rs = new JSONArray();
        getGoodsReward("10000105", 100, 1, rs);
        getGoodsReward("10000107", 50, 1, rs);
        getGoodsReward("10000111", 200, 1, rs);
        getTaleReward(1000000, rs);
        return rs;
    }

    /**
     * 随机种子
     */
    public static String getRandomZhongzi(int lv) {
        int i = 0;
        //3*x-3
        int x = strUtils.getRandom(1, 8);
        if (lv == 1) i = 3 * x - 3;
        else if (lv == 2) i = 3 * x - 2;
        else if (lv == 3) i = 3 * x - 1;
        String str = i + "";
        int len = 4 - str.length();
        for (int p = 0; p < len; p++) {
            str = "0" + str;
        }
        return "1013" + str;
    }

    /**
     * 开神技、高级、普通礼包
     */
    public static JSONArray openSkillGift(int type) {
        String gdKey = null;
        if (type == 0) {//神技
            if (strUtils.isHappend(0, 1000, 0.1f)) {
                String[] a = {
                        "100210010274", "100210010275"
                };
                gdKey = a[strUtils.getRandom(0, a.length)];
            } else {
                String[] a = {
                        "100210010286", "100210010292", "100210010293",
                        "100210010297", "100210010299", "100210010300",
                        "100210010301", "100210010302", "100210010303",
                };
                gdKey = a[strUtils.getRandom(0, a.length)];
            }
        } else if (type == 1) {
            String[] a = {
                    "100210010265", "100210010266", "100210010267", "100210010268", "100210010269",
                    "100210010270", "100210010271", "100210010272", "100210010273", "100210010276",
                    "100210010277", "100210010278", "100210010279", "100210010280", "100210010281",
                    "100210010282", "100210010283", "100210010284", "100210010287",
                    "100210010288", "100210010289", "100210010291", "100210010294",
                    "100210010295", "100210010296", "100210010298", "100210010308",
                    "100210010309", "100210010310", "100210010311", "100210010312", "100210010313",
                    "100210010180",
            };
            gdKey = a[strUtils.getRandom(0, a.length)];
        } else {
            List<String> arr = new ArrayList<>();
            goodsData.getAllPet2SkillGoodsData(arr);
            Collections.shuffle(arr);
            gdKey = arr.get(0);
        }
        return rewardUtils.getGoodsReward(gdKey, 1, 0);
    }

    /**
     * 随机仙丹礼包碎片
     */
    public static String getRandomXianDanLiBaoSuiPian() {
        int i = strUtils.getRandom(247, 257);
        String str = i + "";
        int len = 4 - str.length();
        for (int p = 0; p < len; p++) {
            str = "0" + str;
        }
        return "1000" + str;
    }

    /**
     * 随机镶嵌石头
     * lv 1 2 3 4 5
     */
    public static String getRandomBaoShi(int lv) {
        int i = 0;
        if (lv == 1) i = strUtils.getRandom(0, 10);
        else if (lv == 2) i = strUtils.getRandom(10, 20);
        else if (lv == 3) i = strUtils.getRandom(20, 30);
        else if (lv == 4) i = strUtils.getRandom(30, 40);
        else if (lv == 5) i = strUtils.getRandom(40, 50);
        String str = i + "";
        int len = 4 - str.length();
        for (int p = 0; p < len; p++) {
            str = "0" + str;
        }
        return "1003" + str;
    }

    /**
     * 随机一个宠物丹药（固原、元魂、仙元）
     * lv 1,2,3
     */
    public static String getRandomPetDan(int lv) {
        int i = 0;
        if (lv == 1) i = strUtils.getRandom(0, 10);
        else if (lv == 2) i = strUtils.getRandom(10, 20);
        else if (lv == 3) i = strUtils.getRandom(20, 30);
        String str = i + "";
        int len = 4 - str.length();
        for (int p = 0; p < len; p++) {
            str = "0" + str;
        }
        return "1011" + str;
    }

    /**
     * 根据货币类型获取key
     */
    public static String getKeyByMoneyType(int moneyType) {
        String key = null;
        if (moneyType == 0) {//元宝
            key = "gold";
        } else if (moneyType == 1) {
            key = "tale";
        } else if (moneyType == 2) {
            key = "yp";
        } else if (moneyType == 3) {
            key = "jf";
        } else if (moneyType == 4) {
            key = "wxz";
        } else if (moneyType == 5) {
            key = "bg";
        } else if (moneyType == 6) {
            key = "xld";//修炼点
        } else if (moneyType == 7) {
            key = "bb";//帮币
        } else if (moneyType == 8) {
            key = "jmPoint";//经脉点数
        } else if (moneyType == 9) {
            key = "ldjf";//领地积分
        } else if (moneyType == 10) {
            key = "cbjf";//传壁积分
        } else if (moneyType == 11) {
            key = "jungong";//军功
        }
        return key;
    }

    /**
     * 判断是否为稀有道具
     */
    private static boolean isImportGoods(String k) {
        if (strUtils.isMatch(k, "1002([0-9]{8})")) {
            return true;
        }
        if (k.equals("10000257") || k.equals("10000258")) return true;

        return false;
    }

    /**
     * 奖励解析并通告
     * 0仙绝宝箱 1洪荒宝库 2梅老板礼包 3鬼见愁礼包 4宠物神技礼包 5宠物高级技能礼包
     */
    public static void noticeReward(int getPath, String name, JSONArray goods) {
        try {
            //只放入队列中，不要产生太多线程，需要一个5s执行一次的定时器
            List<reward> list = staticCollection.copyArr(goods, reward.class);
            JSONArray keys = new JSONArray();
            for (reward r : list) {
                //判断是否为物品
                if (r.type != 2) continue;
                String k = r.goods.getString("key");
                if (isImportGoods(k)) {
                    keys.add(k);
                }
            }
            if (keys.size() > 0) {
                JSONObject msg = new JSONObject();
                msg.put("name", name);
                msg.put("keys", keys);
                msg.put("getPath", getPath);
                staticCollection.rewardMsgList.add(msg);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 将奖励通知队列推送给玩家
     */
    public static void rewardMsgToAllClient() {
        if (staticCollection.rewardMsgList.size() == 0) return;
        JSONArray list = staticCollection.copyArr(staticCollection.rewardMsgList);
        staticCollection.rewardMsgList.clear();
        for (Object msg : list) {
            ChannelSupervise.noticeAllClient(msg, "103");
        }
        list.clear();
    }

    /**
     * 藏宝图奖励
     */
    public static JSONArray getCBTReward(int lv) {
        List<String> list = new ArrayList<>();
        if (lv == 1) {
            list.add("1004");
            list.add("1005");
        } else if (lv == 2) {
            list.add("1008");
            list.add("1009");
            list.add("1010");
        } else {
            for (int i = 4000; i < 4010; i++) {
                list.add(i + "");
            }
        }
        int index = strUtils.getRandom(0, list.size() - 1);
        return getGoodsReward(list.get(index), 1, 1);
    }

    /**
     * 新年礼包奖励
     */
    public static JSONArray getXNGiftReward() {
        String arr[] = getSimpleRewards();
        int index = strUtils.getRandom(0, arr.length);
        return getGoodsReward(arr[index], 1, 1);
    }

    /**
     * 幽谷秘宝随机一个技能
     */
    public static JSONArray getBoxYGMB() {
        JSONArray list = null;
        List<String> arr = new ArrayList<>();
        if (strUtils.numInArea(143, 0, 150)) {
            goodsData.getAllPet4SkillGoodsData(arr);
        } else {
            goodsData.getAllPet2SkillGoodsData(arr);
        }
        //随机获取一个
        int r = strUtils.getRandom(0, arr.size());
        list = getGoodsReward(arr.get(r), 1, 0);
        return list;
    }

    public static JSONArray getBoxXianJue() {
        List<String> list = new ArrayList<>();
        goodsData.getMan2SkillGoodsData(list);
        if (strUtils.isHappend(0, 1000, 0.05f)) {
            goodsData.getMan4SkillGoodsData(list);
        }
        Collections.shuffle(list);
        return getGoodsReward(list.get(0), 1, 0);
    }

    /**
     * 开宝箱奖励
     */
    public static JSONArray getBoxReward() {
        String arr[] = getSimpleRewards();
        String key = arr[strUtils.getRandom(0, arr.length)];
        return getGoodsReward(key, 1, 1);
    }

    public static JSONArray getWorldBossReward(boolean b) {
        if (b) {//前三奖励
            if (strUtils.isHappend(0, 1000, 0.5f)) {
                //天元丹
                return getGoodsReward("10000213", 5, 1);
            } else if (strUtils.isHappend(0, 1000, 0.2f)) {
                //宠物技能卷轴
                return getBox3FromHHBK(false);
            } else {
                //锻皇
                return getGoodsReward("10000107", 2, 1);
            }
        }
        return getBoxReward();
    }

    /**
     * 洪荒宝库箱子
     */
    public static JSONArray getBox3FromHHBK(boolean isBaoLi) {
        if (isBaoLi) return getBoxReward();
        List<String> list = new ArrayList<>();
        int num = 1;
        if (strUtils.isHappend(0, 100, 0.5f)) {
            goodsData.getAllPet2SkillGoodsData(list);
            if (strUtils.isHappend(0, 1000, 0.2f)) {
                goodsData.getAllPet4SkillGoodsData(list);
            }
            Collections.shuffle(list);
        } else {
            //仙元丹自选礼包
            list.add("10000301");
            num = 3;
        }
        return getGoodsReward(list.get(0), num, 0);
    }

    public static JSONArray getBox2FromHHBK(boolean isBaoLi) {
        if (isBaoLi) return getBoxReward();
        List<String> list = new ArrayList<>();
        goodsData.getAllPet2SkillGoodsData(list);
        Collections.shuffle(list);
        return getGoodsReward(list.get(0), 1, 0);
    }


    /**
     * 获得经验奖励
     */
    public static JSONArray getExpReward(int exp) {
        return getExpReward(exp, new JSONArray());
    }

    public static JSONArray getExpReward(int exp, JSONArray list) {
        list.add(new reward().bindExp(exp));
        return list;
    }

    public static JSONArray getExpReward(int exp, int petExp, JSONArray list) {
        list.add(new reward().bindExp(exp, petExp));
        return list;
    }

    /**
     * 获得银两奖励
     */
    public static JSONArray getTaleReward(long tale) {
        return getTaleReward(tale, new JSONArray());
    }

    public static JSONArray getTaleReward(long tale, JSONArray list) {
        list.add(new reward().bindMoney(1, tale));
        return list;
    }

    /**
     * 银票
     */
    public static JSONArray getYinPiaoReward(long yp) {
        return getYinPiaoReward(yp, new JSONArray());
    }

    public static JSONArray getYinPiaoReward(long yp, JSONArray list) {
        list.add(new reward().bindMoney(2, yp));
        return list;
    }

    /**
     * 获取元宝奖励
     */
    public static JSONArray getGoldReward(long gold) {
        return getGoldReward(gold, new JSONArray());
    }

    public static JSONArray getGoldReward(long gold, JSONArray list) {
        list.add(new reward().bindMoney(0, gold));
        return list;
    }

    public static JSONArray getVipReward(int vip) {
        return getVipReward(vip, new JSONArray());
    }

    public static JSONArray getVipReward(int vip, JSONArray list) {
        list.add(new reward().bindVip(vip));
        return list;
    }

    public static JSONArray getSwExpReward(int exp) {
        return getSwExpReward(exp, new JSONArray());
    }

    public static JSONArray getSwExpReward(int exp, JSONArray list) {
        list.add(new reward().bindSwExp(exp));
        return list;
    }

    /**
     * 军功
     */
    public static JSONArray getJungongReward(long jungong) {
        return getJungongReward(jungong, new JSONArray());
    }

    public static JSONArray getJungongReward(long jungong, JSONArray list) {
        list.add(new reward().bindMoney(11, jungong));
        return list;
    }

    /**
     * 传壁积分
     */
    public static JSONArray getCbjfReward(long cbjf) {
        return getCbjfReward(cbjf, new JSONArray());
    }

    public static JSONArray getCbjfReward(long cbjf, JSONArray list) {
        list.add(new reward().bindMoney(10, cbjf));
        return list;
    }

    public static JSONArray getWxReward(long wxz) {
        return getWxReward(wxz, new JSONArray());
    }

    public static JSONArray getWxReward(long wxz, JSONArray list) {
        list.add(new reward().bindMoney(4, wxz));
        return list;
    }

    public static JSONArray getBgReward(long bg) {
        return getBgReward(bg, new JSONArray());
    }

    public static JSONArray getBgReward(long bg, JSONArray list) {
        list.add(new reward().bindMoney(5, bg));
        return list;
    }

    /**
     * 修炼点
     */
    public static JSONArray getXldReward(long bg) {
        return getXldReward(bg, new JSONArray());
    }

    public static JSONArray getXldReward(long bg, JSONArray list) {
        list.add(new reward().bindMoney(6, bg));
        return list;
    }

    /**
     * 帮币
     */
    public static JSONArray getBbReward(long bg) {
        return getBbReward(bg, new JSONArray());
    }

    public static JSONArray getBbReward(long bg, JSONArray list) {
        list.add(new reward().bindMoney(7, bg));
        return list;
    }

    public static JSONArray getLdjfReward(long ldjf) {
        return getLdjfReward(ldjf, new JSONArray());
    }

    public static JSONArray getLdjfReward(long ldjf, JSONArray list) {
        list.add(new reward().bindMoney(9, ldjf));
        return list;
    }

    /**
     * 通用物品奖励调取
     */
    public static JSONArray getGoodsReward(String key, int num, int isBind) {
        return getGoodsReward(key, num, isBind, null);
    }

    public static JSONArray getGoodsReward(String key, int num, int isBind, JSONArray list) {
        if (list == null) {
            list = new JSONArray();
        }
        JSONObject goods = new JSONObject();
        goods.put("key", key);
        goods.put("num", num);
        goods.put("isBind", isBind);
        list.add(new reward().bindGoods(goods));
        return list;
    }


    /**
     * 将一个已经生成好的道具封装成道具奖励
     */
    public static JSONArray getGoodsReward(JSONObject goods) {
        JSONArray list = new JSONArray();
        list.add(new reward().bindGoods(goods));
        return list;
    }

    /**
     * 仅宠物交易时使用
     **/
    public static JSONArray getPetReward(JSONObject pet) {
        JSONArray list = new JSONArray();
        list.add(new reward().bindPet(pet));
        return list;
    }

    /**
     * 获得竞技场积分奖励
     */
    public static JSONArray getJFReward(long num) {
        JSONArray list = new JSONArray();
        list.add(new reward().bindMoney(3, num));
        return list;
    }

    /**
     * 获得战斗奖励
     * todo:师徒组队完成任务另外增加亲和度
     */
    public static JSONArray getFightReward(String name, String monsterKey, Integer monsterNum, String projRootDir, DefaultSqlSession con) {
        JSONArray list = new JSONArray();
        //打怪必掉的经验跟银票
        JSONObject m = monsterData.getMonsterByKey(monsterKey, projRootDir);
        int lever = 1;
        if (m != null && m.get("lever") != null) {
            lever = m.getInteger("lever");
        }
        int lv = startBef.vipService.getVipLv(name, con);
        float k = lv * 1.1f + 1;

        //普通怪才掉落，boss怪不掉落
        int exp = (int) (lever * 5 * monsterNum * k);
        //节日活动经验翻倍
        if (strUtils.isInDay("2026-03-03 00:00:00", "2026-03-06 23:59:00")) {
            exp *= 2;
        }
        int petExp = exp / 2;

        if (startBef.manService.isStatusOpen("rwzhd", name)) {
            exp *= 2;
        }
        //宠物造化丹，双倍经验
        if (startBef.manService.isStatusOpen("cwzhd", name)) {
            petExp *= 2;
        }
        getExpReward(exp, petExp, list);

        int yp = (int) (lever * 10 * monsterNum * k);
        getYinPiaoReward(yp, list);

        if (monsterKey.matches("1[0-9]{3}")) {
            //初段
            if (strUtils.isHappend(0, 1000, 0.1f)) {
                getGoodsReward("10000104", 1, 0, list);
            }
            //明心悟性
            if (strUtils.isHappend(0, 1000, 0.1f)) {
                getGoodsReward("10000130", 1, 0, list);
            }
            //周末 天晶石收集，判断是否到了天晶石开启的时间段 8-11
            if (startBef.activityService.isOpen("tianjingshi") &&
                    (strUtils.isWKS(7) || strUtils.isWKS(1)) &&
                    strUtils.isHappend(0, 1000, 0.1f)) {
                getGoodsReward("10000190", 1, 0, list);
            }
            //玉魄石收集
            if (startBef.activityService.isOpen("yuposhi") &&
                    strUtils.isHappend(0, 1000, 0.2f)) {
                getGoodsReward("10000191", 1, 0, list);
            }
            //白装掉落
            if (strUtils.isHappend(0, 1000, 0.1f)) {
                String equipKey = equipData.getEquipKey(0, null, null, null, null);
                getGoodsReward(equipKey, 1, 0, list);
            }
            //镶嵌石
            if (strUtils.isHappend(0, 1000, 0.1f)) {
                getGoodsReward(getRandomBaoShi(1), 1, 1, list);
            }
            //农场种子掉落
            /*if (strUtils.isHappend(0, 1000, 0.1f)) {
                getGoodsReward(seedData.getOne(), 1, 0, list);
            }*/

            //六一刷怪活动
            /*if (strUtils.isHappend(0, 1000, 0.06f) &&
                    strUtils.isInDay("2022-06-01 00:00:00", "2022-06-06 00:00:00")) {
                String i = "105" + strUtils.getRandom(5, 10);
                list.add(new reward().bindGoods(getGoods(i, 1)));
            }*/
        } else if (monsterKey.contains("xxzd")) {//血腥之地
            //if (strUtils.isInTime(19, 30, 20, 30)) {
            //getGoodsReward("10000304", 1, 1, list);
            //}
        } else if (monsterKey.contains("dmkj_")) {//盗梦空间的怪物会掉落梦幻水晶、珊瑚
            if (strUtils.isHappend(0, 1000, 0.1f)) {
                getGoodsReward("10000199", 1, 0, list);
            } else if (strUtils.isHappend(0, 1000, 0.1f)) {
                //初段
                getGoodsReward("10000104", 1, 0, list);
            }
        } else if (monsterKey.contains("mpbwz_")) {//门派保卫战会掉落两亿八卦
            if (strUtils.isHappend(0, 1000, 0.2f)) {
                getGoodsReward("10000211", 1, 0, list);
            }
        }

        return list;
    }

    /**
     * 获取活动奖励
     */
    public static JSONArray getRewardByActivityKey(Integer lv, String key, Object params) {
        JSONArray list = null;
        switch (key) {
            case "2002": {//欢乐答题
                //传入参数为答对题数
                int exp = lv * 400 * (int) params / 10;
                list = getExpReward(exp);
                if ((int) params == 10)//宠物初级口粮
                    list = getGoodsReward("10000029", 1, 1, list);
                return list;
            }
            case "2004": {//百家争鸣
                JSONObject obj = (JSONObject) params;
                int progress = obj.getInteger("progress");
                int exp = 1000 + lv * 12 * obj.getInteger("right");
                list = getExpReward(exp);
                int tale = lv * 400 * obj.getInteger("right") / 100;
                list = getTaleReward(tale, list);
                return list;
            }
            case "2017": {//转盘
                int reward[] = {1000, 3000, 5000, 6000, 7000, 8000, 10000, 12000};
                if (params == null) return null;
                int r = (int) params;
                int exp = reward[r] + lv * 200;
                list = getExpReward(exp);
                return list;
            }

        }
        return null;
    }

    /**
     * 由任务key获取奖励
     */
    public static JSONArray getRewardByTaskKey(String taskKey, DefaultSqlSession con, String name) {
        String rewardKey = taskData.getTaskRewardKey(taskKey);
        return getRewardByKey(rewardKey, con, name);
    }

    /**
     * 门派任务随机奖励
     */
    private static String getMpTaskRewardsKey() {
        String[] arr = getSimpleRewards();
        return arr[strUtils.getRandom(0, arr.length)];
    }

    /**
     * 获取普通道具奖励
     */
    private static String[] getSimpleRewards() {
        String[] arr = {
                "10000029", "10000124", "10000104", "10000105", "10000106",
                "10000111", "10000114", "10000130", "10000115", "10000113",
                "10000109", "10000030", "10000125", "10000177", "10000179",
                "10000183", "10000184", "10000208", "10000209", "10000209"
        };
        List<String> list = new ArrayList<>(Arrays.asList(arr));
        //一级宝石
        for (int i = 0; i < 10; i++) {
            list.add("1003000" + i);
        }
        return list.toArray(new String[0]);
    }

    /**
     * 高级道具
     */
    private static String[] getSuperRewards() {
        String[] arr = {
                "1011", "1036", "1043", "1063", "1064", "1068", "1073",
                "1082",
        };
        return arr;
    }

    /**
     * 摸金校尉普通、高级奖励
     */
    public static JSONArray getMjxwRewardsKey(int i) {
        String goodsKey = null;
        //难度比较容易，给普通奖励
        String[] arr = getSimpleRewards();
        goodsKey = arr[strUtils.getRandom(0, arr.length)];
        /*if (i == 0) {
            goodsKey = getMpTaskRewardsKey();
        } else {
            String[] arr = {
                    "1026", "1028", "1032", "1036", "1043", "1068", "1073",
                    "1082", "1101",
            };
            goodsKey = arr[strUtils.getRandom(0, arr.length)];
        }*/
        return getGoodsReward(goodsKey, 1, 1, new JSONArray());
    }

    private static void addSklSpToFb(int vipLv, int type, JSONArray list) {
        if (vipLv < 5) return;
        float p = 0;
        if (type == 0) p = 0.005f;//50
        else if (type == 1) p = 0.006f;//60
        else if (type == 2) p = 0.007f;//70
        else if (type == 3) p = 0.008f;//80
        else if (type == 4) p = 0.009f;//90
        else if (type == 5) p = 0.01f;//100
        else if (type == 6) p = 0.05f;//铁1
        else if (type == 7) p = 0.07f;//铁2
        else if (type == 8) p = 0.09f;//铁3
        else if (type == 9) p = 0.11f;//铁4
        else if (type == 10) p = 0.2f;//隐藏1-3
        if (strUtils.isHappend(0, 1000, p)) {
            if (strUtils.isHappend(0, 1000, 0.01f)) {
                //神兽碎片
                getGoodsReward("10000287", 1, 0, list);
            } else if (strUtils.isHappend(0, 1000, 0.01f)) {
                //完整人物技能、宠物技能
                List<String> skls = new ArrayList<>();
                if (strUtils.isHappend(0, 1000, 0.1f)) {
                    //四字
                    goodsData.getMan4SkillGoodsData(skls);
                    goodsData.getAllPet4SkillGoodsData(skls);
                } else {
                    //二字
                    goodsData.getMan2SkillGoodsData(skls);
                    goodsData.getAllPet2SkillGoodsData(skls);
                }
                Collections.shuffle(skls);
                getGoodsReward(skls.get(0), 1, 0, list);
            } else {
                //技能碎片
                String[] arr = {"10000289", "10000290", "10000291"};
                int index = strUtils.getRandom(0, arr.length);
                int num = strUtils.getRandom(2, 6);
                getGoodsReward(arr[index], num, 0, list);
            }
        }
        //getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
    }

    /**
     * 由奖励key获取奖励
     */
    public static JSONArray getRewardByKey(String key, DefaultSqlSession con, String name) {
        JSONObject role = startBef.manService.getRole(name, con);
        int lv = role.getInteger("lever");
        int vipLv = startBef.vipService.getVipLv(name, con);

        String model = roleUtils.getModel(role);
        JSONArray list = new JSONArray();
        if (key.equals("*")) {
            getExpReward(400, list);
            getTaleReward(400, list);
            getYinPiaoReward(800, list);
            return list;
        }
        int ik = Integer.parseInt(key);
        if (ik >= 3000 && ik < 3040) {//天渊
            int exp = (int) ((ik - 2999) * 100 * lv * 0.2f);
            int money = Double.valueOf(200 + 134 * (lv / 100) * Math.pow(2, (ik - 3000) / 10f) + "").intValue();
            getExpReward(exp, list);
            getTaleReward(money, list);
            getYinPiaoReward(money * 2, list);
            return list;
        } else if (ik >= 3040 && ik < 3070) {//宠物炼修混
            int exp = Double.valueOf(30 * lv + lv * 100 * Math.pow(1.1, (ik - 3040)) + "").intValue();
            int money = Double.valueOf(200 + 134 * (lv / 100) * Math.pow(2, (ik - 3040) / 10f) + "").intValue();
            getExpReward(exp, list);
            //getTaleReward(money, list);
            //getYinPiaoReward(money * 2, list);
            if (ik == 3040) {//大药囊
                getGoodsReward("100110060001", 1, 1, list);
            } else if (ik == 3046) {//超级药囊
                getGoodsReward("100110060002", 1, 1, list);
            } else if (ik == 3049) {//随机一个固元丹
                getGoodsReward(getRandomPetDan(1), 1, 1, list);
            } else if (ik >= 3050) {//修、混
                getYinPiaoReward(money * 2, list);
                if (ik == 3051) {//蓝品逆转散
                    getGoodsReward("10000168", 1, 1, list);
                } else if (ik == 3053) {//随机两个个固元丹
                    getGoodsReward(getRandomPetDan(1), 1, 1, list);
                    getGoodsReward(getRandomPetDan(1), 1, 1, list);
                } else if (ik == 3054) {//元灵幽草
                    getGoodsReward("10000234", 1, 1, list);
                } else if (ik == 3056) {//紫品逆转散
                    getGoodsReward("10000169", 1, 1, list);
                } else if (ik == 3058) {//随机两个个元魂丹
                    getGoodsReward(getRandomPetDan(2), 1, 1, list);
                    getGoodsReward(getRandomPetDan(2), 1, 1, list);
                } else if (ik == 3059) {//元灵幽草
                    getGoodsReward("10000234", 1, 1, list);
                } else if (ik == 3061) {//随机3个个固元丹
                    getGoodsReward(getRandomPetDan(1), 1, 1, list);
                    getGoodsReward(getRandomPetDan(1), 1, 1, list);
                    getGoodsReward(getRandomPetDan(1), 1, 1, list);
                } else if (ik == 3063) {//紫品逆转散
                    getGoodsReward("10000169", 1, 1, list);
                } else if (ik == 3064) {//元灵幽花
                    getGoodsReward("10000235", 1, 1, list);
                } else if (ik == 3066) {//随机3个个元魂丹
                    getGoodsReward(getRandomPetDan(2), 1, 1, list);
                    getGoodsReward(getRandomPetDan(2), 1, 1, list);
                    getGoodsReward(getRandomPetDan(2), 1, 1, list);
                } else if (ik == 3068) {//橙品逆转散
                    getGoodsReward("10000170", 1, 1, list);
                } else if (ik == 3069) {//元灵幽花
                    getGoodsReward("10000235", 1, 1, list);
                }
            }
            return list;
        } else if (ik >= 3100 && ik < 3120) {//门派任务
            int exp = (int) (1000 * lv * (0.1f + strUtils.getRandom(5, 10) * 0.01f));
            int money = 120 + lv * strUtils.getRandom(5, 10);
            getExpReward(exp, list);
            getTaleReward(money, list);
            getYinPiaoReward(money * 2, list);
            //第5环、10环有额外奖励
            int num = 0;
            JSONArray list2 = startBef.taskService.getCommitTask(name, con);
            for (Object a : list2) {
                int k = Integer.parseInt(a.toString());
                if (3100 <= k && k < 3120) {
                    num++;
                }
            }
            if (num == 5 || num == 10) {
                String goodsKey = getMpTaskRewardsKey();
                getGoodsReward(goodsKey, 1, 1, list);
            }
            return list;
        } else if (ik >= 3120 && ik < 3123) {//摸金校尉
            int exp = (int) ((ik - 3119) * 100 * lv * 0.5f);
            int money = Double.valueOf(lv * 10 * Math.pow(1.1, (ik - 3120)) + "").intValue();
            getExpReward(exp, list);
            getTaleReward(money, list);
            getYinPiaoReward(money * 2, list);
            //fixme 其他奖励在开宝箱
            return list;
        } else if (ik >= 3123 && ik < 3131) {//师徒任务
            int exp = (int) ((ik - 3122) * 100 * lv * 0.5f);
            int money = Double.valueOf(lv * 10 * Math.pow(1.1, (ik - 3123)) + "").intValue();
            getExpReward(exp, list);
            //getTaleReward(money, list);
            getYinPiaoReward(money * 2, list);
            //每层一件本职业蓝品套装(30-40级)
            int part = ik - 3123 + 1;
            int index = roleUtils.jobToIndex(model);
            String equipKey = equipData.getEquipKey(1, part, index, 3, 5);
            getGoodsReward(equipKey, 1, 1, list);
            return list;
        } else if (ik >= 3131 && ik < 3135) {//幽谷秘宝
            int exp = (int) ((ik - 3130) * 100 * lv * 0.5f);
            int money = Double.valueOf(lv * 10 * Math.pow(1.1, (ik - 3131)) + "").intValue();
            getExpReward(exp, list);
            getTaleReward(money, list);
            getYinPiaoReward(money * 2, list);
            //fixme 奖励在宝箱处
            return list;
        } else if (ik >= 3143 && ik < 3163) {//帮派任务
            int exp = (int) (1000 * lv * (0.1f + strUtils.getRandom(5, 10) * 0.01f));
            int money = 120 + lv * strUtils.getRandom(5, 10);
            getExpReward(exp, list);
            getTaleReward(money, list);
            getYinPiaoReward(money * 2, list);
            //帮贡
            getBgReward(40, list);
            //可能得到贡品奖励
            if (strUtils.isHappend(0, 100, 0.2f)) {
                getGoodsReward("10000172", 1, 1, list);
            } else if (strUtils.isHappend(0, 100, 0.2f)) {
                getGoodsReward("10000173", 1, 1, list);
            }
            return list;
        } else if (ik >= 3163 && ik < 3242) {//副本
            int exp = (int) (3000 * (1 + (ik - 3162) * 0.12f));
            int money = (int) (1000 * (1 + (ik - 3162) * 0.12f));
            getExpReward(exp, list);
            getTaleReward(500, list);
            getYinPiaoReward(money * 2, list);
            if (ik == 3164 || ik == 3166 || ik == 3167) {
                getGoodsReward(getRandomFbEquip(50), 1, 0, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                if (ik == 3167) {
                    addSklSpToFb(vipLv, 0, list);
                }
            } else if (ik == 3168) {
                //增加声望
                getSwExpReward(100, list);
            } else if (ik == 3170 || ik == 3173) {
                getGoodsReward(getRandomFbEquip(60), 1, 0, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                if (ik == 3173) {
                    addSklSpToFb(vipLv, 1, list);
                }
            } else if (ik == 3174) {
                //增加声望
                getSwExpReward(100, list);
            } else if (ik == 3179 || ik == 3180 || ik == 3182) {
                getGoodsReward(getRandomFbEquip(70), 1, 0, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                if (ik == 3182) {
                    addSklSpToFb(vipLv, 2, list);
                }
            } else if (ik == 3183) {
                //增加声望
                getSwExpReward(100, list);
            } else if (ik == 3186 || ik == 3188) {
                getGoodsReward(getRandomFbEquip(80), 1, 0, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                if (ik == 3188) {
                    addSklSpToFb(vipLv, 3, list);
                }
                //增加声望
                if (ik == 3188) getSwExpReward(100, list);
            } else if (ik == 3190 || ik == 3194) {
                getGoodsReward(getRandomFbEquip(90), 1, 0, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                if (ik == 3194) {
                    addSklSpToFb(vipLv, 4, list);
                }
            } else if (ik == 3195) {
                //增加声望
                getSwExpReward(100, list);
            } else if (ik == 3197 || ik == 3200) {
                getGoodsReward(getRandomFbEquip(100), 1, 0, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                if (ik == 3200) {
                    addSklSpToFb(vipLv, 5, list);
                }
            } else if (ik == 3202) {
                //增加声望
                getSwExpReward(100, list);
            } else if (ik == 3206) {
                //名匠之魂、制符材料（随机）、玄铁残骸x1（随机）
                getGoodsReward("10000236", 1, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward("10000219", 1, 1, list);
                }
            } else if (ik == 3211) {//1
                //名匠之魂、制符材料（随机）、暴击抗性玉石x3、玄铁残骸x1（随机）、鞋子模板（随机）
                getGoodsReward("10000236", 1, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                getGoodsReward("10000152", 3, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward("10000219", 1, 1, list);
                }
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(8), 1, 0, list);
                }
                addSklSpToFb(vipLv, 6, list);
            } else if (ik == 3212) {
                //增加声望
                getSwExpReward(200, list);
            } else if (ik == 3217) {
                //名匠之魂、制符材料（随机）、玄铁残骸x1（随机）
                getGoodsReward("10000236", 3, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward("10000219", 1, 1, list);
                }
            } else if (ik == 3219) {//2
                //名匠之魂、制符材料（随机）、混乱抗性玉石x3、玄铁残骸x1、鞋子模板（随机）
                getGoodsReward("10000236", 1, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                getGoodsReward("10000153", 3, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward("10000219", 1, 1, list);
                }
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(8), 1, 0, list);
                }
                addSklSpToFb(vipLv, 7, list);
            } else if (ik == 3220) {
                //增加声望
                getSwExpReward(200, list);
            } else if (ik == 3224) {
                //名匠之魂、制符材料（随机）、玄铁残骸x1（随机）
                getGoodsReward("10000236", 3, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward("10000219", 1, 1, list);
                }
            } else if (ik == 3227) {//3
                //名匠之魂、制符材料（随机）、流血抗性玉石x3、玄铁残骸x1、腿部模板（随机）
                getGoodsReward("10000236", 1, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                getGoodsReward("10000154", 3, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward("10000219", 1, 1, list);
                }
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(7), 1, 0, list);
                }
                addSklSpToFb(vipLv, 8, list);
            } else if (ik == 3228) {
                //增加声望
                getSwExpReward(200, list);
            } else if (ik == 3232) {
                //名匠之魂、制符材料（随机）、玄铁残骸x1（随机）
                getGoodsReward("10000236", 3, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward("10000219", 1, 1, list);
                }
            } else if (ik == 3234) {//4
                //名匠之魂、制符材料（随机）、睡眠抗性玉石x3、玄铁残骸x1、腿部模板（随机）
                getGoodsReward("10000236", 1, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                getGoodsReward("10000155", 3, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward("10000219", 1, 1, list);
                }
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(7), 1, 0, list);
                }
                addSklSpToFb(vipLv, 9, list);
                //增加声望
                getSwExpReward(200, list);
            } else if (ik == 3236) {//隐藏
                //名匠之魂x5、制符材料（随机）、千年玄铁x1、法宝洗练符x1、法宝强化符x1、腰带模板（随机）
                getGoodsReward("10000236", 5, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                getGoodsReward("10000151", 1, 1, list);
                getGoodsReward("10000166", 1, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(6), 1, 0, list);
                } else if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(5), 1, 0, list);
                }
                addSklSpToFb(vipLv, 10, list);
            } else if (ik == 3238) {
                //名匠之魂、制符材料（随机）、千年玄铁x1、法宝洗练符x1、法宝强化符x1、面具、腰带模板（随机）
                getGoodsReward("10000236", 5, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                getGoodsReward("10000151", 1, 1, list);
                getGoodsReward("10000166", 1, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(6), 1, 0, list);
                }
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(4), 1, 0, list);
                } else if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(2), 1, 0, list);
                } else if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(3), 1, 0, list);
                }
                addSklSpToFb(vipLv, 10, list);
            } else if (ik == 3240) {
                //名匠之魂、制符材料（随机）、千年玄铁x2、法宝洗练符x2、法宝强化符x2、面具、武器模板（随机）
                getGoodsReward("10000236", 5, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomZhiFuCaiLiao(), 1, 1, list);
                }
                getGoodsReward("10000151", 2, 1, list);
                getGoodsReward("10000166", 2, 1, list);
                if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(4), 1, 0, list);
                } else if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(0), 1, 0, list);
                } else if (strUtils.isHappend(0, 1000, 0.2f)) {
                    getGoodsReward(getRandomMoBan(1), 1, 0, list);
                }
                addSklSpToFb(vipLv, 10, list);
            } else if (ik == 3241) {
                //增加声望
                getSwExpReward(200, list);
            }

            return list;
        } else if (ik >= 3250 && ik < 3265) {//周日门派
            int exp = (int) ((ik - 3249) * 100 * lv * 0.5f);
            int money = Double.valueOf(lv * 10 * Math.pow(1.1, (ik - 3249)) + "").intValue();
            getExpReward(exp, list);
            getTaleReward(money, list);
            getYinPiaoReward(money * 2, list);
            //完成3141前三名队伍有额外奖励，完成3142（击败震天有额外奖励）
            int r1 = staticCollection.mpcgMap.get("r1");
            int r2 = staticCollection.mpcgMap.get("r2");
            if (ik == 3262 && r1 < 4) {
                staticCollection.mpcgMap.put("r1", r1 + 1);
                //锻皇宝石
                if (r1 == 1) getGoodsReward("10000107", 5, 0, list);
                else if (r1 == 2) getGoodsReward("10000107", 3, 0, list);
                else if (r1 == 3) getGoodsReward("10000107", 1, 0, list);
            } else if (ik == 3264 && r2 < 4) {
                staticCollection.mpcgMap.put("r2", r2 + 1);
                //圣锻皇
                if (r2 == 1) {
                    getGoodsReward("10000108", 1, 0, list);
                    rewardUtils.noticeReward(10, name, list);
                }
                //锻皇
                else if (r2 == 2) getGoodsReward("10000107", 5, 0, list);
                else if (r2 == 3) getGoodsReward("10000107", 3, 0, list);
            }
            return list;
        } else if (ik >= 3265 && ik < 3272) {//魔神日常
            getExpReward(50000, list);
            getTaleReward(20000, list);
            getGoodsReward("10000143", 1, 1, list);
            return list;
        } else if (ik >= 3275 && ik < 3282) {//盗梦空间
            int exp = (int) (212400 * (0.4f + (ik - 3275) * 0.1f));
            getExpReward(exp, list);
            //梦幻水晶打怪时已经掉落
            return list;
        } else if (ik == 3272) {//锄奸卫道
            int exp = (int) (106200 * (0.4f + (lv / 100f) * 0.6f));
            getExpReward(exp, list);
            return list;
        } else if (ik == 3273) {//仗剑除魔
            int exp = (int) (5310 * (0.4f + (lv / 100f) * 0.6f));
            getExpReward(exp, list);
            return list;
        } else if (ik == 3282) {//采阴补阳
            getGoodsReward("10000202", 1, 1, list);
            return list;
        } else if (ik >= 3283 && ik < 3288) {//监狱风云
            String[] arr = {"10000203", "10000204", "10000205", "10000206", "10000207"};
            getGoodsReward(arr[ik - 3283], 1, 0, list);
            return list;
        } else if (ik >= 3288 && ik < 3291) {//王者遗产
            //获取藏宝图的key，判断是哪一星
            list = startBef.wzycService.getWzycReward(name, con);
            return list;
        } else if (ik >= 1000 && ik < 2000) {
            //主线任务
            int exp = Double.valueOf(100 + 520 * Math.pow(1.5, (ik - 1000) / 10f) + "").intValue();
            //int money = Double.valueOf(100 + 173 * Math.pow(1.5, (ik - 1000) / 15f) + "").intValue();
            //全部主线最多10000银两，避免刷银两 第一项10 第200项为190
            int money = 10 + 2 * (ik - 999);
            int yp = Double.valueOf(100 + 173 * Math.pow(1.5, (ik - 1000) / 15f) + "").intValue();
            getExpReward(exp, list);
            getTaleReward(money, list);
            getYinPiaoReward(yp, list);
            //根据职业给予
            int job = roleUtils.jobToIndex(model);
            //额外奖励
            addElseReward(ik, job, list);
            /*putGqjz(list);
            if (strUtils.isInDay("2023-05-01 00:00:00", "2023-05-03 23:59:00")) {
                for (Object o : list) {
                    reward reward = (reward) o;
                    reward.setDoubleGoodsNum();
                }
            }*/
            return list;
        } else if (ik >= 2000 && ik < 3000) {
            //支线任务
            int exp = Double.valueOf(100 + 520 * Math.pow(1.5, (ik - 2000) / 10f) + "").intValue();
            //全部主线最多10000银两，避免刷银两 第一项10 第200项为190
            int money = 10 + 2 * (ik - 1999);
            int yp = Double.valueOf(100 + 173 * Math.pow(1.5, (ik - 2000) / 15f) + "").intValue();
            getExpReward(exp, list);
            getTaleReward(money, list);
            getYinPiaoReward(yp, list);
            //根据职业给予
            int job = roleUtils.jobToIndex(model);
            //额外奖励
            addElseReward(ik, job, list);
            return list;
        } else {
            if (systemUtils.isWindows()) {
                System.err.println("未设置奖励" + key);
            }
        }


        return null;
    }

    /**
     * 主线任务对额外奖励的处理
     */
    private static void addElseReward(int taskKey, int job, JSONArray list) {
        //目前共117个任务
        if (taskKey == 1000) {
            //封妖石（打开后可获得赤翼蝠）
            getGoodsReward("10000233", 1, 1, list);
            //大药囊
            getGoodsReward("100110060001", 1, 1, list);
        }
        if (taskKey == 1001) {
            //蓝装 武器、相应职业、10级内、任意套装
            /*String equipKey = equipData.getEquipKey(1, 0, job, 0, 0);
            getGoodsReward(equipKey, 1, 1, list);*/
        } else if (taskKey == 1002) {
            /*String equipKey = equipData.getEquipKey(1, 1, job, 0, 0);
            getGoodsReward(equipKey, 1, 1, list);*/
        } else if (taskKey == 1003) {
            /*String equipKey = equipData.getEquipKey(1, 2, job, 0, 0);
            getGoodsReward(equipKey, 1, 1, list);*/
        } else if (taskKey == 1004) {
            String equipKey = equipData.getEquipKey(1, 2, job, 0, 0);
            getGoodsReward(equipKey, 1, 1, list);
        } else if (taskKey == 1005) {
            String equipKey = equipData.getEquipKey(1, 3, job, 0, 0);
            getGoodsReward(equipKey, 1, 1, list);
        } else if (taskKey == 1006) {
            String equipKey = equipData.getEquipKey(1, 4, job, 1, 0);
            getGoodsReward(equipKey, 1, 1, list);
        } else if (taskKey == 1008) {

        } else if (taskKey == 1023) {
            //技能书 命术
            getGoodsReward("100210010242", 1, 1, list);
        } else if (taskKey == 2004) {
            //法宝
            getGoodsReward("100110070000", 1, 1, list);
        }
    }


    /**
     * 国庆集字
     */
    public static void putGqjz(JSONArray list) {
        /*if (strUtils.isInDay("2022-10-01 00:00:00", "2022-10-08 00:00:00")) {
            String[] arr = {
                    "1069", "1070", "1071", "1072"
            };
            list.add(new reward().bindGoods(getGoods(arr[strUtils.getRandom(0, 4)], 1)));
        }*/
        /*if (strUtils.isInDay("2022-11-11 00:00:00", "2022-11-17 00:00:00")) {
            int i = strUtils.getRandom(1, 1000);
            String k = "1078";
            if (i == 655) {
                k = "1074";
            } else if (i > 100 && i <= 200) {
                k = "1075";
            } else if (i > 200 && i <= 350) {
                k = "1076";
            } else if (i > 350 && i <= 600) {
                k = "1077";
            }
            list.add(new reward().bindGoods(getGoods(k, 1)));
        }*/
        /*if (strUtils.isInDay("2023-01-01 00:00:00", "2023-01-04 00:00:00")) {
            if (strUtils.getRandom(0, 100) == 66) {
                String k = "1081";
                list.add(new reward().bindGoods(getGoods(k, 1)));
            }
        }*/
        //集字0-9
        /*if (strUtils.isInDay("2023-01-16 00:00:00", "2023-01-31 23:00:00")) {
            String k = "1085" + strUtils.getRandom(0, 10);
            list.add(new reward().bindGoods(getGoods(k, 1)));
        }*/

    }

    /**
     * 随机一个模板，按部位
     * i=0-8
     * “武器”，"玉坠", "戒指", "玉镯", "头冠", "铠甲", "束腰", "护腿", "长靴"
     */
    private static String getRandomMoBan(int i) {//39-41
        //武器 1部位6职业3等级 1*6*3
        //项链、戒指 1部位1职业3等级 1*1*3
        //其他 1部位3职业3等级 1*3*3
        int start = 0, end = 0;
        int kd = 1;//按职业等分
        if (i == 0) {
            end = 18;
            kd = 6;
        } else if (i == 1 || i == 2) {
            start = 18 + 3 * (i - 1);
            end = start + 3 * (i);
        } else {
            start = 18 + 6 + 9 * (i - 3);
            end = start + 6 + 9 * (i - 2);
            kd = 3;
        }
        //3级 6级 10级
        if (strUtils.isHappend(0, 1000, 0.2f)) {//10级
            start = start + 2 * kd;
            end = start + kd;
        } else if (strUtils.isHappend(0, 1000, 0.5f)) {//6级
            start = start + 1 * kd;
            end = start + kd;
        } else {
            start = start + 0 * kd;
            end = start + kd;
        }
        int r = strUtils.getRandom(start, end);
        String str = r + "";
        int len = 4 - str.length();
        for (int p = 0; p < len; p++) {
            str = "0" + str;
        }
        return "1010" + str;
    }

    /**
     * 随机一个制符材料
     */
    private static String getRandomZhiFuCaiLiao() {
        int i = strUtils.getRandom(0, 14);
        String str = i + "";
        int len = 4 - str.length();
        for (int p = 0; p < len; p++) {
            str = "0" + str;
        }
        return "1015" + str;
    }

    /**
     * 随机获取一件装备
     */
    private static String getRandomEquip(int lv) {
        int quality = 2;
        String equipKey = equipData.getEquipKey(quality, null, null, lv / 10 - 1, null);
        return equipKey;
    }

    /**
     * 输入等级获取副本装备
     * 比如100级只能有95级以上装备
     * 90级有86到95装备
     */
    private static String getRandomFbEquip(int lv) {
        int quality = 2;
        //90级只有86-94
        int[] parts1 = {0, 1, 3, 5, 7};//90，88
        int[] parts2 = {2, 4, 6, 8};//92
        int part = 0;
        if (lv < 100) {
            int r = strUtils.getRandom(0, 2);
            if (r == 1) lv += 10;
            if (r == 0) part = parts1[strUtils.getRandom(0, parts1.length)];
            else part = parts2[strUtils.getRandom(0, parts2.length)];
        } else {
            part = parts1[strUtils.getRandom(0, parts1.length)];
        }
        String equipKey = equipData.getEquipKey(quality, part, null, lv / 10 - 1, null);
        return equipKey;
    }

    private static JSONObject getGoods(String key, Integer num) {
        JSONObject obj = new JSONObject();
        obj.put("key", key);
        obj.put("num", num);
        return obj;
    }

    /**
     * 是否为货币类型
     */
    public static boolean isMoneyType(String k) {
        if (k.equals("tale") || k.equals("gold") || k.equals("yp") || k.equals("jf")
                || k.equals("wxz") || k.equals("bg") || k.equals("xld") || k.equals("bb")
                || k.equals("jmPoint") || k.equals("ldjf") || k.equals("cbjf") || k.equals("jungong")) {
            return true;
        }
        return false;
    }

    /**
     * 货币类型转字符串
     */
    public static String moneyTypeToStr(int moneyType) {
        String k = null;
        if (moneyType == 0) k = "gold";
        else if (moneyType == 1) k = "tale";
        else if (moneyType == 2) k = "yp";
        else if (moneyType == 3) k = "jf";
        else if (moneyType == 4) k = "wxz";
        else if (moneyType == 5) k = "bg";
        else if (moneyType == 6) k = "xld";
        else if (moneyType == 7) k = "bb";
        else if (moneyType == 8) k = "jmPoint";
        else if (moneyType == 9) k = "ldjf";
        else if (moneyType == 10) k = "cbjf";
        else if (moneyType == 11) k = "jungong";
        return k;
    }

}

class reward {
    //经验、货币、道具
    public Integer type;
    public Integer exp;
    public Integer petExp;
    public Integer moneyType;
    public Long money;

    public JSONObject goods;

    public JSONObject pet;

    public Integer vip;
    //声望经验
    public Integer swExp;

    public reward bindExp(Integer exp) {
        this.type = 0;
        this.exp = exp;
        this.petExp = exp / 2;
        return this;
    }

    public reward bindExp(Integer exp, Integer petExp) {
        this.type = 0;
        this.exp = exp;
        this.petExp = petExp;
        return this;
    }

    /**
     * moneyType
     * 0元宝1银两2银票3竞技积分4武勋值5帮贡6修炼点7帮币8经脉点
     * 9领地积分10传壁积分11军功
     */
    public reward bindMoney(Integer moneyType, Long money) {
        this.type = 1;
        this.moneyType = moneyType;
        this.money = money;
        return this;
    }

    public reward bindGoods(JSONObject goods) {//:{key,num}
        this.type = 2;
        this.goods = goods;
        return this;
    }

    /**
     * 设置双倍产出
     */
    public void setDoubleGoodsNum() {
        if (this.goods != null) {
            this.goods.put("num", this.goods.getInteger("num") * 2);
        }
    }

    public reward bindPet(JSONObject pet) {
        this.type = 3;
        this.pet = pet;
        return this;
    }

    public reward bindVip(Integer vip) {
        this.type = 4;
        this.vip = vip;
        return this;
    }

    public reward bindSwExp(Integer swExp) {
        this.type = 5;
        this.swExp = swExp;
        return this;
    }
}
