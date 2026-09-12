package my.data;

import com.alibaba.fastjson2.JSONObject;
import my.utils.strUtils;

public class seedData {
    /**
     * 随机取一个普通种子
     */
    public static String getOne() {
        return strUtils.getRandom(11990029, 11990036) + "";
    }

    /**
     * 获取种子的信息
     */
    public static JSONObject getSeedMsg(String key) {
        JSONObject a = new JSONObject();
        switch (key) {
            case "11990000": {
                a.put("num", 1);
                a.put("time", 4);//成熟小时
                a.put("npcKey", "nc3");
                return a;
            }
            case "11990001": {
                a.put("num", 1);
                a.put("time", 4);
                a.put("npcKey", "nc4");
                return a;
            }
            case "11990002": {
                a.put("num", 1);
                a.put("time", 4);
                a.put("npcKey", "nc5");
                return a;
            }
            case "11990003": {
                a.put("num", 1);
                a.put("time", 4);
                a.put("npcKey", "nc6");
                return a;
            }
            case "11990004": {
                a.put("num", 1);
                a.put("time", 4);
                a.put("npcKey", "nc7");
                return a;
            }
            case "11990005": {
                a.put("num", 1);
                a.put("time", 4);
                a.put("npcKey", "nc8");
                return a;
            }
            case "11990006": {
                a.put("num", 2);
                a.put("time", 4);
                a.put("npcKey", "nc9");
                return a;
            }
            case "11990007": {
                a.put("num", 2);
                a.put("time", 4);
                a.put("npcKey", "nc10");
                return a;
            }
            case "11990008": {
                a.put("num", 2);
                a.put("time", 4);
                a.put("npcKey", "nc11");
                return a;
            }
            case "11990009": {
                a.put("num", 2);
                a.put("time", 4);
                a.put("npcKey", "nc12");
                return a;
            }
            case "11990010": {
                a.put("num", 2);
                a.put("time", 4);
                a.put("npcKey", "nc13");
                return a;
            }
            case "11990011": {
                a.put("num", 3);
                a.put("time", 4);
                a.put("npcKey", "nc14");
                return a;
            }
            case "11990012": {
                a.put("num", 3);
                a.put("time", 4);
                a.put("npcKey", "nc15");
                return a;
            }
            case "11990013": {
                a.put("num", 3);
                a.put("time", 4);
                a.put("npcKey", "nc16");
                return a;
            }
            case "11990014": {
                a.put("num", 3);
                a.put("time", 4);
                a.put("npcKey", "nc17");
                return a;
            }
            case "11990015": {
                a.put("num", 3);
                a.put("time", 4);
                a.put("npcKey", "nc18");
                return a;
            }
            case "11990016": {
                a.put("num", 4);
                a.put("time", 4);
                a.put("npcKey", "nc19");
                return a;
            }
            case "11990017": {
                a.put("num", 4);
                a.put("time", 4);
                a.put("npcKey", "nc20");
                return a;
            }
            case "11990018": {
                a.put("num", 4);
                a.put("time", 4);
                a.put("npcKey", "nc21");
                return a;
            }
            case "11990019": {
                a.put("num", 4);
                a.put("time", 4);
                a.put("npcKey", "nc22");
                return a;
            }
            case "11990020": {
                a.put("num", 4);
                a.put("time", 4);
                a.put("npcKey", "nc23");
                return a;
            }
            case "11990021": {
                a.put("num", 5);
                a.put("time", 4);
                a.put("npcKey", "nc24");
                return a;
            }
            case "11990022": {
                a.put("num", 5);
                a.put("time", 4);
                a.put("npcKey", "nc25");
                return a;
            }
            case "11990023": {
                a.put("num", 5);
                a.put("time", 4);
                a.put("npcKey", "nc26");
                return a;
            }
            case "11990024": {
                a.put("num", 5);
                a.put("time", 4);
                a.put("npcKey", "nc27");
                return a;
            }
            case "11990025": {
                a.put("num", 5);
                a.put("time", 4);
                a.put("npcKey", "nc28");
                return a;
            }
            case "11990026": {
                a.put("num", 5);
                a.put("time", 4);
                a.put("npcKey", "nc29");
                return a;
            }
            case "11990027": {
                a.put("num", 5);
                a.put("time", 4);
                a.put("npcKey", "nc30");
                return a;
            }
            case "11990028": {
                a.put("num", 5);
                a.put("time", 4);
                a.put("npcKey", "nc31");
                return a;
            }
            case "11990029": {
                a.put("num", 5);
                a.put("time", 4);
                a.put("npcKey", "nc32");
                return a;
            }
            case "11990030": {
                a.put("num", 5);
                a.put("time", 4);
                a.put("npcKey", "nc33");
                return a;
            }
            case "11990031": {
                a.put("num", 6);
                a.put("time", 4);
                a.put("npcKey", "nc34");
                return a;
            }
            case "11990032": {
                a.put("num", 6);
                a.put("time", 4);
                a.put("npcKey", "nc35");
                return a;
            }
            case "11990033": {
                a.put("num", 6);
                a.put("time", 4);
                a.put("npcKey", "nc36");
                return a;
            }
            case "11990034": {
                a.put("num", 6);
                a.put("time", 4);
                a.put("npcKey", "nc37");
                return a;
            }
            case "11990035": {
                a.put("num", 6);
                a.put("time", 4);
                a.put("npcKey", "nc38");
                return a;
            }

        }

        return null;
    }
}
