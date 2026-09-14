package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.jsonMapper;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.activityCache;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.fileUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

import static my.utils.staticCollection.cutPriceGoodsMap;
import static my.utils.staticCollection.url;

/**
 * 答题服务
 */
public class answerService {

    /**
     * 提交欢乐答题进度
     */
    public result putHappyProgress(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        int isRight = j.getInteger("isRight");
        final String name = user.name;
        int lv = startBef.manService.getRole(name, con).getInteger("lever");
        if (lv < 20) {
            return new result(0);
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> js = jsonMapper.selectHappyAnswer(name);
        int num = 1;
        int right = 0;
        //不存在则插入
        if (js.size() == 0) {
            jsonMapper.insertHappyAnswer(name, num + "", isRight + "");
            return new result(200, 1);
        } else {
            num = js.get(0).getInteger("num");
            if (num >= 10) {
                return new result(200, 0);
            }
            right = js.get(0).getInteger("right_num");
            if (isRight == 1) {
                right += 1;
            }
            num += 1;
            jsonMapper.updateHappyAnswer(name, num + "", right + "");
        }
        if (num == 10) {
            JSONArray list = startBef.rewardService.getActivityReward(lv, name, "2002", right, con);
            return new result(200, list);
        }
        return new result(200, 1);
    }

    /**
     * 获取欢乐答题进度
     */
    public result getHappyProgress(@paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int lv = startBef.manService.getRole(name, con).getInteger("lever");
        if (lv < 20) {
            return new result(200, 0);
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectHappyAnswer(name);
        if (list.size() == 0) {
            jsonMapper.insertHappyAnswer(name, "0", "0");
            JSONObject o = new JSONObject();
            o.put("num", 0);
            o.put("right_num", 0);
            list.add(o);
        }
        JSONObject res = list.get(0);
        res.put("list", getTenQues(10));
        return new result(200, res);
    }

    /**
     * 随机获取十题
     */
    private JSONArray getTenQues(int sum) {
        String json = fileUtils.readFile(url + "question.json");
        JSONArray list = JSON.parseArray(json);
        JSONArray arr = new JSONArray();
        for (int i = 0; i < sum; i++) {
            int r = strUtils.getRandom(0, list.size());
            boolean b = false;
            for (Object j : arr) {
                JSONObject o = (JSONObject) j;
                if (o.getInteger("index") == r) {
                    b = true;
                    break;
                }
            }
            if (b) {
                i--;
                continue;
            }
            JSONObject obj = (JSONObject) list.get(r);
            obj.put("index", r);
            arr.add(obj);
        }
        return arr;
    }

    /**
     * 提交周末答题进度
     */
    public result putZMAnswerProgress(JSONObject j,
                                      @paramsAnno(key = "user") user user,
                                      @paramsAnno(key = "con") DefaultSqlSession con) {
        if (!startBef.activityService.isOpen("ZMAnswer")) {
            //活动未开启
            return new result(696);
        }
        final String name = user.name;
        final int lv = user.msg.getInteger("lever");
        int index = j.getInteger("num");
        int answer = j.getInteger("answer");

        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> js = jsonMapper.selectZMAnswer(name);
        int num = 1;
        int right = 0;
        //不存在则插入
        if (js.size() == 0) {
            return new result(0);
        }
        //进度最多0-3
        if (js.get(0).getInteger("progress") >= 4) {
            return new result(200, 0);
        }
        num = js.get(0).getInteger("num");
        if (num >= 20) {
            return new result(200, 0);
        }
        JSONArray ans = js.get(0).getJSONArray("ans");
        JSONArray ques = readQues();
        JSONArray qs = getByIndex(ans, ques);
        int isRight = 0;
        if (qs.getJSONObject(index).getInteger("answer") == answer) {
            isRight = 1;
        }
        right = js.get(0).getInteger("right_num");
        if (isRight == 1) {
            right += 1;
        }
        num += 1;
        jsonMapper.updateZMAnswer(name, num + "", right + "", null);
        if (num == 20) {
            //答完题
            int progress = js.get(0).getInteger("progress");
            //进度++
            jsonMapper.updateZMAnswer(name, "0", "0", progress + 1 + "");
            //发放奖励
            JSONObject params = new JSONObject();
            params.put("right", right);
            params.put("progress", progress);
            JSONArray list = startBef.rewardService.getActivityReward(lv, name, "2004", params, con);
            return new result(200, list);
        }
        return new result(200, 1);
    }

    /**
     * 获取周末答题进度
     */
    public result getZMProgress(@paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        if (!startBef.activityService.isOpen("ZMAnswer")) {
            //活动未开启
            return new result(696);
        }
        final String name = user.name;
        int lv = user.msg.getInteger("lever");
        if (lv < 30) return new result(0);

        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectZMAnswer(name);
        JSONArray ques = readQues();
        if (list.size() == 0) {
            JSONArray quesIndex = createQuesIndex(ques, 20);
            jsonMapper.insertZMAnswer(name, JSON.toJSONString(quesIndex));
            JSONObject obj = new JSONObject();
            obj.put("num", 0);
            obj.put("right_num", 0);
            obj.put("progress", 0);
            obj.put("ans", quesIndex);
            list.add(obj);
        }
        if (list.get(0).getInteger("progress") >= 4) {
            return new result(200, 0);
        }
        JSONObject res = list.get(0);
        res.put("list", getByIndex(res.getJSONArray("ans"), ques));
        return new result(200, res);
    }

    /**
     * 清理周末答题
     */
    public void clearZMAnswer() {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
            jsonMapper.delZMAnswer();
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 读取问题
     */
    private JSONArray readQues() {
        String json = fileUtils.readFile(url + "question.json");
        JSONArray list = JSON.parseArray(json);
        return list;
    }

    /**
     * 由index筛选问题
     */
    private JSONArray getByIndex(JSONArray indexs, JSONArray ques) {
        JSONArray list = new JSONArray();
        for (Object o : indexs) {
            list.add(ques.get((int) o));
        }
        return list;
    }

    /**
     * 生成不重复的题号索引
     */
    private JSONArray createQuesIndex(JSONArray list, int num) {
        JSONArray arr = new JSONArray();
        for (int i = 0; i < num; i++) {
            int r = strUtils.getRandom(0, list.size());
            boolean isRepeat = false;
            for (Object a : arr) {
                if (r == (int) a) {
                    isRepeat = true;
                    break;
                }
            }
            if (isRepeat) {
                i--;
            } else {
                arr.add(r);
            }
        }
        return arr;
    }
}
