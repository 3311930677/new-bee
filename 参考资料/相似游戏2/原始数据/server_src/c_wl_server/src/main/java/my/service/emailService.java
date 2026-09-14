package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.jsonMapper;
import my.data.equipData;
import my.data.goodsData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.runTask;
import my.model.user;
import my.startBef;
import my.utils.loggerUtils;
import my.utils.runTaskUtils;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.Iterator;
import java.util.List;
import java.util.concurrent.TimeUnit;

public class emailService {
    /**
     * 拉取某个邮件
     */
    public result getOne(JSONObject j, @paramsAnno(key = "user") user user,
                         @paramsAnno(key = "con") DefaultSqlSession con) {
        JSONArray list = this.initEmailList(user.name, con);
        for (Object l : list) {
            if (((JSONObject) l).getString("Id").equals(j.getString("Id"))) {
                return new result(200, l);
            }
        }
        return new result(0);
    }

    /**
     * 读取邮件
     */
    public result readEmail(JSONObject j, @paramsAnno(key = "user") user user,
                            @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray list = initEmailList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(j.getString("Id"))) {
                obj.put("isRead", 1);
                break;
            }
        }
        return new result(200, updateEmail(list, name, con));
    }

    /**
     * 删除邮件
     */
    public result delEmailByType(JSONObject j, @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        //0删除已读 1删除所有（两者都是除了未接取的）
        Integer type = j.getInteger("type");
        if (type == null) return new result(0);
        JSONArray list = initEmailList(name, con);
        for (int i = 0; i < list.size(); i++) {
            JSONObject obj = list.getJSONObject(i);
            //未接取的附件除外
            if ((obj.get("enclosure") != null && (obj.getJSONArray("enclosure")).size() > 0) ||
                    obj.getInteger("tale") > 0) {
                if (obj.getInteger("isObtain") == 0) continue;
            }
            if (type == 0 && obj.getInteger("isRead") == 1) {//删除已读，
                list.remove(i);
                i--;
            } else if (type == 1) {//删除全部
                list.remove(i);
                i--;
            }
        }
        return new result(200, updateEmail(list, name, con));
    }

    /**
     * 退邮
     */
    public result tuihuiEmail(JSONObject j, @paramsAnno(key = "user") user user,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        String id = j.getString("Id");
        if (strUtils.isNull(id)) return new result(0);
        if (backEmail(id, name, "玩家拒接", con, false) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        return new result(200, 1);
    }

    /**
     * 删除邮件
     */
    public result delEmail(JSONObject j, @paramsAnno(key = "user") user user,
                           @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        JSONArray list = initEmailList(name, con);
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(j.getString("Id"))) {
                //付费邮件未接取则不允许删除
                if (obj.getInteger("price") > 0 && obj.getInteger("isObtain") == 0) {
                    return new result(0);
                }
                list.remove(l);
                break;
            }
        }
        return new result(200, updateEmail(list, name, con));
    }

    public boolean isOverMaxEmail(String name, DefaultSqlSession con) {
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> myEmails = dao.selectEmail(name);
        if (myEmails.size() >= 40) {
            return true;
        }
        return false;
    }

    /**
     * 发送邮件
     */
    public result sendGoodsEmail(JSONObject j,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        if (strUtils.isNull(j.get("receiver")) ||
                j.getInteger("price") == null || j.getInteger("price") < 0 ||
                j.getInteger("price") > 999999999 ||
                j.getInteger("tale") == null || j.getInteger("tale") < 0 ||
                j.getInteger("tale") > 999999999 ||
                (j.get("enclosure") != null && j.getJSONArray("enclosure").size() > 3)) {
            return new result(0);
        }
        final String sender = user.name;
        j.put("sender", sender);
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        String receiver = j.getString("receiver");
        if (isOverMaxEmail(receiver, con)) {
            return new result(852);
        }
        if (isOverMaxEmail(sender, con)) {
            return new result(222);
        }
        //扣除发送者的物品、银两、元宝等
        if (j.getInteger("tale") != null && j.getInteger("tale") > 0) {
            long tale = -j.getInteger("tale");
            if (tale >= 0) return new result(0);
            if (startBef.manService.saveMoney(1, tale, sender, con) != 1) {
                return new result(0);
            }
        }
        //设置了价格但没用附件的情况
        if (j.getInteger("price") > 0 &&
                (j.get("enclosure") == null && j.getJSONArray("enclosure").size() == 0)) {
            return new result(0);
        }
        JSONArray enclosure = new JSONArray();
        if (j.get("enclosure") != null && j.getJSONArray("enclosure").size() > 0) {
            //附件
            boolean isNeedBeiBao = false;
            boolean isNeedPet = false;
            JSONArray js = j.getJSONArray("enclosure");
            for (Object e1 : js) {
                //先确定需要查哪些数据
                JSONObject obj2 = (JSONObject) e1;
                if (obj2.getInteger("num") <= 0) {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
                int enType = obj2.getInteger("enType");
                if (enType == 0) isNeedBeiBao = true;//需要背包数据
                else if (enType == 1) isNeedPet = true;//需要宠物数据
                else return new result(0);
            }
            JSONArray beibao = null;
            JSONArray petList = null;
            if (isNeedBeiBao) {
                beibao = startBef.packageService.getGoods(sender, con);
            }
            if (isNeedPet) {
                petList = startBef.petService.getList(sender, con);
            }

            for (int i = 0; i < js.size(); i++) {
                //附件
                JSONObject obj2 = js.getJSONObject(i);
                int enType = obj2.getInteger("enType");
                if (enType == 0) {
                    //遍历背包
                    if (handleBeiBao(beibao, js, i, enclosure) != 1) {
                        //出现数量<0的情况
                        mybatisConfig.rollback(con);
                        return new result(0);
                    }
                } else if (enType == 1) {
                    //遍历宠物
                    if (handlePet(petList, js, i, enclosure) != 1) {
                        //出现数量<0的情况
                        mybatisConfig.rollback(con);
                        return new result(0);
                    }
                }
                //System.err.println("传入附件id："+obj2.get("Id"));
            }
            if (isNeedBeiBao) {
                //减去发送者背包道具
                if (startBef.packageService.savePackage(beibao, sender, con) != 1) {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
            }
            if (isNeedPet) {
                if (startBef.petService.savePetList(petList, sender, con) != 1) {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
            }
        }
        j.put("enclosure", enclosure);
        if (this.email(j, con) != 1) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        if (j.getInteger("price") > 0) {
            String id = j.getString("Id");
            //将未退回的邮件放入数据库
            dao.addEmailBack(strUtils.getId(), id, receiver);
            //对于付费邮件要加入延时处理任务中
            runTaskUtils.addTask(new runTask(() -> {
                this.overTimeNoGet(id, receiver);
            }, 5 * 60 * 1000));
        }
        //邮件发送给玩家（两个操作：1把邮件保存到数据库，2将生成的id发送给client，通知他由这个id更新拉取）
        return new result(200, 1);
    }

    /**
     * ps背包列表 obj2附件项
     */
    private int handleBeiBao(JSONArray beibao, JSONArray js, int index, JSONArray enclosure) {
        JSONObject obj2 = js.getJSONObject(index);
        //遍历发送者背包
        for (Object e2 : beibao) {
            //fixme 注意：（刷数据）一定不能用原附件属性，一定要替换成背包对应的属性
            //发送方物品
            JSONObject obj = (JSONObject) e2;
            if (obj.getString("Id").equals(obj2.getString("Id"))) {
                //System.err.println("Id相同:"+obj.getString("Id"));
                //当物品中确切存在时才添加
                //天机残卷等特殊物品不允许邮件
                if (goodsData.isNoAllowedSend(obj)) {
                    break;
                }
                //为每个附件重新生成id
                JSONObject enclosureObj = staticCollection.copyObj(obj);
                enclosureObj.put("Id", strUtils.getId());
                enclosureObj.put("num", obj2.getInteger("num"));
                enclosureObj.put("enType", 0);//附件类型为背包道具，接取道具时注意要删除该字段
                enclosure.add(enclosureObj);

                obj.put("num", obj.getInteger("num") - obj2.getInteger("num"));
                if (obj.getInteger("num") < 0) {
                    return 0;//数据异常
                } else if (obj.getInteger("num") == 0) {
                    beibao.remove(e2);
                }
                break;
            }
        }
        return 1;
    }

    private int handlePet(JSONArray petList, JSONArray js, int index, JSONArray enclosure) {
        JSONObject obj2 = js.getJSONObject(index);
        //遍历发送者宠物列表
        for (Object e2 : petList) {
            //fixme 注意：（刷数据）一定不能用原附件属性，一定要替换成对应的属性
            //发送方宠物
            JSONObject obj = (JSONObject) e2;
            if (obj.getString("Id").equals(obj2.getString("Id"))) {
                //成长6以上则不允许邮寄
                if (obj.get("growLv") == null || obj.getInteger("growLv") >= 6) {
                    break;
                }
                //为每个附件重新生成id
                JSONObject enclosureObj = staticCollection.copyObj(obj);
                enclosureObj.put("Id", strUtils.getId());
                enclosureObj.put("num", obj2.getInteger("num"));
                enclosureObj.put("enType", 1);//附件类型为宠物，接取道具时注意要删除该字段
                enclosure.add(enclosureObj);

                petList.remove(e2);
                break;
            }
        }
        return 1;
    }

    /**
     * 将数据库记录尚未退回的邮件重新放入缓存
     */
    public void addBackEmailToCache() {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
            List<JSONObject> list = dao.selectAllEmailBack();
            dao.delAllEmailBack();
            mybatisConfig.commit(con);
            for (int i = 0; i < list.size(); i++) {
                String id = list.get(i).getString("email_id");
                String receiver = list.get(i).getString("email_receiver");
                //System.err.println("放入退邮数据"+id);
                runTaskUtils.addTask(new runTask(() -> {
                    this.overTimeNoGet(id, receiver);
                }, 5 * 60 * 1000));
            }

        } catch (Exception e) {
            mybatisConfig.rollback(con);
            e.printStackTrace();
        } finally {
            mybatisConfig.close(con);
        }
    }

    private void overTimeNoGet(String Id, String receiver) {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            this.backEmail(Id, receiver, "玩家超时未接取", con, true);
            mybatisConfig.commit(con);
        } catch (Exception e) {
            mybatisConfig.rollback(con);
            e.printStackTrace();
        } finally {
            mybatisConfig.close(con);
        }

    }

    /**
     * 发送系统邮件
     * 附件中需要带上enType字段确定宠物还是道具
     */
    public int sendSysEmail(String receiver, String content, Object[] enclosure, long tale, DefaultSqlSession con) {
        JSONObject msg = new JSONObject();
        msg.put("title", "系统邮件");
        msg.put("sender", "系统");
        msg.put("receiver", receiver);
        msg.put("content", content);
        msg.put("price", 0);
        msg.put("priceType", 1);
        msg.put("tale", tale);
        msg.put("enclosure", enclosure);
        return email(msg, con);
    }

    public Integer email(JSONObject j, DefaultSqlSession con) {
        //生成id、created、isRead、isObtain
        j.put("Id", strUtils.getId());
        j.put("created", strUtils.getTime() + "");
        j.put("isRead", 0);
        j.put("isObtain", 0);
        //保存邮件
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> arr = jsonMapper.selectEmail(j.getString("receiver"));
        if (arr.size() == 0) {
            //无该用户-退回
            //System.err.println("无该用户-退回");
            if (!j.getString("sender").equals("系统")) {//系统发的就不用退了
                String sender = j.getString("sender");
                noUserbackEmail(j, con);
                try {
                    ChannelSupervise.noticeClientByName(j.getString("Id"), sender, "802");
                } catch (Exception e) {
                    loggerUtils.error("回退邮件时通知异常：" + j + " " + e.getMessage(), this.getClass());
                }
            }
            return 1;
        }
        JSONArray list = arr.get(0).getJSONArray("email");
        list.add(j);
        //删除前面超过的部分
        if (list.size() > 40) {
            list.subList(0, list.size() - 40);
        }
        if (updateEmail(list, j.getString("receiver"), con) == 1) {
            //插入操作日志
            startBef.logService.insertOp("2", j.getString("sender"), "[发送邮件] "+j.toString(), j.getString("receiver"), "1");
            try {
                //通知client有新邮件
                ChannelSupervise.noticeClientByName(j.getString("Id"), j.getString("receiver"), "802");
            } catch (Exception e) {
                loggerUtils.error("邮件发送指定玩家失败:" + j + "" + e.getMessage(), this.getClass());
            }
            return 1;
        }
        return 0;
    }

    /**
     * 退信
     */
    public Integer noUserbackEmail(JSONObject j, DefaultSqlSession con) {
        //对方不在线，进行邮件回退
        j.put("title", "邮件退回");
        j.put("price", 0);
        j.put("receiver", j.getString("sender"));
        j.put("sender", "系统");
        j.put("content", "该玩家不存在！");
        //保存邮件
        JSONArray list = initEmailList(j.getString("receiver"), con);
        list.add(j);
        //删除前面超过的部分
        if (list.size() > 40) {
            list.subList(0, list.size() - 40);
        }
        return updateEmail(list, j.getString("receiver"), con);
    }

    /**
     * 长时间接取/遭到玩家退邮
     */
    public int backEmail(String Id, String name, String tip, DefaultSqlSession con, boolean isNoticeRemOld) {
        //先删除原接收者邮件
        JSONArray list = initEmailList(name, con);
        //删除后并原路返回
        JSONObject email = null;
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(Id)) {
                //必须付费邮件未接取
                if (obj.getInteger("price") > 0 && obj.getInteger("isObtain") == 0) {
                    email = obj;
                    list.remove(l);
                    break;
                } else {
                    return 0;
                }

            }
        }
        //说明已经提前退回
        if (email == null) return 0;

        if (updateEmail(list, name, con) != 1) {
            mybatisConfig.rollback(con);
            return 0;
        }
        String oldRec = email.getString("receiver");
        String oldId = email.getString("Id");
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        //删除数据库中未退回的数据
        dao.delAllEmailBackByRecAndId(Id, name);

        email.put("Id", strUtils.getId());
        email.put("title", "邮件退回");
        email.put("price", 0);
        email.put("receiver", email.getString("sender"));
        email.put("sender", "系统");
        email.put("content", tip);
        //保存邮件
        JSONArray arr = initEmailList(email.getString("receiver"), con);
        arr.add(email);
        //删除前面超过的部分
        if (arr.size() > 40) {
            arr.subList(0, arr.size() - 40);
        }
        int r = updateEmail(arr, email.getString("receiver"), con);
        if (r == 1) {
            try {
                //通知旧的收件人要删除缓存
                if (isNoticeRemOld)
                    ChannelSupervise.noticeClientByName(oldId, oldRec, "850");
                //通知新的接收者有新邮件
                ChannelSupervise.noticeClientByName(email.getString("Id"), email.getString("receiver"), "802");
            } catch (Exception e) {
                loggerUtils.error("邮件发送指定玩家失败:" + email + "" + e.getMessage(), this.getClass());
            }
        }
        return r;
    }

    /**
     * 更新邮件
     */
    private Integer updateEmail(JSONArray list, String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        return jsonMapper.updateEmail(JSON.toJSONString(list), name) ? 1 : 0;
    }

    /**
     * 获取玩家邮件
     */
    public JSONArray initEmailList(String name, DefaultSqlSession con) {
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        JSONArray list = jsonMapper.selectEmail(name).get(0).getJSONArray("email");
        if (list.size() > 40) {
            list.subList(0, list.size() - 40);
            updateEmail(list, name, con);
        }
        return list;
    }

    /**
     * 接取附件
     */
    public result getGoodsEmail(JSONObject data,
                                @paramsAnno(key = "user") user user,
                                @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        if (isOverMaxEmail(name, con)) {
            return new result(222);
        }
        JSONObject j = null;
        //判断是否接取过了
        JSONArray list = this.initEmailList(name, con);
        boolean isExist = false;
        for (Object l : list) {
            JSONObject obj = (JSONObject) l;
            if (obj.getString("Id").equals(data.getString("Id"))) {
                isExist = true;
                //是否接取过了
                if (obj.getInteger("isObtain") == 1) {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
                //设置为已接取
                obj.put("isObtain", 1);
                if (updateEmail(list, name, con) != 1) {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
                j = obj;
                break;
            }
        }
        if (!isExist) {
            mybatisConfig.rollback(con);
            return new result(0);
        }
        if (j.getInteger("price") < 0 || j.getInteger("tale") < 0) {
            mybatisConfig.rollback(con);
            return new result(0);
        }

        JSONObject msg = startBef.manService.getMsgData(name, con);

        //判断是否收费
        if (j.getInteger("price") > 0) {
            if (j.getInteger("priceType") == 1) {
                if (msg.get("tale") == null || msg.getInteger("tale") < 0 || j.getInteger("price") == null) {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
                //判断银两是否充足
                if (msg.getInteger("tale") - j.getInteger("price") < 0) {
                    //提示不足
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
                msg.put("tale", msg.getInteger("tale") - j.getInteger("price"));
                //startBef.manService.saveMoney(1, j.getInteger("price"), j.getString("sender"), con);
            } else {
                if (msg.get("gold") == null || msg.getInteger("gold") < 0 || j.getInteger("price") == null) {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
                //判断元宝是否充足
                if (msg.getInteger("gold") - j.getInteger("price") < 0) {
                    //提示不足
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
                msg.put("gold", msg.getInteger("gold") - j.getInteger("price"));
                //startBef.manService.saveMoney(0, j.getInteger("price"), j.getString("sender"), con);
            }
        }

        //判断是否有银两
        if (j.getInteger("tale") != null && j.getInteger("tale") > 0) {
            long tale = msg.getInteger("tale") + j.getInteger("tale");
            if (tale > Integer.MAX_VALUE) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
            msg.put("tale", tale);
        }
        if (j.getInteger("price") > 0 || j.getInteger("tale") > 0) {
            if (startBef.manService.saveMsg(name, msg, con) != 1) {
                mybatisConfig.rollback(con);
                return new result(0);
            }
        }

        //附件id对应真实id
        JSONObject res = new JSONObject();
        if (j.get("enclosure") != null && j.getJSONArray("enclosure").size() > 0) {
            JSONArray js = j.getJSONArray("enclosure");
            int bbgz = 0;//占用的背包格子
            int petgz = 0;//占用的宠物格子
            boolean isNeedBeiBao = false;
            boolean isNeedPet = false;
            for (int i = 0; i < js.size(); i++) {
                JSONObject obj = (JSONObject) js.get(i);
                int enType = obj.getInteger("enType");
                if (enType == 0) {
                    isNeedBeiBao = true;
                    bbgz++;
                } else if (enType == 1) {
                    isNeedPet = true;
                    petgz++;
                } else {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
            }
            JSONArray beibao = null;
            JSONArray petList = null;
            if (isNeedBeiBao) {
                JSONObject a = startBef.packageService.getGoodsMsg(name, con);
                beibao = a.getJSONArray("package");
                int bbSum = startBef.packageService.getNowBbn(beibao);
                if (a.getInteger("bbn") < bbSum + bbgz) {
                    mybatisConfig.rollback(con);
                    return new result(640);
                }
            }
            if (isNeedPet) {
                petList = startBef.petService.getList(name, con);
                if (20 < petList.size() + petgz) {
                    mybatisConfig.rollback(con);
                    return new result(764);
                }
            }
            //遍历附件
            for (int i = 0; i < js.size(); i++) {
                JSONObject obj = (JSONObject) js.get(i);
                int enType = obj.getInteger("enType");
                if (enType == 0) {
                    if (gainBeiBaoEnsHandle(beibao, js, i, res) != 1) {
                        mybatisConfig.rollback(con);
                        return new result(0);
                    }
                } else {
                    if (gainPetEnsHandle(petList, js, i, res) != 1) {
                        mybatisConfig.rollback(con);
                        return new result(0);
                    }
                }
            }
            if (isNeedBeiBao) {
                if (startBef.packageService.savePackage(beibao, name, con) != 1) {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
            }
            if (isNeedPet) {
                if (startBef.petService.savePetList(petList, name, con) != 1) {
                    mybatisConfig.rollback(con);
                    return new result(0);
                }
            }

        }

        //设置价格的邮件，对方提取后，商家未收到打款
        if (j.getInteger("price") > 0) {
            String sender = j.getString("sender");
            JSONArray rewards = new JSONArray();
            if (j.getInteger("priceType") == 0) {
                rewardUtils.getGoldReward(j.getInteger("price"), rewards);
                int gold = startBef.manService.getMsgData(sender, con).getInteger("gold");
                if (gold + j.getInteger("price") > Integer.MAX_VALUE) {
                    mybatisConfig.rollback(con);
                    return new result(203);
                }
            } else if (j.getInteger("priceType") == 1) {
                rewardUtils.getTaleReward(j.getInteger("price"), rewards);
                int tale = startBef.manService.getMsgData(sender, con).getInteger("tale");
                if (tale + j.getInteger("price") > Integer.MAX_VALUE) {
                    mybatisConfig.rollback(con);
                    return new result(203);
                }
            }
            //通知打款
            startBef.rewardService.saveRewards(rewards, sender, con);
            //通知奖励
            ChannelSupervise.noticeClientByName(rewards, sender, "10000");
            startBef.logService.insertOp("2", name, "[接取邮件] "+j.toString(), j.getString("sender"), "1");

        }

        return new result(200, res);
    }

    private int gainBeiBaoEnsHandle(JSONArray beibao, JSONArray ens, int index, JSONObject res) {
        JSONObject obj = ens.getJSONObject(index);
        boolean isAdd = true;
        //装备\法宝等不可叠加
        if (equipData.get(obj.getString("key")) != null) {
            isAdd = false;
        }
        //刻印不可叠加
        if (equipData.isKeyin(obj.getString("key"))) {
            isAdd = false;
        }
        if (isAdd) {//允许叠加
            Iterator<Object> pss = beibao.iterator();
            boolean b = false;
            //遍历背包
            while (pss.hasNext()) {
                JSONObject pbj = (JSONObject) pss.next();
                // fixme 允许叠加的就找未绑定并且相同key的，没有就新增
                if (pbj.getInteger("isBind") == 0 &&
                        pbj.getString("key").equals(obj.getString("key"))) {
                    b = true;
                    if (pbj.getInteger("num") == null || pbj.getInteger("num") <= 0) {
                        return 0;
                    }
                    pbj.put("num", pbj.getInteger("num") + obj.getInteger("num"));
                    //一次传送附件只可能是一个key
                    //附件id映射真实id
                    JSONObject t = new JSONObject();
                    t.put("Id", pbj.getString("Id"));//新id
                    t.put("enType", 0);//标志附件类型
                    res.put(obj.getString("Id"), t);
                    break;
                }
            }
            if (!b) {//没有该物品时
                obj.remove("enType");//去掉多余字段
                String Id = startBef.packageService.getId(beibao, strUtils.getId());
                JSONObject t = new JSONObject();
                t.put("Id", Id);//新id
                t.put("enType", 0);//标志附件类型
                res.put(obj.getString("Id"), t);
                obj.put("Id", Id);
                beibao.add(obj);
            }
        } else {//不允许叠加
            obj.remove("enType");//去掉多余字段
            String Id = startBef.packageService.getId(beibao, strUtils.getId());
            JSONObject t = new JSONObject();
            t.put("Id", Id);//新id
            t.put("enType", 0);//标志附件类型
            res.put(obj.getString("Id"), t);
            obj.put("Id", Id);
            beibao.add(obj);
        }
        return 1;
    }

    private int gainPetEnsHandle(JSONArray petList, JSONArray ens, int index, JSONObject res) {
        JSONObject obj = ens.getJSONObject(index);
        obj.remove("enType");//去掉多余字段
        String Id = startBef.packageService.getId(petList, strUtils.getId());
        JSONObject t = new JSONObject();
        t.put("Id", Id);//新id
        t.put("enType", 1);//标志附件类型
        res.put(obj.getString("Id"), t);
        obj.put("Id", Id);
        petList.add(obj);
        return 1;
    }
}
