package my.data;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.utils.strUtils;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.regex.Pattern;

public class goodsData {
    /**
     * 2字装备技能
     */
    public static List<String> getZb2SkillGoodsData(List<String> arr) {
        String[] a = {
                "3600", "3601", "3602", "3603", "3604",
                "3605", "3606", "3607", "3608",
        };
        arr.addAll(Arrays.asList(a));
        return arr;
    }

    /**
     * 天地技能
     */
    public static List<String> getManTdSkillGoodsData(List<String> arr) {
        String[] a = {
                "100210030027", "100210030028", "100210030038",
                "100210030039", "100210030041", "100210030042", "100210030048",
                "100210030051", "100210030052", "100210030053",
        };
        arr.addAll(Arrays.asList(a));
        return arr;
    }

    /**
     * 四字仙绝
     */
    public static List<String> getMan4SkillGoodsData(List<String> arr) {
        String[] a = {
                "100210030029", "100210030030", "100210030031",
                "100210030032", "100210030033", "100210030034", "100210030035", "100210030036",
                "100210030037", "100210030040",
                "100210030043", "100210030044", "100210030045", "100210030046",
                "100210030047", "100210030049", "100210030050",
                "100210030070", "100210030072"
        };
        arr.addAll(Arrays.asList(a));
        return arr;
    }

    /**
     * 二字仙绝
     */
    public static List<String> getMan2SkillGoodsData(List<String> arr) {
        String[] a = {
                "100210030054", "100210030055", "100210030056", "100210030057", "100210030058",
                "100210030059", "100210030060", "100210030061", "100210030062", "100210030063",
                "100210030064", "100210030065", "100210030066", "100210030067", "100210030068",
                "100210030069", "100210030071", "100210030073"
        };
        arr.addAll(Arrays.asList(a));
        return arr;
    }

    /**
     * 是否为仙绝技能书
     */
    public static boolean isManSkill(String k) {
        List<String> arr = getMan4SkillGoodsData(new ArrayList<>());
        arr = getMan2SkillGoodsData(arr);
        for (String a : arr) {
            if (a.equals(k)) return true;
        }
        return false;
    }


    /**
     * 宠物技能-2字
     */
    public static List<String> getAllPet2SkillGoodsData(List<String> arr) {
        String[] a = {
                "100210010210", "100210010211", "100210010212", "100210010213", "100210010214",
                "100210010215", "100210010216", "100210010217", "100210010218", "100210010219",
                "100210010220", "100210010221", "100210010222", "100210010223", "100210010224",
                "100210010225", "100210010226", "100210010227", "100210010228", "100210010229",
                "100210010230", "100210010231", "100210010232", "100210010233", "100210010234",
                "100210010235", "100210010236", "100210010237", "100210010238", "100210010239",
                "100210010240", "100210010241", "100210010242", "100210010243", "100210010244",
                "100210010250", "100210010251", "100210010252", "100210010253", "100210010254",
                "100210010255", "100210010256", "100210010257", "100210010258", "100210010259",
                "100210010260", "100210010261", "100210010262", "100210010263", "100210010264",
        };
        arr.addAll(Arrays.asList(a));
        return arr;
    }

    /**
     * 混合宠物技能-4
     */
    public static List<String> getAllPet4SkillGoodsData(List<String> arr) {
        String[] a = {
                "100210010183",
                "100210010265", "100210010266", "100210010267", "100210010268", "100210010269",
                "100210010270", "100210010271", "100210010272", "100210010273", "100210010276",
                "100210010277", "100210010278", "100210010279", "100210010280", "100210010281",
                "100210010282", "100210010283", "100210010284", "100210010286", "100210010287",
                "100210010288", "100210010289", "100210010291", "100210010292", "100210010294",
                "100210010295", "100210010296", "100210010297", "100210010298", "100210010308",
                "100210010309", "100210010310", "100210010311", "100210010312", "100210010313",
                "100210010180", "100210010299", "100210010300", "100210010301", "100210010302",
                "100210010302",
        };
        if (strUtils.isHappend(0, 1000, 0.01f)) {
            //玄心、踏雪
            arr.add("100210010274");
            arr.add("100210010275");
        }
        arr.addAll(Arrays.asList(a));
        return arr;
    }

    /**
     * 是否为宠物技能书
     */
    public static boolean isPetSkill(String k) {
        List<String> arr = getAllPet4SkillGoodsData(new ArrayList<>());
        arr = getAllPet2SkillGoodsData(arr);
        for (String a : arr) {
            if (a.equals(k)) return true;
        }
        return false;
    }

    /**
     * 获取刻印的数据
     */
    public static List<String> getKyGoodsData(List<String> arr) {
        //每19为一组，分三组，蓝、紫、金 57
        for (int a = 10900000; a < 10900057; a++) {
            arr.add(a + "");//天罡印
        }
        return arr;
    }

    /**
     * 通过购买接口调取物品价格等属性
     */
    public static JSONObject getGoodsPrice(String key, int moneyType) {
        JSONArray buyList = new JSONArray();
        switch (key) {
            case "10000000": {
                addBuyRule(0, 1000, buyList);
                break;
            }
            case "10000001": {
                addBuyRule(0, 500, buyList);
                break;
            }
            case "10000002": {
                addBuyRule(0, 100, buyList);
                break;
            }
            case "10000004": {
                addBuyRule(1, 1000, buyList);
                break;
            }
            case "10000029": {
                addBuyRule(1, 2000, buyList);
                break;
            }
            case "10000030": {
                addBuyRule(1, 20000, buyList);
                break;
            }
            case "10000031": {
                addBuyRule(0, 100, buyList);
                break;
            }
            case "10000032": {
                addBuyRule(0, 400, buyList);
                break;
            }
            case "10000105": {
                addBuyRule(0, 80, buyList);
                addBuyRule(3, 120, buyList);
                addBuyRule(5, 420, buyList);
                break;
            }
            case "10000107": {
                addBuyRule(0, 500, buyList);
                addBuyRule(3, 750, buyList);
                break;
            }
            case "10000109": {
                addBuyRule(0, 50, buyList);
                addBuyRule(3, 75, buyList);
                break;
            }
            case "10000111": {
                addBuyRule(0, 300, buyList);
                addBuyRule(3, 450, buyList);
                break;
            }
            case "10000112": {
                addBuyRule(0, 4000, buyList);
                break;
            }
            case "10000113": {
                addBuyRule(0, 800, buyList);
                break;
            }
            case "10000114": {
                addBuyRule(0, 250, buyList);
                addBuyRule(3, 375, buyList);
                break;
            }
            case "10000115": {
                addBuyRule(0, 1500, buyList);
                addBuyRule(3, 2250, buyList);
                break;
            }

            case "10000118": {
                addBuyRule(0, 200, buyList);
                break;
            }
            case "10000119": {
                addBuyRule(0, 500, buyList);
                break;
            }
            case "10000120": {
                addBuyRule(0, 250, buyList);
                break;
            }
            case "10000121": {
                addBuyRule(0, 2000, buyList);
                break;
            }
            case "10000122": {
                addBuyRule(0, 1000, buyList);
                break;
            }
            case "10000123": {
                addBuyRule(0, 250, buyList);
                break;
            }
            case "10000124": {
                addBuyRule(0, 200, buyList);
                break;
            }
            case "10000125": {
                addBuyRule(0, 20, buyList);
                break;
            }
            case "10000126": {
                addBuyRule(0, 430, buyList);
                break;
            }
            case "10000127": {
                addBuyRule(0, 100, buyList);
                break;
            }
            case "10000128": {
                addBuyRule(0, 250, buyList);
                break;
            }
            case "10000129": {
                addBuyRule(0, 1000, buyList);
                break;
            }
            case "10000130": {
                addBuyRule(1, 2500, buyList);
                break;
            }
            case "10000140": {
                addBuyRule(0, 250, buyList);
                break;
            }
            case "10000141": {
                addBuyRule(0, 1000, buyList);
                break;
            }
            case "10000149": {
                addBuyRule(0, 250, buyList);
                addBuyRule(3, 375, buyList);
                break;
            }
            case "10000150": {
                addBuyRule(0, 4000, buyList);
                addBuyRule(3, 6000, buyList);
                break;
            }
            case "10000159": {
                addBuyRule(0, 2000, buyList);
                break;
            }
            case "10000160": {
                addBuyRule(0, 18000, buyList);
                break;
            }
            case "10000162": {
                addBuyRule(0, 100, buyList);
                break;
            }
            case "10000163": {
                addBuyRule(0, 100, buyList);
                break;
            }
            case "10000164": {
                addBuyRule(0, 250, buyList);
                break;
            }
            case "10000165": {
                addBuyRule(0, 250, buyList);
                break;
            }
            case "10000166": {
                addBuyRule(0, 50, buyList);
                break;
            }
            case "10000167": {
                addBuyRule(0, 250, buyList);
                break;
            }
            case "10000171": {
                addBuyRule(0, 200, buyList);
                break;
            }
            case "10000174": {
                addBuyRule(0, 500, buyList);
                addBuyRule(5, 1500, buyList);
                break;
            }
            case "10000177": {
                addBuyRule(0, 90, buyList);
                break;
            }
            case "10000178": {
                addBuyRule(0, 100, buyList);
                addBuyRule(5, 400, buyList);
                break;
            }
            case "10000179": {
                addBuyRule(0, 80, buyList);
                addBuyRule(5, 320, buyList);
                break;
            }
            case "10000183": {
                addBuyRule(0, 120, buyList);
                break;
            }
            case "10000184": {
                addBuyRule(0, 120, buyList);
                break;
            }
            case "10000185": {
                addBuyRule(2, 200, buyList);
                break;
            }
            case "10000187": {
                addBuyRule(0, 500, buyList);
                break;
            }
            case "10000194": {
                addBuyRule(0, 100, buyList);
                break;
            }
            case "10000195": {
                addBuyRule(0, 100, buyList);
                break;
            }
            case "10000196": {
                addBuyRule(0, 300, buyList);
                break;
            }
            case "10000197": {
                addBuyRule(0, 1000, buyList);
                break;
            }
            case "10000198": {
                addBuyRule(0, 300, buyList);
                break;
            }
            case "10000201": {
                addBuyRule(0, 200, buyList);
                break;
            }
            case "10000208": {
                addBuyRule(0, 180, buyList);
                break;
            }
            case "10000209": {
                addBuyRule(0, 460, buyList);
                break;
            }
            case "10000210": {
                addBuyRule(0, 200, buyList);
                break;
            }
            case "10000213": {
                addBuyRule(0, 200, buyList);
                break;
            }
            case "10000223": {
                addBuyRule(0, 200, buyList);
                break;
            }
            case "10000224": {
                addBuyRule(0, 200, buyList);
                break;
            }
            case "10000257": {
                addBuyRule(0, 120000, buyList);
                break;
            }
            case "10000258": {
                addBuyRule(0, 10000, buyList);
                break;
            }
            case "10000260": {
                addBuyRule(0, 15000, buyList);
                break;
            }
            case "10000261": {
                addBuyRule(0, 5000, buyList);
                break;
            }
            case "10000262": {
                addBuyRule(0, 2000, buyList);
                break;
            }
            case "10000263": {
                addBuyRule(0, 20, buyList);
                break;
            }
            case "10000264": {
                addBuyRule(0, 80000, buyList);
                break;
            }
            case "10000265": {
                addBuyRule(0, 100000, buyList);
                break;
            }
            case "10000285": {
                addBuyRule(0, 50000, buyList);
                break;
            }
            case "10000286": {
                addBuyRule(0, 50000, buyList);
                break;
            }
            case "10000292": {
                addBuyRule(0, 4000, buyList);
                break;
            }
            case "100110060000": {//小药囊
                addBuyRule(1, 100, buyList);
                addBuyRule(2, 500, buyList);
                break;
            }
            case "100110060001": {//大药囊
                addBuyRule(1, 5000, buyList);
                break;
            }
            case "100110060002": {//超级药囊
                addBuyRule(0, 100, buyList);
                break;
            }
            case "100110060003": {//无敌药囊
                addBuyRule(0, 1000, buyList);
                break;
            }
        }

        //镶嵌宝石
        if (strUtils.isMatch(key, "1003([0-9]{4})")) {
            //2级
            if (strUtils.isMatch(key, "1003001([0-9]{1})")) {
                addBuyRule(5, 350, buyList);
            }
            //3级
            if (strUtils.isMatch(key, "1003002([0-9]{1})")) {
                addBuyRule(0, 150, buyList);
                addBuyRule(3, 225, buyList);
            }
        }
        //宠物丹
        /*if (strUtils.isMatch(key, "1011([0-9]{4})")) {
            int lv = Integer.parseInt(key.substring(4).charAt(2) + "") + 1;
            int price = lv < 2 ? 10 : (lv < 3 ? 25 : 50);
            addBuyRule(0, price, buyList);
        }*/
        if (buyList.size() > 0) {
            for (Object o : buyList) {
                JSONObject a = (JSONObject) o;
                //同价格类型的导出
                if (a.getInteger("moneyType") == moneyType)
                    return a;
            }
        }
        return null;
    }

    private static void addBuyRule(int moneyType, int value, JSONArray buyList) {
        JSONObject rule = new JSONObject();
        rule.put("moneyType", moneyType);
        rule.put("value", value);
        buyList.add(rule);
    }


    /**
     * 出售、邮寄前判断是否允许
     * fixme:注意前端也要判断
     */
    public static boolean isNoAllowedSend(JSONObject goods) {
        Object isBind = goods.get("isBind");
        if (isBind == null || goods.get("key") == null ||
                goods.getInteger("isBind") == 1) {
            return true;
        }
        return isNoEmailGoods(goods.getString("key"));
    }

    /**
     * 判断是否为不能邮寄的物品
     */
    private static boolean isNoEmailGoods(String key) {

        return false;
    }

    /**
     * 判断是否为宠物召唤道具
     */
    public static boolean isPetZhaoHuanGoods(String key) {
        if (key.equals("10000133") || key.equals("10000134") || key.equals("10000135") ||
                key.equals("10000136") || key.equals("10000137") || key.equals("10000138") ||
                key.equals("10000139") || key.equals("10000140") || key.equals("10000141")) {
            return true;
        }
        return false;
    }

    /**
     * 判断道具是否允许使用
     */
    public static boolean isAllowedUse(String key) {
        if (strUtils.isMatch(key, "1012([0-9]{4})")) {//王者遗产藏宝图
            return true;
        }
        String[] arr = new String[]{
                "10000000", "10000001", "10000002",
                "10000029", "10000030", "10000031", "10000032",
                "10000112", "10000125", "10000126",
                "10000133", "10000134", "10000135", "10000136", "10000137", "10000138", "10000139", "10000140", "10000141", "10000142",
                "10000175", "10000176", "10000177", "10000178", "10000181", "10000182", "10000183", "10000184", "10000187", "10000189",
                "10000201", "10000208", "10000209", "10000210",
                "10000213", "10000214", "10000215", "10000216", "10000217", "10000220",
                "10000233",
                "10000237", "10000238", "10000239", "10000240", "10000241",
                "10000242", "10000243", "10000244", "10000245", "10000246",
                "10000257", "10000258", "10000259", "10000260", "10000261", "10000262", "10000263", "10000264", "10000265",
                "10000267", "10000268", "10000269", "10000270", "10000271", "10000272", "10000273", "10000274", "10000275",
                "10000276", "10000277", "10000278", "10000279", "10000280", "10000281", "10000282", "10000283",
                "10000285", "10000286", "10000288", "10000292", "10000294", "10000302",

        };
        for (String a : arr) {
            if (a.equals(key)) {
                return true;
            }
        }
        return false;
    }

    /**
     * 是否允许使用多个数量
     */
    public static boolean isAllowedUseMulNum(String k) {
        //金票和经验丹才允许超过数量1
        if (k.equals("10000000") || k.equals("10000001") || k.equals("10000002") ||
                k.equals("10000029") || k.equals("10000030") || k.equals("10000031") ||
                k.equals("10000032") || k.equals("10000175") || k.equals("10000176")
                || k.equals("10000220")
        ) {
            return true;
        }
        return false;
    }
}
