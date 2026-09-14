package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.jsonMapper;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * 监狱
 * 对比进入监狱的差值，大于30分钟的可以释放，不需要累计时长
 */
public class prisonService {
    /**
     * 判断是否有通缉任务并且通缉的对象是否一致
     */
    public boolean isTongJiObj(String name, String playerName, DefaultSqlSession con) {
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getTongji(name);
        if (list.size() == 0) return false;
        JSONObject a = list.get(0);
        //超时
        if (strUtils.getTime() - a.getLong("created") > 24 * 60 * 60 * 1000) return false;
        //逮捕的对象不一致
        if (!a.getString("tj_name").equals(playerName)) return false;
        return true;
    }

    /**
     * 放弃通缉任务
     */
    public result cancelTask(@paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        boolean b = activityMapper.remTongji(name);
        if (b) return new result(200, 1);
        return new result(1016);
    }

    /**
     * 通缉任务（对于有通缉任务的玩家允许在主城进行偷袭，同时不扣除善恶值）
     */
    public result gainTask(@paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //验证是否已经接取
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = activityMapper.getTongji(name);
        if (list.size() != 0) {
            return new result(200, backTongJiObj(list, con));
        }
        //随机取一个，允许通缉对象为同一个，首先完成的有奖励，后续任务将失效
        List<JSONObject> al = jsonMapper.selectLvOrderSezE();
        if (al.size() == 0) return new result(1017);//无对象可通缉
        Collections.shuffle(al);
        activityMapper.addTongji(name, al.get(0).getString("name"), strUtils.getTime() + "");
        list = activityMapper.getTongji(name);
        return new result(200, backTongJiObj(list, con));
    }

    private JSONObject backTongJiObj(List<JSONObject> list, DefaultSqlSession con) {
        //返回通缉人
        JSONObject res = list.get(0);
        res.remove("name");
        //在线情况，对方所在地图，对方恶人榜是否存在
        String tjName = res.getString("tj_name");
        boolean b = staticCollection.userIsOnline(tjName);
        res.put("isOnline", b ? 1 : 0);
        if (b) {
            res.put("mapKey", staticCollection.getMapKey(tjName));
        }
        long created = res.getLong("created");
        if (strUtils.getTime() - created > 24 * 60 * 60 * 1000) {
            res.put("isOver", 1);//过期
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> al = jsonMapper.selectLvOrderSezEByName(tjName);
        if (al.size() == 0) {
            res.put("isFinish", 1);//被其他玩家率先完成
        }
        return res;
    }

    /**
     * 使用扬善令牌
     */
    public int useYangShan(String name, DefaultSqlSession con) {
        //每次善恶值+1
        startBef.manService.updateSez(name, 1, con);
        JSONObject msg = startBef.manService.getMsgData(name, con);
        int sez = msg.getInteger("sez");
        if (sez >= 0) {
            //并不会改变坐牢的状态，只是不会被天兵追捕
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            //天兵也要删除
            activityMapper.remTianbing(name);
        }
        return 1;
    }

    /**
     * 贿赂
     */
    public result huilu(@paramsAnno(key = "user") user user,
                        @paramsAnno(key = "con") DefaultSqlSession con) throws Exception {
        final String name = user.name;
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000223", 1, name, con) != 1) {
            return new result(0);
        }
        //恢复平民身份，这里面会自动删除魔头榜单
        startBef.manService.replaceSez(name, 5, con);
        clearPrison(name, con);
        return new result(200, 1);
    }

    /**
     * 清除坐牢的相关数据
     */
    private void clearPrison(String name, DefaultSqlSession con) {
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        //删除坐牢
        activityMapper.delPrison(name);
        //天兵也要删除
        activityMapper.remTianbing(name);
    }

    /**
     * 判断累计坐牢时长是否已经超过30分钟
     */
    public boolean isOver30Min(String name, DefaultSqlSession con) {
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getPrisonOne(name);
        if (list.size() == 0) {
            return true;
        }
        Long online = startBef.logService.getOnlineTime(name, con);
        if (online == null) {
            return true;
        }
        long end = strUtils.getTime();
        //当前时间-上线时间+之前累计的时长=下线时累计的时长
        long accu = end - online + list.get(0).getLong("total");
        //30分钟牢
        if (accu > 1000 * 60 * 30) {
            //身份调整为平民
            startBef.manService.replaceSez(name, 5, con);
            clearPrison(name, con);
            return true;
        } else {
            activityMapper.updatePrison(name, accu + "");
        }
        return false;
    }

    /**
     * 下线时更新坐牢总时长
     */
    public void updateTotal(String name) {
        staticCollection.putTask(() -> {
            DefaultSqlSession con = null;
            try {
                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                isOver30Min(name, con);
                mybatisConfig.commit(con);
            } catch (Exception e) {
                e.printStackTrace();
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        });
    }

    /**
     * 跑商抢夺结果的处理
     */
    public Integer qdResult(Integer w, JSONArray r, JSONArray l) {
        //发生道具窃取
        List<Integer> rIndex = backShuffleList(r.size());
        List<Integer> lIndex = backShuffleList(l.size());
        //取最小的长度
        int len = rIndex.size() > lIndex.size() ? lIndex.size() : rIndex.size();
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            if (w == 1) {
                //r方胜利
                //l方将有几率扣除道具给r方
                for (int i = 0; i < len; i++) {
                    String rName = (String) r.get(rIndex.get(i));
                    String lName = (String) l.get(lIndex.get(i));
                    //l方将物品转移到r方
                    startBef.gangsService.psGoodsToElse(lName, rName, con);
                }
            } else {
                //r方失败
                for (int i = 0; i < len; i++) {
                    String rName = (String) r.get(rIndex.get(i));
                    String lName = (String) l.get(lIndex.get(i));
                    //l方将物品转移到r方
                    startBef.gangsService.psGoodsToElse(rName, lName, con);
                }
            }
            mybatisConfig.commit(con);
            return 1;
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        return 0;
    }

    /**
     * 系统逮捕魔头结算
     */
    public void catchMtResult(int win, JSONArray rList) {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            if (win == 1) {
                activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
                //队伍成员魔头值增加
                for (Object rN : rList) {
                    startBef.manService.updateSez((String) rN, -1, con);
                    user u = staticCollection.getUserByName((String) rN);
                    if (u != null && u.msg != null) {
                        u.msg.put("sez", u.msg.getInteger("sez") - 1);
                    }
                    JSONObject msg = startBef.manService.getMsgData((String) rN, con);
                    if (msg.getInteger("sez") < 0) {
                        //难度增加
                        List<JSONObject> tbList = activityMapper.getTianbing(rN.toString());
                        //队员可能由0变成-1，所以需要增加天兵的数据
                        if (tbList.size() == 0) {
                            activityMapper.addTianbing(rN.toString());
                            JSONObject a = new JSONObject();
                            a.put("lv", 1);
                            tbList.add(a);
                        }
                        int lv = tbList.get(0).getInteger("lv");
                        activityMapper.updateTianbing(rN.toString(), lv + 1 + "");
                        //奖励圣锻皇碎片
                        if (lv == 10) {
                            if (strUtils.isHappend(0, 1000, 0.2f)) {
                                JSONArray rewards = startBef.rewardService.createGoods("10000148", 1, 1, rN.toString(), con);
                                ChannelSupervise.noticeClientByName(rewards, rN.toString(), "10000");
                            }
                        }
                        startBef.orderService.countMTOrder(rN.toString());
                    }
                }
            } else {
                //队伍魔头玩家进入监狱
                List<String> erList = new ArrayList<>();
                for (Object rN : rList) {
                    int sez = startBef.manService.getSez((String) rN, con);
                    if (sez < 0) {
                        //被攻击方存在恶人就放入
                        erList.add((String) rN);
                    }
                }
                //将其送入监牢
                for (String er : erList) {
                    startBef.prisonService.putPrison(er, con);
                }
            }
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }

    }

    /**
     * 每10分钟派遣一队游缴逮捕魔头（触发战斗）
     * list:魔头名单{name,sez}
     */
    public void sysToCatchMt() {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
            List<JSONObject> list = dao.selectLvOrderSezEBySez();
            mybatisConfig.commit(con);
            if (list.size() == 0) {
                return;
            }
            //对于在监狱、不在线的进行移除
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.get(i);
                List<JSONObject> rl = activityMapper.getPrisonOne(a.getString("name"));
                if (!staticCollection.userIsOnline(a.getString("name")) || rl.size() != 0) {
                    list.remove(i);
                    i--;
                }
            }
            for (Object o : list) {
                JSONObject obj = (JSONObject) o;
                startBef.fightRpcService.createFightBySysCatch(obj.getString("name"), obj.getInteger("sez"));
            }
            list.clear();
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }

    }

    /**
     * 偷袭结果的处理
     */
    public Integer sneakResult(Integer w, JSONArray r, JSONArray l) {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            //是否有通缉任务，只有有通缉任务在身的偷袭对方才能不扣除善恶值，同时将对方送入监狱，否则不行
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);

            if (w == 1) {
                //送入监狱的玩家名单
                List<String> intoPrisonNames = new ArrayList<>();
                for (Object rN : r) {
                    List<JSONObject> al = activityMapper.getTongji(rN.toString());
                    if (al.size() == 0) continue;
                    JSONObject a = al.get(0);
                    //超时
                    if (strUtils.getTime() - a.getLong("created") > 24 * 60 * 60 * 1000) continue;
                    //逮捕的对象不一致
                    for (Object lN : l) {
                        if (a.getString("tj_name").equals(lN.toString())) {
                            intoPrisonNames.add(lN.toString());
                            break;
                        }
                    }
                    //完成任务 直接删除并奖励
                    activityMapper.remTongji(rN.toString());
                    //奖励一个扬善令牌
                    JSONArray res = rewardUtils.getGoodsReward("10000187", 1, 1);
                    startBef.rewardService.saveRewards(res, rN.toString(), con);
                    ChannelSupervise.noticeClientByName(res, rN.toString(), "10000");
                }
                if (intoPrisonNames.size() > 0) {
                    //送入监狱
                    for (String er : intoPrisonNames) {
                        startBef.prisonService.putPrison(er, con);
                    }
                } else {
                    //没有名单说明没有通缉任务，玩家善恶值需要降低
                    for (Object rN : r) {
                        startBef.manService.updateSez((String) rN, -1, con);
                    }
                }
            }

            //发生道具窃取
            if (!strUtils.isHappend(0, 100, 0.5f)) {
                mybatisConfig.commit(con);
                return 1;
            }
            List<Integer> rIndex = backShuffleList(r.size());
            List<Integer> lIndex = backShuffleList(l.size());
            //取最小的长度
            int len = rIndex.size() > lIndex.size() ? lIndex.size() : rIndex.size();
            if (w == 1) {
                //r方胜利
                //l方将有几率扣除道具给r方
                for (int i = 0; i < len; i++) {
                    String rName = (String) r.get(rIndex.get(i));
                    String lName = (String) l.get(lIndex.get(i));
                    //l方将物品转移到r方
                    startBef.packageService.aGoodToB(lName, rName, con);
                    //todo:损失银两
                }
                for (int i = 0; i < l.size(); i++) {
                    String lName = (String) l.get(lIndex.get(i));
                    //todo：损失经验
                }
            } else {
                //r方失败
                for (int i = 0; i < len; i++) {
                    String rName = (String) r.get(rIndex.get(i));
                    String lName = (String) l.get(lIndex.get(i));
                    //l方将物品转移到r方
                    startBef.packageService.aGoodToB(rName, lName, con);
                }
            }
            mybatisConfig.commit(con);
            return 1;
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        return 0;
    }

    /**
     * 将玩家放入监狱
     */
    public Integer putPrison(String name, DefaultSqlSession con) {
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getPrisonOne(name);
        if (list.size() == 0) {
            activityMapper.putPrison(name);
        } else {
            activityMapper.updatePrison(name, "0");
        }
        //通知对方进入监狱地图
        //ChannelSupervise.noticeClientByName("prison", name, "830");
        return 1;
    }

    private List<Integer> backShuffleList(int len) {
        List<Integer> list = new ArrayList<>();
        for (int i = 0; i < len; i++) {
            list.add(i);
        }
        //乱序
        Collections.shuffle(list);
        return list;
    }

    /**
     * 获取监狱状态
     */
    public JSONObject getOne(String name, DefaultSqlSession con) {
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getPrisonOne(name);
        if (list.size() == 0) return null;
        return list.get(0);
    }
}
