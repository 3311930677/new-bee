package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.activityMapper;
import my.dao.jsonMapper;
import my.dao.roleMapper;
import my.dao.userMapper;
import my.db.mybatisConfig;
import my.model.auth;
import my.model.result;
import my.model.user;
import my.utils.emailUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.List;

import static my.utils.staticCollection.apkVersion;
import static my.utils.staticCollection.resVersion;


/**
 * 登录服务
 */
public class loginService {
    /**
     * 验证邮箱-获取验证码
     */
    public result getCode(JSONObject j,
                          @paramsAnno(key = "con") DefaultSqlSession con) {
        String username = j.getString("username");
        //已存在code，不再重新发送
        if (staticCollection.codes.get(username) != null) {
            return new result(200, 0);
        }
        userMapper userMapper = mybatisConfig.getMapper(con, userMapper.class);
        List<JSONObject> list = userMapper.getUserView(username);
        if (list.size() == 0) {
            return new result(200, 2);//未注册
        }
        //已注册
        //不存在时获取
        String email = list.get(0).getString("email");
        if (email == null) {
            return new result(200, 2);
        }
        String code = emailUtils.sendCode(email);
        JSONObject obj = new JSONObject();
        obj.put("created", strUtils.getTime());
        obj.put("code", code);
        obj.put("error", 0);
        obj.put("email", email);
        staticCollection.codes.put(username, obj);
        return new result(200, 1);
    }

    /**
     * 开关核验
     */
    public result openVerify(JSONObject j,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        String username = j.getString("username");
        String codeStr = j.getString("code");
        if (codeStr != null && !codeStr.trim().equals("")) {
            JSONObject code = staticCollection.codes.get(username);
            if (code == null || codeStr.trim().length() != 6) {
                return new result(200, 0);
            }
            if (!code.getString("code").equals(codeStr)) {
                code.put("error", code.getInteger("error") + 1);
                //3次匹配不对则销毁
                if (code.getInteger("error") >= 3) {
                    staticCollection.codes.remove(username);
                }
                //不匹配
                return new result(200, 0);
            }
            //验证成功后移除验证码
            staticCollection.codes.remove(username);
            userMapper dao = mybatisConfig.getMapper(con, userMapper.class);
            List<JSONObject> list = dao.getUserView(username);
            if (list.size() == 0) {
                return new result(200, 0);
            }
            int i = list.get(0).getInteger("verify") == 0 ? 1 : 0;
            dao.updateVerify(username, i + "");
            return new result(200, i == 1 ? 1 : 2);
        }
        return new result(200, 0);
    }

    /**
     * 创建角色
     */
    public result createRole(JSONObject j,
                             @paramsAnno(key = "ip") String ip,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        String name = j.getString("name");
        String projRootDir = j.getString("projRootDir");
        if (strUtils.isNull(name) || name.contains("系统") || name.length() > 6 ||
                name.contains("_") ||
                strUtils.isNull(projRootDir)) {
            return new result(605);//角色名重复
        }
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        //判断是否角色名重复
        if (roleMapper.getRoleViewByName(name).size() > 0) {
            return new result(605);//角色名重复
        }
        j.put("lever", 1);
        j.put("Id", strUtils.getId());
        JSONArray models = new JSONArray();
        models.add(j.getString("model"));
        j.put("models", models);
        if (roleMapper.insertRole(j.getString("Id"), j.getString("username"),
                name, j.getString("lever"), j.getString("model"), JSON.toJSONString(models))) {
            //创建成功后，初始化信息
            this.initData(name, con);
            JSONObject res = new JSONObject();
            user user = new user(ip, name, j.getInteger("lever"),
                    j.getString("model"), JSON.toJSONString(models));
            res.put("sbh", user.createSbh());//获取玩家信息使用
            //放置user初步信息，详细信息在ws连接之后附加
            staticCollection.putUser(res.getString("sbh"), user);
            //获取魔尊战斗信息(2d需要这个字段来判断是否切换到魔尊场景进行战斗)
            j.put("mzzd", 0);
            res.put("body", j);
            //返回角色信息
            return new result(200, res);
        }
        //服务器忙
        return new result(0);
    }

    /**
     * 绑定邮箱
     */
    public Integer bindEmail(String email, String username, DefaultSqlSession con) {
        userMapper userMapper = mybatisConfig.getMapper(con, userMapper.class);
        return userMapper.bindEamil(email, username) ? 1 : 0;
    }

    /**
     * 判断账号是否已经存在
     */
    public Integer isExist(String username, String password, String email, DefaultSqlSession con) {
        userMapper userMapper = mybatisConfig.getMapper(con, userMapper.class);
        List<JSONObject> list = userMapper.getUserView(username);
        if (list.size() > 0) {
            //账号存在,注册失败
            return 0;
        }
        return userMapper.insertUser(strUtils.getId(), username, password, strUtils.getTime() + "", email) ? 1 : 0;

    }

    /**
     * 是否超过3个账号
     */
    public Integer countEmailNum(String email, DefaultSqlSession con) {
        userMapper userMapper = mybatisConfig.getMapper(con, userMapper.class);
        return userMapper.countEmailNum(email).get(0).getInteger("n");
    }

    /**
     * 账号密码是否一致
     */
    public Integer isSame(JSONObject j, DefaultSqlSession con) {
        userMapper userMapper = mybatisConfig.getMapper(con, userMapper.class);
        List<JSONObject> list = userMapper.match(j.getString("username"), j.getString("password"));
        if (list.size() > 0) {
            return 1;
        }
        return 0;
    }

    /**
     * 是否绑定过邮箱
     */
    public Integer isBindEmail(String username, DefaultSqlSession con) {
        userMapper userMapper = mybatisConfig.getMapper(con, userMapper.class);
        List<JSONObject> list = userMapper.getUserView(username);
        if (list.size() == 0) return 2;
        if (list.get(0).get("email") != null &&
                !list.get(0).getString("email").trim().equals("")) return 1;
        return 0;
    }

    /**
     * 开启核验功能
     */
    public Object openVerify(JSONObject data) {

        return new result(200, 0);
    }

    /**
     * 登录
     */
    public Object login(JSONObject data,
                        @paramsAnno(key = "ip") String ip,
                        @paramsAnno(key = "con") org.apache.ibatis.session.defaults.DefaultSqlSession con) {
        //验证版本
        if (!staticCollection.apkVersion.equals(data.getString("apkVersion"))) {
            return new result(200, -1);
        }
        return new result(200, isMatch(
                data.getString("username"),
                data.getString("password"),
                data.getString("code"), ip, con));
    }

    /**
     * 验证账号密码是否匹配
     */
    public Object isMatch(String username, String password, String codeStr, String ip, SqlSession con) {
        //没有账号密码的绝对不能登录
        if (strUtils.isNull(username) || strUtils.isNull(password) ||
                username.length() > 30 || password.length() > 30) {
            return 0;
        }
        boolean isAllowedCode = false;
        //邮箱授权，跟邮箱code匹配，3次错误自动销毁
        if (!strUtils.isNull(codeStr)) {
            JSONObject code = staticCollection.codes.get(username);
            if (code == null || codeStr.trim().length() != 6) {
                return 0;
            }
            if (!code.getString("code").equals(codeStr)) {
                code.put("error", code.getInteger("error") + 1);
                //3次匹配不对则销毁
                if (code.getInteger("error") >= 3) {
                    staticCollection.codes.remove(username);
                }
                //不匹配
                return 0;
            }
            //验证成功后移除验证码
            staticCollection.codes.remove(username);
            isAllowedCode = true;
        }
        userMapper userMapper = mybatisConfig.getMapper(con, userMapper.class);
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        //授权后的登录逻辑
        List<JSONObject> list = userMapper.getUserView(username);
        //对于没有邮箱的账号拒绝登录
        if (list.size() == 0 || list.get(0).get("email") == null
                || list.get(0).getString("email").trim().equals("")) {
            return 2;
        }
        //对于黑名单的邮箱拒绝登录
        if (list.get(0).getInteger("ishei") == 1) {
            return 3;
        }
        //账号密码是否匹配
        if (!list.get(0).getString("password").equals(password)) {
            //账号密码不匹配
            return 5;
        }

        JSONArray ipList = list.get(0).getJSONArray("allowed_ip");
        //判断是否需要验证码来验证登录
        if (list.get(0).getInteger("verify") == 1) {
            //ip是否在授权ip的范围内
            if (isAllowedCode) {
                //邮箱code通过-要求账号密码邮箱验证
                if (ipList.size() >= 3) {
                    ipList.remove(0);
                }
                //置入授权的ip
                ipList.add(ip);
            } else {
                //code未通过时-只要求账号密码验证
                if (ipList.size() == 0) {
                    //未授权-需要先进行邮箱验证
                    return 4;
                }
                boolean isAllowed = false;
                for (Object ipStr : ipList) {
                    if (ipStr.equals(ip)) {
                        isAllowed = true;
                        break;
                    }
                }
                if (!isAllowed) {
                    //未授权
                    return 4;
                }
            }
        } else {
            //不需要邮箱核验
            if (ipList.size() >= 3) {
                ipList.remove(0);
            }
            //置入授权的ip
            ipList.add(ip);
        }

        //返回角色信息
        if (list.size() > 0) {
            userMapper.updateOnline(strUtils.getTime() + "", ip, JSON.toJSONString(ipList), username);
            //放入授权-有效时长是1分钟，1分钟后检测isSure=false就移除
            staticCollection.authMap.put(username, new auth(ipList.toArray()));
            list.clear();
            list.addAll(roleMapper.getRoleView(username));
            JSONObject res = new JSONObject();
            //对username+created加密
            res.put("secret", staticCollection.authMap.get(username).createMD5(username));//连接ws使用
            //判断是否有角色
            if (list.size() > 0) {
                user user = new user(ip, list.get(0).getString("name"),
                        list.get(0).getInteger("lever"),
                        list.get(0).getString("model"),
                        list.get(0).getString("models"));
                res.put("sbh", user.createSbh());//获取玩家信息使用
                //放置user初步信息，详细信息在ws连接之后附加
                staticCollection.putUser(res.getString("sbh"), user);
                //返回角色信息
                //获取魔尊战斗信息(2d需要这个字段来判断是否切换到魔尊场景进行战斗)
                List<JSONObject> al = roleMapper.findMzzd(user.name);
                if (al.size() == 0) {
                    roleMapper.insertMzzd("0", user.name);
                    JSONObject t = new JSONObject();
                    t.put("mzzd", 0);
                    al.add(t);
                }
                int mzzd = al.get(0).getInteger("mzzd");
                list.get(0).put("mzzd", mzzd);
                res.put("body", list.get(0));
            } else {
                //跳转创建角色
                res.put("body", 1);
            }
            return res;
        }
        //账号不存在
        return 6;
    }


    /**
     * 验证版本
     */
    public Object matchVersion(JSONObject data) {
        if (!data.getString("apkVersion").equals(apkVersion)) {
            return new result(200, 1);
        }
        if (!data.getString("resVersion").equals(resVersion)) {
            return new result(200, 2);
        }
        return new result(200, 0);
    }

    /**
     * 初始化数据
     *
     * @param name 角色名
     */
    private void initData(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);

        //是否跟魔尊战斗的信息（2d使用）
        roleMapper.insertMzzd("0", name);
        //角色基础属性，如力量等，根据角色等级、静脉等级、装备等计算，所以不需要初始化
        String json;
        //初始化属性
        JSONObject j = new JSONObject();
        //j.put("type", getType(model));//物理、法术
        j.put("xue", 100 + 1 * 5 + 1 * 3);
        j.put("lan", 50 + 1 * 5);
        j.put("exp", 0);
        json = JSON.toJSONString(j);
        jsonMapper.insertProp(json, name);
        //初始化信息
        j.clear();
        j.put("ch", "");
        j.put("stu2", "");//{name,qhd}
        j.put("stu3", "");
        j.put("stu1", "");
        j.put("bp", "");//name,Id
        //fixme 新服测试数据
        j.put("tale", 0);
        j.put("gold", 0);
        j.put("teacher", "");
        j.put("yp", 0);
        j.put("wxz", 0);
        j.put("jf", 0);
        j.put("bg", 0);
        j.put("xld", 0);//修炼点
        j.put("bb", 0);//帮币
        j.put("jmPoint", 0);//经脉可分配点数
        j.put("ldjf", 0);//领地积分
        j.put("cbjf", 0);//传壁积分
        j.put("jungong", 0);//军功
        j.put("sez", 5);//5点善恶-平民 2恶人 0魔头 8侠士 10英雄
        j.put("wings", "");
        j.put("realmLv", 0);//境界
        JSONObject temp = new JSONObject();
        temp.put("xrLv", 0);
        temp.put("xfLv", 0);
        j.put("xrmf", temp);//仙人秘法
        temp = new JSONObject();
        temp.put("lv", 0);
        temp.put("exp", 0);
        j.put("swdj", temp);//声望等级
        json = JSON.toJSONString(j);
        jsonMapper.insertMsg(json, name);
        //初始化装备
        j.clear();
        j.put("wq", "");
        j.put("jb", "");
        j.put("sz", "");
        j.put("wb", "");
        j.put("tb", "");
        j.put("xb", "");
        j.put("yb", "");
        j.put("tuib", "");
        j.put("jiaob", "");
        j.put("hf", "");
        j.put("fb", "");
        j.put("gf", "");
        j.put("bjb", "");
        json = JSON.toJSONString(j);
        jsonMapper.insertEquip(json, name);
        //初始化技能
        JSONArray list = new JSONArray();
        json = JSON.toJSONString(list);
        jsonMapper.insertSkill(json, name);
        //初始化状态
        j.clear();
        j.put("qdxc", getStatus());//驱敌香草
        j.put("sbjy", getStatus());//双倍经验
        j.put("ydxc", getStatus());//诱敌香草
        j.put("bjb", getStatus());//补给包开关
        j.put("pk", getStatus());//切磋开关
        json = JSON.toJSONString(j);
        jsonMapper.insertStatus(json, name);
        //升星
        j.clear();
        j.put("num", 0);//星数
        JSONObject attrs = new JSONObject();
        String[] as = {"wg", "fg", "max_xue", "wf", "ff",
                "max_lan", "bj", "mz", "css", "sd"};
        for (String a : as) {
            //0未点亮1点亮
            attrs.put(a, 0);
        }
        j.put("attr", attrs);
        json = JSON.toJSONString(j);
        jsonMapper.addManStar(name, json);
        //背包
        list.clear();
        json = JSON.toJSONString(list);
        jsonMapper.insertPackage(json, "150", "40", name);
        //任务
        list.clear();
        json = JSON.toJSONString(list);
        jsonMapper.insertTask(json, name);
        //任务完成表
        list.clear();
        json = JSON.toJSONString(list);
        jsonMapper.insertTaskSubmit(json, name);
        //宠物
        list.clear();
        json = JSON.toJSONString(list);
        jsonMapper.insertPet(json, name);
        //伙伴
        list.clear();
        json = JSON.toJSONString(list);
        jsonMapper.insertHuoban(name, json);
        //副本次数
        activityMapper.insertFb(name);
        //邮件
        list.clear();
        json = JSON.toJSONString(list);
        jsonMapper.insertEmail(json, name);
        //好友
        list.clear();
        json = JSON.toJSONString(list);
        roleMapper.insertFriend(json, name);
        //vip
        jsonMapper.addVip(name);
        //魔神等级
        jsonMapper.addYhmk(name);
    }

    private JSONObject getStatus() {
        JSONObject qdxc = new JSONObject();
        qdxc.put("created", 0);//开启时间
        qdxc.put("isOpen", 0);//是否打开
        return qdxc;
    }

    private String getJob(String key) {
        if (key.contains("ms")) return "猛士";
        else if (key.contains("dj")) return "遁甲";
        else if (key.contains("qm")) return "琴魔";
        else if (key.contains("ty")) return "天音";
        else if (key.contains("ym")) return "幽冥";
        else return "罗刹";
    }
}
