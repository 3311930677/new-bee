package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.gameUtils.roleUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.TimeUnit;

import static my.fightUtils.fightUtils.fightMap;

/**
 * 门派首席海选
 */
public class dsxService {
    //门派结束的数量
    private int ends = 0;
    //保存首席的信息 model-name
    private JSONObject sxMsg = new JSONObject();
    //每次匹配都将结果存于此 id-0|1
    //private JSONObject fightRes = new JSONObject();
    //实际调起战斗的人数
    private int fightNum = 0;

    /**
     * 清理报名名单
     * 要求在下次活动报名前进行清理
     */
    public Integer clearNames() {
        ends = 0;
        fightNum = 0;
        sxMsg.clear();
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            int i = activityMapper.delDsx() ? 1 : 0;
            mybatisConfig.commit(con);
            return i;
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        return 0;
    }

    /**
     * 获取门派首席名单（拿到的是win=1的）
     */
    public List<JSONObject> getNameList(String model, DefaultSqlSession con) {
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        return activityMapper.getDsxNameList(model);
    }

    /**
     * 获取所有win=1的
     */
    public List<JSONObject> getWinNameList(DefaultSqlSession con) {
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        return activityMapper.getWinDsxNameList();
    }

    /**
     * 发布门派首席对战名单
     */
    public void noticeNameList() {
        startBef.chatService.putSysMsg("门派首席开始匹配！");
        String[] models = new String[0];
        //只要未选举的职业
        String[] ms = {"ms", "dj", "qm", "ty", "ym", "lc"};
        for (String m : ms) {
            if (sxMsg.get(m) == null) {
                models = Arrays.copyOf(models, models.length + 1);
                models[models.length - 1] = m;
            }
        }

        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            //对于不在场地内的玩家先进行移除
            List ns = new ArrayList();
            List<JSONObject> all = getWinNameList(con);
            for (int i = 0; i < all.size(); i++) {
                String n = all.get(i).getString("name");
                //不在线或者不在赛场
                if (!staticCollection.isInMap("dsx", n)) {
                    ns.add(n);
                    all.remove(i);
                    i--;
                }
            }
            if (ns.size() > 0) {
                //标记失败
                activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
                activityMapper.updateDsxByNames(ns, "0");
                mybatisConfig.commit(con);
                ns.clear();
            }


            for (String model : models) {
                List<JSONObject> list = getNameList(model, con);
                mybatisConfig.commit(con);
                //处理每个职业只剩一个玩家的时候
                if (list.size() <= 1) {
                    String str = null;
                    switch (model) {
                        case "ms": {
                            str = "猛士";
                            break;
                        }
                        case "dj": {
                            str = "遁甲";
                            break;
                        }
                        case "qm": {
                            str = "琴魔";
                            break;
                        }
                        case "ty": {
                            str = "天音";
                            break;
                        }
                        case "ym": {
                            str = "幽冥";
                            break;
                        }
                        case "lc": {
                            str = "罗刹";
                            break;
                        }
                    }
                    if (list.size() == 0) {
                        sxMsg.put(model, "");
                    } else {
                        JSONObject o = list.get(0);
                        sxMsg.put(model, o.getString("name"));
                        startBef.chatService.putSysMsg("恭喜玩家[" + o.getString("name") + "]获得" + str + "门派首席！");
                    }
                    ends++;
                    //6个门派门派首席均已选出
                    if (ends >= 6) {
                        String text = "门派首席海选已结束！恭喜玩家";
                        //奖励限时称号[技冠群雄]、元宝
                        JSONArray rewards = rewardUtils.getGoodsReward("10000000", 2, 0);
                        //rewardUtils.getGoodsReward("11240004", 1, 1, rewards);
                        for (String modelKey : sxMsg.keySet()) {
                            String name = sxMsg.getString(modelKey);
                            if (strUtils.isNull(name)) continue;
                            JSONArray res = startBef.rewardService.saveRewards(rewards, name, con);
                            //通知奖励
                            ChannelSupervise.noticeClientByName(res, name, "10000");
                            text += name + "，";
                        }
                        mybatisConfig.commit(con);
                        text = text.substring(0, text.length() - 1) + "荣获门派首席，奖励龙头金票x2";
                        //两分钟后设置不开启
                        staticCollection.putTask(() -> {
                            startBef.activityService.setDoing("dsx", 0);
                        }, 2, TimeUnit.MINUTES);
                        startBef.chatService.putSysMsg(text);
                        //清理名单
                        clearNames();

                        return;
                    }
                    continue;
                }
                //乱序
                Collections.shuffle(list);
                StringBuilder a0 = new StringBuilder();
                StringBuilder a1 = new StringBuilder();
                for (int p = 0; p < list.size(); p++) {
                    JSONObject l = list.get(p);
                    if (a0.length() == 0) {
                        a0.append(l.getString("name"));
                    } else if (a1.length() == 0) {
                        a1.append(l.getString("name"));
                    }
                    if (a0.length() > 0 && a1.length() > 0) {
                        //调取战斗
                        int i = 0;
                        i = startBef.fightRpcService.createFightByDsx(a0.toString(), a1.toString(), con);
                        if (i == 0) {//两者皆败
                            ns.add(a0.toString());
                            ns.add(a1.toString());
                        } else if (i == 2) {//name败
                            ns.add(a0.toString());
                        } else if (i == 3) {//playerName败
                            ns.add(a1.toString());
                        } else {
                            fightNum += 2;
                        }
                        a0.delete(0, a0.length());
                        a1.delete(0, a1.length());
                    }
                }
                mybatisConfig.commit(con);
                if (ns.size() > 0) {
                    //标记失败
                    activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
                    activityMapper.updateDsxByNames(ns, "0");
                    mybatisConfig.commit(con);
                    ns.clear();
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        //当没有战斗被调起的情况，直接重新发布
        if (fightNum == 0) {
            noticeNameList();
        }
    }

    /**
     * 两者皆败（下线的情况）
     */
    public void markLoser2(String fightId) {
        JSONObject obj = fightMap.get(fightId);
        if (obj == null) {
            System.err.println("markLoser2 obj为null，导致无法结束");
            return;
        }
        JSONArray roleList = obj.getJSONArray("roleList");
        if (roleList == null) {
            System.err.println("markLoser2 roleList为null，导致无法结束");
            return;
        }
        for (Object r : roleList) {
            JSONObject rj = (JSONObject) r;
            if (rj.getInteger("type") == 0) {
                markLoser0(rj.getString("name"));
            }
        }
    }

    /**
     * 手动开启大师兄活动
     */
    /*public result openDsx(@paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (!name.equals("梅仁义") && !name.equals("林志玲")) {
            return new result(0);
        }
        noticeNameList();
        return new result(200, 1);
    }
*/
    /**
     * 报名门派首席
     * 需要完成试炼任务方可参加
     */
    public result sign(@paramsAnno(key = "user") user user,
                       @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //是否在规定的报名时间段 周一
        if (!strUtils.isInTime(1, 0, 19, 50)) {
            return new result(696);
        }
        if (user.msg.getInteger("lever") < 60) {
            return new result(613);
        }
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        //是否已经报过名了
        if (activityMapper.getDsxOne(name).size() > 0) {
            return new result(667);
        }
        JSONObject role = startBef.manService.getRole(name, con);
        String job = roleUtils.getJobFromModels(role);
        //未加入分堂
        if (job == null) return new result(930);
        activityMapper.addDsx(name, job.split("_")[0]);
        return new result(200, 1);
    }

    public void markWinAndLoser(String win, String loser) {
        fightNum -= 2;//减去对战双方人数
        markLoser(loser);
    }

    public void markLoser0(String loser) {
        fightNum -= 1;//减去1个人数
        markLoser(loser);
    }

    /**
     * 标记淘汰
     */
    public void markLoser(String name) {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            activityMapper.updateDsx(name, "0");
            mybatisConfig.commit(con);
            System.err.println("剩余参战人数：" + fightNum);
            //当没有玩家正在参战时可以发布下一轮
            if (fightNum == 0) {
                //需延时10秒后再次发布
                staticCollection.putTask(() -> {
                    try {
                        //可进行下一轮
                        noticeNameList();
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }, 10, TimeUnit.SECONDS);
            }
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }
}
