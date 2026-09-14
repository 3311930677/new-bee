package my.service;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.gangsMapper;
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

/**
 * 永恒魔窟
 * 共xue\lan\wg\fg\wf\ff\css\mz\sd\bj十个属性，名为十星
 * 饕餮产出：wg、fg
 * 混沌产出：max_xue、wf、ff
 * 梼杌：max_lan、bj、mz
 * 穷奇：css、sd
 * 10个属性点满进阶一星，激活属性需要一定数量的星陨石
 * 一共12星
 */
public class yhmkService {
    /**
     * 获取各个魔神等级
     */
    public JSONObject getMoShenLv(String name, DefaultSqlSession con) {
        JSONObject a = new JSONObject();
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectYhmk(name);
        if (list.size() == 0) {
            a.put("lv1", 0);
            a.put("lv2", 0);
            a.put("lv3", 0);
            a.put("lv4", 0);
            a.put("lv5", 0);
            a.put("lv6", 0);
            a.put("lv7", 0);
        } else {
            JSONObject o = list.get(0);
            a.put("lv1", o.get("lv1"));
            a.put("lv2", o.get("lv2"));
            a.put("lv3", o.get("lv3"));
            a.put("lv4", o.get("lv4"));
            a.put("lv5", o.get("lv5"));
            a.put("lv6", o.get("lv6"));
            a.put("lv7", o.get("lv7"));
        }
        return a;
    }

    /**
     * 挑战结束处理
     */
    public void tiaozhanOverHandle(int win, JSONObject data) {
        if (win == 0) return;
        String name = data.getJSONArray("names").get(0).toString();
        String msKey = data.getString("monsterKey");
        int n = Integer.parseInt(msKey.split("_")[1]);
        //魔神等级+1，满意度清零
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
            List<JSONObject> list = jsonMapper.selectYhmk(name);
            int lv = list.get(0).getInteger("lv" + n) + 1;
            if (n == 1) {
                jsonMapper.updateYhmk(name, null, null,
                        lv + "", null, null, null, null, null, null,
                        "0", null, null, null, null, null, null);
            } else if (n == 2) {
                jsonMapper.updateYhmk(name, null, null,
                        null, lv + "", null, null, null, null, null,
                        null, "0", null, null, null, null, null);
            } else if (n == 3) {
                jsonMapper.updateYhmk(name, null, null,
                        null, null, lv + "", null, null, null, null,
                        null, null, "0", null, null, null, null);
            } else if (n == 4) {
                jsonMapper.updateYhmk(name, null, null,
                        null, null, null, lv + "", null, null, null,
                        null, null, null, "0", null, null, null);
            } else if (n == 5) {
                jsonMapper.updateYhmk(name, null, null,
                        null, null, null, null, lv + "", null, null,
                        null, null, null, null, "0", null, null);
            } else if (n == 6) {
                jsonMapper.updateYhmk(name, null, null,
                        null, null, null, null, null, lv + "", null,
                        null, null, null, null, null, "0", null);
            } else {
                jsonMapper.updateYhmk(name, null, null,
                        null, null, null, null, null, null, lv + "",
                        null, null, null, null, null, null, "0");
            }
            mybatisConfig.commit(con);
            //todo：通知魔神等级变更
            ChannelSupervise.noticeClientByName(n, name, "856");
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 挑战魔神
     */
    public result tiaozhanMs(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String msKey = j.getString("msKey");
        //yhmkms_1 ...
        int n = Integer.parseInt(msKey.split("_")[1]);
        //验证满意度是否已满了
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectYhmk(name);
        int lv = list.get(0).getInteger("lv" + n);
        if (lv >= 10) return new result(200, 0);
        //判断满意度是否达到该等级的最大数
        int myd = list.get(0).getInteger("myd" + n);
        if (myd < (lv + 1) * 18) {
            //满意度未满
            JSONObject res = new JSONObject();
            res.put("myd", myd);
            res.put("max_myd", (lv + 1) * 18);
            return new result(200, res);
        }
        //创建战斗，战斗结束后胜利则满意度重置，魔神等级+1
        startBef.fightRpcService.createFightByYhmk(name, n, lv, con);
        return new result(200, 1);
    }

    /**
     * 查看魔神状态
     */
    public result viewStatus(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String msKey = j.getString("msKey");
        //yhmkms_1 ...
        int n = Integer.parseInt(msKey.split("_")[1]);
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectYhmk(name);
        int lv = list.get(0).getInteger("lv" + n);
        return new result(200, lv);
    }

    /**
     * 获取加持等级
     */
    public result getJcMsLv(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //yhmkms_1 ...
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectYhmk(name);
        JSONObject res = new JSONObject();
        for (int i = 1; i < 8; i++) {
            res.put("lv" + i, list.get(0).getInteger("lv" + i));
        }
        return new result(200, res);
    }

    /**
     * 使用供香
     */
    public result userGx(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String msKey = j.getString("msKey");
        String goodsId = j.getString("goodsId");
        //验证背包中是否存在供香
        JSONObject gd = startBef.packageService.getOne(goodsId, name, con);
        if (gd == null || !gd.getString("key").equals("10000143"))
            return new result(0);
        //yhmkms_1 ...
        int n = Integer.parseInt(msKey.split("_")[1]);

        //判断魔神等级是否已经到达10级
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectYhmk(name);
        int lv = list.get(0).getInteger("lv" + n);
        if (lv >= 10) return new result(200, 0);
        //判断满意度是否达到该等级的最大数
        int myd = list.get(0).getInteger("myd" + n);
        //0-18 1-36 2-54 3-72 4-90 5-108 6-126 7-144 8-162 9-180 10-198
        if (myd >= (lv + 1) * 18) {
            //满意度已满，需要击败boss才能继续
            return new result(200, -1);
        }
        //消耗背包中的供香来提升满意度
        //还差多少就能补满当前的满意度
        int need = (lv + 1) * 18 - myd;
        if (gd.getInteger("num") < need) {
            need = gd.getInteger("num");
        }
        if (startBef.packageService.cutPlayerGoodsNum(goodsId, need, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //增加满意度
        boolean b = false;
        myd += need;
        if (n == 1) {
            b = jsonMapper.updateYhmk(name, null, null,
                    null, null, null, null, null, null, null,
                    myd + "", null, null, null, null, null, null);
        } else if (n == 2) {
            b = jsonMapper.updateYhmk(name, null, null,
                    null, null, null, null, null, null, null,
                    null, myd + "", null, null, null, null, null);
        } else if (n == 3) {
            b = jsonMapper.updateYhmk(name, null, null,
                    null, null, null, null, null, null, null,
                    null, null, myd + "", null, null, null, null);
        } else if (n == 4) {
            b = jsonMapper.updateYhmk(name, null, null,
                    null, null, null, null, null, null, null,
                    null, null, null, myd + "", null, null, null);
        } else if (n == 5) {
            b = jsonMapper.updateYhmk(name, null, null,
                    null, null, null, null, null, null, null,
                    null, null, null, null, myd + "", null, null);
        } else if (n == 6) {
            b = jsonMapper.updateYhmk(name, null, null,
                    null, null, null, null, null, null, null,
                    null, null, null, null, null, myd + "", null);
        } else {
            b = jsonMapper.updateYhmk(name, null, null,
                    null, null, null, null, null, null, null,
                    null, null, null, null, null, null, myd + "");
        }

        if (!b) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONObject res = new JSONObject();
        res.put("need", need);
        res.put("myd", myd);
        res.put("max_myd", (lv + 1) * 18);
        return new result(200, res);
    }

    /**
     * 敲打响木
     */
    public result qiaodaxm(@paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //判断今日是否已经敲打
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectYhmk(name);
        int qiaoda = list.get(0).getInteger("qiaoda");
        if (qiaoda != 0) return new result(200, 0);
        //每日一次，每次消耗1000元宝，随机1-7供香
        if (startBef.manService.saveMoney(0, -1 * 1000L, name, con) != 1)
            return new result(634);
        boolean b = jsonMapper.updateYhmk(name, null, "1",
                null, null, null, null, null, null, null,
                null, null, null, null, null, null, null);
        if (!b) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        int num = strUtils.getRandom(1, 8);
        JSONArray gs = startBef.rewardService.createGoods("10000143", num, 1, name, con);
        return new result(200, gs);
    }

    /**
     * 接取魔神日常任务
     */
    public result getMsTask(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if(user.msg.getLong("lever")<60) return new result(0);
        if (!matchTimes(name, con)) {
            //今日已经打过了
            return new result(200, 0);
        }
        //次数--
        setGain(name, con);
        //创建任务
        String tk = strUtils.getRandom(3265, 3272) + "";
        startBef.taskService.createTask(tk, name, con);
        return new result(200, tk);
    }


    /**
     * 验证次数
     */
    public boolean matchTimes(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        //验证次数
        List<JSONObject> list = jsonMapper.selectYhmk(name);
        if (list.get(0).getInteger("gain") == 1) {
            //今日已经打过了
            return false;
        }
        return true;
    }

    /**
     * 设置今日已接取日常
     */
    public boolean setGain(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.updateYhmk(name, "1", null,
                null, null, null, null, null, null, null,
                null, null, null, null, null, null, null);
    }

    /**
     * 击败魔神后提升魔神难度等级、加持等级
     */
    public boolean upLever(String msKey, String name, DefaultSqlSession con) {
        //yhmkms_1 ...
        int n = Integer.parseInt(msKey.split("_")[1]);
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> one = jsonMapper.selectYhmk(name);
        int lv = one.get(0).getInteger("lv" + n) + 1;
        if (n == 1) {
            return jsonMapper.updateYhmk(name, null, null,
                    lv + "", null, null, null, null, null, null,
                    null, null, null, null, null, null, null);
        } else if (n == 2) {
            return jsonMapper.updateYhmk(name, null, null,
                    null, lv + "", null, null, null, null, null,
                    null, null, null, null, null, null, null);
        } else if (n == 3) {
            return jsonMapper.updateYhmk(name, null, null,
                    null, null, lv + "", null, null, null, null,
                    null, null, null, null, null, null, null);
        } else if (n == 4) {
            return jsonMapper.updateYhmk(name, null, null,
                    null, null, null, lv + "", null, null, null,
                    null, null, null, null, null, null, null);
        } else if (n == 5) {
            return jsonMapper.updateYhmk(name, null, null,
                    null, null, null, null, lv + "", null, null,
                    null, null, null, null, null, null, null);
        } else if (n == 6) {
            return jsonMapper.updateYhmk(name, null, null,
                    null, null, null, null, null, lv + "", null,
                    null, null, null, null, null, null, null);
        } else {
            return jsonMapper.updateYhmk(name, null, null,
                    null, null, null, null, null, null, lv + "",
                    null, null, null, null, null, null, null);
        }

    }

}
