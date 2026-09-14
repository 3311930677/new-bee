package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.db.mybatisConfig;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.fileUtils;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static my.utils.staticCollection.*;

/**
 * 投资
 */
public class investService {
    private boolean isDapanC = false;
    private int dapanIndex;
    private boolean isQihuoC = false;
    private int qihuoIndex;
    private boolean qihuoIsFeng = false;

    public result setCont(JSONObject j,
                          @paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (!name.equals("梅仁义")) {
            return new result(0);
        }
        int type = j.getInteger("type");
        if (type == 0) {
            isDapanC = true;
            dapanIndex = j.getInteger("index");
        } else {
            isQihuoC = true;
            qihuoIndex = j.getInteger("index");
            qihuoIsFeng = false;
            if (j.getInteger("isFeng") == 1) qihuoIsFeng = true;
        }
        return new result(200, 1);
    }

    public result cancelCont(JSONObject j,
                             @paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (!name.equals("梅仁义")) {
            return new result(0);
        }
        int type = j.getInteger("type");
        if (type == 0) isDapanC = false;
        else isQihuoC = false;
        return new result(200, 1);
    }
    //=================期货============

    /**
     * 投资期货的产品
     */
    public result getQihuoTZ() {
        JSONObject obj = new JSONObject();
        for (int i = 0; i < 8; i++) {
            if (obj.getInteger("gold_" + i) == null) {
                obj.put("gold_" + i, 0);
            }
            if (obj.getInteger("tale_" + i) == null) {
                obj.put("tale_" + i, 0);
            }
        }
        for (JSONObject d : qihuoPlayer) {
            for (int i = 0; i < 8; i++) {
                Integer v = 0;
                if (d.getInteger("bet") == i) {
                    if (d.getInteger("moneyType") == 0) {
                        String ltpKey = d.getString("value");
                        if (ltpKey.equals("10000000")) v = 1000;
                        else if (ltpKey.equals("10000001")) v = 500;
                        else v = 100;
                        obj.put("gold_" + i, obj.getInteger("gold_" + i) + v);
                    } else {
                        obj.put("tale_" + i, obj.getInteger("tale_" + i) + d.getInteger("value"));
                    }
                }
            }
        }

        List<String> arr = new ArrayList<>();
        arr.add("元宝投资：");
        arr.add("锻造宝石：" + obj.getInteger("gold_0"));
        arr.add("精炼宝石：" + obj.getInteger("gold_1"));
        arr.add("镶嵌宝石：" + obj.getInteger("gold_2"));
        arr.add("修复宝石：" + obj.getInteger("gold_3"));
        arr.add("黑洞陨石：" + obj.getInteger("gold_4"));
        arr.add("天晶石：" + obj.getInteger("gold_5"));
        arr.add("玉魄石：" + obj.getInteger("gold_6"));
        arr.add("补天玄石：" + obj.getInteger("gold_7"));

        arr.add("银两投资：");
        arr.add("锻造宝石：" + obj.getInteger("tale_0"));
        arr.add("精炼宝石：" + obj.getInteger("tale_1"));
        arr.add("镶嵌宝石：" + obj.getInteger("tale_2"));
        arr.add("修复宝石：" + obj.getInteger("tale_3"));
        arr.add("黑洞陨石：" + obj.getInteger("tale_4"));
        arr.add("天晶石：" + obj.getInteger("tale_5"));
        arr.add("玉魄石：" + obj.getInteger("tale_6"));
        arr.add("补天玄石：" + obj.getInteger("tale_7"));
        return new result(200, arr);
    }

    /**
     * 期货行情
     */
    public result getQihuoHQ() {

        List<String> arr = new ArrayList<>();
        for (JSONObject t : qihuoHQ) {
            String text = "";
            text += "第" + t.getInteger("item") + "期：";
            text += getTextQihuo(t);
            arr.add(text);
        }
        return new result(200, arr);
    }

    /**
     * 投资期货
     */
    public result investQihuo(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        if (!startBef.activityService.isOpenByConfig("qihuo") || isCreateQiHuo)
            return new result(696);
        if (user.msg.getInteger("lever") < 30)
            return new result(0);
        final String sender = user.name;
        j.put("sender", sender);
        //一个时间段只能投资一次
        if (!this.isExistQihuo(j, qihuoPlayer)) {
            int i = 0;
            if (j.getInteger("moneyType") == 0) {
                //龙头票数量--
                JSONObject one = startBef.packageService.getOneByKey(j.getString("value"), sender, con);
                if (one == null || one.getInteger("num") <= 0 ||
                        (!one.getString("key").equals("10000000") &&
                                !one.getString("key").equals("10000001") &&
                                !one.getString("key").equals("10000002")))
                    return new result(200, 0);
                i = startBef.packageService.cutPlayerGoodsNumByKey(one.getString("key"), 1, sender, con);
            } else {
                if (j.getInteger("value") <= 0 ||
                        (j.getInteger("value") != 1000 &&
                                j.getInteger("value") != 10000 &&
                                j.getInteger("value") != 100000)) {
                    return new result(0);
                }
                i = startBef.manService.saveMoney(1, -j.getLong("value"), sender, con);
            }
            if (i == 1) {
                qihuoPlayer.add(j);
                //loggerUtils.info("投资成功:\n" + j, investController.class);
                return new result(200, 1);
            }
            return new result(0);
        }
        return new result(200, 2);
    }

    private boolean isExistQihuo(JSONObject j, LinkedBlockingQueue<JSONObject> queue) {
        for (JSONObject obj : queue) {
            String sender1 = obj.getString("sender");
            String sender2 = j.getString("sender");
            Integer bet1 = obj.getInteger("bet");
            Integer bet2 = j.getInteger("bet");
            //投资的类型也一样时
            if (sender1.equals(sender2) && bet1 == bet2) {
                return true;
            }
        }
        return false;
    }

    /**
     * 生成期货结果
     */
    private static boolean isCreateQiHuo = false;

    public void createQhResult() {
        isCreateQiHuo = true;
        try {
            Thread.sleep(2000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        //生成结果
        JSONObject qhRes = getQihuoRes();
        //添加进行情中
        addQihuoHQ(qhRes);
        //对所有人进行通知结果
        noticeQHRes(qhRes);
        //对投资者发送邮件
        noticeQHEmails(qhRes);
        isCreateQiHuo = false;
    }

    public void noticeQHEmails(JSONObject res) {
        //name-[bet]
        JSONObject obj = new JSONObject();
        while (!qihuoPlayer.isEmpty()) {
            try {
                JSONObject j = qihuoPlayer.poll();
                //int bet = j.getInteger("bet");
                if (obj.get(j.getString("sender")) == null) {
                    obj.put(j.getString("sender"), new JSONArray());
                }
                //收集玩家的投资类型及数量
                obj.getJSONArray(j.getString("sender")).add(j);
            } catch (Exception e) {
                loggerUtils.error(e.getMessage(), this.getClass());
            }
        }
        long addGoldSum = 0;//总投入
        long cutGoldSum = 0;//回报
        StringBuilder builder = new StringBuilder();

        for (String key : obj.keySet()) {
            builder.append("黑市期货市场最新消息：第" + staticCollection.investItem + "期：" + getTextQihuo(res) + "，您投资的有");
            Object[] enclosure = {};
            int tale = 0;
            boolean b = false;
            JSONArray arr = obj.getJSONArray(key);
            for (Object o : arr) {
                JSONObject temp = (JSONObject) o;
                int bet = temp.getInteger("bet");
                int num = res.getInteger("num");//当前倍数
                if (bet == res.getInteger("bet")) {
                    b = true;//中了
                    if (temp.getInteger("moneyType") == 0) {//0元宝1银两
                        String ltpKey = temp.getString("value");
                        enclosure = Arrays.copyOf(enclosure, 1);
                        enclosure[0] = getLTP(num, ltpKey);
                        if (ltpKey.equals("10000000")) {
                            addGoldSum += 1000;
                            cutGoldSum += 1000 * num;
                        } else if (ltpKey.equals("10000001")) {
                            addGoldSum += 500;
                            cutGoldSum += 500 * num;
                        } else if (ltpKey.equals("10000002")) {
                            addGoldSum += 100;
                            cutGoldSum += 100 * num;
                        }
                    } else {
                        tale = temp.getInteger("value") * num;
                    }
                } else {
                    if (temp.getInteger("moneyType") == 0) {
                        String ltpKey = temp.getString("value");
                        if (ltpKey.equals("10000000")) addGoldSum += 1000;
                        else if (ltpKey.equals("10000001")) addGoldSum += 500;
                        else if (ltpKey.equals("10000002")) addGoldSum += 100;
                    }

                }
                builder.append("[" + betToName(bet) + "],");
            }
            if (b) {
                builder.append("恭喜您获得红利！");
            } else {
                builder.append("投资失败！");
            }
            //发送邮件
            DefaultSqlSession con = null;
            try {
                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                startBef.emailService.sendSysEmail(key, builder.toString(), enclosure, tale, con);
                builder.delete(0, builder.length());
                mybatisConfig.commit(con);
            } catch (Exception e) {
                mybatisConfig.rollback(con);
                loggerUtils.error("投资邮件发送失败：" + " " + e.getMessage(), this.getClass());
            } finally {
                mybatisConfig.close(con);
            }
        }

        addInvestLog(staticCollection.investItem, 1, addGoldSum, cutGoldSum);
    }

    private void addInvestLog(int item, int type, long addGoldSum, long cutGoldSum) {
        String itemStr = item + "";
        if (type == 0) {
            if (isDapanC) itemStr += "-c";
        } else {
            if (isQihuoC) itemStr += "-c";
        }
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
            ac.addInvestLog(strUtils.getId(), itemStr, type + "",
                    addGoldSum + "", cutGoldSum + "", strUtils.getTime() + "");
            mybatisConfig.commit(con);
        } catch (Exception e) {
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    private String betToName(int bet) {
        String result = null;
        if (bet == 0) {
            result = "锻造宝石 ";
        } else if (bet == 1) {
            result = "精炼宝石 ";
        } else if (bet == 2) {
            result = "镶嵌宝石 ";
        } else if (bet == 3) {
            result = "修复宝石 ";
        } else if (bet == 4) {
            result = "黑洞陨石 ";
        } else if (bet == 5) {
            result = "天晶石 ";
        } else if (bet == 6) {
            result = "玉魄石 ";
        } else if (bet == 7) {
            result = "补天玄石 ";
        }
        return result;
    }

    /**
     * 公布期货结果
     */
    private void noticeQHRes(JSONObject res) {
        List<String> l = new ArrayList<>();
        int num0 = 0;
        for (JSONObject d : qihuoPlayer) {
            if (num0 >= 3) break;
            if (d.getInteger("bet") == res.getInteger("bet")) {
                l.add(d.getString("sender"));
                num0++;
            }
        }
        String sm = getSystemQHMsg(res, l);
        startBef.chatService.putSysMsg(sm);
        l.clear();
    }

    /**
     * 0锻造宝石3\5     35%      50%
     * * 1精炼宝石3\10    15%
     * * 2镶嵌宝石3\10    15%
     * * 3修复宝石3\10    15%
     * * 4黑洞陨石3\10    7.5%     60%
     * * 5天晶石3\20      7.5%
     * * 6玉魄石3\20      7.5%
     * * 7圣锻皇宝石10\40  5%      80%
     *
     * @param res
     * @param players
     * @return
     */
    public String getSystemQHMsg(JSONObject res, List<String> players) {
        String result = getTextQihuo(res);
        String pl = "";
        if (players.size() > 0) {
            for (String p : players) {
                pl += "[" + p + "]";
            }
            if (!pl.equals("")) pl += "等";
        }
        return "黑市期货市场最新消息：第" + staticCollection.investItem + "期：" + result + "，恭喜" + pl + "投资者获得红利！";
    }

    public String getTextQihuo(JSONObject res) {
        Integer bet = res.getInteger("bet");
        Integer num = res.getInteger("num");
        String str = "流行";
        if (num > 3) str = "风靡";
        String result = null;
        if (bet == 0) {
            result = "锻造宝石 " + str + "，[" + num + "]倍红利！";
        } else if (bet == 1) {
            result = "精炼宝石 " + str + "，[" + num + "]倍红利！";
        } else if (bet == 2) {
            result = "镶嵌宝石 " + str + "，[" + num + "]倍红利！";
        } else if (bet == 3) {
            result = "修复宝石 " + str + "，[" + num + "]倍红利！";
        } else if (bet == 4) {
            result = "黑洞陨石 " + str + "，[" + num + "]倍红利！";
        } else if (bet == 5) {
            result = "天晶石 " + str + "，[" + num + "]倍红利！";
        } else if (bet == 6) {
            result = "玉魄石 " + str + "，[" + num + "]倍红利！";
        } else if (bet == 7) {
            if (num < 40) str = "流行";
            result = "补天玄石 " + str + "，[" + num + "]倍红利！";
        }
        return result;
    }

    /**
     * 添加到期货行情
     */
    public void addQihuoHQ(JSONObject res) {
        //最多记录7个
        if (qihuoHQ.size() > 7) {
            qihuoHQ.remove(0);
        }
        qihuoHQ.add(res);
    }

    /**
     * 生成期货结果
     * 0锻造宝石3\5     35%      50%
     * 1精炼宝石3\10    15%
     * 2镶嵌宝石3\10    15%
     * 3修复宝石3\10    15%
     * 4黑洞陨石3\10    7.5%     60%
     * 5天晶石3\20      7.5%
     * 6玉魄石3\20      7.5%
     * 7圣锻皇宝石10\40  5%      80%
     * <p>
     * 返回结果+倍数
     */
    private JSONObject getQihuoRes() {
        int bet = 0;
        int num = 3;
        if (strUtils.isHappend(0, 1000, 0.8f)) {
            bet = strUtils.getRandom(0, 5);
            if (bet == 0) num = 5;
            else if (bet == 1) num = 10;
            else if (bet == 2) num = 10;
            else if (bet == 3) num = 10;
            else if (bet == 4) num = 10;
            if (strUtils.isHappend(0, 1000, 0.8f)) num = 3;
        } else if (strUtils.isHappend(0, 1000, 0.3f)) {
            bet = 5;
            if (strUtils.isHappend(0, 1000, 0.8f)) num = 3;
            else num = 20;
        } else if (strUtils.isHappend(0, 1000, 0.3f)) {
            bet = 6;
            if (strUtils.isHappend(0, 1000, 0.8f)) num = 3;
            else num = 20;
        } else if (strUtils.isHappend(0, 1000, 0.1f)) {
            bet = 7;
            if (strUtils.isHappend(0, 1000, 0.8f)) num = 10;
            else num = 40;
        }
        if (isQihuoC) {
            isQihuoC = false;
            bet = qihuoIndex;
            int[] nums1 = {3, 3, 3, 3, 3, 3, 3, 10};
            int[] nums2 = {5, 10, 10, 10, 10, 20, 20, 40};
            num = nums1[bet];
            if (qihuoIsFeng) {
                num = nums2[bet];
            }
        }
        JSONObject j = new JSONObject();
        j.put("bet", bet);
        j.put("num", num);
        j.put("item", staticCollection.investItem);
        return j;
    }
    //=================大盘==============

    /**
     * 投资记录
     */
    public result getDapanTZ() {
        int gold_0 = 0;
        int gold_1 = 0;
        int gold_2 = 0;
        int tale_0 = 0;
        int tale_1 = 0;
        int tale_2 = 0;
        for (JSONObject d : dapanPlayer) {
            Integer v = 0;
            if (d.getInteger("bet") == 0) {
                if (d.getInteger("moneyType") == 0) {
                    String ltpKey = d.getString("value");
                    if (ltpKey.equals("10000000")) v = 1000;
                    else if (ltpKey.equals("10000001")) v = 500;
                    else v = 100;
                    gold_0 += v;
                } else {
                    tale_0 += d.getInteger("value");
                }
            } else if (d.getInteger("bet") == 1) {
                if (d.getInteger("moneyType") == 0) {
                    String ltpKey = d.getString("value");
                    if (ltpKey.equals("10000000")) v = 1000;
                    else if (ltpKey.equals("10000001")) v = 500;
                    else v = 100;
                    gold_1 += v;
                } else {
                    tale_1 += d.getInteger("value");
                }
            } else if (d.getInteger("bet") == 2) {
                if (d.getInteger("moneyType") == 0) {
                    String ltpKey = d.getString("value");
                    if (ltpKey.equals("10000000")) v = 1000;
                    else if (ltpKey.equals("10000001")) v = 500;
                    else v = 100;
                    gold_2 += v;
                } else {
                    tale_2 += d.getInteger("value");
                }
            }
        }
        List<String> arr = new ArrayList<>();
        arr.add("元宝投资：");
        arr.add("大盘涨：" + gold_0);
        arr.add("大盘跌：" + gold_1);
        arr.add("大盘持平：" + gold_2);
        arr.add("银两投资：");
        arr.add("大盘涨：" + tale_0);
        arr.add("大盘跌：" + tale_1);
        arr.add("大盘持平：" + tale_2);
        return new result(200, arr);
    }

    /**
     * 大盘往期行情
     */
    public result getDapanHQ() {
        List<String> arr = new ArrayList<>();
        for (JSONObject t : DapanHQ) {
            String text = "";
            Integer item = t.getInteger("item");
            text += "第" + item + "期：大盘";
            Integer r = t.getInteger("res");
            if (r == 0) {//涨
                text += "涨";
            } else if (r == 1) {
                text += "跌";
            } else {
                text += "持平";
            }
            arr.add(text);
        }
        return new result(200, arr);
    }

    /**
     * 大盘投资
     */
    public result investDapan(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        if (!startBef.activityService.isOpenByConfig("dapan") || isCreateDapan)
            return new result(696);
        if (user.msg.getInteger("lever") < 30)
            return new result(0);
        final String name = user.name;
        j.put("sender", name);
        //一个时间段只能投资一次
        if (this.isExist(j, dapanPlayer)) {
            return new result(200, 2);
        }
        int i = 0;
        if (j.getInteger("moneyType") == 0) {
            //龙头票数量--
            JSONObject one = startBef.packageService.getOneByKey(j.getString("value"), name, con);
            if (one == null || one.getInteger("num") <= 0 ||
                    (!one.getString("key").equals("10000000") &&
                            !one.getString("key").equals("10000001") &&
                            !one.getString("key").equals("10000002")))
                return new result(0);
            i = startBef.packageService.cutPlayerGoodsNumByKey(one.getString("key"), 1, name, con);
        } else {
            if (j.getInteger("value") <= 0 ||
                    (j.getInteger("value") != 1000 &&
                            j.getInteger("value") != 10000 &&
                            j.getInteger("value") != 100000)) {
                return new result(0);
            }
            i = startBef.manService.saveMoney(1, -j.getLong("value"), name, con);
        }
        if (i == 1) {
            dapanPlayer.add(j);
            return new result(200, 1);
        }
        return new result(0);
    }

    /**
     * 判断是否已经投资过了
     *
     * @param j
     * @return
     */
    private boolean isExist(JSONObject j, LinkedBlockingQueue<JSONObject> queue) {
        for (JSONObject obj : queue) {
            String sender1 = obj.getString("sender");
            String sender2 = j.getString("sender");
            if (sender1.equals(sender2)) {
                return true;
            }
        }
        return false;
    }

    /**
     * 生成结果
     */
    private static boolean isCreateDapan = false;

    public void createDpResult() {
        isCreateDapan = true;
        //生成结果
        int dapanRes = getDapanRes();
        //添加进行情中
        addDapanHQ(dapanRes);
        //对所有人进行通知大盘结果
        noticeDapanRes(dapanRes);
        //对投资者发送邮件
        noticeEmails(dapanRes);

        staticCollection.putTask(() -> {
            staticCollection.investItem++;
            if (staticCollection.investItem >= 1000) staticCollection.investItem = 1;
        }, 10, TimeUnit.SECONDS);
        isCreateDapan = false;
    }

    /**
     * 对投资者发送邮件
     */
    public void noticeEmails(int res) {
        long addGoldSum = 0;
        long cutGoldSum = 0;
        while (!dapanPlayer.isEmpty()) {
            try {
                JSONObject j = dapanPlayer.poll();
                //如果该玩家投资中了，则发邮件
                int bet = j.getInteger("bet");
                JSONObject rs = null;
                int num = bet == 2 ? 30 : 2;
                if (bet == res) {//涨跌持平
                    Object[] enclosure = {};
                    int tale = 0;
                    if (j.getInteger("moneyType") == 0) {//0元宝1银两
                        //添加龙头票附件
                        String ltpKey = j.getString("value");
                        enclosure = new Object[1];
                        enclosure[0] = getLTP(num, ltpKey);
                        if (ltpKey.equals("10000000")) {
                            addGoldSum += 1000;
                            cutGoldSum += 1000 * num;
                        } else if (ltpKey.equals("10000001")) {
                            addGoldSum += 500;
                            cutGoldSum += 500 * num;
                        } else if (ltpKey.equals("10000002")) {
                            addGoldSum += 100;
                            cutGoldSum += 100 * num;
                        }
                    } else {
                        tale = j.getInteger("value") * num;
                    }
                    rs = getSystemEmail(j.getString("sender"), res, enclosure, tale, true);

                } else {
                    rs = getSystemEmail(j.getString("sender"), res, new Object[0], 0, false);
                    if (j.getInteger("moneyType") == 0) {
                        String ltpKey = j.getString("value");
                        if (ltpKey.equals("10000000")) addGoldSum += 1000;
                        else if (ltpKey.equals("10000001")) addGoldSum += 500;
                        else if (ltpKey.equals("10000002")) addGoldSum += 100;
                    }
                }
                DefaultSqlSession con = null;
                try {
                    con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                    startBef.emailService.email(rs, con);
                    mybatisConfig.commit(con);
                } catch (Exception e) {
                    mybatisConfig.rollback(con);
                    loggerUtils.error("投资邮件发送失败：" + rs + " " + e.getMessage(), this.getClass());
                } finally {
                    mybatisConfig.close(con);
                }
                //loggerUtils.info("发送邮件:\n" + j, investController.class);
            } catch (Exception e) {
                loggerUtils.error(e.getMessage(), this.getClass());
            }
        }
        addInvestLog(staticCollection.investItem, 0, addGoldSum, cutGoldSum);
    }

    /**
     * 获取系统邮件结构
     */
    public JSONObject getSystemEmail(String receiver, int i, Object[] enclosure, int tale, boolean isSuccess) {
        String result;
        if (i == 0) {
            result = "大盘涨";
        } else if (i == 1) {
            result = "大盘跌";
        } else {
            result = "大盘持平";
        }
        JSONObject msg = new JSONObject();
        msg.put("title", "系统邮件");
        msg.put("sender", "系统");
        msg.put("receiver", receiver);
        if (isSuccess) {
            msg.put("content", "黑市期货大盘最新消息：第" + staticCollection.investItem + "期：" + result + "，恭喜投资者获得红利！");
        } else {
            msg.put("content", "黑市期货大盘最新消息：第" + staticCollection.investItem + "期：" + result + "，投资失败！");
        }

        msg.put("price", 0);
        msg.put("priceType", 1);
        msg.put("tale", tale);
        msg.put("enclosure", enclosure);
        return msg;
    }

    /**
     * 获取一个龙头票数据结构
     * Id: 'm1', key: '0x003', isBind: false, position: 1, num: 1,
     * attrs: { gold: 10000000 },
     *
     * @return
     */
    public JSONObject getLTP(int num, String key) {
        JSONObject j = new JSONObject();
        j.put("Id", strUtils.getId());
        j.put("key", key);
        j.put("pos", 0);
        j.put("isBind", 0);
        j.put("num", num);
        j.put("enType", 0);//附件类型
        return j;
    }

    private void noticeDapanRes(int res) {
        List<String> l = new ArrayList<>();
        int num0 = 0;
        for (JSONObject d : dapanPlayer) {
            if (num0 >= 3) break;
            if (d.getInteger("bet") == res) {
                l.add(d.getString("sender"));
                num0++;
            }
        }
        startBef.chatService.putSysMsg(getSystemMsg(res, l));
        l.clear();
    }

    /**
     * 返回一个系统消息结构
     * sender: { name: role.name, username: role.username },
     * receiver: this.receiver,
     * type: this.window_choose,
     * pic: img.head,
     * content: t.text,
     * time:new Date().getTime(),
     *
     * @return
     */
    public String getSystemMsg(int i, List<String> players) {
        String result;
        if (i == 0) {
            result = "大盘涨";
        } else if (i == 1) {
            result = "大盘跌";
        } else {
            result = "大盘持平";
        }
        String pl = "";
        if (players.size() > 0) {
            for (String p : players) {
                pl += "[" + p + "]";
            }
            if (!pl.equals("")) pl += "等";
        }
        return "黑市期货大盘最新消息：第" + staticCollection.investItem + "期：" + result + "，恭喜" + pl + "投资者获得红利！";
    }

    /**
     * 生成大盘结果
     */
    private int getDapanRes() {
        int p = strUtils.getRandom(1, 102);
        int res;
        if (p > 100) res = 2;
        else if (p < 50) res = 1;
        else res = 0;//0是涨
        if (isDapanC) {
            isDapanC = false;
            res = dapanIndex;
        }
        return res;
    }

    public void addDapanHQ(Integer res) {
        JSONObject j = new JSONObject();
        j.put("res", res);
        j.put("item", staticCollection.investItem);
        //最多记录6个
        if (DapanHQ.size() > 6) {
            DapanHQ.remove(0);
        }
        DapanHQ.add(j);
    }
}
