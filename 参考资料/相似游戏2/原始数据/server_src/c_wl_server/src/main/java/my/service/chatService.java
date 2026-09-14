package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.chatMapper;
import my.db.mybatisConfig;
import my.fightUtils.fightUtils;
import my.model.ChannelSupervise;
import my.model.msgCenter;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.*;
import java.util.concurrent.LinkedBlockingQueue;

import static my.utils.staticCollection.chatList0;
import static my.utils.staticCollection.chatList1;

public class chatService {

    /**
     * 发送离线语音
     * 会将语音暂时缓存到chat里面，当玩家点击时通过id找到他
     */
    public result sendLeaveAudio(JSONObject j,
                                 @paramsAnno(key = "user") user user) {
        //final String name = user.name;
        //结构：id->arr
        String id = j.getString("Id");
        List<JSONObject> list = staticCollection.leaveVoices.get(id);
        if (list == null) {
            list = new ArrayList<>();
            staticCollection.leaveVoices.put(id, list);
        }
        list.add(j);

        //判断结束
        int len = Integer.parseInt(id.split("_")[1]);
        if (list.size() == len) {
            putLeaveAudio(id, user);
        }

        return new result(200, 1);
    }

    /**
     * 获取离线语音
     * id
     */
    public result getLeaveAudio(JSONObject j,
                                @paramsAnno(key = "user") user user) {
        final String name = user.name;
        List<JSONObject> list = staticCollection.leaveVoices.get(j.getString("Id"));
        if (list == null) return new result(200, 0);
        /*for (JSONObject s : list) {
            ChannelSupervise.noticeClientByName(s, name, "10086");
        }*/
        return new result(200, list);
    }

    /**
     * 语音
     * todo 注意清理过期语音
     */
    public result sendAudio(JSONObject j,
                            @paramsAnno(key = "user") user user) {
        final String name = user.name;
        Map<String, JSONObject> map = staticCollection.voices.get(name);
        if (map == null) {
            map = new HashMap<>();
            staticCollection.voices.put(name, map);
        }
        map.put(j.getString("i"), j);

        //判断结束
        int len = Integer.parseInt(j.getString("Id").split("_")[1]);
        if (map.keySet().size() == len) {
            //发送给队员，由客户端排序就行
            for (String s : map.keySet()) {
                ChannelSupervise.noticeAllClient(map.get(s), "10086");
            }
            staticCollection.voices.remove(name);
        }
        return new result(200, 1);
    }

    /**
     * 推送给观战人员
     */
    public result sendToViewFightPlayer(JSONObject j,
                                        @paramsAnno(key = "user") user user) {
        final String name = user.name;
        String fgId = j.getString("Id");
        j.put("name", name);
        List<String> list = fightUtils.viewFightMap.get(fgId);
        for (String n : list) {
            ChannelSupervise.noticeClientByName(j, n, "3007");
        }
        return new result(200, 1);
    }

    /**
     * 推送给队伍成员
     * {text}
     */
    public result sendToTeam(JSONObject j,
                             @paramsAnno(key = "user") user user) {
        final String name = user.name;
        j.put("name", name);
        JSONObject team = startBef.teamService.getTeamByName(name);
        if (team == null) {
            return new result(200, 0);
        }
        JSONArray list = team.getJSONArray("list");
        j.remove("teamId");
        for (Object l : list) {
            try {
                JSONObject obj = (JSONObject) l;
                if (obj.getInteger("isOnline") == 1) {
                    ChannelSupervise.noticeClientByName(j, obj.getString("name"), "3007");
                }
            } catch (Exception e) {
                loggerUtils.error("通知成员聊天时错误：" + e.getMessage(), this.getClass());
            }
        }
        return new result(200, 1);
    }

    /**
     * 拉取消息
     */
    public Object getChatMsg(JSONObject obj,
                             @paramsAnno(key = "user") user user) {
        List<JSONObject> vs = staticCollection.copyArr(chatList0, JSONObject.class);
        int len = vs.size();
        JSONArray list = new JSONArray();
        for (int i = 0; i < len; i++) {
            JSONObject c = vs.get(i);
            //每次只拉一条数据
            if (c.getLong("created") >= obj.getLong("created")) {
                //去除发送者跟接收者一样的消息
                if (!c.getString("sender").equals(user.name))
                    list.add(c);
            }
        }
        if (list.size() > 0)
            ChannelSupervise.noticeClient(list, user.channelId, "800");
        return 1;
    }

    /**
     * 接收发送过来的消息并通知玩家拉取
     */
    public Integer send(JSONObject obj,
                        @paramsAnno(key = "user") user user) {
        String name = null;
        if (user != null) {
            name = user.name;
            //obj.put("head", getPicByJob(user.msg.getString("model")));
        } else {
            name = "系统";
        }
        //默认文字类型，语音类型会将语音id放入content里
        if (obj.get("type") == null) {
            obj.put("type", 0);
        }
        obj.put("created", strUtils.getTime());
        obj.put("sender", name);
        //群发
        if (obj.get("receiver") == null) {
            if (obj.get("content") != null && (
                    obj.getString("content").contains("赔") ||
                            obj.getString("content").contains("赌") ||
                            obj.getString("content").contains("h267471"))) {
                return 1;
            }
            //添加到缓存
            if (staticCollection.chatIndex == 0) {
                chatList0.add(obj);
                //通知有新消息可以拉取,将该时间点交给玩家
                ChannelSupervise.noticeAllClient(obj.getString("created"), "800");
            } else {
                chatList1.add(obj);
            }
            //处理世界答题
            if (obj.getInteger("channel") == 2) {
                //startBef.answerService.putAnswer(name, obj.getString("content"));
            }

            //保证消息最多50条
            if (chatList0.size() > 50) {
                JSONObject msg = chatList0.get(0);
                //语音信息需要清理
                if (msg.getInteger("type") == 1 && msg != null) {
                    staticCollection.leaveVoices.remove(msg.getString("content"));
                }
                chatList0.remove(0);
            }
            if (chatList1.size() > 50) {
                JSONObject msg = chatList1.get(0);
                //语音信息需要清理
                if (msg.getInteger("type") == 1 && msg != null) {
                    staticCollection.leaveVoices.remove(msg.getString("content"));
                }
                chatList1.remove(0);
            }
        } else {
            String receiver = obj.getString("receiver");
            //当玩家不在线的情况下才保存到数据库中，待玩家上线后拉取消息
            if (!staticCollection.userIsOnline(receiver)) {
                //不在线时转离线保存
                //addMsgToLeave(obj);
                ChannelSupervise.noticeClientByName(831, name, "799");
                return 1;
            }
            //寻找指定的玩家发送
            msgCenter msgCenter = new msgCenter(4);
            msgCenter.putParams(user.name, user.msg.getInteger("lever"));
            msgCenter.addParams("model", user.msg.getString("model"));
            msgCenter.addParams("obj", obj);
            ChannelSupervise.noticeClientByName(msgCenter, receiver, "845");
            //ChannelSupervise.noticeClientByName(obj, obj.getString("receiver"), "839");
        }
        return 1;
    }

    /**
     * 将离线消息放入缓存
     */
    public void addMsgToLeave(JSONObject msg) {
        msg.put("Id", strUtils.getId());
        msg.put("created", strUtils.getTime());
        msg.put("type", 0);
        staticCollection.leaveChatList.add(msg);
    }

    /**
     * 将离线的消息放入数据库
     */
    public void putMsgToDB() {
        LinkedBlockingQueue<JSONObject> leaveChatList = staticCollection.leaveChatList;
        if (leaveChatList.size() == 0) {
            return;
        }
        SqlSession con = null;
        try {
            con = mybatisConfig.getSqlSession();
            chatMapper chatMapper = mybatisConfig.getMapper(con, chatMapper.class);
            while (!leaveChatList.isEmpty()) {
                JSONObject obj = leaveChatList.poll();
                //fixme 为防止恶意攻击，需要判断是否满30条，满30条就删除后续的

                chatMapper.addChat(obj.getString("Id"), obj.getString("sender"),
                        obj.getString("receiver"), obj.getString("created"),
                        obj.getString("content"), obj.getString("type"));
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
     * 获取离线消息
     */
    public result getLeaveChatMsg(JSONObject j,
                                  @paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String receiver = user.name;
        String sender = j.getString("sender");
        if (strUtils.isNull(sender)) {
            return new result(0);
        }
        chatMapper chatMapper = mybatisConfig.getMapper(con, chatMapper.class);
        //拉取前30条
        List<JSONObject> list = chatMapper.getChat(sender, receiver, 0L, 30L);
        //删除相关消息
        chatMapper.delChat(sender, receiver);
        return new result(200, list);
    }

    /**
     * 投放离线语音
     */
    public void putLeaveAudio(String audioId, user user) {
        String model = user.msg.getString("model");

        JSONObject msg = new JSONObject();
        msg.put("channel", 2);
        msg.put("head", getPicByJob(model));
        //语音类
        msg.put("type", 1);
        msg.put("content", audioId);
        send(msg, user);
    }

    private String getPicByJob(String model) {
        return model + "_head_png";
    }

    /**
     * 投放红包口令消息
     */
    public void putHongBaoKlMsg(String content, user user) {
        String model = user.msg.getString("model");
        JSONObject msg = new JSONObject();
        msg.put("channel", 2);
        msg.put("head", getPicByJob(model));
        msg.put("content", content);
        send(msg, user);
    }

    /**
     * 投放系统消息
     */
    public void putSysMsg(String content) {
        JSONObject msg = new JSONObject();
        msg.put("channel", 0);
        msg.put("head", "001_png");
        msg.put("content", content);
        send(msg, null);
    }

    /**
     * 投放帮派消息
     */
    public void putBpMsg(String content, String bpId) {
        JSONObject msg = new JSONObject();
        msg.put("channel", 4);
        msg.put("head", "001_png");
        msg.put("content", content);
        msg.put("type", 0);
        JSONArray list = new JSONArray();
        list.add(msg);
        ChannelSupervise.noticeAllBpMember(bpId, list, "800");
    }


    /**
     * 带红包附件的消息
     */
    public void putMsgWithHb(String Id, String talk, user user) {
        String model = user.msg.getString("model");
        JSONObject msg = new JSONObject();
        msg.put("channel", 2);
        msg.put("head", getPicByJob(model));
        msg.put("content", "");
        JSONObject fj = new JSONObject();
        fj.put("name", "红包-" + talk);
        fj.put("type", 2);
        fj.put("Id", Id);
        msg.put("fj", fj);
        send(msg, user);
    }

    public void putMsgWithSysHb(String Id, String talk) {
        JSONObject msg = new JSONObject();
        msg.put("channel", 0);
        msg.put("head", "gm_head_png");
        msg.put("content", "");
        JSONObject fj = new JSONObject();
        fj.put("name", "红包-" + talk);
        fj.put("type", 2);
        fj.put("Id", Id);
        msg.put("fj", fj);
        send(msg, null);
    }

}
