package my.gameUtils;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;

public class roleUtils {


    /**
     * 是否为基础门派技能
     */
    public static boolean isMenPaiSklKey(String sklKey) {
        if (!sklKey.equals("100210000040") && !sklKey.equals("100210000041") &&
                !sklKey.equals("100210000042") && !sklKey.equals("100210000043") &&
                !sklKey.equals("100210000044") && !sklKey.equals("100210000045")) return false;
        return true;
    }

    /**
     * 将基本门派技能转为职业技能（因为加入分堂后可能从门主npc处学习基本门派技能）
     */
    public static String mpSklToJobSkl(String job, String sklKey) {
        if (job.contains("ms")) {
            if (sklKey.equals("100210000040")) return "100210000002";
            else if (sklKey.equals("100210000041")) return "100210000003";
        } else if (job.contains("dj")) {
            if (sklKey.equals("100210000040")) return "100210000008";
            else if (sklKey.equals("100210000041")) return "100210000009";
        } else if (job.contains("qm")) {
            if (sklKey.equals("100210000042")) return "100210000015";
            else if (sklKey.equals("100210000043")) return "100210000016";
        } else if (job.contains("ty")) {
            if (sklKey.equals("100210000042")) return "100210000021";
            else if (sklKey.equals("100210000043")) return "100210000022";
        } else if (job.contains("ym")) {
            if (sklKey.equals("100210000044")) return "100210000029";
            else if (sklKey.equals("100210000045")) return "100210000030";
        } else if (job.contains("lc")) {
            if (sklKey.equals("100210000044")) return "100210000035";
            else if (sklKey.equals("100210000045")) return "100210000036";
        }
        return sklKey;
    }

    public static String mpSklToJobSkl(JSONObject role, String sklKey) {
        if (!isMenPaiSklKey(sklKey)) return sklKey;
        String job = getJobFromModels(role);
        if (job != null)//说明加入了门派，就要转化
        {
            sklKey = mpSklToJobSkl(job, sklKey);
        }
        return sklKey;
    }

    /**
     * 获取性别
     */
    public static String getSexFromModels(JSONObject role) {
        JSONArray models = JSON.parseArray(role.getString("models"));
        for (Object a : models) {
            if (a.toString().contains("_nan")) return "nan";
            else if (a.toString().contains("_nv")) return "nv";
        }
        return null;
    }

    /**
     * 从model中提取门派
     */
    public static String getMenPaiFromModels(JSONObject role) {
        JSONArray models = JSON.parseArray(role.getString("models"));
        for (Object a : models) {
            if (a.toString().contains("zs_") || a.toString().contains("fs_") ||
                    a.toString().contains("fz_"))
                return a.toString();
        }
        return null;
    }

    /**
     * 从models中提取职业
     */
    public static String getJobFromModels(JSONObject role) {
        JSONArray models = JSON.parseArray(role.getString("models"));
        for (Object a : models) {
            if (a.toString().contains("ms_") || a.toString().contains("dj_") ||
                    a.toString().contains("qm_") || a.toString().contains("ty_") ||
                    a.toString().contains("ym_") || a.toString().contains("lc_"))
                return a.toString();
        }
        return null;
    }

    /**
     * 从数组中选出最终的model
     */
    public static String getModel(JSONObject role) {
        //先选职业
        String md = getJobFromModels(role);
        if (md == null) {
            //不存在则选门派
            md = getMenPaiFromModels(role);
        }
        //还是没有则返回原model
        if (md == null) md = role.getString("model");

        return md;
    }

    /**
     * 根据model返回职业对应的index
     */
    public static int jobToIndex(String job) {
        if (job.contains("ms")) return 0;
        else if (job.contains("dj")) return 1;
        else if (job.contains("qm")) return 2;
        else if (job.contains("ty")) return 3;
        else if (job.contains("ym")) return 4;
        else if (job.contains("lc")) return 5;
        return 0;
    }

    /**
     * 由职业获取法术、物理
     */
    public static Integer jobToType(String job) {
        if (job.contains("qm") || job.contains("ty") || job.contains("fs")) {
            return 1;
        }
        return 0;
    }

    /**
     * 判断是否为5个基础属性之一
     */
    public static boolean isBaseProp(String key) {
        String[] arr = {"ll", "nl", "js", "zl", "mj"};
        for (String a : arr) {
            if (a.equals(key)) return true;
        }
        return false;
    }
}
