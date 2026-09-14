package my.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.dao.*;
import my.db.mybatisConfig;
import my.gameUtils.roleUtils;
import my.model.result;
import my.startBef;
import my.utils.staticCollection;
import my.utils.strUtils;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.*;

/**
 * 排行服务
 */
public class orderService {
    /**
     * 百战千军排行
     */
    public result getOrderBzqj(JSONObject obj,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        if (obj.get("type") == null) return new result(0);
        int type = obj.getInteger("type");
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        List<JSONObject> list = null;
        if (type == 0) {
            list = activityMapper.getSomeWHJX(150, 0);
        } else if (type == 1) {
            list = activityMapper.getSomeWHJX(300, 149);
        } else if (type == 2) {
            list = activityMapper.getSomeWHJX(600, 299);
        } else if (type == 3) {
            list = activityMapper.getSomeWHJX(1000, 599);
        } else if (type == 4) {
            list = activityMapper.getSomeWHJX(12000, 999);
        } else return new result(0);
        List<JSONObject> al = new ArrayList<>();
        for (int i = 0; i < list.size(); i++) {
            JSONObject a = list.get(i);
            a.put("order", i + 1);
            int jf = a.getInteger("jf");
            isBigToBef("jf", a.getString("name"), jf, al, true);
        }
        if (al.size() > 10)
            al = al.subList(0, 10);
        JSONObject res = new JSONObject();
        res.put("totalPage", 1);
        res.put("list", al);
        return new result(200, res);
    }

    /**
     * 人气值排行
     */
    public result getOrderSez(JSONObject obj,
                              @paramsAnno(key = "con") DefaultSqlSession con) {
        long pageNum = obj.getLong("pageNum");
        int type = obj.getInteger("type");
        if (pageNum < 1) {
            pageNum = 1;
        } else if (pageNum > 10) {
            pageNum = 10;
        }
        long pageSum = 10L;
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> aL = null;
        long n = 0;
        if (type == 0) {
            aL = jsonMapper.selectLvOrderSezShanByPage((pageNum - 1) * pageSum, pageSum);
            n = jsonMapper.selectLvOrderSezShanSum().get(0).getInteger("n");
        } else if (type == 1) {
            aL = jsonMapper.selectLvOrderSezEByPage((pageNum - 1) * pageSum, pageSum);
            n = jsonMapper.selectLvOrderSezESum().get(0).getInteger("n");
        }
        for (JSONObject a : aL) {
            a.put("order", a.getLong("sort") + 1);
            a.remove("sort");
        }

        long total = n % pageSum == 0 ? (n / pageSum) : (n / pageSum + 1);
        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", aL);
        return new result(200, res);
    }

    /**
     * 按职业来获取等级榜
     */
    public result getOrderLvByJob(JSONObject obj,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        long pageNum = obj.getLong("pageNum");
        int type = obj.getInteger("type");
        if (pageNum < 1) {
            pageNum = 1;
        } else if (pageNum > 10) {
            pageNum = 10;
        }
        long pageSum = 10L;
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> aL = null;
        long n = 0;
        if (type == 0) {
            aL = jsonMapper.selectLvOrderMsByPage((pageNum - 1) * pageSum, pageSum);
            n = jsonMapper.selectLvOrderMsSum().get(0).getInteger("n");
        } else if (type == 1) {
            aL = jsonMapper.selectLvOrderDjByPage((pageNum - 1) * pageSum, pageSum);
            n = jsonMapper.selectLvOrderDjSum().get(0).getInteger("n");
        } else if (type == 2) {
            aL = jsonMapper.selectLvOrderQmByPage((pageNum - 1) * pageSum, pageSum);
            n = jsonMapper.selectLvOrderQmSum().get(0).getInteger("n");
        } else if (type == 3) {
            aL = jsonMapper.selectLvOrderTyByPage((pageNum - 1) * pageSum, pageSum);
            n = jsonMapper.selectLvOrderTySum().get(0).getInteger("n");
        } else if (type == 4) {
            aL = jsonMapper.selectLvOrderYmByPage((pageNum - 1) * pageSum, pageSum);
            n = jsonMapper.selectLvOrderYmSum().get(0).getInteger("n");
        } else if (type == 5) {
            aL = jsonMapper.selectLvOrderLcByPage((pageNum - 1) * pageSum, pageSum);
            n = jsonMapper.selectLvOrderLcSum().get(0).getInteger("n");
        }
        for (int i = 0; i < aL.size(); i++) {
            JSONObject a = aL.get(i);
            a.put("order", (pageNum - 1) * pageSum + i + 1);
            a.remove("sort");
        }

        long total = n % pageSum == 0 ? (n / pageSum) : (n / pageSum + 1);
        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", aL);
        return new result(200, res);
    }

    /**
     * 获取等级排名
     */
    public result getOrderLv(JSONObject obj,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        long pageNum = obj.getLong("pageNum");
        if (pageNum < 1) {
            pageNum = 1;
        } else if (pageNum > 10) {
            pageNum = 10;
        }
        long pageSum = 10L;
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> aL = jsonMapper.selectLvOrderByPage((pageNum - 1) * pageSum, pageSum);
        for (int i = 0; i < aL.size(); i++) {
            JSONObject a = aL.get(i);
            a.put("order", (pageNum - 1) * pageSum + i + 1);
            a.remove("sort");
        }
        long n = jsonMapper.selectLvOrderSum().get(0).getInteger("n");
        long total = n % pageSum == 0 ? (n / pageSum) : (n / pageSum + 1);
        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", aL);
        return new result(200, res);
    }

    /**
     * 战力榜
     * 每十分钟计算一次，然后放入缓存，这里只看缓存
     */
    public result getOrderZL(JSONObject obj,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        long pageNum = obj.getLong("pageNum");
        if (pageNum < 1) {
            pageNum = 1;
        } else if (pageNum > 10) {
            pageNum = 10;
        }
        long pageSum = 10L;
        jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> aL = jsonMapper.selectZlOrderByPage((pageNum - 1) * pageSum, pageSum);
        for (JSONObject a : aL) {
            a.put("order", a.getInteger("sort") + 1);
            a.remove("sort");
        }
        long n = jsonMapper.selectZlOrderSum().get(0).getInteger("n");
        long total = n % pageSum == 0 ? (n / pageSum) : (n / pageSum + 1);
        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", aL);
        return new result(200, res);
    }

    /**
     * 天梯榜
     */
    public result getOrderTt(JSONObject obj,
                             @paramsAnno(key = "con") DefaultSqlSession con) {
        long pageNum = obj.getLong("pageNum");
        if (pageNum < 1) {
            pageNum = 1;
        } else if (pageNum > 10) {
            return new result(0);
        }
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        int num = activityMapper.getTtViewSum().get(0).getInteger("n");
        int total = num % 10 == 0 ? (num / 10) : (num / 10 + 1);
        if (pageNum > total) {
            JSONObject res = new JSONObject();
            res.put("totalPage", total);
            res.put("list", new JSONArray());
            return new result(200, res);
        }
        long pageSum = 10;
        List<JSONObject> list = activityMapper.getTtView((pageNum - 1) * pageSum, pageSum);
        for (int i = 0; i < list.size(); i++) {
            list.get(i).put("order", (pageNum - 1) * pageSum + i + 1);
        }
        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", list);
        return new result(200, res);
    }

    /**
     * 绩点排行（从视图中查询，避免锁表）
     */
    public result getOrderByJd(JSONObject obj,
                               @paramsAnno(key = "con") DefaultSqlSession con) {
        Integer type = obj.getInteger("type");
        //0个人竞技 1排位
        if (type != 0 && type != 1) {
            return new result(0);
        }
        long pageNum = obj.getLong("pageNum");
        if (pageNum < 1) {
            pageNum = 1;
        } else if (pageNum > 10) {
            return new result(0);
        }
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        int num = 0;
        if (type == 0) {
            num = activityMapper.getJJViewSum().get(0).getInteger("n");
        } else if (type == 1) {
            num = activityMapper.getPWViewSum().get(0).getInteger("n");
        }
        int total = num % 10 == 0 ? (num / 10) : (num / 10 + 1);
        if (pageNum > total) {
            JSONObject res = new JSONObject();
            res.put("totalPage", total);
            res.put("list", new JSONArray());
            return new result(200, res);
        }
        long pageSum = 10;
        List<JSONObject> list = null;
        if (type == 0) {
            list = activityMapper.getJdFromJJView((pageNum - 1) * pageSum, pageSum);
        } else if (type == 1) {
            list = activityMapper.getJdFromPWView((pageNum - 1) * pageSum, pageSum);
        }
        for (int i = 0; i < list.size(); i++) {
            list.get(i).put("order", (pageNum - 1) * pageSum + i + 1);
        }
        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", list);
        return new result(200, res);
    }

    /**
     * 论贱排行
     */
    public result getOrderLunjian(JSONObject obj,
                                  @paramsAnno(key = "con") DefaultSqlSession con) {
        long pageNum = obj.getLong("pageNum");
        if (pageNum < 1) {
            pageNum = 1;
        }
        activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
        int num = activityMapper.getLunjianSum().get(0).getInteger("num");
        int total = num % 10 == 0 ? (num / 10) : (num / 10 + 1);
        if (pageNum > total) {
            JSONObject res = new JSONObject();
            res.put("totalPage", total);
            res.put("list", new JSONArray());
            return new result(200, res);
        }
        long pageSum = 10;
        List<JSONObject> list = activityMapper.getLunJianPetSignOrder(null, (pageNum - 1) * pageSum, pageSum);
        for (int i = 0; i < list.size(); i++) {
            list.get(i).put("order", (pageNum - 1) * pageSum + i + 1);
        }
        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", list);
        return new result(200, res);
    }

    /**
     * 帮战排行
     */
    public result bzOrder(@paramsAnno(key = "con") DefaultSqlSession con) {
        gangsMapper dao = mybatisConfig.getMapper(con, gangsMapper.class);
        List<JSONObject> list = dao.selectGangsAndFightByOrder();
        for (int i = 0; i < list.size(); i++) {
            list.get(i).put("order", i + 1);
        }
        JSONObject res = new JSONObject();
        res.put("totalPage", 1);
        res.put("list", list);
        return new result(200, res);
    }

    /**
     * 获取世界boss排行
     */
    public result getWorldBossOrder(JSONObject obj) {
        List<Map.Entry<String, Integer>> list = new ArrayList<>(staticCollection.hurtMap.entrySet());
        Collections.sort(list, new Comparator<Map.Entry<String, Integer>>() {
            //升序排序
            public int compare(Map.Entry<String, Integer> o1,
                               Map.Entry<String, Integer> o2) {
                return -o1.getValue().compareTo(o2.getValue());
            }
        });
        List<JSONObject> aList = new ArrayList<>();
        int len = (obj.getInteger("pageNum") - 1) * 10 + 10 > list.size() ?
                list.size() - (obj.getInteger("pageNum") - 1) * 10 : (obj.getInteger("pageNum") - 1) * 10 + 10;
        for (int i = (obj.getInteger("pageNum") - 1) * 10; i < len; i++) {
            JSONObject n = new JSONObject();
            n.put("order", i + 1);
            n.put("name", list.get(i).getKey());
            n.put("value", list.get(i).getValue());
            aList.add(n);
        }
        int totalPage = list.size() / 10 > 10 ? 10 : (list.size() % 10 == 0 ? list.size() / 10 : list.size() / 10 + 1);
        JSONObject res = new JSONObject();
        res.put("list", aList);
        res.put("totalPage", totalPage);
        return new result(200, res);
    }

    /**
     * 获取土豪排名
     * 银两、元宝
     * 全查询（前100放入缓存，元宝、银两发生更新时比较这100个）
     */
    /*public result getOrderTuHao(JSONObject obj) {
        int pageNum = obj.getInteger("pageNum");
        int type = obj.getInteger("type");
        if (pageNum < 1) {
            pageNum = 1;
        } else if (pageNum > 10) {
            pageNum = 10;
        }
        List<JSONObject> aL = null;
        if (type == 0) {
            aL = staticCollection.orderData.get("goldList");
        } else {
            aL = staticCollection.orderData.get("taleList");
        }
        return new result(200, getOrderByPage(pageNum, 10, aL));
    }*/

    /**
     * 获取侠义排名
     */
    /*public result getOrderXiayi(JSONObject obj) {
        int pageNum = obj.getInteger("pageNum");
        int type = obj.getInteger("type");
        if (pageNum < 1) {
            pageNum = 1;
        } else if (pageNum > 10) {
            pageNum = 10;
        }
        List<JSONObject> aL = null;
        if (type == 0) {
            aL = staticCollection.orderData.get("yingxiongList");
        } else {
            aL = staticCollection.orderData.get("motouList");
        }
        return new result(200, getOrderByPage(pageNum, 10, aL));
    }*/
    public JSONObject getOrderByPage(int pageNum, int pageSum, List<JSONObject> aL) {
        List<JSONObject> list = new ArrayList<>();
        int start = (pageNum - 1) * pageSum;
        int end = pageNum * pageSum;
        if (aL.size() <= end) {
            end = aL.size();
        }
        for (int i = start; i < end; i++) {
            list.add(JSON.parseObject(JSON.toJSONString(aL.get(i))));
            list.get(i - start).put("order", i + 1);
        }
        int total = aL.size() % pageSum == 0 ? aL.size() / pageSum : aL.size() / pageSum + 1;
        JSONObject res = new JSONObject();
        res.put("totalPage", total);
        res.put("list", list);
        return res;
    }

    private void orderToDB(String type, Set<String> arr, DefaultSqlSession con) throws Exception {
        if (arr != null && arr.size() > 0) {
            jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
            List<JSONObject> list = null;
            //清理一次，因为重新排序后需要重新入库
            if (type.equals("lvList")) {
                list = dao.selectLvOrder();
                dao.delLvOrder();
            } else if (type.equals("msList")) {
                list = dao.selectLvOrderMs();
                dao.delLvOrderMs();
            } else if (type.equals("djList")) {
                list = dao.selectLvOrderDj();
                dao.delLvOrderDj();
            } else if (type.equals("qmList")) {
                list = dao.selectLvOrderQm();
                dao.delLvOrderQm();
            } else if (type.equals("tyList")) {
                list = dao.selectLvOrderTy();
                dao.delLvOrderTy();
            } else if (type.equals("ymList")) {
                list = dao.selectLvOrderYm();
                dao.delLvOrderYm();
            } else if (type.equals("lcList")) {
                list = dao.selectLvOrderLc();
                dao.delLvOrderLc();
            } else if (type.equals("yingxiongList")) {
                list = dao.selectLvOrderSezShan();
                dao.delLvOrderSezShan();
            } else if (type.equals("motouList")) {
                list = dao.selectLvOrderSezE();
                dao.delLvOrderSezE();
            }
            mybatisConfig.commit(con);
            //将缓存的名单先加入即将入库的集合
            List al = new ArrayList();
            for (String a : arr) {
                al.add(a);
            }
            if (type.equals("yingxiongList") || type.equals("motouList")) {
                boolean asc = type.equals("motouList") ? false : true;
                jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
                List<JSONObject> mL = jsonMapper.getPlayerMsgByNames(al);
                for (int i = 0; i < mL.size(); i++) {
                    JSONObject a = mL.get(i);
                    JSONObject msg = a.getJSONObject("msg");
                    JSONObject obj = new JSONObject();
                    obj.put("model", roleUtils.getModel(a));
                    obj.put("name", a.get("name"));
                    obj.put("lever", a.get("lever"));
                    obj.put("sez", msg.get("sez"));
                    isBigToBef("sez", obj.getString("name"), obj
                            , list, asc, new String[]{"model", "lever"});
                }
            } else {
                //将最新需要更改的名单加入其中
                roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
                List<JSONObject> mL = roleMapper.getRolesMsg(al);
                for (int i = 0; i < mL.size(); i++) {
                    JSONObject obj = mL.get(i);
                    obj.put("model", roleUtils.getModel(obj));
                    isBigToBef("lever", obj.getString("name"), obj
                            , list, true, new String[]{"model"});
                }
            }
            //将重新排好的数据进行入库
            for (int i = 0; i < list.size(); i++) {
                if (i >= 100) break;
                JSONObject obj = list.get(i);
                if (type.equals("lvList")) {
                    dao.addLvOrder(obj.getString("name"), obj.getString("lever"), obj.getString("model"), i + "");
                } else if (type.equals("msList")) {
                    dao.addLvOrderMs(obj.getString("name"), obj.getString("lever"), obj.getString("model"), i + "");
                } else if (type.equals("djList")) {
                    dao.addLvOrderDj(obj.getString("name"), obj.getString("lever"), obj.getString("model"), i + "");
                } else if (type.equals("qmList")) {
                    dao.addLvOrderQm(obj.getString("name"), obj.getString("lever"), obj.getString("model"), i + "");
                } else if (type.equals("tyList")) {
                    dao.addLvOrderTy(obj.getString("name"), obj.getString("lever"), obj.getString("model"), i + "");
                } else if (type.equals("ymList")) {
                    dao.addLvOrderYm(obj.getString("name"), obj.getString("lever"), obj.getString("model"), i + "");
                } else if (type.equals("lcList")) {
                    dao.addLvOrderLc(obj.getString("name"), obj.getString("lever"), obj.getString("model"), i + "");
                } else if (type.equals("yingxiongList")) {
                    dao.addLvOrderSezShan(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sez"), i + "");
                } else if (type.equals("motouList")) {
                    dao.addLvOrderSezE(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sez"), i + "");
                }

                mybatisConfig.commit(con);
            }
        }
    }

    /**
     * 定时计算排行
     */
    private boolean ishandleOrder = false;

    public void handleOrder() {
        if (ishandleOrder) return;
        ishandleOrder = true;
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            //jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
            //查询当前等级排行榜
            //List<JSONObject> zlList = dao.selectZlOrder();
            synchronized (staticCollection.orderDataNames) {
                Map<String, Set<String>> orderDataNames = staticCollection.orderDataNames;
                Set<String> lvList = orderDataNames.get("lvList");
                reCountLvOrder("lvList", lvList, con);
                lvList.clear();
                Set<String> msList = orderDataNames.get("msList");
                reCountLvOrder("msList", msList, con);
                msList.clear();
                Set<String> djList = orderDataNames.get("djList");
                reCountLvOrder("djList", djList, con);
                djList.clear();
                Set<String> qmList = orderDataNames.get("qmList");
                reCountLvOrder("qmList", qmList, con);
                qmList.clear();
                Set<String> tyList = orderDataNames.get("tyList");
                reCountLvOrder("tyList", tyList, con);
                tyList.clear();
                Set<String> ymList = orderDataNames.get("ymList");
                reCountLvOrder("ymList", ymList, con);
                ymList.clear();
                Set<String> lcList = orderDataNames.get("lcList");
                reCountLvOrder("lcList", lcList, con);
                lcList.clear();


                Set<String> goldList = orderDataNames.get("goldList");
                Set<String> taleList = orderDataNames.get("taleList");
                Set<String> yingxiongList = orderDataNames.get("yingxiongList");
                reCountLvOrder("yingxiongList", yingxiongList, con);
                yingxiongList.clear();
                Set<String> motouList = orderDataNames.get("motouList");
                reCountLvOrder("motouList", motouList, con);
                motouList.clear();
                //战力排行
                Set<String> zhanLiList = orderDataNames.get("zhanLiList");
                /*if (zhanLiList != null && zhanLiList.size() > 0) {
                    dao.delZlOrder();
                    mybatisConfig.commit(con);
                    for (String name : zhanLiList) {
                        JSONObject attr = startBef.manService.getFightAttr(name, (DefaultSqlSession) con);
                        JSONObject prop = attr.getJSONObject("prop");
                        JSONObject petAttr = startBef.petService.getFightAttr(name, (DefaultSqlSession) con);

                        if (petAttr != null) {
                            JSONObject petProp = petAttr.getJSONObject("prop");
                            for (String k : prop.keySet()) {
                                if (petProp.get(k) != null) {
                                    prop.put(k, prop.getInteger(k) + petProp.getInteger(k));
                                }
                            }
                        }
                        //人物、宠物战力
                        int zl = startBef.manService.countZhanLi(prop);
                        isBigToBef("zl", name, zl, zlList, true);
                    }
                    for (int i = 0; i < zlList.size(); i++) {
                        if (i >= 100) break;
                        JSONObject obj = zlList.get(i);
                        dao.addZlOrder(obj.getString("name"), obj.getString("zl"), i + "");
                        mybatisConfig.commit(con);
                    }
                }*/
            }

        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
            ishandleOrder = false;
        }

    }

    /**
     * 重新计算等级排行
     */
    private void reCountLvOrder(String type, Set<String> nameList, DefaultSqlSession con) throws Exception {
        if (nameList == null || nameList.size() == 0) return;
        roleMapper roleMapper = mybatisConfig.getMapper(con, roleMapper.class);
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        List<JSONObject> list = null;
        //清理一次，因为重新排序后需要重新入库
        if (type.equals("lvList")) {
            list = dao.selectLvOrder();
            dao.delLvOrder();
        } else if (type.equals("msList")) {
            list = dao.selectLvOrderMs();
            dao.delLvOrderMs();
        } else if (type.equals("djList")) {
            list = dao.selectLvOrderDj();
            dao.delLvOrderDj();
        } else if (type.equals("qmList")) {
            list = dao.selectLvOrderQm();
            dao.delLvOrderQm();
        } else if (type.equals("tyList")) {
            list = dao.selectLvOrderTy();
            dao.delLvOrderTy();
        } else if (type.equals("ymList")) {
            list = dao.selectLvOrderYm();
            dao.delLvOrderYm();
        } else if (type.equals("lcList")) {
            list = dao.selectLvOrderLc();
            dao.delLvOrderLc();
        } else if (type.equals("yingxiongList")) {
            list = dao.selectLvOrderSezShan();
            dao.delLvOrderSezShan();
        } else if (type.equals("motouList")) {
            list = dao.selectLvOrderSezE();
            dao.delLvOrderSezE();
        }
        mybatisConfig.commit(con);
        //将发生变更的角色信息查出来
        List<JSONObject> mL = null;
        if (type.equals("yingxiongList") || type.equals("motouList")) {
            mL = dao.getPlayerMsgByNames(Arrays.asList(nameList.toArray()));
        } else {
            mL = roleMapper.getRolesMsg(Arrays.asList(nameList.toArray()));
        }
        //
        for (JSONObject m : mL) {
            boolean b = false;
            for (JSONObject l : list) {
                if (m.getString("name").equals(l.getString("name"))) {
                    b = true;
                    //在数据库中能被找到则更新数据
                    if (type.equals("yingxiongList") || type.equals("motouList")) {
                        JSONObject msg = m.getJSONObject("msg");
                        l.put("sez", msg.getString("sez"));
                        l.put("sort", strUtils.getTime() + "");
                    } else {
                        l.put("lever", m.getString("lever"));
                        l.put("sort", strUtils.getTime() + "");
                    }
                    break;
                }
            }
            //库中找不到就创建
            if (!b) {
                JSONObject a = new JSONObject();
                a.put("name", m.getString("name"));
                a.put("lever", m.getString("lever"));
                a.put("model", roleUtils.getModel(m));
                a.put("sort", strUtils.getTime() + "");
                if (type.equals("yingxiongList") || type.equals("motouList")) {
                    JSONObject msg = m.getJSONObject("msg");
                    a.put("sez", msg.getString("sez"));
                }
                list.add(a);
            }
        }

        //先按等级排，然后按变动时间排
        Collections.sort(list, new Comparator<JSONObject>() {
            @Override
            public int compare(JSONObject i1, JSONObject i2) {
                int levelCompare = 0;
                if (type.equals("yingxiongList") || type.equals("motouList")) {
                    levelCompare = Integer.compare(i2.getInteger("sez"), i1.getInteger("sez"));
                } else {
                    levelCompare = Integer.compare(i2.getInteger("lever"), i1.getInteger("lever"));
                }
                if (levelCompare == 0) { // 如果等级相同，则比较日期
                    return i1.getLong("sort").compareTo(i2.getLong("sort"));
                }
                return levelCompare; // 返回等级比较的结果
            }
        });
        //将重新排好的数据进行入库
        for (int i = 0; i < list.size(); i++) {
            if (i >= 100) break;
            JSONObject obj = list.get(i);
            if (type.equals("lvList")) {
                dao.addLvOrder(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sort"));
            } else if (type.equals("msList")) {
                dao.addLvOrderMs(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sort"));
            } else if (type.equals("djList")) {
                dao.addLvOrderDj(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sort"));
            } else if (type.equals("qmList")) {
                dao.addLvOrderQm(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sort"));
            } else if (type.equals("tyList")) {
                dao.addLvOrderTy(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sort"));
            } else if (type.equals("ymList")) {
                dao.addLvOrderYm(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sort"));
            } else if (type.equals("lcList")) {
                dao.addLvOrderLc(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sort"));
            } else if (type.equals("yingxiongList")) {
                dao.addLvOrderSezShan(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sez"), obj.getString("sort"));
            } else if (type.equals("motouList")) {
                dao.addLvOrderSezE(obj.getString("name"), obj.getString("lever"), obj.getString("model"), obj.getString("sez"), obj.getString("sort"));
            }

            mybatisConfig.commit(con);
        }

    }

    /**
     * 计算战力排行
     */
    public void countZlOrder(String name) {
        /*Map<String, Set<String>> orderDataNames = staticCollection.orderDataNames;
        Set<String> list = orderDataNames.get("zhanLiList");
        if (list != null)
            list.add(name);*/
    }

    public void countLvOrder(String name) {
        Map<String, Set<String>> orderDataNames = staticCollection.orderDataNames;
        Set<String> list = orderDataNames.get("lvList");
        if (list != null)
            list.add(name);
    }

    public void countGoldOrder(String name) {
        Map<String, Set<String>> orderDataNames = staticCollection.orderDataNames;
        Set<String> list = orderDataNames.get("goldList");
        list.add(name);
    }

    public void countTaleOrder(String name) {
        Map<String, Set<String>> orderDataNames = staticCollection.orderDataNames;
        Set<String> list = orderDataNames.get("taleList");
        list.add(name);
    }

    public void countYXOrder(String name) {
        Map<String, Set<String>> orderDataNames = staticCollection.orderDataNames;
        Set<String> list = orderDataNames.get("yingxiongList");
        list.add(name);
    }

    public void countMTOrder(String name) {
        Map<String, Set<String>> orderDataNames = staticCollection.orderDataNames;
        Set<String> list = orderDataNames.get("motouList");
        list.add(name);
    }

    /**
     * 从魔头榜或英雄榜中除名
     */
    public void removeNameFromMTOrYX(String name, DefaultSqlSession con) {
        Map<String, Set<String>> orderDataNames = staticCollection.orderDataNames;
        Set<String> list = orderDataNames.get("motouList");
        for (String l : list) {
            if (name.equals(l)) {
                list.remove(l);
                break;
            }
        }
        list = orderDataNames.get("yingxiongList");
        for (String l : list) {
            if (name.equals(l)) {
                list.remove(l);
                break;
            }
        }
        jsonMapper dao = mybatisConfig.getMapper(con, jsonMapper.class);
        dao.delLvOrderSezShanByName(name);
        dao.delLvOrderSezEByName(name);
    }

    /**
     * 生成榜（游戏初始化时调用）
     * 这个是当排行榜数据不存在时会生成排行数据并存入数据库，当数据库存在数据时不会再次执行
     * 每次发生变更时会将数据加入内存中的排行数据中，然后等待定时器执行重新排序
     */
    public void createOrder() {
        long old = strUtils.getTime();

        staticCollection.orderDataNames.put("lvList", new HashSet<>());
        staticCollection.orderDataNames.put("goldList", new HashSet<>());
        staticCollection.orderDataNames.put("taleList", new HashSet<>());
        staticCollection.orderDataNames.put("yingxiongList", new HashSet<>());
        staticCollection.orderDataNames.put("motouList", new HashSet<>());
        staticCollection.orderDataNames.put("zhanLiList", new HashSet<>());

        staticCollection.orderDataNames.put("msList", new HashSet<>());
        staticCollection.orderDataNames.put("djList", new HashSet<>());
        staticCollection.orderDataNames.put("qmList", new HashSet<>());
        staticCollection.orderDataNames.put("tyList", new HashSet<>());
        staticCollection.orderDataNames.put("ymList", new HashSet<>());
        staticCollection.orderDataNames.put("lcList", new HashSet<>());
        //个人传壁积分
        staticCollection.orderDataNames.put("cbjfList", new HashSet<>());

        //当表不存在时才执行
        SqlSession con = null;
        try {
            con = mybatisConfig.getSqlSession();
            jsonMapper jsonMapper = mybatisConfig.getMapper(con, jsonMapper.class);
            List<JSONObject> ls = jsonMapper.selectLvOrder();
            if (ls.size() == 0) {
                //生成排行榜
                List<JSONObject> lvList = new ArrayList<>();
                List<JSONObject> motouList = new ArrayList<>();
                List<JSONObject> yingxiongList = new ArrayList<>();
                List<JSONObject> zhanLiList = new ArrayList<>();
                List<JSONObject> msList = new ArrayList<>();
                List<JSONObject> djList = new ArrayList<>();
                List<JSONObject> qmList = new ArrayList<>();
                List<JSONObject> tyList = new ArrayList<>();
                List<JSONObject> ymList = new ArrayList<>();
                List<JSONObject> lcList = new ArrayList<>();
                List<JSONObject> cbjfList = new ArrayList<>();

                activityMapper activityMapper = mybatisConfig.getMapper(con, activityMapper.class);
                int num = activityMapper.getManViewSum().get(0).getInteger("n");
                int len = num % 10 == 0 ? num / 10 : num / 10 + 1;
                for (int i = 0; i < len; i++) {
                    ls = activityMapper.getManView(i * 10L, 10L);
                    mybatisConfig.commit(con);
                    if (ls.size() == 0) continue;
                    for (int j = 0; j < ls.size(); j++) {
                        JSONObject temp = ls.get(j);
                        String model = roleUtils.getJobFromModels(temp);
                        if (model == null) continue;
                        temp.put("model", model);
                        isBigToBef("lever", temp.getString("name"), temp, lvList, true, new String[]{"model"});
                        if (ls.get(j).getString("models").contains("ms_")) {
                            isBigToBef("lever", temp.getString("name"), temp, msList, true, new String[]{"model"});
                        } else if (ls.get(j).getString("models").contains("dj_")) {
                            isBigToBef("lever", temp.getString("name"), temp, djList, true, new String[]{"model"});
                        } else if (ls.get(j).getString("models").contains("qm_")) {
                            isBigToBef("lever", temp.getString("name"), temp, qmList, true, new String[]{"model"});
                        } else if (ls.get(j).getString("models").contains("ty_")) {
                            isBigToBef("lever", temp.getString("name"), temp, tyList, true, new String[]{"model"});
                        } else if (ls.get(j).getString("models").contains("ym_")) {
                            isBigToBef("lever", temp.getString("name"), temp, ymList, true, new String[]{"model"});
                        } else if (ls.get(j).getString("models").contains("lc_")) {
                            isBigToBef("lever", temp.getString("name"), temp, lcList, true, new String[]{"model"});
                        }

                        /*int gold = ls.get(j).getJSONObject("msg").getInteger("gold");
                        int tale = ls.get(j).getJSONObject("msg").getInteger("tale");
                        //土豪
                        isBigToBef("gold", ls.get(j).getString("name"), gold, staticCollection.orderData.get("goldList"), true);
                        isBigToBef("tale", ls.get(j).getString("name"), tale, staticCollection.orderData.get("taleList"), true);*/
                        //侠义
                        int sez = temp.getJSONObject("msg").getInteger("sez");
                        JSONObject msg = temp.getJSONObject("msg");
                        msg.put("model", model);
                        msg.put("lever", temp.get("lever"));
                        if (sez < 3) {
                            isBigToBef("sez", temp.getString("name"), msg, motouList, false, new String[]{"model", "lever"});
                        } else if (sez > 7) {
                            isBigToBef("sez", temp.getString("name"), msg, yingxiongList, true, new String[]{"model", "lever"});
                        }
                        //传壁积分
                        int cbjf = temp.getJSONObject("msg").getInteger("cbjf");
                        isBigToBef("cbjf", temp.getString("name"), cbjf, cbjfList, true);

                        //计算战力，先计算战斗属性，由战斗属性再计算战力
                        /*JSONObject attr = startBef.manService.getFightAttr(temp.getString("name"), (DefaultSqlSession) con);
                        JSONObject prop = attr.getJSONObject("prop");
                        JSONObject petAttr = startBef.petService.getFightAttr(temp.getString("name"), (DefaultSqlSession) con);

                        if (petAttr != null) {
                            JSONObject petProp = petAttr.getJSONObject("prop");
                            for (String k : prop.keySet()) {
                                if (petProp.get(k) != null) {
                                    prop.put(k, prop.getInteger(k) + petProp.getInteger(k));
                                }
                            }
                        }

                        //人物、宠物战力
                        int zl = startBef.manService.countZhanLi(prop);
                        isBigToBef("zl", temp.getString("name"), zl, zhanLiList, true);
                        */
                        mybatisConfig.commit(con);
                    }

                }
                jsonMapper.delLvOrder();
                //将排行数据入库
                for (int i = 0; i < lvList.size(); i++) {
                    JSONObject a = lvList.get(i);
                    jsonMapper.addLvOrder(a.getString("name"), a.getString("lever"), a.getString("model"), i + "");
                    mybatisConfig.commit(con);
                }
                jsonMapper.delLvOrderMs();
                for (int i = 0; i < msList.size(); i++) {
                    JSONObject a = msList.get(i);
                    jsonMapper.addLvOrderMs(a.getString("name"), a.getString("lever"), a.getString("model"), i + "");
                    mybatisConfig.commit(con);
                }
                jsonMapper.delLvOrderDj();
                for (int i = 0; i < djList.size(); i++) {
                    JSONObject a = djList.get(i);
                    jsonMapper.addLvOrderDj(a.getString("name"), a.getString("lever"), a.getString("model"), i + "");
                    mybatisConfig.commit(con);
                }
                jsonMapper.delLvOrderQm();
                for (int i = 0; i < qmList.size(); i++) {
                    JSONObject a = qmList.get(i);
                    jsonMapper.addLvOrderQm(a.getString("name"), a.getString("lever"), a.getString("model"), i + "");
                    mybatisConfig.commit(con);
                }
                jsonMapper.delLvOrderTy();
                for (int i = 0; i < tyList.size(); i++) {
                    JSONObject a = tyList.get(i);
                    jsonMapper.addLvOrderTy(a.getString("name"), a.getString("lever"), a.getString("model"), i + "");
                    mybatisConfig.commit(con);
                }
                jsonMapper.delLvOrderYm();
                for (int i = 0; i < ymList.size(); i++) {
                    JSONObject a = ymList.get(i);
                    jsonMapper.addLvOrderYm(a.getString("name"), a.getString("lever"), a.getString("model"), i + "");
                    mybatisConfig.commit(con);
                }
                jsonMapper.delLvOrderLc();
                for (int i = 0; i < lcList.size(); i++) {
                    JSONObject a = lcList.get(i);
                    jsonMapper.addLvOrderLc(a.getString("name"), a.getString("lever"), a.getString("model"), i + "");
                    mybatisConfig.commit(con);
                }
                jsonMapper.delLvOrderSezShan();
                for (int i = 0; i < yingxiongList.size(); i++) {
                    JSONObject a = yingxiongList.get(i);
                    jsonMapper.addLvOrderSezShan(a.getString("name"), a.getString("lever"), a.getString("model"), a.getString("sez"), i + "");
                    mybatisConfig.commit(con);
                }
                jsonMapper.delLvOrderSezE();
                for (int i = 0; i < motouList.size(); i++) {
                    JSONObject a = motouList.get(i);
                    jsonMapper.addLvOrderSezE(a.getString("name"), a.getString("lever"), a.getString("model"), a.getString("sez"), i + "");
                    mybatisConfig.commit(con);
                }
                jsonMapper.delZlOrder();
                for (int i = 0; i < zhanLiList.size(); i++) {
                    JSONObject a = zhanLiList.get(i);
                    jsonMapper.addZlOrder(a.getString("name"), a.getString("zl"), i + "");
                    mybatisConfig.commit(con);
                }
                mybatisConfig.commit(con);
            }
            mybatisConfig.commit(con);
            //将缓存数据给清理掉，定时任务会从数据库中获取
            for (String k : staticCollection.orderDataNames.keySet()) {
                staticCollection.orderDataNames.get(k).clear();
            }
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
            System.out.println("排行榜生成总耗时：" + (strUtils.getTime() - old) + "ms");
        }

    }

    private void isBigToBef(String k, String name, JSONObject vObj, List<JSONObject> list, boolean isBig, String[] keys) {
        //先将名字重复的移除
        for (int i = 0; i < list.size(); i++) {
            JSONObject a = list.get(i);
            if (a.getString("name").equals(name)) {
                list.remove(i);
                i--;
            }
        }
        //比如k是lever，取这个等级
        int v = vObj.getInteger(k);
        if (list.size() == 0) {
            JSONObject obj = new JSONObject();
            obj.put("name", name);
            obj.put(k, v);
            for (String a : keys) {
                obj.put(a, vObj.get(a));
            }
            list.add(obj);
            return;
        }
        boolean b = false;
        int len = list.size();
        for (int i = 0; i < len; i++) {
            if (isBig && v > list.get(i).getInteger(k)) {
                JSONObject obj = new JSONObject();
                obj.put("name", name);
                obj.put(k, v);
                for (String a : keys) {
                    obj.put(a, vObj.get(a));
                }
                list.add(i, obj);
                b = true;
                break;
            } else if (!isBig && v < list.get(i).getInteger(k)) {
                JSONObject obj = new JSONObject();
                obj.put("name", name);
                obj.put(k, v);
                for (String a : keys) {
                    obj.put(a, vObj.get(a));
                }
                list.add(i, obj);
                b = true;
                break;
            }
        }
        //超过100就要移除后面的
        if (b && list.size() > 100) {
            list.remove(list.size() - 1);
        } else if (!b && list.size() < 100) {
            JSONObject obj = new JSONObject();
            obj.put("name", name);
            obj.put(k, v);
            for (String a : keys) {
                obj.put(a, vObj.get(a));
            }
            list.add(obj);
        }
    }

    /**
     * 按大的位置插入
     * k比较的key，v值
     */
    private void isBigToBef(String k, String name, int v, List<JSONObject> list, boolean isBig) {
        JSONObject obj = new JSONObject();
        obj.put(k, v);
        isBigToBef(k, name, obj, list, isBig, new String[0]);
    }


}
