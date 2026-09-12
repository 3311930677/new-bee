package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.data.monsterData;
import my.db.mybatisConfig;
import my.fightUtils.fightBuffHandUtils;
import my.fightUtils.fightUtils;
import my.gameUtils.aiUtils;
import my.gameUtils.skillUtils;
import my.gameUtils.sysSettingUtils;
import my.model.*;
import my.service.fight.*;
import my.startBef;
import my.utils.classUtils;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Vector;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

import static my.fightUtils.fightBuffHandUtils.*;
import static my.fightUtils.fightUtils.*;
import static my.model.skillItemCreateMoment.*;
import static my.model.skillItemRuleType.*;
import static my.model.skillItemTriggerMoment.*;
import static my.utils.classUtils.invokeFnByFnName;

/**
 * 战斗服务
 */
public class fightService {
    /**
     * 恢复战斗
     */
    public void resumeFight(String id, String name) {
        //放入战斗信息
        fightUtils.resumeDataToFight(id);
        //当所有高级数据准备好之后通知显示菜单、创建ui模型
        updateHuiheStartTime(true, id, 0);
        //通知显示战斗
        ChannelSupervise.noticeClientByName(id, name, "900");
    }

    /**
     * 创建战斗
     */
    public Integer createFight(JSONObject j) {
        //判断数据是否齐全
        if (j.get("type") == null) {
            return 0;
        }
        String projRootDir = j.getString("projRootDir");
        //生成战斗id
        j.put("Id", strUtils.getId());
        //设置当前回合以及倒计时
        j.put("huihe", 0);
        j.put("time", strUtils.getTime() + 30 * 1000);
        String id = j.getString("Id");
        DefaultSqlSession con = null;
        try {
            //将战斗信息缓存，当战斗结束后需要移除
            roleMap.put(id, new JSONObject());
            orderMap.put(id, new JSONObject());
            monsterMap.put(id, new JSONObject());
            buffMap.put(id, new Vector<>());
            onceActionDoing.put(id, false);
            skillCoolMap.put(id, new Vector<>());
            viewFightMap.put(id, new ArrayList<>());
            fightUtils.hurtMap.put(id, new JSONObject());
            amPlayedOrderMap.put(id, new JSONObject());

            int fightType = j.getInteger("type");
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            //复制怪物属性到本场战斗中
            JSONArray monsterList = j.getJSONArray("monsterList");
            if (monsterList != null) {
                if (fightType != 14 && fightType != 16) {
                    //从怪物属性中复制
                    for (Object m : monsterList) {
                        JSONObject t = (JSONObject) m;
                        JSONObject temp = monsterMap.get(id);
                        String posKey = t.getString("posKey");
                        if (t.get("attr") != null) {
                            //这里是自定义怪物生成的数据，在monster.json查不到
                            temp.put(posKey, t.getJSONObject("attr"));
                            t.remove("attr");
                        } else {
                            //从缓存中复制一份放入战斗怪物集
                            JSONObject mon = monsterData.getMonsterByKey(t.getString("key"), projRootDir);
                            //判断是否需要根据等级来调整难度
                            mon = fightUtils.addDifficulty(t.getString("key"), mon, j.getJSONArray("roleList"), con);

                            temp.put(posKey, mon);
                        }
                        //物理、法术
                        int type = temp.getJSONObject(posKey).getInteger("type");
                        //战斗攻击类型要返回客户端，方便判断
                        t.put("fightType", type);
                        monsterMap.put(id, temp);
                    }
                } else {
                    //从实际人物中复制，查不到实际人物就随机创建
                    for (Object m : monsterList) {
                        JSONObject t = (JSONObject) m;
                        JSONObject data = staticCollection.copyObj(t.get("attr"));
                        JSONObject temp = monsterMap.get(id);
                        //从缓存中复制一份放入战斗怪物集
                        temp.put(t.getString("posKey"), data);

                        //物理、法术
                        int type = temp.getJSONObject(t.getString("posKey")).getInteger("type");
                        //战斗攻击类型要返回客户端，方便判断
                        t.put("fightType", type);

                        monsterMap.put(id, temp);
                        t.remove("attr");
                    }
                }

            }


            JSONArray roleList = j.getJSONArray("roleList");
            //fixme 从数据库中读取玩家战斗数据，携宠数据。在这里缓存好（不再需要玩家上传）。返回战斗信息后即可触发菜单显示。
            Iterator it = roleList.iterator();

            while (it.hasNext()) {
                try {
                    JSONObject obj = (JSONObject) it.next();
                    //删除在战斗中的玩家
                    if (obj.getInteger("type") != 4 && isFightingToMsg(obj.getString("name")) != null) {
                        it.remove();
                        continue;
                    }
                    JSONObject attr = null;
                    //从数据库中获取属性并算出高级属性,绑定站位
                    if (fightType != 10 && fightType != 11) {
                        if (obj.getInteger("type") == 0) {//人物数据
                            attr = startBef.manService.getFightAttr(obj.getString("name"), con);
                        } else if (obj.getInteger("type") == 1) {//宠物数据
                            String n = obj.getString("name").substring(0, obj.getString("name").length() - 4);
                            attr = startBef.petService.getFightAttr(n, con);
                        } else if (obj.getInteger("type") == 4) {//ai数据
                            attr = aiUtils.getAiDataByName(obj.getString("name"));
                        }
                    } else {

                    }
                    //添加血、蓝属性
                    JSONObject prop = attr.getJSONObject("prop");
                    JSONObject p = new JSONObject();
                    int xue = prop.getInteger("xue");
                    if (xue > prop.getInteger("max_xue")) {
                        xue = prop.getInteger("max_xue");
                    }
                    p.put("xue", xue);
                    p.put("max_xue", prop.getInteger("max_xue"));
                    int lan = prop.getInteger("lan");
                    if (lan > prop.getInteger("max_lan")) {
                        lan = prop.getInteger("max_lan");
                    }
                    p.put("lan", lan);
                    p.put("max_lan", prop.getInteger("max_lan"));
                    obj.put("prop", p);
                    JSONArray skillList = attr.getJSONArray("skill");
                    JSONArray arr = new JSONArray();
                    if (skillList != null) {
                        for (Object o : skillList) {
                            JSONObject skl = (JSONObject) o;
                            arr.add(skl.get("key"));
                        }
                    }
                    //客户端只能从这里选择技能
                    obj.put("skill", arr);

                    if (obj.getInteger("type") == 0) {//人物
                        user u = staticCollection.getUserByName(obj.getString("name"));
                        //橙装等级特效
                        obj.put("goldType", u.msg.getInteger("goldType"));
                        obj.put("shenfu", u.msg.get("shenfu"));
                        //施法方式
                        JSONObject shifa = startBef.manService.getShiFaWay(obj.getString("name"), con);
                        obj.put("shifaWay", shifa);
                    } else if (obj.getInteger("type") == 1) {//宠物
                        //施法方式
                        String n = obj.getString("name").substring(0, obj.getString("name").length() - 4);
                        JSONObject shifa = startBef.manService.getShiFaWay(n, con);
                        obj.put("shifaWay", shifa);
                    }
                    //物理、法术
                    int type = attr.getInteger("type");
                    //战斗攻击类型要返回客户端，方便判断
                    obj.put("fightType", type);

                    roleMap.get(id).put(obj.getString("posKey"), attr);
                } catch (Exception e) {
                    e.printStackTrace();
                    loggerUtils.error("战斗创建失败(请求数据超时)：" + e.getMessage(), this.getClass());
                    empty(id);
                    return 0;
                }
            }
            mybatisConfig.commit(con);

            fightMap.put(id, j);
            //将需要放置的buff放入缓存
            buffCreateHandle.getOne().readyCreateBuff(id);
            //通知客户端调起战斗场景
            for (Object r : roleList) {
                JSONObject obj = (JSONObject) r;
                if (fightType != 10 && fightType != 11) {
                    if (obj.getInteger("type") != 0) continue;
                    //战斗信息回执后，各个玩家会显示战斗界面，等待全部站位的战斗属性信息上传
                    ChannelSupervise.noticeClientByName(id, obj.getString("name"), "900");
                } else {
                    //论贱
                    final String n = obj.getString("name");
                    String k = n.charAt(n.length() - 1) + "";
                    if (k.equals("a")) {
                        ChannelSupervise.noticeClientByName(id, n.substring(0, n.length() - 2), "900");
                    }
                }
            }
            //System.out.println("战斗被创建：" + fightMap.get(id));
            //当所有高级数据准备好之后通知显示菜单、创建ui模型
            updateHuiheStartTime(true, id, 0);

        } catch (Exception e) {
            e.printStackTrace();
            empty(id);
            //loggerUtils.error("战斗创建失败：" + e.getMessage(), this.getClass());
            mybatisConfig.rollback(con);
            return 0;
        } finally {
            mybatisConfig.close(con);
        }
        return 1;
    }

    /**
     * 处于战斗的话就返回战斗信息
     */
    public JSONObject isFightingToMsg(String name) {
        for (String k : fightMap.keySet()) {
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
     * 同步客户端回合开始时间（战斗数据准备好后调用一次，每次生成战斗动作后调用一次）
     * 最多20s播放动画时间，超时则触发下一回合
     * （不超时但动画都已播放完毕时，客户端要上传播放完毕的标志）
     * 触发客户端菜单的调启，设置回合时间，当前回合数++
     */
    private void updateHuiheStartTime(boolean isTrigger, String id, int acLen) {
        long delay = 1500;
        //是否立即触发（触发对客户端指令菜单的显示）
        if (!isTrigger) {
            //按场上模型数量定义时间(几种情况，看出手速)
            /*JSONArray js = getNoZeroPlayerAndMonster(id);
            delay = 1500 * js.size() + 2000;*/
            JSONObject fgMsg = fightMap.get(id);
            if (fgMsg.getString("projRootDir").equals("wl")) {
                delay = acLen * 4000 + 3000;
            } else if (fgMsg.getString("projRootDir").equals("xq2d")) {
                delay = acLen * 1800 + 3000;
            }
        }
        //System.err.println("acLen:" + acLen);
        huiheStartMap.put(id, strUtils.getTime() + delay);
    }

    /**
     * 上传玩家动画播放完成的指令
     */
    public void putAmPlayedOrder(JSONObject j) {
        orderHandle.getOne().putAmPlayedOrder(j);
    }

    /**
     * 接收取消自动的命令
     */
    public void putCancelAutoOrder(JSONObject j) {
        orderHandle.getOne().putCancelAutoOrder(j);
    }

    /**
     * 接收自动的命令
     */
    public void putAutoOrder(JSONObject j) {
        orderHandle.getOne().putAutoOrder(j);
    }

    /**
     * 上传命令
     * 都由客户端上传命令，当客户端不在线时自动补足
     * fixme 注意不要让该接口连续调用
     * 有些玩家网络延迟导致一个已经不存在的玩家发送位置
     * 占用了其他玩家位置致使提前执行doAction
     */
    public Integer putOrder(JSONObject j) {
        return orderHandle.getOne().putOrder(j);
    }

    /**
     * 所有玩家命令下达，开始执行
     * todo bug多次调用doAction
     */
    public void doAction(String id) {
        try {
            //System.out.println("当前缓存的指令：" + orderMap.get(id));
            JSONObject fightMsg = fightMap.get(id);
            if (fightMsg == null) return;

            List<action> list = new ArrayList<>();
            //回合开始时对所有buff进行回合--，然后去掉无效的buff
            fightBuffHandUtils.updateBuffHuihe(id);
            //回合开始时触发buff
            buffTriggerHandle.getOne().huiheStartTriggerBuff(id, list);
            //回合开始时创建的buff
            buffCreateHandle.getOne().huiheStartCreateBuff(id, list);
            //生成怪物指令
            orderHandle.getOne().createMonsterOrder(id);
            // 按出手速排序后计算伤害、闪避等。最后回送给各个玩家进行展示
            //按css排序 {posKey->attr} css输出 正序posKey数组
            Vector<String> posKeys = orderByCss(id);
            //按输入的技能排序
            //防御先手，
            //真武>援护>玄武护体
            Vector<String> expPosKeys = new Vector<>();
            Iterator<String> ps = posKeys.iterator();
            while (ps.hasNext()) {
                String posKey = ps.next();
                JSONObject playerOrder = getOrderByPosKey(id, posKey);
                if (playerOrder == null) {
                    //可能出现，要补足命令
                    JSONObject order = orderHandle.getOne().getOrder(id, posKey)
                            .getJSONObject("uploadOrder")
                            .getJSONObject(posKey);
                    JSONObject oMap = orderMap.get(id);
                    oMap.put(posKey, order);
                    continue;
                }
                //防御优先
                if (playerOrder.getInteger("action") == 5) {
                    expPosKeys.add(posKey);
                    ps.remove();
                    continue;
                }
                JSONObject skl = playerOrder.getJSONObject("skill");
                if (skl != null && (skl.getString("key").equals("100210000012") ||
                        //怪物先手技能
                        skl.getString("key").equals("100210010315") ||
                        skl.getString("key").equals("100210010316") ||
                        skl.getString("key").equals("100210010320") ||
                        skl.getString("key").equals("100210010321") ||
                        //角色、宠物先手技能
                        skl.getString("key").equals("100210010187") ||
                        skl.getString("key").equals("100210010253") ||
                        skl.getString("key").equals("100210010183") ||
                        skl.getString("key").equals("100210010225") ||
                        skl.getString("key").equals("100210010279") ||
                        skl.getString("key").equals("100210010216") ||
                        skl.getString("key").equals("100210010270"))) {
                    expPosKeys.add(posKey);
                    ps.remove();
                }
            }
            expPosKeys.addAll(posKeys);
            posKeys = expPosKeys;
            //System.err.println("按出手速排序：" + posKeys);
            //按出手速获取指令，并计算
            for (String posKey : posKeys) {
                //{"action":"0","control":"r0","target":"l0"}
                JSONObject playerOrder = getOrderByPosKey(id, posKey);
                //判断执行者血量,没血\已经逃跑\被捕捉了则不允许执行
                if (isBreak(id, posKey)) {
                    continue;
                }
                //动作开始前处理 蛊、休息
                if (!actionStartBeforeBuffHandle(id, posKey, list)) {
                    continue;
                }
                //todo bug目标有时没有 2v1的情况出现玩家r2不见了
                if (playerOrder == null) {
                    loggerUtils.error("目标出现null：" + orderMap.get(id), this.getClass());
                    continue;
                }
                Integer action = playerOrder.getInteger("action");
                if (action == null) {
                    playerOrder.put("action", 0);
                    action = 0;
                    loggerUtils.error("出现action=null：" + playerOrder, this.getClass());
                }
                if (action == 0 || action == 1) {//普通攻击\技能
                    String control = playerOrder.getString("control");
                    String target = playerOrder.getString("target");
                    //攻击开始时创建的buff
                    buffCreateHandle.getOne().attackStartCreateBuff(id, control, target, list);
                    if (action == 0) {
                        attackHandle.getOne().simpleAttackHandle(id, control, target, list, true);
                        //System.err.println(playerOrder);
                    } else {
                        //判断站位是否具有该技能，并且修正技能等级
                        if (orderHandle.getOne().fixPlayerOrder(id, playerOrder) && !skillHandle.getOne().isCool(id, playerOrder, true)) {
                            //改成动作在方法能添加，因为有些是buff技能，所需动作构造不同
                            attackHandle.getOne().skillAttackHandle(id, playerOrder, list);
                            try {

                            } catch (Exception e) {
                                e.printStackTrace();
                                throw new RuntimeException("使用技能出错：" + playerOrder);
                            }
                        } else {
                            if (target.equals(control)) {
                                //重新选举一个目标
                                target = getRandomTarget(id, control.contains("r") ? "l" : "r");
                            }
                            attackHandle.getOne().simpleAttackHandle(id, control, target, list, true);
                        }
                    }
                } else if (action == 2) {//逃跑
                    //不能为竞技、武状元、抢壁、大师兄海选、
                    int type = fightMsg.getInteger("type");
                    if (type == 3 || type == 4 || type == 5 ||
                            type == 6 || type == 8) {
                        continue;
                    }
                    action ac = new action(posKey, null);
                    //逃跑失败
                    if (!strUtils.isHappend(0, 100, 0.5f)) {
                        ac.isTao = 0;
                        list.add(ac);
                        continue;
                    }
                    ac.isTao = 1;
                    //标记玩家、玩家宠物逃跑
                    setPlayerTao(id, posKey);
                    list.add(ac);

                    //通过clientId找到标记是否isTao
                    if (isAllTao(id, posKey)) {
                        JSONObject one = getRoleListOne(id, posKey);
                        String clientId = one.getString("clientId");
                        ac = new action(posKey, 1, clientId);
                        list.add(ac);
                    }
                } else if (action == 3) {//物品

                } else if (action == 4) {//捕捉
                    //判断战斗是否允许捕捉
                    if (fightMsg.getInteger("type") != 0) {
                        continue;
                    }
                    String target = playerOrder.getString("target");
                    //判断捕捉对象是否有血
                    target = getNewTarget(id, target);
                    //没有该对象的话就不执行
                    if (target == null) {
                        continue;
                    }
                    action ac = new action(posKey, null);
                    ac.isCatch = 1;//表示执行者将要执行捕捉这一动作
                    actionItem item = new actionItem(target);
                    if (strUtils.isHappend(0, 100, 0.3f)) {
                        item.isCatch = 1;//表示被捕获者是否被捕捉
                    } else {
                        item.isCatch = 0;
                    }
                    if (item.isCatch == 1) {
                        //调用捕捉 传入站位即可
                        item.isCatch = startBef.petService.catchPet(posKey, target, fightMsg) ? 1 : 0;
                        //标记对象已被捕捉
                        if (item.isCatch == 1)
                            setIsCatch(id, target);
                    }
                    ac.putActionItem(item);
                    list.add(ac);
                } else if (action == 5) {//防御
                    //添加一个减伤的buff即可
                    skill s = skillUtils.getInstance().getSkill("100210000046");
                    action ac = new action(posKey, s.key);
                    JSONObject skl = new JSONObject();
                    skl.put("lv", 1);
                    skl.put("key", s.key);//防御技能key
                    buff bf = buffCreateHandle.getOne().addBuffToMap(id, posKey, skl, posKey, s.skillItems.get(0), ac, 0, 0);
                    actionItem aci = new actionItem(posKey);
                    aci.statusType = bf.statusType;
                    aci.tipKey = bf.txRule.paramStr;
                    aci.value = (int) (bf.txRule.getVal(bf.lever, 0) * 100);
                    ac.putActionItem(aci);

                    list.add(ac);
                }
                //System.out.println("当前目标属性：\n"+getAttrByPosKey(id, target));
            }
            int isEnd = 0;
            //isSuccess=1表示r方胜利
            final action ac = getEndAction(id);
            if (ac != null) {
                isEnd = 1;
                list.add(ac);
                //System.err.println(list);
            }
            //System.err.println("动作："+JSON.toJSONString(list));
            JSONArray roleList = fightMsg.getJSONArray("roleList");
            //loggerUtils.info("返回前端的结果：\n" + result.toJSON(), this.getClass());
            //System.err.println(JSON.toJSONString(list));
            Iterator it = roleList.iterator();
            while (it.hasNext()) {
                try {
                    JSONObject obj = (JSONObject) it.next();
                    //只有是角色类型的才会返回
                    if (fightMsg.getInteger("type") != 10 &&
                            fightMsg.getInteger("type") != 11) {
                        if (obj.getInteger("type") == 0) {
                            ChannelSupervise.noticeClientByName(list, obj.getString("name"), "3010");
                        }
                    } else {
                        //论贱
                        final String n = obj.getString("name");
                        if (n.length() > 2 && (n.charAt(n.length() - 1) + "").equals("a")) {
                            ChannelSupervise.noticeClientByName(list, n.substring(0, n.length() - 2), "3010");
                        }
                    }
                    //判断其标记逃跑的必须移除
                    if (obj.getInteger("isTao") == 1) {
                        it.remove();
                    }
                } catch (Exception e) {
                    loggerUtils.error("doAction/while:" + e.getMessage(), this.getClass());
                }
            }
            //发送给观战人员
            fightUtils.noticeViewFightPlayerAction(id, list);
            //统计伤害
            countHurt(roleList, list, id);

            //System.out.println(JSON.toJSONString(list));
            //想反击、连击、援护等item里面还有item，所以要重新获取一次真实的长度
            int len = getRealActionLen(list);
            //战斗结束，清空缓存
            if (isEnd == 1) {
                //战斗奖励
                JSONObject fightMsgCopy = staticCollection.copyObj(fightMap.get(id));
                JSONObject roleMapCopy = staticCollection.copyObj(roleMap.get(id));

                //单次战斗伤害累计
                JSONObject hurt = staticCollection.copyObj(fightUtils.hurtMap.get(id));
                staticCollection.putTask(() -> {
                    try {
                        //战斗奖励
                        handleFightOverReward(fightMsgCopy, roleMapCopy, hurt, ac);
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                });
                list.clear();
                //命令转换成动作完成，清空命令
                orderMap.put(id, new JSONObject());
                //一个动作流程已经结束
                //onceActionDoing.put(id, false);
                empty(id);
                //System.err.println(id + "战斗结束！");
            } else {
                //System.err.println(JSON.toJSONString(list));
                //20s播放动画的时间，没播完也要启动菜单
                updateHuiheStartTime(false, id, len);
                //命令转换成动作完成，清空命令
                orderMap.put(id, new JSONObject());
                //一个动作流程已经结束 fixme:不能在这里结束，一定得在下一个回合开始后才显示
                //onceActionDoing.put(id, false);
            }
            list.clear();
            posKeys.clear();
        } catch (Exception e) {
            e.printStackTrace();
            loggerUtils.error("下达战斗指令时错误", this.getClass());
        }
    }

    /**
     * 处理战斗结束后的战斗奖励
     */
    public void handleFightOverReward(JSONObject fightMsg, JSONObject roleMap, JSONObject hurt, final action ac) {
        if (fightMsg == null) {
            return;
        }
        try {
            String projRootDir = fightMsg.getString("projRootDir");
            //System.err.println(fightMsg);
            String Id = fightMsg.getString("Id");
            Integer type = fightMsg.getInteger("type");
            JSONArray roleList = fightMsg.getJSONArray("roleList");
            //去除ai助战对象
            for (int i = 0; i < roleList.size(); i++) {
                JSONObject r = roleList.getJSONObject(i);
                if (r.getInteger("type") != 0) {
                    roleList.remove(i);
                    i--;
                }
            }
            //右方
            JSONArray rList = new JSONArray();
            //左方
            JSONArray lList = new JSONArray();
            for (Object r : roleList) {
                JSONObject rbj = (JSONObject) r;
                if (rbj.getInteger("type") == 0 && rbj.getString("posKey").contains("r")) {
                    rList.add(rbj.getString("name"));
                } else if (rbj.getInteger("type") == 0 && rbj.getString("posKey").contains("l")) {
                    lList.add(rbj.getString("name"));
                }
            }

            //补给包加血
            if (type != 2 && type != 10 && type != 11) {
                startBef.manService.handHp(roleMap, roleList);
            }

            //isSuccess=1表示r方胜利
            if (type == 0 || type == 1) {//普通怪、boss
                //根据怪物数量计算经验
                JSONArray monsterList = fightMsg.getJSONArray("monsterList");
                String key = ((JSONObject) monsterList.get(0)).getString("key");

                JSONObject data = new JSONObject();
                data.put("monsterKey", key);
                data.put("monsterNum", monsterList.size());
                rList.addAll(lList);
                data.put("names", rList);
                data.put("bpId", fightMsg.get("params"));
                data.put("projRootDir", projRootDir);
                startBef.fightOverService.handleMonster(Id, type, ac.isSuccess, data, hurt);
            } else if (type == 2) {//切磋

            } else if (type == 3) {//竞技
                startBef.fightOverService.handleJingji(Id, type, ac.isSuccess, rList, lList);
            } else if (type == 4) {//武状元
                //r增加队伍积分，win标记1；l标记为淘汰，win标记0
                startBef.fightOverService.handleWzy(Id, type, ac.isSuccess, fightMsg.getString("wzyId"));
            } else if (type == 5) {//抢壁
                startBef.fightOverService.handleQb(Id, type, ac.isSuccess, rList.getString(0), lList.getString(0));
            } else if (type == 6) {//大师兄海选
                JSONObject data = new JSONObject();
                data.put("rName", rList.get(0));
                data.put("lName", lList.get(0));
                startBef.fightOverService.handleDsx(Id, type, ac.isSuccess, rList.getString(0), lList.getString(0));
            } else if (type == 7) {//胜利方将从失败方背包中获取一个道具
                startBef.fightOverService.handleTx(Id, type, ac.isSuccess, rList, lList);
            } else if (type == 8) {//帮战
                startBef.fightOverService.handleBz(Id, type, ac.isSuccess, rList, lList, fightMsg.getJSONObject("params"));
            } else if (type == 9) {//跑商抢夺
                startBef.fightOverService.handleQd(Id, type, ac.isSuccess, rList, lList);
            } else if (type == 10) {
            } else if (type == 11) {
            } else if (type == 12) {//江湖追杀
                startBef.fightOverService.handleZsl(Id, type, ac.isSuccess, rList, lList, fightMsg.getJSONObject("params"));
            } else if (type == 13) {//逮捕魔头
                startBef.fightOverService.handleCatchMt(Id, type, ac.isSuccess, rList, lList);
            } else if (type == 14) {

            } else if (type == 15) {

            } else if (type == 16) {

            } else if (type == 17) {//王侯将相
                startBef.fightOverService.handleWHJX(Id, type, ac.isSuccess, rList.get(0).toString(), lList.get(0).toString());
            } else if (type == 18) {//百炼妖塔
                startBef.fightOverService.handleBLYT(Id, type, ac.isSuccess, rList);
            } else if (type == 19) {//成王败寇
                startBef.fightOverService.handleCWBK(Id, type, ac.isSuccess, rList.get(0).toString(), fightMsg.getString("params"));
            } else if (type == 20) {//

            } else if (type == 21) {//境界心魔
                startBef.fightOverService.handleJJXM(Id, type, ac.isSuccess, rList.get(0).toString());
            } else if (type == 22) {//斗战封神榜
                JSONArray monsterList = fightMsg.getJSONArray("monsterList");
                startBef.fightOverService.handleDzfsb(Id, type, ac.isSuccess, rList, monsterList);
            } else if (type == 23) {//血腥之地
                startBef.fightOverService.handleXXZD(Id, type, ac.isSuccess, rList, lList);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

    }

    /**
     * 判断玩家是否有某些技能
     */
    private boolean isGetSkillByKeys(String id, String control, String... keys) {
        JSONObject attr = getAttrByPosKey(id, control);
        JSONArray sklList = attr.getJSONArray("skill");
        int n = 0;
        for (String k : keys) {
            for (Object obj : sklList) {
                JSONObject o = (JSONObject) obj;
                if (o.getString("key").equals(k)) {
                    n++;
                    break;
                }
            }
        }
        if (n == keys.length) {
            return true;
        }
        return false;
    }


    /**
     * 统计伤害数值
     */
    public void countHurt(JSONArray roleList, List<action> list, String id) {
        for (action ac : list) {
            if (ac.control == null) continue;
            String name = null;
            for (Object o : roleList) {
                JSONObject r = (JSONObject) o;
                if (r.getString("posKey").equals(ac.control)) {
                    name = r.getString("name");
                    break;
                }
            }
            if (name == null) continue;
            //累加伤害
            for (actionItem item : ac.actionItems) {
                if (item.value != null && item.value < 0) {
                    JSONObject res = fightUtils.hurtMap.get(id);
                    if (res.get(name) == null) {
                        res.put(name, 0);
                    }
                    res.put(name, res.getInteger(name) + item.value);
                }
            }
        }
    }

    /**
     * 战斗胜利、失败
     * 返回结束动作
     */
    public action getEndAction(String id) {
        action ac = null;
        if (isZero(id, 0)) {//胜利 (r方)
            ac = new action(1);
        }
        if (isZero(id, 1)) {//失败
            ac = new action(0);
        }
        //大于60回合就结束
        if (fightMap.get(id).getInteger("huihe") > 60) {
            ac = new action(0);
        }
        return ac;
    }


    /**
     * 动作执行前处理
     * 判断是否再继续往下执行
     */
    public boolean actionStartBeforeBuffHandle(String id, String target, List<action> list) throws Exception {
        action ac = new action(target, null);
        float r = buffTriggerHandle.getOne().actionStartBeforeTriggerBuff(id, target, target, list, ac);
        if (r < 0) {//存在不继续向下执行的buff时（蛊、休息等）
            list.add(ac);
            return false;
        }
        return true;//允许后续步骤进行
    }


    /**
     * 将buff有效回合置为指定数
     */
    private void resetBuffHuihe(int huihe, Vector<buff> buffList, String name, int statusType) {
        synchronized (buffList) {
            for (buff b : buffList) {
                if (b.target.equals(name) && b.statusType == statusType) {
                    b.bindEffectRule(huihe, null, null);
                    break;
                }
            }
        }

    }


    /**
     * 递归移除
     */
    private synchronized void removeListOne(int i, Vector<buff> buffList, String name, int statusType) {
        if (i >= buffList.size()) {
            return;
        }
        buff b = buffList.get(i);
        if (b.target.equals(name) && b.statusType == statusType) {
            buffList.remove(i);
        } else {
            i++;
        }
        this.removeListOne(i, buffList, name, statusType);
    }


}

