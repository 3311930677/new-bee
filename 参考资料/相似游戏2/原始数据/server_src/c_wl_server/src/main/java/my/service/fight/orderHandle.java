package my.service.fight;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.fightUtils.fightUtils;
import my.gameUtils.skillUtils;
import my.gameUtils.sysSettingUtils;
import my.model.ChannelSupervise;
import my.model.skill;
import my.model.skillItem;
import my.model.skillItemTxRule;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.strUtils;
import my.utils.systemUtils;

import java.util.ArrayList;
import java.util.List;

import static my.fightUtils.fightBuffHandUtils.isInBuff;
import static my.fightUtils.fightUtils.*;
import static my.model.skillItemRuleType.AttackRule;

/**
 * 命令相关的处理
 */
public class orderHandle {
    private static orderHandle one;

    public static orderHandle getOne() {
        if (one == null) one = new orderHandle();
        return one;
    }

    /**
     * 获取一个指令
     */
    public JSONObject getOrder(String id, String control) {
        return getOrder(id, control, null, null);
    }

    public JSONObject getOrder(String id, String control, JSONObject skl, String target) {
        //{"uploadOrder":{"r0":{"action":0,"control":"r0","target":"l0"}},"Id":"1634628574251496"}
        JSONObject j1 = new JSONObject();
        j1.put(control, getOrderAction(control, skl, target));
        JSONObject j2 = new JSONObject();
        j2.put("uploadOrder", j1);
        j2.put("Id", id);
        return j2;
    }

    public JSONObject getOrderAction(String control, JSONObject skl, String target) {
        JSONObject j = new JSONObject();
        j.put("action", (skl != null ? 1 : 0) + "");
        j.put("control", control);
        //目标为null就默认给一个
        if (target == null) {
            target = (control.contains("r") ? "l" : "r") + "0";
        }
        j.put("target", target);
        if (skl != null) {
            j.put("skill", skl);
        }
        return j;
    }

    /**
     * 自动生成命令
     */
    public void createOrder(String id, String control) {
        //todo：先判断玩家施法方式 智能、固定（前端设定，掉线后就使用智能）

        //先生成宠物的指令，不然在不带宠物的情况下会导致战斗结束了再去生成宠物指令，这样里面的缓存会找不到
        //根据站位得到宠物站位
        JSONObject r = fightUtils.getPetByControl(id, control);
        //判断是否存在该站位
        if (r != null) {
            addOrderToPosKeyObj(id, r);
        }
        //角色站位
        JSONObject me = fightUtils.getTargetByPosKey(id, control);
        String name = me.getString("name");
        int res = addOrderToPosKeyObj(id, me);
        //标记该玩家为自动战斗
        if (res == 1) {
            if (name != null) sysSettingUtils.setAutoFight(name, 1);
        }
        //这里只需要生成宠物+玩家的指令，putOrder里面生成伙伴的指令

    }

    /**
     * 为站位对象生成指令
     */
    private int addOrderToPosKeyObj(String id, JSONObject posKeyObj) {
        String posKey = posKeyObj.getString("posKey");
        JSONObject shifa = posKeyObj.getJSONObject("shifaWay");
        if (shifa.getInteger("way") == 0) {
            //智能选取
            JSONObject res = skillHandle.getOne().getAllowSkillKey(id, posKey);
            JSONObject skl = res.getJSONObject("skl");
            String target = res.getString("target");
            if (systemUtils.isWindows()) {
                System.err.println("智能施法：" + skl + " / " + target);
            }
            return putOrder(getOrder(id, posKey, skl, target));
        } else {
            //根据设定的来选
            JSONArray skls = null;
            int roleType = posKeyObj.getInteger("type");
            if (roleType == 0) {
                skls = shifa.getJSONArray("role_skls");
            } else if (roleType == 1) {
                skls = shifa.getJSONArray("pet_skls");
            } else {
                System.err.println("出现既不是人物也不是宠物的东西");
            }
            //判断技能是否冷却或是否满足释放条件，满足的就选定
            JSONObject res = skillHandle.getOne().getAllowSkillKey(id, posKey, skls);
            JSONObject skl = res.getJSONObject("skl");
            String target = res.getString("target");
            if (systemUtils.isWindows()) {
                System.err.println("固定施法：" + skl + " / " + target);
            }
            return putOrder(getOrder(id, posKey, skl, target));
        }
    }

    /**
     * 上传命令
     * 都由客户端上传命令，当客户端不在线时自动补足
     * fixme 注意不要让该接口连续调用
     * 有些玩家网络延迟导致一个已经不存在的玩家发送位置
     * 占用了其他玩家位置致使提前执行doAction
     */
    public Integer putOrder(JSONObject j) {
        try {
            //System.err.println("上传命令：\n"+j);
            //{"uploadOrder":{"r0":{"action":0,"control":"r0","target":"l0"}},"Id":"1634628574251496"}
            String id = j.getString("Id");
            // 判断所有玩家是否都已经上传了指令
            JSONObject order = orderMap.get(id);
            if (order == null) {
                return 0;
            }
            //当命令已经全部下达，就不允许再上传，否则会导致doAction调用多次
            Boolean b = onceActionDoing.get(id);
            if (b == null || b) {
                return 0;
            }
            JSONObject uploadOrder = j.getJSONObject("uploadOrder");
            //过滤错误数据
            if (uploadOrder == null || uploadOrder.keySet().size() == 0) {
                return 0;
            }
            for (String up : uploadOrder.keySet()) {
                //下达命令者为null，出现该情况立即移除
                if (strUtils.isNull(up)) {
                    uploadOrder.remove(up);
                    break;
                }
                //逃跑是不需要目标的
                JSONObject obj = uploadOrder.getJSONObject(up);
                if (obj == null) {
                    loggerUtils.error("站位出现null:" + up + "/" + j, this.getClass());
                }
                if (obj.get("action") == null) {
                    //no skill、action、control，只有一个target
                    loggerUtils.error("action出现null:" + up + "/" + j, this.getClass());
                    continue;
                }
                if (obj.getInteger("action") != 2 && obj.get("target") == null) {
                    continue;
                }

                //封装成{id,posKey:{action,control,target}}
                //todo bug 战斗结束后客户端又上传了指令 pk时
                if (!b) {
                    order.put(up, obj);
                    //玩家位置 0 1 2 3 4号位
                    //通知已经收到指令，沙漏可以不显示了
                    if (up.contains("0") || up.contains("1") || up.contains("2")
                            || up.contains("3") || up.contains("4")) {
                        //通知对战的所有客户端
                        JSONObject fg = fightMap.get(id);
                        JSONObject res = new JSONObject();
                        res.put("posKey", up);
                        res.put("status", 1);
                        JSONArray roleList = fg.getJSONArray("roleList");
                        for (Object r : roleList) {
                            JSONObject one = (JSONObject) r;
                            //玩家
                            if (one.getInteger("type") == 0) {
                                ChannelSupervise.noticeClientByName(res, one.getString("name"), "3011");
                            }
                        }
                        //通知观战人员
                        fightUtils.noticeViewFightPlayerClearShaLou(id, res);
                    }

                }
            }
            //需要获取所有站位信息，拿到玩家跟pet的站位，再对比上传命令的站位是否都已经有了

            //判断order长度是否跟玩家列表的长度一致
            //所有未逃跑玩家命令已经下达（宠物+玩家，不包含伙伴）
            if (!b && getNoTaoPlayer(id).size() == order.keySet().size()) {
                //关闭超时命令下达任务,并移除 bug下一回合还没开启就已经上传命令导致这里报错
                onceActionDoing.put(id, true);
                //移除超时
                overTimeOrderMap.remove(id);
                //清理接收动画播放完成的指令
                amPlayedOrderMap.get(id).clear();
                //根据站位获取伙伴站位，主控方才能获取
                List<JSONObject> rs = getHuobanList(id, "r");
                for (int i = 0; i < rs.size(); i++) {
                    JSONObject r1 = rs.get(i);
                    //todo:需要生成技能
                    putOrder(orderHandle.getOne().getOrder(id, r1.getString("posKey"), null, null));
                }
                //todo bug：有玩家的order为null也执行了？
                startBef.fightService.doAction(id);
            }
            return 1;
        } catch (Exception e) {
            e.printStackTrace();
            loggerUtils.error("putOrder错误：" + e.getMessage(), this.getClass());
            //todo 通知玩家重新下达命令

        }
        return 0;
    }

    /**
     * 接收取消自动的命令
     */
    public void putCancelAutoOrder(JSONObject j) {
        try {
            //Id、control
            String id = j.getString("Id");
            if (!fightMap.containsKey(id)) return;
            String control = j.getString("control");
            String name = fightUtils.getRoleNameByRole(id, control);
            sysSettingUtils.setAutoFight(name, 0);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 接收自动的命令
     */
    public void putAutoOrder(JSONObject j) {
        try {
            //Id、control
            String id = j.getString("Id");
            if (!fightMap.containsKey(id)) return;
            String control = j.getString("control");
            createOrder(id, control);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 上传玩家动画播放完成的指令
     */
    public void putAmPlayedOrder(JSONObject j) {
        try {
            //出现玩家断线的情况就靠定时器来判断是否开启下一回合
            String id = j.getString("Id");
            if (!fightMap.containsKey(id)) return;
            String control = j.getString("control");
            JSONObject a = amPlayedOrderMap.get(id);
            a.put(control, 1);
            //当所有玩家的指令都接收完毕后将等待延时设置为0，让定时其判断完结
            if (isAmPlayedOrderRecDone(id, a)) {
                //System.out.println("所有前端动画都播放完毕！");
                if (huiheStartMap.containsKey(id)) {
                    huiheStartMap.put(id, 0L);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 生成怪物指令
     *
     * @param id
     */
    public void createMonsterOrder(String id) throws Exception {
        JSONObject fightMsg = fightMap.get(id);
        JSONArray monsterList = fightMsg.getJSONArray("monsterList");
        for (Object o : monsterList) {
            JSONObject mon = (JSONObject) o;
            String posKey = mon.getString("posKey");

            JSONObject res = skillHandle.getOne().getAllowSkillKey(id, posKey);
            JSONObject skl = res.getJSONObject("skl");
            String target = res.getString("target");
            if (target == null) target = getRandomTarget(id, "r");
            if (target == null) target = "r0";
            if (systemUtils.isWindows()) {
                System.err.println("怪物施法：" + skl + " / " + target);
            }
            JSONObject j = getOrderAction(posKey, skl, target);
            //{id,posKey:{action,control,target}}
            /*JSONObject j = new JSONObject();
            j.put("action", 0);
            if (posKey == null) {
                loggerUtils.error("createMonsterOrder 出现目标为null:", this.getClass());
            }
            j.put("control", posKey);
            //当玩家因中毒等效果导致全部死亡时，目标为null
            j.put("target", getRandomTarget(id, "r"));
            if (j.get("target") == null) {
                j.put("target", "r0");//默认目标
            }*/


            /*JSONObject skill = getMonsterSkill(id, posKey, j);
            if (skill != null) {
                j.put("action", 1);
                j.put("skill", skill);
                my.model.skill skl = skillUtils.getInstance().getSkill(skill.getString("key"));
                skillItemTxRule attackRule = skl.skillItems.get(0).getTxRule(AttackRule);
                if (attackRule != null) {
                    if (attackRule.paramBool) {//转回血技能
                        //目标改为自己
                        j.put("target", posKey);
                    }
                }
                //System.err.println("选举技能："+skill);
            }*/
            JSONObject r = orderMap.get(id);
            r.put(posKey, j);
            orderMap.put(id, r);
        }
    }

    /**
     * 选择怪物技能 {lever,key}
     */
    public JSONObject getMonsterSkill(String id, String posKey, JSONObject order) {
        JSONObject skl = null;
        JSONObject obj = getTargetByPosKey(id, posKey);
        JSONObject one = getOneMonsterByPosKey(id, obj.getString("posKey"));
        if (one != null) {
            JSONArray sklList = one.getJSONArray("skill");
            if (sklList.size() > 0) {//存在技能，并且要求statuType==012
                List<skill> list = new ArrayList<>();
                //先判是否存在复活技能，存在则判断是否存在死亡的怪物，存在则复活他
                for (Object o : sklList) {
                    JSONObject j = (JSONObject) o;
                    if (!j.containsKey("key")) continue;
                    skill skill = skillUtils.getInstance().getSkill(j.getString("key"));
                    //一些加属性的技能为null
                    if (skill == null || skillHandle.getOne().isCool(id, posKey, skill.key, false) ||
                            skill.skillItems == null) continue;
                    for (skillItem item : skill.skillItems) {
                        //拥有复活技能,判断同站位方的是否有死亡
                        String newPosKey = null;
                        if (item.statusType == 13 && (newPosKey = getDiePosByPosKey(id, posKey)) != null) {
                            list.add(skill);
                            order.put("target", newPosKey);
                            break;
                        }
                    }
                }
                //判断是否有加血技能，有则判断怪物是否低于30%血量，有则加血
                if (list.size() == 0) {
                    for (Object o : sklList) {
                        JSONObject j = (JSONObject) o;
                        if (!j.containsKey("key")) continue;
                        skill skill = skillUtils.getInstance().getSkill(j.getString("key"));
                        //一些加属性的技能为null
                        if (skill == null || skill.skillItems == null) continue;
                        if (skill.skillItems.size() > 1 && skill.skillItems.get(0).statusType == 0 &&
                                skill.skillItems.get(1).statusType == 5 && isNeedXue(id, posKey)) {
                            list.add(skill);
                            break;
                        }
                    }
                }
                //根据自身是否存在buff来给
                if (list.size() == 0) {
                    for (Object o : sklList) {
                        JSONObject j = (JSONObject) o;
                        String sklKey = j.getString("key");

                        if (sklKey.equals("3006") &&
                                !isInBuff(id, posKey, "3006")) {
                            //是否存在狂龙吼，存在就使用
                            skill skill = skillUtils.getInstance().getSkill(sklKey);
                            //一些加属性的技能为null
                            if (skill == null) continue;
                            list.add(skill);
                            order.put("target", posKey);
                            break;
                        } else if (sklKey.equals("3014") &&
                                !isInBuff(id, posKey, "3014")) {
                            //是否存在玄武护体，存在就使用
                            skill skill = skillUtils.getInstance().getSkill(sklKey);
                            //一些加属性的技能为null
                            if (skill == null) continue;
                            list.add(skill);
                            order.put("target", posKey);
                            break;
                        } else if (sklKey.equals("3028") &&
                                !isInBuff(id, posKey, "3028")) {
                            //是否存在魔音壁，存在就使用
                            skill skill = skillUtils.getInstance().getSkill(sklKey);
                            //一些加属性的技能为null
                            if (skill == null) continue;
                            list.add(skill);
                            order.put("target", posKey);
                            break;
                        } else if (sklKey.equals("3037") &&
                                !isInBuff(id, posKey, "3037")) {
                            //是否存在凝钢决，存在就使用
                            skill skill = skillUtils.getInstance().getSkill(sklKey);
                            //一些加属性的技能为null
                            if (skill == null) continue;
                            list.add(skill);
                            order.put("target", posKey);
                            break;
                        } else if (sklKey.equals("3041") || sklKey.equals("3042") ||
                                sklKey.equals("3043") || sklKey.equals("3040")) {
                            if (skillHandle.getOne().isCool(id, posKey, sklKey, false)) {
                                continue;
                            }
                            skill skill = skillUtils.getInstance().getSkill(sklKey);
                            //一些加属性的技能为null
                            if (skill == null) continue;
                            list.add(skill);
                            order.put("target", "r0");
                        } else if (sklKey.equals("3045") &&
                                !isInBuff(id, posKey, "3045")) {
                            //是否存在逆天转命，存在就使用
                            skill skill = skillUtils.getInstance().getSkill(sklKey);
                            //一些加属性的技能为null
                            if (skill == null) continue;
                            list.add(skill);
                            order.put("target", posKey);
                            break;
                        } else if (sklKey.equals("3064") &&
                                !isInBuff(id, posKey, "3064") &&
                                !skillHandle.getOne().isCool(id, posKey, sklKey, false)) {
                            //todo 会一直使用？
                            //是否存在真武御体，存在就使用
                            skill skill = skillUtils.getInstance().getSkill(sklKey);
                            //一些加属性的技能为null
                            if (skill == null) continue;
                            list.add(skill);
                            order.put("target", posKey);
                            break;
                        }

                    }

                }
                //其他攻击技能
                if (list.size() == 0) {
                    for (Object o : sklList) {
                        JSONObject j = (JSONObject) o;
                        if (!j.containsKey("key")) continue;
                        skill skill = skillUtils.getInstance().getSkill(j.getString("key"));
                        //一些加属性的技能为null
                        if (skill == null || skill.skillItems == null) continue;
                        for (skillItem item : skill.skillItems) {
                            //要求场上还有角色才允许释放
                            if ((item.statusType == 18 || item.statusType == 47)
                                    && isPlayerExist(id)) {
                                list.add(skill);
                                break;
                            }
                            if (item.statusType == 0) {
                                list.add(skill);
                                break;
                            }
                        }
                        //已经选出了
                        if (list.size() > 0) {
                            break;
                        }
                    }
                }

                if (list.size() > 0) {
                    //从可执行的技能列表中挑选一个技能进行执行
                    int i = strUtils.getRandom(0, list.size());
                    skl = new JSONObject();
                    skl.put("key", list.get(i).key);
                    for (Object o : sklList) {
                        JSONObject j = (JSONObject) o;
                        if (j.getString("key").equals(skl.getString("key"))) {
                            skl.put("lv", j.getInteger("lv"));
                            break;
                        }
                    }
                }
            }
        }

        return skl;
    }

    /**
     * 修正输入的技能等级，当技能不存在时返回false
     */
    public boolean fixPlayerOrder(String id, JSONObject playerOrder) {
        String control = playerOrder.getString("control");
        JSONObject s = playerOrder.getJSONObject("skill");
        //判断该技能是否为主动触发，不是的就返回false
        skill skl = skillUtils.getInstance().getSkill(s.getString("key"));
        if (skl == null || skl.triggerType != 0) {
            System.err.println("fixPlayerOrder选择一个非主动触发的技能/ key:" + s.getString("key") + " / " + playerOrder.toString());
            return false;
        }

        JSONObject attr = getAttrByPosKey(id, control);
        JSONArray sklList = attr.getJSONArray("skill");
        for (Object obj : sklList) {
            JSONObject o = (JSONObject) obj;
            if (o.getString("key").equals(s.getString("key"))) {
                //修正lv
                s.put("lv", o.get("lv"));
                return true;
            }
        }
        return false;
    }

    /**
     * 获取一方的伙伴
     * 要求控制者为队长
     */
    private List<JSONObject> getHuobanList(String id, String control) {
        //左方或者右方
        String t = control.charAt(0) + "";
        List<JSONObject> arr = new ArrayList<>();
        JSONObject fightMsg = fightMap.get(id);
        JSONArray list = fightMsg.getJSONArray("roleList");
        for (Object l : list) {
            JSONObject j = (JSONObject) l;
            //要求是主控方才允许获取
            if (j.get("captain") == null || j.getInteger("captain") != 1) {
                continue;
            }
            if (j.getString("posKey").contains(t) &&
                    j.getInteger("type") == 4) {
                arr.add(j);
            }
        }
        return arr;
    }

    /**
     * 过滤错误的order
     */
    public void filterErrorOrder(String id) {
        JSONObject order = orderMap.get(id);
        for (String posKey : order.keySet()) {
            if (strUtils.isNull(posKey)) {
                order.remove(posKey);
            }
        }
    }
}
