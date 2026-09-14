package my.gameUtils;

import com.alibaba.fastjson2.JSONObject;

import java.util.concurrent.ConcurrentHashMap;

/**
 * 游戏内系统设置
 * 如：双倍经验开关、自动战斗开关等
 */
public class sysSettingUtils {
    //fixme：上线时添加，下线时移除
    //name->{autoFight,doubleExp...}
    private static ConcurrentHashMap<String, JSONObject> setMsg = new ConcurrentHashMap<>();

    /**
     * 是否自动战斗
     */
    public static boolean isAutoFight(String name) {
        JSONObject obj = setMsg.get(name);
        if(obj == null) return true;//针对下线，默认自动
        if ( obj.getInteger("autoFight") == 0) return false;
        return true;
    }

    public static void setAutoFight(String name, int b) {
        if(name==null) return;
        JSONObject obj = setMsg.get(name);
        if (obj == null) return;
        obj.put("autoFight", b);
    }

    /**
     * 上线后进行初始化
     */
    public static void init(String name) {
        JSONObject msg = new JSONObject();
        msg.put("autoFight", 0);
        setMsg.put(name, msg);
    }
    /**下线释放*/
    public static void offLine(String name){
        setMsg.remove(name);
    }
}
