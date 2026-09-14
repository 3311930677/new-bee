package my.model;

import com.alibaba.fastjson2.JSON;
import io.netty.buffer.ByteBuf;
import io.netty.channel.Channel;
import io.netty.channel.ChannelId;
import io.netty.channel.group.ChannelGroup;
import io.netty.channel.group.DefaultChannelGroup;
import io.netty.handler.codec.http.websocketx.BinaryWebSocketFrame;
import io.netty.util.concurrent.GlobalEventExecutor;
import my.utils.DESUtils;
import my.utils.staticCollection;

public class ChannelSupervise {
    private static ChannelGroup GlobalGroup = new DefaultChannelGroup(GlobalEventExecutor.INSTANCE);

    public static ChannelGroup getGlobalGroup() {
        return GlobalGroup;
    }

    /**
     * 断开所有客户端
     */
    public static void closeAllClient() {
        GlobalGroup.close();
    }

    /**
     * 区域通知
     */
    public static void noticeAllClientInArea(String mapKey, Object msg, String callback) {
        try {
            String res = JSON.toJSONString(new result(200, msg, callback));
            for (String sbh : staticCollection.userMap.keySet()) {
                try {
                    user u = staticCollection.userMap.get(sbh);
                    if (u.getPos() != null && u.getPos().getString("map").equals(mapKey)) {
                        sendOne(u.channelId, res);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 通知所有玩家
     */
    public static void noticeAllClient(Object msg, String callback) {
        result result = new result(200, msg, callback);
        ChannelSupervise.sendAll(JSON.toJSONString(result));
    }

    /**
     * 通知所有帮派成员
     */
    public static void noticeAllBpMember(String bpId, Object msg, String callback) {
        result result = new result(200, msg, callback);
        ChannelSupervise.sendByBpId(bpId, JSON.toJSONString(result));
    }

    public static void noticeClientByName(Object msg, String name, String callback) {
        result result = new result(200, msg, callback);
        sendByName(name, JSON.toJSONString(result));
    }

    public static void noticeClient(Object msg, ChannelId channelId, String callback) {
        result result = new result(200, msg, callback);
        sendOne(channelId, JSON.toJSONString(result));
    }

    public static void addChannel(Channel channel) {
        GlobalGroup.add(channel);
    }

    private static void removeChannel(Channel channel) {
        GlobalGroup.remove(channel);
    }

    /**
     * 关闭并移除channel
     */
    public static void closeChannel(ChannelId channelId) {
        if (channelId == null) return;
        Channel channel = GlobalGroup.find(channelId);
        if (channel != null && (channel.isOpen() || channel.isActive())) {
            channel.close();
        }
        removeChannel(channel);
    }

    /**
     * 查找单个客户端
     */
    public static Channel findChannel(ChannelId channelId) {
        return GlobalGroup.find(channelId);
    }

    /**
     * 发送给所有客户端
     */
    public static void sendAll(String msg) {
        try {
            BinaryWebSocketFrame bw = new BinaryWebSocketFrame();
            ByteBuf buf = bw.content();
            buf.writeBytes(DESUtils.EncodeDES(msg, DESUtils.DESKEY_WS));
            GlobalGroup.writeAndFlush(bw.retain());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void sendOne(ChannelId channelId, String msg) {
        if (channelId == null) {
            return;
        }
        try {
            BinaryWebSocketFrame bw = new BinaryWebSocketFrame();
            ByteBuf buf = bw.content();
            buf.writeBytes(DESUtils.EncodeDES(msg, DESUtils.DESKEY_WS));
            Channel channel = findChannel(channelId);
            if (channel != null && channel.isOpen() && channel.isActive()) {
                channel.writeAndFlush(bw.retain());
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static void sendByName(String name, String msg) {
        user user = staticCollection.getUserByName(name);
        if (user != null) {
            sendOne(user.channelId, msg);
        }
    }

    /**
     * 通过帮派id发送
     */
    public static void sendByBpId(String bpId, String msg) {
        for (String name : staticCollection.userMap.keySet()) {
            user u = staticCollection.userMap.get(name);
            if (u != null && u.msg != null && u.msg.get("bpId") != null
                    && u.msg.get("bpId").equals(bpId)) {
                sendOne(u.channelId, msg);
            }
        }
    }
}
