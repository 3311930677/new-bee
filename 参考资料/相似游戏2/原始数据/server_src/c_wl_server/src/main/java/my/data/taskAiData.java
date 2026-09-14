package my.data;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.fightUtils.fightUtils;

public class taskAiData {
    /**
     * 由任务key获取ai伙伴
     */
    public static void addAiGayByTask(String taskKey, int progressIndex, JSONArray members) {
        if (taskKey.equals("1018") || taskKey.equals("1019") || taskKey.equals("1020") ||
                taskKey.equals("1021") || taskKey.equals("1022")) {
            if (progressIndex == 0) {
                //todo:客户端type=4类的model需要改成可加载2000等的model
                addToMembers("宫主", 100, "tianbing", members);
                addToMembers("白供奉", 100, "tianbing", members);
                addToMembers("黑供奉", 100, "tianbing", members);
            }
        }

    }

    /**
     * 添加任务战斗的ai辅助数据
     */
    private static void addToMembers(String name, int lv, String model, JSONArray members) {
        String posKey = getNoExistPosKey(members);
        if (posKey != null) {
            JSONObject obj = fightUtils.getRoleMsg(name, lv, model, 4, posKey, null);
            members.add(obj);
        }
    }

    /**
     * 获取不存在的站位
     */
    private static String getNoExistPosKey(JSONArray members) {
        for (int i = 0; i < 10; i++) {
            boolean b = false;
            for (Object o : members) {
                JSONObject m = (JSONObject) o;
                if ((m.getString("posKey")).equals("r" + i)) {
                    b = true;
                }
            }
            if (!b) return "r" + i;
        }
        return null;
    }
}
