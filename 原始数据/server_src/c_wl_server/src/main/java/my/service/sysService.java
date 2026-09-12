package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import com.sun.management.OperatingSystemMXBean;
import my.anno.paramsAnno;
import my.dao.*;
import my.data.equipData;
import my.db.mybatisConfig;
import my.fightUtils.fightUtils;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.startBef;
import my.utils.*;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.io.File;
import java.lang.management.ManagementFactory;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.function.Function;

import static my.utils.staticCollection.*;

public class sysService {

    public result perCzRk(String secret, String playerName, int gold) {
        if (!"iloveu".equals(secret) || strUtils.isNull(playerName)) {
            return new result(0);
        }
        Function<DefaultSqlSession, Object> fn = (con) -> {
            JSONArray rewards = rewardUtils.getGoldReward(gold);
            startBef.rewardService.saveRewards(rewards, playerName, con);
            ChannelSupervise.noticeClientByName(rewards, playerName, "10000");
            return null;
        };
        mybatisConfig.putTask(fn);
        return new result(200, 1);
    }

    /**
     * 获取系统信息
     */
    public JSONObject getOsMsg(String secret) {
        if (!"iloveu".equals(secret)) {
            return new JSONObject();
        }
        JSONObject osMsg = new JSONObject();
        Runtime runtime = Runtime.getRuntime();
        OperatingSystemMXBean osmxb = (OperatingSystemMXBean) ManagementFactory.getOperatingSystemMXBean();
        osMsg.put("name", System.getenv().get("COMPUTERNAME"));
        //osMsg.put("ip", InetAddress.getLocalHost().getHostAddress());
        osMsg.put("os.name", System.getProperty("os.name"));
        osMsg.put("java.version", System.getProperty("java.version"));
        osMsg.put("jvmTotal", runtime.totalMemory());
        osMsg.put("jvmFree", runtime.freeMemory());
        osMsg.put("startTime", ManagementFactory.getRuntimeMXBean().getStartTime());
        osMsg.put("upTime", ManagementFactory.getRuntimeMXBean().getUptime());
        osMsg.put("osTotal", osmxb.getTotalPhysicalMemorySize());
        osMsg.put("osFree", osmxb.getFreePhysicalMemorySize());
        return osMsg;
    }


    /**
     * 带邮箱的注册
     * 匹配验证码
     */
    public result matchCode(JSONObject j,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        if (j.getString("username") == null || codes.get(j.getString("username")) == null) {
            return new result(200, 0);
        }
        JSONObject code = codes.get(j.getString("username"));
        if (!code.getString("code").equals(j.getString("code"))) {
            code.put("error", code.getInteger("error") + 1);
            //5次匹配不对则销毁
            if (code.getInteger("error") >= 5) {
                codes.remove(j.getString("username"));
            }
            return new result(200, 0);
        }
        if (code.getString("username") != null &&
                code.getString("password") != null) {
            //注册
            startBef.loginService.isExist(code.getString("username"),
                    code.getString("password"),
                    code.getString("email"), con);
        } else {
            //绑定邮箱
            startBef.loginService.bindEmail(code.getString("email"), code.getString("username"), con);
        }
        codes.remove(code.getString("username"));
        return new result(200, 1);
    }

    /**
     * 获取验证码
     */
    public result getCode(JSONObject j,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        if (strUtils.isNull(j.getString("username")) ||
                strUtils.isNull(j.getString("password")) ||
                strUtils.isNull(j.getString("email"))) {
            return new result(200, 0);
        }
        //已经存在code
        if (codes.get(j.getString("username")) != null) {
            return new result(200, 0);
        }
        JSONObject obj = null;

        //该账号是否已经绑定过了
        int isBind = startBef.loginService.isBindEmail(j.getString("username"), con);
        if (isBind == 1) {//绑过
            return new result(200, 4);
        } else if (isBind == 2) {//用户未注册
            obj = new JSONObject();
            //缓存账号密码，验证成功后进行注册
            obj.put("username", j.getString("username"));
            obj.put("password", j.getString("password"));
        } else {//未绑定过
            //账号密码匹配
            if (startBef.loginService.isSame(j, con) == 0) {
                return new result(200, 2);
            }
            obj = new JSONObject();
        }
        //一个邮箱最多只能绑3个账号
        if (startBef.loginService.countEmailNum(j.getString("email"), con) >= 3) {
            return new result(200, 3);
        }
        String code = emailUtils.sendCode(j.getString("email"));
        obj.put("created", strUtils.getTime());
        obj.put("code", code);
        obj.put("error", 0);
        obj.put("email", j.getString("email"));
        codes.put(j.getString("username"), obj);
        return new result(200, 1);
    }

    /**
     * 定时移除code\限制的ip、同设备请求
     */
    public void removeCode() {
        staticCollection.putTask(() -> {
            try {
                long now = strUtils.getTime();
                //验证码过期
                for (String key : codes.keySet()) {
                    try {
                        if (key != null && codes.get(key) != null && now - codes.get(key).getLong("created") > 5 * 60 * 1000) {
                            codes.remove(key);
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
                //授权过期未确认
                for (String username : staticCollection.authMap.keySet()) {
                    try {
                        //大于1分钟未确认的就销毁
                        if (username != null &&
                                now - staticCollection.authMap.get(username).created > 1000 * 60) {
                            staticCollection.authMap.remove(username);
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
                //限制的ip
                for (String ip : ipMap.keySet()) {
                    JSONObject obj = ipMap.get(ip);
                    //距离上次请求大于30s的移除
                    if (now - obj.getLong("time") > 30000) {
                        ipMap.remove(ip);
                    }
                }
                //相同设备请求
                for (String k : sameReqMap.keySet()) {
                    //要求200毫秒内不允许出现同设备同请求
                    if (now - sameReqMap.get(k) > 1000) {
                        sameReqMap.remove(k);
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }, 16, 16, TimeUnit.SECONDS);
    }

    public void exportBPData() {
        SqlSession con = null;
        try {
            con = mybatisConfig.getSqlSession();
            gangsMapper gangsMapper = mybatisConfig.getMapper(con, gangsMapper.class);
            List<JSONObject> list = gangsMapper.selectAllGangs();
            for (JSONObject l : list) {
                String id = l.getString("Id");
                JSONArray members = l.getJSONArray("members");
                //插入新表
                for (Object m : members) {
                    JSONObject a = (JSONObject) m;
                    if (a.get("bg") == null) a.put("bg", 0);
                    gangsMapper.insertGangsMembers(id, a.getString("name"), a.getString("job"));
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
     * 将字段添加到人物的msg中
     */
    public void addZdToManMsg() {
        SqlSession con = null;
        try {
            con = mybatisConfig.getSqlSession();
            jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
            roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
            int num = roleMapper.count().get(0).getInteger("num");
            int pageSize = num % 10 > 0 ? num / 10 + 1 : num / 10;
            List<JSONObject> ls = new ArrayList<>();
            for (long i = 0; i < pageSize; i++) {
                ls.addAll(jsonMapper.selectMsgLimit(i * 10, 10L));
                for (JSONObject l : ls) {
                    JSONObject msg = l.getJSONObject("msg");
                    boolean b = false;
                    if (msg.get("jungong") == null) {
                        //军功字段
                        msg.put("jungong", 0);
                        b = true;
                    }
                    if (msg.get("cbjf") == null) {
                        //传壁积分
                        msg.put("cbjf", 0);
                        b = true;
                    }
                    if (msg.get("swdj") == null) {
                        //声望等级字段
                        JSONObject swdj = new JSONObject();
                        swdj.put("lv", 0);
                        swdj.put("exp", 0);
                        msg.put("swdj", swdj);
                        b = true;
                    }
                    if (msg.get("xrmf") == null) {
                        //仙人秘法字段
                        JSONObject xrmf = new JSONObject();
                        xrmf.put("xrLv", 0);
                        xrmf.put("xfLv", 0);
                        msg.put("xrmf", xrmf);
                        b = true;
                    }
                    if (msg.get("xld") == null) {
                        msg.put("xld", 0);
                        b = true;
                    }
                    if (msg.get("bb") == null) {
                        msg.put("bb", 0);
                        b = true;
                    }
                    if (msg.get("ldjf") == null) {
                        msg.put("ldjf", 0);
                        b = true;
                    }
                    if (msg.get("realmLv") == null) {
                        msg.put("realmLv", 0);
                        b = true;
                    }

                    if (b) {
                        jsonMapper.updateMsgByName(JSON.toJSONString(msg), l.getString("name"));
                    }
                }
                ls.clear();
                mybatisConfig.commit(con);
            }
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    private static long befGoldSum = 0;
    private static long goldSum = 0;
    private static long befTaleSum = 0;
    private static long taleSum = 0;

    public result getGoldMsg(@paramsAnno(key = "user") user u) {
        if (!u.name.equals("梅仁义")) return new result(0);
        countMoney(false);
        JSONObject res = new JSONObject();
        res.put("befGoldSum", befGoldSum);
        res.put("goldSum", goldSum);
        res.put("befTaleSum", befTaleSum);
        res.put("taleSum", taleSum);
        return new result(200, res);
    }

    /**
     * 获取元宝变动情况
     */
    public result getGoldOrder(JSONObject j,
                               @paramsAnno(key = "user") user u,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        if (!u.name.equals("梅仁义")) return new result(0);
        int type = j.getInteger("type");
        int pageNum = j.getInteger("pageNum");
        jsonMapper jm = mybatisConfig.getMapper(con, jsonMapper.class);
        long n = jm.countMoneyCountSum(type).get(0).getLong("n");
        long total = n % 10 == 0 ? (n / 10) : (n / 10 + 1);
        if (pageNum > total) return new result(0);
        List<JSONObject> list = null;
        if (type == 0) {
            list = jm.selectMoneyCountGoldByPage((pageNum - 1) * 10L, 10L);
        } else {
            list = jm.selectMoneyCountTaleByPage((pageNum - 1) * 10L, 10L);
        }
        JSONObject res = new JSONObject();
        res.put("list", list);
        res.put("totalPage", total);
        return new result(200, res);
    }

    /**
     * 统计金票、银票、小票、元宝
     */
    public boolean countMoney(boolean isStart) {
        String path = null;
        if (systemUtils.isWindows()) {
            path = "C:\\Users\\13245\\Desktop\\aaa.txt";
        } else {
            path = "/home/wl/aaa.txt";
        }
        fileUtils.delFile(new File(path));
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            jsonMapper jm = mybatisConfig.getMapper(con, jsonMapper.class);
            long num = jm.countPackageNum().get(0).getLong("n");
            long pageSize = num % 10 > 0 ? (num / 10 + 1) : (num / 10);
            System.err.println("总人数:" + num + " 分页：" + pageSize);
            long sumGold = 0;
            long sumTale = 0;
            StringBuilder sb = new StringBuilder();
            List<JSONObject> ls = new ArrayList<>();
            for (long i = 0; i < pageSize; i++) {
                ls.addAll(jm.selectPackageViewByPage(i * 10L, 10L));
                for (int j = 0; j < ls.size(); j++) {
                    String name = ls.get(j).getString("name");
                    JSONArray pack = ls.get(j).getJSONArray("package");
                    JSONObject msg = ls.get(j).getJSONObject("msg");
                    sb.append("[" + name + "]");
                    long jp = 0, zp = 0, xp = 0;
                    for (Object o : pack) {
                        JSONObject a = (JSONObject) o;
                        if (a.getString("key").equals("10000000")) {
                            jp = a.getLong("num");
                        } else if (a.getString("key").equals("10000001")) {
                            zp = a.getLong("num");
                        } else if (a.getString("key").equals("10000002")) {
                            xp = a.getLong("num");
                        }
                        if (a.getLong("num") > 1000) {
                            if (a.getString("key").equals("10000200") &&
                                    a.getString("key").equals("10000199") &&
                                    a.getString("key").equals("10000188"))
                                System.err.println(name + "->" + a.getString("key"));
                        }
                    }
                    sb.append(" 金票：" + jp + " 银票：" + zp + " 小票：" + xp);
                    long gold = msg.getLong("gold");
                    sb.append(" 元宝：" + gold);
                    sb.append(" 合计：" + (jp * 1000 + zp * 500 + xp * 100 + gold));
                    long tale = msg.getLong("tale");
                    sb.append(" ****银两：" + tale + "\n");
                    /*if(true){
                        sb.append("关联角色：");
                        Set<String> sets=new HashSet<>();
                        roleMapper rm = mybatisConfig.getMapper(con, roleMapper.class);
                        JSONObject one= rm.getRoleAndUser(name).get(0);
                        JSONArray allowed_ip=one.getJSONArray("allowed_ip");
                        for(Object a: allowed_ip){
                            List<JSONObject> rlList=rm.selectRoleByIp("%"+a+"%",null);
                            for(JSONObject rl:rlList){
                                sets.add(rl.getString("name"));
                            }
                        }
                        List<JSONObject> rlList0=rm.selectRoleByIp(null,one.getString("email"));
                        for(JSONObject rl:rlList0) {
                            sets.add(rl.getString("name"));
                        }
                        for (String s:sets){
                            sb.append(s+",");
                        }
                        sb.append("\n============\n");
                    }*/
                    if (jp * 1000 + zp * 500 + xp * 100 + gold == 0) {
                        sb.delete(0, sb.length());
                        continue;
                    }
                    if (jm.selectMoneyCount(name).size() == 0) {
                        jm.addMoneyCount(name, "0", "0", "0", "0");
                    }
                    if (isStart) {
                        jm.updateMoneyCount(name, gold + "", gold + "", tale + "", tale + "");
                    } else {
                        jm.updateMoneyCount(name, null, gold + "", null, tale + "");
                    }
                    mybatisConfig.commit(con);
                    sumGold += (jp * 1000 + zp * 500 + xp * 100 + gold);
                    sumTale += tale;
                    fileUtils.writeFile(sb.toString(), path, true);
                    sb.delete(0, sb.length());
                }
                ls.clear();
            }
            sb.append(" 所有元宝合计：" + sumGold);
            sb.append(" 所有银两合计：" + sumTale);
            fileUtils.writeFile(sb.toString(), path, true);
            sb.delete(0, sb.length());
            goldSum = sumGold;
            taleSum = sumTale;
            if (isStart) {
                befGoldSum = sumGold;
                befTaleSum = sumTale;
                String path1 = null;
                if (systemUtils.isWindows()) {
                    path1 = "C:\\Users\\13245\\Desktop\\bbb.txt";
                } else {
                    path1 = "/home/wl/bbb.txt";
                }
                fileUtils.delFile(new File(path1));
                Files.copy(Paths.get(path), Paths.get(path1));
            }
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            System.err.println("统计完成完成！");
            mybatisConfig.close(con);
        }
        return false;
    }

    /**
     * 启动时初始化一些数据
     */
    public boolean startInitData() {
        System.err.println("开始初始化数据");
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
            int num = roleMapper.count().get(0).getInteger("num");
            int pageSize = num % 10 > 0 ? (num / 10 + 1) : (num / 10);
            System.err.println("总人数:" + num + " 分页：" + pageSize);
            List<JSONObject> ls = new ArrayList<>();
            for (long i = 0; i < pageSize; i++) {
                ls.addAll(roleMapper.getRolesByPage(i * 10L, 10L));
                StringBuilder sb = new StringBuilder();
                for (JSONObject l : ls) {
                    sb.append(l.getString("name") + ",");
                }
                System.err.println(sb);
                /*Iterator<JSONObject> js = ls.iterator();
                while (js.hasNext()) {
                    JSONObject a = js.next();
                    String name = a.getString("name");
                    *//*String md = a.getString("model").split("_")[0] + "_nan";
                    roleMapper.updateModel(md, a.getString("name"));*//*
                    //将装备的随机属性字段变成数组（背包、装备页）
                    JSONArray list = startBef.packageService.getGoods(name, con);
                    for (int p = 0; p < list.size(); p++) {
                        JSONObject equip = list.getJSONObject(p);
                        if (!equipData.isEquip(equip.getString("key")) ||
                                equip.get("randomAttr") == null) continue;
                        equipData.putRandomAttr(equip);
                    }
                    startBef.packageService.savePackage(list, name, con);

                    JSONObject epObj = startBef.manService.getEquipData(name, con);
                    for (String part : epObj.keySet()) {
                        if (strUtils.isNull(epObj.getString(part))) continue;
                        JSONObject equip = epObj.getJSONObject(part);
                        if (!equipData.isEquip(equip.getString("key")) ||
                                equip.get("randomAttr") == null) continue;
                        equipData.putRandomAttr(equip);
                    }
                    startBef.manService.saveEquip(name, epObj, con);
                }*/
                ls.clear();
                mybatisConfig.commit(con);
            }


            System.err.println("初始化数据完成");
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
        return false;
    }

    public boolean startInitData1() {
        System.err.println("开始初始化数据");
        DefaultSqlSession con = null;

        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            //==========删除6天未登录的玩家================
            long td = 1000 * 60 * 60 * 24 * 6L;
            userMapper userMapper = mybatisConfig.getMapper(con, userMapper.class);
            jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
            roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
            logMapper logMapper = mybatisConfig.getMapper(con, logMapper.class);
            //todo 删除不在xq_role中的数据

            long old = strUtils.getTime();
            //分页删
            List<JSONObject> ls = new ArrayList<>();
            int num = userMapper.getUserNum().get(0).getInteger("num");
            int pageSize = num % 10 > 0 ? num / 10 + 1 : num / 10;
            for (long i = 0; i < pageSize; i++) {
                ls.addAll(userMapper.getUserLimit(i * 10, 10L));
                for (JSONObject l : ls) {
                    //System.err.println(new Date().getTime() - l.getLong("online"));
                    boolean isDel = false;
                    if (l.getLong("online") != null && (((new Date().getTime() - l.getLong("online")) > td)
                            && l.getInteger("lever") < 60)) {
                        String name = l.getString("name");
                        //删除用户
                        userMapper.delUser(l.getString("username"));
                        //删除角色
                        roleMapper.delRole(name);
                        //删除任务
                        jsonMapper.delTaskSubmit(name);

                        jsonMapper.delTask(name);

                        jsonMapper.delStatus(name);

                        jsonMapper.delSkill(name);

                        jsonMapper.delProp(name);

                        jsonMapper.delPet(name);

                        jsonMapper.delPackage(name);

                        jsonMapper.delMsg(name);

                        jsonMapper.delEquip(name);

                        jsonMapper.delEmail(name);

                        roleMapper.delFriend(name);
                        isDel = true;
                    }
                    /*if(!isDel){
                        //把小号的道具清理
                        if(l.getInteger("lever") < 60){
                            String name=l.getString("name");
                            //{"ch":"","stu2":"","stu3":"","stu1":"","bp":"","tale":31000,"gold":0,"djph":"100名以外","sf":"平民","teacher":"","yp":74390,"wxz":0,"jf":0,"jmPoint":0,"zy":"天音"}
                            jsonMapper.updatePackageByName(JSON.toJSONString(new JSONArray()),name);
                            JSONObject msg=jsonMapper.selectMsg(name).get(0).getJSONObject("msg");
                            msg.put("tale",0);
                            msg.put("gold",0);
                            jsonMapper.updateMsgByName(JSON.toJSONString(msg),name);
                            String eq="{\"jiaob\":\"\",\"sz\":\"\",\"jb\":\"\",\"yb\":\"\",\"wq\":\"\",\"xb\":\"\",\"wb\":\"\",\"bjb\":\"\",\"tuib\":\"\",\"fb\":\"\",\"tb\":\"\",\"hf\":\"\"}";
                            jsonMapper.updateEquip(eq,name);
                        }
                    }*/
                }
                ls.clear();
                mybatisConfig.commit(con);
            }
            ls.clear();
            System.err.println(strUtils.getTime() - old + " 删除6天不在线的用户完成");
            old = strUtils.getTime();
            //fixme:注意要的是xq_role的数量

            //获取删除后的数量
            num = roleMapper.count().get(0).getInteger("num");
            pageSize = num % 10 > 0 ? num / 10 + 1 : num / 10;
            //==========更改人物模型model===========
            /*for (long i = 0; i < pageSize; i++) {
                ls.addAll(roleMapper.getRolesByPage(i * 10L, 10L));
                Iterator<JSONObject> js = ls.iterator();
                while (js.hasNext()) {
                    JSONObject a = js.next();
                    JSONArray models=a.getJSONArray("models");
                    if(models.size()==0){
                        String m=a.getString("model").split("_")[0];
                        models.add(m+"_01");
                        models.add(m+"_02");
                        roleMapper.updateModels(JSON.toJSONString(models),a.getString("name"));
                    }
                    *//*if(a.getString("model").contains("_")){
                        continue;
                    }
                    String model=a.getString("model")+"_02";
                    roleMapper.updateModel(model,a.getString("name"));*//*
                }
                ls.clear();
                mybatisConfig.commit(con);
            }
            ls.clear();
            System.err.println(strUtils.getTime() - old + " 修改人物模型完成");*/
            //==========检验装备字段缺失============
            for (long i = 0; i < pageSize; i++) {
                ls.addAll(jsonMapper.selectEquipByPage(i * 10, 10L));
                Iterator<JSONObject> js = ls.iterator();
                while (js.hasNext()) {
                    JSONObject a = js.next();
                    JSONObject equips = a.getJSONObject("equip");
                    boolean b = false;
                    if (equips.get("gf") == null) {
                        equips.put("gf", "");
                        b = true;
                    }
                    /*if(!equips.get("gf").equals("")){
                        JSONObject gf=equips.getJSONObject("gf");
                        JSONObject forging=gf.getJSONObject("forging");
                        if(forging.getInteger("lv")>0){
                            forging.put("lv",0);
                            gf.remove("inlay");
                            gf.remove("potential");
                            b=true;
                        }
                    }
                    if(!equips.get("fb").equals("")){
                        JSONObject fb=equips.getJSONObject("fb");
                        JSONObject forging=fb.getJSONObject("forging");
                        if(forging.getInteger("lv")>0){
                            forging.put("lv",0);
                            fb.remove("inlay");
                            fb.remove("potential");
                            b=true;
                        }

                    }
                    if(!equips.get("hf").equals("")){
                        JSONObject hf=equips.getJSONObject("hf");
                        JSONObject forging=hf.getJSONObject("forging");
                        if(forging.getInteger("lv")>0){
                            forging.put("lv",0);
                            hf.remove("inlay");
                            hf.remove("potential");
                            b=true;
                        }
                    }*/
                    if (b) {
                        jsonMapper.updateEquip(JSON.toJSONString(equips), a.getString("name"));
                    }
                    //System.err.println("检验格式："+a.getString("name"));
                }
                ls.clear();
                mybatisConfig.commit(con);
            }
            ls.clear();
            System.err.println(strUtils.getTime() - old + " 检验装备字段缺失完成");
            //==========检验背包中道具格式是否有出错===============
            for (long i = 0; i < pageSize; i++) {
                ls.addAll(jsonMapper.selectPackageLimit(i * 10, 10L));
                Iterator<JSONObject> js = ls.iterator();
                while (js.hasNext()) {
                    JSONObject a = js.next();
                    JSONArray pas = a.getJSONArray("package");
                    Iterator<Object> ps = pas.iterator();
                    boolean isChange = false;
                    while (ps.hasNext()) {
                        JSONObject b = (JSONObject) ps.next();
                        //去除5级宝石
                        /*if (b.getInteger("key") >= 4040 &&
                                b.getInteger("key") < 4050) {
                            System.err.println(a.getString("name") + "/" + b.getInteger("key"));
                            ps.remove();
                            isChange = true;
                            continue;
                        }*/

                        //删除背包中龙头金票、银票、小票、魔龙印
                    /*if (b.getString("key").equals("1003")||
                            b.getString("key").equals("3046")) {
                        ps.remove();
                        continue;
                    }*/
                    /*if ((b.getString("key").equals("1000") && b.getInteger("num") > 5) ||
                            (b.getString("key").equals("1001") && b.getInteger("num") > 50) ||
                            (b.getString("key").equals("1002") && b.getInteger("num") > 500)) {
                        ps.remove();
                        continue;
                    }*/
                        //fixme 清理多余称号
                        /*if (b.getString("key").equals("1079") ||
                                b.getString("key").equals("1080")) {
                            ps.remove();
                            isChange = true;
                            continue;
                        }*/
                        /*if(b.get("forging")!=null&&b.getInteger("num")>1){
                            System.out.println(a.getString("name")+"=>"+b.getString("key")+"/"+b.getInteger("num"));
                        }*/
                        //去掉错误项
                        if (b.getInteger("num") < 1 || b.get("pos") == null || b.get("key") == null) {
                            ps.remove();
                            isChange = true;
                            continue;
                        }
                        //给装备附加锻造字段
                        if (b.get("forging") == null &&
                                !b.getString("key").equals("2002") &&
                                b.get("randomAttr") != null) {
                            JSONObject forging = new JSONObject();
                            forging.put("lv", 0);
                            b.put("forging", forging);
                            JSONObject inlay = new JSONObject();
                            inlay.put("num", 0);
                            inlay.put("list", new JSONArray());
                            b.put("inlay", inlay);
                            JSONObject potential = new JSONObject();
                            potential.put("num", 0);
                            potential.put("max", 0);
                            b.put("potential", potential);
                            isChange = true;
                        }
                        //fixme 清空护符、法宝、功法的锻造等级
                        /*if(b.getInteger("key")>=2500&&
                                b.getInteger("key")<2800){
                            JSONObject forging = b.getJSONObject("forging");
                            forging.put("lv", 0);
                            b.put("forging", forging);
                            b.remove("inlay");
                            b.remove("potential");
                            isChange = true;
                        }*/
                    }
                    if (isChange) {
                        jsonMapper.updatePackageByName(JSON.toJSONString(pas), null, null, null, a.getString("name"));
                    }
                    //System.err.println("检验格式："+a.getString("name"));
                }
                ls.clear();
                mybatisConfig.commit(con);
            }
            ls.clear();
            System.err.println(strUtils.getTime() - old + " 背包数据错误检测完成");
            old = strUtils.getTime();
            //=============检验人物信息是否有格式错误===============
            for (long i = 0; i < pageSize; i++) {
                ls.addAll(jsonMapper.selectMsgLimit(i * 10, 10L));
                for (JSONObject l : ls) {
                    JSONObject msg = l.getJSONObject("msg");
                    boolean b = false;
                    //元宝归0
                /*if (msg.get("gold") != null && msg.getInteger("gold") > 5000) {
                    msg.put("gold", 5000);
                    b = true;
                }*/
                    //银两
                /*if (msg.get("tale") != null && msg.getInteger("tale") > 10000000) {
                    msg.put("tale", 10000000);
                    b = true;
                }*/
                    if (msg.get("gold") == null || msg.getInteger("gold") < 0) {
                        msg.put("gold", 0);
                        b = true;
                    }

                    if (msg.get("tale") == null || msg.getInteger("tale") < 0) {
                        msg.put("tale", 0);
                        b = true;
                    }
                    //fixme
            /*if(msg.get("tale")!=null&&msg.getInteger("tale")>50000){
                //设置银两50000
                msg.put("tale", 50000);
                b=true;
            }*/
                    if (msg.get("yp") == null || msg.getInteger("yp") < 0) {
                        msg.put("yp", 0);
                        b = true;
                    }
                    if (msg.get("jf") == null || msg.getInteger("jf") < 0) {
                        msg.put("jf", 0);
                        b = true;
                    }
                    if (msg.get("jmPoint") == null) {
                        msg.put("jmPoint", 0);
                        b = true;
                    }
                    //善恶值
                    if (msg.get("sez") == null) {
                        msg.put("sez", 5);
                        b = true;
                    }
                    //亲和度
                    if (msg.get("qhd") == null) {
                        msg.put("qhd", 0);
                        b = true;
                    }
                    //帮贡
                    if (msg.get("bg") == null) {
                        msg.put("bg", 0);
                        b = true;
                    }
                    //翅膀
                    if (msg.get("wings") == null) {
                        msg.put("wings", "");
                        b = true;
                    }

                    /*if (!msg.get("bp").equals("")) {
                        msg.put("bp", "");
                        b = true;
                    }*/
                    if (b) {
                        jsonMapper.updateMsgByName(JSON.toJSONString(msg), l.getString("name"));
                    }
                }
                ls.clear();
                mybatisConfig.commit(con);
            }

            ls.clear();
            System.err.println(strUtils.getTime() - old + " 人物数据错误检测完成");
            old = strUtils.getTime();
            //=============检测宠物最大血量错误===============
            for (long i = 0; i < pageSize; i++) {
                ls.addAll(jsonMapper.selectPetLimit(i * 10, 10L));
                for (JSONObject a : ls) {
                    JSONArray list = a.getJSONArray("pet");
                    boolean isChange = false;
                    for (Object l : list) {
                        JSONObject item = (JSONObject) l;
                        //补齐缺失字段
                        if (item.get("eatPet") == null) {
                            item.put("eatPet", 0);
                            isChange = true;
                        }
                        if (item.get("growValue") == null) {
                            item.put("growValue", 0);
                            isChange = true;
                        }
                        if (item.get("growLv") == null) {
                            item.put("growLv", 0);
                            isChange = true;
                        }
                        if (item.get("growBreachLv") == null) {
                            item.put("growBreachLv", 0);
                            isChange = true;
                        }

                        //处理乱码
                        if (item.getString("nickName").contains("?")) {
                            item.put("nickName", "犬夜叉");
                            isChange = true;
                        }
                        JSONObject role = new JSONObject();
                        role.put("lever", item.get("lever"));
                        role.put("attr", item.get("attr"));
                        role.put("baseProp", item.get("baseProp"));
                        role.put("qualityValue", item.get("qualityValue"));
                        role.put("growLv", item.getInteger("growLv"));
                        role.put("danAttr", item.get("danAttr"));
                        role.put("xrmf", startBef.manService.getXrmf(a.getString("name"), con));
                        role.put("petEquip", startBef.packageService.getPetEquip(a.getString("name"), con));
                        JSONObject obj = startBef.petService.countProp(role);
                        JSONObject attr = item.getJSONObject("attr");
                        JSONObject prop = attr.getJSONObject("prop");
                        //System.err.println(prop.getInteger("xue")+"   "+obj.getInteger("max_xue"));
                        if (prop.getInteger("xue") > obj.getInteger("max_xue")) {
                            prop.put("xue", obj.getInteger("max_xue"));
                            prop.put("lan", obj.getInteger("max_lan"));
                            isChange = true;
                            //item.put("attr",attr);
                            //loggerUtils.info(a.getString("name")+" "+prop.getInteger("xue")+"   "+obj.getInteger("max_xue"),this.getClass());
                        }
                        //获取等级
                        Integer lv = item.getInteger("lever");
                        //该等级的总点数
                        int sum = (lv - 1) * 5;
                        JSONObject baseProp = item.getJSONObject("baseProp");
                        int pSum = baseProp.getInteger("ll") +
                                baseProp.getInteger("nl") +
                                baseProp.getInteger("zl") +
                                baseProp.getInteger("js") +
                                baseProp.getInteger("mj") - 5 * 5;
                        if (sum != item.getInteger("propPoint") + pSum) {
                            //数据异常
                            item.put("propPoint", sum);
                            JSONObject basePropTemp = item.getJSONObject("baseProp");
                            baseProp.put("ll", 5);
                            baseProp.put("nl", 5);
                            baseProp.put("zl", 5);
                            baseProp.put("js", 5);
                            baseProp.put("mj", 5);
                            item.put("baseProp", basePropTemp);
                            isChange = true;
                        }
                    }
                    if (isChange) {
                        jsonMapper.updatePetByName(JSON.toJSONString(list), a.getString("name"));
                    }
                }
                ls.clear();
                mybatisConfig.commit(con);
            }

            ls.clear();
            System.err.println(strUtils.getTime() - old + " 宠物数据错误检测完成");

            //清理5天前的操作日志
            logMapper.delOpByCreated(strUtils.getTime() - 5 * 24 * 60 * 60 * 1000);
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
            return false;
        } finally {
            mybatisConfig.close(con);
        }
        loggerUtils.info("已完成启动", this.getClass());
        return true;
    }

    /**
     * 检测数据异常
     */
    public JSONObject checkDataException(String secret) {
        if (!"iloveu".equals(secret)) {
            return null;
        }
        if (systemUtils.isWindows()) {
            return null;
        }
        SqlSession con = null;
        try {
            con = mybatisConfig.getSqlSession();
            //每小时发送一次检测报告给我
            userMapper userMapper = mybatisConfig.getMapper(con, userMapper.class);
            jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
            List<JSONObject> ls = new ArrayList<>();
            int num = userMapper.getUserNum().get(0).getInteger("num");
            int pageSize = num % 10 > 0 ? num / 10 + 1 : num / 10;
            StringBuilder sb = new StringBuilder();
            sb.append("============道具=====================\n");
            for (long i = 0; i < pageSize; i++) {
                ls.addAll(jsonMapper.selectPackageLimit(i * 10, 10L));
                Iterator<JSONObject> js = ls.iterator();
                while (js.hasNext()) {
                    JSONObject a = js.next();
                    JSONArray pas = a.getJSONArray("package");
                    Iterator<Object> ps = pas.iterator();
                    while (ps.hasNext()) {
                        JSONObject b = (JSONObject) ps.next();

                        //关键性数据检测数量是否异常
                        //神宠
                        if (b.getString("key").equals("1003") || b.getString("key").equals("1007") ||
                                b.getString("key").equals("1019") || b.getString("key").equals("1020") ||
                                b.getString("key").equals("1021") || b.getString("key").equals("1022")) {
                            if (b.getInteger("num") > 10) {
                                sb.append(a.getString("name") + "/" + b.getInteger("key") + "/（神宠）" + b.getInteger("num") + "\n");
                            }
                        }
                        //金票
                        if (b.getString("key").equals("1000") || b.getString("key").equals("1001") ||
                                b.getString("key").equals("1002")) {
                            if (b.getInteger("num") > 100)
                                sb.append(a.getString("name") + "/" + b.getInteger("key") + "/（金票）" + b.getInteger("num") + "\n");
                        }
                        //兑换道具
                        if (b.getString("key").equals("1034") || b.getString("key").equals("1037") || b.getString("key").equals("1023")) {
                            if (b.getInteger("num") > 500)
                                sb.append(a.getString("name") + "/" + b.getInteger("key") + "/（碎片）" + b.getInteger("num") + "\n");
                        }
                        //仙回
                        if (b.getString("key").equals("3046")) {
                            if (b.getInteger("num") > 10)
                                sb.append(a.getString("name") + "/" + b.getInteger("key") + "/（仙回）" + b.getInteger("num") + "\n");
                        }
                        //修复
                        if (b.getString("key").equals("1013")) {
                            if (b.getInteger("num") > 1000)
                                sb.append(a.getString("name") + "/" + b.getInteger("key") + "/（修复宝石）" + b.getInteger("num") + "\n");
                        }
                        //仙绝
                        if (b.getInteger("key") >= 3500 && b.getInteger("key") < 3522) {
                            if (b.getInteger("num") > 10)
                                sb.append(a.getString("name") + "/" + b.getInteger("key") + "/（仙绝）" + b.getInteger("num") + "\n");
                        }
                    }
                }
                ls.clear();
                mybatisConfig.commit(con);
            }
            ls.clear();
            sb.append("============元宝=====================\n");
            for (long i = 0; i < pageSize; i++) {
                ls.addAll(jsonMapper.selectMsgLimit(i * 10, 10L));
                for (JSONObject l : ls) {
                    JSONObject msg = l.getJSONObject("msg");
                    if (msg.getInteger("gold") != null && msg.getInteger("gold") > 1000 * 1000) {
                        sb.append(l.getString("name") + "/" + msg.getInteger("gold"));
                    }
                    if (msg.getInteger("tale") != null && msg.getInteger("tale") > 100000000) {
                        sb.append(l.getString("name") + "/" + msg.getInteger("tale"));
                    }
                }
                ls.clear();
                mybatisConfig.commit(con);
            }
            ls.clear();
            //emailUtils.sendPort(sb.toString());
            JSONObject msg = new JSONObject();
            msg.put("port", sb.toString());
            //System.err.println(sb);
            sb.delete(0, sb.length());
            mybatisConfig.commit(con);
            return msg;
        } catch (Exception e) {
            mybatisConfig.rollback(con);
            loggerUtils.error("数据检测时错误：" + e.getMessage(), this.getClass());
        } finally {
            mybatisConfig.close(con);
        }
        return null;
    }

    public void checkReStart() {
        int time = 30;
        staticCollection.putTask(() -> {
            OperatingSystemMXBean osmxb = (OperatingSystemMXBean) ManagementFactory.getOperatingSystemMXBean();
            if (osmxb.getFreePhysicalMemorySize() < 1024 * 1024 * 150) {
                systemUtils.doClearCache();
                if (osmxb.getFreePhysicalMemorySize() < 1024 * 1024 * 150) {
                    noticeRestart();
                }
            }
        }, time, time, TimeUnit.SECONDS);
    }

    public void noticeRestart() {
        startBef.chatService.putSysMsg("服务器内存不足，将于1分钟后重启，请玩家下线！");
        staticCollection.putTask(() -> {
            staticCollection.isAllowedReq = false;
            ChannelSupervise.closeAllClient();
            if (systemUtils.isWindows()) {
                return;
            }
            systemUtils.doSh("nohup java -jar " + url + "do_sh.jar &");
        }, 1, TimeUnit.MINUTES);
    }

    public JSONObject someLogger(String secret) {
        if (!"iloveu".equals(secret)) {
            return new JSONObject();
        }
        JSONObject osMsg = new JSONObject();
        String a = "当前剩余的战斗：" + fightUtils.fightMap.size()
                + "当前剩余的buffMap：" + fightUtils.buffMap.size()
                + "当前剩余的orderMap：" + fightUtils.orderMap.size()
                + "当前剩余的roleMap：" + fightUtils.roleMap.size()
                + "当前剩余的monsterMap：" + fightUtils.monsterMap.size()
                + "当前剩余的overTimeOrderMap：" + fightUtils.overTimeOrderMap.size()
                + ";当前剩余队伍：" + staticCollection.teamMap.size()
                + ";当前剩余玩家：" + staticCollection.userMap.size()
                + ";授权：" + staticCollection.authMap.size()

                + ";ip限制名单：" + staticCollection.ipMap.size()
                + ";同ip同路径请求：" + staticCollection.sameReqMap.size()
                + ";正在上传的壁：" + staticCollection.bMap.size()
                + ";聊天：" + staticCollection.chatList0.size() + "/" + staticCollection.chatList1.size()
                + ";大盘投资者：" + staticCollection.dapanPlayer.size()
                + ";期货投资者：" + staticCollection.qihuoPlayer.size()
                + ";地图位置：" + staticCollection.posMap.size()
                + ";竞技场：" + staticCollection.jingjiMap.size()
                + ";验证码：" + staticCollection.codes.size()
                + ";世界boss伤害统计：" + staticCollection.hurtMap.size()
                + ";武状元对战表：" + staticCollection.fightList.size()
                + ";红包列表：" + staticCollection.hongbaoList.size()

                + ";砍价队列：" + staticCollection.cutPriceQue.size()
                + ";砍价商品：" + staticCollection.cutPriceGoodsMap.size()
                //+ ";上架的商品：" + staticCollection.groundingGoodsMap.size()
                + ";抢购商品集：" + staticCollection.goodsMap.size()
                + ";抢购的玩家队列：" + staticCollection.players.size()
                + ";已经推送过的用户：" + staticCollection.pushUser.size();
        /*loggerUtils.info("竞技名单详情：",this.getClass());
        for(String lv:staticCollection.jingjiMap.keySet()){
            loggerUtils.info("等级"+lv+":"+staticCollection.jingjiMap.get(lv),this.getClass());
        }*/
        osMsg.put("cache", a);
        return osMsg;
    }

}
