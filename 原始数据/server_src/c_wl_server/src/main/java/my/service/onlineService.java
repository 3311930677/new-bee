package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.TimeUnit;

public class onlineService {
    /**
     * 查询在线人数等信息
     */
    public result getSysMsg(JSONObject j,
                            @paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (!name.equals("吊你公龟")) return new result(0);
        JSONObject res = new JSONObject();
        res.put("userNum", staticCollection.userMap.size());
        return new result(200, res);
    }

    /**
     * 获取近期活动公告
     */
    public result getNotice(@paramsAnno(key = "user") user user) {
        final String name = user.name;
        //List<JSONObject> zlList= staticCollection.orderData.get("zhanLiList");
        List<JSONObject> zlList = new ArrayList<>();
        int sum = zlList.size();
        sum = sum > 3 ? 3 : sum;
        for (int i = 0; i < sum; i++) {
            String n = zlList.get(i).getString("name");
            if (name.equals(n)) {
                String str = null;
                if (i == 0) {
                    str = "他俯瞰大地，发现在场的都是渣渣！";
                } else if (i == 1) {
                    str = "渣渣，不要误会，我不是针对某一个，我是针对在场的各位！";
                } else if (i == 2) {
                    str = "世界尽在我的掌控之中！";
                }
                startBef.chatService.putSysMsg("战力榜第" + (i + 1) + "的" + name + "上线了！" + str);
                break;
            }
        }
        return new result(200, staticCollection.noticeMsg);
    }

    /**
     * 同步橙装特效值
     */
    public Object syncGoldType(JSONObject j,
                               @paramsAnno(key = "user") user user) {
        user.msg.put("goldType", j.getInteger("goldType"));
        return 1;
    }

    /**
     * 同步位置
     */
    public Object syncPos(JSONObject obj,
                          @paramsAnno(key = "user") user user) {
        JSONObject pos = obj.getJSONObject("pos");
        if (pos.getFloat("z") == null) {
            pos.put("z", 0);
        }
        user.setPos(obj.getString("map"),
                pos.getFloat("x"), pos.getFloat("y"), pos.getFloat("z"));
        //判断是否处于队伍，如果在队伍中并且该玩家是队长则同步位置给成员
        //teamService.captaionPosToMember(j.getString("name"));
        //System.err.println(user.name+":"+user.getPos());
        return 1;
    }

    /**
     * 拉取玩家位置
     * 改成http的请求，不要ws的，数据量大容易卡消息
     */
    public result getPlayerPos(@paramsAnno(key = "user") user user) {
        if (user == null || user.getPos() == null ||
                user.getPos().getString("map") == null) return new result(200, new JSONArray());
        final String w1 = user.name;
        //获取map里的玩家 注意这里会出现玩家自己,而且一定要复制map里的list，
        // 因为list不允许改变，一但改变就会影响下一个玩家获取map里的玩家数据数据
        String mapKey = user.getPos().getString("map");
        List<JSONObject> a = staticCollection.posMap.get(mapKey);
        if (a == null) {
            return new result(200, new JSONArray());
        }
        JSONArray list = null;
        //当玩家处于副本时，只显示队伍成员
        if (mapKey.contains("fb_")) {
            JSONObject team = startBef.teamService.getTeamByName(w1);
            if (team != null) {
                list = new JSONArray();
                JSONArray members = team.getJSONArray("list");
                user captain = staticCollection.getUserByName(team.getString("captain"));
                for (Object m : members) {
                    JSONObject t = (JSONObject) m;
                    if (!t.getString("name").equals(w1) &&
                            t.getInteger("isOnline") == 1 &&
                            t.getInteger("isFollow") == 1 &&
                            staticCollection.userIsOnline(t.getString("name"))) {
                        user u = staticCollection.getUserByName(t.getString("name"));
                        JSONObject obj = createMsg(u);
                        obj.put("pos", captain.getPos().get("pos"));
                        list.add(obj);
                    }
                }
            }
        } else if (mapKey.contains("bp_")) {
            String bpId = user.msg.getString("bpId");
            //之筛选帮派id相同的玩家
            list = new JSONArray();
            Iterator<JSONObject> l1 = a.iterator();
            while (l1.hasNext()) {
                JSONObject t = l1.next();
                user player = staticCollection.getUserByName(t.getString("name"));
                if (player == null || player.msg == null ||
                        player.msg.getString("bpId") == null) {
                    continue;
                }
                //对于不在线\不同帮派和自己都删除
                if (!t.getString("name").equals(w1) &&
                        staticCollection.userIsOnline(t.getString("name")) &&
                        player.msg.getString("bpId").equals(bpId)) {
                    list.add(t);
                }
            }
        } else {
            list = new JSONArray();
            Iterator<JSONObject> l1 = a.iterator();
            while (l1.hasNext()) {
                JSONObject t = l1.next();
                //对于不在线和自己都删除
                if (!t.getString("name").equals(w1) &&
                        staticCollection.userIsOnline(t.getString("name"))) {
                    list.add(t);
                }
            }
        }
        //if (list.size() == 0) continue;
        //当前地图没有玩家也要同步
        if (list != null) {
            return new result(200, list);
        }
        return new result(200, new JSONArray());
    }

    private JSONObject createMsg(user user) {
        JSONObject obj = new JSONObject();
        obj.put("name", user.name);
        obj.put("lever", user.msg.get("lever"));
        obj.put("model", user.msg.get("model"));
        obj.put("models", user.msg.get("models"));
        obj.put("pos", user.getPos().get("pos"));
        obj.put("sez", user.msg.get("sez"));
        obj.put("ch", user.msg.get("ch"));
        obj.put("wings", user.msg.get("wings"));
        obj.put("bpId", user.msg.get("bpId"));
        obj.put("goldType", user.msg.get("goldType"));
        obj.put("pet", user.msg.get("pet"));
        obj.put("vip", user.msg.get("vip"));
        obj.put("shenfu", user.msg.get("shenfu"));
        return obj;
    }

    /**
     * 统计玩家位置
     */
    private static boolean isDoingSyncPos = false;

    public void timerUpdatePos() {
        staticCollection.putTask(() -> {
            try {
                if (isDoingSyncPos) return;
                isDoingSyncPos = true;
                staticCollection.posMap.clear();
                //遍历每一个玩家
                for (String w : staticCollection.userMap.keySet()) {
                    user user = staticCollection.userMap.get(w);
                    if (user == null || user.msg.get("pos") == null) continue;
                    //获得当前玩家所在地图位置
                    String key = user.getPos().getString("map");
                    //todo 天渊等特殊地图不同步
                    if (key == null || key.contains("abyss")) {
                        continue;
                    }
                    List<JSONObject> temp;
                    if ((temp = staticCollection.posMap.get(key)) == null) {
                        staticCollection.posMap.put(key, new LinkedList<>());
                        temp = staticCollection.posMap.get(key);
                    }
                    JSONObject obj = createMsg(user);
                    temp.add(obj);
                }
                //对每个在线的用户都通知有新位置信息待拉取
                ChannelSupervise.noticeAllClient(1, "803");
            } catch (Exception e) {
                e.printStackTrace();
                loggerUtils.error("同步位置时报错：" + e.getMessage(), onlineService.class);
            } finally {
                isDoingSyncPos = false;
            }
        }, 10L, 10L, TimeUnit.SECONDS);
    }
}
