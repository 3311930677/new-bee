package my.fightUtils;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.dao.jsonMapper;
import my.data.monsterData;
import my.db.mybatisConfig;
import my.gameUtils.skillUtils;
import my.model.*;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Vector;
import java.util.concurrent.ConcurrentHashMap;

import static my.fightUtils.fightBuffHandUtils.*;
import static my.fightUtils.fightUtils.getRoleListOne;
import static my.model.skillItemRuleType.*;

public class fightUtils {
    //可还原战斗信息的缓存
    public static ConcurrentHashMap<String, JSONObject> resumeFightMap = new ConcurrentHashMap<>();
    //观战玩家 id-[name]
    public static ConcurrentHashMap<String, List<String>> viewFightMap = new ConcurrentHashMap<>();
    //缓存触发战斗的信息 战斗结束需要移除 由战斗id
    public static ConcurrentHashMap<String, JSONObject> fightMap = new ConcurrentHashMap<>();
    //缓存战斗中上传的指令 玩家指令，不包含怪物，怪物指令需要服务端生成 战斗结束需要移除
    public static ConcurrentHashMap<String, JSONObject> orderMap = new ConcurrentHashMap<>();
    //缓存战斗中触发的buff 战斗结束需要移除
    public static ConcurrentHashMap<String, Vector<buff>> buffMap = new ConcurrentHashMap<>();
    //战斗中生成的玩家战斗属性，战斗结束需要移除 {fightId,{posKey,attr}}
    public static ConcurrentHashMap<String, JSONObject> roleMap = new ConcurrentHashMap<>();
    //战斗中生成的怪物战斗属性，战斗结束需要移除 {fightId,{posKey,attr}}
    public static ConcurrentHashMap<String, JSONObject> monsterMap = new ConcurrentHashMap<>();
    //超时命令下达 当所有命令下达之后必须关闭
    public static ConcurrentHashMap<String, Long> overTimeOrderMap = new ConcurrentHashMap<>();
    //回合开始的map,记录延时调取回合开始
    public static ConcurrentHashMap<String, Long> huiheStartMap = new ConcurrentHashMap<>();
    //记录玩家一次战斗的伤害，战斗结束则移除
    public static ConcurrentHashMap<String, JSONObject> hurtMap = new ConcurrentHashMap<>();
    //一次动作是否正在执行中
    public static ConcurrentHashMap<String, Boolean> onceActionDoing = new ConcurrentHashMap<>();
    //技能冷却
    public static ConcurrentHashMap<String, Vector<skillCool>> skillCoolMap = new ConcurrentHashMap<>();
    //返回回合开始后3s进行自动战斗的检测
    public static ConcurrentHashMap<String, Long> autoFightTimeMap = new ConcurrentHashMap<>();
    //接收前端动画播放完成的指令
    public static ConcurrentHashMap<String, JSONObject> amPlayedOrderMap = new ConcurrentHashMap<>();

    /**
     * 获取真实的动作长度（因为反击、援护、连击这些是放在内部，要把它们也作为action一起算）
     */
    public static int getRealActionLen(List<action> list) {
        int len = list.size();
        for (int i = 0; i < list.size(); i++) {
            action ac = list.get(i);
            List<actionItem> items = ac.actionItems;
            if (items == null || items.size() == 0) continue;
            for (int j = 0; j < items.size(); j++) {
                actionItem item = items.get(j);
                if (item.statusType != null && (
                        (item.statusType == DiDangRule && item.helper != null) ||
                                item.statusType == LianJiRule ||
                                item.statusType == FanJiRule
                )) {
                    len++;
                }
            }
        }
        return len;
    }

    /**
     * 根据等级来增加难度
     */
    public static JSONObject addDifficulty(String key, JSONObject mon, JSONArray roleList, DefaultSqlSession con) {
        //判断是否需要增加难度
        if (key.contains("abyss_")) {
            int maxLv = getMaxLv(roleList);
            JSONObject prop = mon.getJSONObject("prop");
            for (String p : prop.keySet()) {
                prop.put(p, prop.getFloat(p) * maxLv * 0.01f);
            }
            //System.err.println(prop);
        } else if (key.contains("petxl_")) {
            int maxLv = getMaxLv(roleList);
            JSONObject prop = mon.getJSONObject("prop");
            for (String p : prop.keySet()) {
                prop.put(p, prop.getFloat(p) * (maxLv / 100f + 1));
            }
        } else if (key.contains("ztzs_")) {
            String[] ks = key.split("_");
            int index = Integer.parseInt(ks[1]);
            if (index == 7) return mon;
            int maxLv = getMaxLv(roleList);
            JSONObject prop = mon.getJSONObject("prop");
            for (String p : prop.keySet()) {
                prop.put(p, prop.getFloat(p) * maxLv * 0.1f);
            }
        }

        return mon;
    }

    /**
     * 获取玩家中最大等级
     */
    public static int getMaxLv(JSONArray roleList) {
        int maxLv = 0;
        for (Object a : roleList) {
            JSONObject r = (JSONObject) a;
            if (r.getInteger("type") == 0) {
                if (r.getInteger("lever") > maxLv)
                    maxLv = r.getInteger("lever");
            }
        }
        return maxLv;
    }

    /**
     * 放置ai
     * m战斗属性数值
     */
    public static void putAI(JSONArray temp, String monKey, String model, JSONObject m, String posKey, int quality, int goldType) {
        JSONObject obj = new JSONObject();
        obj.put("name", m.getString("name"));
        obj.put("key", monKey);
        obj.put("type", 4);
        obj.put("model", model);
        obj.put("posKey", posKey);
        obj.put("quality", quality);
        obj.put("isCatch", 0);
        obj.put("isDie", 0);
        JSONObject prop = m.getJSONObject("prop");
        JSONObject p = new JSONObject();
        p.put("xue", prop.getInteger("xue"));
        p.put("max_xue", prop.getInteger("max_xue"));
        p.put("lan", prop.getInteger("lan"));
        p.put("max_lan", prop.getInteger("max_lan"));
        obj.put("prop", p);

        obj.put("attr", m);

        obj.put("goldType", goldType);
        temp.add(obj);
    }

    /**
     * 自定义战斗数据
     */
    public static JSONObject createDefinedFightData(String name, int type, JSONObject prop, JSONArray skill) {
        JSONObject obj = new JSONObject();
        obj.put("name", name);
        obj.put("lever", 1);
        obj.put("type", type);//0物理1法术
        obj.put("prop", prop);
        //按职业、宠物分配技能
        obj.put("skill", skill);
        return obj;
    }

    /**
     * 获取一个roleMsg
     */
    public static JSONObject getRoleMsg(String name, int lv, String model,
                                        int type, String posKey, String clientId) {
        JSONObject msg = new JSONObject();
        msg.put("name", name);//显示的名字是nickName
        msg.put("lever", lv);
        msg.put("model", model);
        //0人物 1宠物 2怪物 4ai 5伙伴
        msg.put("type", type);
        msg.put("posKey", posKey);
        msg.put("clientId", clientId);
        msg.put("isTao", 0);
        msg.put("isDie", 0);
        return msg;
    }

    /**
     * 自定义一个怪物数据
     * type:0人物 1宠物 2怪物 4ai 5伙伴
     */
    public static void putDefinedMon(JSONArray temp, int isCatch, String monKey, JSONObject m, int i, int quality, int goldType) {
        JSONObject obj = new JSONObject();
        obj.put("name", m.getString("name"));
        obj.put("key", monKey);
        obj.put("type", 2);
        obj.put("model", m.getString("model"));
        obj.put("posKey", "l" + i);
        obj.put("quality", quality);
        obj.put("isCatch", isCatch);
        obj.put("isDie", 0);
        JSONObject prop = m.getJSONObject("prop");
        JSONObject p = new JSONObject();
        p.put("xue", prop.getInteger("xue"));
        p.put("max_xue", prop.getInteger("max_xue"));
        p.put("lan", prop.getInteger("lan"));
        p.put("max_lan", prop.getInteger("max_lan"));
        obj.put("prop", p);

        obj.put("attr", m);

        obj.put("goldType", goldType);
        temp.add(obj);
    }

    /**
     * 放置怪物
     */
    public static void putMonster(JSONArray temp, String monKey, int i, int quality, String projRootDir) {
        JSONObject m = monsterData.getMonsterByKey(monKey, projRootDir);
        JSONObject obj = new JSONObject();
        obj.put("name", m.getString("name"));
        obj.put("key", monKey);
        obj.put("type", 2);
        obj.put("model", m.getString("model"));
        obj.put("posKey", "l" + i);
        obj.put("quality", quality);
        obj.put("isCatch", 0);
        obj.put("isDie", 0);
        JSONObject prop = m.getJSONObject("prop");
        JSONObject p = new JSONObject();
        p.put("xue", prop.getInteger("xue"));
        p.put("max_xue", prop.getInteger("max_xue"));
        p.put("lan", prop.getInteger("lan"));
        p.put("max_lan", prop.getInteger("max_lan"));
        obj.put("prop", p);
        temp.add(obj);
    }

    /**
     * 战斗属性
     */
    public static JSONObject getAttrObj(float xue, float wg, float fg, float wf, float ff, float css, float mz, float sd, float bj) {
        JSONObject prop = new JSONObject();
        prop.put("max_xue", xue);
        prop.put("max_lan", 10000);
        prop.put("xue", xue);
        prop.put("lan", 10000);
        prop.put("wg", wg);
        prop.put("fg", fg);
        prop.put("wf", wf);//20->5000
        prop.put("ff", ff);
        prop.put("css", css);
        prop.put("mz", mz);
        prop.put("sd", sd);
        prop.put("bj", bj);
        return prop;
    }

    public static JSONObject getSkillObj(String key, int lv) {
        JSONObject j = new JSONObject();
        j.put("key", key);
        j.put("lv", lv);
        return j;
    }

    public static JSONArray getSkillList(JSONObject... skl) {
        JSONArray list = new JSONArray();
        for (JSONObject s : skl) {
            list.add(s);
        }
        return list;
    }

    /**
     * 判断是否为友方
     */
    public static boolean isMyFriend(String target, String control) {
        if (control.charAt(0) != target.charAt(0)) {
            return false;
        }
        return true;
    }

    /**
     * 判断技能目标是否为友方
     */
    public static boolean isMyFriend(JSONObject playerOrder) {
        JSONObject s = playerOrder.getJSONObject("skill");
        skill skl = skillUtils.getInstance().getSkill(s.getString("key"));
        for (skillItem item : skl.skillItems) {
            if (item.getTarget() == 2) {
                return false;
            }
        }
        return true;
    }

    /**
     * 筛选返回前端的buff重要属性
     */
    public static JSONArray filterBuffAttr(String id) {
        JSONArray buffs = new JSONArray();
        List<buff> list = buffMap.get(id);
        for (buff l : list) {
            JSONObject obj = new JSONObject();
            obj.put("key", l.key);
            obj.put("statusType", l.statusType);
            obj.put("target", l.target);
            obj.put("effectRule", l.effectRule);
            buffs.add(obj);
        }
        return buffs;
    }

    /**
     * 通知观战者播放战斗动作
     */
    public static void noticeViewFightPlayerAction(String id, List<action> list) {
        try {
            List<String> l = viewFightMap.get(id);
            if (l == null) return;
            for (String n : l) {
                ChannelSupervise.noticeClientByName(list, n, "3010");
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 通知观战者启用倒计时
     */
    public static void noticeViewFightPlayerDjs(String id, JSONObject obj) {
        try {
            List<String> l = viewFightMap.get(id);
            if (l == null) return;
            for (String n : l) {
                ChannelSupervise.noticeClientByName(obj, n, "3009");
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 通知观战者清理沙漏
     */
    public static void noticeViewFightPlayerClearShaLou(String id, JSONObject obj) {
        try {
            List<String> l = viewFightMap.get(id);
            if (l == null) return;
            for (String n : l) {
                ChannelSupervise.noticeClientByName(obj, n, "3011");
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 是否处于只允许生成一只怪物的场景
     */
    public static boolean isInOneMonsterMap(String name) {
        String[] maps = {
                "abyss", "blxt",
        };
        user u = staticCollection.getUserByName(name);
        String map = u.getPos().getString("map");
        for (String m : maps) {
            if (map.contains(m)) return true;
        }
        return false;
    }

    /**
     * 是否处于不允许捕捉的场景
     */
    public static boolean isInNoCatchMap(String name) {
        String[] maps = {
                "abyss", "cbd", "fb", "qlhd", "gangs", "hhbk", "dmkj",
        };
        user u = staticCollection.getUserByName(name);
        String map = u.getPos().getString("map");
        for (String m : maps) {
            if (map.contains(m)) return true;
        }
        return false;
    }

    /**
     * 由玩家民获取此刻正在进行的战斗
     */
    public static JSONObject getFightMsgByName(String name) {
        for (String k : fightMap.keySet()) {
            if (fightMap.get(k) == null) {
                continue;
            }
            JSONArray js = fightMap.get(k).getJSONArray("roleList");
            for (Object o : js) {
                JSONObject obj = (JSONObject) o;
                if (obj.getString("name").equals(name)) {
                    return fightMap.get(k);
                }
            }
        }
        return null;
    }

    /**
     * 是否为队长触发的战斗
     */
    public static boolean isCaptainTriggerFight(String name) {
        JSONObject team = startBef.teamService.getTeamByName(name);
        if (team == null || team.getString("captain").equals(name)) return true;
        return false;
    }

    /**
     * 是否存在队伍
     */
    public static boolean isInTeam(String name) {
        JSONObject team = startBef.teamService.getTeamByName(name);
        if (team == null) return false;
        return true;
    }

    /**
     * 获取一个战斗信息的基本结构
     */
    public static JSONObject getFightMsgStruct(int type, int isCatch, String npcKey,
                                               String taskKey, Integer progressIndex,
                                               JSONArray roleList, JSONArray monsterList) {
        JSONObject fightMsg = new JSONObject();
        fightMsg.put("isCatch", isCatch);
        fightMsg.put("npcKey", npcKey);
        fightMsg.put("taskKey", taskKey);
        fightMsg.put("progressIndex", progressIndex);
        fightMsg.put("type", type);
        fightMsg.put("roleList", roleList);
        fightMsg.put("monsterList", monsterList);
        return fightMsg;
    }

    public static JSONObject getFightMsgStruct(int type, int isCatch, JSONArray roleList, JSONArray monsterList) {
        return getFightMsgStruct(type, isCatch, null, null, null, roleList, monsterList);
    }

    public static JSONObject getFightMsgStruct(int type, int isCatch, JSONArray roleList) {
        return getFightMsgStruct(type, isCatch, null, null, null, roleList, new JSONArray());
    }

    /**
     * 是否允许战斗
     */
    public static boolean isAllowedFight(String name) {
        //战斗中或者不在线就不允许战斗
        if (isFighting(name) || !staticCollection.userIsOnline(name)) {
            return false;
        }
        return true;
    }

    public static boolean isAllowedFight(String name0, String name1) {
        if (isAllowedFight(name0) && isAllowedFight(name1)) {
            return true;
        }
        return false;
    }

    /**
     * 判断一个玩家是否在战斗中
     */
    private static boolean isFighting(String name) {
        synchronized (fightMap) {
            for (String k : fightMap.keySet()) {
                if (fightMap.get(k) == null) {
                    continue;
                }
                JSONArray js = fightMap.get(k).getJSONArray("roleList");
                for (Object o : js) {
                    JSONObject obj = (JSONObject) o;
                    if (obj.getString("name").equals(name)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    /**
     * 是否发生闪躲
     */
    public static boolean isSanDuo(String id, String control, String target) throws Exception {
        //判断是否存在必中buff
        if (isIgnoreAttr(id, control, "sd")) {
            return false;
        }
        //遍历提高闪避的buff
        JSONObject controlAttr = getAttrByPosKey(id, control);
        float mz = controlAttr.getJSONObject("prop").getFloat("mz");
        float mzZy = getObjFinalZy(id, control, "mz") + 1;
        //System.err.println("命中："+mz+" 命中增益："+mzZy+" 最终："+mz*mzZy);
        JSONObject targetAttr = getAttrByPosKey(id, target);
        float sd = targetAttr.getJSONObject("prop").getFloat("sd");
        float sdZy = getObjFinalZy(id, target, "sd") + 1;
        //命中概率
        float final_mz = mz * mzZy*0.5f < 1 ? 1 : mz * mzZy*0.5f;
        float final_sd = sd * sdZy < 1 ? 1 : sd * sdZy;
        float p = final_mz/final_sd;
        if(p>=1) p=0.99f;
        //是否发生命中
        boolean b = strUtils.isHappend(0, 1000, p);
        return !b;
    }

    /**
     * 是否发生暴击
     */
    public static boolean isBaoJi(String id, String control, String target) throws Exception {
        if (isInBuff(id, control, BiRanBaoJiRule)) {
            return true;
        }
        JSONObject controlAttr = getAttrByPosKey(id, control);
        float bj = controlAttr.getJSONObject("prop").getFloat("bj");
        float bjZy = getObjFinalZy(id, control, "bj") + 1;
        //增加暴击的buff
        buff bf = getBuffInStatusTypeByAttrName(id, control, 50, "bj");
        if (bf != null) {
            bjZy += bf.txRule.getVal(bf.lever, 0) * bf.getNowAddNum();
        }
        JSONObject targetAttr = getAttrByPosKey(id, target);
        float bjkx = 0;
        if (targetAttr.getJSONObject("prop").get("bjkx") != null) {
            bjkx = targetAttr.getJSONObject("prop").getFloat("bjkx");
        }
        float p = bj * bjZy / (3000 + bjkx) * 0.5f;
        //System.err.println("暴击概率："+p);
        return strUtils.isHappend(0, 100, p);
    }

    /**
     * 根据posKey获取方向
     * b true 同方向
     */
    public static String getDirection(String posKey, Boolean b) {
        if (b) {
            return posKey.substring(0, 1);
        }
        //返回反方向
        return posKey.contains("r") ? "l" : "r";
    }

    /**
     * 判断一个目标是否还有必要继续向下执行
     */
    public static boolean isBreak(String id, String posKey) {
        if (isTao(id, posKey) || isCatch(id, posKey) || isDie(id, posKey)) {
            return true;//中断执行
        }
        return false;
    }

    /**
     * 判断是否有客户端需要退出（只要人物退出，宠物也立即退出）
     */
    public static boolean isAllTao(String id, String posKey) {
        JSONObject one = getRoleListOne(id, posKey);
        //只要人物退出，宠物也立即退出
        if (one.getInteger("type") == 0) {
            return true;
        }
        return false;
    }

    /**
     * 由控制方站位获取宠物站位
     */
    public static JSONObject getPetByControl(String id, String controlPosKey) {
        JSONObject r = getRoleListOne(id, controlPosKey);
        if (r == null) return null;
        String name = r.getString("name");
        String clientId = r.getString("clientId");
        JSONObject fightMsg = fightMap.get(id);
        JSONArray list = fightMsg.getJSONArray("roleList");
        for (Object l : list) {
            JSONObject j = (JSONObject) l;
            if (j.getString("clientId").equals(clientId) &&
                    j.getString("name").equals(name + "_pet")) {
                return j;
            }
        }
        return null;

    }


    /**
     * 由站位获取玩家名字，非宠物
     * 只要返回null即不是玩家控制
     */
    public static String getRoleNameByRole(String Id, String posKey) {
        JSONObject r = getRoleListOne(Id, posKey);
        if (r == null) return null;
        return getRoleNameByRole(fightMap.get(Id), r);
    }

    public static String getRoleNameByRole(JSONObject fightMsg, JSONObject r) {
        return getRoleNameByType(r.getString("name"), r.getInteger("type"), isLunjianFight(fightMsg));
    }

    /**
     * 判断是否为论贱战斗
     */
    public static boolean isLunjianFight(JSONObject fightMsg) {

        if (fightMsg.getInteger("type") != 10 &&
                fightMsg.getInteger("type") != 11) {
            return false;
        } else {//官办论贱、个人论贱
            return true;
        }
    }

    /**
     * 对论贱战斗的名字取法
     */
    public static String getRoleNameByType(String n, int type, boolean isLunjian) {
        if (isLunjian) {
            if (n.length() > 2 && (n.charAt(n.length() - 1) + "").equals("a"))
                return n.substring(0, n.length() - 2);
            return null;
        }
        //判断是否为玩家
        if (type == 0) return n;
        return null;
    }

    /**
     * 由posKey获取roleList元素的信息
     */
    public static JSONObject getRoleListOne(String id, String posKey) {
        JSONObject fightMsg = fightMap.get(id);
        if (fightMsg == null) return null;
        JSONArray list = fightMsg.getJSONArray("roleList");
        for (Object l : list) {
            JSONObject j = (JSONObject) l;
            if (j.getString("posKey").equals(posKey)) {
                return j;
            }
        }
        return null;
    }

    /**
     * 获取所有玩家的站位
     */
    public static List<String> getRoleListOfPosKey(String id) {
        List<String> al = new ArrayList<>();
        JSONObject fightMsg = fightMap.get(id);
        JSONArray list = fightMsg.getJSONArray("roleList");
        for (Object l : list) {
            JSONObject j = (JSONObject) l;
            if (j.getInteger("type") == 0) {
                al.add(j.getString("posKey"));
            }
        }
        return al;
    }

    /**
     * 根据血量和逃跑情况获取一个有血、未逃跑的新目标
     */
    public static String getNewTarget(String id, String target) {
        try {
            //当目标血小于0时才会选取一个新的目标，否则返回原目标
            if (isDie(id, target) || isTao(id, target) || isCatch(id, target)) {
                return getTargetPosKeyByStr(id, target.substring(0, 1));
            }
        } catch (Exception e) {
            e.printStackTrace();
            loggerUtils.error("getNewTarget/target:" + target, fightUtils.class);
            try {
                throw new Exception(e);
            } catch (Exception e1) {
                e1.printStackTrace();
            }
        }
        return target;
    }

    /**
     * 根据站位设置该站位死亡状态
     */
    public static Integer isDieByPosKey(String id, String posKey) {
        int targetIsDie = 0;
        JSONObject targetAttr = getAttrByPosKey(id, posKey);
        if (targetAttr.getJSONObject("prop").getFloat("xue") <= 0) {
            targetAttr.getJSONObject("prop").put("xue", 0);
            targetIsDie = 1;
            //标记已经死亡
            setPlayerDie(id, posKey, 1);
        }
        return targetIsDie;
    }

    /**
     * 标记玩家及宠物逃跑
     */
    public static void setPlayerTao(String id, String posKey) {
        JSONObject fightMsg = fightMap.get(id);
        JSONObject target = getTargetByPosKey(id, posKey);
        String clientId = target.getString("clientId");
        JSONArray list = fightMsg.getJSONArray("roleList");
        for (Object l : list) {
            JSONObject j = (JSONObject) l;
            if (j.getString("clientId").equals(clientId)) {
                j.put("isTao", 1);
            }
        }
    }

    /**
     * 标记怪物已被捕捉
     */
    public static void setIsCatch(String id, String posKey) {
        JSONObject fightMsg = fightMap.get(id);
        JSONArray list = fightMsg.getJSONArray("monsterList");
        for (Object l : list) {
            JSONObject j = (JSONObject) l;
            if (j.getString("posKey").equals(posKey)) {
                j.put("isCatch", 1);
                break;
            }
        }
    }

    /**
     * 根据站位从roleList和monsterList获取一个站位对象
     */
    private static JSONObject getOnePlayerFromFightMsg(String id, String posKey) {
        JSONObject fightMsg = fightMap.get(id);
        JSONArray list = fightMsg.getJSONArray("roleList");
        for (Object l : list) {
            JSONObject j = (JSONObject) l;
            if (j.getString("posKey").equals(posKey)) {
                return j;
            }
        }
        list = fightMsg.getJSONArray("monsterList");
        for (Object l : list) {
            JSONObject j = (JSONObject) l;
            if (j.getString("posKey").equals(posKey)) {
                return j;
            }
        }
        return null;
    }

    /**
     * 标记玩家已死亡
     */
    public static void setPlayerDie(String id, String posKey, Integer status) {

        JSONObject a = getOnePlayerFromFightMsg(id, posKey);
        a.put("isDie", status);
    }

    /**
     * 通过r\l重新选举一个有血量、没有逃跑的目标站位
     */
    public static String getTargetPosKeyByStr(String id, String str) {
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String posKey = t.getString("posKey");
            if (posKey.contains(str)) {
                if (!isDie(id, posKey) && !isTao(id, posKey) && !isCatch(id, posKey)) {
                    return t.getString("posKey");
                }
            }
        }
        return null;
    }

    /**
     * 获取一个队友站位
     */
    public static String getNoSelfTargetPosKey(String id, String posKey) {
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String pk = t.getString("posKey");
            if (pk.contains(posKey.charAt(0) + "") && !pk.equals(posKey)) {
                if (!isDie(id, pk) && !isTao(id, pk) && !isCatch(id, pk)) {
                    return pk;
                }
            }
        }
        return null;
    }

    /**
     * 获取一个友方死亡的站位
     */
    public static String getDiePosByPosKey(String id, String posKey) {
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String pk = t.getString("posKey");
            if (pk.contains(posKey.charAt(0) + "") && !pk.equals(posKey)) {
                if (isDie(id, pk)) {
                    return pk;
                }
            }
        }
        return null;
    }

    /**
     * 判断队友是否生命值低于30%
     */
    public static boolean isNeedXue(String id, String posKey) {
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String pk = t.getString("posKey");
            if (pk.contains(posKey.charAt(0) + "") && !pk.equals(posKey)) {
                JSONObject prop = t.getJSONObject("prop");
                if (prop.getInteger("xue") > 0 && prop.getInteger("xue") < prop.getInteger("max_xue") * 0.3) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * 由站位获取目标对象
     */
    public static JSONObject getTargetByPosKey(String id, String posKey) {
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            if (t.getString("posKey").equals(posKey)) {
                return t;
            }
        }
        return null;
    }


    /**
     * 判断一个站位是否逃跑
     */
    public static boolean isTao(String id, String posKey) {
        JSONObject obj = getTargetByPosKey(id, posKey);
        if (obj == null) return true;
        //怪物没有逃
        if (obj.getInteger("isTao") == null) return false;
        if (obj != null && obj.getInteger("isTao") == 1) {
            return true;
        }
        return false;
    }

    /**
     * 判断一个站位是否被捕捉了
     */
    public static boolean isCatch(String id, String posKey) {
        JSONObject obj = getTargetByPosKey(id, posKey);
        //注意：当逃跑后会直接删除其数据，所以obj会为null
        if (obj == null) return true;
        //只有怪物数据才有isCatch，对于人物数据直接返回false
        if (obj.getInteger("isCatch") == null) return false;
        if (obj != null && obj.getInteger("isCatch") == 1) {
            return true;
        }
        return false;
    }

    /**
     * 由key获取技能
     */
    public static JSONObject getSkill(String id, String control, String key) {
        JSONArray skls = getSkills(id, control);
        for (Object o : skls) {
            JSONObject obj = (JSONObject) o;
            if (obj.getString("key").equals(key)) {
                return obj;
            }
        }
        return null;
    }

    /**
     * 获取技能项
     */
    public static skillItem getSkillItem(String key, int i) {
        skill skl = skillUtils.getInstance().getSkill(key);
        return skl.skillItems.get(i);
    }

    /**
     * 判断是否死亡
     */
    public static boolean isDie(String id, String posKey) {
        JSONObject obj = getTargetByPosKey(id, posKey);
        //注意：当逃跑后会直接删除其数据，所以obj会为null
        if (obj == null) return true;
        if (obj != null && obj.getInteger("isDie") == 1) {
            return true;
        }
        return false;
    }

    /**
     * 寻找一个已经死亡的目标
     */
    public static String getOneIsDiePosKey(String id, String rOrl) {
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            if (t != null && t.getString("posKey").contains(rOrl) &&
                    t.getInteger("isDie") == 1) {
                return t.getString("posKey");
            }
        }
        return null;
    }

    /**
     * 获取一个处于某状态的目标
     */
    public static String getOneIsInBuffPosKey(String id, String rOrl, int statusType) {
        List<String> arr = new ArrayList<>();
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            if (t != null && t.getString("posKey").contains(rOrl) &&
                    t.getInteger("isDie") != 1 &&
                    isInBuff(id, t.getString("posKey"), statusType)) {
                arr.add(t.getString("posKey"));
            }
        }
        if (arr.size() == 0) return null;
        Collections.shuffle(arr);
        return arr.get(0);
    }

    /**
     * 寻找一个低血量的目标
     */
    public static String getOneIsLowXuePosKey(String id, String rOrl) {
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            if (t != null && t.getString("posKey").contains(rOrl) &&
                    t.getInteger("isDie") != 1) {
                JSONObject attr = getPlayerOrMonsterAttrByKey(id, t.getString("posKey"));
                //血量小于50%
                if (attr.getJSONObject("prop").getFloat("xue") > 0
                        && attr.getJSONObject("prop").getFloat("xue") <
                        attr.getJSONObject("prop").getFloat("max_xue") * 0.5f) {
                    return t.getString("posKey");
                }
            }
        }
        return null;
    }

    /**
     * 获取某一方未死玩家数量
     */
    public static int getNoDieNum(String id, String rOrl) {
        int num = 0;
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            if (t != null && t.getString("posKey").contains(rOrl) &&
                    t.getInteger("isDie") != 1) {
                num++;
            }
        }
        return num;
    }


    /**
     * 判断某一方所有血量是否为0
     * i 0左边 1右边
     */
    public static boolean isZero(String id, int i) {
        String str = "l";
        if (i == 1) {
            str = "r";
        }
        int sum = 0;
        int num = 0;
        //第一遍先算出总数量
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String posKey = t.getString("posKey");
            if (posKey.contains(str)) {
                if (isDie(id, posKey) || isTao(id, posKey) || isCatch(id, posKey)) {
                    num++;
                }
                sum++;
            }
        }
        //todo 当角色标记逃跑，宠物也必须标记
        //判断数量是否一致
        if (num == sum) {
            return true;
        }
        return false;
    }

    /**
     * 按排或列选举
     * isA是否按 排 选举
     */
    public static Vector<String> getPosKeysByAOrB(String id, String posKey, int num, boolean isA) {
        Vector<String> list = new Vector<>();
        if (num <= 0) return list;
        String str = "l";
        if (posKey.contains("r")) {
            str = "r";
        }
        int sum = 0;
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String targetPosKey = t.getString("posKey");
            //对于此状态下的都不需要获取
            if (isBreak(id, targetPosKey)) {
                continue;
            }
            if (!targetPosKey.equals(posKey) && targetPosKey.contains(str)) {
                if (isA) {//排 0-4 5-9
                    int n1 = Integer.parseInt(posKey.substring(1));
                    int n2 = Integer.parseInt(targetPosKey.substring(1));
                    if ((n1 < 5 && n2 < 5) || (n1 >= 5 && n2 >= 5)) {
                        list.add(targetPosKey);
                        sum++;
                    }
                } else {//列
                    /**由站位获取模型位置
                     * 站位 共20个位置
                     * 14 9 4 19
                     * 12 7 2 17
                     * 10 5 0 15
                     * 11 6 1 16
                     * 13 8 3 18
                     */
                    String a = posKey.charAt(1) + "" + targetPosKey.charAt(1);
                    if (a.equals("05") || a.equals("50") ||
                            a.equals("16") || a.equals("61") ||
                            a.equals("27") || a.equals("72") ||
                            a.equals("38") || a.equals("83") ||
                            a.equals("49") || a.equals("94")) {
                        list.add(targetPosKey);
                        sum++;
                    }
                }

                if (sum == num) {
                    break;
                }
            }
        }
        return list;
    }

    /**
     * 获取除自己外的站位
     */
    public static Vector<String> getPosKeysByNumRemSelf(String id, String posKey, int num) {
        Vector<String> list = new Vector<>();
        if (num <= 0) return list;
        int sum = 0;
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String targetPosKey = t.getString("posKey");
            //对于此状态下的都不需要获取
            if (isDie(id, targetPosKey) || isTao(id, targetPosKey) || isCatch(id, targetPosKey)) {
                continue;
            }
            if (!targetPosKey.equals(posKey)) {
                list.add(targetPosKey);
                sum++;
                if (sum == num) {
                    break;
                }
            }
        }
        return list;
    }
    /**
     * 取某一方的站位集
     */
    public static Vector<String> getLeftOrRightPosKeysByNum(String id, String lOrR, int num) {
        Vector<String> list = new Vector<>();
        if (num <= 0) return list;
        String str = "l";
        if (lOrR.contains("r")) {
            str = "r";
        }
        int sum = 0;
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String targetPosKey = t.getString("posKey");
            //对于此状态下的都不需要获取
            if (isDie(id, targetPosKey) || isTao(id, targetPosKey) || isCatch(id, targetPosKey)) {
                continue;
            }
            if (targetPosKey.contains(str)) {
                list.add(targetPosKey);
                sum++;
                if (sum == num) {
                    break;
                }
            }
        }
        return list;
    }
    /**
     * 由数量获取某一方的站位集
     */
    public static Vector<String> getPosKeysByNum(String id, String posKey, int num) {
        Vector<String> list = new Vector<>();
        if (num <= 0) return list;
        String str = "l";
        if (posKey.contains("r")) {
            str = "r";
        }
        int sum = 0;
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String targetPosKey = t.getString("posKey");
            //对于此状态下的都不需要获取
            if (isDie(id, targetPosKey) || isTao(id, targetPosKey) || isCatch(id, targetPosKey)) {
                continue;
            }
            if (!targetPosKey.equals(posKey) && targetPosKey.contains(str)) {
                list.add(targetPosKey);
                sum++;
                if (sum == num) {
                    break;
                }
            }
        }
        return list;
    }

    /**
     * 随机取某方的一个站位
     */
    public static Vector<String> getPosKeysByRandom(String id, String posKey, int limitNum) {
        Vector<String> list = new Vector<>();
        String str = "l";
        if (posKey.contains("r")) {
            str = "r";
        }
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String targetPosKey = t.getString("posKey");
            //对于此状态下的都不需要获取
            if (isDie(id, targetPosKey) || isTao(id, targetPosKey) || isCatch(id, targetPosKey)) {
                continue;
            }
            if (targetPosKey.contains(str)) {
                list.add(targetPosKey);
            }
        }
        if (list.size() > limitNum) {
            Collections.shuffle(list);
            list = new Vector<>(list.subList(0, limitNum));
        }
        return list;
    }

    /**
     * 将要恢复的数据重新放入战斗相关信息中
     */
    public static void resumeDataToFight(String id) {
        JSONObject re = resumeFightMap.get(id);
        fightMap.put(id, re.getJSONObject("fightMap"));
        roleMap.put(id, re.getJSONObject("roleMap"));
        orderMap.put(id, re.getJSONObject("orderMap"));
        monsterMap.put(id, re.getJSONObject("monsterMap"));
        buffMap.put(id, (Vector<buff>) re.get("buffMap"));
        //overTimeOrderMap.put(id, re.getLong("overTimeOrderMap"));
        //huiheStartMap.put(id, re.getLong("huiheStartMap"));
        hurtMap.put(id, re.getJSONObject("hurtMap"));
        onceActionDoing.put(id, re.getBoolean("onceActionDoing"));
        skillCoolMap.put(id, (Vector<skillCool>) re.get("skillCoolMap"));
        viewFightMap.put(id, (List<String>) re.get("viewFightMap"));

        resumeFightMap.remove(id);
    }

    /**
     * 复制所有战斗相关的信息进行缓存
     */
    public static void copyFightMsgToCache(String id) {
        JSONObject msg = new JSONObject();
        msg.put("fightMap", staticCollection.copyObj(fightMap.get(id)));
        msg.put("roleMap", staticCollection.copyObj(roleMap.get(id)));
        msg.put("orderMap", staticCollection.copyObj(orderMap.get(id)));
        msg.put("monsterMap", staticCollection.copyObj(monsterMap.get(id)));
        msg.put("buffMap", new Vector<>(buffMap.get(id)));
        //msg.put("overTimeOrderMap", overTimeOrderMap.get(id).longValue());
        //msg.put("huiheStartMap", huiheStartMap.get(id).longValue());
        msg.put("hurtMap", staticCollection.copyObj(hurtMap.get(id)));
        msg.put("onceActionDoing", onceActionDoing.get(id).booleanValue());
        msg.put("skillCoolMap", new Vector<>(skillCoolMap.get(id)));
        msg.put("viewFightMap", new ArrayList<>(viewFightMap.get(id)));
        resumeFightMap.put(id, msg);
    }

    /**
     * 清空缓存
     */
    public static void empty(String id) {
        fightMap.remove(id);
        roleMap.remove(id);
        orderMap.remove(id);
        monsterMap.remove(id);
        buffMap.remove(id);
        overTimeOrderMap.remove(id);
        huiheStartMap.remove(id);
        hurtMap.remove(id);
        onceActionDoing.remove(id);
        skillCoolMap.remove(id);
        viewFightMap.remove(id);
        //移除动画播放完毕的指令
        amPlayedOrderMap.remove(id);
        //loggerUtils.info("战斗" + id + "被清理！", fightController.class);
    }

    /**
     * 判断是否还有角色存活（不包括宠物）
     */
    public static boolean isPlayerExist(String id) {
        if (isDie(id, "r0") && isDie(id, "r1") && isDie(id, "r1")) {
            return false;
        }
        return true;
    }

    /**
     * 由站位获取一个怪物
     */
    public static JSONObject getOneMonsterByPosKey(String id, String posKey) {
        return monsterMap.get(id).getJSONObject(posKey);
    }

    /**
     * 随机获取一个敌方目标
     */
    public static String getRandomTarget(String id, String str) {
        JSONArray arr = new JSONArray();
        JSONArray playerList = getMonsterAndPlayer(id);
        for (Object o : playerList) {
            JSONObject t = (JSONObject) o;
            String posKey = t.getString("posKey");
            if (posKey.contains(str)) {
                if (!isDie(id, posKey) && !isTao(id, posKey) && !isCatch(id, posKey)) {
                    arr.add(posKey);
                }
            }
        }
        if (arr.size() > 0) {
            //随机一个
            int i = strUtils.getRandom(0, arr.size());
            return arr.getString(i);
        }
        return null;
    }

    /**
     * 按css排序
     */
    public static Vector<String> orderByCss(String id) {
        JSONArray playerList = getMonsterAndPlayer(id);
        //第一遍选出最大值，第二遍选第二大的值。。。
        Vector<String> posKeys = new Vector<>();
        for (int i = 0; i < playerList.size(); i++) {
            //外层循环，遍历次数
            for (int j = 0; j < playerList.size() - i - 1; j++) {
                //内层循环，升序（如果前一个值比后一个值大，则交换）
                //内层循环一次，获取一个最大值
                JSONObject t0 = (JSONObject) playerList.get(j);
                JSONObject playerAttr0 = getAttrByPosKey(id, t0.getString("posKey"));
                JSONObject t1 = (JSONObject) playerList.get(j + 1);
                JSONObject playerAttr1 = getAttrByPosKey(id, t1.getString("posKey"));
                //System.out.println(playerAttr0+"\n"+playerAttr1);
                if (playerAttr0.getJSONObject("prop").getFloat("css") - playerAttr1.getJSONObject("prop").getFloat("css") < 0) {
                    Object temp = playerList.get(j + 1);
                    playerList.remove(j + 1);
                    playerList.add(j + 1, playerList.get(j));
                    playerList.remove(j);
                    playerList.add(j, temp);
                }
            }
        }
        for (Object r : playerList) {
            posKeys.add(((JSONObject) r).getString("posKey"));
        }
        //System.err.println("排序：" + posKeys);
        return posKeys;
    }

    /**
     * 获取技能等级
     */
    public static int getSkillLv(String id, String posKey, String skillKey) {
        JSONArray sklList = getSkills(id, posKey);
        for (Object s : sklList) {
            JSONObject ss = (JSONObject) s;
            if (ss.getString("key").equals(skillKey)) {
                return ss.getInteger("lv");
            }
        }
        return 1;
    }

    /**
     * 获取某个站位身上携带的技能
     */
    public static JSONArray getSkills(String id, String control) {
        JSONObject attr = getAttrByPosKey(id, control);
        JSONArray sklList = attr.getJSONArray("skill");
        return sklList;
    }

    /**
     * 由站位获取战斗属性（注意：这里不是复制数据，是取战斗真实的数据）
     */
    public static JSONObject getAttrByPosKey(String id, String posKey) {
        return getPlayerOrMonsterAttrByKey(id, posKey);
    }

    /**
     * 是否属于玩家方（非怪物）
     */
    public static boolean isPlayerType(int type) {
        //0人物 1宠物 4ai 5伙伴
        if (type == 0 || type == 1 || type == 4 || type == 5) return true;
        //2是怪物
        return false;
    }

    /**
     * 获取玩家和怪物合成后的数组
     *
     * @return
     */
    public static JSONArray getMonsterAndPlayer(String id) {
        JSONObject fightMsg = fightMap.get(id);
        JSONArray list = new JSONArray();
        //必须得复制一份新的，json操作的是原对象
        list.fluentAddAll(fightMsg.getJSONArray("monsterList"));
        list.fluentAddAll(fightMsg.getJSONArray("roleList"));
        return list;
    }

    /**
     * 获取内存中真实的目标，而不是复制的
     */
    /*public static JSONObject getRealTargetFromMem(String id, String posKey) {
        JSONObject fightMsg = fightMap.get(id);
        JSONArray rs = fightMsg.getJSONArray("roleList");
        JSONArray mons = fightMsg.getJSONArray("monsterList");
        for (Object o : rs) {
            JSONObject r = (JSONObject) o;
            if (r.getString("posKey").equals(posKey)) {
                return roleMap.get(id).getJSONObject(posKey);
            }
        }
        for (Object o : mons) {
            JSONObject r = (JSONObject) o;
            if (r.getString("posKey").equals(posKey)) {
                return monsterMap.get(id).getJSONObject(posKey);
            }
        }
        return null;
    }*/

    /**
     * 获取未逃跑的玩家
     */
    public static JSONArray getNoTaoPlayer(String id) {
        JSONArray array = new JSONArray();
        JSONObject fightMsg = fightMap.get(id);
        JSONArray playerList = fightMsg.getJSONArray("roleList");
        for (Object m : playerList) {
            JSONObject j = (JSONObject) m;
            //既不是ai又不是伙伴
            if (j.getInteger("type") != 4 && j.getInteger("type") != 5
                    && j.getInteger("isTao") != 1) {
                array.add(j);
            }
        }
        return array;
    }

    /**
     * 是否所有动画播放完成命令都接收完毕
     */
    public static boolean isAmPlayedOrderRecDone(String id, JSONObject order) {
        int num = 0;
        JSONObject fightMsg = fightMap.get(id);
        JSONArray playerList = fightMsg.getJSONArray("roleList");
        for (Object m : playerList) {
            JSONObject j = (JSONObject) m;
            if (j.getInteger("type") == 0
                    && j.getInteger("isTao") != 1) {
                num++;
            }
        }
        if (order.keySet().size() == num) return true;
        return false;
    }

    /**
     * 获取所有有血的玩家和怪物
     */
    public static JSONArray getNoZeroPlayerAndMonster(String id) {
        JSONArray array = new JSONArray();
        JSONObject fightMsg = fightMap.get(id);
        JSONArray monsterList = fightMsg.getJSONArray("monsterList");
        JSONArray playerList = fightMsg.getJSONArray("roleList");
        for (Object m : monsterList) {
            JSONObject j = (JSONObject) m;
            JSONObject attr = getPlayerOrMonsterAttrByKey(id, j.getString("posKey"));
            //血量大于0且没有被捕捉
            if (attr.getJSONObject("prop").getFloat("xue") > 0 && j.getInteger("isCatch") != 1) {
                array.add(j);
            }
        }
        for (Object m : playerList) {
            JSONObject j = (JSONObject) m;
            JSONObject attr = getPlayerOrMonsterAttrByKey(id, j.getString("posKey"));
            if (j.getInteger("isTao") != 1 &&
                    attr.getJSONObject("prop").getFloat("xue") > 0) {
                array.add(j);
            }
        }
        return array;
    }

    /**
     * 由站位获取下达的命令
     * {id,posKey:{action,control,target}}
     */
    public static JSONObject getOrderByPosKey(String id, String posKey) {
        return orderMap.get(id).getJSONObject(posKey);
    }

    /**
     * 由posKey获取某个怪物战斗属性
     *
     * @param posKey
     * @return {type,prop}
     */
    private static JSONObject getMonsterAttrByKey(String fightId, String posKey) {
        return monsterMap.get(fightId).getJSONObject(posKey);
    }

    /**
     * 由name、fightId获取玩家战斗属性
     *
     * @return {type,prop}
     */
    private static JSONObject getPlayerAttrByKey(String fightId, String posKey) {
        return roleMap.get(fightId).getJSONObject(posKey);
    }

    public static JSONObject getPlayerOrMonsterAttrByKey(String fightId, String posKey) {
        JSONObject attr = getPlayerAttrByKey(fightId, posKey);
        if (attr != null) return attr;
        return getMonsterAttrByKey(fightId, posKey);
    }
}
