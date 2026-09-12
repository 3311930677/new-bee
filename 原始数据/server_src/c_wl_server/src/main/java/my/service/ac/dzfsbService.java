package my.service.ac;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.jsonMapper;
import my.db.mybatisConfig;
import my.gameUtils.roleUtils;
import my.model.result;
import my.model.user;
import my.startBef;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.List;

/**
 * 斗战封神榜
 */
public class dzfsbService {
    /**
     * 处理挑战成功后排名变动
     */
    public void handleDzfsb(int win, String rName, String lName) {
        //挑战成功则排名变动
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            if (win == 1) {
                jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
                JSONObject a1 = jsonMapper.selectDzfsbOrderByName(rName).get(0);
                JSONObject a2 = jsonMapper.selectDzfsbOrderByName(lName).get(0);
                //交换sort
                int sort1 = a1.getInteger("sort");
                int sort2 = a2.getInteger("sort");
                int lv1 = startBef.manService.getRoleLv(rName, con);
                int lv2 = startBef.manService.getRoleLv(lName, con);
                if (sort2 < sort1) {//只有被挑战者排行考前才会交换
                    jsonMapper.updateDzfsbOrder(rName, lv1 + "", sort2 + "");
                    jsonMapper.updateDzfsbOrder(lName, lv2 + "", sort1 + "");
                }
            }
            //将战绩插入
            addFightLog(win, rName, lName, con);
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    private void addFightLog(int win, String rName, String lName, DefaultSqlSession con) {
        //最多10条数据
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> al1 = jsonMapper.selectDzfsbLogByName(rName);
        if (al1.size() == 0) {
            jsonMapper.addDzfsbLog(rName, new JSONArray().toString());
            al1 = jsonMapper.selectDzfsbLogByName(rName);
        }
        List<JSONObject> al2 = jsonMapper.selectDzfsbLogByName(lName);
        if (al2.size() == 0) {
            jsonMapper.addDzfsbLog(lName, new JSONArray().toString());
            al2 = jsonMapper.selectDzfsbLogByName(lName);
        }
        JSONArray log1 = al1.get(0).getJSONArray("log");
        JSONArray log2 = al2.get(0).getJSONArray("log");
        JSONObject a1 = new JSONObject();
        a1.put("n1", rName);//挑战者
        a1.put("n2", lName);//接受者
        a1.put("win", win);//结果
        log1.add(a1);
        if (log1.size() > 10) {
            int len = log1.size() - 10;
            for (int i = 0; i < len; i++) {
                log1.remove(0);
            }
        }
        log2.add(a1);
        if (log2.size() > 10) {
            int len = log2.size() - 10;
            for (int i = 0; i < len; i++) {
                log2.remove(0);
            }
        }
        jsonMapper.updateDzfsbLog(rName, log1.toString(), null);
        jsonMapper.updateDzfsbLog(lName, log2.toString(), null);
    }

    /**
     * 获取战斗日志
     */
    public result getFgLog(@paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> al1 = jsonMapper.selectDzfsbLogByName(name);
        if (al1.size() == 0) {
            jsonMapper.addDzfsbLog(name, new JSONArray().toString());
            al1 = jsonMapper.selectDzfsbLogByName(name);
        }
        return new result(200, al1.get(0).getJSONArray("log"));
    }

    /**
     * 获取前100排名
     */
    public result getOrder(JSONObject obj,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (user.msg.getInteger("lever") < 30) {
            return new result(613);
        }
        long pageNum = obj.getLong("pageNum");
        long pageSum = 10L;
        if (pageNum < 1) {
            pageNum = 1;
        } else if (pageNum > 10) {
            pageNum = 10;
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        long n = jsonMapper.selectDzfsbOrderSum().get(0).getInteger("n");
        //先判断榜单上玩家是否存在
        List<JSONObject> ml = jsonMapper.selectDzfsbOrderByName(name);
        if (ml.size() == 0) {
            JSONObject role = startBef.manService.getRole(name, con);
            String model = roleUtils.getModel(role);
            jsonMapper.addDzfsbOrder(name, role.getString("lever"), model, n + "");
        }
        List<JSONObject> aL = jsonMapper.selectDzfsbOrderByPage((pageNum - 1) * pageSum, pageSum);
        for (JSONObject a : aL) {
            a.put("order", a.getInteger("sort") + 1);
            a.remove("sort");
        }
        long total = n % pageSum == 0 ? (n / pageSum) : (n / pageSum + 1);
        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", aL);
        return new result(200, res);
    }
}
