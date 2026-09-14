package my.service.ac;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import io.netty.util.concurrent.ScheduledFuture;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.jsonMapper;
import my.db.mybatisConfig;
import my.fightUtils.fightUtils;
import my.gameUtils.roleUtils;
import my.model.ChannelSupervise;
import my.model.activityCache;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.TimeUnit;

import static my.fightUtils.fightUtils.isAllowedFight;
import static my.utils.staticCollection.whjxMap;

/**
 * 血腥之地
 */
public class xxzdService {
    //是否开启了活动
    public boolean isOpenAc = false;
    //活动开启的时间
    private long createdTime = 0;
    //上次开始匹配的时间
    private long preMatchTime = 0;


    public result openAc(@paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (!name.equals("梅仁义")) {
            return new result(0);
        }
        activityCache ac = startBef.activityService.getMsg("xxzdAc");
        Calendar now = Calendar.getInstance();
        int min = now.get(Calendar.MINUTE);
        int hour = now.get(Calendar.HOUR_OF_DAY);
        ac.initTime(hour, min, hour + 1, min);
        return new result(200, 1);
    }

    public result openMatch(@paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (!name.equals("梅仁义")) {
            return new result(0);
        }
        createdTime -= 30 * 60 * 1000;

        return new result(200, 1);
    }

    public result closeAc(@paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (!name.equals("梅仁义")) {
            return new result(0);
        }
        //createdTime -= 60 * 60 * 1000;
        activityCache ac = startBef.activityService.getMsg("xxzdAc");
        Calendar now = Calendar.getInstance();
        int min = now.get(Calendar.MINUTE);
        int hour = now.get(Calendar.HOUR_OF_DAY);
        ac.initTime(hour - 1, min, hour, min);
        return new result(200, 1);
    }

    public result getOrder(JSONObject obj,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        long pageNum = obj.getLong("pageNum");
        long pageSum = 10L;
        if (pageNum < 1) {
            pageNum = 1;
        }
        activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
        long n = ac.getXxzdSum().get(0).getInteger("n");
        long total = n % pageSum == 0 ? (n / pageSum) : (n / pageSum + 1);
        if (pageNum > total) {
            return new result(0);
        }

        List<JSONObject> aL = ac.getXxzdByPage((pageNum - 1) * pageSum, pageSum);
        for (JSONObject a : aL) {
            a.put("order", (pageNum - 1) * pageSum + 1);
        }

        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", aL);
        return new result(200, res);
    }

    /**
     * 开启活动
     */
    public void startAc() {
        createdTime = strUtils.getTime();
        isOpenAc = true;
        startBef.chatService.putSysMsg("血腥之地已开启");
    }

    /**
     * 后30分钟执行匹配
     */
    public void startMatch() {
        long now = strUtils.getTime();
        if (now - createdTime < 30 * 60 * 1000) return;
        //每30s一次（还在战斗的不会执行调取，只调取未战斗的玩家）
        if (now - preMatchTime > 30 * 1000) {
            startBef.chatService.putSysMsg("血腥之地执行匹配");
            preMatchTime = now;
            doFight();
        }
    }

    public void endAc() {
        createdTime = 0;
        isOpenAc = false;
        preMatchTime = 0;
        startBef.chatService.putSysMsg("血腥之地已结束");
    }

    /**
     * 执行匹配
     */
    private boolean isDoingFight = false;

    public void doFight() {
        if (isDoingFight) return;
        isDoingFight = true;
        //读取所有参与玩家的jf
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
            List<JSONObject> list = ac.getAllXxzd();
            mybatisConfig.commit(con);
            Collections.shuffle(list);
            //先去除一遍不能参与战斗的玩家
            for (int i = 0; i < list.size(); i++) {
                String name = list.get(i).getString("name");
                if (!isAllowedFight(name) ||
                        !staticCollection.isInMap("xxzd", name)) {
                    list.remove(i);
                    i--;
                }
            }
            //每两个进行一次匹配
            String a0 = null;
            String a1 = null;
            for (int i = 0; i < list.size(); i++) {
                String name = list.get(i).getString("name");
                if (!isAllowedFight(name) ||
                        !staticCollection.isInMap("xxzd", name)) {
                    continue;
                }
                if (a0 == null) a0 = name;
                else if (a1 == null) a1 = name;
                if (a0 != null && a1 != null) {
                    //调取战斗
                    int r = startBef.fightRpcService.createFightByXXZD(a0, a1, con);
                    a0 = null;
                    a1 = null;
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
            isDoingFight = false;
        }
    }

    public void fightRes(int win, String rName, String lName) {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            int num = strUtils.getRandom(5, 21);
            //无论胜利失败基础分+5
            if (win == 1) {
                //右方胜利
                List<JSONObject> al = activityMapper.getXxzd(rName);
                int jf = al.get(0).getInteger("jf") + 5;
                List<JSONObject> al2 = activityMapper.getXxzd(lName);
                int jf2 = al2.get(0).getInteger("jf") + 5;
                if (jf2 - num <= 0) num = jf2;
                jf2 = jf2 - num;
                jf = jf + num;

                activityMapper.updateXxzd(rName, jf + "");
                activityMapper.updateXxzd(lName, jf2 + "");
                ChannelSupervise.noticeClientByName(num, rName, "858");
                ChannelSupervise.noticeClientByName(-num, lName, "858");
            } else {
                List<JSONObject> al = activityMapper.getXxzd(lName);
                int jf = al.get(0).getInteger("jf") + 5;
                List<JSONObject> al2 = activityMapper.getXxzd(rName);
                int jf2 = al2.get(0).getInteger("jf") + 5;
                if (jf2 - num <= 0) num = jf2;
                jf2 = jf2 - num;
                jf = jf + num;

                activityMapper.updateXxzd(lName, jf + "");
                activityMapper.updateXxzd(rName, jf2 + "");
                ChannelSupervise.noticeClientByName(-num, rName, "858");
                ChannelSupervise.noticeClientByName(num, lName, "858");
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
     * 击败怪物增加积分
     */
    public void addJfByMon(int jf, String name, DefaultSqlSession con) {
        activityMapper ac = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = ac.getXxzd(name);
        if (list.size() == 0) {
            ac.addXxzd(name);
            list = ac.getXxzd(name);
        }
        JSONObject one = list.get(0);
        int old = one.getInteger("jf");
        old += jf;
        ac.updateXxzd(name, old + "");
        ChannelSupervise.noticeClientByName(jf, name, "858");
    }
}
