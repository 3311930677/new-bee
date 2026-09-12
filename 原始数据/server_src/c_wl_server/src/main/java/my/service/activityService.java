package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.dao.jsonMapper;
import my.dao.roleMapper;
import my.data.mapData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.activityCache;
import my.startBef;
import my.utils.fileUtils;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.SqlSession;

import java.io.File;
import java.util.*;
import java.util.concurrent.TimeUnit;

import static my.utils.staticCollection.url;

/**
 * 活动服务
 * 控制活动开启与关闭
 */
public class activityService {
    //活动缓存
    private Map<String, activityCache> acMap = new HashMap<>();
    //是否正在遍历活动中
    private static boolean isAcDoing = false;

    private static JSONObject acConfig;

    public void initConfig() {
        String json = fileUtils.readFile(url + "activity.json");
        acConfig = JSON.parseObject(json);
    }

    public boolean isOpenByConfig(String key) {
        if (acConfig.getInteger(key) == 1) return true;
        return false;
    }

    /**
     * 获取活动信息
     */
    public activityCache getMsg(String k) {
        return acMap.get(k);
    }

    /**
     * 判断活动是否开启
     */
    public boolean isOpen(String k) {
        activityCache ac = acMap.get(k);
        //活动是否被gm关闭
        if (ac != null && ac.isOpen == 1 && ac.isDoing == 1
                && ac.isInTime()) {
            return true;
        }
        return false;
    }

    /**
     * 设置活动开启、关闭
     */
    public boolean setDoing(String k, int isDoing) {
        activityCache ac = acMap.get(k);
        if (ac == null) return false;
        ac.isDoing = isDoing;
        return true;
    }

    /**
     * 创建活动
     */
    public void createActivity() {
        activityCache clearDailyTask = new activityCache("清理日常", "clearDailyTask", 1, null);
        clearDailyTask.initTime(0, 0, 0, 1);
        acMap.put(clearDailyTask.acKey, clearDailyTask);

        activityCache countOrder = new activityCache("统计排行", "countOrder", 2, 1 * 60 * 1000L);
        acMap.put(countOrder.acKey, countOrder);
        activityCache rewardMsg = new activityCache("世界级奖励消息", "rewardMsg", 2, 5 * 1000L);
        acMap.put(rewardMsg.acKey, rewardMsg);

        activityCache testMsg = new activityCache("测试系统消息", "testMsg", 2, 5 * 60 * 1000L);
        acMap.put(testMsg.acKey, testMsg);
        activityCache jiMaiOverTime = new activityCache("寄卖过期清理", "jiMaiOverTime", 2, 10 * 60 * 1000L);
        acMap.put(jiMaiOverTime.acKey, jiMaiOverTime);

        activityCache daibu = new activityCache("逮捕魔头", "daibu", 2, 1 * 60 * 1000L);
        acMap.put(daibu.acKey, daibu);

        activityCache fbLqzAc = new activityCache("法宝灵气值", "fbLqzAc", 2, 1 * 60 * 1000L);
        acMap.put(fbLqzAc.acKey, fbLqzAc);

        activityCache dpAc = new activityCache("大盘", "dapan", 2, 10 * 60 * 1000L);
        acMap.put(dpAc.acKey, dpAc);

        activityCache xxzdAc = new activityCache("血腥之地", "xxzdAc", 1, null);
        xxzdAc.initTime(19, 30, 20, 30);
        acMap.put(xxzdAc.acKey, xxzdAc);

        activityCache cbAc = new activityCache("传壁", "cb", 2, 5 * 1000L);
        acMap.put(cbAc.acKey, cbAc);

        activityCache juling = new activityCache("聚灵真火", "juling", 2, 30 * 1000L);
        acMap.put(juling.acKey, juling);

        activityCache shenfuEfeect = new activityCache("神符效果", "shenfuEfeect", 2, 60 * 1000L);
        acMap.put(shenfuEfeect.acKey, shenfuEfeect);

        activityCache roleStatusCheck = new activityCache("角色状态检测（诱敌香草等）", "roleStatusCheck", 2, 10 * 1000L);
        acMap.put(roleStatusCheck.acKey, roleStatusCheck);

        activityCache huitian = new activityCache("技能回天处理", "huitian", 2, 1 * 60 * 1000L);
        acMap.put(huitian.acKey, huitian);

        activityCache jingji = new activityCache("竞技场", "jingji", 2, 20 * 1000L);
        acMap.put(jingji.acKey, jingji);
        activityCache whjx = new activityCache("百战千军", "whjx", 2, 20 * 1000L);
        acMap.put(whjx.acKey, whjx);

        activityCache tianjingshi = new activityCache("天晶石", "tianjingshi", 1, null);
        tianjingshi.initTime(20, 0, 22, 0);
        acMap.put(tianjingshi.acKey, tianjingshi);

        activityCache yuposhi = new activityCache("玉魄石", "yuposhi", 1, null);
        yuposhi.initTime(18, 0, 20, 0);
        acMap.put(yuposhi.acKey, yuposhi);

        activityCache qihuo = new activityCache("期货", "qihuo", 2, 10 * 60 * 1000L);
        acMap.put(qihuo.acKey, qihuo);


        activityCache updatePsGoods = new activityCache("刷新跑商物品", "updatePsGoods", 2, 60 * 1000L);
        acMap.put(updatePsGoods.acKey, updatePsGoods);

        activityCache dsx = new activityCache("门派首席", "dsx", 1, null);
        dsx.week = 2;//周一
        dsx.initTime(20, 0, 20, 1);
        //dsx.initTime(23, 22, 23, 23);
        acMap.put(dsx.acKey, dsx);


        activityCache wzy = new activityCache("巅峰赛", "wzy", 1, null);
        wzy.week = 4;//周三
        wzy.initTime(20, 0, 20, 1);
        acMap.put(wzy.acKey, wzy);

        activityCache worldBoss = new activityCache("世界boss", "worldBoss", 1, null);
        worldBoss.week = 5;//周四
        worldBoss.initTime(19, 0, 19, 10);
        acMap.put(worldBoss.acKey, worldBoss);

        activityCache bz = new activityCache("帮战", "bz", 1, null);
        bz.week = 6;//周五
        bz.initTime(19, 50, 20, 20);
        acMap.put(bz.acKey, bz);

        activityCache mpbwz = new activityCache("门派保卫战", "mpbwz", 1, null);
        mpbwz.initTime(14, 30, 16, 0);
        acMap.put(mpbwz.acKey, mpbwz);

        activityCache ZMAnswer = new activityCache("百家争鸣", "ZMAnswer", 1, null);
        ZMAnswer.week = 7;//周六
        ZMAnswer.initTime(16, 0, 18, 0);
        acMap.put(ZMAnswer.acKey, ZMAnswer);

        activityCache ztzs = new activityCache("门派闯关", "ztzs", 1, null);
        ztzs.week = 1;//周日
        ztzs.initTime(16, 0, 18, 0);
        acMap.put(ztzs.acKey, ztzs);

        activityCache qianggou = new activityCache("秒杀活动", "qianggou", 1, null);
        qianggou.initTime(20, 0, 22, 5);
        //qianggou.initTime(20, 0, 23, 55);
        acMap.put(qianggou.acKey, qianggou);


        activityCache clearNames = new activityCache("清理名单", "clearNames", 1, null);
        clearNames.initTime(10, 0, 10, 1);
        acMap.put(clearNames.acKey, clearNames);

        activityCache zslAc = new activityCache("江湖追杀令过期清理", "zsl", 2, 60 * 1000L);
        acMap.put(zslAc.acKey, zslAc);

        activityCache openServerAc = new activityCache("开服活动", "openServerAc", 1, null);
        openServerAc.initDay("2026-02-11 00:00:00", "2026-02-18 23:50:00");
        acMap.put(openServerAc.acKey, openServerAc);


        //开启一个线程-检测活动的开启
        staticCollection.putTask(() -> {
            if (isAcDoing) return;
            isAcDoing = true;
            try {
                for (String k : acMap.keySet()) {
                    activityCache ac = acMap.get(k);
                    //活动是否被gm关闭
                    if (ac.isOpen == 0) {
                        continue;
                    }
                    if (ac.type == 0 && ac.isDoing == 0) {//开启长期活动
                        getActivity(ac.acKey).run();
                    } else if (ac.type == 1) {//开启限时活动
                        //在指定时间内但未开启，不在指定时间但未关闭
                        if ((ac.isInTime())
                                || (!ac.isInTime() && ac.isDoing == 1)) {
                            getActivity(ac.acKey).run();
                        }
                    } else if (ac.type == 2) {//开启定时活动
                        if (ac.isInTime()) {
                            //未达到定时点
                            continue;
                        }
                        getActivity(ac.acKey).run();
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            } finally {
                isAcDoing = false;
            }
        }, 10, 2, TimeUnit.SECONDS);
    }

    /**
     * 由key获取活动
     */
    public Runnable getActivity(String key) {
        switch (key) {
            case "testMsg": {
                Runnable r1 = () -> {
                    String str = fileUtils.readFile(staticCollection.url + "/notice.txt");
                    startBef.chatService.putSysMsg(str);
                };
                return commonDelayAc(key, r1);
            }
            case "jiMaiOverTime": {
                Runnable r1 = () -> {
                    startBef.jimaiService.overTimeHandle();
                };
                return commonDelayAc(key, r1);
            }

            case "clearDailyTask": {//日常活动清理
                Runnable r1 = () -> {
                    startBef.taskService.updateDailyTask();
                };
                return commonAc(key, r1, null, null);
            }
            /*case "syncIp": {//同步本地公网ip
                Runnable r = () -> {
                    startBef.getIpService.syncIP();
                };
                return commonDelayAc(key, r);
            }*/
            case "countOrder": {//排行统计
                Runnable r = () -> {
                    //单独开个线程给他统计，不要阻塞其他活动
                    staticCollection.putTask(() -> {
                        startBef.orderService.handleOrder();
                    });
                };
                return commonDelayAc(key, r);
            }
            case "rewardMsg": {//奖励消息通知
                Runnable r = () -> {
                    rewardUtils.rewardMsgToAllClient();
                };
                return commonDelayAc(key, r);
            }
            case "daibu": {//逮捕
                Runnable r = () -> {
                    startBef.prisonService.sysToCatchMt();
                };
                return commonDelayAc(key, r);
            }
            case "fbLqzAc": {
                Runnable r = () -> {
                    startBef.packageService.cutFaBaoLqz();
                };
                return commonDelayAc(key, r);
            }
            case "dapan": {//大盘
                Runnable r = () -> {
                    if (!isOpenByConfig(key)) return;
                    startBef.investService.createDpResult();
                };
                return commonDelayAc(key, r);
            }

            case "cb": {//传壁
                Runnable r = () -> {
                    startBef.cbService.upResult();
                };
                return commonDelayAc(key, r);
            }
            case "juling": {//聚灵真火
                Runnable r = () -> {
                    startBef.julingService.resHandle();
                };
                return commonDelayAc(key, r);
            }
            case "shenfuEfeect": {//神符效果
                Runnable r = () -> {
                    startBef.shenfuService.overTimeHandle();
                };
                return commonDelayAc(key, r);
            }

            case "roleStatusCheck": {//角色状态栏
                Runnable r = () -> {
                    startBef.manService.statusHandle();
                };
                return commonDelayAc(key, r);
            }
            case "huitian": {//技能回天书处理
                Runnable r = () -> {
                    startBef.manService.huitianHandle();
                };
                return commonDelayAc(key, r);
            }
            case "jingji": {//竞技场
                Runnable r = () -> {
                    startBef.jingjiService.doFight();
                };
                return commonDelayAc(key, r);
            }
            case "whjx": {//王侯将相
                Runnable r = () -> {
                    startBef.bzqjService.doWHJXFight();
                };
                return commonDelayAc(key, r);
            }
            case "xxzdAc": {//血腥之地
                Runnable r1 = () -> {
                    startBef.xxzdService.startAc();
                };
                Runnable r2 = () -> {
                    startBef.xxzdService.startMatch();
                };
                Runnable r3 = () -> {
                    startBef.xxzdService.endAc();
                };
                return commonAc(key, r1, r2, r3);
            }
            case "worldBoss": {//世界boss
                Runnable r1 = () -> {
                    startBef.worldBossService.startWorldBoss();
                };
                Runnable r3 = () -> {
                    startBef.worldBossService.worldBossResult();
                };
                return commonAc(key, r1, null, r3);
            }
            case "tianjingshi": {//天晶石
                return commonAc(key, null, null, null);
            }
            case "yuposhi": {//玉魄石
                return commonAc(key, null, null, null);
            }
            case "qihuo": {//期货
                Runnable r = () -> {
                    if (!isOpenByConfig(key)) return;
                    startBef.investService.createQhResult();
                };
                return commonDelayAc(key, r);
            }
            case "wzy": {//武状元
                Runnable r1 = () -> {
                    startBef.wzyService.starting = true;
                    startBef.wzyService.noticeNameList();
                };
                return commonAc(key, r1, null, null);
            }


            case "ZMAnswer": {//周六答题
                /*List<String> taskListClear = new ArrayList<>();
                taskListClear.add("3059");
                taskListClear.add("3060");
                taskListClear.add("3061");
                taskListClear.add("3062");
                taskListClear.add("3063");*/
                Runnable r1 = () -> {
                    //startActivity(key, "3059", taskListClear).run();
                };
                Runnable r3 = () -> {
                    //activityOver(key, taskListClear);
                    //清理表
                    startBef.answerService.clearZMAnswer();
                };
                return commonAc(key, r1, null, r3);
            }
            case "ztzs": {//震天战神
                List<String> taskListClear = new ArrayList<>();
                for (int i = 3250; i < 3265; i++) {
                    taskListClear.add(i + "");
                }
                Runnable r1 = () -> {
                    //创建npc
                    JSONArray list = new JSONArray();
                    list.add(mapData.getOne("10000565", mapData.getVc(230, 350), null));
                    startBef.mapService.pushNpcToClient(list, 2, "m_20", "m_20");

                    //因为起始任务为-1，不能通过任务检测来触发开启，这里会825通知前端创建任务
                    startActivity(key, "3250", taskListClear).run();
                    //将门派闯关的奖励map清空
                    staticCollection.mpcgMap.put("r1", 1);
                    staticCollection.mpcgMap.put("r2", 1);
                };
                Runnable r3 = () -> {
                    activityOver(key, taskListClear);
                };
                return commonAc(key, r1, null, r3);
            }
            case "dsx": {//门派大师兄
                Runnable r1 = () -> {
                    startBef.dsxService.noticeNameList();
                };
                return commonAc(key, r1, null, null);
            }

            case "bz": {//帮战
                Runnable r1 = () -> {
                    startBef.gangsService.startBz();
                };
                Runnable r3 = () -> {
                    startBef.gangsService.bzOverResult();
                };
                return commonAc(key, r1, null, r3);
            }
            case "mpbwz": {
                Runnable r1 = () -> {
                    startBef.mpbwzService.startAc();
                };
                Runnable r3 = () -> {
                    startBef.mpbwzService.endAc();
                };
                return commonAc(key, r1, null, r3);
            }

            case "updatePsGoods": {//刷新跑商物品
                Runnable r = () -> {
                    startBef.gangsService.updatePsGoodsRes();
                };
                return commonDelayAc(key, r);
            }
            case "qianggou": {//8点抢购
                Runnable r1 = () -> {
                    //初始化缓存
                    startBef.shopService.initQiangGou();
                    //推送
                    startBef.shopService.rushToBuy();
                };
                return commonAc(key, r1, null, null);
            }

            case "clearNames": {
                Runnable r1 = () -> {
                    startBef.wzyService.clearNames();
                    //startBef.petLunJianService.clearNames();
                };
                return commonAc(key, r1, null, null);
            }
            case "zsl": {//江湖追杀令过期清理
                Runnable r = () -> {
                    startBef.zslService.clear();
                };
                return commonDelayAc(key, r);
            }

            case "openServerAc": {//开服活动
                Runnable r1 = () -> {
                    startBef.openServerAcService.startNotice();
                };
                Runnable r3 = () -> {
                    startBef.openServerAcService.endCount();
                };
                return commonAc(key, r1, null, r3);
            }


        }
        return null;
    }

    /**
     * type=2 定时活动
     * r1 定时点到时调用
     */
    private Runnable commonDelayAc(String acKey, Runnable r1) {
        return () -> {
            try {
                activityCache ac = acMap.get(acKey);
                //到定时点时活动要设为关闭，不允许投资等行为
                ac.isDoing = 0;
                //赋予新的起始点
                ac.initTime = strUtils.getTime();
                if (r1 != null) {
                    r1.run();
                }
                ac.isDoing = 1;
            } catch (Exception e) {
                e.printStackTrace();
                loggerUtils.error(acKey + "活动启动失败!", this.getClass());
            }
        };
    }

    /**
     * type=1 限时活动
     * r1开启时调用
     * r2进行时调用
     * r3活动结束时调用
     */
    private Runnable commonAc(String acKey, Runnable r1, Runnable r2, Runnable r3) {
        return () -> {
            try {
                activityCache ac = acMap.get(acKey);
                if (!ac.isInTime()) {
                    //不在活动时间内并且还处于开启状态时，需要关闭活动
                    if (ac.isDoing == 1) {
                        ac.isDoing = 0;
                        if (r3 != null) {
                            r3.run();
                        }
                        /*if (!acKey.equals("dsx") && !acKey.equals("wzy")
                                && !acKey.equals("lunjian") && !acKey.equals("clearDailyTask")
                                && !acKey.equals("dataCheck") && !acKey.equals("clearNames")
                                && !acKey.equals("updateOrder")) {
                            startBef.chatService.putSysMsg(ac.acName + "活动已结束");
                        }*/
                    }
                    return;
                }
                //处于活动指定时间，并且未开启过
                if (ac.isDoing == 0) {
                    ac.isDoing = 1;
                    if (r1 != null) {
                        r1.run();
                    }
                    /*if (!acKey.equals("clearDailyTask") && !acKey.equals("dataCheck")
                            && !acKey.equals("clearNames") && !acKey.equals("updateOrder")
                    ) {
                        startBef.chatService.putSysMsg(ac.acName + "活动已开启！");
                    }*/
                    return;
                }
                //处于指定时间内并且进行中
                if (r2 != null) {
                    r2.run();
                }
            } catch (Exception e) {
                loggerUtils.error(acKey + "活动启动失败!", this.getClass());
            }
        };
    }

    /**
     * 接任务式活动开启
     */
    private Runnable startActivity(String acKey, String startTask, List<String> taskListClear) {
        return () -> {
            JSONObject task = null;
            if (startTask != null) {
                task = new JSONObject();
                task.put("progressIndex", 0);
                JSONObject taskProgress = new JSONObject();
                JSONObject target = new JSONObject();
                target.put("num", 0);
                taskProgress.put("target", target);
                task.put("taskProgress", taskProgress);
                task.put("key", startTask);
                task.put("status", 1);
            }

            //清理
            //开启条件设置为时间
            //到点后将任务设置为开启状态，通知客户端重新拉取任务数据
            SqlSession con = null;
            try {
                con = mybatisConfig.getSqlSession();
                roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
                jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
                int num = roleMapper.count().get(0).getInteger("num");
                int sumPage = num % 10 == 0 ? num / 10 : num / 10 + 1;
                java.util.List<JSONObject> ls = new ArrayList<>();
                JSONArray taskList = new JSONArray();
                for (int i = 0; i < sumPage; i++) {
                    ls.addAll(roleMapper.selectRoleByLever(29, i * 10L, 10L));
                    Iterator<JSONObject> js = ls.iterator();
                    while (js.hasNext()) {
                        try {
                            JSONObject a = js.next();
                            clearTask(task, a, taskList, jsonMapper, taskListClear);
                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                    }
                    ls.clear();
                    taskList.clear();
                    mybatisConfig.commit(con);
                }
                mybatisConfig.commit(con);
            } catch (Exception e) {
                mybatisConfig.rollback(con);
                e.printStackTrace();
            } finally {
                mybatisConfig.close(con);
            }
            //2小时后结束活动

            //通知在线的缓存任务
            JSONObject msg = new JSONObject();
            msg.put("remove", 0);
            msg.put("acKey", acKey);
            JSONArray list = new JSONArray();
            if (startTask != null) list.add(startTask);
            msg.put("list", list);
            ChannelSupervise.noticeAllClient(msg, "825");
        };
    }

    /**
     * 清理任务
     */
    private void clearTask(JSONObject task, JSONObject a, JSONArray taskList,
                           jsonMapper jsonMapper, List<String> taskListClear) {
        //先清理一遍
        //==========submit表=================
        taskList.addAll(jsonMapper.selectTaskSubmitByName(a.getString("name")).get(0).getJSONArray("list"));
        Iterator ts = taskList.iterator();
        while (ts.hasNext()) {
            String obj = (String) ts.next();
            for (String t : taskListClear) {
                if (obj.equals(t)) {
                    ts.remove();
                    break;
                }
            }
        }
        jsonMapper.updateTaskSubmitByName(JSON.toJSONString(taskList), a.getString("name"));
        taskList.clear();
        //==========task表=================
        taskList.addAll(jsonMapper.selectTaskByName(a.getString("name")).get(0).getJSONArray("task"));
        ts = taskList.iterator();
        while (ts.hasNext()) {
            JSONObject obj = (JSONObject) ts.next();
            for (String t : taskListClear) {
                if (obj.getString("key").equals(t)) {
                    ts.remove();
                    break;
                }
            }
        }
        //再添加起始任务
        if (task != null) {
            taskList.add(task);
        }
        jsonMapper.updateTaskByName(JSON.toJSONString(taskList), a.getString("name"));
        taskList.clear();
    }

    /**
     * 活动结束的处理
     */
    public void activityOver(String acKey, List<String> taskListClear) {
        SqlSession con = null;
        try {
            con = mybatisConfig.getSqlSession();
            roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
            jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
            int num = roleMapper.count().get(0).getInteger("num");
            int sumPage = num % 10 == 0 ? num / 10 : num / 10 + 1;
            List<JSONObject> ls = new ArrayList<>();
            JSONArray taskList = new JSONArray();
            for (int i = 0; i < sumPage; i++) {
                ls.addAll(roleMapper.selectRoleByLever(29, i * 10L, 10L));
                Iterator<JSONObject> js = ls.iterator();
                while (js.hasNext()) {
                    try {
                        JSONObject a = js.next();
                        clearTask(null, a, taskList, jsonMapper, taskListClear);
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
                ls.clear();
                taskList.clear();
                mybatisConfig.commit(con);
            }
            mybatisConfig.commit(con);
            //通知在线的移除缓存任务
            JSONObject msg = new JSONObject();
            msg.put("remove", 1);
            msg.put("acKey", acKey);
            msg.put("list", taskListClear);
            ChannelSupervise.noticeAllClient(msg, "825");
        } catch (Exception e) {
            mybatisConfig.rollback(con);
            loggerUtils.error("清理通知活动时异常：" + e.getMessage(), this.getClass());
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * type=0 通用活动开启
     */
    private Runnable commonActivity(String acKey) {
        return () -> {
            try {
                activityCache ac = acMap.get(acKey);
                ac.isDoing = 1;
                //loggerUtils.info(ac.acName + "活动开启", this.getClass());
            } catch (Exception e) {
                loggerUtils.error(acKey + "活动启动失败!", this.getClass());
            }
        };
    }


}
