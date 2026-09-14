package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.dao.logMapper;
import my.db.mybatisConfig;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.List;

public class logService {
    /**
     * 个人竞技对战结果
     * winner name->jd
     * failer name
     */
    public void addJingjiResLog(int win, JSONObject aList, JSONArray bList) {
        staticCollection.putTask(() -> {
            SqlSession con = null;
            try {
                con = mybatisConfig.getSqlSession();
                logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
                JSONObject res = new JSONObject();
                res.put("win", win);
                res.put("player", bList);
                for (String name : aList.keySet()) {
                    List<JSONObject> list = logMapper.getPkLogByName(name);
                    if (list.size() == 0) {
                        logMapper.insertPkLog(name, "[]", "[]");
                        JSONObject data = new JSONObject();
                        data.put("jingji", new JSONArray());
                        list.add(data);
                    }
                    res.put("jd", aList.get(name));
                    JSONArray al = list.get(0).getJSONArray("jingji");
                    al.add(0, res);
                    //超过10个记录就删除后面的
                    if (al.size() > 10) {
                        al.remove(al.size() - 1);
                    }
                    logMapper.updatePkLog(name, null, JSON.toJSONString(al));
                    mybatisConfig.commit(con);
                }
            } catch (Exception e) {
                e.printStackTrace();
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        });
    }
    /**
     * 排位战斗结果
     * winner name->jd
     * failer name
     */
    public void addPaiweiResLog(int win, JSONObject aList, JSONArray bList) {
        staticCollection.putTask(() -> {
            SqlSession con = null;
            try {
                con = mybatisConfig.getSqlSession();
                logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
                JSONObject res = new JSONObject();
                res.put("win", win);
                res.put("player", bList);
                for (String name : aList.keySet()) {
                    List<JSONObject> list = logMapper.getPkLogByName(name);
                    if (list.size() == 0) {
                        logMapper.insertPkLog(name, "[]", "[]");
                        JSONObject data = new JSONObject();
                        data.put("paiwei", new JSONArray());
                        list.add(data);
                    }
                    res.put("jd", aList.get(name));
                    JSONArray al = list.get(0).getJSONArray("paiwei");
                    al.add(0, res);
                    //超过10个记录就删除后面的
                    if (al.size() > 10) {
                        al.remove(al.size() - 1);
                    }
                    logMapper.updatePkLog(name, JSON.toJSONString(al), null);
                    mybatisConfig.commit(con);
                }
            } catch (Exception e) {
                e.printStackTrace();
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        });
    }

    /**
     * 离帮时间
     */
    public Integer updateLeaveBpTime(String name, DefaultSqlSession con) {
        logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
        boolean b = logMapper.update(name, null, null, null, null, strUtils.getTime() + "");
        return b ? 1 : 0;
    }

    /**
     * 标记领取灵力丹
     */
    public Integer getLLD(String name, DefaultSqlSession con) {
        logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
        List<JSONObject> list = logMapper.getByName(name);
        if (list.size() == 0) {
            return 0;
        }
        boolean b = logMapper.update(name, null, null, null, "1", null);
        return b ? 1 : 0;
    }

    /**
     * 判断在线时长是否足够,以及是否以及领取
     */
    public Integer isEnoughAccumulate(long time,String name, DefaultSqlSession con) {
        logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
        List<JSONObject> list = logMapper.getByName(name);
        if (list.size() == 0) {
            return 0;
        }
        long end = strUtils.getTime();
        long accu = end - list.get(0).getLong("online") + list.get(0).getLong("accumulate");
        if (accu > time) {
            return 1;
        }
        return 0;
    }

    /**
     * 是否领取过灵力丹
     */
    public Integer isGetLLD(String name, DefaultSqlSession con) {
        logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
        List<JSONObject> list = logMapper.getByName(name);
        if (list.size() == 0 || list.get(0).getInteger("is_get_lld") == 1) {
            return 1;
        }
        return 0;
    }

    /**
     * 是否距离上次离帮足够8小时
     */
    public Integer isEnoughLeaveBpTime(String name, DefaultSqlSession con) {
        logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
        List<JSONObject> list = logMapper.getByName(name);
        if (list.size() == 0) {
            return 0;
        }
        if (list.get(0).get("leave_bp_time") == null ||
                strUtils.getTime() - list.get(0).getLong("leave_bp_time") > 8 * 60 * 60 * 1000) {
            return 1;
        }
        return 0;
    }

    /**
     * 获取上线时间
     */
    public Long getOnlineTime(String name, DefaultSqlSession con) {
        logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
        List<JSONObject> list = logMapper.getByName(name);
        if (list.size() == 0) {
            return null;
        }
        return list.get(0).getLong("online");
    }

    /**
     * 上线时调用
     */
    public Integer insertOnlineLog(String name) {
        staticCollection.putTask(() -> {
            SqlSession con = null;
            try {
                con = mybatisConfig.getSqlSession();
                logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
                List<JSONObject> list = logMapper.getByName(name);
                boolean b = false;
                if (list.size() == 0) {
                    b = logMapper.insert(name, strUtils.getTime() + "", "0", "", "0");
                } else {
                    //存在就更新
                    b = logMapper.update(name, strUtils.getTime() + "", null, null, null, null);
                }
                mybatisConfig.commit(con);
            } catch (Exception e) {
                loggerUtils.error("日志插入异常" + e.getMessage(), this.getClass());
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        });
        return 1;
    }

    /**
     * 离线时调用
     */
    public void offLine(String name) {
        staticCollection.putTask(() -> {
            SqlSession con = null;
            try {
                con = mybatisConfig.getSqlSession();
                logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
                List<JSONObject> list = logMapper.getByName(name);
                if (list.size() == 0) {
                    return;
                }
                long end = strUtils.getTime();
                long accu = end - list.get(0).getLong("online") + list.get(0).getLong("accumulate");
                boolean b = logMapper.update(name, null, accu + "", end + "", null, null);
                mybatisConfig.commit(con);
            } catch (Exception e) {
                loggerUtils.error("日志插入异常" + e.getMessage(), this.getClass());
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        });
    }

    /**
     * 插入操作日志
     */
    public Integer insertOp(String type, String name, String des, String ename, String suc) {
        //type 0登录 1使用道具 2邮件 3商品 4道具转移 5寄卖 6技能兑换 7元宝/银两获得记录 8领取累计档活动奖励 9领取印象分元宝
        staticCollection.putTask(() -> {
            SqlSession con = null;
            try {
                con = mybatisConfig.getSqlSession();
                logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
                String id = strUtils.getId();
                String created = strUtils.getTime() + "";
                String ip = staticCollection.getIpByName(name);
                String eip = staticCollection.getIpByName(ename);
                logMapper.insertOp(id, type, ip, name, des, eip, ename, created, suc);
                mybatisConfig.commit(con);
            } catch (Exception e) {
                loggerUtils.error("日志插入异常" + e.getMessage(), this.getClass());
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        });
        return 1;
    }
}
