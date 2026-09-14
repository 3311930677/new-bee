package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.jsonMapper;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.msgCenter;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.List;

/**
 * 师徒 50级出师 70级可收徒
 */
public class stService {
    /**
     * 增加师徒双方的情义值
     */
    public void addQhd(int qhd, JSONArray names, DefaultSqlSession con) throws Exception {
        //判断双方是否为师徒关系
        if (names.size() != 2) return;
        String name1 = names.getString(0);
        String name2 = names.getString(1);
        JSONObject tea = null;
        JSONObject stu = null;
        JSONObject msg1 = startBef.manService.getMsgData(name1, con);
        JSONObject msg2 = startBef.manService.getMsgData(name2, con);
        if (!msg1.getString("teacher").equals("")) {
            tea = msg1.getJSONObject("teacher");
        }
        if (tea == null) {//name1的师傅为null说明这个是师傅
            for (int i = 1; i < 4; i++) {
                JSONObject a = msg1.getJSONObject("stu" + i);
                if (a != null && a.getString("name").equals(name2)) {
                    stu = a;
                    stu.put("qhd", stu.getInteger("qhd") + qhd);
                    JSONObject temp = new JSONObject();
                    temp.put("stu" + i, stu);
                    //保存师傅的徒弟数据
                    startBef.manService.saveMsg(name1, temp, con);
                    temp.clear();
                    tea = msg2.getJSONObject("teacher");
                    tea.put("qhd", stu.getInteger("qhd"));
                    temp.put("teacher", tea);
                    //保存徒弟的师傅数据
                    startBef.manService.saveMsg(name2, temp, con);
                    mybatisConfig.commit(con);
                    JSONObject res = new JSONObject();
                    res.put("k", "stu" + i);
                    res.put("qhd", stu.getInteger("qhd"));
                    ChannelSupervise.noticeClientByName(res, name1, "855");
                    res.put("k", "teacher");
                    ChannelSupervise.noticeClientByName(res, name2, "855");
                    break;
                }
            }
        } else {//name1的师傅不为null，说明name1是徒弟
            if (tea.getString("name").equals(name2)) {
                for (int i = 1; i < 4; i++) {
                    JSONObject a = msg2.getJSONObject("stu" + i);
                    if (a != null && a.getString("name").equals(name1)) {
                        stu = a;
                        stu.put("qhd", stu.getInteger("qhd") + qhd);
                        JSONObject temp = new JSONObject();
                        temp.put("stu" + i, stu);
                        //保存师傅的徒弟数据
                        startBef.manService.saveMsg(name2, temp, con);
                        temp.clear();
                        tea = msg1.getJSONObject("teacher");
                        tea.put("qhd", stu.getInteger("qhd"));
                        temp.put("teacher", tea);
                        //保存徒弟的师傅数据
                        startBef.manService.saveMsg(name1, temp, con);
                        mybatisConfig.commit(con);
                        JSONObject res = new JSONObject();
                        res.put("k", "stu" + i);
                        res.put("qhd", stu.getInteger("qhd"));
                        ChannelSupervise.noticeClientByName(res, name2, "855");
                        res.put("k", "teacher");
                        ChannelSupervise.noticeClientByName(res, name1, "855");
                        break;
                    }
                }
            }
        }
    }

    /**
     * 取消登记拜师
     */
    public result remBs(
            @paramsAnno(key = "user") user user,
            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lv = user.msg.getInteger("lever");
        if (lv < 15) return new result(0);
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        return new result(200, activityMapper.remStSign(name) ? 1 : 0);
    }

    /**
     * 登记拜师
     */
    public result signBs(
            @paramsAnno(key = "user") user user,
            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断是否达到15-50级
        int lv = user.msg.getInteger("lever");
        if (lv >= 50 || lv < 15) return new result(0);
        //判断是否还有空位
        JSONObject msg = startBef.manService.getMsgData(name, con);
        if (!msg.getString("teacher").equals("")) {
            return new result(0);
        }
        //登记
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getStSign(name);
        if (list.size() == 0) {
            activityMapper.addStSign(name);
            return new result(200, 1);
        }
        return new result(867);
    }

    /**
     * 招收弟子
     * 随机匹配登记的玩家
     */
    public result recruit(
            @paramsAnno(key = "user") user user,
            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断是否达到80级
        int lv = user.msg.getInteger("lever");
        if (lv < 70) return new result(0);
        //查询是否有登记的玩家（等级>=15且小于50）
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getStSignView();
        //暂无登记的玩家
        if (list.size() == 0) return new result(865);
        for (int i = 0; i < list.size(); i++) {
            JSONObject player = list.get(i);
            String n = player.getString("name");
            int r = shoutu(name, n, con);
            if (r == -1) {
                //删除登记
                activityMapper.remStSign(n);
                continue;
            } else if (r == 0) return new result(0);
            //删除登记
            activityMapper.remStSign(n);
            return new result(200, 1);
        }
        return new result(865);
    }

    private int shoutu(String teaName, String stuName, DefaultSqlSession con) {
        int lv = startBef.manService.getRoleLv(teaName, con);
        if (lv < 70) return 0;
        //判断是否还有空位
        JSONObject msg = startBef.manService.getMsgData(teaName, con);
        String kw = null;
        String stu1 = msg.getString("stu1");
        if (kw == null && stu1.equals("")) kw = "stu1";
        String stu2 = msg.getString("stu2");
        if (kw == null && stu2.equals("")) kw = "stu2";
        String stu3 = msg.getString("stu3");
        if (kw == null && stu3.equals("")) kw = "stu3";
        if (kw == null) {
            //没有空位
            return 0;
        }
        //判断玩家是否有师傅/等级是否超过50
        JSONObject stuMsg = startBef.manService.getMsgData(stuName, con);
        String tea = stuMsg.getString("teacher");
        int tdLv = startBef.manService.getRoleLv(stuName, con);
        if (!tea.equals("") || tdLv >= 50 || tdLv < 15) {
            return -1;
        }

        JSONObject data = new JSONObject();
        JSONObject t = new JSONObject();
        t.put("name", teaName);
        t.put("qhd", 0);
        data.put("teacher", t);
        startBef.manService.saveMsg(stuName, data, con);
        //通知徒弟刷新师傅缓存
        JSONObject res = new JSONObject();
        res.put("name", teaName);
        res.put("type", 1);
        ChannelSupervise.noticeClientByName(res, stuName, "833");
        data.clear();
        t.clear();
        t.put("name", stuName);
        t.put("qhd", 0);
        data.put(kw, t);
        startBef.manService.saveMsg(teaName, data, con);
        //通知收徒成功刷新缓存
        res.clear();
        res.put("name", stuName);
        res.put("key", kw);
        res.put("type", 2);
        ChannelSupervise.noticeClientByName(res, teaName, "833");
        return 1;
    }

    /**
     * 领取扫塔任务
     */
    public result getStTask(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断玩家等级是否足够
        JSONObject obj0 = startBef.manService.getRole(name, con);
        if (obj0.getInteger("lever") < 15 ||
                obj0.getInteger("lever") >= 50) {
            return new result(0);
        }
        //是否拜了师、是否跟师傅组队了
        JSONObject msg = startBef.manService.getMsgData(name, con);
        if (msg.get("teacher").equals("")) {
            return new result(822);
        }
        //必须师徒组队
        JSONObject team = startBef.teamService.getTeamByName(name);
        if (team == null) return new result(822);
        JSONArray list = team.getJSONArray("list");
        if (list.size() == 1) {
            return new result(822);
        }
        //队伍中有师傅
        String teaName = msg.getJSONObject("teacher").getString("name");
        boolean b = false;
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("name").equals(teaName)) {
                b = true;
                break;
            }
        }
        if (!b) {
            return new result(822);
        }
        //根据等级来分配任务
        return new result(200, startBef.taskService.getStTask(name, obj0.getInteger("lever"), con));
    }

    /**
     * 出师
     */
    public result apprenticeship(
            @paramsAnno(key = "user") user user,
            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        return new result(200, chushi(name, con));
    }

    public int chushi(String name, DefaultSqlSession con) {
        JSONObject obj = startBef.manService.getRole(name, con);
        //大于50级才允许出师
        if (obj.getInteger("lever") < 50) {
            return 0;
        }

        JSONObject msg0 = startBef.manService.getMsgData(name, con);
        if (msg0.getString("teacher").equals("")) {
            return 0;
        }
        JSONObject teacher = msg0.getJSONObject("teacher");
        String teaName = teacher.getString("name");
        int qhd = teacher.getInteger("qhd");
        //徒弟玩家清空师傅
        JSONObject data = new JSONObject();
        data.put("teacher", "");
        startBef.manService.saveMsg(name, data, con);
        //师傅玩家清空该徒弟
        JSONObject msg1 = startBef.manService.getMsgData(teaName, con);
        for (int i = 1; i < 4; i++) {
            if(strUtils.isNull(msg1.getString("stu" + i))) continue;
            JSONObject a = msg1.getJSONObject("stu" + i);
            if (a.getString("name").equals(name)) {
                data.clear();
                data.put("stu" + i, "");
                startBef.manService.saveMsg(teaName, data, con);
                //通知师傅徒弟出师
                try {
                    JSONObject msg = new JSONObject();
                    msg.put("type", 0);
                    msg.put("index", "stu" + i);
                    ChannelSupervise.noticeClientByName(msg, teaName, "835");
                } catch (Exception e) {
                    e.printStackTrace();
                }
                break;
            }
        }
        //礼包分四等 <500 <1000 <2000
        String lbKey1 = null;
        String lbKey2 = null;
        if (qhd < 500) {
            lbKey1 = "10000225";
            lbKey2 = "10000229";
        } else if (qhd < 1000) {
            lbKey1 = "10000226";
            lbKey2 = "10000230";
        } else if (qhd < 2000) {
            lbKey1 = "10000227";
            lbKey2 = "10000231";
        } else {
            lbKey1 = "10000228";
            lbKey2 = "10000232";
        }
        //徒弟、师傅各一个礼包
        JSONArray r1 = rewardUtils.getGoodsReward(lbKey1, 1, 1);
        startBef.rewardService.saveRewards(r1, name, con);
        JSONArray r2 = rewardUtils.getGoodsReward(lbKey2, 1, 1);
        startBef.rewardService.saveRewards(r2, teaName, con);
        ChannelSupervise.noticeClientByName(r1, name, "10000");
        ChannelSupervise.noticeClientByName(r2, teaName, "10000");
        return 1;
    }

    /**
     * 解除关系
     * 两种情况，徒弟解除师傅关系，师傅解除徒弟关系
     */
    public result removeMatter(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String playerName = j.getString("playerName");
        if (playerName == null) {//徒弟解除师傅
            JSONObject msg0 = startBef.manService.getMsgData(name, con);
            if (msg0.getString("teacher").equals("")) {
                return new result(0);
            }
            if (startBef.manService.saveMoney(1, -50000L, name, con) == 0) {
                return new result(0);
            }
            JSONObject data = new JSONObject();
            data.put("teacher", "");
            startBef.manService.saveMsg(name, data, con);
            String teaName = msg0.getJSONObject("teacher").getString("name");
            JSONObject msg1 = startBef.manService.getMsgData(teaName, con);
            for (int i = 1; i < 4; i++) {
                if (msg1.getString("stu" + i).equals("")) continue;
                JSONObject stu = msg1.getJSONObject("stu" + i);
                if (stu.getString("name").equals(name)) {
                    data.clear();
                    data.put("stu" + i, "");
                    startBef.manService.saveMsg(teaName, data, con);
                    //通知师傅关系被解除
                    try {
                        JSONObject msg = new JSONObject();
                        msg.put("type", 0);
                        msg.put("index", "stu" + i);
                        ChannelSupervise.noticeClientByName(msg, teaName, "834");
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                    break;
                }
            }
        } else {//师傅解除徒弟
            if (startBef.manService.saveMoney(1, -50000L, name, con) == 0) {
                return new result(0);
            }
            JSONObject msg0 = startBef.manService.getMsgData(name, con);
            JSONObject data = new JSONObject();
            for (int i = 1; i < 4; i++) {
                if (msg0.getString("stu" + i).equals("")) continue;
                JSONObject stu = msg0.getJSONObject("stu" + i);
                if (stu.getString("name").equals(playerName)) {
                    data.put("stu" + i, "");
                    startBef.manService.saveMsg(name, data, con);
                    //抹除徒弟的师傅标记
                    data.clear();
                    data.put("teacher", "");
                    startBef.manService.saveMsg(playerName, data, con);
                    //通知徒弟关系被解除
                    try {
                        JSONObject msg = new JSONObject();
                        msg.put("type", 1);
                        ChannelSupervise.noticeClientByName(msg, playerName, "834");
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                    break;
                }
            }
        }
        return new result(200, 1);
    }

    /**
     * 递交拜师申请
     */
    public result apprentice(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String playerName = j.getString("playerName");
        //判断玩家等级是否符合
        JSONObject obj0 = startBef.manService.getRole(name, con);
        if (obj0.getInteger("lever") < 15 ||
                obj0.getInteger("lever") >= 50) {
            return new result(0);
        }
        //判断是否足够等级去招收弟子
        JSONObject obj1 = startBef.manService.getRole(playerName, con);
        if (obj1.getInteger("lever") < 70) {
            return new result(0);
        }
        JSONObject msg0 = startBef.manService.getMsgData(name, con);
        //判断是否已经有师傅了
        if (!msg0.getString("teacher").equals("")) {
            return new result(0);
        }
        JSONObject msg1 = startBef.manService.getMsgData(playerName, con);
        //是否重复招收
        for (int i = 1; i < 4; i++) {
            JSONObject stu = msg1.getJSONObject("stu" + i);
            if (stu == null) continue;
            if (stu.getString("name").equals(playerName)) {
                return new result(0);
            }
        }
        //判断是否有收徒位置
        int i = -1;
        if (msg1.getString("stu1").equals("")) {
            i = 1;
        } else if (msg1.getString("stu2").equals("")) {
            i = 2;
        } else if (msg1.getString("stu3").equals("")) {
            i = 3;
        }
        if (i == -1) {
            //没有位置
            return new result(864);
        }
        //通知有人申请做你的徒弟
        msgCenter msgCenter = new msgCenter(2);
        msgCenter.putParams(name, user.msg.getInteger("lever"));
        ChannelSupervise.noticeClientByName(msgCenter, playerName, "845");
        return new result(200, 1);
    }

    /**
     * 申请收徒
     */
    public result reqSt(JSONObject j,
                        @paramsAnno(key = "user") user user,
                        @paramsAnno(key = "con") DefaultSqlSession con) {
        //师傅
        final String name = user.name;
        if (user.msg.getInteger("lever") < 70) return new result(0);
        String stuName = j.getString("playerName");
        //通知有人申请做你的师傅
        msgCenter msgCenter = new msgCenter(3);
        msgCenter.putParams(name, user.msg.getInteger("lever"));
        ChannelSupervise.noticeClientByName(msgCenter, stuName, "845");
        return new result(200, 1);
    }

    /**
     * 徒弟同意成为徒弟
     */
    public result agreeBecomeStu(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        //徒弟名
        final String name = user.name;
        //师傅名
        String teaName = j.getString("playerName");
        //判断玩家等级是否符合
        JSONObject obj0 = startBef.manService.getRole(name, con);
        if (obj0.getInteger("lever") < 15 ||
                obj0.getInteger("lever") >= 50) {
            return new result(0);
        }
        //判断是否足够等级去招收弟子
        JSONObject obj1 = startBef.manService.getRole(teaName, con);
        if (obj1.getInteger("lever") < 70) {
            return new result(0);
        }
        int r = shoutu(teaName, name, con);
        if (r == 0) return new result(0);//自己满徒弟等
        else if (r == -1) return new result(0);//徒弟已经有师傅、或出师了
        return new result(200, 1);
    }

    /**
     * 师傅同意拜师申请
     */
    public result agreeApprentice(JSONObject j,
                                  @paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        //师傅名
        final String name = user.name;
        //徒弟
        String stuName = j.getString("playerName");
        //判断玩家等级是否符合
        JSONObject obj0 = startBef.manService.getRole(stuName, con);
        if (obj0.getInteger("lever") < 15 ||
                obj0.getInteger("lever") >= 50) {
            return new result(0);
        }
        //判断是否足够等级去招收弟子
        JSONObject obj1 = startBef.manService.getRole(name, con);
        if (obj1.getInteger("lever") < 70) {
            return new result(0);
        }
        int r = shoutu(name, stuName, con);
        if (r == 0) return new result(0);//自己满徒弟等
        else if (r == -1) return new result(0);//徒弟已经有师傅、或出师了
        return new result(200, 1);
    }
}
