package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.roleMapper;
import my.db.mybatisConfig;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.List;

public class friendService {
    /**删除好友*/
    public result delOne(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String playerName = j.getString("playerName");
        if (playerName == null || playerName.equals(name)) {
            return new result(200, 0);
        }
        JSONArray list = getAllFriend(name, con);
        for (Object l : list) {
            if (playerName.equals(l)) {
                list.remove(l);
                saveFriend(list, name, con);
                return new result(200, 1);
            }
        }
        return new result(200, 0);
    }
    /**
     * 获取好友列表
     */
    public Object getFriendList(String name, DefaultSqlSession con) {
        JSONArray list = getAllFriend(name, con);
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        if (list == null) {
            JSONArray l = new JSONArray();
            roleMapper.insertFriend(JSON.toJSONString(l), name);
            return l;
        }
        if (list.size() == 0) return list;
        //获取好友的全部信息
        List<JSONObject> l = roleMapper.getRolesMsg(list);
        return l;
    }

    /**
     * 添加好友
     */
    public result addOne(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String playerName = j.getString("playerName");
        if (playerName == null || playerName.equals(name)) {
            return new result(200, 0);
        }
        JSONObject role = startBef.manService.getRole(playerName, con);
        if (role != null) {
            //插入好友列表
            JSONArray list = getAllFriend(name, con);
            if (list.size() >= 40) {
                return new result(200, 2);
            }
            for (Object l : list) {
                if (playerName.equals(l)) {
                    //已经是好友了
                    return new result(200, 0);
                }
            }
            list.add(playerName);
            saveFriend(list, name, con);
            JSONObject res = new JSONObject();
            res.put("name", role.get("name"));
            res.put("lever", role.get("lever"));
            res.put("model", role.get("model"));
            res.put("models", role.get("models"));
            return new result(200, res);
        }
        return new result(0);
    }

    public Integer saveFriend(JSONArray list, String name, DefaultSqlSession con) {
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        return roleMapper.updateFriend(name, JSON.toJSONString(list)) ? 1 : 0;
    }

    public JSONArray getAllFriend(String name, DefaultSqlSession con) {
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        List<JSONObject> list = roleMapper.findFriend(name);
        if (list.size() > 0)
            return list.get(0).getJSONArray("friend");
        return null;
    }
    /**模糊查找*/
    public result getMore(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name=user.name;
        String playerName = j.getString("playerName");
        if (playerName == null|| strUtils.isNull(playerName) || name.equals(playerName)) {
            return new result(200,new JSONArray());
        }
        //需要除开自己及已经成为好友的玩家
        JSONArray list=getAllFriend(name,con);
        if(list==null){
            list=new JSONArray();
        }
        list.add(name);

        List<JSONObject> roles = startBef.manService.getRoleByLikeName(playerName,list,0L,3L, con);
        JSONArray res=new JSONArray();
        for(JSONObject r:roles) {
            JSONObject a = new JSONObject();
            a.put("name", r.get("name"));
            a.put("lever", r.get("lever"));
            a.put("model", r.get("model"));
            res.add(a);
        }
        return new result(200, res);
    }
    /**
     * 查找玩家
     */
    public result getOne(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        String playerName = j.getString("playerName");
        if (playerName == null || user.name.equals(playerName)) {
            return new result(200);
        }
        JSONObject role = startBef.manService.getRole(playerName, con);
        JSONObject res = null;
        if (role != null) {
            res = new JSONObject();
            res.put("name", role.get("name"));
            res.put("lever", role.get("lever"));
            res.put("model", role.get("model"));
        }
        return new result(200, res);
    }
}
