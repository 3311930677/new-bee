package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.gangsMapper;
import my.dao.jsonMapper;
import my.dao.logMapper;
import my.data.mapData;
import my.data.taskData;
import my.db.mybatisConfig;
import my.gameUtils.roleUtils;
import my.model.*;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import my.utils.systemUtils;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.*;

/**
 * 任务服务
 */
public class taskService {
    /**
     * 门派任务接取（职业跑环）
     */
    public result getMenPaiTask(@paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String mp = roleUtils.getMenPaiFromModels(user.msg);
        if (mp == null) return new result(0);
        JSONArray list1 = startBef.taskService.getTaskList(name, con);
        for (Object a : list1) {
            JSONObject l = (JSONObject) a;
            int k = l.getInteger("key");
            if (3100 <= k && k < 3120) {
                //已经接取
                return new result(765);
            }
        }
        List<String> rdTask = new ArrayList<>();
        //获取所有已提交的任务
        JSONArray list2 = startBef.taskService.getCommitTask(name, con);
        for (int i = 3100; i < 3120; i++) {
            boolean b = false;
            for (Object a : list2) {
                int k = Integer.parseInt(a.toString());
                if (i == k) {//在完成的任务中已经存在
                    b = true;
                    break;
                }
            }
            if (!b) {//不存在的才加入
                rdTask.add(i + "");
            }
        }
        //判断是否还有接取的次数
        if (rdTask.size() == 0) return new result(854);
        Collections.shuffle(rdTask);
        String k = rdTask.get(0).toString();
        //不含有起始对话进度，所以progressIndex=0
        JSONObject task = startBef.taskService.createAcTask(k, name, con);
        return new result(200, k);
    }

    /**
     * 获取其他活动列表信息
     */
    public result getElseAcMsg() {
        //开启时间、结束时间
        JSONArray list = new JSONArray();

        if (startBef.activityService.isOpen("sjjl")) {
            activityCache ac = startBef.activityService.getMsg("sjjl");
            addElseAc("20430000",
                    ac.startDay.replace(" 00:00:00", "") + "~" +
                            ac.endDay.replace(" 00:00:00", ""), list);
        }
        if (startBef.activityService.isOpen("msjl")) {
            //activityCache ac = startBef.activityService.getMsg("msjl");
            addElseAc("20430003",
                    "全天", list);
        }


        return new result(200, list);
    }

    private void addElseAc(String k, String openTime, JSONArray list) {
        JSONObject a = new JSONObject();
        a.put("key", k);
        a.put("openTime", openTime);
        list.add(a);
    }

    /**
     * 接取师徒任务
     */
    public Object getStTask(String name, int lever, DefaultSqlSession con) {
        String[] arr = new String[1];
        if (lever >= 15 && lever < 20) {
            arr[0] = "3123";
        } else if (lever >= 20 && lever < 25) {
            arr[0] = "3124";
        } else if (lever >= 25 && lever < 30) {
            arr[0] = "3125";
        } else if (lever >= 30 && lever < 35) {
            arr[0] = "3126";
        } else if (lever >= 35 && lever < 40) {
            arr[0] = "3127";
        } else if (lever >= 40 && lever < 45) {
            arr[0] = "3128";
        } else if (lever >= 45 && lever < 50) {
            arr[0] = "3129";
        } else if (lever >= 50 && lever < 60) {
            arr[0] = "3130";
        } else {
            return 0;
        }
        int i = isGetTaskList(arr, name, con);
        if (i == 1) {
            //任务中存在不完成的
            return -1;
        }
        i = isCommitList(arr, name, con);
        if (i == 1) {
            return -2;
        }
        createTask(arr[0], name, con);
        //触发战斗
        startBef.fightRpcService.createFightByTask(name, arr[0], con);
        return arr[0];
    }

    private JSONObject createListItem(String k, int status, int progressIndex) {
        JSONObject o = new JSONObject();
        o.put("key", k);
        o.put("status", status);
        o.put("progressIndex", progressIndex);
        return o;
    }

    /**
     * 接取活动任务
     */
    public result getHDTask(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (true) return new result(0);
        String key = j.getString("key");
        //需要清理的任务
        List<String> remList = new ArrayList<>();
        //需要创建的任务
        List<JSONObject> createList = new ArrayList<>();
        switch (key) {
            case "3100": {//门派任务
                //获取所有接取的任务
                JSONArray list1 = getTaskList(name, con);
                for (Object a : list1) {
                    JSONObject l = (JSONObject) a;
                    int k = l.getInteger("key");
                    if (3100 <= k && k < 3120) {
                        //已经接取
                        return new result(200, -2);
                    }
                }
                //获取所有已提交的任务
                int num = 0;
                JSONArray list2 = getCommitTask(name, con);
                for (Object a : list2) {
                    int k = Integer.parseInt(a.toString());
                    if (3100 <= k && k < 3120) {
                        num++;
                    }
                }
                //判断是否还有接取的次数
                if (num >= 10) return new result(200, -3);
                //从20个任务中随机一个（不重复的）
                Integer k = strUtils.getRandom(3100, 3120, list2);
                //对于提交表中已经存在所有该范围的任务
                if (k == null) return new result(0);
                //不含有起始对话进度，所以progressIndex=0
                createList.add(createListItem(k.toString(), 2, 0));//自动接取
                break;
            }
            case "3131": {//洪荒宝库任务
                //需要把相关的任务都移除
                remList.add("3131");
                remList.add("3132");
                remList.add("3133");
                remList.add("3134");
                //带了一个起始对话任务，所以progressIndex=1
                createList.add(createListItem("3131", 2, 1));//自动接取
                createList.add(createListItem("3132", 1, 0));
                //扣除一个洪荒密钥
                if (startBef.packageService.cutPlayerGoodsNumByKey("10000140", 1, name, con) != 1)
                    return new result(0);
                //将开启的宝箱清空
                activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
                activityMapper.updateYGMB(name, "0", "0", "0");
                break;
            }
            case "3135": {//门派闯关
                //判断是否在活动时间内
                if (!startBef.activityService.isOpen("ztzs")) {
                    return new result(200, 0);
                }
                //等级是否满足60级
                if (user.msg.getInteger("lever") < 60) {
                    return new result(200, -1);
                }
                //是否已经接取
                if (isInTaskList("3135", name, con)) {
                    return new result(200, -2);
                }

                //需要把相关的任务都移除
                for (int i = 3135; i < 3143; i++) {
                    remList.add(i + "");
                }
                createList.add(createListItem("3135", 2, 1));//自动接取
                createList.add(createListItem("3136", 1, 0));
                break;
            }
            case "3143": {//帮派任务
                //获取所有接取的任务
                JSONArray list1 = getTaskList(name, con);
                for (Object a : list1) {
                    JSONObject l = (JSONObject) a;
                    int k = l.getInteger("key");
                    if (3143 <= k && k < 3163) {
                        //已经接取
                        return new result(200, -2);
                    }
                }
                //获取所有已提交的任务
                int num = 0;
                JSONArray list2 = getCommitTask(name, con);
                for (Object a : list2) {
                    int k = Integer.parseInt(a.toString());
                    if (3143 <= k && k < 3163) {
                        num++;
                    }
                }
                //判断是否还有接取的次数
                if (num >= 10) return new result(200, -3);
                //从20个任务中随机一个（不重复的）
                Integer k = strUtils.getRandom(3143, 3163, list2);
                //对于提交表中已经存在所有该范围的任务
                if (k == null) return new result(0);
                //不含有起始对话进度，所以progressIndex=0
                createList.add(createListItem(k.toString(), 2, 0));//自动接取
                break;
            }
            default:
                return new result(0);
        }
        //移除完成的、已接取的该任务
        boolean b = false;
        JSONArray list = getCommitTask(name, con);
        for (String k : remList) {
            for (int i = 0; i < list.size(); i++) {
                if (list.get(i).equals(k)) {
                    b = true;
                    list.remove(i);
                    break;
                }
            }
        }
        if (b) {
            saveSubmitTask(list, name, con);
        }
        list.clear();
        list.addAll(getTaskList(name, con));
        for (String k : remList) {
            for (int i = 0; i < list.size(); i++) {
                JSONObject obj = (JSONObject) list.get(i);
                if (obj.getString("key").equals(k)) {
                    list.remove(i);
                    break;
                }
            }
        }
        if (createList != null) {
            for (JSONObject s : createList) {
                list.add(getTaskItem(s.getInteger("progressIndex"), s.getString("key"), s.getInteger("status"), 0));
            }
        }
        int i = saveTask(list, name, con);
        list.clear();

        JSONObject res = new JSONObject();
        res.put("createList", createList);
        res.put("remList", remList);
        return new result(200, res);
    }

    /**
     * 创建活动任务
     */
    public JSONObject createAcTask(String key, String name, DefaultSqlSession con) {
        //接取/提交过的则不允许再次接取
        if (isInTaskList(key, name, con)) return null;
        //一个已接取状态的任务
        JSONObject s = createListItem(key, 2, 0);
        JSONObject a = getTaskItem(s.getInteger("progressIndex"), s.getString("key"), s.getInteger("status"), 0);
        JSONArray list = getTaskList(name, con);
        list.add(a);
        saveTask(list, name, con);
        return a;
    }

    /**
     * 移除任务列表中的某些任务
     */
    public void removeNoSubmitTask(String name, DefaultSqlSession con, String... remList) {
        boolean b = false;
        JSONArray list = getTaskList(name, con);
        for (String k : remList) {
            for (int i = 0; i < list.size(); i++) {
                JSONObject a = list.getJSONObject(i);
                if (a.getString("key").equals(k)) {
                    b = true;
                    list.remove(i);
                    i--;
                }
            }
        }
        if (b) {
            saveTask(list, name, con);
        }
    }

    /**
     * 移除已经提交的任务列表
     */
    public void removeSubmitTask(String name, DefaultSqlSession con, String... remList) {
        boolean b = false;
        JSONArray list = getCommitTask(name, con);
        for (String k : remList) {
            for (int i = 0; i < list.size(); i++) {
                if (list.get(i).equals(k)) {
                    b = true;
                    list.remove(i);
                    i--;
                }
            }
        }
        if (b) {
            saveSubmitTask(list, name, con);
        }
    }

    /**
     * 是否存在于任务列表或提交的列表
     */
    private boolean isInTaskList(String key, String name, DefaultSqlSession con) {
        String[] arr = {key};
        return isInTaskList(arr, name, con);
    }

    private boolean isInTaskList(String arr[], String name, DefaultSqlSession con) {
        int i = isGetTaskList(arr, name, con);
        if (i == 1) {
            //任务中存在不完成的
            return true;
        }
        i = isCommitList(arr, name, con);
        if (i == 1) {
            return true;
        }
        return false;
    }

    /**
     * 状态是否为可提交
     */
    public Integer isOverTask(String key, String name, DefaultSqlSession con) {
        String[] keys = new String[1];
        keys[0] = key;
        return isOverTaskList(keys, name, con);
    }

    public Integer isOverTaskList(String[] keys, String name, DefaultSqlSession con) {
        JSONArray doList = this.getTaskList(name, con);
        for (Object o : doList) {
            JSONObject obj = (JSONObject) o;
            for (String key : keys) {
                if (obj.getString("key").equals(key) && obj.getInteger("status") == 3) {
                    return 1;
                }
            }
        }
        return 0;
    }

    /**
     * 判断某个任务是否已经提交
     */
    public int isCommit(String key, String name, DefaultSqlSession con) {
        String[] keys = {key};
        return isCommitList(keys, name, con);
    }

    public int isCommitList(String[] keys, String name, DefaultSqlSession con) {
        JSONArray list = getCommitTask(name, con);
        for (Object o : list) {
            for (int i = 0; i < keys.length; i++) {
                String key = keys[i];
                if (o.equals(key)) {
                    return 1;
                }
            }
        }
        return 0;
    }

    /**
     * 获取职业任务
     */
    /*public result getJobTask(@paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String[] arr = {
                "3100", "3101", "3102", "3103", "3104",
                "3105", "3106", "3107", "3108", "3109",
                "3110",
        };
        int i = isGetTaskList(arr, name, con);
        if (i == 1) {
            //任务中存在不完成的不允许接取
            return new result(200, 0);
        }
        JSONArray list = getCommitTask(name, con);
        //已完成的职业任务数量不能超过10
        int num = 0;
        for (Object l : list) {
            for (String a : arr) {
                if (l.equals(a)) {
                    num++;
                    break;
                }
            }
        }
        if (num >= 10) {
            return new result(200, 0);
        }
        //随机接取一个未有的任务
        String k = getRandomTask(arr, list);
        createTask(k, name, con);
        return new result(200, k);
    }*/

    /**
     * 创建一个任务，前提是提交表、任务表都不存在这个key
     */
    public Integer createTask(String taskKey, String name, DefaultSqlSession con) {
        JSONObject task = new JSONObject();
        task.put("progressIndex", 0);
        JSONObject taskProgress = new JSONObject();
        JSONObject target = new JSONObject();
        target.put("num", 0);
        taskProgress.put("target", target);
        task.put("taskProgress", taskProgress);
        task.put("key", taskKey);
        task.put("status", 2);
        JSONArray doList = this.getTaskList(name, con);
        doList.add(task);
        saveTask(doList, name, con);
        return 1;
    }

    /**
     * 创建任务，要求包含{key,status}
     * 注意是进度0
     */
    public int createTasks(String[] tasks, String name, DefaultSqlSession con) {
        JSONArray doList = this.getTaskList(name, con);
        for (int i = 0; i < tasks.length; i++) {
            String k = tasks[i];
            JSONObject task = new JSONObject();
            task.put("progressIndex", 0);
            JSONObject taskProgress = new JSONObject();
            JSONObject target = new JSONObject();
            target.put("num", 0);
            taskProgress.put("target", target);
            task.put("taskProgress", taskProgress);
            task.put("key", k);
            task.put("status", "1");
            doList.add(task);
        }
        saveTask(doList, name, con);
        return 1;
    }

    /**
     * 随机获取一个任务
     */
    private String getRandomTask(String[] arr, JSONArray list) {
        String key = arr[strUtils.getRandom(0, arr.length)];
        for (Object l : list) {
            if (l.equals(key)) {
                return getRandomTask(arr, list);
            }
        }
        return key;
    }

    /**
     * 判断是否有某些任务
     */
    public int isGetTaskList(String name, DefaultSqlSession con, String... keys) {
        return isGetTaskList(keys, name, con);
    }

    public int isGetTaskList(String[] keys, String name, DefaultSqlSession con) {
        JSONArray doList = this.getTaskList(name, con);
        for (Object o : doList) {
            JSONObject obj = (JSONObject) o;
            for (String key : keys) {
                if (obj.getString("key").equals(key)) {
                    return 1;
                }
            }
        }
        return 0;
    }
    /**是否接取*/

    /**
     * 提交特殊npcKey
     */
    public result putSpecial(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray res = null;
        switch (j.getString("npcKey")) {
            case "5043": {//宝藏
                //判断是否已经完成
                activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
                List<JSONObject> list = activityMapper.getCBT(name);
                if (list.size() == 0 || list.get(0).getInteger("finish") == 1) {
                    return new result(0);
                }
                activityMapper.finishCBT(name);
                //发放奖励
                res = startBef.rewardService.getCBTReward(name, list.get(0).getInteger("lv"), con);
                break;
            }
            case "5082": {//年兽
                String mapKey = user.getPos().getString("map");
                if (mapKey == null) {
                    break;
                }
                //数量减少成功才有奖励
                if (startBef.npcCreateService.cutOneByMapKey(mapKey)) {
                    res = startBef.rewardService.createGoods("1097", 1, 1, name, con);
                    //调取战斗
                    String mons[] = {"nianshou", "nianshou", "nianshou", "nianshou", "nianshou", "nianshou"};
                    startBef.fightRpcService.createFightByAc(name, new ArrayList<>(Arrays.asList(mons)), con);
                }
                break;
            }
            /*case "5075":{//月饼
                //判断是否月饼数够30了
                activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
                List<JSONObject> list = activityMapper.getAcDayLimit(name);
                if(list.size()==0){
                    if(!activityMapper.insertAcDayLimit(name,0)){
                        break;
                    }
                    JSONObject obj=new JSONObject();
                    obj.put("yuebing",0);
                    list.add(obj);
                }
                int num=list.get(0).getInteger("yuebing");
                if(num>=30){
                    break;
                }
                num++;
                if(!activityMapper.updateAcDayLimit(name,num)){
                    break;
                }
                String mapKey=user.getPos().getString("map");
                if(mapKey==null){
                    break;
                }
                //数量减少成功才有奖励
                if(startBef.zhouqiuAcService.cutOneByMapKey(mapKey)){
                    res = startBef.rewardService.createGoods("1067",1,name,con);
                }
                break;
            }*/
        }
        return new result(200, res);
    }

    /**
     * 提交任务
     */
    public result submitTask(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        Object res = submitOneTask(key, name, con);
        return new result(200, res);
    }

    /*
     * 1.战斗结束后触发怪物收集，触发任务对怪物的数量检测，有足够数量时把任务状态设置成可提交
     * 2.有可能点击提交后触发任务开启的检测导致任务再次开启（sub中没有，所以不是这个原因）
     * 3.提交回滚
     * */
    //todo:bug点击提交后这里似乎回滚了，task表还是status=1，sub表没有这个key，战斗收集怪物时可能未能成功
    private Object submitOneTask(String key, String name, DefaultSqlSession con) {
        JSONArray overList = null;
        JSONArray doList = this.getTaskList(name, con);
        int len = doList.size();
        boolean b = false;
        for (int i = 0; i < len; i++) {
            JSONObject obj = (JSONObject) doList.get(i);
            if (obj.getString("key").equals(key)) {
                if (obj.getInteger("status") != 3) {//不是完成状态
                    return 0;
                }
                doList.remove(i);
                overList = this.getCommitTask(name, con);
                overList.add(key);
                b = true;
                break;
            }
        }
        //对于不存在的任务不允许继续向后执行
        if (!b) {
            return 0;
        }
        saveTask(doList, name, con);
        if (saveSubmitTask(overList, name, con) == 1) {
            JSONObject r = new JSONObject();
            //todo:验证副本还有剩余次数就要通知前端进行删除关联的任务
            //对于副本任务判断是否需要刷新
            if (handleFbTask(overList, key, name, con) == 1) {
                r.put("isDel", 1);
            }
            //对于盗梦任务需要移除
            if (handleDMKJTask(overList, key, name, con) == 1) {
                r.put("isDel", 1);
            }
            //对于幽谷秘宝任务需要掉落宝箱
            handleYGMBTask(key, name, con);
            //对于帮派任务需要添加帮贡
            handleBPTask(key, name, con);
            //对于洪荒宝库需要掉落宝箱
            handleHHBKTask(key, name, con);

            //检测是否有任务开启（某个任务提交后可能并没有升级，但是却达到了下个任务的开启条件）
            checkTaskStart(name, con);
            //保存奖励（加exp，可能发生升级，升级处有检测任务是否开启）
            JSONArray res = startBef.rewardService.saveRewardsByTask(key, name, con);
            r.put("reward", res);

            //通知队员提交任务（因为这里只处理队长的任务）
            teamMemberToGetTask(3, name, key);
            return r;
        }
        return 0;
    }

    /**
     * 帮派任务的处理
     */
    private void handleBPTask(String key, String name, DefaultSqlSession con) {
        int k = Integer.parseInt(key);
        if (k < 3143 || k >= 3163) {
            return;
        }
        //对个人今日贡献、帮派总贡献的处理
        startBef.gangsService.handleBpTaskRewards(40, name, con);
    }

    /**
     * 处理幽谷秘宝任务
     * 提交后生成宝箱
     */
    private void handleYGMBTask(String key, String name, DefaultSqlSession con) {
        //推送宝箱
        //List<JSONObject> list = new ArrayList<>();
        //startBef.ygmbService.sendBox(key, list, name, true);
    }

    /**
     * 处理洪荒宝库任务
     * 提交后生成宝箱
     */
    private void handleHHBKTask(String key, String name, DefaultSqlSession con) {
        //推送宝箱
        List<JSONObject> list = new ArrayList<>();
        startBef.hhbkService.sendBox(key, list, name, true);
    }

    private int handleDMKJTask(JSONArray overList, String key, String name, DefaultSqlSession con) {
        if (key.equals("3275") || key.equals("3276") || key.equals("3277") ||
                key.equals("3278") || key.equals("3279") || key.equals("3280") ||
                key.equals("3281")) {
            for (int i = 0; i < overList.size(); i++) {
                if (overList.get(i).equals(key)) {
                    overList.remove(i);
                    break;
                }
            }
            return saveSubmitTask(overList, name, con);
        }
        return 0;
    }

    /**
     * 处理副本任务
     */
    private int handleFbTask(JSONArray overList, String key, String name, DefaultSqlSession con) {
        if (key.equals("3168") || key.equals("3174") ||
                key.equals("3183") || key.equals("3188") ||
                key.equals("3195") || key.equals("3202") ||
                key.equals("3212") || key.equals("3220") ||
                key.equals("3228") || key.equals("3234")) {
            //检验是否还有副本次数
            activityMapper acMapper = mybatisConfig.getMapper(con, activityMapper.class);
            List<JSONObject> list = acMapper.getFb(name);

            JSONObject fb = list.get(0);
            String fbKey = "";
            if (key.equals("3168")) {
                fbKey = "fb50";
            } else if (key.equals("3174")) {
                fbKey = "fb60";
            } else if (key.equals("3183")) {
                fbKey = "fb70";
            } else if (key.equals("3188")) {
                fbKey = "fb80";
            } else if (key.equals("3195")) {
                fbKey = "fb90";
            } else if (key.equals("3202")) {
                fbKey = "fb100";
            } else if (key.equals("3212")) {
                fbKey = "fbls";
            } else if (key.equals("3220")) {
                fbKey = "fbhh";
            } else if (key.equals("3228")) {
                fbKey = "fbys";
            } else if (key.equals("3234")) {
                fbKey = "fbzx";
            }
            //次数--
            int n = fb.getInteger(fbKey) - 1;
            fb.put(fbKey, n);
            Iterator<String> it = fb.keySet().iterator();
            while (it.hasNext()) {
                String k = it.next();
                if (!k.equals(fbKey)) {
                    it.remove();
                }
            }

            String fb50N = fb.getString("fb50");
            String fb60N = fb.getString("fb60");
            String fb70N = fb.getString("fb70");
            String fb80N = fb.getString("fb80");
            String fb90N = fb.getString("fb90");
            String fb100N = fb.getString("fb100");
            String fblsN = fb.getString("fbls");
            String fbhhN = fb.getString("fbhh");
            String fbysN = fb.getString("fbys");
            String fbzxN = fb.getString("fbzx");
            String fbyzjN = fb.getString("fbyzj");
            //更新副本次数
            if (!acMapper.updateFb(name, fb50N, fb60N, fb70N,
                    fb80N, fb90N, fb100N, fblsN, fbhhN, fbysN, fbzxN, fbyzjN)) {
                return 0;
            }
            //次数>0则可刷新任务
            if (n > 0) {
                //统计相关任务
                List<String> arr = getSerialTask(key);
                //移除提交的副本任务
                for (int i = 0; i < overList.size(); i++) {
                    for (String a : arr) {
                        if (overList.get(i).equals(a)) {
                            overList.remove(i);
                            i--;
                            break;
                        }
                    }
                }
                return saveSubmitTask(overList, name, con);
            }

        }
        return 0;
    }

    /**
     * 获取相关任务（由结尾任务确定）
     */
    private List<String> getSerialTask(String key) {
        List<String> list = new ArrayList<>();
        int start = 0;
        int end = 0;
        if (key.equals("3168")) {
            start = 3163;
            end = 3169;
        } else if (key.equals("3174")) {
            start = 3169;
            end = 3175;
        } else if (key.equals("3183")) {
            start = 3175;
            end = 3184;
        } else if (key.equals("3188")) {
            start = 3184;
            end = 3189;
        } else if (key.equals("3195")) {
            start = 3189;
            end = 3196;
        } else if (key.equals("3202")) {
            start = 3196;
            end = 3203;
        } else if (key.equals("3212")) {
            start = 3203;
            end = 3213;
        } else if (key.equals("3220")) {
            start = 3213;
            end = 3221;
        } else if (key.equals("3228")) {
            start = 3221;
            end = 3229;
        } else if (key.equals("3234")) {
            start = 3229;
            end = 3235;
        } else if (key.equals("3241")) {
            start = 3235;
            end = 3242;
        }
        for (int i = start; i < end; i++) {
            list.add(i + "");
        }
        return list;
    }

    /**
     * 提交收集的采集物
     */
    public result commitCjw(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String npcKey = j.getString("key");
        if (npcKey == null) return new result(0);
        //获取队员
        JSONObject team = startBef.teamService.getTeamByName(name);
        JSONArray names = new JSONArray();
        if (team == null) {
            names.add(name);
        } else {
            JSONArray list = team.getJSONArray("list");
            for (Object l : list) {
                JSONObject a = (JSONObject) l;
                names.add(a.getString("name"));
            }
        }
        for (Object n : names) {
            boolean b = false;
            JSONArray doList = this.getTaskList((String) n, con);
            //遍历任务列表
            for (Object o : doList) {
                JSONObject obj = (JSONObject) o;
                //要求只有在进行中的任务才允许提交数量
                if (obj.getInteger("status") != 2) {
                    continue;
                }
                JSONObject taskMsg = taskData.getTask(obj.getString("key"));
                //不存在该任务（比如：跳跳虎任务）
                if (taskMsg == null) {
                    continue;
                }
                JSONArray progressList = taskMsg.getJSONArray("progressList");
                JSONObject progress = (JSONObject) progressList.get(obj.getInteger("progressIndex"));
                //要求是采集物类型
                if (progress.getInteger("type") != 1) {
                    continue;
                }
                if (progress.getJSONObject("target").getInteger("targetType") == 0 &&
                        progress.getJSONObject("target").getString("key").equals(npcKey)) {
                    b = true;
                    int collectionNum = obj.getJSONObject("taskProgress").getJSONObject("target").
                            getInteger("num") + 1;
                    //判断收集数量是否满足
                    if (progress.getJSONObject("target").getInteger("sum") > collectionNum) {
                        //不满足则只更新数量
                        obj.getJSONObject("taskProgress").getJSONObject("target").put("num", collectionNum);
                    } else {
                        //满足则进度index+1，判断是否超过总进度数
                        if (obj.getInteger("progressIndex") + 1 >= progressList.size()) {
                            obj.getJSONObject("taskProgress").getJSONObject("target").put("num",
                                    progress.getJSONObject("target").getInteger("sum"));
                            //超过则视为任务完成
                            obj.put("status", 3);
                        } else {
                            //进度+1
                            obj.getJSONObject("taskProgress").getJSONObject("target").put("num", 0);
                            obj.put("progressIndex", obj.getInteger("progressIndex") + 1);
                        }
                    }
                }
            }
            if (!b) {
                continue;
            }
            //保存
            saveTask(doList, (String) n, con);
        }
        //通知收集
        JSONObject msg = new JSONObject();
        msg.put("npcKey", npcKey);
        msg.put("num", 1);
        for (Object n : names) {
            ChannelSupervise.noticeClientByName(msg, (String) n, "842");
        }
        return new result(200, 1);
    }

    /**
     * 提交怪物数量(包含组队)
     */
    public Integer commitMonster(JSONObject j) {
        String monsterKey = j.getString("monsterKey");
        int num = j.getInteger("monsterNum");
        JSONArray names = j.getJSONArray("names");

        DefaultSqlSession con = null;
        for (Object name : names) {
            try {
                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                boolean b = false;
                JSONArray doList = this.getTaskList((String) name, con);
                //遍历任务列表
                for (Object o : doList) {
                    JSONObject obj = (JSONObject) o;
                    //要求只有在进行中的任务才允许提交数量
                    if (obj.getInteger("status") != 2) {
                        continue;
                    }
                    JSONObject taskMsg = taskData.getTask(obj.getString("key"));
                    //不存在该任务（比如：跳跳虎任务）
                    if (taskMsg == null) {
                        continue;
                    }
                    JSONArray progressList = taskMsg.getJSONArray("progressList");
                    JSONObject progress = (JSONObject) progressList.get(obj.getInteger("progressIndex"));
                    if (progress.getJSONObject("target").getInteger("targetType") == 1 &&
                            progress.getJSONObject("target").getString("key").equals(monsterKey)) {
                        b = true;
                        int collectionNum = obj.getJSONObject("taskProgress").getJSONObject("target").
                                getInteger("num") + num;
                        //判断收集数量是否满足
                        if (progress.getJSONObject("target").getInteger("sum") > collectionNum) {
                            //不满足则只更新数量
                            obj.getJSONObject("taskProgress").getJSONObject("target").put("num", collectionNum);
                        } else {
                            //满足则进度index+1，判断是否超过总进度数
                            if (obj.getInteger("progressIndex") + 1 >= progressList.size()) {
                                obj.getJSONObject("taskProgress").getJSONObject("target").put("num",
                                        progress.getJSONObject("target").getInteger("sum"));
                                //超过则视为任务完成
                                obj.put("status", 3);
                            } else {
                                //进度+1
                                obj.getJSONObject("taskProgress").getJSONObject("target").put("num", 0);
                                obj.put("progressIndex", obj.getInteger("progressIndex") + 1);
                            }
                        }
                    }
                }
                if (!b) {
                    continue;
                }
                //保存
                saveTask(doList, (String) name, con);
                mybatisConfig.commit(con);
            } catch (Exception e) {
                e.printStackTrace();
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        }
        //通知收集
        JSONObject msg = new JSONObject();
        msg.put("monKey", monsterKey);
        msg.put("num", num);
        for (Object name : names) {
            ChannelSupervise.noticeClientByName(msg, (String) name, "842");
        }
        return 1;
    }

    /**
     * 放弃任务
     */
    /*public result abandonTask(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray doList = this.getTaskList(name, con);
        for (Object o : doList) {
            JSONObject obj = (JSONObject) o;
            //要求正在进行中的任务才允许放弃
            if (obj.getString("key").equals(j.getString("key")) &&
                    obj.getInteger("status") == 2) {
                obj.put("status", 1);
                obj.put("progressIndex", 0);
                obj.getJSONObject("taskProgress").getJSONObject("target").put("num", 0);
                return new result(200, saveTask(doList, name, con));
            }
        }
        return new result(0);
    }*/

    /**
     * 更新任务
     */
    public Integer updateTask(String key, int num, String name, boolean isClient, DefaultSqlSession con) {
        //判断任务是否已经完成，或者任务处于进行中状态
        JSONArray overList = this.getCommitTask(name, con);
        for (Object o : overList) {
            if (o.equals(key)) {
                return 0;
            }
        }
        boolean b = false;
        JSONArray doList = this.getTaskList(name, con);
        for (Object o : doList) {
            JSONObject obj = (JSONObject) o;
            if (obj.getString("key").equals(key)) {
                if (obj.getInteger("status") != 2) {//不是进行中状态
                    return 0;
                }
                //更新任务进度、数量
                //判断当前进度提交来源
                JSONObject taskMsg = taskData.getTask(key);
                JSONArray progressList = taskMsg.getJSONArray("progressList");
                JSONObject progress = (JSONObject) progressList.get(obj.getInteger("progressIndex"));
                //目标类型为怪物（战斗的来源是服务器）
                if (isClient) {
                    if (progress.getJSONObject("target").getInteger("targetType") == 1) {
                        return 0;
                    }
                }
                int collectionNum = obj.getJSONObject("taskProgress").getJSONObject("target").
                        getInteger("num") + num;
                //判断收集数量是否满足
                if (progress.getJSONObject("target").getInteger("sum") < collectionNum) {
                    //不满足则只更新数量
                    obj.getJSONObject("taskProgress").getJSONObject("target").put("num", collectionNum);
                } else {
                    //满足则进度index+1，判断是否超过总进度数
                    if (obj.getInteger("progressIndex") + 1 >= progressList.size()) {
                        obj.getJSONObject("taskProgress").getJSONObject("target").put("num",
                                progress.getJSONObject("target").getInteger("sum"));
                        //超过则视为任务完成
                        obj.put("status", 3);
                    } else {
                        //进度+1
                        obj.getJSONObject("taskProgress").getJSONObject("target").put("num", 0);
                        obj.put("progressIndex", obj.getInteger("progressIndex") + 1);
                    }
                }
                b = true;
                break;
            }
        }
        //对于不存在的任务不允许继续向后执行
        if (!b) {
            return 0;
        }
        //保存
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, my.dao.jsonMapper.class);
        return jsonMapper.updateTaskByName(JSON.toJSONString(doList), name) ? 1 : 0;
    }


    /**
     * 接取任务
     */
    public result getTask(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        return new result(200, getOneTask(j.getString("key"), name, con));
    }

    private Integer getOneTask(String taskKey, String name, DefaultSqlSession con) {
        JSONArray doList = this.getTaskList(name, con);
        for (Object o : doList) {
            JSONObject obj = (JSONObject) o;
            if (obj.getString("key").equals(taskKey)) {
                if (obj.getInteger("status") != 1) {//不是可接取状态
                    return 0;
                }
                //将状态变为已接取
                obj.put("status", 2);
                int i = saveTask(doList, name, con);
                if (i == 1) {
                    //fixme:接取后不触发进度++
                    //接取后触发某些效果，如进入战斗、任务刷新等
                    //int r = triggerByProgressType(taskKey, name, con);
                    //如果是队长的话通知队员接取任务
                    teamMemberToGetTask(1, name, taskKey);
                    /*
                    if(r==1){
                        //通知队员更新任务缓存
                        teamMemberToGetTask(2, name, taskKey, con);
                    }*/

                }
                return i;
            }
        }
        return 0;
    }

    /**
     * 通知队员接取任务
     */
    private void teamMemberToGetTask(int type, String name, String taskKey) {
        staticCollection.putTask(() -> {
            try {
                //不是队长不允许执行
                JSONObject team = startBef.teamService.getTeamByName(name);
                if (team == null || !team.getString("captain").equals(name)) {
                    return;
                }
                JSONArray list = team.getJSONArray("list");
                for (Object l : list) {
                    JSONObject jb = (JSONObject) l;
                    final String memberName = jb.getString("name");
                    if (!memberName.equals(name) && jb.getInteger("isFollow") == 1) {
                        String callback = null;
                        if (type == 1) {//接取
                            DefaultSqlSession con = null;
                            try {
                                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                                if (getOneTask(taskKey, memberName, con) == 1) {
                                    callback = "814";
                                }
                                mybatisConfig.commit(con);
                            } catch (Exception e) {
                                e.printStackTrace();
                                mybatisConfig.rollback(con);
                            } finally {
                                mybatisConfig.close(con);
                            }

                        } else if (type == 2) {//更新
                            callback = "815";
                        } else if (type == 3) {//提交
                            //通知队员提交
                            callback = "816";
                        }
                        //接取后通知成员刷新刷新
                        if (callback != null) {
                            ChannelSupervise.noticeClientByName(taskKey, memberName, callback);
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        });

    }

    /**
     * 触发进度更新
     */
    public result trigger(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String taskKey = j.getString("key");
        int i = triggerByProgressType(taskKey, name, con);
        //通知队员触发进度更新
        JSONObject team = startBef.teamService.getTeamByName(name);
        if (team != null) {
            JSONArray list = team.getJSONArray("list");
            //不是队长就不要通知队员
            if (!team.getString("captain").equals(name)) {
                return new result(200, i);
            }
            for (Object l : list) {
                JSONObject o = (JSONObject) l;
                if (!name.equals(o.getString("name"))) {
                    //队员触发刷新
                    triggerByProgressType(taskKey, o.getString("name"), con);
                }
            }
        }
        if (i == 1) {
            //通知队员刷新缓存
            teamMemberToGetTask(2, name, taskKey);
        }
        return new result(200, i);
    }

    /**
     * 接取任务后调用，对进度类型的处理
     */
    private Integer triggerByProgressType(String key, String name, DefaultSqlSession con) {
        JSONArray doList = this.getTaskList(name, con);
        boolean b = false;
        for (Object o : doList) {
            JSONObject obj = (JSONObject) o;
            if (obj.getString("key").equals(key)) {
                b = true;
                //要求任务状态必须是进行中才允许触发
                if (obj.getInteger("status") != 2) {
                    return 0;
                }
                JSONObject taskMsg = taskData.getTask(key);
                JSONArray progressList = taskMsg.getJSONArray("progressList");
                JSONObject progress = (JSONObject) progressList.get(obj.getInteger("progressIndex"));
                if (progress.getInteger("type") == 0) {//对话任务
                    this.updateTask(key, 1, name, false, con);
                } else if (progress.getInteger("type") == 1) {//摘取

                } else if (progress.getInteger("type") == 2) {//战斗
                    //fixme:注意调取战斗时只能用队长调
                    JSONObject team = startBef.teamService.getTeamByName(name);
                    if (team != null) {
                        if (team.getString("captain").equals(name)) {
                            startBef.fightRpcService.createFightByTask(name, key, con);
                        }
                    } else {
                        startBef.fightRpcService.createFightByTask(name, key, con);
                    }
                } else if (progress.getInteger("type") == 3) {//接取即完成
                    this.updateTask(key, 1, name, false, con);
                } else if (progress.getInteger("type") == 4) {//只接取啥也不做

                }
                break;
            }
        }
        if (!b) {
            return 0;
        }
        return 1;
    }

    /**
     * 获取任务数据去创建战斗
     * 只要求返回：目标key、当前进度下标
     */
    public JSONObject getTaskMsgToCreateFight(String key, String name, DefaultSqlSession con) {
        JSONObject res = null;
        JSONArray doList = this.getTaskList(name, con);
        for (Object o : doList) {
            JSONObject obj = (JSONObject) o;
            if (obj.getString("key").equals(key)) {
                res = new JSONObject();
                //{"progressIndex":0,"taskProgress":{"target":{"num":0}},"key":"999","status":1}
                JSONObject taskMsg = taskData.getTask(key);
                JSONArray progressList = taskMsg.getJSONArray("progressList");
                JSONObject progress = (JSONObject) progressList.get(obj.getInteger("progressIndex"));
                res.put("progressIndex", obj.getInteger("progressIndex"));
                res.put("npcKey", progress.getJSONObject("target").getString("key"));
                break;
            }
        }
        return res;
    }

    /**
     * 重新拉取任务数据
     */
    public result reGetAllTask(@paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        return new result(200, getAllTask(user.name, con));
    }

    /**
     * 获取所有任务（未完成、完成、索引）
     */
    public Object getAllTask(String name, DefaultSqlSession con) {
        return checkTaskStart(name, con);
    }

    /**
     * 获取提交后的任务列表
     */
    public JSONArray getCommitTask(String name, SqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.selectTaskSubmitByName(name).get(0).getJSONArray("list");
    }

    /**
     * 获取未提交的任务列表
     */
    public JSONArray getTaskList(String name, SqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.selectTaskByName(name).get(0).getJSONArray("task");
    }

    /**
     * 检测是否有新任务开启
     */
    public JSONObject checkTaskStart(String name, DefaultSqlSession con) {
        //1000-5000中任务数据实际存在的key
        List<String> taskList = taskData.getTastIndex();
        int lever = startBef.manService.getRoleLv(name, con);
        JSONArray doList = this.getTaskList(name, con);
        JSONArray overList = this.getCommitTask(name, con);
        JSONArray newList = new JSONArray();
        //获取所有任务，去掉已经完成跟正在进行的
        for (String key : taskList) {
            boolean b = false;
            for (Object o : doList) {
                JSONObject obj = (JSONObject) o;
                if (obj.getString("key").equals(key)) {
                    b = true;
                    break;
                }
            }
            //已经接取过了
            if (b) continue;
            for (Object o : overList) {
                if (o.equals(key)) {
                    b = true;
                    break;
                }
            }
            if (b) continue;
            //未开启时判断是否达到开启的条件（等级、任务key）
            JSONObject taskMsg = taskData.getTask(key);
            JSONObject condition = taskMsg.getJSONObject("condition");
            /*if(key.equals("3163")){
                System.out.println("1111");
            }*/
            /*if(condition==null){
                System.out.println("1111");
            }*/
            //是否满足等级条件
            if (condition.getInteger("lever") > lever) {
                continue;
            }
            //是否满足任务链条件 -1是不需要其他任务作为开启条件
            if (condition.getString("taskKey") != null) {
                //是否需要某个任务完成后再开启
                boolean b1 = false;
                for (Object o : overList) {
                    if (o.equals(condition.getString("taskKey"))) {
                        b1 = true;
                        break;
                    }
                }
                if (!b1) {//完成的任务中不存在开启任务的条件
                    continue;
                }
            }
            //当两个条件都满足时开启任务
            //JSONArray progressList=taskMsg.getJSONArray("progressList");
            JSONObject item = getTaskItem(0, key, 1, 0);
            newList.add(item);
        }
        if (newList.size() > 0) {
            //保存新开启的任务数据
            doList.addAll(newList);
            saveTask(doList, name, con);
        }

        JSONObject res = new JSONObject();
        res.put("playerTask", doList);
        res.put("overTask", overList);
        res.put("taskIndex", taskList);
        return res;
    }

    /**
     * 保存任务
     */
    private Integer saveTask(JSONArray list, String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.updateTaskByName(JSON.toJSONString(list), name) ? 1 : 0;
    }

    public Integer saveSubmitTask(JSONArray list, String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.updateTaskSubmitByName(JSON.toJSONString(list), name) ? 1 : 0;
    }

    /**
     * 任务项
     */
    private JSONObject getTaskItem(int progressIndex, String key, int status, int num) {
        JSONObject item = new JSONObject();
        item.put("progressIndex", progressIndex);
        item.put("key", key);
        item.put("status", status);//1可接取2已接取（进行中）3完成（可提交）
        item.put("taskProgress", getTaskProgress(num));
        return item;
    }

    /**
     * 任务进度
     */
    private JSONObject getTaskProgress(int num) {
        JSONObject res = new JSONObject();
        JSONObject target = new JSONObject();
        target.put("num", num);//当前进度收集数量
        res.put("target", target);
        return res;
    }

    /**
     * 获取需要日常清理的任务key
     */
    public List<String> getKeys() {
        List<String> keys = new ArrayList<>();
        //宠物修炼、天渊
        for (int i = 3000; i < 3070; i++) {
            keys.add("" + i);
        }
        //门派任务、摸金校尉
        for (int i = 3100; i < 3123; i++) {
            keys.add("" + i);
        }
        //神秘宝藏
        for (int i = 3131; i < 3135; i++) {
            keys.add("" + i);
        }
        //帮派任务
        for (int i = 3143; i < 3163; i++) {
            keys.add("" + i);
        }
        //副本任务
        for (int i = 3163; i < 3242; i++) {
            keys.add("" + i);
        }
        //魔神日常
        for (int i = 3265; i < 3272; i++) {
            keys.add("" + i);
        }
        //锄奸卫道
        keys.add("3272");
        //仗剑除魔
        keys.add("3273");

        return keys;
    }


    public boolean clearTaskByListKey() {
        List<String> keys = new ArrayList<>();
        for (int i = 3025; i < 3040; i++) {
            keys.add(i + "");
        }
        SqlSession con = mybatisConfig.getSqlSession();
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        try {
            //清理已完成的
            int sum = jsonMapper.getTaskCount().get(0).getInteger("n");
            int len = sum % 10 == 0 ? (sum / 10) : (sum / 10 + 1);
            List<JSONObject> list = new ArrayList<>();
            for (int i = 0; i < len; i++) {
                list.clear();
                list.addAll(jsonMapper.selectAllTask(i * 10L, 10L));
                for (JSONObject r : list) {
                    //判断是否为需要刷新的任务
                    String name = r.getString("name");
                    JSONArray taskList = r.getJSONArray("task");
                    Iterator<Object> aList = taskList.iterator();
                    while (aList.hasNext()) {
                        JSONObject a = (JSONObject) aList.next();
                        for (String k : keys) {
                            //需要刷新
                            if (a.getString("key").equals(k)) {
                                aList.remove();
                                break;
                            }
                        }
                    }
                    jsonMapper.updateTaskByName(JSON.toJSONString(taskList), name);
                }
                list.clear();
                mybatisConfig.commit(con);
                //清理正在进行的
                list.addAll(jsonMapper.selectAllTaskSubmit(i * 10L, 10L));
                for (JSONObject r : list) {
                    //判断是否为需要刷新的任务
                    String name = r.getString("name");
                    JSONArray taskList = r.getJSONArray("list");
                    Iterator<Object> aList = taskList.iterator();
                    while (aList.hasNext()) {
                        String a = (String) aList.next();
                        for (String k : keys) {
                            //需要刷新
                            if (a.equals(k)) {
                                aList.remove();
                                break;
                            }
                        }
                    }
                    jsonMapper.updateTaskSubmitByName(JSON.toJSONString(taskList), name);
                }
                mybatisConfig.commit(con);
            }
            list.clear();

        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            mybatisConfig.close(con);
        }
        return true;
    }

    /**
     * 清理日常任务
     */
    public void updateDailyTask() {
        staticCollection.isAllowedReq = false;
        //先清理服务器缓存
        systemUtils.doClearCache();
        //备份数据库
        systemUtils.startBbBackup();
        //获取所有需要清理的任务key
        List<String> keys = getKeys();
        //启动时获取当前时间，算出距离12点还差多久，将其设置延时
        clear(keys);

        //百战千军
        startBef.bzqjService.countWHJX();
        //（旧）竞技场
        startBef.jingjiService.countJingji();
        //传壁
        startBef.cbService.countCb();

        staticCollection.isAllowedReq = true;
    }

    private void clear(List<String> keys) {
        System.err.println("开始清理");
        SqlSession con = mybatisConfig.getSqlSession();
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        try {
            //清理已完成的
            int sum = jsonMapper.getTaskCount().get(0).getInteger("n");
            int len = sum % 10 == 0 ? (sum / 10) : (sum / 10 + 1);
            List<JSONObject> list = new ArrayList<>();
            for (int i = 0; i < len; i++) {
                list.clear();
                list.addAll(jsonMapper.selectAllTask(i * 10L, 10L));
                for (JSONObject r : list) {
                    //判断是否为需要刷新的任务
                    String name = r.getString("name");
                    JSONArray taskList = r.getJSONArray("task");
                    Iterator<Object> aList = taskList.iterator();
                    while (aList.hasNext()) {
                        JSONObject a = (JSONObject) aList.next();
                        for (String k : keys) {
                            //需要刷新
                            if (a.getString("key").equals(k)) {
                                aList.remove();
                                break;
                            }
                        }
                    }
                    jsonMapper.updateTaskByName(JSON.toJSONString(taskList), name);
                }
                list.clear();
                mybatisConfig.commit(con);
                //清理正在进行的
                list.addAll(jsonMapper.selectAllTaskSubmit(i * 10L, 10L));
                for (JSONObject r : list) {
                    //判断是否为需要刷新的任务
                    String name = r.getString("name");
                    JSONArray taskList = r.getJSONArray("list");
                    Iterator<Object> aList = taskList.iterator();
                    while (aList.hasNext()) {
                        String a = (String) aList.next();
                        for (String k : keys) {
                            //需要刷新
                            if (a.equals(k)) {
                                aList.remove();
                                break;
                            }
                        }
                    }
                    jsonMapper.updateTaskSubmitByName(JSON.toJSONString(taskList), name);
                }
                mybatisConfig.commit(con);
            }
            list.clear();
            //重置宠物吃虫限制
            for (int i = 0; i < len; i++) {
                list.addAll(jsonMapper.selectPetLimit(i * 10L, 10L));
                //遍历玩家
                for (JSONObject a : list) {
                    JSONArray ls = a.getJSONArray("pet");
                    boolean isChange = false;
                    //遍历宠物
                    for (Object l : ls) {
                        JSONObject item = (JSONObject) l;
                        item.put("eatPet", 0);
                        isChange = true;
                    }
                    if (isChange) {
                        jsonMapper.updatePetByName(JSON.toJSONString(ls), a.getString("name"));
                    }
                }
                list.clear();
                mybatisConfig.commit(con);
            }
            list.clear();
            //清理休闲活动
            jsonMapper.delChumo();
            jsonMapper.delHappyAnswer();
            jsonMapper.delZhuanpan();
            //更新副本次数
            activityMapper.clearFb();
            //清理竞技场
            activityMapper.clearTimesJingji();
            //清理帮派请求
            gangsMapper.clearGangsReq();
            //清理帮战
            gangsMapper.delGangsFight();
            //清理跑商数据
            gangsMapper.delGangsPs(null);
            //刷新帮派成员每日活动次数
            gangsMapper.updateGangsAcTimes("0", "0", "0", "0", null);
            //清理帮派活动
            gangsMapper.clearGangsActivity();
            //刷新今日帮贡及帮派任务接取次数
            gangsMapper.updateGangsMembers(null, null, null, null, "0", "0");
            //清理邮件
            //jsonMapper.clearEmail();
            //清理藏宝图活动
            activityMapper.clearAll();
            //清理传壁活动
            activityMapper.clearAllCb();
            //清理在线时长日志
            logMapper.clear(strUtils.getTime() + "");
            //更新每日领月饼的次数
            activityMapper.delAcDayLimit();
            //更新基金领取次数
            activityMapper.updateJiJinByDay();
            //更新签到
            activityMapper.remQiandao();
            //清理每日签到
            activityMapper.remDayQiandao();
            //清理摸金校尉
            activityMapper.remMJXW();
            //刷新王侯将相次数
            activityMapper.clearTimesWHJX();
            //刷新百炼妖塔
            activityMapper.remBLYT();
            //刷新魔神降临次数
            activityMapper.remMSJLMsg();
            //魔神窟任务接取次数
            jsonMapper.clearYhmkTimes();

            //解散资金为负的帮派
            startBef.gangsService.dayFixBp();
            //刷新锄奸卫道
            activityMapper.clearCjwd();
            //刷新垂钓
            activityMapper.clearChuiDiao();
            //刷新聚灵真火次数
            activityMapper.clearJuling();
            //王者遗产免费次数
            activityMapper.clearWzyc();
            //仗剑除魔次数
            activityMapper.clearZJCM();
            //农场偷取次数、领取次数
            activityMapper.clearFarm();
            //斗战封神榜次数
            jsonMapper.clearDzfsbLog();
            //清理开服签到
            activityMapper.clearOpenServerQianDaoGift();
            //刷新元宝领取
            activityMapper.clearQdGainShenYb();
            //清理血腥之地积分
            activityMapper.remXxzd();

            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
            keys.clear();
        }
        //通知在线的重新拉取任务
        ChannelSupervise.noticeAllClient(null, "838");
    }
}
