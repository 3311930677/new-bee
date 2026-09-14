package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.dao.activityMapper;
import my.data.equipData;
import my.db.mybatisConfig;
import my.fightUtils.fightUtils;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

public class fightOverService {
    /**
     * 境界心魔
     */
    public void handleJJXM(String fightId, int type, int win, String name) {
        if (win == 1) {
            //标记已经击败心魔
            DefaultSqlSession con = null;
            try {
                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
                List<JSONObject> list = activityMapper.getXinMo(name);
                int lv = list.get(0).getInteger("lv") + 1;
                activityMapper.updateXinMo(name, lv + "");
                mybatisConfig.commit(con);
            } catch (Exception e) {
                e.printStackTrace();
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        }
    }


    /**
     * 成王败寇
     */
    public void handleCWBK(String fightId, int type, int win, String rName, String Cid) {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            if (win == 1) {
                List<JSONObject> list = activityMapper.getCWBK(Cid);
                if (list.size() > 0) {
                    long start = list.get(0).getLong("start");
                    int jf = 10;
                    int Id = list.get(0).getInteger("Id");
                    if (Id < 3) jf = 50;
                    else if (Id < 6) jf = 40;
                    else if (Id < 9) jf = 30;
                    else if (Id < 13) jf = 20;
                    long d = (strUtils.getTime() - start) / 1000 / 60 / 60;
                    if (d <= 0) jf = 0;
                    else jf = (int) d * jf;
                    if (jf > 0) {
                        //击败后夺取20%收益
                        JSONArray al = rewardUtils.getLdjfReward((int) (jf * 0.2f));
                        startBef.rewardService.saveRewards(al, rName, con);
                        ChannelSupervise.noticeClientByName(al, rName, "10000");
                        al = rewardUtils.getLdjfReward((int) (jf * 0.8f));
                        String lName = list.get(0).getString("name");
                        startBef.rewardService.saveRewards(al, lName, con);
                        ChannelSupervise.noticeClientByName(al, lName, "10000");
                    }
                }
                activityMapper.updateCWBK(Cid, rName, strUtils.getTime() + "");
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
     * 百炼妖塔
     */
    public void handleBLYT(String Id, int type, int win, JSONArray rList) {
        if (rList.size() == 0) return;
        String rName = rList.get(0).toString();
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            if (win == 1) {
                List<JSONObject> al = activityMapper.getBLYT(rName);
                //刚好0点刷新后战斗才结束会导致这里数组为0
                if (al.size() == 0) {
                    mybatisConfig.commit(con);
                    return;
                }
                int lever = al.get(0).getInteger("lever");
                activityMapper.updateBLYT(rName, lever + 1 + "");
                //练潜装备
                startBef.packageService.turnToPotential(10, rName, con);
                JSONArray rewards = new JSONArray();
                int exp = lever * 600 + 618;
                int petExp = exp / 2;
                rewardUtils.getExpReward(exp, petExp, rewards);
                //奖励-潜力符石、福神的礼袋（锻皇）、汇通银券、汇通金券
                if ((lever + 1) >= 60) {//大于6概率掉福神的礼袋
                    if (strUtils.isHappend(0, 1000, 0.1f))
                        rewardUtils.getGoodsReward("10000189", 1, 1, rewards);
                }
                if ((lever + 1) % 10 == 0) {//7;[g*}PeA#98xut
                    if ((lever + 1) / 10 >= 4) {//大于4必掉潜力石头
                        rewardUtils.getGoodsReward("10000114", 1, 1, rewards);
                        rewardUtils.getGoodsReward("10000175", 1, 1, rewards);
                    }
                } else {
                    if (strUtils.isHappend(0, 1000, 0.1f)) {
                        List<String> arr = new ArrayList<>();
                        arr.add("10000176");
                        if (lever > 40) arr.add("10000175");
                        if (strUtils.isHappend(0, 1000, 0.8f)) {
                            rewardUtils.getGoodsReward(arr.get(0), 1, 1, rewards);
                        } else {
                            rewardUtils.getGoodsReward(arr.get(arr.size() - 1), 1, 1, rewards);
                        }
                    }
                }
                rewards = startBef.rewardService.saveRewards(rewards, rName, con);
                ChannelSupervise.noticeClientByName(rewards, rName, "10000");
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
     * 血腥之地
     */
    public void handleXXZD(String Id, int type, int win, JSONArray rList, JSONArray lList) {
        if (rList.size() == 0 || lList.size() == 0) return;
        String rName = rList.get(0).toString();
        String lName = lList.get(0).toString();
        startBef.xxzdService.fightRes(win, rName, lName);
    }

    /**
     * 王侯将相
     */
    public void handleWHJX(String Id, int type, int win, String rName, String lName) {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
            if (win == 1) {
                //右方胜利 积分+20 败方+10
                List<JSONObject> al = activityMapper.getWHJX(rName);
                int jf = al.get(0).getInteger("jf");
                activityMapper.updateWHJX(rName, jf + 20 + "", null);

                al = activityMapper.getWHJX(lName);
                jf = al.get(0).getInteger("jf");
                activityMapper.updateWHJX(lName, jf + 10 + "", null);
            } else {
                List<JSONObject> al = activityMapper.getWHJX(rName);
                int jf = al.get(0).getInteger("jf");
                activityMapper.updateWHJX(rName, jf + 10 + "", null);

                al = activityMapper.getWHJX(lName);
                jf = al.get(0).getInteger("jf");
                activityMapper.updateWHJX(lName, jf + 20 + "", null);
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
     * 处理跑商抢夺
     */
    public void handleQd(String Id, int type, int win, JSONArray rList, JSONArray lList) {
        startBef.prisonService.qdResult(win, rList, lList);
    }

    /**
     * 处理帮战
     */
    public void handleBz(String Id, int type, int win, JSONArray rList, JSONArray lList, JSONObject pm) {
        //都是单人，赢的一方占领宝箱，需要宝箱的key
        if (win == 1) {
            startBef.gangsService.bzOneRes(pm.getString("bzId"), pm.getString("boxKey"), rList.getString(0));
        }
    }

    /**
     * 处理偷袭
     */
    public void handleTx(String Id, int type, int win, JSONArray rList, JSONArray lList) {
        startBef.prisonService.sneakResult(win, rList, lList);
    }

    /**
     * 处理系统逮捕魔头
     */
    public void handleCatchMt(String Id, int type, int win, JSONArray rList, JSONArray lList) {
        startBef.prisonService.catchMtResult(win, rList);
    }

    /**
     * 处理江湖追杀
     */
    public void handleZsl(String Id, int type, int win, JSONArray rList, JSONArray lList, JSONObject params) {
        String name = params.getString("name");
        String playerName = params.getString("playerName");
        startBef.zslService.zslResult(win, name, playerName);
    }

    /**
     * 处理大师兄结算
     */
    public void handleDsx(String Id, int type, int win, String name, String playerName) {
        if (win == 1) {
            startBef.dsxService.markWinAndLoser(name, playerName);
        } else {
            startBef.dsxService.markWinAndLoser(playerName, name);
        }
    }

    /**
     * 处理抢壁结算
     */
    public void handleQb(String Id, int type, int win, String name, String playerName) {
        startBef.cbService.qbRes(name, playerName, win);
    }

    /**
     * 处理武状员战斗结算
     */
    public void handleWzy(String Id, int type, int win, String wzyId) {
        int r;
        if (win == 1) {
            //主攻击队伍胜利
            r = 1;
        } else {
            r = 2;
        }
        startBef.wzyService.markLoser(wzyId, r);
    }



    /**
     * 斗战封神榜
     */
    public void handleDzfsb(String Id, int type, int win, JSONArray rList, JSONArray lList) {
        if (rList.size() == 0) {//可能中途下线导致为0
            return;
        }
        String rName = rList.get(0).toString();
        String lName = lList.getJSONObject(0).getString("name");
        startBef.dzfsbService.handleDzfsb(win, rName, lName);
    }

    /**
     * 处理竞技战斗奖励
     */
    public void handleJingji(String Id, int type, int win, JSONArray rList, JSONArray lList) {
        String rName = rList.get(0).toString();
        String lName = lList.get(0).toString();
        //todo：记录竞技积分，周末结算时按排名给予积分（msg）
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            activityMapper dao = mybatisConfig.getMapper(con, activityMapper.class);
            JSONObject obj0 = dao.getJingji(rName).get(0);
            JSONObject obj1 = dao.getJingji(lName).get(0);
            int lv0 = startBef.manService.getRoleLv(rName, con);
            int lv1 = startBef.manService.getRoleLv(lName, con);
            int rJf = 0, lJf = 0;
            //需按等级给予积分
            if (win == 1) {//右方胜利
                rJf = 20;
                lJf = 10;
            } else {
                rJf = 10;
                lJf = 20;
            }
            rJf = (int) (rJf * (lv0 / 100f));
            lJf = (int) (lJf * (lv1 / 100f));
            dao.updateJingji(rName, obj0.getInteger("jf") + rJf + "", obj0.getInteger("times") + 1 + "");
            dao.updateJingji(lName, obj1.getInteger("jf") + lJf + "", obj1.getInteger("times") + 1 + "");

            mybatisConfig.commit(con);
        } catch (Exception e) {
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        /*if (win == 1) {
            //右方胜利
            startBef.rewardService.getJFReward(1, rName);
            startBef.rewardService.getJFReward(0, lName);
        } else {
            startBef.rewardService.getJFReward(0, rName);
            startBef.rewardService.getJFReward(1, lName);
        }*/
    }


    /**
     * 处理怪物战斗奖励
     */
    public void handleMonster(String Id, int type, int win, JSONObject data, JSONObject hurt) {
        if (win == 1) {
            staticCollection.putTask(() -> {
                try {
                    //提交任务怪物数量
                    startBef.taskService.commitMonster(data);
                    //对于洪荒宝库死门的怪物需要处理
                    startBef.hhbkService.commitMonster(data);
                    //对于门派保卫战的怪物需要处理
                    startBef.mpbwzService.commitMonster(data);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });
            staticCollection.putTask(() -> {
                try {
                    //战斗经验等奖励
                    startBef.rewardService.getFightReward(data);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });

        }

        if (type == 1) {
            //世界boss统计伤害
            if (data.getString("monsterKey").equals("world_boss") && hurt != null) {
                startBef.worldBossService.count(hurt);
            }
            //帮派boss总血量减少
            if (data.getString("monsterKey").equals("bp_boss") && hurt != null) {
                startBef.gangsService.cutBossXue(hurt, data.getJSONArray("names"));
            }

            if (data.getString("monsterKey").equals("bp_robber") && hurt != null) {
                //startBef.gangsService.attackRobberOverHandle(win, data);
            }
            //魔尊
            if (data.getString("monsterKey").equals("mozun_boss")) {
                //通知跳转场景1
                startBef.fightRpcService.mozunFightOverHandle(win, data);
            }
            //魔窟魔神
            if (data.getString("monsterKey").contains("yhmkms_")) {
                //通知跳转场景1
                startBef.yhmkService.tiaozhanOverHandle(win, data);
            }
            //帮派猴子
            if (data.getString("monsterKey").equals("houzi")) {
                startBef.gangsService.beatMonkey(win, data);
            }

        }
    }
}
