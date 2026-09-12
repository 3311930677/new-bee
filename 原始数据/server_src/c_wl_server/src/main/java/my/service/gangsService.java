package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import io.netty.util.concurrent.ScheduledFuture;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.gangsMapper;
import my.dao.jsonMapper;
import my.dao.roleMapper;
import my.data.*;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

public class gangsService {

    //是否推送了盒子
    private boolean isSendYanhuiBox = false;
    public boolean isBzAcOpen = false;

    /**
     * 手动开启活动
     */
    public result openBz(@paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (!name.equals("梅仁义")) {
            return new result(0);
        }
        startBz();
        return new result(200, 1);
    }
    public result closeBz(@paramsAnno(key = "user") user user) {
        final String name = user.name;
        if (!name.equals("梅仁义")) {
            return new result(0);
        }
        bzOverResult();
        return new result(200, 1);
    }


    /**
     * 对帮派任务奖励的处理
     */
    public void handleBpTaskRewards(int bg, String name, DefaultSqlSession con) {
        //修改个人历史帮贡，今日帮贡
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject m = dao.selectGangsMembers(null, name).get(0);
        dao.updateGangsMembers(null, name, null, m.getInteger("bg") + bg + "", m.getInteger("dayBg") + bg + "", null);
        //帮派帮贡
        String bpId = m.getString("bpId");
        JSONObject bp = dao.selectGangs(bpId).get(0);
        dao.updateGangs(null, null, null, bp.getInteger("bg") + bg + "", null, bpId);
    }

    /**
     * 升级帮派
     */
    public result upLvGangs(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        if (bpId == null) return new result(0);
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        //判断是否为有权限审批（帮主、副帮主）
        JSONObject m = dao.selectGangsMembers(null, name).get(0);
        int job = m.getInteger("job");
        if (job != 0 && job != 1) {
            return new result(649);
        }
        JSONObject bp = dao.selectGangs(bpId).get(0);
        //判断是否已满
        int lv = bp.getInteger("lever");
        if (lv >= 6) return new result(656);
        int max = countMaxBuildV(lv);
        JSONObject build = dao.selectGangsBuild(bpId).get(0);
        if (build.getInteger("shop") < max || build.getInteger("tec") < max ||
                build.getInteger("solicit") < max || build.getInteger("book") < max ||
                build.getInteger("mifa") < max) {
            //未满
            return new result(969);
        }
        //消耗20000建设金
        int money = bp.getInteger("money");
        money = money - 20000;
        if (money < 0) return new result(970);
        //清空建设值
        dao.updateGangsBuild("0", "0", "0", "0", "0", bpId);
        //帮派升级
        dao.updateGangs(null, lv + 1 + "", money + "", null, null, bpId);
        return new result(200, 1);
    }

    /**
     * 获取建设度
     */
    public result getBuildV(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject build = dao.selectGangsBuild(bpId).get(0);
        build.remove("Id");
        return new result(200, build);
    }

    /**
     * 提交帮贡
     */
    /*public result putBG(JSONObject j,
                        @paramsAnno(key = "user") user user,
                        @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int num = j.getInteger("num");
        int type = j.getInteger("type");
        if (num <= 0) {
            return new result(0);
        }
        String Id = getBPIdByName(name, con);
        if (Id == null) {
            return new result(0);
        }
        String key = null;
        int k = 10;
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        if (type == 0) {
            int i = startBef.manService.saveMoney(1, -num, name, con);
            if (i == 0) return new result(0);
            int bg = num / 1000;
            startBef.manService.saveMoney(5, bg, name, con);
            //保存当前帮派贡献
            JSONObject bp = dao.selectGangs(Id).get(0);

            JSONObject m = dao.selectGangsMembers(null, name).get(0);
            dao.updateGangsMembers(null, name, null,
                    m.getInteger("bg") + bg + "",
                    m.getInteger("dayBg") + bg + "");

            dao.updateGangs(null, null,
                    bp.getInteger("money") + num + "", bp.getInteger("bg") + bg + "", null, Id);
            return new result(200, 1);
        } else if (type == 1) {
            key = "1049";
        } else if (type == 2) {
            key = "1050";
            k = 50;
        } else if (type == 3) {
            key = "1051";
            k = 100;
        } else {
            return new result(0);
        }
        int i = startBef.packageService.cutPlayerGoodsNumByKey(key, num, name, con);
        if (i == 0) {
            return new result(0);
        }
        int bg = num * k;
        //保存所有帮贡
        startBef.manService.saveMoney(5, bg, name, con);
        //保存当前帮派贡献
        JSONObject bp = dao.selectGangs(Id).get(0);
        //更改个人帮贡
        JSONObject m = dao.selectGangsMembers(null, name).get(0);
        dao.updateGangsMembers(null, name, null,
                m.getInteger("bg") + bg + "",
                m.getInteger("dayBg") + bg + "");

        dao.updateGangs(null, null, null,
                bp.getInteger("bg") + bg + "", null, Id);
        return new result(200, 0);
    }*/

    /**
     * 捐献资金
     */
    public result putBpMoney(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        Long num = j.getLong("num");
        //最少1000银两 1000=1帮贡
        if (bpId == null || num == null || num < 1000) return new result(0);
        if (startBef.manService.saveMoney(1, -num, name, con) != 1) {
            return new result(0);
        }
        long bg = num / 1000L;
        if (!addManBg(bg, bpId, name, con)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject bp = dao.selectGangs(bpId).get(0);
        //增加帮派资金
        boolean b = dao.updateGangs(null, null,
                bp.getInteger("money") + num + "", null, null, bpId);
        if (!b) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //msg的帮贡
        JSONArray list = rewardUtils.getBgReward(bg);
        startBef.rewardService.saveRewards(list, name, con);
        return new result(200, list);
    }

    /**
     * 提交贡品
     */
    public result putGP(JSONObject j,
                        @paramsAnno(key = "user") user user,
                        @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        String buildKey = j.getString("buildKey");
        if (bpId == null || (!buildKey.equals("shop") && !buildKey.equals("tec") &&
                !buildKey.equals("solicit") && !buildKey.equals("book") &&
                !buildKey.equals("mifa"))) {
            return new result(0);
        }
        String key = j.getString("key");
        Integer num = j.getInteger("num");
        if ((!key.equals("10000172") && !key.equals("10000173")) ||
                num == null || num <= 0) {
            return new result(0);
        }
        //减少数量
        if (startBef.packageService.cutPlayerGoodsNumByKey(key, num, name, con) == 0) {
            return new result(0);
        }
        //可提交的道具 稀土（10点建设度、40点帮贡）、神木（20点建设、160帮贡）、玉石（30、400）
        int bV = num;//num点建设度
        int bg = num;//1点帮贡
        //根据帮派等级计算建设度
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject bp = dao.selectGangs(bpId).get(0);
        int maxBuildV = countMaxBuildV(bp.getInteger("lever"));
        //判断建设度是否满，为选择的建设项增加建设度
        JSONObject build = dao.selectGangsBuild(bpId).get(0);
        int buildV = build.getInteger(buildKey);
        //满了则不允许再提交
        if (buildV >= maxBuildV) return new result(966);
        //增加帮派贡献
        buildV = buildV + bV;
        if (buildV > maxBuildV) {
            buildV = maxBuildV;
        }
        boolean b = false;
        if (buildKey.equals("shop")) {
            b = dao.updateGangsBuild(buildV + "", null, null, null, null, bpId);
        } else if (buildKey.equals("tec")) {
            b = dao.updateGangsBuild(null, buildV + "", null, null, null, bpId);
        } else if (buildKey.equals("solicit")) {
            b = dao.updateGangsBuild(null, null, buildV + "", null, null, bpId);
        } else if (buildKey.equals("book")) {
            b = dao.updateGangsBuild(null, null, null, buildV + "", null, bpId);
        } else if (buildKey.equals("mifa")) {
            b = dao.updateGangsBuild(null, null, null, null, buildV + "", bpId);
        }

        if (!b || !addManBg(bg, bpId, name, con)) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //msg的帮贡
        JSONArray list = rewardUtils.getBgReward(bg);
        startBef.rewardService.saveRewards(list, name, con);
        return new result(200, list);
    }

    /**
     * 增加帮派、个人帮贡（不涉及msg里的bg）
     */
    private boolean addManBg(long bg, String bpId, String name, DefaultSqlSession con) {
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = dao.selectGangs(bpId);
        if (list.size() == 0) return false;
        JSONObject bp = list.get(0);
        //增加帮派贡献
        boolean b = dao.updateGangs(null, null, null,
                bp.getLong("bg") + bg + "", null, bpId);
        if (!b) return b;
        //增加个人贡献、历史贡献
        JSONObject m = dao.selectGangsMembers(null, name).get(0);
        b = dao.updateGangsMembers(null, name, null,
                m.getLong("bg") + bg + "", m.getLong("dayBg") + bg + "", null);
        if (!b) return b;
        return true;
    }

    /**
     * 计算最大建设度
     */
    private int countMaxBuildV(int lv) {
        return 15000 * (lv - 1) + 10000;
    }

    /**
     * 今日是否已经领取过每日奖励
     */
    public result isGainDayRewards(@paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject tms = dao.selectGangsAcTimes(name).get(0);
        //统计今日总贡献度
        List<JSONObject> list = dao.selectGangsMembersDayBg(bpId);
        int dayBg = 0;
        for (int i = 0; i < list.size(); i++) {
            dayBg += list.get(i).getInteger("dayBg");
        }
        //根据今日贡献度来提升奖励 "帮贡","修炼点","帮币"
        //根据玩家职位提升
        JSONObject m = dao.selectGangsMembers(null, name).get(0);
        JSONObject rw = countDayRewards(dayBg, m.getInteger("job"));
        rw.put("isGain", tms.getInteger("dayReward") >= 1 ? 1 : 0);
        return new result(200, rw);
    }

    private JSONObject countDayRewards(int dayBg, int job) {
        float bg = 100;
        float xld = 90;
        float bb = 50;
        float k = 1;
        if (dayBg > 50000) {//s
            k = 2;
        } else if (dayBg > 20000) {//a
            k = 1.5f;
        } else if (dayBg > 10000) {//b
            k = 1.3f;
        } else if (dayBg > 5000) {//c
            k = 1.1f;
        }
        if (job == 0) k += 0.2f;
        else if (job == 1) k += 0.1f;
        else if (job == 2 || job == 3) k += 0.06f;
        else if (job == 4) k += 0.03f;
        JSONObject res = new JSONObject();
        res.put("bg", (int) (bg * k));
        res.put("xld", (int) (xld * k));
        res.put("bb", (int) (bb * k));
        return res;
    }

    /**
     * 领取每日奖励
     */
    public result gainDayRewards(@paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (name == null) return new result(0);
        String bpId = user.msg.getString("bpId");
        //判断是否已经领取
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject tms = dao.selectGangsAcTimes(name).get(0);
        if (tms.getInteger("dayReward") >= 1) {
            return new result(0);
        }
        //统计今日总贡献度
        List<JSONObject> list = dao.selectGangsMembersDayBg(bpId);
        int dayBg = 0;
        for (int i = 0; i < list.size(); i++) {
            dayBg += list.get(i).getInteger("dayBg");
        }
        //根据今日贡献度来提升奖励 "帮贡","修炼点","帮币"
        //根据玩家职位提升
        JSONObject m = dao.selectGangsMembers(null, name).get(0);
        JSONObject rw = countDayRewards(dayBg, m.getInteger("job"));
        //标记已领取
        if (dao.updateGangsAcTimes("1", null, null, null, name)) {
            //保存
            JSONArray rewards = rewardUtils.getBgReward(rw.getInteger("bg"));
            rewards.fluentAddAll(rewardUtils.getXldReward(rw.getInteger("xld")));
            rewards.fluentAddAll(rewardUtils.getBbReward(rw.getInteger("bb")));
            startBef.rewardService.saveRewards(rewards, name, con);
            return new result(200, rewards);
        }
        return new result(0);
    }

    /**
     * 更改职位
     */
    public result changeJob(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        int job = j.getInteger("job");
        String playerName = j.getString("playerName");
        if (bpId == null || playerName == null || (playerName.equals(name)) || job < 0 || job > 5)
            return new result(0);
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        //验证是否为成员
        List<JSONObject> ms = gangsMapper.selectGangsMembers(null, name);
        if (ms.size() == 0 || !ms.get(0).getString("bpId").equals(bpId))
            return new result(0);

        List<JSONObject> list = gangsMapper.selectGangs(bpId);
        if (list.size() == 0) return new result(0);
        JSONObject bp = list.get(0);
        //判断是否有权限更改 只有帮主才能更改
        if (!bp.getString("captain").equals(name)) {
            return new result(649);//无权限
        }
        //0帮主1副帮主2左护法3右护法4精英5帮众
        if (job == 0) {
            //移交帮主，自己将成为帮众
            gangsMapper.updateGangsMembers(bpId, playerName, job + "", null, null, null);
            gangsMapper.updateGangsMembers(bpId, name, "5", null, null, null);
            gangsMapper.updateGangs(playerName, null, null, null, null, bpId);
            return new result(200, 1);
        } else if (job == 5) {
            gangsMapper.updateGangsMembers(bpId, playerName, job + "", null, null, null);
            return new result(200, 1);
        } else {
            //统计该职位是否还有空缺
            JSONObject map = new JSONObject();
            map.put("0", 0);
            map.put("1", 0);//1个
            map.put("2", 0);//2
            map.put("3", 0);//2
            map.put("4", 0);//8
            map.put("5", 0);
            List<JSONObject> members = gangsMapper.selectGangsMembers(bpId, null);
            for (JSONObject m : members) {
                String k = m.getString("job");
                int n = map.getInteger(k);
                map.put(k, n + 1);
            }
            boolean b = true;
            if (job == 1 && map.getInteger(job + "") >= 1) b = false;
            else if (job == 2 && map.getInteger(job + "") >= 2) b = false;
            else if (job == 3 && map.getInteger(job + "") >= 2) b = false;
            else if (job == 4 && map.getInteger(job + "") >= 8) b = false;
            if (b) {
                gangsMapper.updateGangsMembers(bpId, playerName, job + "", null, null, null);
                //任命成功
                return new result(200, 1);
            } else {
                //位置已满
                return new result(1022);
            }
        }
    }

    /**
     * 提交任务
     */
    public result subTask(@paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        if (bpId == null) return new result(0);
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> tasks = gangsMapper.selectGangsTask(bpId);
        if (tasks.size() == 0) return new result(0);
        tasks = JSON.parseArray(tasks.get(0).getJSONArray("task").toString(), JSONObject.class);
        for (int i = 0; i < tasks.size(); i++) {
            JSONObject person = tasks.get(i).getJSONObject("person");
            if (name.equals(person.getString("name")) &&
                    person.getInteger("status") == 2) {
                JSONObject temp = staticCollection.copyObj(tasks.get(i));
                //移除并更新
                tasks.remove(i);
                //重新生成一个任务
                tasks.add(gangsTaskData.getRandomTask());
                gangsMapper.updateGangsTask(bpId, JSON.toJSONString(tasks));
                //个人帮贡历史、帮派帮贡++
                JSONObject bp = gangsMapper.selectGangs(bpId).get(0);

                //修改个人帮贡\接取任务次数
                JSONObject m = gangsMapper.selectGangsMembers(null, name).get(0);
                gangsMapper.updateGangsMembers(null, name, null,
                        m.getInteger("bg") + temp.getInteger("jf") + "",
                        m.getInteger("dayBg") + temp.getInteger("jf") + "",
                        m.getInteger("taskTimes") + 1 + "");

                int bg = bp.getInteger("bg") + temp.getInteger("jf");
                //帮派贡献
                gangsMapper.updateGangs(null, null, null, bg + "", null, bpId);
                //个人帮贡
                JSONArray res = rewardUtils.getBgReward(temp.getInteger("jf"));
                //增加经验
                JSONArray reward = rewardUtils.getExpReward(temp.getInteger("exp"));
                res = res.fluentAddAll(reward);
                startBef.rewardService.saveRewards(res, name, con);
                ChannelSupervise.noticeClientByName(res, name, "10000");

                return new result(200, 1);
            }
        }
        return new result(0);
    }

    /**
     * 寻秦使用的帮派任务接取
     */
    public result getBpTask(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray list1 = startBef.taskService.getTaskList(name, con);
        for (Object a : list1) {
            JSONObject l = (JSONObject) a;
            int k = l.getInteger("key");
            if (3143 <= k && k < 3163) {
                //已经接取
                return new result(765);
            }
        }
        //获取所有已提交的任务
        int num = 0;
        JSONArray list2 = startBef.taskService.getCommitTask(name, con);
        for (Object a : list2) {
            int k = Integer.parseInt(a.toString());
            if (3143 <= k && k < 3163) {
                num++;
            }
        }
        //判断是否还有接取的次数
        if (num >= 10) return new result(854);
        //从20个任务中随机一个（不重复的）
        Integer k = strUtils.getRandom(3143, 3163, list2);
        //对于提交表中已经存在所有该范围的任务
        if (k == null) return new result(0);
        //不含有起始对话进度，所以progressIndex=0
        JSONObject task = startBef.taskService.createAcTask(k.toString(), name, con);
        return new result(200, k.toString());
    }

    /**
     * 接取帮派任务（这个是类似帮派大作战的那种共享任务）
     */
    public result getTask(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        String Id = j.getString("Id");
        if (strUtils.isNull(Id) || strUtils.isNull(bpId)) return new result(0);
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = gangsMapper.selectGangsTask(bpId);
        if (list.size() == 0) return new result(0);

        JSONArray tasks = list.get(0).getJSONArray("task");
        long end = 0;
        for (int i = 0; i < tasks.size(); i++) {
            JSONObject a = (JSONObject) tasks.get(i);
            JSONObject person = a.getJSONObject("person");
            String n = person.getString("name");
            //身上有其他任务了
            if (name.equals(n)) {
                return new result(200, 0);
            }
            //是否被别人接取了
            if (a.getString("Id").equals(Id) && n != null) {
                return new result(0);
            }
            //是否还有次数
            List<JSONObject> tms = gangsMapper.selectGangsMembers(null, name);
            int time = tms.get(0).getInteger("taskTimes");
            if (time >= 20) {
                return new result(610);
            }

            if (a.getString("Id").equals(Id)) {
                long start = strUtils.getTime();
                end = start + 24 * 60 * 60 * 1000;
                person.put("name", name);
                person.put("endTime", end);
                person.put("status", 1);
            }
        }
        boolean b = gangsMapper.updateGangsTask(bpId, JSON.toJSONString(tasks));
        if (!b) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, end);
    }

    /**
     * 获取帮派任务
     */
    public result getTaskList(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer pageNum = j.getInteger("pageNum");
        if (pageNum <= 0) return new result(0);
        int pageSum = 10;
        int sum = 60;
        sum = sum % pageSum == 0 ? (sum / pageSum) : (sum / pageSum + 1);
        if (pageNum > sum) return new result(0);

        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        //先判断是否已经有了数据
        String bpId = user.msg.getString("bpId");
        if (bpId == null) return new result(0);
        List<JSONObject> tasks = gangsMapper.selectGangsTask(bpId);
        if (tasks.size() == 0) {
            //创建任务
            tasks = gangsTaskData.createBpdzzTask();
            gangsMapper.addGangsTask(bpId, JSON.toJSONString(tasks));
        } else {
            tasks = JSON.parseArray(tasks.get(0).getJSONArray("task").toString(), JSONObject.class);
            //判断是否有超时的任务，有就先移除再重新增加
            long now = strUtils.getTime();
            for (int i = 0; i < tasks.size(); i++) {
                JSONObject t = tasks.get(i);
                JSONObject person = t.getJSONObject("person");
                if (person.getInteger("status") != 1) continue;
                if (person.getLong("endTime") - now < 0) {
                    //移除超时未完成的任务
                    tasks.remove(i);
                    i++;
                }
            }
            //补够60个
            if (tasks.size() < 60) {
                int len = 60 - tasks.size();
                for (int i = 0; i < len; i++) {
                    tasks.add(gangsTaskData.getRandomTask());
                }
                gangsMapper.updateGangsTask(bpId, JSON.toJSONString(tasks));
            }

        }
        tasks = tasks.subList((pageNum - 1) * pageSum, (pageNum) * pageSum);
        //获取剩余次数
        List<JSONObject> tms = gangsMapper.selectGangsMembers(null, name);

        JSONObject res = new JSONObject();
        res.put("totalPage", 60 / pageSum);
        res.put("list", tasks);
        res.put("times", tms.get(0).getInteger("taskTimes"));

        return new result(200, res);
    }

    /**
     * 全服排行
     */
    public result getBpdzzAllOrder(@paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        //final String name = user.name;
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> gs = gangsMapper.selectGangsBpdzzAllOrder(0L, 20L);
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        List names = new ArrayList();
        for (JSONObject g : gs) {
            names.add(g.get("name"));
        }
        if (names.size() == 0) return new result(0);
        List<JSONObject> roles = roleMapper.selectRoleByNames(names);
        for (JSONObject g : gs) {
            g.put("order", g.get("pos"));
            g.remove("pos");
            for (JSONObject r : roles) {
                if (g.getString("name").equals(r.get("name"))) {
                    g.put("model", r.get("model"));
                    break;
                }
            }
        }
        return new result(200, gs);
    }

    /**
     * 帮派前20排行
     */
    public result getBpdzzBpOrder(@paramsAnno(key = "user") user user,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        //final String name = user.name;
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> gs = gangsMapper.selectGangsBpdzzGangsOrderView();
        for (JSONObject g : gs) {
            g.remove("members");
        }
        if (gs.size() > 20) {
            gs = gs.subList(0, 20);
        }
        return new result(200, gs);
    }

    /**
     * 个人帮派内排名前20排行
     */
    public result getBpdzzBpPersonOrder(@paramsAnno(key = "user") user user,
                                        @paramsAnno(key = "con") DefaultSqlSession con) {
        //final String name = user.name;
        if (user.msg.get("bpId") == null) return new result(0);
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        List<JSONObject> gs = gangsMapper.selectGangs(user.msg.getString("bpId"));
        if (gs.size() == 0) return new result(0);
        JSONArray members = gs.get(0).getJSONArray("members");
        List names = new ArrayList();
        for (Object o : members) {
            JSONObject m = (JSONObject) o;
            names.add(m.getString("name"));
        }
        //获取职业
        List<JSONObject> roles = roleMapper.selectRoleByNames(names);
        List<JSONObject> ns = gangsMapper.selectGangsBpdzzPlayerByNames(names);
        List<JSONObject> resList = new ArrayList<>();
        for (Object o : names) {
            String m = (String) o;
            JSONObject t = new JSONObject();
            t.put("name", m);
            //找不到时给默认值
            t.put("jf", 0);
            t.put("sumTimes", 10);
            t.put("getTimes", 0);
            for (JSONObject n : ns) {
                if (m.equals(n.getString("name"))) {
                    t.put("jf", n.get("jf"));
                    t.put("sumTimes", n.get("sum_times"));
                    t.put("getTimes", n.get("get_times"));
                    break;
                }
            }
            for (JSONObject r : roles) {
                if (m.equals(r.getString("name"))) {
                    t.put("model", r.get("model"));
                }
            }
            resList.add(t);
        }
        Collections.sort(resList, new Comparator<JSONObject>() {
            @Override
            public int compare(JSONObject o1, JSONObject o2) {
                return -o1.getInteger("jf").compareTo(o2.getInteger("jf"));
            }
        });
        if (resList.size() > 20)
            resList = resList.subList(0, 20);
        return new result(200, resList);
    }

    /**
     * 获取成就奖励领取记录
     */
    public result getBpdzzCJRewards(@paramsAnno(key = "user") user user,
                                    @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (user.msg.get("bpId") == null) return new result(0);
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = gangsMapper.selectGangsBpdzzPlayer(name);
        if (list.size() == 0) return new result(0);
        JSONArray rs = list.get(0).getJSONArray("rewards");
        int jf = gangsMapper.selectGangsBpdzzGangs(user.msg.getString("bpId")).get(0).getInteger("jf");
        JSONObject res = new JSONObject();
        res.put("bpJf", jf);
        res.put("rewards", rs);
        return new result(200, res);
    }

    /**
     * 领取奖励
     */
    public result gainBpdzzRewards(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String k = j.getString("key");
        if (strUtils.isNull(k) || user.msg.get("bpId") == null) return new result(0);
        int n = Integer.parseInt(k.replace("a", "")) - 1;
        if (n > 19 || n < 0) return new result(0);
        //验证是否达到指定积分
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        String bpId = user.msg.getString("bpId");
        int jf = gangsMapper.selectGangsBpdzzGangs(bpId).get(0).getInteger("jf");
        if (jf < 5000 + n * 5000) {
            return new result(0);
        }
        //验证是否领取过
        JSONObject player = gangsMapper.selectGangsBpdzzPlayer(name).get(0);
        JSONArray rewards = player.getJSONArray("rewards");
        for (Object o : rewards) {
            if (k.equals(o)) {
                return new result(0);
            }
        }
        //标记为领取
        rewards.add(k);
        boolean b = gangsMapper.updateGangsBpdzzPlayer(name, null, null, null, JSON.toJSONString(rewards));
        if (!b) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //返回奖励
        JSONArray list = keyToRewards(k);
        startBef.rewardService.saveRewards(list, name, con);
        return new result(200, list);
    }

    private JSONArray keyToRewards(String k) {
        int n = Integer.parseInt(k.replace("a", "")) - 1;
        String pk = "11060000";
        if (n % 4 == 1) {
            pk = "11060001";
        } else if (n % 4 == 2) {
            pk = "11060002";
        }
        if (n % 4 == 3) {
            pk = "11060003";
        }
        JSONArray rewards = rewardUtils.getGoodsReward("1004", 10 + n * 5, 1);
        return rewards.fluentAddAll(rewardUtils.getGoodsReward(pk, 2 + n * 2, 1));
    }


    /**
     * 接取大作战任务
     */
    public result getBpdzzTask(JSONObject j,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (!startBef.activityService.isOpen("bpdzz")) {
            return new result(696);
        }
        String Id = j.getString("Id");
        if (strUtils.isNull(Id)) return new result(0);
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = gangsMapper.selectGangsBpdzzTask(Id);
        if (list.size() == 0) return new result(0);
        //身上有其他任务了
        if (gangsMapper.selectGangsBpdzzTaskByGainner(name).size() > 0) {
            return new result(200, 0);
        }
        JSONObject task = list.get(0);
        //是否被别人接取了
        if (!strUtils.isNull(task.getString("gainner"))) return new result(0);
        //验证是否还有次数
        JSONObject one = gangsMapper.selectGangsBpdzzPlayer(name).get(0);
        if (one.getInteger("get_times") >= one.getInteger("sum_times")) {
            return new result(200, -1);
        }
        //已接次数++
        boolean b = gangsMapper.updateGangsBpdzzPlayer(name, null, null, one.getInteger("get_times") + 1 + "", null);
        if (!b) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        long start = strUtils.getTime();
        long end = start + 24 * 60 * 60 * 1000;
        b = gangsMapper.updateGangsBpdzzTask(Id, name, start + "", end + "", "1", null, null);
        if (!b) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, end);
    }

    /**
     * 活动结束后下发奖励
     */
    public void acOverSendRewards() {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
            //发放奖励
            //帮派内个人
            List<JSONObject> list = gangsMapper.selectGangsBpdzzGangsOrderView();
            List<JSONObject> allPlayers = new ArrayList<>();
            for (int j = 0; j < list.size(); j++) {
                JSONObject l = list.get(j);
                List names = new ArrayList();
                JSONArray members = l.getJSONArray("members");
                for (Object m : members) {
                    names.add(((JSONObject) m).getString("name"));
                }
                List<JSONObject> players = gangsMapper.selectGangsBpdzzPlayerByNames(names);
                Collections.sort(players, new Comparator<JSONObject>() {
                    @Override
                    public int compare(JSONObject o1, JSONObject o2) {
                        return -o1.getInteger("jf").compareTo(o2.getInteger("jf"));
                    }
                });
                JSONArray bpRewards = null;
                if (j == 0) {
                    bpRewards = rewardUtils.getGoodsReward("1051", 100, 1);
                } else if (j == 1) {
                    bpRewards = rewardUtils.getGoodsReward("1051", 50, 1);
                } else if (j == 2) {
                    bpRewards = rewardUtils.getGoodsReward("1050", 50, 1);
                } else {
                    bpRewards = rewardUtils.getGoodsReward("1049", 50, 1);
                }
                int bpJf = l.getInteger("jf");
                int k = 1;
                if (bpJf > 10000 && bpJf <= 20000) {
                    k = 2;
                } else if (bpJf > 20000 && bpJf <= 60000) {
                    k = 3;
                }
                if (bpJf > 60000 && bpJf <= 100000) {
                    k = 4;
                }
                if (bpJf > 100000) {
                    k = 5;
                }
                for (int i = 0; i < players.size(); i++) {
                    JSONArray rewards = null;
                    if (i == 0) {
                        rewards = rewardUtils.getGoodsReward("1004", 20 * k, 1);
                        rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 10 * k, 1));
                    } else if (i == 1) {
                        rewards = rewardUtils.getGoodsReward("1004", 18 * k, 1);
                        rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 8 * k, 1));
                    } else if (i == 2) {
                        rewards = rewardUtils.getGoodsReward("1004", 16 * k, 1);
                        rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 6 * k, 1));
                    } else if (i > 2 && i < 5) {
                        rewards = rewardUtils.getGoodsReward("1004", 12 * k, 1);
                        rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 4 * k, 1));
                    } else if (i >= 5 && i < 10) {
                        rewards = rewardUtils.getGoodsReward("1004", 10 * k, 1);
                        rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 3 * k, 1));
                    } else if (i >= 10 && i < 20) {
                        rewards = rewardUtils.getGoodsReward("1004", 5 * k, 1);
                        rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 2 * k, 1));
                    } else {
                        rewards = rewardUtils.getGoodsReward("1004", 2 * k, 1);
                        rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 1 * k, 1));
                    }
                    //追加帮派排行奖励
                    rewards = rewards.fluentAddAll(bpRewards);
                    startBef.rewardService.saveRewards(rewards, players.get(i).getString("name"), con);
                    mybatisConfig.commit(con);
                    ChannelSupervise.noticeClientByName(rewards, players.get(i).getString("name"), "10000");
                    //个人积分>2000才参与全服
                    if (players.get(i).getInteger("jf") >= 2000) {
                        allPlayers.add(players.get(i));
                    }

                }
            }
            //全服个人
            Collections.sort(allPlayers, new Comparator<JSONObject>() {
                @Override
                public int compare(JSONObject o1, JSONObject o2) {
                    return -o1.getInteger("jf").compareTo(o2.getInteger("jf"));
                }
            });
            for (int i = 0; i < allPlayers.size(); i++) {
                JSONArray rewards = null;
                if (i == 0) {
                    rewards = rewardUtils.getGoodsReward("1004", 200, 1);
                    rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 120, 1));
                } else if (i == 1) {
                    rewards = rewardUtils.getGoodsReward("1004", 150, 1);
                    rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 100, 1));
                } else if (i == 2) {
                    rewards = rewardUtils.getGoodsReward("1004", 120, 1);
                    rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 80, 1));
                } else if (i > 2 && i < 5) {
                    rewards = rewardUtils.getGoodsReward("1004", 100, 1);
                    rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 50, 1));
                } else if (i >= 5 && i < 10) {
                    rewards = rewardUtils.getGoodsReward("1004", 80, 1);
                    rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 20, 1));
                } else if (i >= 10 && i < 20) {
                    rewards = rewardUtils.getGoodsReward("1004", 50, 1);
                    rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 10, 1));
                } else {
                    rewards = rewardUtils.getGoodsReward("1004", 20, 1);
                    rewards = rewards.fluentAddAll(rewardUtils.getGoodsReward("11060005", 5, 1));
                }
                startBef.rewardService.saveRewards(rewards, allPlayers.get(i).getString("name"), con);
                mybatisConfig.commit(con);
                ChannelSupervise.noticeClientByName(rewards, allPlayers.get(i).getString("name"), "10000");
            }
            mybatisConfig.commit(con);
            if (allPlayers.size() > 0) {
                startBef.chatService.putSysMsg("帮派大作战活动已结束，恭喜玩家" + allPlayers.get(0).getString("name") + "获得全服第一，神宠碎片拿到手抖~");
            }
            clearData();
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 奖励发放完两小时后删除数据
     */
    private void clearData() {
        staticCollection.putTask(() -> {
            DefaultSqlSession con = null;
            try {
                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
                //奖励发放完两小时后删除数据
                gangsMapper.delBpdzzGangs();
                gangsMapper.delBpdzzPlayer();
                gangsMapper.delBpdzzTask();
                mybatisConfig.commit(con);
            } catch (Exception e) {
                e.printStackTrace();
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        }, 2, TimeUnit.HOURS);

    }


    /**
     * 进入帮战地图前处理
     */
    public result toBzMapBef(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = j.getString("Id");
        //判断是否在活动时间，活动结束后要将该地图的所有人员传送出去
        if (!isBzAcOpen) {
            return new result(200, 3);
        }
        //判断是否生成了帮战地图信息(判断是否存在自己帮的信息)
        JSONObject bzMap = staticCollection.bzMap.get(bpId);
        if (bzMap == null) {
            //帮主未报名
            return new result(200, 0);
        }
        //两种情况 1.去自己帮的据点 2.去其他帮派的据点


        //队伍中不同帮派的需要移除，前端需要将申请入队的列表给清理
        JSONObject team = startBef.teamService.getTeamByName(name);
        if (team != null) {
            JSONArray members = team.getJSONArray("list");
            for (Object o : members) {
                JSONObject m = (JSONObject) o;
                if (!m.getString("name").equals(name)) {
                    JSONObject msg = startBef.manService.getMsgData(m.getString("name"), con);
                    if (msg.get("bp") == null || msg.get("bp").equals("") || !msg.getJSONObject("bp").getString("Id").equals(bpId)) {
                        return new result(200, 2);//队伍中有其他帮派成员
                    }
                }
            }
        }
        return new result(200, 1);
    }

    /**
     * 帮战启动
     */
    public void startBz() {
        this.isBzAcOpen = true;
        DefaultSqlSession con = null;
        try {
            //开启时会为报名的帮派生成据点 Id->
            ConcurrentHashMap<String, JSONObject> bzMap = staticCollection.bzMap;
            bzMap.clear();
            //10分钟后开启
            int startMin = 1;
            //查询报名的帮派 报名后xq_gangs_fight会有记录，没记录就是没有报名
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
            List<JSONObject> bpfList = gangsMapper.selectGangsFightAndMsg();
            for (int i = 0; i < bpfList.size(); i++) {
                JSONObject a = bpfList.get(i);
                boolean isExist = false;
                for (int j = (i + 1); j < bpfList.size(); j++) {
                    JSONObject b = bpfList.get(j);
                    //每两个同等级的帮派生成一组,同时生成地图
                    if (a.getInteger("lever") == b.getInteger("lever")) {
                        isExist = true;
                        //生成地图数据
                        JSONObject data = new JSONObject();
                        //据点名
                        data.put("Id", strUtils.getId());
                        data.put("mapName", "帮战场景");
                        data.put("lever", a.getInteger("lever"));

                        JSONObject zjf = new JSONObject();
                        zjf.put(a.getString("Id"), 0);//帮战总积分
                        zjf.put(b.getString("Id"), 0);//帮战总积分
                        data.put("zjf", zjf);
                        //每个对抗组需要有单独的一个宝箱集
                        JSONObject bzBoxMap = new JSONObject();
                        data.put("box", bzBoxMap);

                        //为每个成员生成对应积分缓存
                        JSONObject mb = new JSONObject();
                        JSONArray aList = new JSONArray();
                        JSONArray bList = new JSONArray();
                        List<JSONObject> al = gangsMapper.selectGangsMembers(a.getString("Id"), null);
                        List<JSONObject> bl = gangsMapper.selectGangsMembers(b.getString("Id"), null);
                        for (JSONObject l : al) {
                            JSONObject n = new JSONObject();
                            n.put("name", l.get("name"));
                            n.put("jf", 0);
                            aList.add(n);
                        }
                        for (JSONObject l : bl) {
                            JSONObject n = new JSONObject();
                            n.put("name", l.get("name"));
                            n.put("jf", 0);
                            bList.add(n);
                        }
                        mb.put(a.getString("Id"), aList);
                        mb.put(b.getString("Id"), bList);
                        data.put("mb", mb);

                        bzMap.put(data.getString("Id"), data);


                        //先移除后位，再移除前位
                        bpfList.remove(j);
                        bpfList.remove(i);
                        i--;//回到前一位
                        break;
                    }
                }
                if (!isExist) {
                    //当找不到可以对战的帮派时，自动胜利
                    int lever = a.getInteger("lever");
                    JSONArray rewards = new JSONArray();
                    rewardUtils.getGoodsReward("10000173", lever * 100, 1, rewards);
                    rewardUtils.getBgReward(400 * lever, rewards);
                    List<JSONObject> members = gangsMapper.selectGangsMembers(a.getString("Id"), null);
                    for (int j = 0; j < members.size(); j++) {
                        JSONObject m = members.get(j);
                        startBef.rewardService.saveRewards(rewards, m.getString("name"), con);
                        ChannelSupervise.noticeClientByName(rewards, m.getString("name"), "10000");
                    }
                }
            }
            mybatisConfig.commit(con);
            startBef.chatService.putSysMsg("帮战" + startMin + "分钟后开启，请进入帮战场景做好准备！");
            //10分钟后才会推送
            staticCollection.putTask(() -> {
                //生成固定的宝箱并推送
                for (String k : bzMap.keySet()) {
                    JSONObject bzBoxMap = bzMap.get(k).getJSONObject("box");
                    createBzBox(bzBoxMap);
                }

                Map<String, ScheduledFuture<?>> task = new HashMap<>();
                //推送随机宝箱
                ScheduledFuture<?> t0 = null;
                t0 = staticCollection.putTask(() -> {
                    if (!isBzAcOpen) {
                        task.get("t0").cancel(true);
                        return;
                    }
                    //每20秒刷一次随机积分宝箱
                    for (String k : bzMap.keySet()) {
                        JSONObject bzBoxMap = bzMap.get(k).getJSONObject("box");
                        for (int i = 0; i < 20; i++) {
                            //刷新缓存
                            bzBoxMap.put("sj" + i, addBzBox(3));
                        }
                    }
                    //不需要每个对抗组都推送一次
                    JSONArray list = new JSONArray();
                    JSONArray clearList = new JSONArray();
                    for (int i = 0; i < 20; i++) {
                        //todo：怎么将不同对抗组的地图进行区分
                        //todo：推送到帮战地图（每两个帮派组成一个帮战地图）
                        //list.add(mapData.getOne("bz_box_sj" + i, mapData.getVc(strUtils.getRandom(158, 191), strUtils.getRandom(63, 103), 0), null));
                        list.add(mapData.getOne("bz_box_sj" + i, mapData.getVc(strUtils.getRandom(50, 350), strUtils.getRandom(50, 350)), null));
                        clearList.add("bz_box_sj" + i);
                    }

                    startBef.mapService.pushNpcToClient(list, 2, "bz", "bz", clearList);
                }, 1, 20, TimeUnit.SECONDS);
                task.put("t0", t0);
                //开启一个定时任务，对宝箱对应的玩家增加积分
                ScheduledFuture<?> t1 = null;
                t1 = staticCollection.putTask(() -> {
                    if (!isBzAcOpen) {
                        task.get("t1").cancel(true);
                        return;
                    }
                    //每2秒加一次积分
                    for (String k : bzMap.keySet()) {
                        JSONObject bzBoxMap = bzMap.get(k);
                        //bpId->jf
                        JSONObject zjf = bzBoxMap.getJSONObject("zjf");
                        //bpId->list
                        JSONObject mb = bzBoxMap.getJSONObject("mb");
                        JSONObject boxObj = bzBoxMap.getJSONObject("box");
                        for (String bk : boxObj.keySet()) {
                            if (bk.contains("b") &&
                                    boxObj.getJSONObject(bk).get("playerName") != null) {
                                JSONObject box = boxObj.getJSONObject(bk);
                                String plName = box.getString("playerName");
                                //对于不在线的要移除
                                if (!staticCollection.userIsOnline(plName)) {
                                    box.put("playerName", null);
                                    box.put("isFight", 0);
                                    continue;
                                }
                                int jf = 0;
                                if (box.getInteger("type") == 0) jf = 40;
                                else if (box.getInteger("type") == 1) jf = 20;
                                else if (box.getInteger("type") == 2) jf = 10;
                                //个人积分++
                                String myBpId = null;
                                for (String bpId : mb.keySet()) {
                                    JSONArray members = mb.getJSONArray(bpId);
                                    boolean isAdd = false;
                                    for (int p = 0; p < members.size(); p++) {
                                        JSONObject m = (JSONObject) members.get(p);
                                        if (m.getString("name").equals(plName)) {
                                            m.put("jf", m.getInteger("jf") + jf);
                                            isAdd = true;
                                            myBpId = bpId;
                                            //通知积分++
                                            ChannelSupervise.noticeClientByName(jf, plName, "107");
                                            break;
                                        }
                                    }
                                    if (isAdd) break;
                                }
                                //总积分++
                                zjf.put(myBpId, zjf.getInteger(myBpId) + jf);
                            }
                        }

                    }
                }, 1, 2, TimeUnit.SECONDS);
                task.put("t1", t1);
                //每10秒同步一次积分排行
                ScheduledFuture<?> t2 = null;
                t2 = staticCollection.putTask(() -> {
                    if (!isBzAcOpen) {
                        task.get("t2").cancel(true);
                        return;
                    }
                    List<JSONObject> order = new ArrayList<>();
                    for (String k : bzMap.keySet()) {
                        JSONObject bzBoxMap = bzMap.get(k);
                        //bpId->jf
                        JSONObject zjf = bzBoxMap.getJSONObject("zjf");
                        //bpId->list
                        JSONObject mb = bzBoxMap.getJSONObject("mb");
                        //进行排名
                        JSONArray tt = new JSONArray();
                        int tp = 0;//区分红蓝
                        for (String bpId : mb.keySet()) {
                            JSONArray al = mb.getJSONArray(bpId);
                            for (Object a : al) {
                                JSONObject n = staticCollection.copyObj(a);
                                n.put("tp", tp);
                                tt.add(n);
                            }
                            tp++;
                        }
                        for (Object o : tt) {
                            //name,jf
                            JSONObject obj = (JSONObject) o;
                            boolean b = false;
                            for (int j = 0; j < order.size(); j++) {
                                JSONObject o1 = order.get(j);
                                //大的放前面
                                if (obj.getInteger("jf") > o1.getInteger("jf")) {
                                    order.add(j, obj);
                                    b = true;
                                    break;
                                }
                            }
                            //当这个是最小时放在后面
                            if (!b) {
                                order.add(obj);
                            }
                        }
                        //推送
                        for (int j = 0; j < order.size(); j++) {
                            ChannelSupervise.noticeClientByName(order, order.get(j).getString("name"), "108");
                        }
                    }
                }, 10, 10, TimeUnit.SECONDS);
                task.put("t2", t2);

            }, startMin, TimeUnit.MINUTES);

        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 获取一个帮战玩家
     */
    private JSONObject getBzPlayer(String bzId, String bpId, String playerName) {
        JSONArray list = staticCollection.bzMap.get(bzId).getJSONObject("mb").getJSONArray(bpId);
        for (int i = 0; i < list.size(); i++) {
            JSONObject a = (JSONObject) list.get(i);
            if (a.getString("name").equals(playerName)) return a;
        }
        return null;
    }


    /**
     * 生成帮战宝箱（帮战开启时调用）
     */
    public void createBzBox(JSONObject bzBoxMap) {
        bzBoxMap.put("b1", addBzBox(0));
        bzBoxMap.put("b2", addBzBox(0));

        bzBoxMap.put("b3", addBzBox(1));
        bzBoxMap.put("b4", addBzBox(1));
        bzBoxMap.put("b5", addBzBox(1));
        bzBoxMap.put("b6", addBzBox(1));
        for (int i = 7; i < 17; i++) {
            bzBoxMap.put("b" + i, addBzBox(2));
        }
        //推送
        JSONArray list = new JSONArray();
        JSONArray clearList = new JSONArray();
        for (String k : bzBoxMap.keySet()) {
            //todo：怎么将不同对抗组的地图进行区分
            //todo：推送到帮战地图（每两个帮派组成一个帮战地图）
            //list.add(mapData.getOne("bz_box_" + k, mapData.getVc(strUtils.getRandom(158, 191), strUtils.getRandom(63, 103), 0), null));
            list.add(mapData.getOne("bz_box_" + k, mapData.getVc(strUtils.getRandom(50, 350), strUtils.getRandom(50, 350)), null));
            clearList.add("bz_box_" + k);
        }
        startBef.mapService.pushNpcToClient(list, 2, "bz", "bz", clearList);
    }

    /**
     * 根据帮派id取
     */
    public JSONArray getBoxsByBpId(String bpId) {
        for (String bzId : staticCollection.bzMap.keySet()) {
            JSONObject a = staticCollection.bzMap.get(bzId);
            JSONObject mb = a.getJSONObject("mb");
            if (mb.get(bpId) != null) {
                JSONObject bzBoxMap = a.getJSONObject("box");
                JSONArray list = new JSONArray();
                for (String k : bzBoxMap.keySet()) {
                    //todo：怎么将不同对抗组的地图进行区分
                    //todo：推送到帮战地图（每两个帮派组成一个帮战地图）
                    //list.add(mapData.getOne("bz_box_" + k, mapData.getVc(strUtils.getRandom(158, 191), strUtils.getRandom(63, 103), 0), null));
                    list.add(mapData.getOne("bz_box_" + k, mapData.getVc(strUtils.getRandom(50, 350), strUtils.getRandom(50, 350)), null));
                }
                return list;
            }
        }

        return new JSONArray();
    }

    /**
     * 根据key取一个宝箱
     */
    public JSONObject getOneBox(String bzId, String boxKey) {
        return staticCollection.bzMap.get(bzId)
                .getJSONObject("box")
                .getJSONObject(boxKey);
    }

    public JSONObject getBoxByPlayerName(String bzId, String playerName) {
        JSONObject map = staticCollection.bzMap.get(bzId).getJSONObject("box");
        for (String k : map.keySet()) {
            JSONObject m = map.getJSONObject(k);
            if (m.get("playerName") != null &&
                    m.getString("playerName").equals(playerName)) return m;
        }
        return null;
    }

    private JSONObject addBzBox(int type) {
        //40分 20 10 3-8分
        JSONObject box = new JSONObject();
        box.put("type", type);//0金 1银 2铜 3随机积分宝箱
        box.put("playerName", null);
        box.put("isFight", 0);//是否处于抢夺中
        return box;
    }

    /**
     * 单次帮战结算
     * 胜利者占领宝箱
     */
    public Integer bzOneRes(String bzId, String boxKey, String name) {
        //将宝箱对应的占领玩家替换成name
        JSONObject bz = staticCollection.bzMap.get(bzId);
        JSONObject box = bz.getJSONObject("box");
        JSONObject boxMap = box.getJSONObject(boxKey);
        boxMap.put("playerName", name);
        boxMap.put("isFight", 0);//标记不处于抢夺中
        return 1;
    }

    /**
     * 帮战结算 20：00-20：20
     */
    public void bzOverResult() {
        this.isBzAcOpen = false;
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
            //移除所有报名的
            gangsMapper.delGangsFight();
            mybatisConfig.commit(con);
            //根据帮派积分派发奖励
            StringBuilder sb = new StringBuilder();
            sb.append("帮战已结束！");
            //按等级组，帮派胜负
            for (String bzId : staticCollection.bzMap.keySet()) {
                JSONObject bz = staticCollection.bzMap.get(bzId);
                int lever = bz.getInteger("lever");
                JSONObject zjf = bz.getJSONObject("zjf");
                int jf1 = 0;
                String bp1 = null;
                int jf2 = 0;
                String bp2 = null;
                for (String bpId : zjf.keySet()) {
                    if (bp1 == null) {
                        bp1 = bpId;
                        jf1 = zjf.getInteger(bpId);
                    } else {
                        bp2 = bpId;
                        jf2 = zjf.getInteger(bpId);
                    }
                }
                JSONObject mb = bz.getJSONObject("mb");
                JSONArray members = null;
                if (jf1 > jf2) {
                    members = mb.getJSONArray(bp1);
                    bz.put("win", 1);
                } else if (jf1 < jf2) {
                    members = mb.getJSONArray(bp2);
                    bz.put("win", 2);
                } else {
                    bz.put("win", 3);
                }
                //按帮派等级决定奖励
                if (members == null) continue;
                JSONArray rewards = new JSONArray();
                rewardUtils.getGoodsReward("10000173", lever * 100, 1, rewards);
                rewardUtils.getBgReward(500 + lever * 500, rewards);
                for (int i = 0; i < members.size(); i++) {
                    JSONObject a = (JSONObject) members.get(i);
                    startBef.rewardService.saveRewards(rewards, a.getString("name"), con);
                    ChannelSupervise.noticeClientByName(rewards, a.getString("name"), "10000");
                }
            }
            //按满足的分数段
            for (String bzId : staticCollection.bzMap.keySet()) {
                JSONObject bz = staticCollection.bzMap.get(bzId);
                int lever = bz.getInteger("lever");
                JSONObject zjf = bz.getJSONObject("zjf");
                JSONObject mb = bz.getJSONObject("mb");
                for (String bpId : mb.keySet()) {
                    //没有达到最低积分的去掉
                    if (zjf.getInteger(bpId) < 10000) continue;
                    int t = 0;
                    if (zjf.getInteger(bpId) >= 30000 && zjf.getInteger(bpId) < 50000) {
                        t = 1;
                    } else if (zjf.getInteger(bpId) >= 50000 && zjf.getInteger(bpId) < 70000) {
                        t = 2;
                    } else if (zjf.getInteger(bpId) >= 70000 && zjf.getInteger(bpId) < 90000) {
                        t = 3;
                    }
                    JSONArray members = mb.getJSONArray(bpId);
                    JSONArray rewards = new JSONArray();
                    rewardUtils.getTaleReward(3000 + 500 * t + (lever - 1) * 600, rewards);
                    rewardUtils.getBgReward(500 + 500 * t + (lever - 1) * 200, rewards);
                    for (int i = 0; i < members.size(); i++) {
                        JSONObject a = (JSONObject) members.get(i);
                        startBef.rewardService.saveRewards(rewards, a.getString("name"), con);
                        ChannelSupervise.noticeClientByName(rewards, a.getString("name"), "10000");
                    }
                }

            }
            //按个人积分排行
            JSONObject order = new JSONObject();
            order.put("1", new JSONArray());
            order.put("2", new JSONArray());
            order.put("3", new JSONArray());
            order.put("4", new JSONArray());
            order.put("5", new JSONArray());
            for (String bzId : staticCollection.bzMap.keySet()) {
                JSONObject bz = staticCollection.bzMap.get(bzId);
                int lever = bz.getInteger("lever");
                JSONArray orderList = order.getJSONArray(lever + "");
                JSONObject mb = bz.getJSONObject("mb");
                for (String bpId : mb.keySet()) {
                    JSONArray members = mb.getJSONArray(bpId);
                    for (int i = 0; i < members.size(); i++) {
                        JSONObject m = (JSONObject) members.get(i);
                        int jf = m.getInteger("jf");
                        //积分为0的不参与排行
                        if (jf == 0) continue;
                        boolean b = false;
                        for (int j = 0; j < orderList.size(); j++) {
                            JSONObject o = (JSONObject) orderList.get(j);
                            if (jf > o.getInteger("jf")) {
                                orderList.add(j, m);
                                b = true;
                                break;
                            }
                        }
                        //比所有都小时放最后
                        if (!b) orderList.add(m);
                    }
                }
            }
            for (String k : order.keySet()) {
                int t = 0;
                if (k.equals("2")) t = 1;
                else if (k.equals("3")) t = 2;
                else if (k.equals("4")) t = 3;
                else if (k.equals("5")) t = 4;
                JSONArray al = order.getJSONArray(k);
                for (int i = 0; i < al.size(); i++) {
                    JSONObject a = (JSONObject) al.get(i);
                    int n1 = 0;
                    int n2 = 0;
                    if (i == 0) {
                        n1 = 100 + t * 50;
                        n2 = 1000 + t * 800;
                    } else if (i == 1) {
                        n1 = 80 + t * 40;
                        n2 = 800 + t * 500;
                    } else if (i == 2) {
                        n1 = 60 + t * 30;
                        n2 = 600 + t * 300;
                    } else if (i >= 3 && i < 5) {
                        n1 = 50 + t * 20;
                        n2 = 500 + t * 200;
                    } else if (i >= 5 && i < 10) {
                        n1 = 50 + t * 10;
                        n2 = 300 + t * 150;
                    } else if (i >= 10 && i < 20) {
                        n1 = 50 + t * 10;
                        n2 = 200 + t * 100;
                    } else if (i >= 20 && i < 999) {
                        n1 = 30 + t * 10;
                        n2 = 100 + t * 50;
                    }
                    JSONArray rewards = new JSONArray();
                    rewardUtils.getGoodsReward("10000173", n1, 1, rewards);
                    rewardUtils.getBgReward(n2, rewards);
                    startBef.rewardService.saveRewards(rewards, a.getString("name"), con);
                    ChannelSupervise.noticeClientByName(rewards, a.getString("name"), "10000");
                }
            }

            mybatisConfig.commit(con);

            startBef.chatService.putSysMsg(sb.toString());
            //通知玩家跳转地图
            ChannelSupervise.noticeAllClientInArea("bz", "m_1", "792");
        } catch (Exception e) {
            mybatisConfig.rollback(con);
            e.printStackTrace();
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 拾取帮战宝箱或获取宝箱信息
     */
    public result getBzBox(JSONObject j,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        if (bpId == null) {
            return new result(648);
        }
        String boxKey = j.getString("npcKey").replace("bz_box_", "");
        //是否在报名的时间
        if (!isBzAcOpen) {
            return new result(863);
        }
        for (String bzId : staticCollection.bzMap.keySet()) {
            JSONObject a = staticCollection.bzMap.get(bzId);
            JSONObject zjf = a.getJSONObject("zjf");
            JSONObject mb = a.getJSONObject("mb");
            if (mb.get(bpId) != null) {
                JSONObject bzBoxMap = a.getJSONObject("box");
                JSONObject box = bzBoxMap.getJSONObject(boxKey);
                if (boxKey.contains("sj")) {
                    if (box.get("playerName") != null) {//被开过了
                        return new result(200, -1);
                    }
                    //标记领取了
                    box.put("playerName", name);
                    //随机积分的直接给积分
                    int jf = strUtils.getRandom(1, 8);
                    JSONArray members = mb.getJSONArray(bpId);
                    for (int p = 0; p < members.size(); p++) {
                        JSONObject m = (JSONObject) members.get(p);
                        if (m.getString("name").equals(name)) {
                            m.put("jf", m.getInteger("jf") + jf);
                            //总积分++
                            zjf.put(bpId, zjf.getInteger(bpId) + jf);
                            //通知积分++
                            ChannelSupervise.noticeClientByName(jf, name, "107");
                            break;
                        }
                    }
                    return new result(200, 1);
                }
                //弹出宝箱信息
                JSONObject res = new JSONObject();
                res.put("playerName", box.getString("playerName"));
                res.put("boxKey", boxKey);
                res.put("bzId", bzId);
                return new result(200, res);
            }
        }
        return new result(221);
    }

    private JSONArray getShop() {
        JSONArray arr = new JSONArray();
        addToProps("1189", 200, 1, 3, arr);
        addToProps("1190", 500, 1, 3, arr);
        addToProps("1191", 1000, 1, 3, arr);
        addToProps("1192", 1500, 1, 3, arr);
        addToProps("1193", 2000, 1, 3, arr);
        addToProps("1194", 200, 1, 3, arr);
        addToProps("1195", 500, 1, 3, arr);
        addToProps("1196", 1000, 1, 3, arr);
        addToProps("1197", 1500, 1, 3, arr);
        addToProps("1198", 2000, 1, 3, arr);
        return arr;
    }

    private void addToProps(String k, int price, int num, int sum, JSONArray list) {
        JSONObject a = new JSONObject();
        a.put("key", k);
        a.put("price", price);
        a.put("num", num);
        a.put("sum", sum);
        list.add(a);
    }

    /**
     * 获取可兑换的商品
     */
    public result getExchangeShop(
            @paramsAnno(key = "user") user user,
            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = gangsMapper.selectBRE(name);
        if (list.size() == 0) {
            gangsMapper.insertBRE(name);
            list = gangsMapper.selectBRE(name);
        }
        JSONObject a = list.get(0);
        //{key,sum} 每兑换一次sum+1
        JSONObject exchange = a.getJSONObject("exchange");

        JSONArray arr = getShop();

        for (int i = 0; i < arr.size(); i++) {
            JSONObject o = arr.getJSONObject(i);
            String k = o.getString("key");
            if (exchange.get(k) == null) continue;
            o.put("sum", o.getInteger("sum") - exchange.getInteger(k));
        }
        return new result(200, arr);
    }

    /**
     * 兑换物品
     */
    public result jfExchange(JSONObject obj,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = obj.getString("key");
        //判断是否还有剩余
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = gangsMapper.selectBRE(name);
        JSONObject a = list.get(0);
        //{key,sum} 每兑换一次sum+1
        JSONObject exchange = a.getJSONObject("exchange");
        if (exchange.get(key) == null) {
            exchange.put(key, 0);
        }
        //是否为可兑换的物品
        int gdNum = 0;
        int price = 0;
        JSONArray arr = getShop();
        for (int i = 0; i < arr.size(); i++) {
            JSONObject o = arr.getJSONObject(i);
            String k = o.getString("key");
            if (k.equals(key)) {
                gdNum = o.getInteger("num");
                price = o.getInteger("price");
                //没有剩余
                if (o.getInteger("sum") - exchange.getInteger(k) <= 0) {
                    return new result(0);
                }
            }

        }
        //是否为可兑换的物品、是否有足够的神将令牌
        if (gdNum == 0 || startBef.packageService.cutPlayerGoodsNumByKey("1188", price, name, con) != 1)
            return new result(0);

        //每兑换一次sum+1
        exchange.put(key, exchange.getInteger(key) + 1);
        boolean b = gangsMapper.updateBRE(name, JSON.toJSONString(exchange));
        if (!b) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        JSONArray rewards = rewardUtils.getGoodsReward(key, gdNum, 1);
        startBef.rewardService.saveRewards(rewards, name, con);
        return new result(200, rewards);
    }

    /**
     * 获取帮战成员积分榜
     */
    public result getBzMbJf(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> al = dao.selectGangsFightAndMsg();
        JSONArray list = new JSONArray();
        for (String bzId : staticCollection.bzMap.keySet()) {
            JSONObject a = staticCollection.bzMap.get(bzId);
            JSONArray mb = a.getJSONArray("mb");
            //遍历对战的每一组（a帮派 pk b帮派）
            for (int i = 0; i < mb.size(); i++) {
                JSONObject m = mb.getJSONObject(i);
                for (String bpId : m.keySet()) {
                    String bpName = null;
                    for (JSONObject bp : al) {
                        if (bp.getString("Id").equals(bpId)) {
                            bpName = bp.getString("name");
                            break;
                        }
                    }
                    JSONArray arr = m.getJSONArray(bpId);
                    for (int j = 0; j < arr.size(); j++) {
                        JSONObject msg = arr.getJSONObject(j);
                        JSONObject one = new JSONObject();
                        one.put("name", msg.get("name"));
                        one.put("jf", msg.get("jf"));
                        one.put("bpName", bpName);
                        list.add(one);
                    }
                }
            }
        }
        return new result(200, list);
    }

    /**
     * 获取所有对战的帮派（19:50分发布）
     */
    public result getPkOfGangs(@paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> al = dao.selectGangsFightAndMsg();
        JSONArray list = new JSONArray();
        for (String bzId : staticCollection.bzMap.keySet()) {
            JSONObject a = staticCollection.bzMap.get(bzId);
            JSONObject zjf = a.getJSONObject("zjf");
            JSONObject res = new JSONObject();
            res.put("bzId", bzId);
            res.put("win", a.get("win"));
            JSONArray bpList = new JSONArray();
            for (String bpId : zjf.keySet()) {
                JSONObject bp = new JSONObject();
                bp.put("Id", bpId);
                bp.put("jf", zjf.get(bpId));
                for (int i = 0; i < al.size(); i++) {
                    if (bpId.equals(al.get(i).getString("Id"))) {
                        bp.put("name", al.get(i).get("name"));
                        bp.put("lever", al.get(i).get("lever"));
                        bpList.add(bp);
                        break;
                    }
                }

            }
            res.put("bpList", bpList);
            list.add(res);
        }
        return new result(200, list);
    }

    /**
     * 获取所有报名帮战的帮派
     */
    public result getSignUpBzOfGangs(@paramsAnno(key = "user") user user,
                                     @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = dao.selectGangsFightAndMsg();
        return new result(200, list);
    }

    /**
     * 报名帮战
     */
    public result signUpBz(@paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        //是否在报名的时间
        if (isBzAcOpen) {
            return new result(674);
        }
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        //判断是否有权限报名（帮主、副帮主）
        JSONObject mem = dao.selectGangsMembers(null, name).get(0);
        if (mem.getInteger("job") > 1) {
            return new result(649);
        }
        //是否已经报过名了
        List<JSONObject> list = dao.selectGangsFight(bpId);
        if (list.size() != 0) {
            return new result(667);
        }
        return new result(200, dao.insertGangsFight(bpId, "0") ? 1 : 0);
    }

    /**
     * 完成跑商目标
     */
    public result compilePs(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        //验证白银是否满足100000
        List<JSONObject> psList = dao.selectGangsPs(name);
        if (psList.size() == 0) {
            return new result(696);
        }
        JSONObject m = psList.get(0);
        if (m.getInteger("tale") < 100000) {
            return new result(998);
        }
        //清理跑商背包
        boolean b = dao.delGangsPs(name);
        if (b) {
            //获得40000银两
            JSONArray res = rewardUtils.getTaleReward(40000);
            startBef.rewardService.saveRewards(res, name, con);
            return new result(200, res);
        }
        return new result(0);

    }

    /**
     * 出售跑商商品
     */
    public result salePsGoods(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int num = j.getInteger("num");
        String key = j.getString("key");
        List<JSONObject> list = goodsMapToList();
        if (list == null || list.size() == 0 || num <= 0 || key == null) {
            return new result(0);
        }
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.get("key").equals(key)) {
                List<JSONObject> psList = dao.selectGangsPs(name);
                if (psList.size() == 0) {
                    return new result(0);
                }
                JSONObject m = psList.get(0);
                int ye = m.getInteger("tale") + obj.getInteger("price") * num;
                if (ye < 0) {
                    return new result(0);
                }
                JSONArray goods = m.getJSONArray("goods");
                boolean b = false;
                for (Object g : goods) {
                    JSONObject o = (JSONObject) g;
                    if (o.getString("key").equals(key)) {
                        o.put("num", o.getInteger("num") - num);
                        if (o.getInteger("num") < 0) {
                            return new result(0);
                        }
                        if (o.getInteger("num") == 0) {
                            goods.remove(g);
                        }
                        b = true;
                        break;
                    }
                }
                if (!b) {
                    return new result(0);
                }
                dao.updateGangsPs(name, ye + "", JSON.toJSONString(goods));
                return new result(200, ye);
            }
        }
        return new result(0);
    }

    /**
     * 购买跑商商品
     */
    public result buyPsGoods(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String areaKey = j.getString("areaKey");
        int num = j.getInteger("num");
        String key = j.getString("key");
        JSONArray list = staticCollection.psMap.get(areaKey);
        if (list == null || list.size() == 0 || num <= 0 || key == null) {
            return new result(0);
        }
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.get("key").equals(key)) {
                List<JSONObject> psList = dao.selectGangsPs(name);
                if (psList.size() == 0) {
                    return new result(0);
                }
                JSONObject m = psList.get(0);
                int ye = m.getInteger("tale") - obj.getInteger("price") * num;
                if (ye < 0) {
                    return new result(0);
                }
                JSONArray goods = m.getJSONArray("goods");
                boolean b = false;
                for (Object g : goods) {
                    JSONObject o = (JSONObject) g;
                    if (o.getString("key").equals(key)) {
                        o.put("num", o.getInteger("num") + num);
                        b = true;
                        break;
                    }
                }
                if (!b) {
                    JSONObject my = new JSONObject();
                    my.put("key", key);
                    my.put("num", num);
                    my.put("name", obj.getString("name"));
                    goods.add(my);
                }
                dao.updateGangsPs(name, ye + "", JSON.toJSONString(goods));
                return new result(200, ye);
            }
        }
        return new result(0);
    }

    /**
     * 将跑商商品变成列表
     */
    private List<JSONObject> goodsMapToList() {
        List<JSONObject> arr = new ArrayList<>();
        synchronized (staticCollection.psMap) {
            for (String o : staticCollection.psMap.keySet()) {
                JSONArray list = staticCollection.psMap.get(o);
                for (Object l : list) {
                    arr.add((JSONObject) l);
                }
            }
        }
        return arr;
    }

    /**
     * 获取当前商品的价格
     */
    public result getPsGoodsPrice(JSONObject j) {
        String areaKey = j.getString("areaKey");
        String key = j.getString("key");
        JSONArray arr = staticCollection.psMap.get(areaKey);
        for (Object a : arr) {
            JSONObject aa = (JSONObject) a;
            if (aa.getString("key").equals(key)) {
                return new result(200, aa.getInteger("price"));
            }
        }
        return new result(0);
    }

    /**
     * 获取拥有的跑商商品
     */
    public result getMyPsGoods(@paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = dao.selectGangsPs(name);
        if (list.size() == 0) {
            return new result(0);
        }
        JSONObject a = list.get(0);
        JSONArray arr = a.getJSONArray("goods");
        JSONObject res = new JSONObject();
        res.put("list", arr);
        res.put("tale", a.getInteger("tale"));
        return new result(200, res);
    }

    /**
     * 获取跑商区域的商品
     */
    public result getPsGoods(JSONObject j, @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String areaKey = j.getString("key");
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = dao.selectGangsPs(name);
        if (list.size() == 0) {
            return new result(0);
        }
        JSONObject a = list.get(0);
        JSONObject res = new JSONObject();
        res.put("list", staticCollection.psMap.get(areaKey));
        res.put("tale", a.getInteger("tale"));
        return new result(200, res);
    }

    /**
     * 初始化跑商货物并启动定时任务
     */
    public void initPsGoods() {
        if (staticCollection.psMap.size() != 0) {
            return;
        }
        //先进行初始化
        List<JSONObject> shop = new ArrayList<>();
        JSONObject obj = new JSONObject();
        obj.put("key", "g001");
        obj.put("name", "茶叶");
        obj.put("price", 80);
        obj.put("base", 80);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g002");
        obj.put("name", "鹿茸");
        obj.put("price", 120);
        obj.put("base", 120);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g003");
        obj.put("name", "人参");
        obj.put("price", 150);
        obj.put("base", 150);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g004");
        obj.put("name", "玉瓷");
        obj.put("price", 100);
        obj.put("base", 100);
        shop.add(staticCollection.copyObj(obj));
        staticCollection.psMap.put("p1", staticCollection.copyArr(shop));
        shop.clear();

        obj.put("key", "g005");
        obj.put("name", "人参");
        obj.put("price", 180);
        obj.put("base", 180);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g006");
        obj.put("name", "玉瓷");
        obj.put("price", 120);
        obj.put("base", 120);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g007");
        obj.put("name", "丝绸");
        obj.put("price", 200);
        obj.put("base", 200);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g008");
        obj.put("name", "珠宝");
        obj.put("price", 250);
        obj.put("base", 250);
        shop.add(staticCollection.copyObj(obj));
        staticCollection.psMap.put("p2", staticCollection.copyArr(shop));
        shop.clear();

        obj.put("key", "g009");
        obj.put("name", "面粉");
        obj.put("price", 90);
        obj.put("base", 90);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g010");
        obj.put("name", "酒料");
        obj.put("price", 150);
        obj.put("base", 150);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g011");
        obj.put("name", "茶叶");
        obj.put("price", 80);
        obj.put("base", 80);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g012");
        obj.put("name", "鹿茸");
        obj.put("price", 110);
        obj.put("base", 110);
        shop.add(staticCollection.copyObj(obj));
        staticCollection.psMap.put("p3", staticCollection.copyArr(shop));
        shop.clear();

        obj.put("key", "g013");
        obj.put("name", "面粉");
        obj.put("price", 80);
        obj.put("base", 80);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g014");
        obj.put("name", "香料");
        obj.put("price", 100);
        obj.put("base", 100);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g015");
        obj.put("name", "丝绸");
        obj.put("price", 180);
        obj.put("base", 180);
        shop.add(staticCollection.copyObj(obj));
        obj.put("key", "g016");
        obj.put("name", "珠宝");
        obj.put("price", 100);
        obj.put("base", 100);
        shop.add(staticCollection.copyObj(obj));
        staticCollection.psMap.put("p4", staticCollection.copyArr(shop));
        shop.clear();
    }

    /**
     * 刷新跑商物价
     */
    public void updatePsGoodsRes() {
        initPsGoods();
        for (String k : staticCollection.psMap.keySet()) {
            JSONArray list = staticCollection.psMap.get(k);
            for (Object l : list) {
                JSONObject o = (JSONObject) l;
                //增减一定价钱，最低50%最高400%
                Double d = strUtils.getRandom(1, 11) * 0.01 * o.getInteger("price");
                if (strUtils.isHappend(0, 100, 0.5f)) {
                    d *= -1;
                }

                if ((o.getInteger("price") + d.intValue()) > o.getInteger("base") * 4) {
                    //大于最大值就变负号
                    d = -Math.abs(d);
                } else if ((o.getInteger("price") + d.intValue()) < o.getInteger("base") * 0.5) {
                    //前提是小于号，小于最小值就变正号
                    d = Math.abs(d);
                }
                o.put("price", o.getInteger("price") + d.intValue());
            }
        }
    }

    /**
     * 跳转跑商地图之前
     */
    public result getPsTask(@paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        //判断身上是否存在未完成的跑商任务
        List<JSONObject> list = dao.selectGangsPs(name);
        if (list.size() > 0) {
            //身上有未完成的任务，直接进入场景
            return new result(998);
        }
        //判断跑商次数是否还有剩余
        List<JSONObject> bpList = dao.selectGangsActivityAndV(bpId);
        if (bpList.size() == 0 || bpList.get(0).getInteger("ps") == 0) {
            return new result(696);
        }
        if (bpList.get(0).getInteger("pstimes") <= 0) {
            return new result(610);
        }
        //是否有2w
        int isEnough = startBef.manService.saveMoney(1, -20000L, name, con);
        if (isEnough == 0) {
            return new result(634);
        }
        //次数--
        int t = bpList.get(0).getInteger("pstimes") - 1;
        boolean b = dao.updateGangsAcTimes(null, null, t + "", null, name);
        if (b) {
            b = dao.insertGangsPs(name);
        }
        return new result(200, 1);
    }



    /**
     * 开启帮派活动
     */
    public result openBPActivity(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = user.msg.getString("bpId");
        int type = j.getInteger("type");
        if (Id == null || type > 2 || type < 0) {
            return new result(0);
        }

        //必须帮主、副帮主才能开
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject m = dao.selectGangsMembers(null, name).get(0);
        if (m.getInteger("job") > 1) {
            return new result(649);
        }
        //需要扣除帮贡
        /*JSONObject bp = dao.selectGangs(Id).get(0);
        if (bp.getInteger("bg") - 10000 < 0) {
            return new result(890);
        }
        dao.updateGangs(null, null, null, bp.getInteger("bg") - 10000 + "", null, Id);
*/
        JSONObject bpAcMsg = dao.selectGangsActivity(Id).get(0);
        if (type == 0) {//开启boss
            if (bpAcMsg.getInteger("boss") == 1) {
                return new result(200, 0);
            }
            dao.updateGangsActivity(Id, "1", null, null, null);
            dao.updateGangsBoss(Id, "10000000", "[]");
            //推送boss到场景
            JSONArray list = new JSONArray();
            list.add(mapData.getOne("2105", mapData.getVc(176f, 92f, 0), null));
            startBef.mapService.pushNpcToClient(list, 1, user.msg.getString("bpId"), "gangs");
        } else if (type == 1) {//开启演武堂（一天一次）
            if (bpAcMsg.getInteger("ywt") == 1) {
                return new result(200, 0);
            }
            //需要帮派达到二级
            int lv = dao.selectGangs(Id).get(0).getInteger("lever");
            if (lv < 2) return new result(997);
            //消耗封赏玉帛
            if (startBef.packageService.cutPlayerGoodsNumByKey("10000174", 1, name, con) != 1) {
                return new result(200, 0);
            }
            dao.updateGangsActivity(Id, null, "1", null, null);
            dao.updateGangsV(Id, "400", null);
            //创建一只猴子npc
            JSONArray list = new JSONArray();
            //todo:位置根据等级来区分
            list.add(mapData.getOne("10000600", mapData.getVc(200, 200), null));
            startBef.mapService.pushNpcToClient(list, 1, Id, "gangs" + lv);
        } else if (type == 2) {//开启跑商（一天开一次，但有四次领取的机会）
            if (bpAcMsg.getInteger("ps") == 1) {
                return new result(200, 0);
            }
            //扣除帮贡
            JSONObject bp = dao.selectGangs(Id).get(0);
            if (bp.getInteger("bg") - 10000 < 0) {
                return new result(890);
            }
            dao.updateGangs(null, null, null, bp.getInteger("bg") - 10000 + "", null, Id);
            //每日一次开启，开启后有四次接取任务的机会，玩家接取任务后会减少1次
            dao.updateGangsActivity(Id, null, null, "1", null);
            dao.updateGangsV(Id, null, "4");
        } else {
            return new result(0);
        }
        //通知成员帮派活动已经开启，某些活动需要刷新地图
        JSONObject res = new JSONObject();
        res.put("type", type);
        ChannelSupervise.noticeAllBpMember(Id, res, "840");
        return new result(200, 1);
    }

    /**
     * 判断帮派boss、跑商等活动是否开启了
     */
    public boolean activityIsOpen(String key, String bpId, DefaultSqlSession con) {
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject m = dao.selectGangsActivity(bpId).get(0);
        if (m.getString(key).equals("1")) {
            return true;
        }
        return false;
    }

    /**
     * 加入帮派
     */
    public result agreeReq(JSONObject j,
                           @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String captain = user.name;
        String name = j.getString("playerName");
        String Id = user.msg.getString("bpId");
        if (startBef.logService.isEnoughLeaveBpTime(name, con) == 0) {
            return new result(767);
        }

        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        //申请人是否已经存在帮派
        if (dao.selectGangsMembers(null, name).size() > 0) {
            //移除申请
            rejectReqOne(name, Id, con);
            //已经有帮派了
            return new result(643);
        }
        List<JSONObject> list = dao.selectGangs(Id);
        if (list.size() == 0) {
            //移除申请
            rejectReqOne(name, Id, con);
            //没有该帮派
            return new result(886);
        }
        //判断是否为有权限审批（帮主、副帮主）
        JSONObject m = dao.selectGangsMembers(null, captain).get(0);
        int job = m.getInteger("job");
        if (job != 0 && job != 1) {
            return new result(649);
        }
        //人数是否满了
        int num = dao.selectGangsMembersSum(Id).get(0).getInteger("n");
        int sum = getSumByLv(list.get(0).getInteger("lever"));
        if (num >= sum) {
            //移除申请
            rejectReqOne(name, Id, con);
            return new result(650);
        }
        //加入成员
        dao.insertGangsMembers(Id, name, "5");

        //人物msg帮派名
        JSONObject bp = new JSONObject();
        bp.put("Id", list.get(0).getString("Id"));
        bp.put("name", list.get(0).getString("name"));
        updateManBP(bp, name, con);
        //移除申请
        rejectReqOne(name, Id, con);
        //创建个人活动次数
        List<JSONObject> personAcTimes = dao.selectGangsAcTimes(name);
        if (personAcTimes.size() == 0) {
            dao.addGangsAcTimes("0", "0", "0", "0", name);
        }

        //通知申请人已加入帮派，并刷新缓存
        if (staticCollection.userIsOnline(name)) {
            //刷新缓存的帮派id
            staticCollection.getUserByName(name).msg.put("bpId", Id);
            ChannelSupervise.noticeClientByName(bp, name, "822");
        }

        //通知帮派成员有新人加入
        JSONObject res = new JSONObject();
        res.put("code", "799");
        res.put("params", name);
        res.put("channel", 4);
        ChannelSupervise.noticeAllBpMember(Id, res, "700");

        return new result(200, 1);
    }

    /**
     * 拒绝申请
     */
    public result rejectReq(JSONObject j,
                            @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        String name = j.getString("playerName");
        String Id = user.msg.getString("bpId");
        //判断是否为有权限审批（帮主、副帮主）
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject m = dao.selectGangsMembers(null, user.name).get(0);
        int job = m.getInteger("job");
        if (job != 0 && job != 1) {
            return new result(649);
        }
        int i = rejectReqOne(name, Id, con);
        ChannelSupervise.noticeClientByName("798", name, "799");
        return new result(200, i);
    }

    public Integer rejectReqOne(String name, String Id, DefaultSqlSession con) {
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);

        JSONArray list = dao.selectGangsReq(Id).get(0).getJSONArray("req");
        Iterator<Object> arr = list.iterator();
        while (arr.hasNext()) {
            try {
                JSONObject obj = (JSONObject) arr.next();
                if (name.equals(obj.getString("name"))) {
                    arr.remove();
                }
            } catch (Exception e) {
                e.printStackTrace();
                loggerUtils.error("拒绝帮派申请错误", gangsService.class);
            }
        }
        dao.updateGangsReq(JSON.toJSONString(list), Id);
        return 1;
    }

    /**
     * 查看入帮申请
     */
    public result viewReqList(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (j.get("pageNum") == null) return new result(0);

        String Id = user.msg.getString("bpId");
        //判断是否为有权限查看入帮申请
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject member = dao.selectGangsMembers(null, name).get(0);
        int job = member.getInteger("job");
        if (job != 0 && job != 1) {
            //无权访问
            return new result(649);
        }
        //获取相关申请
        JSONArray members = dao.selectGangsReq(Id).get(0).getJSONArray("req");
        JSONArray list = new JSONArray();
        int pageNum = j.getInteger("pageNum");
        int pageSum = 10;
        if (members.size() > 0) {
            //StringBuilder suf = new StringBuilder();
            JSONObject map = new JSONObject();
            int end = pageNum * pageSum;
            if (end > members.size()) {
                end = members.size();
            }
            List names = new ArrayList();
            for (int i = (pageNum - 1) * pageSum; i < end; i++) {
                //需要展示的数据：等级、申请人
                JSONObject obj = (JSONObject) members.get(i);
                map.put(obj.getString("name"), obj);
                names.add(obj.getString("name"));
                //suf.append("'" + obj.getString("name") + "',");
            }
            //suf.deleteCharAt(suf.length() - 1);
            roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
            List<JSONObject> ls = roleMapper.selectRoleByNames(names);
            for (JSONObject l : ls) {
                JSONObject m = map.getJSONObject(l.getString("name"));
                m.put("lever", l.getInteger("lever"));
                list.add(m);
            }
        }
        JSONObject page = new JSONObject();
        page.put("list", list);
        int totalPage = members.size() % pageSum == 0 ? (members.size() / pageSum) : (members.size() / pageSum + 1);
        page.put("totalPage", totalPage);
        return new result(200, page);
    }


    /**
     * 踢出帮派
     */
    public result tichuGangs(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = user.msg.getString("bpId");
        String playerName = j.getString("playerName");
        if (Id == null || name == null || playerName == null) {
            return new result(0);
        }
        //帮主不能退出帮派
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject bp = dao.selectGangs(Id).get(0);
        //不能踢帮主、自己踢自己
        if (bp.getString("captain").equals(playerName) || playerName.equals(name)) {
            return new result(649);
        }

        //只允许帮主、副帮主才能移除其他成员（验证权限）
        JSONObject m = dao.selectGangsMembers(null, name).get(0);
        if (m.getInteger("job") == 0 || m.getInteger("job") == 1) {
            List al = new ArrayList();
            al.add(playerName);
            dao.delGangsMembers(al);
            //抹除人物msg的帮派信息
            JSONObject data = new JSONObject();
            data.put("bp", "");
            startBef.manService.saveMsg(playerName, data, con);
            //更新离帮时间
            startBef.logService.updateLeaveBpTime(playerName, con);
            startBef.gangsService.noticeExistGangs(playerName);
            return new result(200, 1);
        }

        return new result(649);
    }

    /**
     * 退出帮派（主动）
     */
    public result existGangs(@paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String Id = user.msg.getString("bpId");
        if (Id == null || name == null) {
            return new result(0);
        }

        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        JSONObject bp = dao.selectGangs(Id).get(0);
        if (bp.getString("captain").equals(name)) {
            //当没有成员时直接解散
            int n = dao.selectGangsMembersSum(Id).get(0).getInteger("n");
            if (n <= 1) {
                //解散
                dissolutionGangs(Id, con);
                return new result(200, 1);
            }
            //需要先转让才可以
            return new result(909);
        }
        //从成员表删除
        List al = new ArrayList();
        al.add(name);
        dao.delGangsMembers(al);
        //抹除人物msg的帮派信息
        JSONObject data = new JSONObject();
        data.put("bp", "");
        startBef.manService.saveMsg(name, data, con);
        //更新离帮时间
        startBef.logService.updateLeaveBpTime(name, con);
        startBef.gangsService.noticeExistGangs(name);

        return new result(200, 1);
    }

    /**
     * 解散帮派
     */
    public void dissolutionGangs(String gangsId, DefaultSqlSession con) {
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        dao.delGangs(gangsId);
        dao.delGangsActivity(gangsId);
        dao.delGangsBoss(gangsId);
        dao.delGangsBuild(gangsId);
        dao.delGangsReq(gangsId);
        dao.delGangsTaskById(gangsId);
        dao.delGangsV(gangsId);
        dao.delGangsYanhui(gangsId);
        dao.delGangsFarm(gangsId);

        List<JSONObject> members = dao.selectGangsMembers(gangsId, null);
        JSONObject msg = new JSONObject();
        msg.put("bp", "");
        List al = new ArrayList();
        for (JSONObject mm : members) {
            try {
                al.add(mm.getString("name"));
                startBef.manService.saveMsg(mm.getString("name"), msg, con);
                //推送帮派已解散，前端刷新缓存
                noticeExistGangs(mm.getString("name"));
            } catch (Exception e) {
                loggerUtils.error(mm.getString("name") + "解散时出现帮派成员不存在：" + e.getMessage(), this.getClass());
            }
        }
        dao.delGangsMembers(al);
    }

    /**
     * 通知退出帮派
     */
    public void noticeExistGangs(String playerName) {
        if (staticCollection.userIsOnline(playerName)) {
            //刷新缓存的帮派id
            staticCollection.getUserByName(playerName).msg.put("bpId", null);
            //通知退出帮派
            ChannelSupervise.noticeClientByName(0, playerName, "836");
        }
    }

    /**
     * 日常维护帮派
     */
    public Integer dayFixBp() {
        //强盗处已经扣除资金了，所以这里只用判断是否有足够的资金即可
        staticCollection.putTask(() -> {
            DefaultSqlSession con = null;
            try {
                con = (DefaultSqlSession) mybatisConfig.getSqlSession();
                gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
                List<JSONObject> list = dao.selectAllGangs();
                for (JSONObject l : list) {
                    //按帮派等级扣除资金
                    int sum = l.getInteger("money");
                    if (sum < 0) {
                        dissolutionGangs(l.getString("Id"), con);
                        mybatisConfig.commit(con);
                    }
                }
                mybatisConfig.commit(con);
            } catch (Exception e) {
                e.printStackTrace();
                mybatisConfig.rollback(con);
            } finally {
                mybatisConfig.close(con);
            }
        });
        return 1;
    }

    public List<JSONObject> viewMembersNames(String bpId, DefaultSqlSession con) {
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        return dao.selectGangsMembersNames(bpId);
    }

    /**
     * 查看帮派成员
     */
    public result viewMemberList(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String bpId = user.msg.getString("bpId");
        if (bpId == null || j.get("pageNum") == null) return new result(0);
        long pageNum = j.getInteger("pageNum") - 1;
        long pageSum = 10;

        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        //分页获取成员
        long sum = dao.selectGangsMembersSum(bpId).get(0).getLong("n");
        List<JSONObject> members = dao.selectGangsMembersByPage(bpId, pageNum * pageSum, pageSum);
        JSONObject map = new JSONObject();
        List names = new ArrayList();
        for (int i = 0; i < members.size(); i++) {
            //需要展示的数据：等级、name、职位、在线状态、贡献(另外表)
            JSONObject obj = members.get(i);
            obj.put("online", staticCollection.userIsOnline(obj.getString("name")) ? 1 : 0);
            map.put(obj.getString("name"), obj);
            names.add(obj.getString("name"));
        }
        JSONArray list = new JSONArray();
        if (map.size() > 0) {
            roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
            List<JSONObject> ls = roleMapper.selectRoleByNames(names);
            for (JSONObject l : ls) {
                JSONObject m = map.getJSONObject(l.getString("name"));
                m.put("lever", l.getInteger("lever"));
                list.add(m);
            }
        }
        JSONObject page = new JSONObject();
        page.put("list", list);
        long totalPage = sum % pageSum == 0 ? (sum / pageSum) : (sum / pageSum + 1);
        page.put("totalPage", totalPage);
        return new result(200, page);
    }

    /**
     * 查看帮派信息
     */
    public result viewBPMsg(JSONObject j,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        if (j.get("Id") == null) return new result(0);
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = dao.selectGangsMsgAndBuild(j.getString("Id"));
        if (list.size() == 0) return new result(0);
        JSONObject gangs = list.get(0);
        long num = dao.selectGangsMembersSum(j.getString("Id")).get(0).getLong("n");
        JSONObject msg = new JSONObject();
        msg.put("name", gangs.get("name"));
        msg.put("lever", gangs.get("lever"));
        msg.put("num", num);
        msg.put("sum", getSumByLv(gangs.getInteger("lever")));
        msg.put("captain", gangs.get("captain"));
        msg.put("money", gangs.get("money"));
        msg.put("bg", gangs.get("bg"));
        //这五个等级达到1级才能升级帮派，15000*(lv-1)+10000，每次升级这5个都将清空
        msg.put("shop", gangs.get("shop"));//升级商店
        msg.put("tec", gangs.get("tec"));//升级科技（建筑）
        msg.put("solicit", gangs.get("solicit"));//升级人数
        msg.put("book", gangs.get("book"));//升级生活技能
        msg.put("mifa", gangs.get("mifa"));//升级秘法（帮战中加成）
        return new result(200, msg);
    }

    /**
     * 跑商道具转移，由a转b
     */
    public Integer psGoodsToElse(String aName, String bName, DefaultSqlSession con) {
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> aList = dao.selectGangsPs(aName);
        if (aList.size() == 0) {
            return 0;
        }
        float rate = strUtils.getRandom(5, 11) * 0.01f;
        if (strUtils.isHappend(0, 100, 0.5f)) {
            //白银
            Float n = aList.get(0).getFloat("tale") * rate;
            if (n.intValue() <= 0) {
                return 0;
            }
            if (dao.updateGangsPs(aName,
                    aList.get(0).getInteger("tale") - n.intValue() + "", null)) {
                List<JSONObject> bList = dao.selectGangsPs(bName);
                try {
                    //通知刷新白银数
                    JSONObject res = new JSONObject();
                    res.put("tale", -n.intValue());
                    ChannelSupervise.noticeClientByName(res, aName, "837");
                    res.put("tale", n.intValue());
                    ChannelSupervise.noticeClientByName(res, bName, "837");
                } catch (Exception e) {
                    e.printStackTrace();
                }
                return dao.updateGangsPs(bName,
                        bList.get(0).getInteger("tale") + n.intValue() + "", null) ? 1 : 0;
            }
        } else {
            //道具
            JSONArray goods = aList.get(0).getJSONArray("goods");
            if (goods.size() == 0) {
                return 0;
            }
            int index = strUtils.getRandom(0, goods.size());
            JSONObject o = (JSONObject) goods.get(index);
            Float num = o.getFloat("num") * rate;
            if (num <= 0) {
                return 0;
            }
            o.put("num", o.getInteger("num") - num.intValue());
            if (dao.updateGangsPs(aName, null, JSON.toJSONString(goods))) {
                List<JSONObject> bList = dao.selectGangsPs(bName);
                JSONArray bg = bList.get(0).getJSONArray("goods");
                boolean b = false;
                for (Object t : bg) {
                    JSONObject item = (JSONObject) t;
                    if (item.getString("key").equals(o.getString("key"))) {
                        item.put("num", item.getInteger("num") + num.intValue());
                        b = true;
                        break;
                    }
                }
                if (!b) {
                    JSONObject m = new JSONObject();
                    m.put("key", o.get("key"));
                    m.put("num", num.intValue());
                    m.put("name", o.get("name"));
                    bg.add(m);
                }
                //通知刷新道具数
                try {
                    JSONObject res = new JSONObject();
                    res.put("key", o.get("key"));
                    res.put("num", -num.intValue());
                    res.put("name", o.get("name"));
                    ChannelSupervise.noticeClientByName(res, aName, "837");
                    res.put("num", num.intValue());
                    ChannelSupervise.noticeClientByName(res, bName, "837");
                } catch (Exception e) {
                    e.printStackTrace();
                }
                return dao.updateGangsPs(bName, null, JSON.toJSONString(bg)) ? 1 : 0;
            }
        }
        return 0;
    }


    /**
     * 击败猴子
     */
    public void beatMonkey(int win, JSONObject data) {
        if (win != 1) return;
        String name = data.getJSONArray("names").get(0).toString();
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
            //猴子数量少于1时不允许获得奖励
            String Id = getBPIdByName(name, con);
            JSONObject bpMsg = dao.selectGangsV(Id).get(0);
            //猴子数量--
            int num = bpMsg.getInteger("monkey");
            if (num <= 0) return;
            num--;
            dao.updateGangsV(Id, num + "", null);
            //奖励玉帛
            JSONArray res = startBef.rewardService.createGoods("10000180", 1, 1, (String) name, con);
            ChannelSupervise.noticeClientByName(res, name, "10000");
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }


    /**
     * 减少帮派boss的血量
     */
    public Integer cutBossXue(JSONObject obj, JSONArray names) {
        if (obj == null || obj.size() == 0) {
            return 0;
        }
        int xue = 0;
        String n = null;
        for (String name : obj.keySet()) {
            int hurt = -obj.getInteger(name);
            if (name.contains("_pet")) {
                name = name.substring(0, name.length() - 4);
            }
            n = name;
            xue += hurt;
        }
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            String Id = getBPIdByName(n, con);
            if (Id == null) {
                return 0;
            }
            gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
            JSONObject bpMsg = dao.selectGangsBoss(Id).get(0);
            if (bpMsg.getInteger("xue") <= 0) {
                return 0;
            }
            //标记今日已经打过boss
            for (Object o : names) {
                dao.updateGangsAcTimes(null, "1", null, null, o.toString());
            }

            int sum = bpMsg.getInteger("xue") - xue < 0 ? 0 : bpMsg.getInteger("xue") - xue;
            String bossReward = null;
            if (sum == 0) {
                //boss被击杀后生成奖励
                JSONArray list = createBPBossReward();
                bossReward = JSON.toJSONString(list);
                //推送10个宝箱给客户端
                startBef.mapService.pushNpcToClient(list, 1, Id, "gangs");
                //通知被击杀
                JSONObject res = new JSONObject();
                res.put("code", "730");
                res.put("channel", 4);
                ChannelSupervise.noticeAllBpMember(Id, res, "700");
            }
            dao.updateGangsBoss(Id, sum + "", bossReward);
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
     * 40份奖励
     */
    public JSONArray createBPBossReward() {
        List<JSONObject> list = new ArrayList<>();

        list.add(getGoods("1004", 10));
        list.add(getGoods("1005", 1));
        list.add(getGoods("1008", 10));
        list.add(getGoods("1009", 10));
        list.add(getGoods("1010", 10));
        list.add(getGoods("1011", 1));
        list.add(getGoods("1013", 10));
        list.add(getGoods("1014", 10));
        list.add(getGoods("110200", 1));
        list.add(getGoods("110201", 1));
        list.add(getGoods("110202", 1));
        list.addAll(new ArrayList<>(list));//22
        list.addAll(new ArrayList<>(list));//44
        list.addAll(new ArrayList<>(list));//88

        list.add(getGoods("1000", 1));
        list.add(getGoods("1001", 1));
        list.add(getGoods("1002", 1));

        //乱序
        Collections.shuffle(list);
        //只取40个
        list = list.subList(0, 42);
        return JSON.parseArray(JSON.toJSONString(list));
    }

    private JSONObject getGoods(String key, Integer num) {
        JSONObject obj = new JSONObject();
        obj.put("key", key);
        obj.put("num", num);
        obj.put("isOpen", 0);
        obj.put("name", null);
        return obj;
    }

    /**
     * 创建帮派
     */
    public result create(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String captain = user.name;
        String gangsName = j.getString("gangsName");
        if (strUtils.isNull(gangsName) || gangsName.length() > 6) {
            return new result(0);
        }
        //是否过冷却8小时
        if (startBef.logService.isEnoughLeaveBpTime(captain, con) == 0) {
            return new result(200, -1);
        }
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        if (dao.selectGangsByName(gangsName, captain).size() > 0) {
            //帮派名重复或者已经有帮派了
            return new result(200, 0);
        }
        //是否已经在其他帮派
        if (dao.selectGangsMembers(null, captain).size() > 0) {
            return new result(200, 0);
        }
        //扣除创建帮派的资金
        int isPay = startBef.manService.saveMoney(1, -20000L, captain, con);
        if (isPay == 0) {//不足以支付
            return new result(0);
        }
        //创建帮派
        String Id = strUtils.getId();
        dao.insertGangs(Id, gangsName, captain);
        dao.insertGangsMembers(Id, captain, "0");
        //人物msg帮派名
        JSONObject bp = new JSONObject();
        bp.put("Id", Id);//帮派Id
        bp.put("name", gangsName);//帮派名
        updateManBP(bp, captain, con);
        //帮派申请表
        dao.insertGangsReq(Id);
        //帮派活动表
        dao.insertGangsActivity(Id);
        //帮派活动缓存的一些值
        dao.insertGangsV(Id);
        //帮派boss
        dao.insertGangsBoss(Id);
        //帮派建设度
        dao.addGangsBuild("0", "0", "0", "0", "0", Id);
        //宴会活动
        dao.addGangsYanhui("10", "[]", Id);
        //创建个人活动次数
        List<JSONObject> personAcTimes = dao.selectGangsAcTimes(captain);
        if (personAcTimes.size() == 0) {
            dao.addGangsAcTimes("0", "0", "0", "0", captain);
        }
        user.msg.put("bpId", Id);
        startBef.chatService.putSysMsg("玩家[" + captain + "]建立了帮派[" + gangsName + "]，从此江湖上又将掀起一番腥风血雨！");
        return new result(200, bp);
    }

    /**
     * 获取一个封装好职位的成员
     */
    private JSONObject getMemberObj(String name, Integer job) {
        JSONObject obj = new JSONObject();
        obj.put("name", name);
        //0帮主 1副帮主 2左护法 3右护法 4精英 5普通
        obj.put("job", job);
        //当前帮派的贡献度
        obj.put("bg", 0);
        return obj;
    }

    /**
     * 更新人物帮派信息
     */
    public void updateManBP(JSONObject bp, String name, DefaultSqlSession con) {
        JSONObject msg = new JSONObject();
        msg.put("bp", bp);
        startBef.manService.saveMsg(name, msg, con);
    }

    /**
     * 申请入帮
     */
    public result reqInto(JSONObject j,
                          @paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String reqName = user.name;
        String Id = j.getString("Id");
        if (startBef.logService.isEnoughLeaveBpTime(reqName, con) == 0) {
            return new result(200, -1);
        }
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> arr = dao.selectGangsReq(Id);
        JSONArray list = arr.get(0).getJSONArray("req");
        for (Object o : list) {
            JSONObject obj = (JSONObject) o;
            //已经申请过了
            if (obj.getString("name").equals(reqName)) {
                return new result(200, 0);
            }
        }
        JSONObject one = new JSONObject();
        one.put("name", reqName);
        one.put("created", strUtils.getTime());
        list.add(one);
        dao.updateGangsReq(JSON.toJSONString(list), Id);
        //通知帮主
        String captain = dao.selectGangs(Id).get(0).getString("captain");
        ChannelSupervise.noticeClientByName(reqName + "申请入帮", captain, "794");
        return new result(200, 1);
    }

    /**
     * 查看帮派列表
     */
    public result viewList(JSONObject j,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        //从1开始
        int pageNum = j.getInteger("pageNum");
        int pageSum = 10;
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = dao.selectGangsLimit((pageNum - 1) * pageSum + 0L, pageSum + 0L);
        //统计每个帮派的人数
        for (JSONObject l : list) {
            int num = dao.selectGangsMembersSum(l.getString("Id")).get(0).getInteger("n");
            l.put("num", num);
            l.put("sum", getSumByLv(l.getInteger("lever")));
        }
        int total = dao.countGangs().get(0).getInteger("total");
        int totalPage = total % pageSum == 0 ? (total / pageSum) : (total / pageSum + 1);
        JSONObject page = new JSONObject();
        page.put("list", list);
        page.put("totalPage", totalPage);
        return new result(200, page);
    }

    /**
     * 获取帮派成员的总帮贡
     */
    public int getBpMemberZongBg(String name, DefaultSqlSession con) {
        user u = staticCollection.getUserByName(name);
        String bpId = u.msg.getString("bpId");
        if (bpId == null) return 0;
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = gangsMapper.selectGangsMembers(null, name);
        if (list.size() >= 0) return list.get(0).getInteger("bg");
        return 0;
    }

    public JSONObject getBpBaseMsg(user user, DefaultSqlSession con) {
        String bpId = user.msg.getString("bpId");
        if (bpId == null) return null;
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = gangsMapper.selectGangs(bpId);
        if (list.size() == 0) return null;
        return list.get(0);
    }

    /**
     * 获取帮派信息
     */
    public result getBpMsg(@paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        String bpId = user.msg.getString("bpId");
        if (bpId == null) {
            return new result(0);
        }
        //帮派基本\活动信息
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> bps = gangsMapper.selectGangs(bpId);
        if (bps.size() == 0) return new result(0);
        JSONObject bp = bps.get(0);
        List<JSONObject> list = gangsMapper.selectGangsMembersDayBg(bpId);
        //统计今日总贡献度
        int dayBg = 0;
        for (int i = 0; i < list.size(); i++) {
            dayBg += list.get(i).getInteger("dayBg");
        }
        int num = list.size();
        bp.put("num", num);
        bp.put("dayBg", dayBg);
        return new result(200, bp);
    }

    /**
     * 根据帮派等级来计算总人数
     */
    private int getSumByLv(int lv) {
        int sum = 30;
        if (lv == 1) sum = 30;
        else if (lv == 2) sum = 35;
        else if (lv == 3) sum = 40;
        else if (lv == 4) sum = 45;
        else if (lv == 5) sum = 50;
        else if (lv == 6) sum = 60;
        return sum;
    }

    /**
     * 由帮派名获取帮派信息
     */
    public JSONObject getGangsMsgByName(String name, DefaultSqlSession con) {
        String Id = getBPIdByName(name, con);
        if (Id == null) {
            return null;
        }
        //帮派基本\活动信息
        gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
        return gangsMapper.selectGangsActivityAndV(Id).get(0);
    }

    /**
     * 获取帮派id
     */
    public String getBPIdByName(String name, DefaultSqlSession con) {
        JSONObject msg = startBef.manService.getMsgData(name, con);
        if (msg.getString("bp").equals("")) {
            return null;
        }
        return msg.getJSONObject("bp").getString("Id");
    }


}
