package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.gangsMapper;
import my.dao.roleMapper;
import my.data.mapData;
import my.db.mybatisConfig;
import my.model.*;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;

import static my.data.mapData.getVc;

public class mapService {
    /**
     * 获取地图相关npcKeys
     */
    public result getNpcsByMapKey(JSONObject obj,
                                  @paramsAnno(key = "user") user user) {
        List<JSONObject> al = null;
        if (user.projRootDir.equals("xq2d")) {
            al = mapData.getXq2dData(obj.getString("key"));
        }
        List<String> list = new ArrayList<>();
        for (JSONObject a : al) {
            list.add(a.getString("key"));
        }
        return new result(200, list);
    }

    public result toMap(JSONObject obj,
                        @paramsAnno(key = "user") user user,
                        @paramsAnno(key = "con") DefaultSqlSession con) throws Exception {
        final String name = user.name;
        if (obj.get("key") == null) {
            return null;
        }
        //判断是否在监狱
        if(!startBef.prisonService.isOver30Min(name,con)){
            obj.put("key", "prison");
        }

        //对于帮派地图需要判断所在帮派的等级、开启的npc
        /*if (obj.getString("key").contains("bp_")) {
            JSONObject msg = startBef.gangsService.getGangsMsgByName(name, con);
            if (msg != null) {
                params = msg;
            } else {
                //没有加入帮派时，默认1图
                obj.put("key", "m_1");
            }
        }*/


        //处于监狱时是不会有藏宝图的
        /*if (a == null) {
            //是否需要添加藏宝图生成的npc位置
            JSONObject map = startBef.wbService.getBZPos(name, obj.getString("key"), con);
            if (map != null) {
                list.add(map);
            }
        }*/
        List<JSONObject> list = new ArrayList<>();
        List<JSONObject> buildList = new ArrayList<>();
        //上古战场（2d魔尊图处理）
        handleSgzc(obj, name, list, con);
        //判断幽谷秘宝是否需要生成宝箱
        //handleYGMB(obj, name, list, con);
        //洪荒宝库宝箱生成
        handleHHBK(obj, name, list, con);
        //帮派场景处理
        handleBP(obj, user, list, con);
        //副本地图，添加相应npc
        handleFB(obj, name, list, con);
        //帮战场景处理
        handleBZ(obj, user, list, con);
        //魔神降临处理
        //handleMSJL(obj, user, list, con);
        //魔神窟处理
        handleMSK(obj, user, list, con);
        //百炼玄塔
        handleBLXT(obj, user, list, con);
        //仗剑除魔
        handleZJCM(obj, user, list, con);
        //采阴补阳
        handleCYBY(obj, user, list, con);
        //监狱风云
        handleJYFY(obj, user, list, con);

        //添加该地图相关npc
        List<JSONObject> al = null;
        if(user.projRootDir==null) return new result(0);
        if (user.projRootDir.equals("xq2d")) {
            al = mapData.getXq2dData(obj.getString("key"));
        }
        list.addAll(al);
        //天降月饼活动生成月饼npc
        /*if (mapData.isMainCity(obj.getString("key"))) {
            int yuebing = startBef.zhouqiuAcService.getOneByMapKey(obj.getString("key"));
            for (int i = 0; i < yuebing; i++) {
                list.add(mapData.getOne("5075", strUtils.getRandom(300, 1200), strUtils.getRandom(300, 1200)));
            }
        }*/
        //年兽降临主城
        /*if (mapData.isMainCity(obj.getString("key"))) {
            int yuebing = startBef.npcCreateService.getOneByMapKey(obj.getString("key"));
            for (int i = 0; i < yuebing; i++) {
                list.add(mapData.getOne("5082", strUtils.getRandom(300, 1200), strUtils.getRandom(300, 1200)));
            }
        }*/

        //通知队伍成员跳转地图
        vector3 v3 = mapData.getInitPos(obj.getString("key"));
        user.setPos(obj.getString("key"), v3.x, v3.y, v3.z);
        //判断该地图是否允许组队，不允许则脱离队伍
        if (startBef.teamService.isAllowedCreateTeam(obj.getString("key"))) {
            //将当前地图的初始位置同步给队员
            startBef.teamService.captainPosToMember(name);
        } else {
            JSONObject p = new JSONObject();
            p.put("playerName", name);
            startBef.teamService.leaveTeam(p);
        }

        JSONObject res = new JSONObject();
        res.put("list", list);
        res.put("key", obj.getString("key"));
        res.put("buildList", buildList);
        return new result(200, res);
    }



    /**
     * 百炼玄塔
     */
    private void handleBLXT(JSONObject obj, user user, List<JSONObject> list, DefaultSqlSession con) {
        if (!obj.getString("key").contains("blxt")) {
            return;
        }
        //先获取层数
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> al = activityMapper.getBLYT(user.name);
        if (al.size() == 0) {
            activityMapper.addBLYT(user.name);
            al = activityMapper.getBLYT(user.name);
        }
        JSONObject one = al.get(0);
        //最多70层
        if (one.getInteger("lever") > 70) one.put("lever", 70);

        int num = (one.getInteger("lever") - 1) / 10 + 1;

        //设置对应层级的地图
        obj.put("key", "blxt" + num);
        vector2[] vs = {
                getVc(115, 350), getVc(195, 350), getVc(275, 350),
                getVc(275, 270), getVc(195, 270), getVc(115, 270),
                getVc(115, 190), getVc(195, 190), getVc(275, 190),
                getVc(275, 110),
        };
        int len = (one.getInteger("lever") - 1) % 10 + 1;
        for (int i = 1; i <= len; i++) {
            list.add(mapData.getOne("blxt_" + ((num - 1) * 10 + i), vs[i - 1], null));
        }

    }

    /**
     * 魔神窟
     */
    private void handleMSK(JSONObject obj, user user, List<JSONObject> list, DefaultSqlSession con) {
        if (!obj.getString("key").contains("msd")) {
            return;
        }
        //先获取默认任务
        JSONArray arr = startBef.taskService.getTaskList(user.name, con);
        Integer tk = null;
        for (int i = 0; i < arr.size(); i++) {
            JSONObject a = arr.getJSONObject(i);
            if (a.getInteger("key") >= 3265 && a.getInteger("key") < 3272 &&
                    a.getInteger("status") == 2) {
                tk = a.getInteger("key");
                break;
            }
        }
        if (tk == null) return;
        if (obj.getString("key").equals("kgmsd") && tk != 3265) return;
        else if (obj.getString("key").equals("tbmsd") && tk != 3266) return;
        else if (obj.getString("key").equals("smmsd") && tk != 3267) return;
        else if (obj.getString("key").equals("ssmsd") && tk != 3268) return;
        else if (obj.getString("key").equals("sheshoumsd") && tk != 3269) return;
        else if (obj.getString("key").equals("fsmsd") && tk != 3270) return;
        else if (obj.getString("key").equals("bnmsd") && tk != 3271) return;
        //创建魔神护卫
        list.add(mapData.getOne("mshuwei_" + (tk - 3264), getVc(265f, 300f), null));
    }

    /**
     * 仗剑除魔
     */
    private void handleZJCM(JSONObject obj, user user, List<JSONObject> list, DefaultSqlSession con) {
        if (!obj.getString("key").contains("m_")) {
            return;
        }
        //判断是否接取了任务
        JSONArray arr = startBef.taskService.getTaskList(user.name, con);
        boolean b = false;
        for (int i = 0; i < arr.size(); i++) {
            JSONObject a = arr.getJSONObject(i);
            if (a.getInteger("key") == 3273 &&
                    a.getInteger("status") == 2) {
                b = true;
                break;
            }
        }
        if (!b) {
            return;
        }
        activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
        String mapKey = dao.getZJCM(user.name).get(0).getString("map_key");
        if (!obj.getString("key").equals(mapKey)) {
            return;
        }
        //创建吸魂小妖
        list.add(mapData.getOne("xhxy_1", getVc(265f, 300f), null));
    }

    /**
     * 采阴补阳
     */
    private void handleCYBY(JSONObject obj, user user, List<JSONObject> list, DefaultSqlSession con) {
        if (!obj.getString("key").equals("m_30")) {
            return;
        }
        //判断是否接取了任务
        JSONArray arr = startBef.taskService.getTaskList(user.name, con);
        boolean b = false;
        for (int i = 0; i < arr.size(); i++) {
            JSONObject a = arr.getJSONObject(i);
            if (a.getInteger("key") == 3282 &&
                    a.getInteger("status") == 2) {
                b = true;
                break;
            }
        }
        if (!b) {
            return;
        }
        //创建狐萌萌
        list.add(mapData.getOne("cyby_1", getVc(265f, 300f), null));
    }

    /**
     * 监狱风云
     */
    private void handleJYFY(JSONObject obj, user user, List<JSONObject> list, DefaultSqlSession con) {
        if (!obj.getString("key").equals("m_12") &&
                !obj.getString("key").equals("m_5") &&
                !obj.getString("key").equals("m_4") &&
                !obj.getString("key").equals("m_10") &&
                !obj.getString("key").equals("m_11")) {
            return;
        }
        String mapKey = obj.getString("key");
        //判断是否接取了任务
        JSONArray arr = startBef.taskService.getTaskList(user.name, con);

        for (int i = 0; i < arr.size(); i++) {
            JSONObject a = arr.getJSONObject(i);
            if (mapKey.equals("m_12") && a.getInteger("key") == 3283 &&
                    a.getInteger("status") == 2) {
                list.add(mapData.getOne("jyfy_1", getVc(265f, 300f), null));
                break;
            } else if (mapKey.equals("m_5") && a.getInteger("key") == 3284 &&
                    a.getInteger("status") == 2) {
                list.add(mapData.getOne("jyfy_2", getVc(265f, 300f), null));
                break;
            } else if (mapKey.equals("m_4") && a.getInteger("key") == 3285 &&
                    a.getInteger("status") == 2) {
                list.add(mapData.getOne("jyfy_3", getVc(265f, 300f), null));
                break;
            } else if (mapKey.equals("m_10") && a.getInteger("key") == 3286 &&
                    a.getInteger("status") == 2) {
                list.add(mapData.getOne("jyfy_4", getVc(265f, 300f), null));
                break;
            } else if (mapKey.equals("m_11") && a.getInteger("key") == 3287 &&
                    a.getInteger("status") == 2) {
                list.add(mapData.getOne("jyfy_5", getVc(265f, 300f), null));
                break;
            }
        }


    }

    /**
     * 处理帮战场景
     * list 放置需要动态生成的npc
     */
    private void handleBZ(JSONObject obj, user user, List<JSONObject> list, DefaultSqlSession con) {
        if (!obj.getString("key").equals("bz")) {
            return;
        }
        //判断玩家是否加入了帮派
        if (user.msg.get("bpId") == null) {
            //没有加入帮派就要给默认地图
            obj.put("key", "m_1");
        }
        //是否帮战开启了
        if (startBef.gangsService.isBzAcOpen) {
            //生成宝箱
            JSONArray box = startBef.gangsService.getBoxsByBpId(user.msg.getString("bpId"));
            list.addAll(JSON.parseArray(JSON.toJSONString(box), JSONObject.class));
        }
    }

    /**
     * 处理帮派场景
     * list 放置需要动态生成的npc
     */
    private void handleBP(JSONObject obj, user user, List<JSONObject> list, DefaultSqlSession con) {
        if (!obj.getString("key").contains("gangs")) {
            return;
        }
        //判断玩家是否加入了帮派
        if (user.msg.get("bpId") == null) {
            //没有加入帮派就要给默认地图
            obj.put("key", "m_1");
        }
        if (user.msg.get("bpId") != null && user.projRootDir.equals("xq2d")) {
            //2d需要根据等级来判断加载的场景
            JSONObject bpMsg = startBef.gangsService.getBpBaseMsg(user, con);
            String mk = "gangs1";
            int lv = bpMsg.getInteger("lever");
            if (lv == 2) mk = "gangs2";
            else if (lv == 3) mk = "gangs3";
            else if (lv == 4) mk = "gangs4";
            else if (lv == 5) mk = "gangs5";
            else if (lv == 6) mk = "gangs6";
            obj.put("key", mk);
            //对活动开启的处理
            if (startBef.gangsService.activityIsOpen("ywt", user.msg.getString("bpId"), con)) {
                if (lv == 2)
                    list.add(mapData.getOne("10000600", getVc(200, 200f), null));
                else if (lv == 3)
                    list.add(mapData.getOne("10000600", getVc(250, 150f), null));
                else if (lv == 4)
                    list.add(mapData.getOne("10000600", getVc(250, 150f), null));
                else if (lv == 5)
                    list.add(mapData.getOne("10000600", getVc(250, 150f), null));
                else if (lv == 6)
                    list.add(mapData.getOne("10000600", getVc(100, 350f), null));
            }
        }

        //todo：2d版本需要修改npckey
        if (user.projRootDir.equals("xq2d")) return;



    }

    private String[] addToList(String... k) {
        return k;
    }

    /**
     * 副本地图，生成任务相应npc
     */
    private void handleFB(JSONObject obj, String name, List<JSONObject> list, DefaultSqlSession con) {
        if (true) return;
        //以下是3d版本的逻辑
        String mk = obj.getString("key");
        if (!mk.equals("m_3") && !mk.equals("m_4") && !mk.equals("m_8") &&
                !mk.equals("m_13") && !mk.equals("m_17") && !mk.equals("m_18")) {
            return;
        }
        List<JSONObject> npcs = new ArrayList<>();
        String[] taskKeys = null;
        if (mk.equals("m_3")) {
            taskKeys = addToList("3163", "3164", "3165", "3166");
            npcs.add(mapData.getOne("2111", getVc(-104f, 34f, -100.4f), null));
            npcs.add(mapData.getOne("2112", getVc(-96f, 38f, -100.5f), null));
            npcs.add(mapData.getOne("2113", getVc(-87f, 35f, -99.6f), null));
            npcs.add(mapData.getOne("2114", getVc(-98f, 53f, -100f), null));
        } else if (mk.equals("m_4")) {
            taskKeys = addToList("3167", "3168", "3169", "3170");
            npcs.add(mapData.getOne("2115", getVc(-12f, 40f, -63.9f), null));
            npcs.add(mapData.getOne("2116", getVc(-28f, 40f, -63.9f), null));
            npcs.add(mapData.getOne("2117", getVc(-34f, 28f, -63.9f), null));
            npcs.add(mapData.getOne("2118", getVc(-39f, 19f, -63.9f), null));
        } else if (mk.equals("m_8")) {
            taskKeys = addToList("3171", "3172", "3173", "3174");
            npcs.add(mapData.getOne("2119", getVc(63f, 62f, -39.8f), null));
            npcs.add(mapData.getOne("2120", getVc(54f, 67f, -39.8f), null));
            npcs.add(mapData.getOne("2121", getVc(28f, 65f, -42.9f), null));
            npcs.add(mapData.getOne("2122", getVc(29f, 76f, -42.9f), null));
        } else if (mk.equals("m_13")) {
            taskKeys = addToList("3175", "3176", "3177", "3178");
            npcs.add(mapData.getOne("2123", getVc(298f, 333f, 9.2f), null));
            npcs.add(mapData.getOne("2124", getVc(312f, 333f, 9.1f), null));
            npcs.add(mapData.getOne("2125", getVc(326f, 335f, 8f), null));
            npcs.add(mapData.getOne("2126", getVc(322f, 347f, 7.5f), null));
        } else if (mk.equals("m_17")) {
            taskKeys = addToList("3179", "3180", "3181", "3182");
            npcs.add(mapData.getOne("2127", getVc(64f, 41f, -46.9f), null));
            npcs.add(mapData.getOne("2128", getVc(81f, 42f, -46.9f), null));
            npcs.add(mapData.getOne("2129", getVc(107f, 44f, -42.4f), null));
            npcs.add(mapData.getOne("2130", getVc(116f, 57f, -42.4f), null));
        } else if (mk.equals("m_18")) {
            taskKeys = addToList("3183", "3184", "3185", "3186");
            npcs.add(mapData.getOne("2131", getVc(4f, 23f, -30f), null));
            npcs.add(mapData.getOne("2132", getVc(2.8f, 31f, -30f), null));
            npcs.add(mapData.getOne("2133", getVc(-8f, 38f, -30f), null));
        } else {
            return;
        }
        JSONArray tasks = startBef.taskService.getTaskList(name, con);
        //进入前判断是否有任务
        for (Object l : tasks) {
            JSONObject a = (JSONObject) l;
            for (String taskKey : taskKeys) {
                if (a.getString("key").equals(taskKey)) {
                    //将任务相关npc放入
                    list.addAll(npcs);
                    return;
                }
            }
        }

    }

    /**
     * 2d上古战场图（魔尊）处理
     */
    private void handleSgzc(JSONObject obj, String name, List<JSONObject> list, DefaultSqlSession con) {
        if (!obj.getString("key").contains("sgzc")) {
            return;
        }
        roleMapper dao = mybatisConfig.getMapper(con, roleMapper.class);
        int mzzd = dao.findMzzd(name).get(0).getInteger("mzzd");
        if (mzzd == 1) {
            //已经打过魔尊了，跳转1图
            obj.put("key", "m_1");
        }
    }



    /**
     * 处理洪荒宝库宝箱生成
     */
    private void handleHHBK(JSONObject obj, String name, List<JSONObject> list, DefaultSqlSession con) {
        if (!obj.getString("key").equals("hhbk_3")) {
            return;
        }
        if (startBef.taskService.isCommit("3274", name, con) == 1) {
            startBef.hhbkService.sendBox("3274", list, name, false);
        }
    }

    /**
     * 推送宝箱到客户端
     * list box[]
     * type 0指定名字 1帮派 2指定地图区域
     * params type=0 params为玩家名字；type=1 params为帮派id；type=2 params为地图key
     */
    public void pushNpcToClient(JSONArray list, int type, String params, String mapKey, JSONArray clearList) {
        //ws通知地图生成npc
        JSONObject res = new JSONObject();
        res.put("mapKey", mapKey);
        res.put("list", list);
        res.put("clearList", clearList);
        if (type == 0) {
            ChannelSupervise.noticeClientByName(res, params, "102");
        } else if (type == 1) {
            ChannelSupervise.noticeAllBpMember(params, res, "102");
        } else if (type == 2) {
            ChannelSupervise.noticeAllClientInArea(params, res, "102");
        }
    }

    public void pushNpcToClient(JSONArray list, int type, String params, String mapKey) {
        pushNpcToClient(list, type, params, mapKey, null);
    }
}
