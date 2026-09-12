package my.gameUtils;

public class baoshiUtils {
    /**
     * 由装备部位判断是否能镶嵌该宝石
     */
    public static boolean isAllowedInlay(String bsKey, String part) {
        String[] arr = getBaoshiPart(bsKey);
        for (String a : arr) {
            if (a.equals(part)) return true;
        }
        return false;
    }

    /**
     * 根据宝石的类型获取其能镶嵌的部位
     */
    public static String[] getBaoshiPart(String key) {
        int bsType = Integer.parseInt(key.substring(4).charAt(3) + "");
        switch (bsType) {
            case 0:
                return new String[]{"wq", "sz", "jb"};//暴击
            case 1:
                return new String[]{"tb", "yb"};//闪避
            case 2:
                return new String[]{"tb", "wb", "sz"};//命中
            case 3:
                return new String[]{"jb", "jiaob"};//mp
            case 4:
                return new String[]{"xb", "tuib"};//hp
            case 5:
                return new String[]{"xb", "tuib", "yb"};//法防
            case 6:
                return new String[]{"xb", "tuib", "yb"};//物防
            case 7:
                return new String[]{"wq", "wb", "sz"};//法攻
            case 8:
                return new String[]{"wq", "wb", "sz"};//物攻
            case 9:
                return new String[]{"jiaob"};//速度
        }
        return null;
    }

    public static String getAttrName(String key) {
        Integer type = Integer.parseInt(key.charAt(3) + "");
        switch (type) {
            case 0: {//暴击
                return "bj";
            }
            case 1: {//闪避
                return "sd";
            }
            case 2: {//命中
                return "mz";
            }
            case 3: {//mp
                return "max_lan";
            }
            case 4: {//hp
                return "max_xue";
            }
            case 5: {//法防
                return "ff";
            }
            case 6: {//物防
                return "wf";
            }
            case 7: {//法攻
                return "fg";
            }
            case 8: {//物攻
                return "wg";
            }
            case 9: {//速度
                return "css";
            }
        }
        return null;
    }

    public static int getBaoshiAttr(String key) {
        int type = Integer.parseInt(key.charAt(3) + "");
        int lv = Integer.parseInt(key.charAt(2) + "") + 1;
        float k = 0f;
        double b = Math.pow(3, lv - 1);
        switch (type) {
            //k*1+b=47  k*2+b=77  k=30 b=17  k+17=168
            case 0: {//暴击
                k = 40;
                break;
            }
            case 1: {//闪避
                k = 20;
                break;
            }
            case 2: {//命中
                k = 40;
                break;
            }
            case 3: {//mp
                k = 80;
                break;
            }
            case 4: {//hp
                k = 100;
                break;
            }
            case 5: {//法防
                k = 20;
                break;
            }
            case 6: {//物防
                k = 20;
                break;
            }
            case 7: {//法攻
                k = 24;
                break;
            }
            case 8: {//物攻
                k = 24;
                break;
            }
            case 9: {//速度
                k = 40;
                break;
            }
        }
        Double res = k * (lv-1) + b;
        return res.intValue();
    }
}
