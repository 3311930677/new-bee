package my.service.ac;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.gameUtils.rewardUtils;
import my.model.result;
import my.model.user;
import my.startBef;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 门派保卫战
 */
public class mpbwzService {
    private Map<String, JSONObject> mpbwzMap = null;

    public void startAc() {
        initNum();
        setNowMp("mj");
    }

    /**
     * 战斗之前需要先判断是否还有剩余怪物
     */
    public result isHasMonster(JSONObject j, @paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (mpbwzMap == null) return new result(200, 0);
        String mp = j.getString("mp");
        JSONObject a = mpbwzMap.get(mp);
        if (a.getInteger("num") <= 0) return new result(200, 0);
        return new result(200, 1);
    }

    /**
     * 战斗结束后需要调用数量--
     */
    public void commitMonster(JSONObject j) {
        String monKey = j.getString("monsterKey");
        int num = j.getInteger("monsterNum");
        if (mpbwzMap == null || !monKey.contains("mpbwz_")) return;
        String mp = null;
        if (monKey.contains("_1")) mp = "mj";
        else if (monKey.contains("_2")) mp = "dj";
        else mp = "yyj";
        JSONObject a = mpbwzMap.get(mp);
        if (a.getInteger("num") < 0) return;

        int n = a.getInteger("num") - num;
        if (n < 0) n = 0;
        a.put("num", n);
        if (n == 0) {
            String str = null;
            int index = 0;
            if (mp.equals("mj")) {
                str = "墨家";
                index = 0;
            } else if (mp.equals("dj")) {
                str = "道家";
                index = 1;
            } else {
                str = "阴阳家";
                index = 2;
            }
            startBef.chatService.putSysMsg(str + "的妖魔已经被全部清除！");
            index++;
            if (index > 2) index = 0;
            String[] arr = {"mj", "dj", "yyj"};
            //重置
            setNowMp(arr[index]);
        }
    }

    /**
     * 当前轮到的门派
     */
    private void setNowMp(String mp) {
        for (String k : mpbwzMap.keySet()) {
            if (k.equals(mp)) {
                mpbwzMap.get(k).put("num", 6000);
            } else {
                mpbwzMap.get(k).put("num", 0);
            }
        }
        String str = null;
        if (mp.equals("mj")) str = "墨家";
        else if (mp.equals("dj")) str = "道家";
        else str = "阴阳家";
        startBef.chatService.putSysMsg("6000只妖魔正在" + str + "横行！");
    }

    private void initNum() {
        mpbwzMap = new ConcurrentHashMap<>();
        JSONObject a = new JSONObject();
        a.put("num", 0);//妖魔数量
        mpbwzMap.put("mj", a);
        a = new JSONObject();
        a.put("num", 0);//妖魔数量
        mpbwzMap.put("dj", a);
        a = new JSONObject();
        a.put("num", 0);//妖魔数量
        mpbwzMap.put("yyj", a);
    }

    public void endAc() {
        mpbwzMap = null;
        startBef.chatService.putSysMsg("门派保卫战结束！");
    }
}
