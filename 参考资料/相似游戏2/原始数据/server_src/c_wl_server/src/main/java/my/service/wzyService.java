package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.jsonMapper;
import my.db.mybatisConfig;
import my.fightUtils.fightUtils;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.Collections;
import java.util.List;
import java.util.concurrent.TimeUnit;

import static my.utils.staticCollection.fightList;

/**
 * 巅峰赛
 */
public class wzyService {
    //轮数
    private int num = 1;
    public boolean starting = false;

    /**
     * 清理报名名单
     */
    public Integer clearNames() {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
            int i = dao.delWzySign() ? 1 : 0;
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
     * 获取积分排行
     */
    public result getJfPh(JSONObject j,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        long pageSum = 10;
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = dao.selectWzySignLimit((j.getInteger("pageNum") - 1) * pageSum, pageSum);
        int total = dao.countWzySign().get(0).getInteger("total");
        long totalPage = total % pageSum == 0 ? (total / pageSum) : (total / pageSum + 1);
        JSONObject page = new JSONObject();
        page.put("list", list);
        page.put("totalPage", totalPage);
        return new result(200, page);
    }

    /**
     * 获取对战名单
     */
    public result getNameList(JSONObject j) {
        Integer pageNum = j.getInteger("pageNum");
        JSONObject msg = new JSONObject();
        msg.put("list", fightList);
        msg.put("total", fightList.size());
        return new result(200, msg);
    }

    /**
     * 获取前3名队伍
     */
    public List<JSONObject> getThree(DefaultSqlSession con) {
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        return dao.getWzySignOrderByJf(0L, 3L);
    }

    /**
     * 获取参赛的战队
     */
    public result getZdNames(@paramsAnno(key = "con") DefaultSqlSession con) {
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = dao.selectAllWzySign();
        JSONObject res = new JSONObject();
        res.put("list", list);
        return new result(200, res);
    }

    /**
     * 手动开启活动
     */
    /*public result openWzy(@paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (!name.equals("梅仁义") && !name.equals("林志玲")) {
            return new result(0);
        }
        starting = true;
        noticeNameList();
        return new result(200, 1);
    }*/

    /**
     * 报名巅峰赛大赛
     * teamName队伍名
     * teamId组队时的id
     */
    public result signUp(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        //判断是否在报名时间内 11点报名，到晚上7点50
        if (//!strUtils.isWKS(4) ||
                !strUtils.isInTime(6, 0, 19, 50)) {
            //报名时间已过
            return new result(674);
        }
        final String name = user.name;
        String teamName = j.getString("teamName");
        if (strUtils.isNull(teamName) || teamName.length() > 6) {
            return new result(617);
        }
        JSONArray mList = new JSONArray();
        //获取队伍成员
        JSONObject team = startBef.teamService.getTeamByName(name);
        if (team == null || !team.getString("captain").equals(name)) {
            return new result(200, 2);//没有该队伍
        }
        JSONArray memberList = team.getJSONArray("list");
        for (Object o : memberList) {
            if (((JSONObject) o).getInteger("lever") < 60) {
                return new result(200, 6);
            }
        }
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = dao.selectAllWzySign();
        for (JSONObject l : list) {
            if (l.getString("name").equals(teamName)) {
                //判断此队伍是否重名
                return new result(200, 0);
            }
            JSONArray aList = l.getJSONArray("list");
            //判断队伍成员是否已经在其他队伍了
            for (Object a : memberList) {
                JSONObject o1 = (JSONObject) a;
                if (!staticCollection.userIsOnline(o1.getString("name"))) {
                    return new result(200, 3);//成员不在线
                }
                for (Object o2 : aList) {
                    if (o1.getString("name").equals(o2)) {
                        return new result(200, 4);//成员已经在其他队伍报名了
                    }
                }
            }
        }
        //并没有报名过
        for (Object a : memberList) {
            JSONObject o1 = (JSONObject) a;
            mList.add(o1.getString("name"));
        }
        if (dao.insertWzySign(teamName, JSON.toJSONString(mList)))
            return new result(200, 1);
        return new result(0);
    }

    /**
     * 活动开启后公布对战战名单
     */
    public boolean publishNameList(DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        try {
            List<JSONObject> list = jsonMapper.selectWzySignByPromotion("1");
            if (list.size() == 0 || list.size() == 1) {
                //只剩下最后一只队伍了，该队伍为冠军，结束战斗
                return false;
            }
            StringBuilder a0 = new StringBuilder();
            StringBuilder a1 = new StringBuilder();

            //将list进行随机
            Collections.shuffle(list);

            for (JSONObject l : list) {
                try {
                    if (a0.length() == 0) {
                        a0.append(l.getString("name"));
                    } else if (a1.length() == 0) {
                        a1.append(l.getString("name"));
                    }
                    if (a0.length() > 0 && a1.length() > 0) {
                        JSONObject obj = new JSONObject();
                        obj.put("Id", strUtils.getId());
                        obj.put("name1", a0.toString());
                        obj.put("name2", a1.toString());
                        obj.put("win", null);
                        a0.delete(0, a0.length());
                        a1.delete(0, a1.length());
                        //将队伍玩家名放入
                        JSONArray names1 = jsonMapper.selectWzySignByName(obj.getString("name1")).get(0).getJSONArray("list");
                        obj.put("list1", names1);
                        JSONArray names2 = jsonMapper.selectWzySignByName(obj.getString("name2")).get(0).getJSONArray("list");
                        obj.put("list2", names2);
                        //放入对战列表
                        fightList.add(obj);
                    }
                } catch (Exception e) {
                    loggerUtils.info("匹配异常：" + a0 + " pk " + a1 + e.getMessage(), fightList.getClass());
                }
            }
            //处理轮空
            if (list.size() % 2 == 1) {
                //String teamName=list.get(list.size()-1).getString("name");
            }
            loggerUtils.info("匹配对战对战：\n" + fightList, fightList.getClass());
        } catch (Exception e) {
            loggerUtils.error("匹配对战对战异常：\n" + e.getMessage(), fightList.getClass());
        }
        return true;
    }

    /**
     * 发布名单
     */
    public void noticeNameList() {
        if (!starting) return;
        //每次公布前都要将上一次的给清除
        fightList.clear();
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            //公布名单
            boolean b = publishNameList(con);
            //loggerUtils.info("公布名单", this.getClass());
            //公布名单之后等待玩家队伍进入赛场，40分钟后开启一轮
            if (b) {
                startBef.chatService.putSysMsg("巅峰赛第" + num + "轮，5分钟后开始，请选手到赛场准备！");
                num++;
                toFight();
            } else {
                starting = false;
                num = 1;
                //通知玩家巅峰赛大赛圆满结束
                List<JSONObject> list = getThree(con);
                StringBuilder sb = new StringBuilder();
                sb.append("本届巅峰赛圆满结束！恭喜玩家");
                for (int i = 0; i < list.size(); i++) {
                    JSONObject o = list.get(i);
                    JSONArray names = o.getJSONArray("list");
                    for (Object n : names) {
                        sb.append("[" + n + "]，");
                    }
                    if (names.size() > 0) {
                        sb.append("荣获");
                        if (i == 0) {
                            sb.append("冠军，奖励 武勋1000；");
                        } else if (i == 1) {
                            sb.append("亚军，奖励 武勋700；");
                        } else if (i == 2) {
                            sb.append("季军，奖励 武勋500；");
                        }
                    }
                }
                startBef.chatService.putSysMsg(sb.toString());
                sb.delete(0, sb.length());
                //按积分排名获取奖励
                sendReward(con);
                mybatisConfig.commit(con);
                //两分钟后设置为活动未开启
                staticCollection.putTask(() -> {
                    startBef.activityService.setDoing("wzy", 0);
                }, 2, TimeUnit.MINUTES);
            }
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 结算奖励
     */
    public Integer sendReward(DefaultSqlSession con) {
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        //查出前100名的队伍
        List<JSONObject> list = dao.getWzySignOrderByJf(0L, 100L);
        for (int i = 0; i < list.size(); i++) {
            try {
                JSONArray names = list.get(i).getJSONArray("list");
                JSONArray rewards = null;
                //改为发放武勋
                if (i == 0) {
                    //获取成员发送奖励
                    rewards = rewardUtils.getWxReward(1000);
                } else if (i == 1) {
                    rewards = rewardUtils.getWxReward(700);
                } else if (i == 2) {
                    rewards = rewardUtils.getWxReward(500);
                } else if (i < 10) {
                    rewards = rewardUtils.getWxReward(300);
                } else if (i < 20) {
                    rewards = rewardUtils.getWxReward(200);
                } else {
                    rewards = rewardUtils.getWxReward(100);
                }
                for (Object n : names) {
                    JSONArray res = startBef.rewardService.saveRewards(rewards, (String) n, con);
                    //通知奖励
                    ChannelSupervise.noticeClientByName(res, (String) n, "10000");
                }
            } catch (Exception e) {
                loggerUtils.error("发奖励时出错：队伍[" +
                        list.get(i).getString("name") + "]\n" + e.getMessage(), this.getClass());
            }
        }
        return 1;
    }

    /**
     * 根据名单匹配战斗
     */
    public void toFight() {
        //int t = 5 * 60 * 1000;//发布名单后的5分钟开启
        int t = 30 * 1000;
        //int t0=60*1000;
        //t = 12 * 60 * 60 * 1000;
        staticCollection.putTask(() -> {
            try {
                //todo bug十分钟前结束会导致多个离线检测
                //触发战斗后10分检测是否有队伍下线，有则标记弃权
                handleOffLine();
                //loggerUtils.info("开始匹配战斗：", this.getClass());
                ChannelSupervise.noticeAllClientInArea("wzy", "巅峰赛开始匹配！", "794");
                int len = fightList.size();
                for (int a = 0; a < len; a++) {
                    JSONObject l = fightList.get(a);
                    //实际能够参与战斗的玩家集合
                    JSONArray temp1 = new JSONArray();
                    JSONArray temp2 = new JSONArray();
                    //判断是否在赛场（只要在赛场就可以，不必管是否组队）
                    JSONArray list1 = l.getJSONArray("list1");
                    for (int i = 0; i < list1.size(); i++) {
                        putTemp(temp1, (String) list1.get(i), "r", i);
                    }
                    JSONArray list2 = l.getJSONArray("list2");
                    for (int i = 0; i < list2.size(); i++) {
                        putTemp(temp2, (String) list2.get(i), "l", i);
                    }
                    if (temp1.size() == 0 || temp2.size() == 0) {
                        //当两个队伍都没有成员时，视为双方弃权
                        if (temp1.size() == 0 && temp2.size() == 0) {
                            //表示弃权
                            markLoser(l.getString("Id"), 3);
                            continue;
                        }
                        //当有一个队伍有成员时，该队伍直接胜利
                        if (temp1.size() == 0) {
                            //1队弃权
                            markLoser(l.getString("Id"), 2);
                        } else {
                            //2队弃权
                            markLoser(l.getString("Id"), 1);
                        }
                        continue;
                    }
                    //将选出来实际能够参赛的玩家构建fightMsg
                    JSONObject fightMsg = getFightMsg(temp1.fluentAddAll(temp2), l.getString("Id"));
                    //调起战斗
                    user u = staticCollection.getUserByName(temp1.getJSONObject(0).getString("name"));
                    fightMsg.put("projRootDir", u.projRootDir);
                    startBef.fightService.createFight(fightMsg);
                    loggerUtils.info("调起战斗：\n" + fightMsg.toString(), this.getClass());
                }
            } catch (Exception e) {
                e.printStackTrace();
                loggerUtils.info("巅峰赛调起战斗异常：\n" + e.getMessage(), this.getClass());
            }
        }, t, TimeUnit.MILLISECONDS);
    }

    /**
     * 获取一个战斗信息对象
     */
    private JSONObject getFightMsg(JSONArray roleList, String wzyId) {
        JSONObject msg = new JSONObject();
        msg.put("roleList", roleList);
        msg.put("type", 4);
        //巅峰赛类型的战斗才需要加上对战Id
        msg.put("wzyId", wzyId);
        msg.put("monsterList", new JSONArray());
        return msg;
    }

    /**
     * 放置到参与战斗的列表
     */
    private void putTemp(JSONArray temp, String name, String direct, int i) {
        user u = staticCollection.getUserByName(name);
        //选出实际上能够参赛的成员（可能有的不在线）
        if (u == null || !u.getPos().getString("map").equals("wzy")) {
            return;
        }
        String clientId = strUtils.getId();
        JSONObject rMsg = fightUtils.getRoleMsg(u.name, u.msg.getInteger("lever"), u.msg.getString("model"),
                0, direct + i, clientId);
        temp.add(rMsg);
        //获取出战的宠物
        DefaultSqlSession con = null;
        JSONObject pet = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            pet = (JSONObject) startBef.petService.getIsFightPet(u.name, con);
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        if (pet != null) {
            rMsg = fightUtils.getRoleMsg(u.name + "_pet", pet.getInteger("lever"), pet.getString("model"),
                    1, direct + (i + 5), clientId);
            rMsg.put("nickName", pet.getString("nickName"));
            temp.add(rMsg);
        }
    }

    /**
     * 处理中途下线的玩家
     * 有两种情况：
     * 1.一直处于下线
     * 2.战斗时下线被清理了，然后上线后没有战斗来刷新fightList
     */
    public void handleOffLine() {
        //fixme：当两个队伍都下线，会导致战斗被移除，对于武状元这样的战斗就不允许战斗移除
        int t = 30 * 60 * 1000;
        final int nowNum = num;
        staticCollection.putTask(() -> {
            try {
                //轮数不相同的不用执行
                if (nowNum != num) {
                    return;
                }
                int len = fightList.size();
                for (int i = 0; i < len; i++) {
                    if (fightList.size() == 0) break;
                    JSONObject o = fightList.get(i);
                    if (o.get("win") != null) {
                        continue;
                    }
                    //对于10分钟后还没有结果的队伍以弃权处理
                    //表示弃权
                    markLoser(o.getString("Id"), 3);
                    loggerUtils.info("10分钟未比完，弃权：\n" + o, fightList.getClass());
                }

                loggerUtils.info("处理handleOffLine：\n" + fightList, fightList.getClass());
            } catch (Exception e) {
                loggerUtils.info("handleOffLine执行异常：" + e.getMessage() + fightList, fightList.getClass());
            }
        }, t, TimeUnit.MILLISECONDS);
        loggerUtils.info("启动中途下线监听", fightList.getClass());
    }

    /**
     * 标记队伍失败
     */
    public Integer markLoser(String wzyId, Integer r) {
        DefaultSqlSession con = null;
        int len = fightList.size();
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            //赢的增加队伍积分，win标记1；输的标记为淘汰(不加积分)，win标记0
            //1表示1队赢了 0表示2队赢了
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < len; i++) {
                JSONObject o = fightList.get(i);
                if (o.getString("Id").equals(wzyId)) {
                    if (r == 1) {
                        o.put("win", 1);//1表示1队，2表示2队
                        //1队增加积分
                        addJF(o.getString("name1"), con);
                        //2队标记淘汰
                        markLoser(o.getString("name2"), con);
                        sb.append("战队[" + o.getString("name1") + "]淘汰了战队[" + o.getString("name2") + "]");
                        loggerUtils.info(sb.toString(), this.getClass());
                    } else if (r == 2) {
                        o.put("win", 2);//1表示1队，2表示2队
                        //2队增加积分
                        addJF(o.getString("name2"), con);
                        //1队标记淘汰
                        markLoser(o.getString("name1"), con);
                        sb.append("战队[" + o.getString("name2") + "]淘汰了战队[" + o.getString("name1") + "]");
                        loggerUtils.info(sb.toString(), this.getClass());
                    } else if (r == 3) {
                        //双方弃权
                        o.put("win", 3);
                        markLoser(o.getString("name1"), con);
                        markLoser(o.getString("name2"), con);
                        sb.append("战队[" + o.getString("name1") + "]、[" + o.getString("name2") + "]弃权");
                        loggerUtils.info(sb.toString(), this.getClass());
                    }
                    //chatController.getInstance().putSysMsg(sb.toString());
                    ChannelSupervise.noticeAllClientInArea("wzy", sb.toString(), "794");
                    sb.delete(0, sb.length());
                    break;
                }
            }
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        //当所有都队伍win都存在时，说明该轮可以结束了
        boolean isOver = true;
        for (int i = 0; i < len; i++) {
            JSONObject o = fightList.get(i);
            if (o.get("win") == null) {
                isOver = false;
            }
        }
        if (isOver) {
            //该轮结束，可以发布下二轮
            System.err.println("该轮武状元结束");
            noticeNameList();
        }

        return 1;
    }

    /**
     * 标记失败
     */
    public boolean markLoser(String teamName, DefaultSqlSession con) {
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        JSONObject obj = dao.selectWzySignByName(teamName).get(0);
        int jf = obj.getInteger("jf");
        return dao.updateWzySignJFAndPromotion(jf - 1 + "", "0", teamName);
    }

    /**
     * 增加积分
     */
    public boolean addJF(String teamName, DefaultSqlSession con) {
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        JSONObject obj = dao.selectWzySignByName(teamName).get(0);
        int jf = obj.getInteger("jf");
        return dao.updateWzySign((jf + 1) + "", teamName);
    }
}
