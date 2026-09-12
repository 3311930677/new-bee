package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.gangsMapper;
import my.dao.jsonMapper;
import my.dao.roleMapper;
import my.data.*;
import my.db.mybatisConfig;
import my.fightUtils.fightUtils;
import my.gameUtils.roleUtils;
import my.gameUtils.sysSettingUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.service.fight.orderHandle;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import static my.fightUtils.fightUtils.*;
import static my.utils.staticCollection.teamMap;

/**
 * 战斗外部接口调用
 */
public class fightRpcService {

    /**
     * 血腥之地
     */
    public Integer createFightByXXZD(String name, String playerName, DefaultSqlSession con) {
        //处于战斗中就不允许创建
        if (!isAllowedFight(name)) {
            return 0;
        }
        if (!isAllowedFight(playerName)) {
            return 0;
        }

        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        msgPutRoleListByFormation(false, roleList, playerName, "l", con);
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(23, 0, roleList);


        toFight(fightMsg, staticCollection.getUserByName(name));
        return 1;
    }


    /**
     * 攻击魔尊
     */
    public result attackMozun(@paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        roleMapper dao = mybatisConfig.getMapper(con, roleMapper.class);
        List<JSONObject> list = dao.findMzzd(name);
        if (list.size() == 0) return new result(0);
        int mzzd = list.get(0).getInteger("mzzd");
        if (mzzd == 1) return new result(0);
        dao.updateMzzd(name, "1");
        //触发boss战斗
        startBef.fightRpcService.createFightByMozun(name, con);
        return new result(200, 1);
    }

    /**
     * 魔尊战斗
     */
    public Integer createFightByMozun(String name, DefaultSqlSession con) {
        if (!isAllowedFight(name)) {
            return 0;
        }
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(true, roleList, name, "r", con);
        //被攻击方
        JSONArray monsterList = new JSONArray();
        putMonster(monsterList, "mozun_boss", 0, 4, staticCollection.getProjRootDirByName(name));
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(1, 0, roleList, monsterList);

        toFight(fightMsg, staticCollection.getUserByName(name));
        return 1;
    }

    public void mozunFightOverHandle(int win, JSONObject data) {
        /*String name = data.getJSONArray("names").getString(0);
        staticCollection.putTask(() -> {
            //跳转到一图
            ChannelSupervise.noticeClientByName("m_1", name, "830");
        }, 10, TimeUnit.SECONDS);*/
    }

    /**
     * 重载战斗
     */
    public void reloadFight(String name) {
        JSONObject fightMsg = startBef.fightService.isFightingToMsg(name);
        if (fightMsg != null) {
            //通知唤醒战斗
            //延时才行，为了让客户端组件创建完成
            try {
                Thread.sleep(3000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            ChannelSupervise.noticeClientByName(fightMsg.getString("Id"), name, "900");
            //要变成自动
            sysSettingUtils.setAutoFight(name, 1);
        }
    }

    /**
     * 退出观战
     */
    public result closeViewFight(JSONObject j,
                                 @paramsAnno(key = "user") user user) {
        final String name = user.name;
        String Id = j.getString("Id");
        List<String> list = fightUtils.viewFightMap.get(Id);
        if (list != null) {
            for (String n : list) {
                if (n.equals(name)) {
                    list.remove(n);
                    break;
                }
            }
        }
        return new result(200, 1);
    }

    /**
     * 观看战斗
     */
    public result viewFight(JSONObject j,
                            @paramsAnno(key = "user") user user) {
        final String name = user.name;
        String playerName = j.getString("playerName");
        JSONObject fm = startBef.fightService.isFightingToMsg(playerName);
        if (fm == null) {
            return new result(200, 0);
        }
        fightUtils.viewFightMap.get(fm.getString("Id")).add(name);
        return new result(200, fm);
    }

    /**
     * 境界心魔(单人)
     */
    public result createFightByXinMo(@paramsAnno(key = "user") user user,
                                     @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (!isAllowedFight(name)) {
            return new result(0);
        }
        //判断当前心魔是否已经被击败
        if (user.msg.getInteger("lever") < 100)
            return new result(915);
        JSONObject msg = startBef.manService.getMsgData(name, con);
        int realmLv = msg.getInteger("realmLv");
        if (realmLv >= 10) return new result(0);

        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getXinMo(name);
        if (list.size() == 0) {
            activityMapper.addXinMo(name);
            list = activityMapper.getXinMo(name);
        }
        if (list.get(0).getInteger("lv") != realmLv)
            return new result(917);

        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        JSONArray monsterList = new JSONArray();
        String monName = "心魔";
        String model = "sanguo81_1";
        String monKey = "jjxm_0";
        int attackType = 0;
        JSONArray skills = getSkillList(
                getSkillObj("3047", 1), getSkillObj("3072", 1)
        );
        int lv = realmLv;
        float xue = 50000 * (1 + lv / 10f), wg = 10000 * (1 + lv / 20f), fg = 10000 * (1 + lv / 20f),
                wf = 500 * (1 + lv / 20f), ff = 500 * (1 + lv / 20f), css = 1000 * (1 + lv / 20f),
                mz = 5000 * (1 + lv / 100f), sd = 50 * (1 + lv / 20f), bj = 1000 * (1 + lv / 20f);
        /*float xue = 1, wg = 1, fg = 1,
                wf = 1, ff = 1, css = 1,
                mz = 1, sd = 1, bj = 1;*/
        JSONObject prop = getAttrObj(xue, wg, fg, wf, ff, css, mz, sd, bj);
        JSONObject m = createDefinedFightData(monName, attackType, prop, skills);
        m.put("model", model);
        putDefinedMon(monsterList, 0, monKey, m, 0, 4, 0);
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(21, 0, roleList, monsterList);
        toFight(fightMsg, user);
        return new result(200, 1);
    }

    /**
     * 魔神降临
     */
    public result createFightByMSJL(String key, String playerName, user user, DefaultSqlSession con) {
        final String name = user.name;
        if (!isAllowedFight(name)) {
            return new result(200, 0);
        }
        //队伍
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        JSONArray monsterList = new JSONArray();
        if (playerName == null) {
            String a0 = "赵谦孙俪周五正文乾坤教干";
            String a1 = "流破风";
            String[] arr = key.split("-");
            String monName = "魔神-" + a0.charAt(Integer.parseInt(arr[1]) - 1) + a1.charAt(Integer.parseInt(arr[2]) - 1);
            String monKey = "msjl_" + arr[1] + "_" + arr[2];
            String model = "sanguo" + (Integer.parseInt(arr[1]) + Integer.parseInt(arr[2]) + 12) + "_1";

            int attackType = 0;
            JSONArray skills = getSkillList(
                    getSkillObj("3047", 1), getSkillObj("3072", 1)
            );
            int lv = Integer.parseInt(arr[1]);
            float xue = 50000 * (1 + lv / 10f), wg = 10000 * (1 + lv / 20f), fg = 10000 * (1 + lv / 20f),
                    wf = 500 * (1 + lv / 20f), ff = 500 * (1 + lv / 20f), css = 1000 * (1 + lv / 20f),
                    mz = 5000 * (1 + lv / 100f), sd = 50 * (1 + lv / 20f), bj = 1000 * (1 + lv / 20f);
            /*float xue = 100000, wg = 1, fg = 1,
                    wf = 1, ff = 1, css = 1,
                    mz = 1, sd = 1, bj = 1;*/
            JSONObject prop = getAttrObj(xue, wg, fg, wf, ff, css, mz, sd, bj);
            JSONObject m = createDefinedFightData(monName, attackType, prop, skills);
            m.put("model", model);
            putDefinedMon(monsterList, 0, monKey, m, 0, 4, 0);
            //构造战斗信息
            JSONObject fightMsg = getFightMsgStruct(20, 0, roleList, monsterList);
            JSONObject params = new JSONObject();
            params.put("playerName", playerName);//用于战斗结束后判断是玩家战斗还是怪物战斗
            params.put("key", key);//用于战斗结束后重置map
            fightMsg.put("params", params);
            toFight(fightMsg, user);
        } else {
            //跟玩家战斗
            //将玩家的战斗信息进行缓存
            JSONObject fg = startBef.fightService.isFightingToMsg(playerName);
            if (fg == null) return new result(0);
            fightUtils.copyFightMsgToCache(fg.getString("Id"));
            //清除原先的战斗
            fightUtils.empty(fg.getString("Id"));
            //todo:触发抢夺战斗并通知玩家结束当前战斗
            //被攻击方
            msgPutRoleListByFormation(false, roleList, playerName, "l", con);
            //构造战斗信息
            JSONObject fightMsg = getFightMsgStruct(20, 0, roleList);
            JSONObject params = new JSONObject();
            params.put("playerName", playerName);//用于战斗结束后判断是玩家战斗还是怪物战斗
            params.put("key", key);//用于战斗结束后重置map
            params.put("resumeId", fg.getString("Id"));//用于战斗结束后恢复之前的战斗
            fightMsg.put("params", params);
            toFight(fightMsg, user);
            //ChannelSupervise.noticeClientByName();
            //如果被抢夺了就会删除之前缓存的战斗信息，没被抢夺成功则将缓存信息取出，继续战斗
        }


        return new result(200, 1);
    }



    /**
     * 百炼妖塔
     */
    public result createFightBLYT(int lever, user user, DefaultSqlSession con) {
        final String name = user.name;
        if (!isAllowedFight(name)) {
            return new result(200, 0);
        }
        //队伍
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        int lv = lever;
        JSONArray monsterList = new JSONArray();
        String[] arr = {
                "离火剑", "散瘟鞭", "落宝金钱", "列瘟印", "紫金铃", "撞心杵", "风火轮", "酱油瓶", "乾坤针", "斩仙飞刀",
                "风袋", "梅花镖", "六根清净竹", "雾露乾坤网", "戳目珠", "照妖鉴", "长生根", "伤不旗", "逆鳞枪", "宝莲灯",
                "万里起云烟", "钻心钉", "万鸦壶", "紫金钵", "定风珠", "魔神甲", "穿天弩", "咆哮梯", "金光锉", "五行旗",
                "乱心尘", "阴阳二气瓶", "劈地珠", "杏黄旗", "阴阳刃", "穿心锁", "三尖两刃枪", "浮云", "金霞冠", "伏羲琴",
                "落魂钟", "焰光旗", "化血神刀", "日月珠", "定海珠", "破军", "开天珠", "混元锤", "火星帖", "翻天印",
                "四象塔", "天荡", "降魔杵", "乾坤圈", "如意乾坤袋", "捆仙绳", "招妖幡", "杯具", "水火锋", "苍刑逆天枪",
                "黑砂", "混元幡", "乾坤弓", "落魄镜", "听谛印", "照天印", "遁龙桩", "鸭梨", "缚龙索", "混沌钟",
        };
        String monName = arr[lv - 1];
        String monKey = "blxt_" + lv;
        String model = "blxt_" + lv;

        int attackType = 0;
        JSONArray skills = getSkillList(
                //getSkillObj("3047", 1), getSkillObj("3072", 1)
        );
        float xue = 5000 * (1 + lv / 10f), wg = 1000 * (1 + lv / 20f), fg = 1000 * (1 + lv / 20f),
                wf = 500 * (1 + lv / 20f), ff = 500 * (1 + lv / 20f), css = 1000 * (1 + lv / 20f),
                mz = 5000 * (1 + lv / 100f), sd = 50 * (1 + lv / 20f), bj = 1000 * (1 + lv / 20f);
        /*float xue = 1, wg = 1, fg = 1,
                wf = 1, ff = 1, css = 1,
                mz = 1, sd = 1, bj = 1;*/
        JSONObject prop = getAttrObj(xue, wg, fg, wf, ff, css, mz, sd, bj);
        JSONObject m = createDefinedFightData(monName, attackType, prop, skills);
        m.put("model", model);
        putDefinedMon(monsterList, 0, monKey, m, 0, 4, 0);
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(18, 0, roleList, monsterList);

        toFight(fightMsg, user);
        return new result(200, 1);
    }

    /**
     * 跑商抢夺
     */
    public result createFightByQd(JSONObject j,
                                  @paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String playerName = j.getString("playerName");
        if (!isAllowedFight(name, playerName)) {
            return new result(200, 0);
        }
        //队伍
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        msgPutRoleListByFormation(false, roleList, playerName, "l", con);
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(9, 0, roleList);

        toFight(fightMsg, user);
        return new result(200, 1);
    }

    /**
     * 帮战（单人占领宝箱）
     */
    public result createFightByBz(JSONObject j,
                                  @paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //String playerName = j.getString("playerName");
        //if (playerName != null && playerName.equals(name)) return new result(0);
        if (j.get("boxKey") == null || j.get("bzId") == null) {
            throw new RuntimeException("缺少boxKey");
        }
        //当挑战方已经占领了宝箱时需要先移除
        JSONObject abox = startBef.gangsService.getBoxByPlayerName(j.getString("bzId"), name);
        if (abox != null) {
            abox.put("playerName", null);
        }
        //对于没有被占领的宝箱，就对战人机；占领的才对战玩家（标记此宝箱正处于抢夺中）
        JSONObject box = startBef.gangsService.getOneBox(j.getString("bzId"), j.getString("boxKey"));
        String playerName = box.getString("playerName");
        if (box.getInteger("isFight") == 1) {
            //处于抢夺中
            return new result(200, 2);
        }
        int i = 1;
        if (!isAllowedFight(name)) {
            i = 2;//name处于战斗中
            return new result(200, i);
        }
        //标记正在战斗
        box.put("isFight", 1);

        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        JSONArray monsterList = new JSONArray();
        if (box.get("playerName") == null) {
            //对战人机
            monsterList = new JSONArray();
            String monName = null;
            int type = box.getInteger("type");//0金 1银 2铜 3随机积分宝箱

            int lv = 20;
            if (type == 0) {

            } else if (type == 1) {
                lv = 10;
            } else if (type == 2) {
                lv = 5;
            } else if (type == 3) {
                lv = 1;
            }
            int attackType = 0;
            JSONArray skills = getSkillList(
                    getSkillObj("3047", 1), getSkillObj("3072", 1)
            );
            float xue = 100 * (1 + lv / 10f), wg = 1000 * (1 + lv / 20f), fg = 1000 * (1 + lv / 20f),
                    wf = 100 * (1 + lv / 20f), ff = 100 * (1 + lv / 20f), css = 2000 * (1 + lv / 20f),
                    mz = 10000 * (1 + lv / 100f), sd = 100 * (1 + lv / 20f), bj = 1000 * (1 + lv / 20f);
            String monKey = "bz_box_";
            if (type == 0) {
                monName = "守卫1";
                //wg *= 1.3;
                monKey += "0";
                //todo 添加怪物专属技能
            } else if (type == 1) {
                monName = "守卫2";
                attackType = 1;
                //fg *= 1.3;
                monKey += "1";
            } else if (type == 2) {
                monName = "守卫3";
                //wf *= 1.5;
                //ff *= 1.5;
                monKey += "2";
            } else if (type == 3) {
                monName = "守卫4";
                attackType = 1;
                xue *= 1.2;
                sd *= 1.5;
                monKey += "3";
            }
            String model = monKey;
            JSONObject prop = getAttrObj(xue, wg, fg, wf, ff, css, mz, sd, bj);
            JSONObject m = createDefinedFightData(monName, attackType, prop, skills);
            m.put("model", model);
            putDefinedMon(monsterList, 0, monKey, m, 0, 4, 0);
        } else {
            //对战玩家
            if (!isAllowedFight(playerName)) {
                i = 3;//playerName处于战斗中
                box.put("isFight", 0);
                return new result(200, i);
            }
            //被攻击方
            msgPutRoleListByFormation(false, roleList, playerName, "l", con);
        }

        try {
            //构造战斗信息
            JSONObject fightMsg = getFightMsgStruct(8, 0, roleList, monsterList);
            fightMsg.put("params", j);
            toFight(fightMsg, user);
        } catch (Exception e) {
            loggerUtils.error("帮战调取失败" + e.getMessage(), this.getClass());
            i = 0;
            box.put("isFight", 0);
        }
        return new result(200, i);
    }

    /**
     * 偷袭
     * 恶人3-魔头5
     * 侠士3-英雄5
     * 善恶值
     * 偷袭恶人、魔头善恶值++，其他善恶值--
     */
    public result createFightBySneak(JSONObject j,
                                     @paramsAnno(key = "user") user user,
                                     @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String playerName = j.getString("playerName");
        if (playerName.equals(name)) return new result(0);
        if (startBef.teamService.isTeamMember(name, playerName)) return new result(0);
        try {
            //只允许队长触发战斗
            if (!isCaptainTriggerFight(name)) {
                return new result(794);
            }
            if (!isAllowedFight(name)) {
                return new result(795);
            }
            if (!isAllowedFight(playerName)) {
                return new result(795);
            }
            //当接取逮捕令后则允许在主城进行抓捕
            if (startBef.prisonService.isTongJiObj(name, playerName, con)) {
                //有通缉任务时除了牢房、恶人谷不能被偷袭
                if (staticCollection.isInMap("prison", playerName)) {
                    return new result(716);
                }
            } else {
                //不存在通缉任务时只能在野区才能偷袭
                if (staticCollection.isNoSneakMap(name) ||
                        staticCollection.isNoSneakMap(playerName)) {
                    return new result(716);
                }
            }

            JSONArray roleList = new JSONArray();
            //主动攻击方
            msgPutRoleListByFormation(true, roleList, name, "r", con);
            //被攻击方
            msgPutRoleListByFormation(true, roleList, playerName, "l", con);
            //构造战斗信息
            JSONObject fightMsg = getFightMsgStruct(7, 0, roleList);

            toFight(fightMsg, user);
        } catch (Exception e) {
            loggerUtils.error("偷袭战斗调取失败" + e.getMessage(), this.getClass());
        }
        return new result(200, 1);
    }

    /**
     * 系统逮捕魔头
     */
    public void createFightBySysCatch(String name, int sez) {
        DefaultSqlSession con = null;
        try {
            if (!isAllowedFight(name)) {
                return;//name处于战斗中
            }
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            //获取当前天兵的等级来增加难度
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            List<JSONObject> tbList = activityMapper.getTianbing(name);
            mybatisConfig.commit(con);
            if (tbList.size() == 0) {
                activityMapper.addTianbing(name);
                JSONObject a = new JSONObject();
                a.put("lv", 1);
                tbList.add(a);
            }
            int lv = tbList.get(0).getInteger("lv");
            //对于大于10的系统不再缉捕，需使用道具恢复平民身份才重置lv
            if (lv > 10) return;

            JSONArray roleList = new JSONArray();
            //主动攻击方
            msgPutRoleListByFormation(true, roleList, name, "r", con);

            JSONArray monsterList = new JSONArray();
            float f = lv;
            for (int i = 0; i < 10; i++) {
                JSONObject prop = getAttrObj(50000 * f, 1000 * f, 1000 * f, 500 * f, 500 * f, 600 * f, 5000 * f, 10 * f, 100 * f);
                JSONObject m = createDefinedFightData("天兵", 0, prop, new JSONArray());
                m.put("model", "tianbing");
                putDefinedMon(monsterList, 0, "tianbing", m, i, 4, 0);
            }

            //构造战斗信息
            JSONObject fightMsg = getFightMsgStruct(13, 0, roleList, monsterList);

            mybatisConfig.commit(con);
            toFight(fightMsg, staticCollection.getUserByName(name));
        } catch (Exception e) {
            e.printStackTrace();
            loggerUtils.error("逮捕魔头战斗调取失败" + e.getMessage(), this.getClass());
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 由追杀令创建战斗
     */
    public result createFightByZsl(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String playerName = j.getString("playerName");
        if (strUtils.isNull(playerName)) return new result(0);
        if (playerName.equals(name)) return new result(0);
        if (startBef.teamService.isTeamMember(name, playerName)) return new result(0);
        try {
            //只允许队长触发战斗
            if (!isCaptainTriggerFight(name)) {
                return new result(794);
            }
            if (!isAllowedFight(name, name)) {
                return new result(681);
            }
            if (!isAllowedFight(name, playerName)) {
                return new result(681);
            }

            //先判断是否有追杀任务并判断是否为追杀的对象
            if (!startBef.zslService.isKillObj(playerName, name, con)) {
                return new result(1018);//非指定目标
            }
            JSONArray roleList = new JSONArray();
            //主动攻击方
            msgPutRoleListByFormation(true, roleList, name, "r", con);
            //被攻击方
            msgPutRoleListByFormation(true, roleList, playerName, "l", con);
            //构造战斗信息
            JSONObject fightMsg = getFightMsgStruct(12, 0, roleList);
            //用于战斗结束后分辨哪个玩家悬赏哪个玩家
            JSONObject params = new JSONObject();
            params.put("playerName", playerName);
            params.put("name", name);
            fightMsg.put("params", params);
            toFight(fightMsg, user);
        } catch (Exception e) {
            loggerUtils.error("追杀战斗调取失败" + e.getMessage(), this.getClass());
            return new result(0);
        }
        return new result(200, 1);
    }

    /**
     * 是否允许pk
     */
    private boolean isAllowedPK(String playerName, DefaultSqlSession con) {
        //先找到对方是否组队，队长是否开了切磋
        JSONObject team = startBef.teamService.getTeamByName(playerName);
        if (team == null) {
            if (startBef.manService.isAllowedPk(playerName, con) != 1) {
                return false;
            }
        } else {
            JSONArray list = team.getJSONArray("list");
            for (int i = 0; i < list.size(); i++) {
                JSONObject obj = (JSONObject) list.get(i);
                //处于跟随状态就要判断队长切磋开关
                if (obj.getString("name").equals(playerName) &&
                        obj.getInteger("isOnline") == 1 && obj.getInteger("isFollow") == 1) {
                    //判断队长切磋开关是否打开
                    if (startBef.manService.isAllowedPk(team.getString("captain"), con) != 1) {
                        return false;
                    }
                    break;
                } else if (obj.getString("name").equals(playerName) &&
                        obj.getInteger("isOnline") == 1 && obj.getInteger("isFollow") == 0) {
                    //判断自身切磋开关
                    if (startBef.manService.isAllowedPk(playerName, con) != 1) {
                        return false;
                    }
                    break;
                } else {
                    return false;
                }
            }
        }
        return true;
    }

    /**
     * 斗战封神榜
     */
    public result createFightByDzfsb(JSONObject j,
                                     @paramsAnno(key = "user") user user,
                                     @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int useZdhl = j.getInteger("useZdhl");
        int sort = j.getInteger("sort") - 1;
        if (sort < 0) return new result(0);
        if (!isAllowedFight(name, name)) {
            return new result(681);
        }

        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        //验证次数是否充足
        List<JSONObject> al1 = jsonMapper.selectDzfsbLogByName(name);
        if (al1.size() == 0) {
            jsonMapper.addDzfsbLog(name, new JSONArray().toString());
            al1 = jsonMapper.selectDzfsbLogByName(name);
        }
        int times = al1.get(0).getInteger("times");
        if (times <= 0) {
            return new result(610);
        }

        JSONObject a1 = jsonMapper.selectDzfsbOrderByName(name).get(0);
        if (useZdhl == 0) {
            int d = Math.abs(a1.getInteger("sort") - sort);
            if (d > 10) {
                //随机一个
                sort = strUtils.getRandom(a1.getInteger("sort") - 10, a1.getInteger("sort") - 1);
                if (sort < 0)
                    sort = strUtils.getRandom(a1.getInteger("sort") + 1, a1.getInteger("sort") + 10);
            }
        } else {
            if (startBef.packageService.cutPlayerGoodsNumByKey("10000224", 1, name, con) == 0) {
                return new result(0);
            }
        }

        List<JSONObject> al2 = jsonMapper.selectDzfsbOrderBySort(sort + "");
        if (al2.size() == 0) return new result(0);
        String playerName = al2.get(0).getString("name");
        if (playerName.equals(name)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        JSONArray monsterList = new JSONArray();
        //拷贝对方战斗数据
        JSONObject one = startBef.manService.getPlayerAIData(playerName, con);
        putAI(monsterList, null, roleUtils.getModel(one), staticCollection.copyObj(one.get("attr0")), "l0", 4, one.getInteger("goldType"));

        one = new JSONObject();
        startBef.manService.putPetAIData(one, playerName, con);
        if (one.get("pet") != null) {
            String key = one.getJSONObject("pet").getString("key");
            JSONObject m = petData.get(key, user.projRootDir);
            putAI(monsterList, key, m.getString("model"), staticCollection.copyObj(one.get("attr1")), "l5", 4, 0);
        }
        //挑战次数--
        jsonMapper.updateDzfsbLog(name, null, times - 1 + "");
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(22, 0, roleList, monsterList);
        toFight(fightMsg, staticCollection.getUserByName(name));
        return new result(200, 1);
    }

    /**
     * pk
     */
    public result createFightByPK(JSONObject j,
                                  @paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String playerName = j.getString("playerName");
        if (staticCollection.isNoPKMap(playerName)) {
            return new result(883);
        }
        //只允许队长触发战斗
        if (!isCaptainTriggerFight(name)) {
            return new result(794);
        }
        //处于战斗中就不允许创建\先找到对方是否组队，队长是否开了切磋
        if (!isAllowedFight(name, playerName)) {
            return new result(681);
        }
        if (!isAllowedPK(playerName, con)) {
            return new result(623);
        }
        //获取r方阵容和l方阵容，并根据阵容放入roleList
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(true, roleList, name, "r", con);
        //被攻击方
        msgPutRoleListByFormation(true, roleList, playerName, "l", con);

        //创建切磋战斗
        JSONObject fightMsg = getFightMsgStruct(2, 0, roleList);

        //触发战斗
        toFight(fightMsg, user);

        //将切磋开关打开
        JSONObject pk = new JSONObject();
        pk.put("isOpen", 1);
        startBef.manService.setStatusPk(pk, user, con);
        return new result(200, 1);
    }

    /**
     * 大师兄海选
     */
    public Integer createFightByDsx(String name, String playerName, DefaultSqlSession con) {
        int i = 1;
        try {
            if (!isAllowedFight(name)) {
                i = 2;//name视为失败
            }
            if (!isAllowedFight(playerName)) {
                if (i == 2) {
                    i = 0;//两者都弃权
                } else {
                    i = 3;//player视为失败
                }
            }
            if (i != 1) {
                return i;
            }
            JSONArray roleList = new JSONArray();
            //主动攻击方
            msgPutRoleListByFormation(false, roleList, name, "r", con);
            //被攻击方
            msgPutRoleListByFormation(false, roleList, playerName, "l", con);
            //构造战斗信息
            JSONObject fightMsg = getFightMsgStruct(6, 0, roleList);

            toFight(fightMsg, staticCollection.getUserByName(name));
        } catch (Exception e) {
            loggerUtils.error("海选调取战斗失败" + e.getMessage(), this.getClass());
            i = 0;
        }
        return i;
    }

    /**
     * 永恒魔域(单人)
     */
    public Integer createFightByYhmk(String name, int type, int lv, DefaultSqlSession con) {
        if (!isAllowedFight(name)) {
            return 0;
        }

        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con, false);
        //被攻击方
        JSONArray monsterList = new JSONArray();
        String model = "yhmkms_" + type;
        int attackType = 0;
        JSONArray skills = getSkillList(
                getSkillObj("100210000002", 1)
        );
        float xue = 10000 + 10000 * lv,
                wg = 500 * (1 + lv), fg = 500 * (1 + lv),
                wf = 200 * (1 + lv), ff = 200 * (1 + lv),
                css = 2000 * (1 + lv / 20f), mz = 10000 * (1 + lv / 10f),
                sd = 500 * (1 + lv / 10f), bj = 1000 * (1 + lv / 10f);
        String monKey = model;
        String[] ns = {"狂攻", "铁壁", "生命", "神速", "射手", "法术", "暴怒"};
        String monName = ns[type - 1];
        if (type == 0) {
            wg *= 1.3;
        } else if (type == 1) {
            attackType = 1;
            fg *= 1.3;
        } else if (type == 2) {
            wf *= 1.5;
            ff *= 1.5;
        } else if (type == 3) {
            attackType = 1;
            xue *= 1.2;
            sd *= 1.5;
        } else {
            wg *= 1.3;
            fg *= 1.3;
            xue *= 1.2;
        }
        JSONObject prop = getAttrObj(xue, wg, fg, wf, ff, css, mz, sd, bj);
        JSONObject m = createDefinedFightData(monName + "魔神", attackType, prop, skills);
        m.put("model", model);
        putDefinedMon(monsterList, 0, monKey, m, 0, 4, 0);
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(1, 0, roleList, monsterList);


        toFight(fightMsg, staticCollection.getUserByName(name));
        return 1;
    }


    /**
     * 过滤不在同一帮派的队伍成员
     */
    public void removeNoSameBp(String name, JSONArray roleList, DefaultSqlSession con) {
        JSONObject msg = startBef.manService.getMsgData(name, con);
        List<String> names = new ArrayList<>();
        for (Object o : roleList) {
            JSONObject r = (JSONObject) o;
            if (r.getString("name").equals(name) || r.getInteger("type") != 0) {
                continue;
            }
            JSONObject msg2 = startBef.manService.getMsgData(r.getString("name"), con);
            if (msg2.get("bp") == null || msg2.getString("bp").equals("")) {
                names.add(r.getString("name"));
                continue;
            }
            if (!msg.getJSONObject("bp").getString("name")
                    .equals(msg2.getJSONObject("bp").getString("name"))) {
                names.add(r.getString("name"));
            }
        }
        for (Object o : roleList) {
            JSONObject r = (JSONObject) o;
            for (String n : names) {
                if (r.getString("name").equals(n) ||
                        r.getString("name").equals(n + "_pet")) {
                    roleList.remove(o);
                    break;
                }
            }
        }
    }

    /**
     * 帮派强盗
     */
    public Integer createFightByBPRobber(String name, DefaultSqlSession con) {
        if (!isAllowedFight(name)) {
            return 0;
        }
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(true, roleList, name, "r", con);
        //被攻击方
        JSONArray monsterList = new JSONArray();
        putMonster(monsterList, "bp_robber", 0, 4, staticCollection.getProjRootDirByName(name));
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(1, 0, roleList, monsterList);

        toFight(fightMsg, staticCollection.getUserByName(name));
        return 1;
    }

    /**
     * 帮派boss创建战斗
     */
    public Integer createFightByBPBoss(String name, DefaultSqlSession con) {
        if (!isAllowedFight(name)) {
            return 0;
        }
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        JSONArray monsterList = new JSONArray();
        putMonster(monsterList, "bp_boss", 0, 4, staticCollection.getProjRootDirByName(name));
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(1, 0, roleList, monsterList);

        toFight(fightMsg, staticCollection.getUserByName(name));
        return 1;
    }

    /**
     * 创建活动战斗
     */
    public Integer createFightByAc(String name, List<String> mons, DefaultSqlSession con) {
        //处于战斗中就不允许创建
        if (!isAllowedFight(name)) {
            return 0;
        }
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(true, roleList, name, "r", con);
        //被攻击方
        JSONArray monsterList = new JSONArray();
        for (int i = 0; i < mons.size(); i++) {
            putMonster(monsterList, mons.get(i), i, 4, staticCollection.getProjRootDirByName(name));
        }
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(1, 0, roleList, monsterList);

        toFight(fightMsg, staticCollection.getUserByName(name));
        return 1;
    }

    /**
     * 由任务创建战斗
     */
    public Integer createFightByTask(String name, String key, DefaultSqlSession con) {
        //处于战斗中就不允许创建
        if (!isAllowedFight(name)) {
            return 0;
        }
        JSONObject taskMsg = startBef.taskService.getTaskMsgToCreateFight(key, name, con);

        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(true, roleList, name, "r", con);
        //加入ai位置
        taskAiData.addAiGayByTask(key, taskMsg.getInteger("progressIndex"), roleList);
        //被攻击方
        List<String> mons = taskProgressToMonKey.getMonsterKeysByTask(key, taskMsg.getInteger("progressIndex"));
        JSONArray monsterList = new JSONArray();
        for (int i = 0; i < mons.size(); i++) {
            putMonster(monsterList, mons.get(i), i, 4, staticCollection.getProjRootDirByName(name));
        }
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(1, 0, taskMsg.getString("npcKey"), key, taskMsg.getInteger("progressIndex"), roleList, monsterList);


        toFight(fightMsg, staticCollection.getUserByName(name));
        return 1;
    }

    /**
     * 拉取战斗信息
     */
    public result getFightMsg(JSONObject j) {
        JSONObject fightMsg = fightMap.get(j.getString("Id"));
        return new result(200, fightMsg);
    }

    /**
     * 抢壁
     */
    public Integer createFightByCb(String name, String playerName, DefaultSqlSession con) {
        if (!isAllowedFight(name)) {
            return 0;
        }
        if (!isAllowedFight(playerName)) {
            return 0;
        }
        //创建切磋战斗
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        msgPutRoleListByFormation(false, roleList, playerName, "l", con);
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(5, 0, roleList);


        toFight(fightMsg, staticCollection.getUserByName(name));
        return 1;
    }

    /**
     * 世界boss
     */
    public result createFightByWorldBoss(@paramsAnno(key = "user") user user,
                                         @paramsAnno(key = "con") DefaultSqlSession con) {
        //是否在boss开启的时间段 晚7点到7点10
        if (!startBef.activityService.isOpen("worldBoss")) {
            return new result(696);
        }
        if (user.msg.getInteger("lever") < 30) {
            return new result(0);
        }
        final String name = user.name;
        if (!isAllowedFight(name)) {
            return new result(0);
        }

        //创建切磋战斗
        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        JSONArray monsterList = new JSONArray();
        putMonster(monsterList, "world_boss", 0, 4, staticCollection.getProjRootDirByName(name));
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(1, 0, roleList, monsterList);

        toFight(fightMsg, user);
        return new result(200, 1);
    }


    /**
     * 多人排位
     */
    public Integer createFightByTeamPaiwei(String teamId0, String teamId1) {
        JSONObject team0 = teamMap.get(teamId0);
        if (team0 == null) return -1;
        JSONObject team1 = teamMap.get(teamId1);
        if (team1 == null) return -2;
        String name = team0.getString("captain");
        String playerName = team1.getString("captain");
        //处于战斗中就不允许创建
        if (!isAllowedFight(name)) {
            //name处于战斗而不能创建
            return -1;
        }
        if (!isAllowedFight(playerName)) {
            return -2;
        }

        //队伍
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();

            JSONArray roleList = new JSONArray();
            //主动攻击方
            msgPutRoleListByFormation(true, roleList, name, "r", con);
            //被攻击方
            msgPutRoleListByFormation(true, roleList, playerName, "l", con);
            //构造战斗信息
            JSONObject fightMsg = getFightMsgStruct(15, 0, roleList);

            mybatisConfig.commit(con);

            toFight(fightMsg, staticCollection.getUserByName(name));
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }

        return 1;
    }

    /**
     * 个人排位
     */
    public Integer createFightByPersonPaiwei(String name, String playerName) {
        //处于战斗中就不允许创建
        if (!isAllowedFight(name)) {
            //name处于战斗而不能创建
            return -1;
        }
        if (!isAllowedFight(playerName)) {
            return -2;
        }

        //队伍
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();

            JSONArray roleList = new JSONArray();
            //主动攻击方
            msgPutRoleListByFormation(false, roleList, name, "r", con);
            //被攻击方
            msgPutRoleListByFormation(false, roleList, playerName, "l", con);
            //构造战斗信息
            JSONObject fightMsg = getFightMsgStruct(15, 0, roleList);

            mybatisConfig.commit(con);
            toFight(fightMsg, staticCollection.getUserByName(name));
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }

        return 1;
    }

    /**
     * 王侯将相
     */
    public Integer createFightByWHJX(String name, String playerName, DefaultSqlSession con) {
        //处于战斗中就不允许创建
        if (!isAllowedFight(name)) {
            return 0;
        }
        if (!isAllowedFight(playerName)) {
            return 0;
        }

        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        msgPutRoleListByFormation(false, roleList, playerName, "l", con);
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(17, 0, roleList);


        toFight(fightMsg, staticCollection.getUserByName(name));
        return 1;
    }

    /**
     * 竞技
     */
    public Integer createFightByJingji(String name, String playerName, DefaultSqlSession con) {
        //处于战斗中就不允许创建
        if (!isAllowedFight(name, playerName)) {
            return 0;
        }

        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        msgPutRoleListByFormation(false, roleList, playerName, "l", con);
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(3, 0, roleList);


        toFight(fightMsg, staticCollection.getUserByName(name));
        return 1;
    }

    /**
     * 跟猴子战斗
     */
    public result attackMonkey(@paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        if (strUtils.isNull(bpId)) return new result(0);
        //处于战斗中就不允许创建
        if (!isAllowedFight(name)) {
            return new result(0);
        }
        //不允许组队
        if (isInTeam(name)) {
            return new result(630);
        }
        //验证活动是否开启及猴子数量是否>0
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        int num = dao.selectGangsV(bpId).get(0).getInteger("monkey");
        if (num <= 0) return new result(200, -1);
        int ywt = dao.selectGangsActivity(bpId).get(0).getInteger("ywt");
        if (ywt == 0) return new result(0);

        JSONArray roleList = new JSONArray();
        //主动攻击方
        msgPutRoleListByFormation(false, roleList, name, "r", con);
        //被攻击方
        JSONArray monsterList = new JSONArray();
        putMonster(monsterList, "houzi", 0, 4, staticCollection.getProjRootDirByName(name));
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(1, 0, roleList, monsterList);
        toFight(fightMsg, user);
        return new result(200, 1);
    }

    /**
     * 遇怪
     */
    public result createFightByMonster(JSONObject j,
                                       @paramsAnno(key = "user") user user,
                                       @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String npcKey = j.getString("npcKey");
        if (strUtils.isNull(npcKey)) return new result(0);
        //处于战斗中就不允许创建
        if (!isAllowedFight(name)) {
            return new result(795);
        }
        //只允许队长触发战斗
        if (!isCaptainTriggerFight(name)) {
            return new result(794);
        }
        int isCatch = 0;
        if (strUtils.isMatch(npcKey, "gw[0-9]{4}")) {
            int n = Integer.parseInt(npcKey.substring(2));
            if (n < 1215) {
                isCatch = 1;//野怪才允许捕捉
            }
        }

        JSONArray roleList = new JSONArray();
        boolean allowedTeam = true;
        if (npcKey.contains("abyss") || npcKey.contains("xxzd")) {
            //天渊、血腥之地不允许组队
            allowedTeam = false;
        }
        //主动攻击方
        msgPutRoleListByFormation(allowedTeam, roleList, name, "r", con);
        //被攻击方
        int num = roleList.size();
        boolean isJingYing = false;
        if (startBef.manService.isStatusOpen("jml", name)) {
            //打开聚魔铃的情况就遇10只精英
            num = 10;
            isJingYing = true;
        } else if (startBef.manService.isStatusOpen("blx", name)) {
            //打开百里香的情况就遇10只
            num = 10;
        }

        List<String> mons = monsterData.getMonsterKeysByNpcKey(npcKey, num, name);
        JSONArray monsterList = new JSONArray();
        int quality = 0;
        for (int i = 0; i < mons.size(); i++) {
            if (isCatch != 1) {//不允许捕捉时，品质设置为boss
                quality = 4;
            } else {
                if (strUtils.isHappend(0, 1000, 0.1f)) {
                    quality = -1;//精英
                } else if (strUtils.isHappend(0, 1000, 0.6f)) {
                    quality = strUtils.getRandom(0, 2);//普通
                } else if (strUtils.isHappend(0, 1000, 0.5f)) {
                    quality = 2;//宝宝
                } else {
                    quality = 3;//变异
                }
            }
            if (isJingYing) quality = -1;
            putMonster(monsterList, mons.get(i), i, quality, staticCollection.getProjRootDirByName(name));
        }
        //构造战斗信息
        JSONObject fightMsg = getFightMsgStruct(0, isCatch, npcKey, null, null, roleList, monsterList);

        toFight(fightMsg, user);
        return new result(200, 1);
    }

    /**
     * 调取战斗
     */
    private void toFight(JSONObject fightMsg, user user) {
        fightMsg.put("projRootDir", user.projRootDir);
        staticCollection.putTask(() -> {
            try {
                startBef.fightService.createFight(fightMsg);
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }


    /**
     * 提取阵位信息并放入roleList
     * allowedTeam 是否允许组队
     * team队伍（攻击方、被攻击方）
     * temp roleList
     * playerName 任意玩家名（因为被攻击玩家不一定担任队长）
     * direct r/l
     * 站位
     * 14 9 4 19
     * 12 7 2 17
     * 10 5 0 15
     * 11 6 1 16
     * 13 8 3 18
     */
    private void msgPutRoleListByFormation(boolean allowedTeam, JSONArray temp, String playerName, String direct, DefaultSqlSession con) {
        msgPutRoleListByFormation(allowedTeam, temp, playerName, direct, con, true);
    }

    private void msgPutRoleListByFormation(boolean allowedTeam, JSONArray temp, String playerName, String direct, DefaultSqlSession con, boolean isAddPet) {
        JSONObject team = null;
        if (allowedTeam)
            team = startBef.teamService.getTeamByName(playerName);
        String name = playerName;
        //使name一定为队长
        if (team != null) name = team.getString("captain");
        //获取队长的伙伴
        //JSONArray arr = startBef.huobanService.getIsFightHuoban(name, con);
        JSONArray arr = new JSONArray();
        //获取阵型
        JSONObject lineup = null;
        if (team != null) {
            lineup = team.getJSONObject("lineup");
        } else {
            lineup = startBef.teamService.getFormation(name, con);
        }
        JSONObject formation = lineup.getJSONObject("formation");
        //根据阵位来创建
        for (String k : formation.keySet()) {
            if (formation.getString(k).equals("")) continue;
            JSONObject a = formation.getJSONObject(k);
            int type = a.getInteger("type");
            //确定归属于哪个玩家
            user u = null;
            if (team == null) {
                //都归属于name
                u = staticCollection.getUserByName(name);
            } else {
                //按a的playerName进行区分
                u = staticCollection.getUserByName(a.getString("playerName"));
                if (u == null) continue;
                //对于组队的成员并且暂离（不在线）的不允许
                if (!allowedAddToRoleList(team, u.name)) continue;
            }


            JSONObject rMsg;
            if (type == 0) {//玩家
                rMsg = getRoleMsg(u.name, u.msg.getInteger("lever"), u.msg.getString("model"),
                        0, k.replace("p", direct), u.sbh);
                if (team != null && team.getString("captain").equals(name)) {
                    rMsg.put("captain", 1);//主控玩家标记（队长或者是非组队的自己）
                }
                temp.add(rMsg);
            } else if (type == 1 && isAddPet) {//宠物
                Object petD = startBef.petService.getIsFightPet(u.name, con);
                if (petD != null) {
                    JSONObject pet = (JSONObject) petD;
                    rMsg = getRoleMsg(u.name + "_pet", pet.getInteger("lever"), pet.getString("model"),
                            1, k.replace("p", direct), u.sbh);
                    rMsg.put("nickName", pet.getString("nickName"));
                    temp.add(rMsg);
                }
            } else if (type == 5) {//伙伴
                for (int p = 0; p < arr.size(); p++) {
                    JSONObject hb = (JSONObject) arr.get(p);
                    if (hb.getString("key").equals(a.getString("key"))) {
                        //玩家名_4位的武将key
                        rMsg = getRoleMsg(u.name + "_" + hb.getString("key"), hb.getInteger("lever"), hb.getString("model"),
                                5, k.replace("p", direct), u.sbh);
                        rMsg.put("nickName", hb.getString("nickName"));
                        temp.add(rMsg);
                        break;
                    }
                }

            }
        }


    }

    /**
     * 是否允许加入RoleList
     * 对于组队的成员并且暂离（不在线）的才不允许
     */
    private boolean allowedAddToRoleList(JSONObject team, String name) {
        //未组队和自身是队长则允许
        if (team == null || name.equals(team.getString("captain"))) return true;
        //对于暂离的队员不能加入其中
        JSONArray members = team.getJSONArray("list");
        for (int i = 0; i < members.size(); i++) {
            JSONObject m = members.getJSONObject(i);
            if (m.getString("name").equals(name) &&
                    m.getInteger("isOnline") == 1 &&
                    m.getInteger("isFollow") == 1) {
                return true;
            }
        }
        return false;
    }


}
