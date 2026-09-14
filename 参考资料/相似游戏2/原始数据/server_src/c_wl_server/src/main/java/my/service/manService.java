package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.jsonMapper;
import my.dao.roleMapper;
import my.dao.userMapper;
import my.data.equipData;
import my.data.mapData;
import my.data.shenFuData;
import my.data.skillData;
import my.db.mybatisConfig;
import my.fightUtils.fightUtils;
import my.gameUtils.*;
import my.model.*;
import my.startBef;
import my.utils.*;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 玩家相关服务
 */
public class manService {

    /**
     * 上传施法方式
     */
    public result uploadShiFaWay(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int way = j.getInteger("way");
        if (way != 0 && way != 1) return new result(0);
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        if (way == 0) {
            jsonMapper.updateShiFaWay(name, way + "", null, null);
            return new result(200, 1);
        }
        int type = j.getInteger("type");//-1不设置 0人物、1宠物
        int order = j.getInteger("order");//-1不设置 0置顶 1上移 2下移 3末端
        int index = j.getInteger("index");//数组下标
        JSONObject shifa = getShiFaWay(name, con);
        JSONArray sfList = null;
        if (type == 0) sfList = shifa.getJSONArray("role_skls");
        else sfList = shifa.getJSONArray("pet_skls");
        String k = sfList.getString(index);
        sfList.remove(index);
        if (order == 0) {
            sfList.add(0, k);
        } else if (order == 1) {
            sfList.add(index - 1, k);
        } else if (order == 2) {
            sfList.add(index + 1, k);
        } else {
            sfList.add(k);
        }
        if (type == 0) {
            jsonMapper.updateShiFaWay(name, way + "", sfList.toString(), null);
        } else {
            jsonMapper.updateShiFaWay(name, way + "", null, sfList.toString());
        }
        return new result(200, 1);
    }

    /**
     * 更改密码
     */
    public result gbPassword(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (!name.equals("梅仁义")) {
            return new result(0);
        }
        userMapper um = mybatisConfig.getMapper(con, userMapper.class);
        String username = j.getString("username");
        String old = j.getString("old");
        String password = j.getString("password");

        if (strUtils.isNull(username)|| strUtils.isNull(old) || strUtils.isNull(password) ||
                username.length() > 30 || old.length() > 30|| password.length() > 30) {
            return new result(0);
        }

        if (um.match(username, old).size() == 0) {
            return new result(0);
        }

        if (um.updatePassword(username, password))
            return new result(200, 1);
        return new result(0);
    }

    /**
     * 获取施法方式
     */
    public result viewShiFaWay(@paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        return new result(200, getShiFaWay(name, con));
    }

    public JSONObject getShiFaWay(String name, DefaultSqlSession con) {
        boolean isUpdate = false;
        //不存在则初始化一份
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> al = jsonMapper.selectShiFaWayView(name);
        if (al.size() == 0) {
            JSONObject a = new JSONObject();
            a.put("way", 0);
            al.add(a);
            jsonMapper.addShiFaWay(name, "0",
                    JSON.toJSONString(new JSONArray()),
                    JSON.toJSONString(new JSONArray()));
            al = jsonMapper.selectShiFaWayView(name);
            isUpdate = true;
        }
        //选人物的主动技能
        JSONArray list = new JSONArray();
        JSONArray skls = getSkill(name, con);
        for (int i = 0; i < skls.size(); i++) {
            JSONObject a = skls.getJSONObject(i);
            if (!a.containsKey("key")) continue;
            skill skl = skillUtils.getInstance().getSkill(a.getString("key"));
            //选出人物技能中的主动技能
            if (skl != null && skl.triggerType == 0) {
                list.add(skl.key);
            }
        }

        JSONObject shifa = al.get(0);
        shifa.put("role_skls", shifa.getJSONArray("role_skls"));
        shifa.put("pet_skls", shifa.getJSONArray("pet_skls"));
        shifa.remove("name");
        //设置人物的技能
        if (updateShiFaSkls("role_skls", shifa, list)) {
            isUpdate = true;
        }
        //选宠物的技能
        list = new JSONArray();
        int start = 10010178;
        int end = 10010314;
        for (int i = start; i < end; i++) {
            skill skl = skillUtils.getInstance().getSkill("1002" + i);
            if (skl != null && skl.triggerType == 0) {
                list.add(skl.key);
            }
        }
        //设置宠物的技能
        if (updateShiFaSkls("pet_skls", shifa, list)) {
            isUpdate = true;
        }
        if (isUpdate) {
            jsonMapper.updateShiFaWay(name, null,
                    shifa.getString("role_skls"),
                    shifa.getString("pet_skls"));
        }
        shifa.put("role_skls", shifa.getJSONArray("role_skls"));
        shifa.put("pet_skls", shifa.getJSONArray("pet_skls"));
        return shifa;
    }

    private boolean updateShiFaSkls(String k, JSONObject shifa, JSONArray list) {
        boolean isUpdate = false;
        //不存在人物的施法技能列表时，将筛选的list放入即可
        if (!shifa.containsKey(k)) {
            shifa.put(k, list);
        }
        JSONArray sfList = shifa.getJSONArray(k);
        //当两者技能长度不一致时，即学了新主动技能
        isUpdate = true;
        if (k.equals("role_skls")) {
            for (int i = 0; i < sfList.size(); i++) {
                boolean isExist = false;
                for (int j = 0; j < list.size(); j++) {
                    if (sfList.getString(i).equals(list.getString(j))) {
                        isExist = true;
                        break;
                    }
                }
                if (!isExist) {//移除不存在的技能
                    sfList.remove(i);
                    i--;
                }
            }
        }
        for (int i = 0; i < list.size(); i++) {
            boolean b = false;
            //新的技能在旧的之中是否存在
            String newSkl = list.getString(i);
            for (int j = 0; j < sfList.size(); j++) {
                if (newSkl.equals(sfList.getString(j))) {
                    b = true;
                    break;
                }
            }
            if (!b) {
                sfList.add(list.getString(i));
            }
        }
        return isUpdate;
    }

    /**
     * 更换角色形象
     */
    public result changeModel(JSONObject obj,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer type = obj.getInteger("type");
        if (type == null || type < 0 || type > 2) return new result(0);
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        JSONObject role = roleMapper.getRoleViewByName(name).get(0);
        JSONArray models = role.getJSONArray("models");
        if (type >= models.size()) return new result(0);
        String model = models.getString(type);
        roleMapper.updateModel(model, name);
        user.msg.put("model", model);
        return new result(200, 1);
    }

    /**
     * 加入分堂
     */
    public result joinFenTang(JSONObject obj,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer type = obj.getInteger("type");
        if (type == null || type < 0 || type > 5) return new result(0);
        JSONObject role = getRole(name, con);
        //是否大于30级
        if (role.getInteger("lever") < 30) return new result(0);
        //要求先加入门派
        String mp = roleUtils.getMenPaiFromModels(role);
        if (mp == null) return new result(976);
        if ((mp.contains("zs") && type != 0 && type != 1) ||
                (mp.contains("fs") && type != 2 && type != 3) ||
                (mp.contains("fz") && type != 4 && type != 5)) {
            return new result(976);
        }
        //判断是否已经加入过分堂
        String job = roleUtils.getJobFromModels(role);
        if (job != null) return new result(974);
        String sex = roleUtils.getSexFromModels(role);
        String md = null;
        if (type == 0) md = "ms_" + sex;
        else if (type == 1) md = "dj_" + sex;
        else if (type == 2) md = "qm_" + sex;
        else if (type == 3) md = "ty_" + sex;
        else if (type == 4) md = "ym_" + sex;
        else if (type == 5) md = "lc_" + sex;
        else return new result(0);
        //需要把之前学习的门派技能进行转化成职业技能
        JSONArray skls = getSkill(name, con);
        for (int i = 0; i < skls.size(); i++) {
            JSONObject skl = skls.getJSONObject(i);
            if (!skl.containsKey("key")) continue;
            String sklKey = skl.getString("key");
            if (roleUtils.isMenPaiSklKey(sklKey)) {
                //直接覆盖旧的技能
                String newSklKey = roleUtils.mpSklToJobSkl(md, sklKey);
                skl.put("key", newSklKey);
            }
        }
        saveSkill(skls, name, con);

        JSONArray models = JSON.parseArray(role.getString("models"));
        models.add(md);
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        roleMapper.updateModels(models.toString(), name);
        return new result(200, 1);
    }

    /**
     * 加入门派
     */
    public result joinMenPai(JSONObject obj,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer type = obj.getInteger("type");
        if (type == null ||
                (type != 0 && type != 1 && type != 2)) return new result(0);
        JSONObject role = getRole(name, con);
        //是否大于15级
        if (role.getInteger("lever") < 15) return new result(0);
        //判断是否已经加入过门派
        String mp = roleUtils.getMenPaiFromModels(role);
        if (mp != null) return new result(972);
        String sex = roleUtils.getSexFromModels(role);
        String md = null;
        if (type == 0) md = "zs_" + sex;
        else if (type == 1) md = "fs_" + sex;
        else if (type == 2) md = "fz_" + sex;
        else return new result(0);
        JSONArray models = JSON.parseArray(role.getString("models"));
        models.add(md);
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        roleMapper.updateModels(models.toString(), name);
        return new result(200, 1);
    }

    /**
     * 提升仙人秘法
     */
    public result upXrmf(JSONObject j,
                         @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer type = j.getInteger("type");
        if (type == null || (type != 0 && type != 1))
            return new result(0);
        JSONObject msg = getMsgData(name, con);
        JSONObject xrmf = msg.getJSONObject("xrmf");
        int lv = 0;
        String xhKey = "10000162";
        if (type == 0) {
            lv = xrmf.getInteger("xrLv") + 1;
        } else {
            lv = xrmf.getInteger("xfLv") + 1;
            xhKey = "10000163";
        }
        if (lv > 30) return new result(0);

        long tale = 0;
        int xhNum = 0;
        if (type == 0) {
            tale = lv * 1000;
            int[] xhNums = {4, 5, 6, 7, 9, 11, 13, 15, 17, 27, 33, 39, 45, 51, 61, 71, 81, 91, 101, 125};
            if (lv > 10) {
                xhNum = xhNums[lv - 11];
                if (lv > 11) tale = (lv - 10) * 10000;
            }
        } else {
            tale = lv * 1000;
            if (lv > 10) xhNum = lv - 10;
        }
        if (saveMoney(1, -tale, name, con) != 1) {
            return new result(0);
        }
        if (xhNum > 0 && startBef.packageService.cutPlayerGoodsNumByKey(xhKey, xhNum, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        float p = 1f;
        //概率计算
        if (lv < 11) p = 1;
        else p = (float) Math.pow(0.98, lv - 10);
        if (strUtils.isHappend(0, 1000, p)) {
            if (type == 0) xrmf.put("xrLv", lv);
            else xrmf.put("xfLv", lv);

            JSONObject obj = new JSONObject();
            obj.put("xrmf", xrmf);
            if (saveMsg(name, obj, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            return new result(200, 1);
        }
        return new result(200, 0);

    }

    /**
     * 境界突破（100级开启，涉及武魂和魔神）
     * 0无 1灵境 2魂境 3智境 4潜境 5圆境 6灵修境
     * 7浑天境 8破虚境 9灵实境 10圣灵境
     */
    public result realmBreak(@paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (user.msg.getInteger("lever") < 100)
            return new result(915);
        JSONObject msg = getMsgData(name, con);
        int realmLv = msg.getInteger("realmLv");
        if (realmLv >= 10) return new result(0);
        //是否战胜心魔
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = activityMapper.getXinMo(name);
        if (list.size() == 0) {
            activityMapper.addXinMo(name);
            list = activityMapper.getXinMo(name);
        }
        if (list.get(0).getInteger("lv") != (realmLv + 1))
            return new result(914);
        //材料是否充足
        if (startBef.packageService.cutPlayerGoodsNumByKey("1155", 9 * (realmLv + 1), name, con) != 1) {
            return new result(0);
        }
        //境界提升
        JSONObject obj = new JSONObject();
        obj.put("realmLv", realmLv + 1);
        saveMsg(name, obj, con);
        return new result(200, 1);
    }


    /**
     * 处理血包扣除
     */
    public void handHp(JSONObject rMap, JSONArray roleList) {
        Map<String, JSONObject> attrMap = new HashMap<>();
        for (int i = 0; i < roleList.size(); i++) {
            JSONObject a = roleList.getJSONObject(i);
            JSONObject attr = rMap.getJSONObject(a.getString("posKey"));
            //将昵称跟属性对应上
            attrMap.put(a.getString("name"), attr);
        }
        JSONObject addMap = new JSONObject();
        for (int i = 0; i < roleList.size(); i++) {
            JSONObject a = roleList.getJSONObject(i);
            String name = a.getString("name");
            //只要角色，不要宠物
            if (name.contains("_pet")) continue;
            //角色的血量计算
            JSONObject prop = attrMap.get(name).getJSONObject("prop");
            float max_xue = prop.getFloat("max_xue");
            float xue = prop.getFloat("xue");
            if (xue <= 0) xue = 1;
            float manXue = max_xue - xue;//需要补上的血量
            float max_lan = prop.getFloat("max_lan");
            float lan = prop.getFloat("lan");
            if (lan <= 0) lan = 1;
            float manLan = max_lan - lan;

            //宠物需要补上的血量
            float petXue = 0;
            float petLan = 0;
            if (attrMap.containsKey(name + "_pet")) {
                prop = attrMap.get(name + "_pet").getJSONObject("prop");
                max_xue = prop.getFloat("max_xue");
                xue = prop.getFloat("xue");
                if (xue <= 0) xue = 1;
                petXue = max_xue - xue;//需要补上的血量
                max_lan = prop.getFloat("max_lan");
                lan = prop.getFloat("lan");
                if (lan <= 0) lan = 1;
                petLan = max_lan - lan;
            }
            JSONObject temp = new JSONObject();
            temp.put("manXue", manXue);
            temp.put("manLan", manLan);
            temp.put("petXue", petXue);
            temp.put("petLan", petLan);
            addMap.put(name, temp);
        }

        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            for (String name : addMap.keySet()) {
                //补给包状态未打开就跳过
                if (isAllowedBjb(name, con) != 1) {
                    continue;
                }
                JSONObject temp = addMap.getJSONObject(name);
                int manXue = temp.getInteger("manXue");
                int manLan = temp.getInteger("manLan");
                int petXue = temp.getInteger("petXue");
                int petLan = temp.getInteger("petLan");
                startBef.packageService.updateBJB(name, manXue, manLan, petXue, petLan, con);
                mybatisConfig.commit(con);
            }
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 点亮属性
     */
    public result clkStarAttr(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        String[] as = {"wg", "fg", "max_xue", "wf", "ff",
                "max_lan", "bj", "mz", "css", "sd"};
        //判断参数是否允许
        boolean b = false;
        for (String a : as) {
            if (a.equals(key)) b = true;
        }
        if (!b) return new result(0);

        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        JSONObject one = getManStar(name, con);
        JSONObject star = one.getJSONObject("star");

        JSONObject attrs = star.getJSONObject("attr");
        if (attrs.getInteger(key) == 1) {
            //无需再次点亮
            return new result(0);
        }

        //判断点亮的材料是否充足
        int num = star.getInteger("num");
        //12星是极限
        if (num >= 12) {
            return new result(0);
        }
        //所需数量
        int n = 10 + 10 * num;
        String gKey = attrKeyToGoodsKey(key);
        //减掉数量
        if (gKey == null || startBef.packageService.cutPlayerGoodsNumByKey(gKey, n, name, con) != 1) {
            return new result(0);
        }
        //点亮属性
        attrs.put(key, 1);
        //检测10个属性是否均已点亮，是就升星
        for (String a : attrs.keySet()) {
            if (attrs.getInteger(a) == 0) {
                b = false;
                break;
            }
        }
        if (!b) {
            //未满10属性，不升星

        } else {
            //满10属性，升星
            star.put("num", num + 1);
            for (String a : attrs.keySet()) {
                attrs.put(a, 0);
            }
        }
        b = jsonMapper.updateManStar(name, JSON.toJSONString(star));
        if (!b) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        //重新计算战力
        startBef.orderService.countZlOrder(name);
        return new result(200, 1);
    }

    private String attrKeyToGoodsKey(String key) {
        switch (key) {
            case "wg":
                return "111000";
            case "fg":
                return "111001";
            case "max_xue":
                return "111002";
            case "wf":
                return "111003";
            case "ff":
                return "111004";
            case "max_lan":
                return "111005";
            case "bj":
                return "111006";
            case "mz":
                return "111007";
            case "css":
                return "111008";
            case "sd":
                return "111009";
        }
        return null;
    }

    private JSONObject getManStar(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectManStar(name);
        if (list.size() == 0) {
            JSONObject o = new JSONObject();
            o.put("num", 0);//星数
            JSONArray attrs = new JSONArray();
            String[] as = {"wg", "fg", "max_xue", "wf", "ff",
                    "max_lan", "bj", "mz", "css", "sd"};
            for (String a : as) {
                JSONObject n = new JSONObject();
                n.put(a, 0);//0未点亮1点亮
                attrs.add(n);
            }
            o.put("attr", attrs);
            list.add(o);
            jsonMapper.addManStar(name, JSON.toJSONString(o));
        }
        return list.get(0);
    }

    /**
     * 更换翅膀
     */
    public result changeWings(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = dao.getWings(name);
        if (list.size() == 0) {
            dao.addWings(name);
            return new result(0);
        }
        //设置不显示
        if (key.equals("")) {
            JSONObject obj = new JSONObject();
            obj.put("wings", key);
            saveMsg(name, obj, con);
            user.msg.put("wings", key);
            return new result(200, 1);
        }
        JSONArray wings = list.get(0).getJSONArray("wings");
        for (int i = 0; i < wings.size(); i++) {
            if (key.equals(wings.get(i))) {
                JSONObject obj = new JSONObject();
                obj.put("wings", key);
                saveMsg(name, obj, con);
                user.msg.put("wings", key);
                return new result(200, 1);
            }
        }
        return new result(0);
    }

    /**
     * 添加新称号
     */
    public Object addTitle(String key, String name, DefaultSqlSession con) {
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = dao.getTitle(name);
        if (list.size() == 0) {
            dao.addTitle(name);
            JSONObject o = new JSONObject();
            o.put("titles", new JSONArray());
            list.add(o);
        }
        JSONArray titles = list.get(0).getJSONArray("titles");
        for (int i = 0; i < titles.size(); i++) {
            if (key.equals(titles.get(i))) {
                //称号已经存在
                mybatisConfig.rollback(con);
                return 0;
            }
        }
        titles.add(key);
        //todo:对于限时称号需要插入一张新表，每天凌晨将这些即将过期的称号放入缓存，需要有一个线程专门处理这些过期的称号
        return dao.updateTitle(name, JSON.toJSONString(titles)) ? 1 : 0;
    }

    /**
     * 更换称号
     */
    public result changeTitle(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = dao.getTitle(name);
        if (list.size() == 0) {
            dao.addTitle(name);
            return new result(0);
        }
        //设置不显示
        if (key.equals("")) {
            JSONObject obj = new JSONObject();
            obj.put("ch", key);
            saveMsg(name, obj, con);
            user.msg.put("ch", key);
            return new result(200, 1);
        }
        JSONArray titles = list.get(0).getJSONArray("titles");
        for (int i = 0; i < titles.size(); i++) {
            if (key.equals(titles.get(i))) {
                JSONObject obj = new JSONObject();
                obj.put("ch", key);
                saveMsg(name, obj, con);
                user.msg.put("ch", key);
                return new result(200, 1);
            }
        }
        return new result(0);
    }


    /**
     * 获取人物的所有形象
     */
    private JSONArray getModels(String name, DefaultSqlSession con) {
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        JSONObject role = roleMapper.getRoleViewByName(name).get(0);
        return role.getJSONArray("models");
    }


    /**
     * 更新善恶值
     */
    public Integer updateSez(String name, int i, DefaultSqlSession con) {
        JSONObject msg = getMsgData(name, con);
        int r = msg.getInteger("sez") + i;
        /*if (r < 0) r = 0;
        else if (r > 10) r = 10;*/
        //发生变更
        if (r != msg.getInteger("sez")) {
            JSONObject res = new JSONObject();
            res.put("sez", r);
            saveMsg(name, res, con);
        }
        if (r < 3) {
            startBef.orderService.countMTOrder(name);
        } else if (r > 7) {
            startBef.orderService.countYXOrder(name);
        } else {
            //从两个榜中除名
            startBef.orderService.removeNameFromMTOrYX(name, con);
        }
        user u = staticCollection.getUserByName(name);
        if (u != null && u.msg != null) {
            u.msg.put("sez", r);
        }
        return 1;
    }

    /**
     * 替换原来的善恶值
     */
    public Integer replaceSez(String name, int r, DefaultSqlSession con) {
        JSONObject res = new JSONObject();
        res.put("sez", r);
        saveMsg(name, res, con);
        if (r < 3) {
            startBef.orderService.countMTOrder(name);
        } else if (r > 7) {
            startBef.orderService.countYXOrder(name);
        } else {
            //从两个榜中除名
            startBef.orderService.removeNameFromMTOrYX(name, con);
        }
        user u = staticCollection.getUserByName(name);
        if (u != null && u.msg != null) {
            u.msg.put("sez", r);
        }
        return 1;
    }

    /**
     * 获取善恶值
     */
    public Integer getSez(String name, DefaultSqlSession con) {
        JSONObject msg = getMsgData(name, con);
        return msg.getInteger("sez");
    }

    /**
     * 遗忘技能
     */
    public result forgetSkill(JSONObject j,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //要求类型、索引
        Integer type = j.getInteger("type");
        Integer index = j.getInteger("index");
        if (type != 1 && type != 2 && type != 3) return new result(0);
        if ((type == 1 || type == 2) && index != 0) return new result(0);
        if (type == 3 && (index < 0 || index > 8)) return new result(0);
        JSONArray list = getSkill(name, con);
        JSONObject item = getOneSklFromXj(type, index, list);
        if (item == null) return new result(0);
        //消耗道具
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000165", 1, name, con) == 0) {
            return new result(0);
        }

        item.remove("key");
        item.remove("lv");
        if (saveSkill(list, name, con) == 1) {
            //重新计算战力
            startBef.orderService.countZlOrder(name);
            return new result(200, 1);
        }
        mybatisConfig.rollback(con);
        return new result(0);
    }

    /**
     * 打通仙绝刻印
     */
    public result openXianJueKeyin(JSONObject j,
                                   @paramsAnno(key = "user") user user,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer type = j.getInteger("type");
        Integer index = j.getInteger("index");
        if (type != 1 && type != 2 && type != 3) return new result(0);
        if ((type == 1 || type == 2) && index != 0) return new result(0);
        if (type == 3 && (index < 0 || index > 9)) return new result(0);
        //消耗刻印卷轴
        if (startBef.packageService.cutPlayerGoodsNumByKey("10000164", 6, name, con) != 1) {
            return new result(0);
        }
        JSONArray list = getSkill(name, con);
        //判断该位置是否已经开启了
        JSONObject skl = null;
        if (type == 1) {
            skl = getOneSklFromXj(1, 0, list);
        } else if (type == 2) {
            skl = getOneSklFromXj(2, 0, list);
        } else {
            skl = getOneSklFromXj(3, index, list);
        }
        //已经开过
        if (skl != null) return new result(0);
        //学习了技能后才有key字段
        skl = new JSONObject();
        skl.put("type", type);
        skl.put("index", index);
        list.add(skl);
        if (saveSkill(list, name, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, 1);
    }

    private JSONObject getOneSklFromXj(int type, int index, JSONArray list) {
        for (int i = 0; i < list.size(); i++) {
            JSONObject a = list.getJSONObject(i);
            if ((a.containsKey("type") && a.getInteger("type") == type) &&
                    ((a.containsKey("index") && a.getInteger("index") == index))) {
                return a;
            }
        }
        return null;
    }

    private JSONObject getOneSkl(String key, JSONArray list) {
        for (int i = 0; i < list.size(); i++) {
            JSONObject a = list.getJSONObject(i);
            if (a.containsKey("key") && a.getString("key").equals(key)) {
                return a;
            }
        }
        return null;
    }


    /**
     * 学习技能
     */
    public result learnSkill(JSONObject j,
                             @paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String key = j.getString("key");
        if (strUtils.isNull(key)) return new result(0);
        //jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        //roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        //由key获取其种类 0门派、1天技（4级）、2地技（4级）允许升级 3人技不允许升级 4宠物专属 5宠物普通 6经脉
        JSONArray list = getSkill(name, con);
        skill data = skillUtils.getInstance().getSkill(key);
        if (data == null) return new result(979);

        if (data.type == 0) {
            JSONObject role = getRole(name, con);
            //如果是门派初始技能，需要先将技能这个key转换成对应的职业技能
            key = roleUtils.mpSklToJobSkl(role, key);
            //门派技能，不需要消耗技能书，验证角色是否属于该职业，是否达到升级条件
            skill msg = skillUtils.getInstance().getSkill(key);
            String mp = roleUtils.getMenPaiFromModels(role);
            String job = roleUtils.getJobFromModels(role);
            if (job == null && mp == null) return new result(200, 0);
            if (mp != null && job != null && !msg.job.contains(job.substring(0, 2))) {
                return new result(200, 0);
            } else if (job == null && mp != null && !msg.job.contains(mp.substring(0, 2))) {
                return new result(200, 0);
            }

            //升级条件 人物等级、消耗经验、消耗银票、最大等级
            for (Object l : list) {
                JSONObject obj = (JSONObject) l;
                if (obj.containsKey("key") && obj.getString("key").equals(key)) {
                    int lv = obj.getInteger("lv");
                    //超过最大等级
                    if (lv >= msg.maxLv) {
                        return new result(200, 0);
                    }
                    //等级是否达到
                    if (role.getInteger("lever") < ((lv + 1) * 4 + 10)) {
                        return new result(200, 0);
                    }
                    //经验是否足够
                    int exp = getProp(name, con).getInteger("exp");
                    if (exp < 150 * Math.pow(lv + 1, 4)) {
                        return new result(200, 0);
                    }
                    //银票是否足够
                    int yp = getMsgData(name, con).getInteger("yp");
                    if (yp < 100 * Math.pow(lv + 1, 4)) {
                        return new result(200, 0);
                    }
                    //减去exp、yp
                    JSONObject expObj = new JSONObject();
                    expObj.put("exp", exp - 150 * Math.pow(lv + 1, 4));
                    saveProp(name, expObj, con);
                    JSONObject ypObj = new JSONObject();
                    ypObj.put("yp", yp - 100 * Math.pow(lv + 1, 4));
                    saveMsg(name, ypObj, con);

                    obj.put("lv", obj.getInteger("lv") + 1);
                    saveSkill(list, name, con);
                    return new result(200, 1);
                }
            }
            //未学习的情况
            //等级是否达到
            if (role.getInteger("lever") < ((1) * 4 + 10)) {
                return new result(200, 0);
            }
            //经验是否足够
            int exp = getProp(name, con).getInteger("exp");
            if (exp < 150 * Math.pow(1, 4)) {
                return new result(200, 0);
            }
            //银票是否足够
            int yp = getMsgData(name, con).getInteger("yp");
            if (yp < 100 * Math.pow(1, 4)) {
                return new result(200, 0);
            }
            //减去exp、yp
            JSONObject expObj = new JSONObject();
            expObj.put("exp", exp - 150 * Math.pow(1, 4));
            saveProp(name, expObj, con);
            JSONObject ypObj = new JSONObject();
            ypObj.put("yp", yp - 100 * Math.pow(1, 4));
            saveMsg(name, ypObj, con);

            JSONObject item = new JSONObject();
            item.put("key", key);
            item.put("lv", 1);
            list.add(item);
            saveSkill(list, name, con);
        } else if (data.type == 1 || data.type == 2) {
            //天技，需要消耗技能书，最高4级,只能有一个天技
            //获取槽位
            JSONObject item = null;
            if (data.type == 1) item = getOneSklFromXj(1, 0, list);
            else item = getOneSklFromXj(2, 0, list);
            //是否开启了槽位
            if (item == null) {
                return new result(0);
            }
            //没有打技能的情况
            if (!item.containsKey("key")) {
                if (startBef.packageService.cutPlayerGoodsNumByKey(key, 1, name, con) == 0) {
                    return new result(0);
                }
                item.put("key", key);
                item.put("lv", 1);
                saveSkill(list, name, con);
            } else {
                //打了技能但技能的key跟要打的key不一致时
                if (!item.getString("key").equals(key)) {
                    return new result(0);
                }
                //技能key一致时发生升级
                int num = item.getInteger("lv") * 2;
                if (item.getInteger("lv") >= 4 || startBef.packageService.cutPlayerGoodsNumByKey(key, num, name, con) == 0) {
                    return new result(0);
                }
                item.put("lv", item.getInteger("lv") + 1);
                saveSkill(list, name, con);
            }

        } else if (data.type == 3) {
            //人技，需要消耗技能书，最高1级
            //判断回天书处理中是否存在需要处理的任务
            for (int i = 0; i < skillData.HuitianSkillCache.size(); i++) {
                JSONObject a = skillData.HuitianSkillCache.get(i);
                if (a.getString("name").equals(name) &&
                        a.getInteger("roleType") == 0) {
                    JSONObject res = new JSONObject();
                    res.put("index", a.getInteger("index"));
                    res.put("sure", 1);//表示需要弹出询问
                    return new result(200, res);
                }
            }

            //判断是否已经学习过该技能
            for (Object l : list) {
                JSONObject obj = (JSONObject) l;
                if (obj.containsKey("type") && obj.getInteger("type") == 3 &&
                        obj.containsKey("key") && obj.getString("key").equals(key)) {
                    return new result(0);
                }
            }
            //对开启的槽位随机
            List<JSONObject> temp = new ArrayList<>();
            for (Object l : list) {
                JSONObject obj = (JSONObject) l;
                if (obj.containsKey("type") && obj.getInteger("type") == 3) {
                    temp.add(obj);
                }
            }
            if (temp.size() == 0) {//一个槽位都没开
                return new result(0);
            }
            //随机取一个
            int sy = strUtils.getRandom(0, temp.size());
            int tIndex = temp.get(sy).getInteger("index");

            if (startBef.packageService.cutPlayerGoodsNumByKey(key, 1, name, con) == 0) {
                return new result(0);
            }
            //确定修改的槽位
            JSONObject item = getOneSklFromXj(3, tIndex, list);
            if (item.containsKey("key")) {//已经打过技能的情况
                //需要询问是否使用回天书
                //将其延迟放入缓存
                JSONObject cache = new JSONObject();
                cache.put("name", name);
                cache.put("key", key);
                cache.put("index", item.getInteger("index"));
                cache.put("created", strUtils.getTime());
                cache.put("roleType", 0);//0角色1宠物
                skillData.HuitianSkillCache.add(cache);

                JSONObject res = new JSONObject();
                res.put("index", item.getInteger("index"));
                res.put("sure", 1);//表示需要弹出询问
                return new result(200, res);
            } else {
                item.put("key", key);
                item.put("lv", 1);
                saveSkill(list, name, con);
                //将技能所在的位置返回
                JSONObject res = new JSONObject();
                res.put("index", item.getInteger("index"));
                res.put("sure", 0);//表示不需要弹出询问
                return new result(200, res);
            }
        } else if (data.type == 6) {//经脉
            //判断传入的key是否属于经脉范围
            if (!key.substring(0, 8).equals("10021002")) return new result(0);
            //需要消耗可分配点数
            boolean b = false;
            int lv = 0;
            int index = 0;
            for (int i = 0; i < list.size(); i++) {
                JSONObject obj = (JSONObject) list.get(i);
                if (obj.containsKey("key") && obj.getString("key").equals(key)) {
                    //已经学过了
                    b = true;
                    lv = obj.getInteger("lv");
                    index = i;
                    break;
                }
            }
            //最高15级
            if (lv >= 15) return new result(656);
            //已经学习过的需要判断可分配点数是否足已升级
            JSONObject msg = getMsgData(name, con);
            int jmPoint = msg.getInteger("jmPoint");
            //智力增加 1级40点 2级44点 3级48点 4级52 5级56
            //14+5+1是1060
            //1级20点 2级20点
            // 3级40点 4级40点 5级40
            // 6级60 7级60 8级60
            // 9级80 10级80 11级80
            // 12级100 13级100 14级100 15级100
            //
            int[] xhn = {20, 20, 40, 40, 40, 60, 60, 60, 80, 80, 80, 100, 100, 100, 100};
            int xh = xhn[lv];
            if (jmPoint - xh < 0) {
                return new result(703);
            }
            saveJmPoint(name, -xh, con);
            if (b) {
                ((JSONObject) list.get(index)).put("lv", lv + 1);
            } else {
                JSONObject item = new JSONObject();
                item.put("key", key);
                item.put("lv", lv + 1);
                list.add(item);
            }
            saveSkill(list, name, con);
        } else if (data.type == 9) {//生活技能
            JSONObject item = getOneSkl(key, list);
            if (item == null) {
                //未学习的情况
                item = new JSONObject();
                item.put("key", key);
                item.put("lv", 0);
                list.add(item);
            }
            int lv = item.getInteger("lv");
            int exp = 3000 + 5000 * lv;
            long tale = 1100 + 300 * lv;
            int bg = 0;
            if (lv >= 60) {
                bg = lv * 100;
                int zongBg = startBef.gangsService.getBpMemberZongBg(name, con);
                if (zongBg < bg) return new result(890);
            }
            if (lv >= 100) return new result(0);
            if (saveMoney(1, -tale, name, con) == 0) return new result(0);
            JSONObject prop = getProp(name, con);
            if (prop.getInteger("exp") - exp < 0) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            prop.put("exp", prop.getInteger("exp") - exp);
            JSONObject e = new JSONObject();
            e.put("exp", prop.getInteger("exp"));
            if (saveProp(name, e, con) == 0) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            item.put("lv", item.getInteger("lv") + 1);
            saveSkill(list, name, con);
        }
        //重新计算战力
        startBef.orderService.countZlOrder(name);
        return new result(200, 1);
    }

    /**
     * 取消/确认技能覆盖
     */
    public result sureSkillCover(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        Integer sure = j.getInteger("sure");
        if (sure == null || (sure != 0 && sure != 1)) return new result(0);

        JSONObject item = null;
        for (int i = 0; i < skillData.HuitianSkillCache.size(); i++) {
            JSONObject a = skillData.HuitianSkillCache.get(i);
            if (a.getString("name").equals(name) &&
                    a.getInteger("roleType") == 0) {
                item = a;
                skillData.HuitianSkillCache.remove(i);
                break;
            }
        }
        if (item == null) {
            //已经超时未处理，交由系统处理了
            return new result(200, -1);
        }
        int roleType = item.getInteger("roleType");
        int index = item.getInteger("index");
        String key = item.getString("key");
        String xhKey = null;
        if (roleType == 0) xhKey = "10000128";
        else xhKey = "10000120";

        if (sure == 1) {
            //确认覆盖
            if (roleType == 0) {
                JSONArray list = getSkill(name, con);
                JSONObject q = getOneSklFromXj(3, index, list);
                q.put("key", key);
                q.put("lv", 1);
                saveSkill(list, name, con);
            } else {
                //宠物
            }
            return new result(200, 1);
        } else {
            //取消覆盖
            if (startBef.packageService.cutPlayerGoodsNumByKey(xhKey, 1, name, con) == 1) {
                //取消覆盖成功
                return new result(200, 0);
            } else {
                //发生覆盖
                if (roleType == 0) {
                    JSONArray list = getSkill(name, con);
                    JSONObject q = getOneSklFromXj(3, index, list);
                    q.put("key", key);
                    q.put("lv", 1);
                    saveSkill(list, name, con);
                } else {
                    //宠物
                }
                return new result(200, 1);
            }
        }
    }

    /**
     * 技能回天书超时处理（每分钟调取一次）
     */
    public void huitianHandle() {
        long t = strUtils.getTime();
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            for (int i = 0; i < skillData.HuitianSkillCache.size(); i++) {
                JSONObject a = skillData.HuitianSkillCache.get(i);
                //name key index created roleType
                //处理超过2分钟的
                if (t - a.getLong("created") > 2 * 60 * 1000) {
                    //使用回天书
                    int roleType = a.getInteger("roleType");
                    String name = a.getString("name");
                    int index = a.getInteger("index");
                    String key = a.getString("key");
                    String xhKey = null;
                    if (roleType == 0) xhKey = "10000128";
                    else xhKey = "10000120";

                    if (startBef.packageService.cutPlayerGoodsNumByKey(xhKey, 1, name, con) == 0) {
                        //数量不够则直接覆盖
                        if (roleType == 0) {
                            JSONArray list = getSkill(name, con);
                            JSONObject item = getOneSklFromXj(3, index, list);
                            item.put("key", key);
                            item.put("lv", 1);
                            saveSkill(list, name, con);
                        } else {
                            //宠物
                            String petId = a.getString("petId");
                            startBef.petService.handleSklSureOverTime(petId, key, index, name, con);
                        }
                    } else {
                        //取消覆盖
                    }
                    //通知技能被覆盖
                    ChannelSupervise.noticeClientByName(a, name, "849");
                    skillData.HuitianSkillCache.remove(i);
                    i--;
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
     * 保存经脉点数
     */
    public Integer saveJmPoint(String name, int point, DefaultSqlSession con) {
        JSONObject msg = getMsgData(name, con);
        JSONObject j = new JSONObject();
        j.put("jmPoint", msg.getInteger("jmPoint") + point);
        return saveMsg(name, j, con);
    }

    public int getJmPoint(String name, DefaultSqlSession con) {
        JSONObject msg = getMsgData(name, con);
        return msg.getInteger("jmPoint");
    }

    public boolean upShengwang(String name, int exp, DefaultSqlSession con) {
        JSONObject msg = getMsgData(name, con);
        JSONObject swdj = msg.getJSONObject("swdj");
        upShengwangCount(swdj, exp);
        JSONObject j = new JSONObject();
        j.put("swdj", swdj);
        return saveMsg(name, j, con) == 1;
    }

    private JSONObject upShengwangCount(JSONObject swdj, int exp) {
        int lv = swdj.getInteger("lv") + 1;
        int old = swdj.getInteger("exp");
        int max = (int) (lv * 100 + 2 * Math.pow(5, 0.1 * lv));
        int d = exp + old - max;
        if (d >= 0) {
            //发生升级
            swdj.put("lv", lv);
            swdj.put("exp", 0);
            upShengwangCount(swdj, d);
        } else {
            //未发生升级
            swdj.put("exp", exp + old);
        }
        return swdj;
    }

    /**
     * 升级按钮升级
     */
    public result addLvByBtn(@paramsAnno(key = "user") user user,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (user.msg.getInteger("lever") < 30) return new result(0);
        JSONObject item = getRole(name, con);
        int oldLv = item.getInteger("lever");
        JSONObject prop = getProp(name, con);
        int max_exp = getExpData(oldLv).intValue();
        if (prop.getInteger("exp") < max_exp) return new result(0);
        String taskKey = null;
        if (oldLv == 49) taskKey = "1112";
        else if (oldLv == 59) taskKey = "1113";
        else if (oldLv == 69) taskKey = "1114";
        else if (oldLv == 79) taskKey = "1115";
        else if (oldLv == 89) taskKey = "1116";
        else if (oldLv == 99) taskKey = "1117";
        if (taskKey != null) {
            //判断突破任务是否已经完成
            if (startBef.taskService.isCommit(taskKey, name, con) != 1) {
                return new result(978);
            }
        }
        //小于100级就直接计算等级
        boolean b = upLv(name, 0, con, 100);
        if (!b) return new result(0);
        else {
            if (oldLv == 49) {
                //自动出师
                startBef.stService.chushi(name, con);
            }
            //升级必然触发任务开启的检测
            startBef.taskService.checkTaskStart(name, con);
        }
        return new result(200, 1);
    }

    private void handleTuPoLv(JSONObject temp, int oldLv, String name, DefaultSqlSession con) {
        //50-100都需要完成突破任务  最多累计当前未突破等级的5倍
        int newLv = temp.getInteger("lever");
        if (newLv >= 50) {
            String taskKey = null;
            int limit = 49;
            if (oldLv < 50 && newLv >= 50) {
                taskKey = "1112";
                limit = 49;
            } else if (oldLv < 60 && newLv >= 60) {
                taskKey = "1113";
                limit = 59;
            } else if (oldLv < 70 && newLv >= 70) {
                taskKey = "1114";
                limit = 69;
            } else if (oldLv < 80 && newLv >= 80) {
                taskKey = "1115";
                limit = 79;
            } else if (oldLv < 90 && newLv >= 90) {
                taskKey = "1116";
                limit = 89;
            } else if (oldLv < 100 && newLv >= 100) {
                taskKey = "1117";
                limit = 99;
            }
            if (taskKey != null) {
                //判断突破任务是否已经完成
                if (startBef.taskService.isCommit(taskKey, name, con) == 1) {
                    //对于完成的等级就往上提升
                } else {
                    //未完成的就阻止等级提升
                    //距离突破等级相差的等级
                    int disLv = newLv - (limit + 1);
                    int sum = 0;
                    //如：48升51，disLv=1 跨越了50级，所以计算50所需
                    for (int i = 0; i < disLv; i++) {
                        //计算跨级累计
                        Double jy = getExpData(limit + i + 1);
                        int max_exp = new Double(jy).intValue();
                        sum += max_exp;
                    }
                    sum += temp.getInteger("inputExp");
                    //当前等级的极限exp
                    int max_exp = getExpData(limit).intValue();
                    //总经验=当前突破等级所需经验+跨级经验累计
                    sum += max_exp;
                    if (sum > max_exp * 5)
                        sum = max_exp * 5;
                    //等级不变，经验累计
                    temp.put("inputExp", sum);
                    temp.put("lever", limit);
                }
            }
        }
    }

    /**
     * 人物升级
     */
    public boolean upLv(String name, int exp, DefaultSqlSession con, int limitLv) {
        JSONObject item = getRole(name, con);
        int oldLv = item.getInteger("lever");

        JSONObject prop = getProp(name, con);

        JSONObject temp = new JSONObject();
        temp.put("inputExp", prop.getInteger("exp") + exp);
        temp.put("lever", oldLv);
        //低于30级才直接计算等级，否则直接加经验（30-100需要按升级按钮来升级）
        if (oldLv < limitLv) {
            countLv(temp);
        } else {
            //经验不能超过当前等级的极限的5倍
            int max_exp = getExpData(oldLv).intValue() * 5;
            if (temp.getInteger("inputExp") > max_exp) {
                temp.put("inputExp", max_exp);
            }
        }
        //对于有未完成突破任务的进行等级限制
        handleTuPoLv(temp, oldLv, name, con);
        prop.put("exp", temp.getInteger("inputExp"));
        boolean b = false;
        //发生升级
        if (oldLv < temp.getInteger("lever")) {
            roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
            roleMapper.updateLv(temp.getLong("lever"), name);
            //刷新缓存
            user u = null;
            if ((u = staticCollection.getUserByName(name)) != null)
                u.msg.put("lever", temp.getLong("lever"));
            //补满血、蓝
            JSONObject attr = getFightAttr(name, con).getJSONObject("prop");
            prop.put("xue", attr.getInteger("max_xue"));
            prop.put("lan", attr.getInteger("max_lan"));
            startBef.orderService.countLvOrder(name);
            //重新计算战力
            startBef.orderService.countZlOrder(name);
            b = true;
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        jsonMapper.updatePropByName(JSON.toJSONString(prop), name);
        return b;
    }

    /**
     * 获取战斗属性
     */
    public JSONObject getFightAttr(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.getPlayerMsgView(name);
        JSONObject j = list.get(0);
        int lever = j.getInteger("lever");
        //String model = j.getString("model");
        String model = roleUtils.getModel(j);
        j.put("model", model);
        //把数据库存放json格式数据的转对象
        j.put("prop", JSON.parseObject(j.getString("prop")));
        j.put("equip", JSON.parseObject(j.getString("equip")));
        JSONArray skl = JSON.parseArray(j.getString("skill"));
        //去除空槽位
        for (int i = 0; i < skl.size(); i++) {
            JSONObject a = skl.getJSONObject(i);
            if (!a.containsKey("key")) {
                skl.remove(i);
                i--;
            }
        }
        j.put("skill", skl);
        j.put("msLv", startBef.yhmkService.getMoShenLv(name, con));
        j.put("shenfu", startBef.shenfuService.getShenFu(name, con));

        JSONObject r = new JSONObject();
        r.put("lever", lever);
        r.put("attr", j);
        JSONObject prop = countProp(r);

        JSONObject attr = new JSONObject();
        attr.put("prop", prop);
        attr.put("skill", j.get("skill"));
        attr.put("type", roleUtils.jobToType(model));

        return attr;
    }

    /**
     * 对ai数据进行一次筛选
     */
    public List<JSONObject> handleAIData(List<JSONObject> list) {
        list = staticCollection.copyArr(list, JSONObject.class);
        for (JSONObject l : list) {
            l.remove("attr0");
            l.remove("attr1");
        }
        return list;
    }



    /**
     * 获得玩家ai结构数据
     */
    public JSONObject getPlayerAIData(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.getPlayerMsgView(name);
        JSONObject j = list.get(0);
        int lever = j.getInteger("lever");
        //String model = j.getString("model");
        String models = j.getString("models");
        String model = roleUtils.getModel(j);
        j.put("model", model);
        JSONArray arr = JSON.parseArray(j.getString("skill"));
        //去掉空技能
        JSONArray skill = new JSONArray();
        for (Object o : arr) {
            JSONObject obj = (JSONObject) o;
            if (obj.containsKey("key")) {
                skill.add(obj);
            }
        }
        //把数据库存放json格式数据的转对象
        j.put("prop", JSON.parseObject(j.getString("prop")));
        j.put("equip", JSON.parseObject(j.getString("equip")));
        j.put("skill", skill);
        j.put("msLv", startBef.yhmkService.getMoShenLv(name, con));
        j.put("shenfu", startBef.shenfuService.getShenFu(name, con));
        JSONObject r = new JSONObject();
        r.put("lever", lever);
        r.put("attr", j);
        JSONObject prop = countProp(r);
        //人物战斗属性
        JSONObject attr = new JSONObject();
        attr.put("name", name);
        attr.put("lever", 1);
        attr.put("prop", prop);
        attr.put("skill", j.get("skill"));
        attr.put("type", roleUtils.jobToType(model));
        JSONObject res = new JSONObject();
        res.put("attr0", attr);
        res.put("name", name);
        res.put("model", model);
        res.put("models", models);
        res.put("lever", lever);

        JSONObject msgData = getMsgData(name, con);
        res.put("sez", msgData.get("sez"));
        JSONObject equip = j.getJSONObject("equip");
        res.put("goldType", getGoldType(equip));
        res.put("ch", "");
        res.put("wings", "");
        res.put("isAI", 0);
        return res;
    }


    /**
     * 获取宠物ai结构数据
     */
    public void putPetAIData(JSONObject res, String name, DefaultSqlSession con) {
        JSONObject pet = (JSONObject) startBef.petService.getIsFightPet(name, con);
        if (pet != null) {
            JSONObject m = new JSONObject();
            m.put("key", pet.getString("key"));
            if (pet.getInteger("growLv") >= 8) {
                m.put("isX8", true);
            } else {
                m.put("isX8", false);
            }
            res.put("pet", m);
            //宠物战斗属性
            JSONObject petAttr = startBef.petService.getFightAttr(name, con);
            petAttr.put("name", pet.getString("nickName"));
            petAttr.put("lever", 1);
            res.put("attr1", petAttr);
        }
    }






    /**
     * 计算属性
     */
    private JSONObject countProp(JSONObject role) {
        int lever = role.getInteger("lever");
        JSONObject base = new JSONObject();
        base.put("ll", lever);
        base.put("zl", lever);
        base.put("mj", lever);
        base.put("nl", lever);
        base.put("js", lever);
        //根据护符算出抗性
        base.put("lxkx", 0);
        base.put("bjkx", 0);
        base.put("hlkx", 0);
        base.put("hskx", 0);

        JSONObject zb = role.getJSONObject("attr").getJSONObject("equip");
        JSONArray jn = role.getJSONObject("attr").getJSONArray("skill");
        JSONObject msg = role.getJSONObject("attr").getJSONObject("msg");
        JSONObject xrmf = msg.getJSONObject("xrmf");
        //魔神等级，最终加成
        JSONObject msLv = role.getJSONObject("attr").getJSONObject("msLv");
        //神符
        JSONObject shenfu = role.getJSONObject("attr").getJSONObject("shenfu");
        //先计算五个基础属性，再计算高级属性
        if (zb != null) {
            for (String k : zb.keySet()) {
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods == null || playerGoods.getInteger("isBad") == 1 ||
                        !equipData.isEquip(playerGoods.getString("key"))) continue;
                JSONObject equip = equipData.getProp(playerGoods.getString("key"));
                //遍历包含的固定高级属性
                for (String e : equip.keySet()) {
                    if (!roleUtils.isBaseProp(e) || equip.get(e) == null) {
                        continue;
                    }
                    base.put(e, base.getFloat(e) + equip.getFloat(e));
                }
                //遍历保存在数据库的随机属性
                JSONArray randomAttr = playerGoods.getJSONArray("randomAttr");
                if (randomAttr != null) {
                    for (int i = 0; i < randomAttr.size(); i++) {
                        JSONObject o = randomAttr.getJSONObject(i);
                        String e = o.getString("k");
                        if (!roleUtils.isBaseProp(e)) {
                            continue;
                        }
                        float v = o.getFloat("v");
                        int max = equipData.getMaxJingLianAttr(playerGoods.getString("key"), e);
                        if (v > max) v = max;
                        base.put(e, base.getFloat(e) + v);
                    }
                }
                //计算装备刻印加成
                if (playerGoods.get("keyin") != null) {
                    JSONObject keyin = playerGoods.getJSONObject("keyin");
                    for (String p : keyin.keySet()) {
                        if (keyin.get(p) == null || keyin.getString(p).equals("")) continue;
                        JSONObject o = keyin.getJSONObject(p);
                        JSONObject attr = equipData.getKyAttr(o.getString("key"));
                        String kName = attr.getString("k");
                        if (!roleUtils.isBaseProp(kName)) continue;
                        float forgingLv = 0;
                        if (o.get("forging") != null) {
                            forgingLv = o.getJSONObject("forging").getFloat("lv");
                        }
                        if (base.get(kName) == null) {
                            loggerUtils.error("属性异常[找不到]：" + kName, manService.class);
                            continue;
                        }
                        float v = base.getFloat(kName) + attr.getFloat("v") + attr.getFloat("v") * 0.0375f * forgingLv;
                        base.put(kName, v);
                    }
                }
            }
        }
        if (jn != null) {
            for (Object obj : jn) {
                if (obj == null) continue;
                JSONObject jb = (JSONObject) obj;
                if (!jb.containsKey("key")) continue;
                //获取技能的加成属性
                int countWay = skillData.getCountWay(jb.getString("key"));
                JSONArray arr = skillData.getAttrs(jb.getString("key"));
                for (Object a : arr) {
                    JSONObject aa = (JSONObject) a;
                    //不是固定值的去掉
                    if (aa.getInteger("valueType") == 1) continue;
                    String attr = aa.getString("name");
                    //去掉非基础属性的
                    if (!roleUtils.isBaseProp(attr)) continue;
                    float v = 0;
                    if (countWay == 0) {
                        v = skillData.count(jb.getInteger("lv"), aa);
                    } else if (countWay == 1) {//经脉技能计算需要用到n项和
                        v = skillData.countNItemSum(jb.getInteger("lv"), aa);
                    }
                    base.put(attr, base.getFloat(attr) + v);
                }
            }
        }
        Float max_xue = 100 + base.getFloat("nl") * 5 + base.getFloat("js") * 3 + (lever - 1) * 50;
        Float max_lan = 50 + base.getFloat("js") * 5 + (lever - 1) * 5;
        Float wg = 20 + base.getFloat("ll") * 1.3f + lever * 2f;
        Float fg = 20 + base.getFloat("zl") * 1.3f + lever * 2f;
        Float wf = 2 + base.getFloat("nl") * 0.8f + lever * 1;
        Float ff = 2 + base.getFloat("nl") * 0.8f + lever * 1;
        Float mz = base.getFloat("ll") * 1.5f + lever * 7f;
        Float sd = base.getFloat("mj") * 1.2f + lever * 2f;
        Float bj = base.getFloat("zl") * 1f + lever * 2f;
        Float css = 9 + base.getFloat("mj") * 1.5f + lever * 1f;
        base.put("max_xue", max_xue);
        base.put("max_lan", max_lan);
        base.put("wg", wg);
        base.put("fg", fg);
        base.put("wf", wf);
        base.put("ff", ff);
        base.put("mz", mz);
        base.put("sd", sd);
        base.put("bj", bj);
        base.put("css", css);
        String model = role.getJSONObject("attr").getString("model");
        //计算星级属性
        JSONObject star = role.getJSONObject("attr").getJSONObject("star");
        int starNum = star.getInteger("num");
        JSONObject starProp = star.getJSONObject("attr");
        JSONObject starAttr = this.countStarAttr(1, model);
        for (String p : starAttr.keySet()) {
            base.put(p, base.getFloat(p) + starAttr.getFloat(p) * starNum);
        }
        //加上当前等级所点亮的属性
        JSONObject starAttr2 = this.countStarAttr(starNum + 1, model);
        for (String p : starProp.keySet()) {
            if (starProp.getInteger(p) == 1) {
                base.put(p, base.getFloat(p) + starAttr2.getFloat(p));
            }
        }//fg 3028
        if (xrmf != null) {
            int xrLv = xrmf.getInteger("xrLv");
            float d = (float) (xrLv * 20f + Math.pow(1.41f, xrLv) / 3f);
            base.put("max_xue", base.getFloat("max_xue") + d);
        }
        if (zb != null) {
            //计算装备固定属性
            for (String k : zb.keySet()) {
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods == null || playerGoods.getInteger("isBad") == 1 ||
                        !equipData.isEquip(playerGoods.getString("key"))) continue;
                JSONObject equip = equipData.getProp(playerGoods.getString("key"));
                //遍历包含的固定高级属性
                for (String e : equip.keySet()) {
                    if (roleUtils.isBaseProp(e) || equip.get(e) == null) {
                        continue;
                    }
                    float k0 = 1f;
                    //对于有绑定宝石的装备基础属性增加10%
                    if (playerGoods.containsKey("bdbs") &&
                            playerGoods.getInteger("bdbs") == 1) {
                        k0 += 0.1f;
                    }
                    //对于有刻印宝石的装备基础属性增加30%
                    if (playerGoods.containsKey("kybs") &&
                            playerGoods.getInteger("kybs") == 1) {
                        k0 += 0.3f;
                    }
                    //对于有血契宝石的装备基础属性增加60%
                    if (playerGoods.containsKey("xqbs") &&
                            playerGoods.getInteger("xqbs") == 1) {
                        k0 += 0.6f;
                    }
                    base.put(e, base.getFloat(e) + equip.getFloat(e) * k0);
                }
            }//fg 4821
            //System.err.println(base);
            //计算装备随机属性
            for (String k : zb.keySet()) {
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods == null || playerGoods.getInteger("isBad") == 1 ||
                        !equipData.isEquip(playerGoods.getString("key"))) continue;
                //遍历保存在数据库的随机属性
                JSONArray randomAttr = playerGoods.getJSONArray("randomAttr");
                if (randomAttr != null) {
                    for (int i = 0; i < randomAttr.size(); i++) {
                        JSONObject o = randomAttr.getJSONObject(i);
                        String e = o.getString("k");
                        if (roleUtils.isBaseProp(e)) {
                            continue;
                        }
                        float v = o.getFloat("v");
                        int max = equipData.getMaxJingLianAttr(playerGoods.getString("key"), e);
                        if (v > max) v = max;
                        base.put(e, base.getFloat(e) + v);
                    }
                }
            }//fg 6941
            //System.err.println(base);
            //锻造加成
            for (String k : zb.keySet()) {
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods == null || playerGoods.getInteger("isBad") == 1 ||
                        !equipData.isEquip(playerGoods.getString("key"))) continue;
                //计算锻造的加成（高级属性的累计）
                if (playerGoods.get("forging") != null &&
                        playerGoods.getJSONObject("forging").getInteger("lv") > 0) {
                    JSONObject obj = equipData.getAddAttrByForgingLv(playerGoods);
                    for (String attr : obj.keySet()) {
                        base.put(attr, base.getFloat(attr) + obj.getFloat(attr));
                    }
                }
            }//fg 8877
            //System.err.println(base);
            //镶嵌加成
            for (String k : zb.keySet()) {
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods == null || playerGoods.getInteger("isBad") == 1 ||
                        !equipData.isEquip(playerGoods.getString("key"))) continue;
                if (playerGoods.get("inlay") != null &&
                        playerGoods.getJSONObject("inlay").getInteger("num") > 0 &&
                        playerGoods.getJSONObject("inlay").getJSONArray("list").size() > 0) {
                    JSONArray list = playerGoods.getJSONObject("inlay").getJSONArray("list");
                    for (Object o : list) {
                        JSONObject obj = (JSONObject) o;
                        String attr = baoshiUtils.getAttrName(obj.getString("key").substring(4));
                        int max = baoshiUtils.getBaoshiAttr(obj.getString("key").substring(4));
                        int v = obj.getInteger("num");
                        if (v > max) v = max;
                        base.put(attr, base.getFloat(attr) + v);
                    }
                }
            }//fg 11711
            //System.err.println(base);
            //注魔加成
            for (String k : zb.keySet()) {
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods == null || playerGoods.getInteger("isBad") == 1 ||
                        !equipData.isEquip(playerGoods.getString("key"))) continue;
                //装备注魔加成 （高级属性的累计） {"key":"10100012","num":10}
                if (playerGoods.containsKey("czmb")) {
                    JSONObject czmb = playerGoods.getJSONObject("czmb");
                    //JSONObject mbMsg= equipData.getMoban(czmb.getString("key"));
                    float k0 = czmb.getFloat("num") / equipData.getMbMaxMoLi(czmb.getString("key"));
                    if (k0 > 1) k0 = 1f;
                    JSONObject attr = equipData.getMoBanMaxAttr(czmb.getString("key"));
                    for (String p : attr.keySet()) {
                        float kx = attr.getFloat(p) * k0;
                        base.put(p, base.getFloat(p) + kx);
                    }
                }
            }//fg 13330
            //System.err.println(base);
            //抗性加护
            for (String k : zb.keySet()) {
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods == null || playerGoods.getInteger("isBad") == 1 ||
                        !equipData.isEquip(playerGoods.getString("key"))) continue;
                //抗性加护 （高级属性的累计）
                if (playerGoods.containsKey("kxlv")) {
                    JSONObject kxlv = playerGoods.getJSONObject("kxlv");
                    for (String p : kxlv.keySet()) {
                        int lv = kxlv.getInteger(p);
                        int kx = 50 * lv + (int) Math.pow(2d, lv);
                        String attrName = p.substring(0, 2) + "kx";
                        base.put(attrName, base.getFloat(attrName) + kx);
                    }
                }
            }
            //System.err.println(base);
        }

        /*if (zb != null) {
            for (String k : zb.keySet()) {
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods == null || playerGoods.getInteger("isBad") == 1 ||
                        !equipData.isEquip(playerGoods.getString("key"))) continue;
                JSONObject equip = equipData.getProp(playerGoods.getString("key"));
                //遍历包含的固定高级属性
                for (String e : equip.keySet()) {
                    if (roleUtils.isBaseProp(e) || equip.get(e) == null) {
                        continue;
                    }
                    float k0 = 1f;
                    //对于有绑定宝石的装备基础属性增加10%
                    if (playerGoods.containsKey("bdbs") &&
                            playerGoods.getInteger("bdbs") == 1) {
                        k0 += 0.1f;
                    }
                    //对于有刻印宝石的装备基础属性增加30%
                    if (playerGoods.containsKey("kybs") &&
                            playerGoods.getInteger("kybs") == 1) {
                        k0 += 0.3f;
                    }
                    //对于有血契宝石的装备基础属性增加60%
                    if (playerGoods.containsKey("xqbs") &&
                            playerGoods.getInteger("xqbs") == 1) {
                        k0 += 0.6f;
                    }
                    base.put(e, base.getFloat(e) + equip.getFloat(e) * k0);
                }
                //遍历保存在数据库的随机属性
                JSONObject randomAttr = playerGoods.getJSONObject("randomAttr");
                if (randomAttr != null) {
                    for (String e : randomAttr.keySet()) {
                        if (roleUtils.isBaseProp(e)) {
                            continue;
                        }
                        base.put(e, base.getFloat(e) + randomAttr.getFloat(e));
                    }
                }

                //计算锻造的加成（高级属性的累计）
                if (playerGoods.get("forging") != null &&
                        playerGoods.getJSONObject("forging").getInteger("lv") > 0) {
                    JSONObject obj = equipData.getAddAttrByForgingLv(playerGoods);
                    for (String attr : obj.keySet()) {
                        base.put(attr, base.getFloat(attr) + obj.getInteger(attr));
                    }
                }
                //计算镶嵌加成（高级属性的累计）
                if (playerGoods.get("inlay") != null &&
                        playerGoods.getJSONObject("inlay").getInteger("num") > 0 &&
                        playerGoods.getJSONObject("inlay").getJSONArray("list").size() > 0) {
                    JSONArray list = playerGoods.getJSONObject("inlay").getJSONArray("list");
                    for (Object o : list) {
                        JSONObject obj = (JSONObject) o;
                        String attr = baoshiUtils.getAttrName(obj.getString("key").substring(4));
                        base.put(attr, base.getFloat(attr) + obj.getInteger("num"));
                    }
                }
                //装备注魔加成 （高级属性的累计） {"key":"10100012","num":10}
                if (playerGoods.containsKey("czmb")) {
                    JSONObject czmb = playerGoods.getJSONObject("czmb");
                    //JSONObject mbMsg= equipData.getMoban(czmb.getString("key"));
                    float k0 = czmb.getFloat("num") / equipData.getMbMaxMoLi(czmb.getString("key"));
                    if (k0 > 1) k0 = 1f;
                    JSONObject attr = equipData.getMoBanMaxAttr(czmb.getString("key"));
                    for (String p : attr.keySet()) {
                        float kx = attr.getFloat(p) * k0;
                        base.put(p, base.getFloat(p) + kx);
                    }
                }
                //抗性加护 （高级属性的累计）
                if (playerGoods.containsKey("kxlv")) {
                    JSONObject kxlv = playerGoods.getJSONObject("kxlv");
                    for (String p : kxlv.keySet()) {
                        int lv = kxlv.getInteger(p);
                        int kx = 50 * lv + (int) Math.pow(2d, lv);
                        String attrName = p.substring(0, 2) + "kx";
                        base.put(attrName, base.getFloat(attrName) + kx);
                    }
                }
                //装备技能
                if (playerGoods.get("skill") != null &&
                        playerGoods.getJSONArray("skill").size() > 0) {
                    JSONArray list = playerGoods.getJSONArray("skill");
                    for (Object o : list) {
                        JSONObject jb = (JSONObject) o;
                        //获取技能的加成属性
                        JSONArray arr = skillData.getAttrs(jb.getString("key"));
                        for (Object a : arr) {
                            JSONObject aa = (JSONObject) a;
                            String attr = aa.getString("name");
                            //去掉是5个基础属性的
                            if (roleUtils.isBaseProp(attr)) continue;
                            float v = skillData.count(jb.getInteger("lv"), aa);
                            base.put(attr, base.getFloat(attr) + v);
                        }
                    }
                }
                //计算装备刻印加成
                if (playerGoods.get("keyin") != null) {
                    JSONObject keyin = playerGoods.getJSONObject("keyin");
                    for (String p : keyin.keySet()) {
                        if (keyin.get(p) == null || keyin.getString(p).equals("")) continue;
                        JSONObject o = keyin.getJSONObject(p);
                        JSONObject attr = equipData.getKyAttr(o.getString("key"));
                        String kName = attr.getString("k");
                        if (roleUtils.isBaseProp(kName)) continue;
                        float forgingLv = 0;
                        if (o.get("forging") != null) {
                            forgingLv = o.getJSONObject("forging").getFloat("lv");
                        }
                        if (base.get(kName) == null) {
                            loggerUtils.error("属性异常[找不到]：" + kName, manService.class);
                            continue;
                        }
                        float v = base.getFloat(kName) + attr.getFloat("v") + attr.getFloat("v") * 0.0375f * forgingLv;
                        base.put(kName, v);
                    }
                }
            }
        }*/
        //法宝只看镶嵌孔，对人物、宠物、怪物三者额外的伤害跟减免交由战斗中计算
        if (zb != null && !zb.get("fb").equals("")) {
            JSONObject fb = zb.getJSONObject("fb");
            //String k = fb.getString("key");
            //镶嵌孔
            if (fb.get("inlay") != null &&
                    fb.getJSONObject("inlay").getInteger("num") > 0 &&
                    fb.getJSONObject("inlay").getJSONArray("list").size() > 0) {
                JSONArray list = fb.getJSONObject("inlay").getJSONArray("list");
                for (Object o : list) {
                    JSONObject obj = (JSONObject) o;
                    String attr = baoshiUtils.getAttrName(obj.getString("key").substring(4));
                    int max = baoshiUtils.getBaoshiAttr(obj.getString("key").substring(4));
                    int v = obj.getInteger("num");
                    if (v > max) v = max;
                    base.put(attr, base.getFloat(attr) + v);
                }
            }
            //验证灵气值是否存在，存在才生效
            if (fb.containsKey("zhuling")) {
                JSONObject zhuling = fb.getJSONObject("zhuling");
                if (zhuling.containsKey("lqz") && zhuling.getInteger("lqz") > 0 &&
                        fb.containsKey("forging")) {
                    JSONObject forging = fb.getJSONObject("forging");
                    //强化等级
                    int lv = forging.getInteger("lv");
                    //满级 人物56.5 35.92 宠物一样 怪物28.25 21.89
                    //强化类型 针对的类型 人物、宠物、怪物
                    int type = forging.getInteger("type");
                    int quality = zhuling.getInteger("quality");
                    //float addHurt = 0.1f * (quality - 1) + 0.01f * quality + 0.005f * lv * quality;
                    //float cutHurt = 0.1f * (quality - 1) + 0.01f * quality + 0.003f * lv * quality;
                    float addHurt = 0.01f * quality + 0.0107f * lv;
                    float cutHurt = 0.00625f * quality + 0.0066875f * lv;
                    if (type == 2) {//怪物需要除以2
                        addHurt /= 2f;
                        cutHurt /= 2f;
                    }
                    JSONObject a = new JSONObject();
                    a.put("addHurt", addHurt);
                    a.put("cutHurt", cutHurt);
                    a.put("type", type);
                    //生效时才有该属性，灵气没有时则不需要计算
                    //法宝增伤、减伤效果，战斗最后计算时要用type判断
                    base.put("fbEffect", a);
                }
            }


        }

        if (zb != null && !zb.get("hf").equals("")) {
            JSONObject hf = zb.getJSONObject("hf");
            String k = hf.getString("key");
            //需要声望等级
            int lv = 0;
            if (msg.containsKey("swdj")) {
                lv = msg.getJSONObject("swdj").getInteger("lv");
            }
            List<fbResult> list = equipData.getHuFuResult(k);
            for (fbResult f : list) {
                base.put(f.key, base.getFloat(f.key) + f.getV(lv));
            }
        }

        //功法计算最终属性
        if (zb != null && !zb.get("gf").equals("")) {
            JSONObject gf = zb.getJSONObject("gf");
            String k = gf.getString("key");
            List<fbResult> list = equipData.getFabaoResult(k);
            for (fbResult f : list) {
                if (f.key.contains("final_")) {
                    String key = f.key.split("_")[1];
                    base.put(key, base.getFloat(key) * (1 + f.getV(gf.getJSONObject("forging").getInteger("lv"))));
                }
            }
        }
        //fg 13330
        if (jn != null) {
            //固定值类型的计算一遍（基数），非固定值的类型计算一遍（增量）
            for (Object obj : jn) {
                if (obj == null) continue;
                JSONObject jb = (JSONObject) obj;
                if (!jb.containsKey("key")) continue;
                //获取技能的加成属性
                JSONArray arr = skillData.getAttrs(jb.getString("key"));
                for (Object a : arr) {
                    JSONObject aa = (JSONObject) a;
                    //不是固定值的去掉
                    if (aa.getInteger("valueType") == 1) continue;
                    String attr = aa.getString("name");
                    //去掉是5个基础属性的
                    if (roleUtils.isBaseProp(attr)) continue;
                    float v = skillData.count(jb.getInteger("lv"), aa);
                    base.put(attr, base.getFloat(attr) + v);
                }
            }
        }//fg 13950
        //至此固定的属性基数已经计算完成，开始计算增益
        String[] rateKeys = {"max_xue", "max_lan",
                "wg", "fg", "wf", "ff",
                "mz", "sd", "bj", "css",
                "bjkx", "hskx", "hlkx", "lxkx"};
        //存储每个属性的增益比例
        JSONObject rateMap = new JSONObject();
        for (String k : rateKeys) {
            rateMap.put(k, 1);
        }

        if (jn != null) {
            //JSONObject copyBase = JSON.parseObject(JSON.toJSONString(base));
            for (Object obj : jn) {
                if (obj == null) continue;
                JSONObject jb = (JSONObject) obj;
                if (!jb.containsKey("key")) continue;
                //获取技能的加成属性
                JSONArray arr = skillData.getAttrs(jb.getString("key"));
                for (Object a : arr) {
                    JSONObject aa = (JSONObject) a;
                    //不是比例值的去掉
                    if (aa.getInteger("valueType") != 1) continue;
                    String attr = aa.getString("name");
                    //去掉是5个基础属性的
                    if (roleUtils.isBaseProp(attr)) continue;
                    //float v = skillData.countByK(jb.getInteger("lv"), aa, copyBase);
                    //base.put(attr, base.getFloat(attr) + v);
                    //累计增益比例
                    rateMap.put(attr, rateMap.getFloat(attr) +
                            skillData.count(jb.getInteger("lv"), aa));
                }
            }
        }

        //橙装加成（提升所有高级属性）
        if (zb != null) {
            //橙装加成 1->0% 2->2% 3->4% 4->7% 5->10% 6->14% 7->18% 8->25% 9->35%
            int num = 0;
            float rate = 1f;
            for (String k : zb.keySet()) {
                if (zb.getString(k).equals("")) continue;
                JSONObject playerGoods = zb.getJSONObject(k);
                if (playerGoods != null && equipData.isEquip(playerGoods.getString("key")) &&
                        equipData.isGoldEquip(playerGoods.getString("key"))) {
                    num++;
                }
            }
            float[] rates = {0f, 0f, 0.02f, 0.04f, 0.07f, 0.1f,
                    0.14f, 0.18f, 0.25f, 0.35f,};
            rate = rates[num];
            //全属性增加rate
            for (String p : rateKeys) {
                //base.put(p, base.getFloat(p) * rate);
                //累计增益比例
                //抗性加成需按rates，其他属性加成则按0.01*num
                if (p.equals("bjkx") || p.equals("hskx") || p.equals("hlkx") || p.equals("lxkx")) {
                    rateMap.put(p, rateMap.getFloat(p) + rate);
                } else if (p.equals("max_xue")) {
                    rateMap.put(p, rateMap.getFloat(p) + rate * 16f);
                } else if (p.equals("wf") || p.equals("ff")) {
                    rateMap.put(p, rateMap.getFloat(p) + rate * 2f);
                } else {
                    rateMap.put(p, rateMap.getFloat(p) + 0.01f * num);
                }
            }
        }
        //魔神等级计算最终属性
        if (msLv != null) {
            //每个等级对于的加成百分比
            for (String k : msLv.keySet()) {
                int lv = msLv.getInteger(k);
                if (k.equals("lv1")) {//攻击
                    rateMap.put("wg", rateMap.getFloat("wg") + 0.03f * lv);
                    rateMap.put("fg", rateMap.getFloat("fg") + 0.03f * lv);
                } else if (k.equals("lv2")) {//防御
                    rateMap.put("wf", rateMap.getFloat("wf") + 0.03f * lv);
                    rateMap.put("ff", rateMap.getFloat("ff") + 0.03f * lv);
                } else if (k.equals("lv3")) {//生命
                    rateMap.put("max_xue", rateMap.getFloat("max_xue") + 0.03f * lv);
                } else if (k.equals("lv4")) {//速度
                    rateMap.put("css", rateMap.getFloat("css") + 0.05f * lv);
                    rateMap.put("sd", rateMap.getFloat("sd") + 0.02f * lv);
                } else if (k.equals("lv5")) {//命中
                    rateMap.put("mz", rateMap.getFloat("mz") + 0.03f * lv);
                } else if (k.equals("lv6")) {//魔法
                    rateMap.put("max_lan", rateMap.getFloat("max_lan") + 0.03f * lv);
                } else if (k.equals("lv7")) {//暴击
                    rateMap.put("bj", rateMap.getFloat("bj") + 0.03f * lv);
                }
            }
        }
        if (shenfu != null && strUtils.getTime() < shenfu.getLong("end")) {
            my.model.shenfu sf = shenFuData.get(shenfu.getString("sf_key"));
            JSONArray arr = sf.getAttrs();
            for (Object a : arr) {
                JSONObject aa = (JSONObject) a;
                //不是比例值的去掉
                if (aa.getInteger("valueType") != 1) continue;
                String attr = aa.getString("name");
                //去掉是5个基础属性的
                if (roleUtils.isBaseProp(attr)) continue;
                //float v = skillData.countByK(jb.getInteger("lv"), aa, copyBase);
                //base.put(attr, base.getFloat(attr) + v);
                //累计增益比例
                rateMap.put(attr, rateMap.getFloat(attr) +
                        skillData.count(1, aa));
            }
        }
        //计算最终增益后的结果
        for (String p : rateKeys) {
            base.put(p, base.getFloat(p) * rateMap.getFloat(p));
        }

        JSONObject prop = role.getJSONObject("attr").getJSONObject("prop");
        float xue = prop.getFloat("xue");
        if (xue > base.getFloat("max_xue")) {
            xue = base.getFloat("max_xue");
        }
        base.put("xue", xue);
        base.put("lan", prop.getFloat("lan"));
        base.put("exp", prop.getFloat("exp"));
        //对属性小于0的处理
        for (String k : base.keySet()) {
            //法宝效果不需要验证
            if (k.equals("fbEffect")) continue;
            float v = base.getFloat(k);
            if (v < 0) v = 0f;
            base.put(k, v);
        }
        return base;
    }

    public JSONObject countStarAttr(int lv, String model) {
        JSONObject obj = new JSONObject();
        obj.put("wg", 30 * lv);
        obj.put("fg", 30 * lv);
        obj.put("max_xue", 200 * lv);
        obj.put("wf", 20 * lv);
        obj.put("ff", 20 * lv);
        obj.put("max_lan", 100 * lv);
        obj.put("bj", 20 * lv);
        obj.put("mz", 30 * lv);
        obj.put("css", 10 * lv);
        obj.put("sd", 15 * lv);

        if (model.indexOf("ms_") > -1) {
            obj.put("wg", 60 * lv);
            obj.put("mz", 40 * lv);
        } else if (model.indexOf("dj_") > -1) {
            obj.put("max_xue", 300 * lv);
            obj.put("wf", 40 * lv);
            obj.put("ff", 40 * lv);
        } else if (model.indexOf("qm_") > -1) {
            obj.put("fg", 60 * lv);
            obj.put("bj", 40 * lv);
        } else if (model.indexOf("ty_") > -1) {
            obj.put("fg", 40 * lv);
            obj.put("bj", 40 * lv);
            obj.put("wf", 30 * lv);
            obj.put("ff", 30 * lv);
        } else if (model.indexOf("ym_") > -1) {
            obj.put("wg", 60 * lv);
            obj.put("css", 30 * lv);
            obj.put("sd", 30 * lv);
        } else if (model.indexOf("lc_") > -1) {
            obj.put("css", 30 * lv);
            obj.put("sd", 30 * lv);
            obj.put("wf", 30 * lv);
            obj.put("ff", 30 * lv);
        }
        return obj;
    }

    /**
     * 升级计算
     */
    /*public void countLv(JSONObject j) {
        int lv = j.getInteger("lever");
        if (lv >= 100) return;
        int inputExp = j.getInteger("inputExp");
        int max_exp = getExpData(lv).intValue();
        if (lv < 30) {//小于30就直接计算等级
            if (inputExp >= max_exp) {
                inputExp -= max_exp;
                lv += 1;
                j.put("inputExp", inputExp);
                j.put("lever", lv);
                this.countLv(j);
            }
        } else {
            //不加等级，对超出5倍的经验裁剪
            if (inputExp > max_exp * 5) {
                j.put("inputExp", max_exp * 5);
            }
        }
    }*/
    public void countLv(JSONObject j) {
        int lv = j.getInteger("lever");
        if (lv >= 100) return;
        int inputExp = j.getInteger("inputExp");
        Double jy = getExpData(lv);
        int max_exp = new Double(jy).intValue();
        if (inputExp >= max_exp) {
            inputExp -= max_exp;
            lv += 1;
            j.put("inputExp", inputExp);
            j.put("lever", lv);
            this.countLv(j);
        }
    }

    /**
     * 获取当前等级提升到下一级所需经验
     */
    private Double getExpData(Integer lever) {
        return lever * 100 + 2 * Math.pow(5, 0.1 * lever);
    }

    /**
     * 切磋开关
     */
    public result setStatusPk(JSONObject obj,
                              @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        JSONObject status = new JSONObject();
        JSONObject pk = new JSONObject();
        pk.put("isOpen", obj.get("isOpen"));
        status.put("pk", pk);
        return new result(200, saveStatus(user.name, status, con));
    }

    /**
     * 是否允许pk
     */
    public int isAllowedPk(String name, DefaultSqlSession con) {
        JSONObject status = getStatusData(name, con);
        return status.getJSONObject("pk").getInteger("isOpen");
    }

    /**
     * 是否打开了补给包
     */
    public int isAllowedBjb(String name, DefaultSqlSession con) {
        JSONObject status = getStatusData(name, con);
        return status.getJSONObject("bjb").getInteger("isOpen");
    }

    /**
     * 补给包开关
     */
    public result setStatusBjb(JSONObject obj,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        JSONObject status = new JSONObject();
        JSONObject a = new JSONObject();
        a.put("isOpen", obj.get("isOpen"));
        status.put("bjb", a);
        return new result(200, saveStatus(user.name, status, con));
    }

    /**
     * 上线时关闭状态栏计时开关
     */
    private void closeStatusByOnline(String name, DefaultSqlSession con) {
        String[] arr = getStatusLanKeys();
        JSONObject status = getStatusData(name, con);
        boolean isUpdate = false;
        JSONObject newStatus = new JSONObject();
        for (String k : arr) {
            if (status.containsKey(k)) {
                JSONObject a = status.getJSONObject(k);
                if (a.getInteger("isOpen") == 1) {
                    a.put("isOpen", 0);
                    newStatus.put(k, a);
                    isUpdate = true;
                }
            }
        }
        if (isUpdate) {
            saveStatus(name, newStatus, con);
        }
    }

    /**
     * 下线玩家或者过期玩家，数据库需要结算时间
     */
    public void closeStatus(List<String> names) {
        String[] arr = getStatusLanKeys();
        //存放需要关闭状态的key
        List<String> keys = new ArrayList<>();
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            for (String name : names) {
                JSONObject status = getStatusData(name, con);
                JSONObject newStatus = new JSONObject();
                boolean isUpdate = false;
                keys.clear();
                for (String k : arr) {
                    if (status.containsKey(k)) {
                        JSONObject a = status.getJSONObject(k);
                        if (a.getInteger("isOpen") == 1) {
                            long sy = a.getLong("sy");
                            long created = a.getLong("created");
                            sy = sy - (strUtils.getTime() - created);
                            if (sy <= 0) a.remove("sy");
                            else a.put("sy", sy);

                            a.put("isOpen", 0);
                            newStatus.put(k, a);
                            isUpdate = true;

                            keys.add(k);
                        }
                    }
                }
                if (isUpdate) {
                    //通知关闭状态
                    ChannelSupervise.noticeClientByName(keys, name, "854");
                    saveStatus(name, newStatus, con);
                }
                mybatisConfig.commit(con);
            }
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 角色状态栏的处理
     */
    private boolean isHandleStatus = false;

    public void statusHandle() {
        if (isHandleStatus) return;
        isHandleStatus = true;
        long now = strUtils.getTime();
        try {
            //下线玩家或者过期玩家，数据库需要结算时间
            List<String> names = new ArrayList<>();
            for (String name : staticCollection.roleStatusMap.keySet()) {
                if (!staticCollection.userIsOnline(name)) {
                    staticCollection.roleStatusMap.remove(name);
                    names.add(name);
                    continue;
                }
                user u = staticCollection.getUserByName(name);
                JSONObject status = staticCollection.roleStatusMap.get(name);

                String[] arr = getStatusLanKeys();
                for (String k : arr) {
                    if (status.containsKey(k)) {
                        JSONObject a = status.getJSONObject(k);
                        if (a.getInteger("isOpen") == 1 && a.containsKey("sy")) {
                            long sy = a.getLong("sy");
                            long created = a.getLong("created");
                            sy = sy - (now - created);
                            if (sy <= 0) {
                                a.remove("sy");
                                a.put("isOpen", 0);
                                names.add(name);
                                continue;
                            }
                            a.put("sy", sy);
                            a.put("created", now);

                            if (k.equals("ydxc")) {//诱敌香草效果
                                //是否在野区/是否是队长/是否处于战斗中
                                String mapKey = u.getPos().getString("map");
                                int t = startBef.teamService.isTeamAndCaptain(name);
                                if (mapKey != null && mapKey.length() > 2 &&
                                        (mapKey.substring(0, 2).equals("m_") ||
                                                mapKey.substring(0, 4).equals("dmkj")) &&
                                        (t != 0) &&
                                        fightUtils.isAllowedFight(name)) {
                                    //通知遇怪
                                    ChannelSupervise.noticeClientByName(1, name, "853");
                                }
                            }

                        }
                    }
                }

                ChannelSupervise.noticeClientByName(status, name, "857");
            }

            closeStatus(names);
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            isHandleStatus = false;
        }
    }

    /**
     * 将状态加入缓存
     */
    private void addStatusToMap(String name, DefaultSqlSession con) {
        JSONObject status = getStatusData(name, con);
        status.remove("pk");
        status.remove("bjb");
        staticCollection.roleStatusMap.put(name, status);
        ChannelSupervise.noticeClientByName(status, name, "857");
    }

    /**
     * 使用道具后，状态栏初始化（造化丹等）
     */
    public JSONObject userStatusLan(String key, String name, DefaultSqlSession con) {
        long now = strUtils.getTime();
        JSONObject a = new JSONObject();
        a.put("isOpen", 1);
        a.put("created", now);
        a.put("sy", 60 * 60 * 1000);//持续1小时

        JSONObject j = getStatusData(name, con);
        if (j.containsKey(key)) {
            JSONObject old = j.getJSONObject(key);
            //将上次的结余
            if (old.getInteger("isOpen") == 1 && old.containsKey("sy")) {
                long sy = old.getLong("sy");
                long created = old.getLong("created");
                sy = sy - (now - created);
                old.put("sy", sy);
                old.put("created", now);
            }
            //时长延长
            if (old.containsKey("sy")) {
                a.put("sy", old.getLong("sy") + a.getLong("sy"));
                //不允许超出26小时
                if (a.getLong("sy") > 26 * 60 * 60 * 1000) return null;
            }
        }

        JSONObject newStatus = new JSONObject();
        newStatus.put(key, a);
        int r = saveStatus(name, newStatus, con);
        if (r == 1) {
            addStatusToMap(name, con);
            return a;
        }
        return null;
    }

    private String[] getStatusLanKeys() {
        String[] arr = {"rwzhd", "cwzhd", "ydxc", "qdxc", "blx", "jml", "dblq"};
        return arr;
    }

    private boolean isContainStatusLanKey(String key) {
        String[] arr = getStatusLanKeys();
        for (String a : arr) {
            if (a.equals(key)) return true;
        }
        return false;
    }

    /**
     * 判断某些状态是否打开
     */
    public boolean isStatusOpen(String statusKey, String name) {
        JSONObject status = staticCollection.roleStatusMap.get(name);
        if (status == null) return false;
        JSONObject a = null;
        if (status.containsKey(statusKey)) {
            a = status.getJSONObject(statusKey);
        }
        if (a != null && a.containsKey("isOpen") && a.getInteger("isOpen") == 1) return true;
        return false;
    }

    /**
     * 状态栏开关
     * 诱敌香草启用后，服务端会每10s主动推送一次遇怪
     * （前端要判断是否在野区，是否为队长等，不由服务器主动触发战斗）
     */
    public result setStatusLan(JSONObject obj,
                               @paramsAnno(key = "user") user user,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int isOpen = obj.getInteger("isOpen");
        String key = obj.getString("key");
        //判断是否为计时型状态开关
        if (!isContainStatusLanKey(key)) {
            return new result(0);
        }
        JSONObject status = getStatusData(name, con);
        JSONObject a = null;
        if (!status.containsKey(key)) {
            a = new JSONObject();
        } else {
            a = status.getJSONObject(key);
        }
        if (!a.containsKey("sy")) {
            //未使用道具的情况，使用后会有一个小时的剩余时间
            //前端需要提示是否使用道具
            return new result(200, -1);
        }

        a.put("isOpen", isOpen);
        if (isOpen == 1) {
            //启用的时间，当下线跟关闭时要用当前时间减去这个启用时间，得到剩余时间
            a.put("created", strUtils.getTime());
        } else {
            //关闭时要结算剩余时长
            long sy = a.getLong("sy");
            long created = a.getLong("created");
            sy = sy - (strUtils.getTime() - created);
            if (sy <= 0) a.remove("sy");
            else a.put("sy", sy);
        }
        JSONObject newStatus = new JSONObject();
        newStatus.put(key, a);
        saveStatus(user.name, newStatus, con);
        //放入缓存
        addStatusToMap(name, con);
        return new result(200, a);
    }

    /**
     * 保存状态栏
     */
    private Integer saveStatus(String name, JSONObject obj, DefaultSqlSession con) {
        if (obj.keySet().size() == 0) return 0;
        JSONObject j = getStatusData(name, con);
        for (String k : obj.keySet()) {
            j.put(k, obj.get(k));
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.updateStatusByName(JSON.toJSONString(j), name) ? 1 : 0;
    }

    /**
     * 获取玩家基本信息
     */
    public result getPlayerBaseMsg(JSONObject obj,
                                   @paramsAnno(key = "con") DefaultSqlSession con) {
        String playerName = obj.getString("playerName");
        if (staticCollection.getUserByName(playerName) == null) {
            return new result(831);
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        //从视图中获取
        List<JSONObject> list = jsonMapper.getPlayerMsgView(playerName);
        JSONObject j = list.get(0);
        JSONObject msg = JSON.parseObject(j.getString("msg"));
        JSONObject res = new JSONObject();
        res.put("model", j.get("model"));
        res.put("models", j.get("models"));
        res.put("lever", j.get("lever"));
        res.put("bp", "无");
        if (!msg.getString("bp").equals("")) {
            JSONObject bp = msg.getJSONObject("bp");
            res.put("bp", bp.getString("name"));
        }
        return new result(200, res);
    }

    /**
     * 获取玩家信息
     */
    public result getPlayerMsg(JSONObject obj,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        String playerName = obj.getString("playerName");
        user playerUser = null;
        if ((playerUser = staticCollection.getUserByName(playerName)) == null) {
            return new result(831);
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        //从视图中获取
        List<JSONObject> list = jsonMapper.getPlayerMsgView(playerName);
        JSONObject j = list.get(0);
        //把数据库存放json格式数据的转对象
        JSONObject msg = JSON.parseObject(j.getString("msg"));
        //msg.put("sf", getSf(msg.getInteger("sez")));
        msg.put("vip", j.getInteger("jf"));
        j.remove("jf");
        msg.remove("gold");
        msg.remove("tale");
        msg.remove("yp");
        msg.remove("jf");
        msg.remove("wxz");
        msg.remove("bg");
        msg.remove("jmPoint");
        msg.remove("bb");
        msg.remove("xld");
        msg.remove("ldjf");
        msg.remove("cbjf");
        msg.remove("jungong");
        msg.remove("realmLv");
        j.put("prop", JSON.parseObject(j.getString("prop")));
        j.put("msg", msg);
        j.put("equip", JSON.parseObject(j.getString("equip")));
        j.put("petEquip", startBef.packageService.getPetEquip(playerName, con));
        j.put("skill", JSON.parseArray(j.getString("skill")));
        j.put("star", JSON.parseObject(j.getString("star")));
        j.put("msLv", startBef.yhmkService.getMoShenLv(playerName, con));
        j.put("shenfu", playerUser.msg.get("shenfu"));
        if (list.size() > 0) {
            return new result(200, j);
        }
        return new result(0);
    }

    /**
     * 消耗的传负值
     * 保存货币(累计、正负值)
     */
    public Integer saveMoney(Integer moneyType, Long value, String name, DefaultSqlSession con) {
        if (moneyType == 0 && value > 0) {
            String sb = value + "元宝 " + StackTraceUtils.getAllTag();
            if (systemUtils.isWindows()) {
                System.err.println(sb);
            } else {
                startBef.logService.insertOp("7", name, sb, null, "1");
            }
        } else if (moneyType == 1 && value > 0) {
            String sb = value + "银两 " + StackTraceUtils.getAllTag();
            if (systemUtils.isWindows()) {
                System.err.println(sb);
            } else {
                startBef.logService.insertOp("7", name, sb, null, "1");
            }
        }
        JSONObject msg = getMsgData(name, con);
        if (msg == null || value == null) {
            loggerUtils.error("值为空", this.getClass());
            return 0;
        }
        long v = Long.parseLong(value.toString());
        if (v == 0) {
            loggerUtils.error("saveMoney 值为0", this.getClass());
            return 0;
        }

        JSONObject money = new JSONObject();
        String key = rewardUtils.getKeyByMoneyType(moneyType);
        if (key == null) {
            loggerUtils.error("无此对应类型：" + moneyType + "," + money, this.getClass());
            return 0;
        }
        if (msg.get(key) == null) {
            /*loggerUtils.error("玩家" + name + "的msg中没有属性" + key, this.getClass());
            return 0;*/
            //当字段中没有该属性则加上
            msg.put(key, 0);
        }

        long a = msg.getLong(key) + v;
        if (a < 0) {//金额出现小于0
            loggerUtils.error("玩家金额出现小于0 " + name, this.getClass());
            return 0;
        }
        money.put(key, a);
        if (saveMsg(name, money, con) == 0) {
            loggerUtils.error("玩家保存msg时失败 " + name, this.getClass());
            return 0;
        }
        return 1;
    }

    /**
     * 保存玩家属性信息
     */
    public Integer saveMsg(String name, JSONObject obj, DefaultSqlSession con) {
        if (obj.keySet().size() == 0) return 0;
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        //先查询出整个json，再替换键值，最后保存
        List<JSONObject> ls = jsonMapper.selectMsg(name);
        //该玩家不存在
        if (ls.size() == 0) return 0;
        JSONObject j = ls.get(0).getJSONObject("msg");
        for (String k : obj.keySet()) {
            if (obj.get(k) == null) {
                System.err.println("saveMsg保存一个null：" + k);
                return 0;
            }
            //2147483647   2147483647
            if (rewardUtils.isMoneyType(k)) {
                //最大值处理
                if (j.getLong(k) > Integer.MAX_VALUE) {
                    j.put(k, Integer.MAX_VALUE);
                }
                if (j.getInteger(k) < 0) {
                    System.err.println("saveMsg保存一个值小于0：" + k);
                    return 0;
                }
            }
            j.put(k, obj.get(k));
        }
        return jsonMapper.updateMsgByName(JSON.toJSONString(j), name) ? 1 : 0;
    }

    /**
     * 获取属性
     */
    public JSONObject getProp(String name, SqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.selectProp(name).get(0).getJSONObject("prop");
    }

    /**
     * 保存属性
     */
    public Integer saveProp(String name, JSONObject obj, DefaultSqlSession con) {
        if (obj.keySet().size() == 0) return 0;
        //先查询出整个json，再替换键值，最后保存
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        JSONObject j = jsonMapper.selectProp(name).get(0).getJSONObject("prop");
        for (String k : obj.keySet()) {
            if (obj.get(k) == null) {
                System.err.println("saveProp保存一个null：" + k);
                return 0;
            }
            j.put(k, obj.get(k));
        }
        return jsonMapper.updatePropByName(JSON.toJSONString(j), name) ? 1 : 0;
    }

    /**
     * 获取技能
     */
    public JSONArray getSkill(String name, SqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.selectSkill(name).get(0).getJSONArray("skill");
    }

    public Integer saveSkill(JSONArray list, String name, DefaultSqlSession con) {
        if (list.size() == 0) return 0;
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.updateSkillByName(JSON.toJSONString(list), name) ? 1 : 0;
    }

    /**
     * 获取玩家属性页信息数据
     */
    public JSONObject getMsgData(String name, SqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectMsg(name);
        if (list.size() > 0) {
            return list.get(0).getJSONObject("msg");
        }
        return null;
    }

    /**
     * 获取仙人秘法
     */
    public JSONObject getXrmf(String name, SqlSession con) {
        JSONObject a = getMsgData(name, con);
        if (a.get("xrmf") == null) return null;
        return a.getJSONObject("xrmf");
    }

    /**
     * 获取状态栏
     */
    public JSONObject getStatusData(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.selectStatusByName(name).get(0).getJSONObject("status");
    }

    /**
     * 载入角色
     */
    public Object loadMsg(@paramsAnno(key = "user") user user,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //需要将状态栏计时相关的开关关闭
        this.closeStatusByOnline(name, con);
        //获取玩家上线的所有信息(角色属性、宠物属性、任务、背包、邮件)
        //玩家属性
        JSONObject manAttr = (JSONObject) getMsg(name, con);
        //宠物列表
        JSONArray petList = startBef.petService.getList(name, con);
        //伙伴列表
        JSONArray huobanList = new JSONArray();
        //任务列表
        Object taskMap = startBef.taskService.getAllTask(name, con);
        //背包 (包含背包数量，仓库数量)
        Object goods = startBef.packageService.getGoodsMsg(name, con);
        //邮件
        Object emails = startBef.emailService.initEmailList(name, con);
        //好友
        Object friendList = startBef.friendService.getFriendList(name, con);
        //拥有的称号
        Object titles = getTitleByName(name, con);
        //拥有的翅膀
        Object wings = getWingsByName(name, con);
        //拥有的坐骑
        Object zuoqi = getZuoqiByName(name, con);
        //拥有的形象
        Object models = getModels(name, con);
        //初始化必要的user数据
        initSetting(user, manAttr, petList, huobanList);
        //上线日志
        startBef.logService.insertOnlineLog(name);
        //操作日志
        startBef.logService.insertOp("0", name, "上线", null, "1");

        JSONObject res = new JSONObject();
        res.put("manAttr", manAttr);
        res.put("petList", petList);
        res.put("huobanList", huobanList);
        res.put("taskMap", taskMap);
        res.put("goods", goods);
        res.put("emails", emails);
        res.put("friendList", friendList);
        res.put("titles", titles);
        res.put("wings", wings);
        res.put("zuoqi", zuoqi);
        res.put("models", models);
        return new result(200, res);
    }

    /**
     * 获取玩家拥有的坐骑
     */
    public Object getZuoqiByName(String name, SqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.getZuoqi(name);
        if (list.size() == 0) {
            jsonMapper.addZuoqi(name);
            return new JSONArray();
        }
        return list.get(0).getJSONArray("zuoqi");
    }

    /**
     * 完成一些上线的初始化设置
     */
    private void initSetting(user user, JSONObject manAttr, JSONArray petList, JSONArray huobanList) {
        //载入角色时需要设置一些user数据
        JSONObject msg = manAttr.getJSONObject("msg");
        user.msg.put("pos", user.initPos());
        user.msg.put("sez", msg.get("sez"));
        user.msg.put("ch", msg.get("ch"));
        user.msg.put("wings", msg.get("wings"));
        user.msg.put("zuoqi", msg.get("zuoqi"));
        user.msg.put("vip", msg.get("vip"));
        if (!strUtils.isNull(msg.getString("bp"))) {
            user.msg.put("bpId", msg.getJSONObject("bp").get("Id"));
        }
        //查询出战宠物的key
        for (Object a : petList) {
            JSONObject pet = (JSONObject) a;
            if (pet.getInteger("isFight") == 1) {
                JSONObject m = new JSONObject();
                m.put("key", pet.get("key"));
                if (pet.getInteger("growLv") >= 8) m.put("isX8", true);
                else m.put("isX8", false);
                user.msg.put("pet", m);
                break;
            }
        }
        //查询出战的伙伴
        JSONArray hbList = new JSONArray();
        for (Object a : huobanList) {
            JSONObject hb = (JSONObject) a;
            if (hb.getInteger("isFight") == 1) {
                JSONObject m = new JSONObject();
                m.put("key", hb.get("key"));
                hbList.add(m);
            }
        }
        user.msg.put("hbList", hbList);

        //金装的类型
        JSONObject equip = manAttr.getJSONObject("equip");
        user.msg.put("goldType", getGoldType(equip));
        //神符效果 sf_key,end
        user.msg.put("shenfu", manAttr.get("shenfu"));
        //系统设置
        sysSettingUtils.init(user.name);
    }

    public int getGoldType(JSONObject equip) {
        //通缉橙装的数量
        int num = 0;
        for (String k : equip.keySet()) {
            if (equip.getString(k).equals("")) continue;
            JSONObject playerGoods = equip.getJSONObject(k);
            if (playerGoods != null && equipData.isEquip(playerGoods.getString("key")) &&
                    equipData.isGoldEquip(playerGoods.getString("key"))) {
                num++;
            }
        }
        //0-2 3个档位 -1就是没有橙装效果
        int lever = getGoldType(num);
        return lever;
    }

    /**
     * 根据数量来获取goldType
     */
    private int getGoldType(int num) {
        if (num > 0 && num < 4) return 0;
        else if (num >= 6 && num < 9) return 1;
        else if (num >= 9) return 2;
        else return -1;
    }

    /**
     * 由装备获取goldType
     */
    public int getGoldType(String name, DefaultSqlSession con) {
        JSONObject equip = getEquipDataView(name, con);
        return getGoldType(equip);
    }

    /**
     * 保存装备
     */
    public Integer saveEquip(String name, JSONObject obj, DefaultSqlSession con) {
        if (obj.keySet().size() == 0) {
            return 0;
        }
        //先查询出整个json，再替换键值，最后保存
        JSONObject j = startBef.manService.getEquipData(name, con);
        for (String k : obj.keySet()) {
            j.put(k, obj.get(k));
        }
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.updateEquip(JSON.toJSONString(j), name) ? 1 : 0;
    }

    /**
     * 获取装备
     */
    public JSONObject getEquipData(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.selectEquip(name).get(0).getJSONObject("equip");
    }

    public JSONObject getEquipDataView(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.selectEquipView(name).get(0).getJSONObject("equip");
    }

    /**
     * 获取玩家拥有的称号
     */
    public Object getTitleByName(String name, SqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.getTitle(name);
        if (list.size() == 0) {
            jsonMapper.addTitle(name);
            return new JSONArray();
        }
        return list.get(0).getJSONArray("titles");
    }

    /**
     * 获取玩家拥有的称号
     */
    public Object getWingsByName(String name, SqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.getWings(name);
        if (list.size() == 0) {
            jsonMapper.addWings(name);
            return new JSONArray();
        }
        return list.get(0).getJSONArray("wings");
    }

    /**
     * 获取玩家等级
     */
    public Integer getRoleLv(String name, DefaultSqlSession con) {
        return this.getRole(name, con).getInteger("lever");
    }

    /**
     * 由角色名获取角色信息
     */
    public JSONObject getRole(String name, SqlSession con) {
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        List<JSONObject> list = roleMapper.getRoleViewByName(name);
        if (list.size() > 0)
            return list.get(0);
        return null;
    }

    /**
     * 模糊查询
     */
    public List<JSONObject> getRoleByLikeName(String name, List filterName, long pageNum, long pageSum, SqlSession con) {
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        List<JSONObject> list = roleMapper.getRoleByLikeName(name, filterName, pageNum, pageSum);
        return list;
    }

    /**
     * 获取角色所有属性信息
     */
    private Object getMsg(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = jsonMapper.selectAllAttr(name);
        if (list.size() == 0) {
            return null;
        }
        JSONObject j = list.get(0);
        JSONObject prop = j.getJSONObject("prop");
        JSONObject msg = j.getJSONObject("msg");
        //msg.put("sf", getSf(msg.getInteger("sez")));
        JSONObject equip = j.getJSONObject("equip");
        JSONArray skill = j.getJSONArray("skill");
        JSONObject status = j.getJSONObject("status");
        //升星
        JSONObject star = j.getJSONObject("star");
        //vip
        msg.put("vip", j.getInteger("jf"));
        j.remove("jf");
        //把数据库存放json格式数据的转对象
        j.put("prop", prop);
        j.put("msg", msg);
        j.put("equip", equip);
        j.put("petEquip", startBef.packageService.getPetEquip(name, con));
        j.put("skill", skill);
        j.put("status", status);
        j.put("star", star);
        j.put("msLv", startBef.yhmkService.getMoShenLv(name, con));
        j.put("shenfu", startBef.shenfuService.getShenFu(name, con));
        return j;
    }

    private String getSf(int sez) {
        if (sez == 0) {//魔头
            return "魔头";
        } else if (sez < 3) {//恶人
            return "恶人";
        } else if (sez == 10) {//英雄
            return "英雄";
        } else if (sez > 7) {//侠士
            return "侠士";
        }
        return "平民";
    }
}
