package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.jsonMapper;
import my.db.mybatisConfig;
import my.gameUtils.roleUtils;
import my.model.ChannelSupervise;
import my.model.msgCenter;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;

import static my.utils.staticCollection.*;

public class teamService {
    /**
     * 设置阵位
     * type 0自己 1宠物 4ai 5伙伴
     * posKey 置入的位置
     * name 控制方角色名 组队时不需要（null）
     * isClear 清理站位的标志
     * key 伙伴、宠物对应key 玩家对应model
     */
    public void setFormation(boolean isClear, String posKey, int type, String key, String name, JSONObject formation) {
        if (isClear) {
            if (posKey == null) System.err.println("posKey不能为null");
            formation.put(posKey, "");
        } else {
            //保存阵型时是直接覆盖，所以这里不需要考虑交换位置的情况
            //先按 0-5 1-6 2-7 ...这样的站位来布置，这类站位被全部占用时才会自动安排
            String emptyPos = setFormationByType(type, formation);
            //自动安排一个站位（因使用前已经清理了伙伴位置，所以这里不再清理）
            if (emptyPos == null) {
                for (String k : formation.keySet()) {
                    if (formation.getString(k).equals("")) {
                        emptyPos = k;
                        break;
                    }
                }
            }


            formation.put(emptyPos, getFormationData(type, key, name));
        }

    }

    private String setFormationByType(int type, JSONObject formation) {
        String emptyPos = null;
        if (type == 0) {
            for (int p = 0; p < 5; p++) {
                if (formation.getString("p" + p).equals("")) {
                    emptyPos = "p" + p;
                    break;
                }
            }
        } else if (type == 1) {
            for (int p = 4; p > 0; p--) {
                //人物站位上没有位置则跳过
                if (formation.getString("p" + p).equals("")) continue;
                //倒序人物位置上摆放了则+5为宠物位置
                if (formation.getString("p" + (p + 5)).equals("")) {
                    emptyPos = "p" + (p + 5);
                    break;
                }
            }
        }

        return emptyPos;
    }

    /**
     * 非组队时使用（设置出战状态发生阵型变更）
     */
    public void updateSelfFormation(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        JSONObject formation = getFormation(name, con).getJSONObject("formation");

        initSelfFormation(formation, getUserByName(name));

        jsonMapper.updateFormation(name, JSON.toJSONString(formation));
    }

    /**
     * 初始化自己的阵型
     */
    private void initSelfFormation(JSONObject formation, user user) {
        for (int i = 0; i < 20; i++) {
            formation.put("p" + i, "");
        }
        //自己的默认位置 p0
        formation.put("p0", getFormationData(0, user.msg.getString("model"), null));
        //判断是否需要宠物位置
        if (user.msg.get("pet") != null) {
            JSONObject pet = user.msg.getJSONObject("pet");
            if (!strUtils.isNull(pet.getString("key"))) {
                formation.put("p5", getFormationData(1, pet.getString("key"), null));
            }
        }
        //伙伴位置
        if (user.msg.get("hbList") != null) {
            JSONArray hbList = user.msg.getJSONArray("hbList");
            for (int i = 0; i < hbList.size(); i++) {
                JSONObject a = hbList.getJSONObject(i);
                setFormation(false, null, 5, a.getString("key"), null, formation);
            }
        }

    }

    /**
     * 保存阵位
     */
    public result saveFormation(JSONObject j,
                                @paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONObject formation = j.getJSONObject("formation");

        JSONObject team = getTeamByName(name);
        if (team != null) {
            JSONObject a = team.getJSONObject("lineup").getJSONObject("formation");
            int num = 0;
            for (String k : a.keySet()) {
                if (a.getString(k).equals("")) continue;
                num++;
            }
            if (formation.keySet().size() != num) return new result(0);
            for (String k : a.keySet()) {
                if (a.getString(k).equals("")) continue;
                a.put(k, "");
            }
            for (String k : formation.keySet()) {
                a.put(k, formation.get(k));
            }
        } else {
            String petId = j.getString("petId");
            //处理伙伴、宠物休息上阵的状态变更
            if (petId != null) {
                startBef.petService.setPetFightStatusByFormation(petId, user, con);
            }
            int sum = 0;
            List<String> keys = new ArrayList<>();
            for (String k : formation.keySet()) {
                if (formation.getString(k).equals("")) continue;
                JSONObject a = formation.getJSONObject(k);
                if (a.getInteger("type") == 5) keys.add(a.getString("key"));
                else if (a.getInteger("type") == 1) sum++;
            }
            if (sum == 0) {
                //不存在宠物上阵，所有宠物上阵设置为0
                startBef.petService.setPetFightStatusByFormation(null, user, con);
            }
            //startBef.huobanService.setHbFightStatusByFormation(keys, user, con);

            //非组队的情况
            JSONObject a = getFormation(name, con).getJSONObject("formation");
            //要求原来阵型有多少个，上传的数据就要有多少个
            int num = 0;
            for (String k : a.keySet()) {
                if (a.getString(k).equals("")) continue;
                num++;
                a.put(k, "");
            }
            if (formation.keySet().size() != num) return new result(0);

            for (String k : formation.keySet()) {
                a.put(k, formation.get(k));
            }
            jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
            jsonMapper.updateFormation(name, JSON.toJSONString(a));
        }

        return new result(200, 1);
    }

    /**
     * 查询布阵
     */
    public result findFormation(@paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONObject lineup = null;
        JSONObject team = getTeamByName(name);
        if (team != null) {
            //组队的情况读取缓存的阵型
            //对于组队的情况，需要在每个站位上增加一个区分玩家控制的name
            lineup = team.getJSONObject("lineup");
        } else {
            //非组队的情况
            lineup = getFormation(name, con);
        }
        return new result(200, lineup);
    }

    /**
     * 查询布阵，给内部使用
     */
    public JSONObject getFormation(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectFormation(name);
        if (list.size() == 0) {
            JSONObject obj = new JSONObject();
            initSelfFormation(obj, getUserByName(name));
            jsonMapper.insertFormation(name, JSON.toJSONString(obj));
            JSONObject a = new JSONObject();
            a.put("formation", JSON.toJSONString(obj));
            list.add(a);
        }
        JSONObject res = list.get(0);
        res.put("formation", JSON.parseObject(res.getString("formation")));
        return res;
    }

    /**
     * 构造一个阵位数据
     * type 0自己 1宠物 4ai 5伙伴
     * key 区分伙伴的key，宠物、自己不需要使用
     */
    private JSONObject getFormationData(int type, String key, String playerName) {
        JSONObject a = new JSONObject();
        a.put("type", type);
        a.put("key", key);
        a.put("playerName", playerName);
        return a;
    }

    /**
     * 判断玩家是否为队长
     */
    public boolean isCaptain(String name) {
        JSONObject team = getTeamByName(name);
        if (team == null || !team.getString("captain").equals(name)) {
            return false;
        }
        return true;
    }

    /**
     * 判断是否组队并且是否为队长
     */
    public int isTeamAndCaptain(String name) {
        JSONObject team = getTeamByName(name);
        if (team != null) {
            if (team.getString("captain").equals(name)) return 1;//是队长
            return 0;//不是队长
        }
        return -1;//未组队
    }

    /**
     * 判断是否为队员
     */
    public boolean isTeamMember(String name, String player) {
        JSONObject team = getTeamByName(name);
        if (team != null) {
            JSONArray js = team.getJSONArray("list");
            for (Object a : js) {
                JSONObject m = (JSONObject) a;
                if (m.getString("name").equals(player)) return true;
            }
        }
        return false;//未组队
    }

    /**
     * 同意入队申请
     */
    public Integer agreeTeam(JSONObject j, @paramsAnno(key = "user") user user) {
        //是否在允许组队的地图
        if (!isAllowedCreateTeam(user.getPos().getString("map"))) {
            return 0;
        }
        //邀请前判断自己是否有队伍
        if (getTeamByName(j.getString("playerName")) != null) {
            return 0;
        }
        JSONObject team = teamMap.get(j.getString("Id"));
        if (team == null) {
            return 0;
        }
        //人数已满
        if (team.getJSONArray("list").size() >= 5) {
            ChannelSupervise.noticeClientByName(626, j.getString("playerName"), "799");
            return 0;
        }
        user u = staticCollection.getUserByName(j.getString("playerName"));
        if (u == null) {
            return 0;
        }
        //构建成员
        JSONObject member = new JSONObject();
        member.put("name", u.name);
        member.put("lever", u.msg.get("lever"));
        member.put("model", u.msg.get("model"));
        member.put("isFollow", 1);
        member.put("isOnline", 1);
        //同步给所有成员
        JSONArray js = team.getJSONArray("list");
        js.add(member);

        //给新加入的玩家阵位
        JSONObject formation = team.getJSONObject("lineup").getJSONObject("formation");
        //根据成员数量，清理伙伴的站位
        int len = js.size() - 1;
        remHuobanFormation(formation, len);
        addMemberToFormation(formation, u);

        //通知更新状态
        noticeMemberUpdateStatus(copyTeamAndPutPos(team));
        return 1;
    }

    /**
     * 申请入队
     */
    public Integer reqTeam(JSONObject j, @paramsAnno(key = "user") user user) {
        //是否在允许组队的地图
        if (!isAllowedCreateTeam(user.getPos().getString("map"))) {
            return 0;
        }
        //自己已经有队伍
        JSONObject team = getTeamByName(user.name);
        if (team != null) return 0;
        //申请的队伍已经解散
        team = getTeamByName(j.getString("playerName"));
        if (team == null) {
            ChannelSupervise.noticeClientByName(702, user.name, "799");
            return 0;
        }
        JSONArray js = team.getJSONArray("list");
        //人数已满
        if (js.size() >= 5) {
            ChannelSupervise.noticeClientByName(626, user.name, "799");
            return 0;
        }
        //将申请推送给该队伍的队长{lever name}
        msgCenter msgCenter = new msgCenter(1);
        String model = roleUtils.getJobFromModels(user.msg);
        msgCenter.putParams(user.name, user.msg.getInteger("lever"))
                .addParams("model", model);
        ChannelSupervise.noticeClientByName(msgCenter, team.getString("captain"), "845");
        /*JSONObject res = new JSONObject();
        res.put("name", user.name);
        res.put("lever", user.msg.get("lever"));
        ChannelSupervise.noticeClientByName(res, team.getString("captain"), "808");*/
        return 1;
    }

    /**
     * 设置跟随状态
     */
    public Integer setPlayerFollowStatus(JSONObject j, @paramsAnno(key = "user") user user) {
        JSONObject team = teamMap.get(j.getString("Id"));
        if (team == null || user.name.equals(team.getString("captain"))) return 0;
        JSONArray list = team.getJSONArray("list");
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            if (obj.getString("name").equals(user.name)) {
                //不在线不允许操作
                if (!staticCollection.userIsOnline(user.name)) {
                    return 0;
                }
                //判断跟队长是否在一个地图
                user captain = staticCollection.getUserByName(team.getString("captain"));
                user me = staticCollection.getUserByName(user.name);
                //改为跟随状态
                if (j.getInteger("isFollow") == 1) {
                    //不同地图不允许跟随
                    if (!captain.getPos().getString("map").
                            equals(me.getPos().getString("map"))) {
                        return 0;
                    }
                }
                obj.put("isFollow", j.getInteger("isFollow"));
                noticeMemberUpdateStatus(copyTeamAndPutPos(team));
                break;
            }
        }
        return 1;
    }

    /**
     * 离开队伍
     */
    public Integer leaveTeam(JSONObject j) {
        String playerName = j.getString("playerName");
        JSONObject team = getTeamByName(playerName);
        if (team == null) return 0;
        JSONArray js = team.getJSONArray("list");
        for (Object o : js) {
            JSONObject obj = ((JSONObject) o);
            if (obj.getString("name").equals(playerName)) {
                js.remove(o);
                break;
            }
        }
        //如果是队长离开队伍的话需要转移队长
        if (team.getString("captain").equals(playerName)) {
            captainToMember(team, null);
        } else {
            //不是队长的要重新安排
            reloadTeamFormation(team);
        }
        noticeMemberUpdateStatus(copyTeamAndPutPos(team));
        //通知移除队伍缓存
        ChannelSupervise.noticeClientByName(null, playerName, "809");
        return 1;
    }

    /**
     * 移交队长给指定玩家
     */
    public Integer captainToName(JSONObject j, @paramsAnno(key = "user") user user) {
        JSONObject team = teamMap.get(j.getString("Id"));
        if (team == null || !team.getString("captain")
                .equals(user.name)) return 0;
        boolean b = captainToMember(team, j.getString("playerName"));
        //通知成员状态更新
        if (b) {
            noticeMemberUpdateStatus(copyTeamAndPutPos(team));
        }
        return 1;
    }

    /**
     * 处理队伍成员上线
     */
    public void handleOnLine(String name) {
        JSONObject team = getTeamByName(name);
        if (team == null) return;
        JSONArray list = team.getJSONArray("list");
        for (Object o : list) {
            JSONObject obj = ((JSONObject) o);
            if (obj.getString("name").equals(name)) {
                obj.put("isOnline", 1);
                obj.put("isFollow", 1);
                break;
            }
        }
        noticeMemberUpdateStatus(copyTeamAndPutPos(team));
    }

    /**
     * 处理队伍成员下线
     */
    public void handleOffLine(String name) {
        JSONObject team = getTeamByName(name);
        if (team == null) return;
        JSONArray list = team.getJSONArray("list");
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            //只把当前触发者下线
            if (obj.getString("name").equals(name)) {
                obj.put("isFollow", 0);
                obj.put("isOnline", 0);
                break;
            }
        }
        //是队长的话，需要将队长权力转移给其他玩家
        if (name.equals(team.getString("captain"))) {
            boolean b = captainToMember(team, null);
            //未转移成功则需要移除队伍
            if (!b) {
                teamMap.remove(team.getString("Id"));
                team = null;
            }
        }
        if (team != null) {
            //通知成员状态更新
            noticeMemberUpdateStatus(copyTeamAndPutPos(team));
        }
    }

    /**
     * 通知成员变更状态
     */
    public void noticeMemberUpdateStatus(JSONObject team) {
        if (team == null) return;
        JSONArray list = team.getJSONArray("list");
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            //对于离线的不用通知
            if (obj.getInteger("isOnline") != 1 ||
                    !staticCollection.userIsOnline(obj.getString("name"))) {
                continue;
            }
            ChannelSupervise.noticeClientByName(team, obj.getString("name"), "809");
        }
    }

    /**
     * 将队长权益交于另一个在线的玩家
     */
    public boolean captainToMember(JSONObject team, String toName) {
        String captain = team.getString("captain");
        boolean b = false;
        JSONArray list = team.getJSONArray("list");
        if (toName != null) {
            //移交指定玩家
            if (toName.equals(captain) ||
                    !staticCollection.userIsOnline(toName)) {
                return b;
            }
            for (Object o : list) {
                JSONObject obj = (JSONObject) o;
                String name = obj.getString("name");
                if (toName.equals(name)) {
                    team.put("captain", toName);
                    obj.put("isFollow", 1);
                    b = true;
                    //重新安排站位，因为换了队长，伙伴必然变动，所以整个需要重新安排
                    reloadTeamFormation(team);

                    break;
                }
            }
            return b;
        }
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            String name = obj.getString("name");
            if (!name.equals(captain) && obj.getInteger("isOnline") == 1) {
                //玩家在线
                if (staticCollection.userIsOnline(name)) {
                    team.put("captain", name);
                    obj.put("isFollow", 1);
                    b = true;
                    //重新安排站位，因为换了队长，伙伴必然变动，所以整个需要重新安排
                    reloadTeamFormation(team);

                    break;
                }
            }
        }
        return b;
    }

    /**
     * 同意邀请（别人发邀请，我同意）
     */
    public Integer agreeInvite(JSONObject j, @paramsAnno(key = "user") user user) {
        //判断所在地图是否允许组队
        if (!isAllowedCreateTeam(user.getPos().getString("map"))) {
            return 0;
        }
        JSONObject team = null;
        //通知队伍不存在
        if (j.getString("Id") == null || (team = teamMap.get(j.getString("Id"))) == null) {
            ChannelSupervise.noticeClientByName(702, user.name, "799");
            return 0;
        }
        JSONArray list = team.getJSONArray("list");
        if (list.size() >= 5) {
            //提示人数已满
            ChannelSupervise.noticeClientByName(626, user.name, "799");
            return 0;
        }
        //入队前判断受邀请者是否加入其他队伍
        if (getTeamByName(user.name) != null) {
            ChannelSupervise.noticeClientByName(638, user.name, "799");
            return 0;
        }

        int lever = user.msg.getInteger("lever");
        String model = user.msg.getString("model");
        //构建成员
        JSONObject member = new JSONObject();
        member.put("name", user.name);
        member.put("lever", lever);
        member.put("model", model);
        member.put("isFollow", 1);
        member.put("isOnline", 1);
        list.add(member);
        //给新加入的玩家阵位
        JSONObject formation = team.getJSONObject("lineup").getJSONObject("formation");
        //根据成员数量，清理伙伴的站位
        int len = list.size() - 1;
        remHuobanFormation(formation, len);
        //给新队员阵位
        addMemberToFormation(formation, user);

        //复制一份并赋予位置信息
        JSONObject temp = copyTeamAndPutPos(team);
        if (team == null) return 0;
        list = team.getJSONArray("list");
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            ChannelSupervise.noticeClientByName(temp, obj.getString("name"), "809");
        }
        return 1;
    }

    /**
     * 复制一份队伍数据并对成员添加位置
     */
    private JSONObject copyTeamAndPutPos(JSONObject team) {
        JSONObject temp = staticCollection.copyObj(team, JSONObject.class);
        user captain = staticCollection.getUserByName(temp.getString("captain"));
        if (captain == null) return null;
        JSONArray aList = temp.getJSONArray("list");
        //同步队伍信息
        for (Object o : aList) {
            JSONObject obj = (JSONObject) o;
            obj.put("pos", captain.getPos());
        }
        return temp;
    }

    /**
     * 邀请入队
     */
    public result inviteTeam(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        //判断所在地图是否允许组队
        if (!isAllowedCreateTeam(user.getPos().getString("map"))) {
            return new result(630);
        }
        //如果该玩家没有队伍的话就需要创建队伍
        JSONObject team = (JSONObject) createTeam(user, con).getMsg();
        String teamId = team.getString("Id");
        //邀请前判断被邀请玩家是否有队伍
        String playerName = j.getString("playerName");
        if (getTeamByName(playerName) != null) {
            //提示已经处于队伍中
            return new result(638);
        }
        //todo 判断被邀请对象是否处于战斗中
        /*if(fightController.isFighting(j.getString("playerName"))){
            //提示对方处于战斗中
            if (ws != null)
                webSocket.noticeClient(681, ws, "799");
            return "";
        }*/
        msgCenter msgCenter = new msgCenter(0);
        String model = roleUtils.getJobFromModels(user.msg);
        msgCenter.putParams(user.name, user.msg.getInteger("lever"))
                .addParams("model", model).addParams("Id", teamId);
        ChannelSupervise.noticeClientByName(msgCenter, playerName, "845");

        return new result(200, team);
    }

    /**
     * 解散队伍
     */
    public Integer dismissTeam(@paramsAnno(key = "user") user user) {
        String name = user.name;
        JSONObject team = getTeamByName(name);
        //队伍是否存在、是否为队长
        if (team == null || (team != null &&
                !team.getString("captain").equals(name))) {
            return 0;
        }
        //通知所有成员队伍解散了
        JSONArray list = team.getJSONArray("list");
        for (Object t : list) {
            JSONObject obj = (JSONObject) t;
            ChannelSupervise.noticeClientByName(null, obj.getString("name"), "806");
        }
        //删除这个队伍
        teamMap.remove(team.getString("Id"));
        return 1;
    }

    /**
     * 创建队伍,创建成功返回id，如果存在队伍则返回该队伍id
     */
    public result createTeam(@paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        String name = user.name;
        JSONObject team = getTeamByName(name);
        //队伍已存在\玩家是否处于允许组队的场景
        if (team != null)
            return new result(200, team);
        if (!isAllowedCreateTeam(user.getPos().getString("map"))) {
            return new result(630);
        }
        JSONObject teamMember = new JSONObject();
        teamMember.put("name", name);
        teamMember.put("lever", user.msg.getInteger("lever"));
        teamMember.put("model", user.msg.getString("model"));
        teamMember.put("isFollow", 1);
        teamMember.put("isOnline", 1);

        String Id = strUtils.getId();
        JSONArray list = new JSONArray();
        list.add(teamMember);
        team = new JSONObject();
        team.put("Id", Id);
        team.put("captain", name);
        team.put("list", list);
        //默认阵型
        JSONObject obj = new JSONObject();
        initTeamFormation(obj, user);
        JSONObject formation = new JSONObject();
        formation.put("formation", obj);
        //todo:可能后期会加入阵法，指定阵位获得属性加成等
        team.put("lineup", formation);

        teamMap.put(Id, team);
        //通知创建队伍成功
        //ChannelSupervise.noticeClient(team, user.channelId, "805");
        return new result(200, team);
    }

    /**
     * 重新安排站位
     */
    public void reloadTeamFormation(JSONObject team) {
        JSONObject fm = team.getJSONObject("lineup").getJSONObject("formation");
        String name = team.getString("captain");
        JSONArray list = team.getJSONArray("list");
        user u = staticCollection.getUserByName(name);
        if (u == null) {
            return;
        }
        initTeamFormation(fm, u);
        //根据成员数量，清理伙伴的站位
        int len = list.size() - 1;
        remHuobanFormation(fm, len);
        //添加不是队长的站位
        for (Object t : list) {
            String n = ((JSONObject) t).getString("name");
            if (!n.equals(name))
                addMemberToFormation(fm, staticCollection.getUserByName(n));
        }
    }

    /**
     * 清理伙伴站位
     */
    private void remHuobanFormation(JSONObject fm, int len) {
        int num = 0;
        for (String k : fm.keySet()) {
            if (num == len) break;
            if (fm.getString(k).equals("")) continue;
            JSONObject f = fm.getJSONObject(k);
            if (f.getInteger("type") == 5) {
                fm.put(k, "");
                num++;
            }
        }
    }

    /**
     * 初始化队伍的阵型
     * name 队长名
     */
    private void initTeamFormation(JSONObject formation, user user) {
        String name = user.name;
        for (int i = 0; i < 20; i++) {
            formation.put("p" + i, "");
        }
        //自己的默认位置 p0
        formation.put("p0", getFormationData(0, user.msg.getString("model"), name));
        //判断是否需要宠物位置
        if (user.msg.get("pet") != null) {
            JSONObject pet = user.msg.getJSONObject("pet");
            if (!strUtils.isNull(pet.getString("key"))) {
                formation.put("p5", getFormationData(1, pet.getString("key"), name));
            }
        }
        //伙伴位置
        if (user.msg.get("hbList") != null) {
            JSONArray hbList = user.msg.getJSONArray("hbList");
            for (int i = 0; i < hbList.size(); i++) {
                JSONObject a = hbList.getJSONObject(i);
                setFormation(false, null, 5, a.getString("key"), name, formation);
            }
        }

    }

    /**
     * 将队员添加到阵型中(队员不需要伙伴)
     * fixme：使用这个前需要对队长伙伴位置进行清理
     */
    private void addMemberToFormation(JSONObject formation, user user) {
        if (user == null) return;
        setFormation(false, null, 0, user.msg.getString("model"), user.name, formation);
        //判断是否需要补充宠物站位（从user里面取）
        if (user.msg.get("pet") != null) {
            JSONObject pet = user.msg.getJSONObject("pet");
            if (!strUtils.isNull(pet.getString("key"))) {
                setFormation(false, null, 1, pet.getString("key"), user.name, formation);
            }
        }
    }

    /**
     * 判断是否处于允许组队的场景
     */
    public boolean isAllowedCreateTeam(String map) {
        String[] maps = {
                "abyss", "cbd", "xxzd",
        };
        for (String m : maps) {
            if (map.contains(m)) return false;
        }
        return true;
    }

    /**
     * 将队长位置同步给队员
     * fixme:只在地图跳转时调用，上传位置时不调用（前端通过加载玩家模型来找队长位置）
     */
    public Integer captainPosToMember(String name) {
        JSONObject team = getTeamByName(name);
        //队伍不存在\队长才能同步其位置
        if (team == null ||
                !team.getString("captain").equals(name)) {
            return 0;
        }
        user u = staticCollection.getUserByName(name);
        JSONObject pos = u.getPos();
        JSONArray list = team.getJSONArray("list");
        for (Object o : list) {
            JSONObject obj = ((JSONObject) o);
            //队长本身无需同步，但成员需要知道
            if (obj.getString("name").equals(team.getString("captain"))) {
                continue;
            }
            //获取成员
            user user = staticCollection.getUserByName(obj.getString("name"));
            if (user != null) {
                //为成员设置位置，只有成员是跟随的情况下才设置位置
                //必须复制对象，否则成员会和队长操作同一个对象.导致成员位置跟玩家位置一样
                if (obj.getInteger("isFollow") == 1) {
                    JSONObject p = pos.getJSONObject("pos");
                    user.setPos(pos.getString("map"),
                            p.getFloat("x"), p.getFloat("y"), p.getFloat("z"));
                }
                //将队长位置同步给成员(只做保存队长位置，方便跟随的判断)
                ChannelSupervise.noticeClient(u.getPos(), user.channelId, "812");
            }
        }
        return 1;
    }

    /**
     * 由成员名获取队伍
     */
    public JSONObject getTeamByName(String name) {
        for (String id : teamMap.keySet()) {
            JSONArray js = teamMap.get(id).getJSONArray("list");
            //遍历队伍成员，获取队伍id
            for (Object o : js) {
                JSONObject obj = (JSONObject) o;
                //存在队伍
                if (obj.getString("name").equals(name)) {
                    return teamMap.get(id);
                }
            }
        }
        return null;
    }
}
