package my.data;

public class cangbaotuData {
    /**
     * 通过品质跟星级来确定藏宝图的key
     */
    public static String getKey(int cbtType, int cbtLv) {
        //14 2 4
        int n = (cbtLv - 1) * 4 + cbtType;
        String str = n + "";
        if (n < 10) str = "000" + str;
        else if (n < 100) str = "00" + str;
        else if (n < 1000) str = "0" + str;
        return "1012" + str;
    }

    /**
     * 获取星级
     */
    public static int getLv(String key) {
        key = key.substring(4);
        return Integer.parseInt(key) / 4 + 1;
    }

    /**
     * 获取品质
     */
    public static int getType(String key) {
        key = key.substring(4);
        return Integer.parseInt(key) % 4;
    }
}
