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
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.List;

public class vipService {
    /**
     * 增加道具
     */
    public result addGoods(JSONObject j,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (!name.equals("梅仁义")) return new result(0);
        String key = j.getString("key");
        int num = j.getInteger("num");
        if (num < 0 || strUtils.isNull(key)) return new result(0);
        if (startBef.manService.getRole(name, con) == null) {
            return new result(0);
        }
        JSONArray r = startBef.rewardService.saveRewards(
                rewardUtils.getGoodsReward(key, num, 0), name, con);
        return new result(200, r);
    }

    /**
     * 增加gold值
     */
    public result addGoldValue(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (!name.equals("梅仁义")) return new result(0);
        int type = j.getInteger("type");
        int num = j.getInteger("num");
        if (num <= 0) return new result(0);
        if (startBef.manService.getRole(name, con) == null) {
            return new result(0);
        }
        JSONArray r = null;
        if (type == 0) {
            r = startBef.rewardService.saveRewards(rewardUtils.getGoldReward(num), name, con);
        } else if (type == 1) {
            r = startBef.rewardService.saveRewards(rewardUtils.getTaleReward(num), name, con);
        } else if (type == 2) {
            r = startBef.rewardService.saveRewards(rewardUtils.getYinPiaoReward(num), name, con);
        }

        return new result(200, r);
    }

    /**
     * 增加vip值
     */
    public result addVipValue(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (!name.equals("梅仁义")) return new result(0);
        int jf = j.getInteger("jf");
        String playerName = j.getString("playerName");
        if (jf <= 0 || strUtils.isNull(playerName)) return new result(0);
        if (startBef.manService.getRole(name, con) == null) {
            return new result(0);
        }
        if (addVipExp(jf * 100, playerName, con)) {
            if (!addLjdXianJueOldJf(jf * 100, playerName, con)) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            if (!addLjdGoldOldJf(jf * 100, playerName, con)) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            //JSONArray rs= rewardUtils.getVipReward(jf*100);
            //ChannelSupervise.noticeClientByName(rs,playerName,"10000");
            return new result(200, 1);
        }
        mybatisConfig.rollback(con);
        return new result(0);
    }

    private void countXianJueMsg(JSONObject msg) {
        int num100 = msg.getInteger("num100");
        int num200 = msg.getInteger("num200");
        int exp = msg.getInteger("exp");
        int jf = msg.getInteger("jf");
        int preSy = jf % 20000;
        int sy = exp - jf;
        int zong = sy + preSy;
        int xh = 0;
        if (preSy == 0) {
            if (zong >= 100 * 100) {
                num100++;
                xh = 100 * 100;
            }
            if (zong >= 200 * 100) {
                num200++;
                xh = 200 * 100;
            }
        } else if (preSy == 100 * 100) {
            if (zong >= 200 * 100) {
                num200++;
                xh = 200 * 100;
            }
        }
        if (xh == 0) {
            //没有足够积分领取下一个礼包
            return;
        }
        jf += (xh - preSy);
        msg.put("jf", jf);
        msg.put("num100", num100);
        msg.put("num200", num200);
        countXianJueMsg(msg);
    }

    /**
     * 增加仙绝档积分
     */
    private boolean addLjdXianJueOldJf(long jf, String name, DefaultSqlSession con) {
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> dangList = activityMapper.getLjdXianJue(name);
        if (dangList.size() == 0) {
            activityMapper.addLjdXianJue(name);
            dangList = activityMapper.getLjdXianJue(name);
        }
        long num = dangList.get(0).getLong("old_jf") + jf;
        return activityMapper.updateLjdXianJue(name, num + "", null);
    }

    /**
     * 累计档金票赠送
     */
    public result gainLjdXianJueGift(@paramsAnno(key = "user") user user,
                                     @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (!strUtils.isInDay("2026-03-18 00:00:00", "2026-03-24 23:59:00")) {
            return new result(696);
        }
        //档位有 100 200
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> dangList = activityMapper.getLjdXianJue(name);
        if (dangList.size() == 0) {
            return new result(215);
        }
        //获取累计使用过的积分
        JSONObject one = dangList.get(0);
        //冲入的积分
        int old_jf = one.getInteger("old_jf");
        //最低50
        if (old_jf < 100) return new result(215);

        int jf = one.getInteger("jf");
        JSONObject msg = new JSONObject();
        msg.put("exp", old_jf);
        msg.put("jf", jf);
        msg.put("num100", 0);
        msg.put("num200", 0);
        countXianJueMsg(msg);
        jf = msg.getInteger("jf");
        int num100 = msg.getInteger("num100");
        int num200 = msg.getInteger("num200");
        if (num100 == 0 && num200 == 0) {
            return new result(215);
        }
        if (activityMapper.updateLjdXianJue(name, null, jf + "")) {
            //发送奖励
            JSONArray rewards = new JSONArray();
            if (num100 > 0) {//仙绝礼包
                rewardUtils.getGoodsReward("10000112", num100, 0, rewards);
            }
            if (num200 > 0) {//强装宝箱
                rewardUtils.getGoodsReward("10000288", num200, 0, rewards);
            }
            rewards = startBef.rewardService.saveRewards(rewards, name, con);
            startBef.logService.insertOp("8", name, "gainLjdXianJueGift/" + rewards.toString(), null, "1");
            return new result(200, rewards);
        }
        return new result(0);
    }

    /**
     * 增加仙绝档积分
     */
    private boolean addLjdGoldOldJf(long jf, String name, DefaultSqlSession con) {
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> dangList = activityMapper.getLjdGold(name);
        if (dangList.size() == 0) {
            activityMapper.addLjdGold(name);
            dangList = activityMapper.getLjdGold(name);
        }
        long num = dangList.get(0).getLong("old_jf") + jf;
        return activityMapper.updateLjdGold(name, num + "", null);
    }

    /**
     * 累计档金票赠送
     */
    public result gainLjdGoldGift(@paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (true) return new result(0);
        if (!strUtils.isInDay("2026-03-18 00:00:00", "2026-03-24 23:59:00")) {
            return new result(696);
        }
        //档位有 50 100 200 500 1000 共5档
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> dangList = activityMapper.getLjdGold(name);
        if (dangList.size() == 0) {
            return new result(215);
        }
        //获取累计使用过的积分
        JSONObject one = dangList.get(0);
        //冲入的积分
        int old_jf = one.getInteger("old_jf");
        //最低50
        if (old_jf < 50) return new result(215);

        int jf = one.getInteger("jf");
        JSONObject msg = new JSONObject();
        msg.put("exp", old_jf);
        msg.put("jf", jf);
        msg.put("num50", 0);
        msg.put("num100", 0);
        msg.put("num200", 0);
        msg.put("num500", 0);
        msg.put("num1000", 0);
        countMsg(msg);
        jf = msg.getInteger("jf");
        int num50 = msg.getInteger("num50");
        int num100 = msg.getInteger("num100");
        int num200 = msg.getInteger("num200");
        int num500 = msg.getInteger("num500");
        int num1000 = msg.getInteger("num1000");
        if (num50 == 0 && num100 == 0 && num200 == 0 && num500 == 0 && num1000 == 0) {
            return new result(215);
        }
        if (activityMapper.updateLjdGold(name, null, jf + "")) {
            //发送奖励
            //50:龙头金票*2+龙头银票*1
            //100:龙头金票*5
            //200:龙头金票*10
            //500:龙头金票*25
            //1000:龙头金票*50
            JSONArray rewards = new JSONArray();
            if (num50 > 0) {
                rewardUtils.getGoodsReward("10000000", 2 * num50, 0, rewards);
                rewardUtils.getGoodsReward("10000001", 1 * num50, 0, rewards);
            }
            if (num100 > 0) {
                rewardUtils.getGoodsReward("10000000", 5 * num100, 0, rewards);
            }
            if (num200 > 0) {
                rewardUtils.getGoodsReward("10000000", 10 * num200, 0, rewards);
            }
            if (num500 > 0) {
                rewardUtils.getGoodsReward("10000000", 25 * num500, 0, rewards);
            }
            if (num1000 > 0) {
                rewardUtils.getGoodsReward("10000000", 50 * num1000, 0, rewards);
            }
            rewards = startBef.rewardService.saveRewards(rewards, name, con);
            startBef.logService.insertOp("8", name, "gainLjdGoldGift/" + rewards.toString(), null, "1");
            return new result(200, rewards);
        }

        return new result(0);
    }

    /**
     * 累计档钻石宝箱礼包
     */
    public result gainLeiJiDangGift(@paramsAnno(key = "user") user user,
                                    @paramsAnno(key = "con") DefaultSqlSession con) {
        if (true) return new result(0);
        final String name = user.name;
        int exp = getVipExp(name, con);
        if (exp < 5000) return new result(0);
        //档位有 50 100 200 500 1000 共5档
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> dangList = activityMapper.getLeiJiDang(name);
        if (dangList.size() == 0) {
            activityMapper.addLeiJiDang(name);
            dangList = activityMapper.getLeiJiDang(name);
        }
        //获取累计使用过的积分
        JSONObject one = dangList.get(0);
        int jf = one.getInteger("jf");
        JSONObject msg = new JSONObject();
        msg.put("exp", exp);
        msg.put("jf", jf);
        msg.put("num50", 0);
        msg.put("num100", 0);
        msg.put("num200", 0);
        msg.put("num500", 0);
        msg.put("num1000", 0);
        countMsg(msg);
        jf = msg.getInteger("jf");
        int num50 = msg.getInteger("num50");
        int num100 = msg.getInteger("num100");
        int num200 = msg.getInteger("num200");
        int num500 = msg.getInteger("num500");
        int num1000 = msg.getInteger("num1000");
        if (num50 == 0 && num100 == 0 && num200 == 0 && num500 == 0 && num1000 == 0) {
            return new result(215);
        }
        if (activityMapper.updateLeiJiDang(name, jf + "")) {
            //发送奖励
            JSONArray rewards = new JSONArray();
            if (num50 > 0) {
                rewardUtils.getGoodsReward("10000267", num50, 1, rewards);
            }
            if (num100 > 0) {
                rewardUtils.getGoodsReward("10000268", num100, 1, rewards);
            }
            if (num200 > 0) {
                rewardUtils.getGoodsReward("10000269", num200, 1, rewards);
            }
            if (num500 > 0) {
                rewardUtils.getGoodsReward("10000270", num500, 1, rewards);
            }
            if (num1000 > 0) {
                rewardUtils.getGoodsReward("10000271", num1000, 1, rewards);
            }
            startBef.rewardService.saveRewards(rewards, name, con);
            return new result(200, rewards);
        }

        return new result(0);
    }

    private void countMsg(JSONObject msg) {
        int num50 = msg.getInteger("num50");
        int num100 = msg.getInteger("num100");
        int num200 = msg.getInteger("num200");
        int num500 = msg.getInteger("num500");
        int num1000 = msg.getInteger("num1000");
        int exp = msg.getInteger("exp");
        int jf = msg.getInteger("jf");
        int preSy = jf % 100000;
        int sy = exp - jf;
        int zong = sy + preSy;
        int xh = 0;
        if (preSy == 0) {
            if (zong >= 50 * 100) {
                num50++;
                xh = 50 * 100;
            }
            if (zong >= 100 * 100) {
                num100++;
                xh = 100 * 100;
            }
            if (zong >= 200 * 100) {
                num200++;
                xh = 200 * 100;
            }
            if (zong >= 500 * 100) {
                num500++;
                xh = 500 * 100;
            }
            if (zong >= 1000 * 100) {
                num1000++;
                xh = 1000 * 100;
            }
        } else if (preSy == 50 * 100) {
            if (zong >= 100 * 100) {
                num100++;
                xh = 100 * 100;
            }
            if (zong >= 200 * 100) {
                num200++;
                xh = 200 * 100;
            }
            if (zong >= 500 * 100) {
                num500++;
                xh = 500 * 100;
            }
            if (zong >= 1000 * 100) {
                num1000++;
                xh = 1000 * 100;
            }
        } else if (preSy == 100 * 100) {
            if (zong >= 200 * 100) {
                num200++;
                xh = 200 * 100;
            }
            if (zong >= 500 * 100) {
                num500++;
                xh = 500 * 100;
            }
            if (zong >= 1000 * 100) {
                num1000++;
                xh = 1000 * 100;
            }
        } else if (preSy == 200 * 100) {
            if (zong >= 500 * 100) {
                num500++;
                xh = 500 * 100;
            }
            if (zong >= 1000 * 100) {
                num1000++;
                xh = 1000 * 100;
            }
        } else if (preSy == 500 * 100) {
            if (zong >= 1000 * 100) {
                num1000++;
                xh = 1000 * 100;
            }
        }
        if (xh == 0) {
            //没有足够积分领取下一个礼包
            return;
        }
        jf += (xh - preSy);
        msg.put("jf", jf);
        msg.put("num50", num50);
        msg.put("num100", num100);
        msg.put("num200", num200);
        msg.put("num500", num500);
        msg.put("num1000", num1000);
        countMsg(msg);
    }

    /**
     * 领取vip礼包
     */
    public result gainVipLvGift(JSONObject j,
                                @paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //每个等级都有一份，vip增加领取字段
        int lv = j.getInteger("lv");
        if (lv < 1 || lv > 10) return new result(0);
        int exp = getVipExp(name, con);
        int vipLv = getVipLv(exp);
        if (vipLv < lv) return new result(0);
        //判断是否领取过
        activityMapper am = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = am.getVipGift(name);
        if (list.size() == 0) {
            am.addVipGift(name);
            list = am.getVipGift(name);
        }
        JSONObject one = list.get(0);
        int g = one.getInteger("g" + lv);
        if (g != 0) return new result(213);
        boolean b = false;
        String gdKey = null;
        if (lv == 1) {
            b = am.updateVipGift(name, "1", null, null, null, null,
                    null, null, null, null, null);
            gdKey = "10000272";
        } else if (lv == 2) {
            b = am.updateVipGift(name, null, "1", null, null, null,
                    null, null, null, null, null);
            gdKey = "10000273";
        } else if (lv == 3) {
            b = am.updateVipGift(name, null, null, "1", null, null,
                    null, null, null, null, null);
            gdKey = "10000274";
        } else if (lv == 4) {
            b = am.updateVipGift(name, null, null, null, "1", null,
                    null, null, null, null, null);
            gdKey = "10000275";
        } else if (lv == 5) {
            b = am.updateVipGift(name, null, null, null, null, "1",
                    null, null, null, null, null);
            gdKey = "10000276";
        } else if (lv == 6) {
            b = am.updateVipGift(name, null, null, null, null,
                    null, "1", null, null, null, null);
            gdKey = "10000277";
        } else if (lv == 7) {
            b = am.updateVipGift(name, null, null, null, null,
                    null, null, "1", null, null, null);
            gdKey = "10000278";
        } else if (lv == 8) {
            b = am.updateVipGift(name, null, null, null, null,
                    null, null, null, "1", null, null);
            gdKey = "10000279";
        } else if (lv == 9) {
            b = am.updateVipGift(name, null, null, null, null,
                    null, null, null, null, "1", null);
            gdKey = "10000280";
        } else if (lv == 10) {
            b = am.updateVipGift(name, null, null, null, null,
                    null, null, null, null, null, "1");
            gdKey = "10000281";
        } else return new result(0);
        if (b) {
            JSONArray rs = rewardUtils.getGoodsReward(gdKey, 1, 1);
            startBef.rewardService.saveRewards(rs, name, con);
            return new result(200, rs);
        }
        return new result(0);
    }

    /**
     * 宠物强化特权
     */
    public boolean isAllowedQiangHua(int growLv, String name, DefaultSqlSession con) {
        //v1可成2 v2成3 v3成4 v4成5
        //v5允许成6 v6允许成7\8 v7允许成9 v8允许成10
        int exp = getVipExp(name, con);
        int vipLv = getVipLv(exp);
        //必须vip才允许强化
        if (vipLv == 0) return false;
        //成5以上进行强化则需要达到v5
        if (vipLv == 1 && growLv > 1) return false;
        else if (vipLv == 2 && growLv > 2) return false;
        else if (vipLv == 3 && growLv > 3) return false;
        else if (vipLv == 4 && growLv > 4) return false;
        else if (vipLv == 5 && growLv > 5) return false;
        else if (vipLv == 6 && growLv > 7) return false;
        else if (vipLv == 7 && growLv > 8) return false;
        return true;
    }

    /**
     * 根据vip获取强化值
     * //500元宝一次
     * //成6每次100成长度
     * //成7每次50成长度
     * //成8每次25成长度
     * //成9每次15成长度
     * //成10每次10成长度
     */
    public int getQiangHuaZhi(int growLv, String name, DefaultSqlSession con) {
        int exp = getVipExp(name, con);
        int vipLv = getVipLv(exp);
        if (vipLv == 0) return 0;
        if (growLv < 5) {
            return 200;
        } else if (growLv == 5) {//成5的 v7以上一次增加200成长值，以下增加100
            if (vipLv < 7) return 100;
            return 200;
        } else if (growLv == 6) return 50;
        else if (growLv == 7) return 25;
        else if (growLv == 8) return 15;
        else if (growLv == 9) return 10;
        else if (growLv == 10) return 0;
        return 0;
    }

    public int getVipLv(String name, DefaultSqlSession con) {
        int exp = getVipExp(name, con);
        return getVipLv(exp);
    }

    /**
     * 根据vip总经验获取vip等级
     */
    public int getVipLv(int exp) {
        //累计的成长度，1元=100成长度
        int[] arr = {
                100, 2000, 5000, 10000, 20000,
                50000, 100000, 300000, 500000, 1000000
        };
        int sum = 0;
        for (int i = 0; i < arr.length; i++) {
            if (exp >= arr[i]) sum++;
        }
        return sum;
    }

    /**
     * 增加vip经验
     */
    public boolean addVipExp(int vip, String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        int exp = getVipExp(name, con);
        return jsonMapper.updateVip(name, exp + vip + "");
    }

    public int getVipExp(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        //增加vip经验
        List<JSONObject> vipList = jsonMapper.selectVip(name);
        if (vipList.size() == 0) {
            jsonMapper.addVip(name);
            vipList = jsonMapper.selectVip(name);
        }
        return vipList.get(0).getInteger("jf");
    }
}
