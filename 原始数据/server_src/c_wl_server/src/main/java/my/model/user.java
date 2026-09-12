package my.model;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import io.netty.channel.ChannelId;
import my.gameUtils.sysSettingUtils;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.commons.codec.digest.DigestUtils;

import java.io.Serializable;

public class user implements Serializable {
    //设备号
    public String sbh;
    //当前登录的ip
    public String ip;
    //角色名
    public String name;
    //用户名所对应的websocket
    public ChannelId channelId;
    //lever、model、pos、sez、ch、bpId
    public JSONObject msg;
    //区分游戏项目（这个项目可以包含多个游戏后台项目，每个ws连接后就要设置这个值）
    public String projRootDir;

    public user() {

    }

    public user(String name) {
        this.name = name;
    }

    public user(String ip, String name, int lever, String model, String models ) {
        this.ip = ip;
        this.name = name;
        this.msg = new JSONObject();
        this.msg.put("lever", lever);
        this.msg.put("model", model);
        this.msg.put("models", models);
    }

    /*public void setMapKey(String mapKey){
        JSONObject p=this.msg.getJSONObject("pos");
        p.put("map",mapKey);
    }*/
    public JSONObject initPos() {
        JSONObject p = new JSONObject();
        JSONObject pos = new JSONObject();
        pos.put("x", 47f);
        pos.put("y", 1.794543f);
        pos.put("z", 20f);
        p.put("map", "m_1");
        p.put("pos", pos);
        return p;
    }

    public void setPos(String mapKey, float x, float y, float z) {
        JSONObject p = this.msg.getJSONObject("pos");
        if (p == null) return;
        JSONObject pos = p.getJSONObject("pos");
        pos.put("x", x);
        pos.put("y", y);
        pos.put("z", z);
        p.put("map", mapKey);
    }

    public JSONObject getPos() {
        if (this.msg.get("pos") == null) return null;
        return this.msg.getJSONObject("pos");
    }

    /**
     * 创建设备号
     */
    public String createSbh() {
        //生成一个md5设备号号
        this.sbh = DigestUtils.md5Hex((this.name + strUtils.getId()).getBytes());
        return this.sbh;
    }

    /**
     * 对user执行下线
     */
    public void offLine() {
        sysSettingUtils.offLine(name);
        //移除并关闭通道
        ChannelSupervise.closeChannel(this.channelId);
        //移除user缓存
        staticCollection.userMap.remove(this.sbh);
    }

    @Override
    public String toString() {
        return "name:" + name + " channelId:" + channelId + " msg" + msg;
    }
}
