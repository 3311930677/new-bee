package my.service.fight;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.fightUtils.fightUtils;
import my.gameUtils.sysSettingUtils;
import my.model.ChannelSupervise;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;

import java.util.concurrent.TimeUnit;

import static my.fightUtils.fightUtils.*;
import static my.fightUtils.fightUtils.empty;

/**战斗相关的定时任务*/
public class fixedTimeTaskHandle {
    private static fixedTimeTaskHandle one;

    public static fixedTimeTaskHandle getOne() {
        if (one == null) one = new fixedTimeTaskHandle();
        return one;
    }
    public void startTask(){
        //定时战斗超时处理\清理下线
        fightOverTime();
    }
    /**
     * 超时命令监听\回合开始菜单绘制
     */
    private static boolean fightOverTimeIsHandleOver = true;//对每次执行战斗超时处理完成标志

    private void fightOverTime() {
        //fixme:有可能循环未处理完就到时间执行下一轮了
        staticCollection.putTask(() -> {
            try {
                if (!fightOverTimeIsHandleOver) return;
                //表示该过程正在处理中
                fightOverTimeIsHandleOver = false;
                long now = strUtils.getTime();
                //对于下线的处理
                for (String id : fightMap.keySet()) {
                    JSONObject obj = fightMap.get(id);
                    if (obj == null) {
                        empty(id);
                        continue;
                    }

                    JSONArray roleList = obj.getJSONArray("roleList");
                    if (roleList == null) {
                        empty(id);
                        continue;
                    }
                    //先过滤错误的order
                    orderHandle.getOne().filterErrorOrder(id);
                    int num = 0;
                    for (Object r : roleList) {
                        JSONObject rj = (JSONObject) r;
                        //要求是人物离线
                        if (rj.getInteger("type") == 0 && !staticCollection.userIsOnline(rj.getString("name"))) {
                            //对方已经离线则自动下达命令，所控制的宠物也自动下达命令（clientId）
                            for (Object t : roleList) {
                                JSONObject tj = (JSONObject) t;
                                if (tj.getString("clientId").equals(rj.getString("clientId"))) {
                                    num++;
                                    JSONObject order = orderHandle.getOne().getOrder(id, tj.getString("posKey"));
                                    Boolean b = onceActionDoing.get(id);
                                    if (b != null && !b) {
                                        orderHandle.getOne().putOrder(order);
                                    }
                                }
                            }
                        }
                    }
                    if (num == roleList.size()) {
                        //按类型做处理
                        int type = obj.getInteger("type");
                        if (type == 4) {//武状元
                            //标记弃权
                            startBef.wzyService.markLoser(obj.getString("Id"), 3);
                        } else if (type == 6) {//大师兄
                            startBef.dsxService.markLoser2(obj.getString("Id"));
                        }
                        empty(id);
                    }
                }
                //命令超时，执行动作
                for (String id : overTimeOrderMap.keySet()) {
                    //处理超时
                    if (now - overTimeOrderMap.get(id) > 30 * 1000L) {
                        //System.err.println("超时id："+id);
                        overTimeOrderMap.remove(id);
                        staticCollection.putTask(() -> {
                            try {
                                JSONObject fightMsg = fightMap.get(id);
                                if (fightMsg == null) {
                                    return;
                                }
                                //控制客户端将菜单隐藏、对象不能点击，变成自动
                                JSONArray list = fightMsg.getJSONArray("roleList");
                                /*for (Object l : list) {
                                    JSONObject r = (JSONObject) l;
                                    if (r.getInteger("type") != 0) {
                                        continue;
                                    }
                                    //通知客户端时间到了,隐藏菜单
                                    ChannelSupervise.noticeClientByName(null, r.getString("name"), "3004");
                                }*/
                                JSONObject playerOrder = orderMap.get(id);
                                //先将null控制者移除
                                orderHandle.getOne().filterErrorOrder(id);
                                synchronized (playerOrder) {
                                    //对没有下达命令的玩家下达命令
                                    for (Object l : list) {
                                        JSONObject r = (JSONObject) l;
                                        if (r.getInteger("type") != 0 && r.getInteger("type") != 1) continue;
                                        //判断谁没有下达命令，只下达宠物、人物的命令，伙伴的不需要，putOrder里面会判断
                                        if (playerOrder.get(r.getString("posKey")) == null) {
                                            JSONObject order = orderHandle.getOne().getOrder(id, r.getString("posKey"));
                                            //System.err.println(order);
                                            int res = 0;

                                            if (!onceActionDoing.get(id)) {
                                                //当回合战斗未开始才会生成命令
                                                res = orderHandle.getOne().putOrder(order);
                                                //通知变更为自动状态
                                                if (res == 1 && r.getInteger("type") == 0) {
                                                    sysSettingUtils.setAutoFight(r.getString("name"), 1);
                                                    ChannelSupervise.noticeClientByName(null, r.getString("name"), "3006");
                                                }
                                            }
                                        }
                                    }
                                }
                            } catch (Exception e) {
                                e.printStackTrace();
                                loggerUtils.error("战斗超时异常：" + e.getMessage() + " / fgMsg:" + fightMap.get(id) + " / order:" + orderMap.get(id), this.getClass());
                            }

                        });
                    }
                }
                //回合开始，显示菜单
                for (String id : huiheStartMap.keySet()) {
                    if (now - huiheStartMap.get(id) > 0) {
                        huiheStartMap.remove(id);
                        staticCollection.putTask(() -> {
                            try {
                                //fixme 注意战斗结束后就不能再去调3009了。所以先判断战斗是否存在
                                if (fightMap.get(id) == null) {
                                    return;
                                }
                                //一个动作是否在执行
                                onceActionDoing.put(id, false);

                                JSONObject fightMsg = fightMap.get(id);
                                //当前系统时间,不在是30s
                                fightMsg.put("time", strUtils.getTime() + 30 * 1000);
                                fightMsg.put("huihe", fightMsg.getInteger("huihe") + 1);
                                JSONObject obj = new JSONObject();
                                obj.put("time", fightMsg.get("time"));
                                obj.put("huihe", fightMsg.get("huihe"));
                                //必须冷却先--再发送给客户端
                                skillHandle.getOne().cutSkillCool(id);
                                //开启超时
                                //System.out.println("=========================开启超时："+fightMsg.getInteger("huihe"));
                                overTimeOrderMap.put(id, strUtils.getTime());
                                //System.err.println("开启超时："+id);
                                //获取玩家和宠物站位的冷却技能
                                JSONObject coolMap = skillHandle.getOne().getPlayerCool(id);
                                //通知前端可以显示菜单了
                                JSONArray list = fightMsg.getJSONArray("roleList");
                                for (Object l : list) {
                                    JSONObject r = (JSONObject) l;
                                    if (!fightUtils.isLunjianFight(fightMsg)) {
                                        if (r.getInteger("type") != 0) {
                                            continue;
                                        }
                                        //将冷却的技能发送给客户端
                                        obj.put("coolList", coolMap.get(r.getString("posKey")));
                                        ChannelSupervise.noticeClientByName(obj, r.getString("name"), "3009");
                                    } else {
                                        //论贱
                                        final String n = r.getString("name");
                                        //name至少3位
                                        if (n.length() > 2 && (n.charAt(n.length() - 1) + "").equals("a")) {
                                            obj.put("coolList", coolMap.get(r.getString("posKey")));
                                            ChannelSupervise.noticeClientByName(obj, n.substring(0, n.length() - 2), "3009");
                                        }
                                    }

                                }
                                //3s后判断自动战斗
                                autoFightTimeMap.put(id, now);
                                fightUtils.noticeViewFightPlayerDjs(id,obj);
                            } catch (Exception e) {
                                loggerUtils.error("回合开始时报错:" + e.getMessage(), this.getClass());
                            }
                        });
                    }
                }
                //延时1秒后执行判断是否自动战斗
                for (String id : autoFightTimeMap.keySet()) {
                    if (now - autoFightTimeMap.get(id) > 1000) {
                        autoFightTimeMap.remove(id);
                        staticCollection.putTask(() -> {
                            try {
                                if (fightMap.get(id) == null) {
                                    return;
                                }
                                JSONObject fightMsg = fightMap.get(id);
                                JSONArray list = fightMsg.getJSONArray("roleList");
                                for (Object l : list) {
                                    JSONObject r = (JSONObject) l;
                                    String name = getRoleNameByRole(fightMsg, r);
                                    if (name != null && sysSettingUtils.isAutoFight(name)) {
                                        JSONObject od = new JSONObject();
                                        od.put("Id", id);
                                        od.put("control", r.getString("posKey"));
                                        orderHandle.getOne().putAutoOrder(od);
                                    }

                                }

                            } catch (Exception e) {
                                e.printStackTrace();
                            }
                        });

                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }finally {
                //该过程已经处理完毕
                fightOverTimeIsHandleOver = true;
            }
        }, 2, 2, TimeUnit.SECONDS);
    }

}
