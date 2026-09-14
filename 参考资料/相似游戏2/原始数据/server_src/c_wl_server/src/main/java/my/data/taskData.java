package my.data;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.fightUtils.fightUtils;

import java.util.ArrayList;
import java.util.List;

public class taskData {
    private static List<String> taskIndex;

    /**
     * 获取任务奖励key
     */
    public static String getTaskRewardKey(String key) {
        return getTask(key).getString("reward");
    }

    /**
     * 获取任务详情
     */
    public static JSONObject getTask(String key) {
        JSONObject res = null;
        int i = Integer.parseInt(key);
        //天渊40层
        if (i >= 3000 && i < 3040) {
            res = new JSONObject();
            res.put("reward", key);
            if (i == 3000) {
                res.put("condition", getCondition(40, null));
            } else {
                res.put("condition", getCondition(40, i - 1 + ""));
            }
            JSONArray progressList = new JSONArray();//进度列表
            String monKey = "abyss_" + (i - 2999);

            progressList.add(getTaskProgress(4, 1, monKey, 1));
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3040 && i < 3070) {//宠物炼修混
            res = new JSONObject();
            res.put("reward", key);
            if (i == 3040 || i == 3050 || i == 3060) {
                res.put("condition", getCondition(40, null));
            } else {
                res.put("condition", getCondition(40, i - 1 + ""));
            }
            JSONArray progressList = new JSONArray();//进度列表
            String monKey = "petxl_" + (i - 3039);
            if (i >= 3050) {
                monKey = "petxl_" + ((i - 3050) * 2 + 11);
            }
            progressList.add(getTaskProgress(2, 1, monKey, 1));
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3100 && i < 3120) {//职业跑环
            res = new JSONObject();
            res.put("reward", i);
            res.put("condition", getCondition(1, "-1"));
            JSONArray progressList = new JSONArray();//进度列表
            int index = i - 3099;
            int progressType = 0;
            int targetType = 0;//0npc 1怪物
            String targetKey = null;
            int sum = 1;
            if (index < 6) {
                progressType = 0;
                if (index == 1) targetKey = "10000001";
                else if (index == 2) targetKey = "10000002";
                else if (index == 3) targetKey = "10000003";
                else if (index == 4) targetKey = "10000004";
                else if (index == 5) targetKey = "10000007";
            } else if (index < 11) {
                progressType = 1;
                if (index == 6) targetKey = "cj1012";
                else if (index == 7) targetKey = "cj1013";
                else if (index == 8) targetKey = "cj1014";
                else if (index == 9) targetKey = "cj1015";
                else if (index == 10) targetKey = "cj1016";
            } else if (index < 16) {
                progressType = 2;
                targetType = 1;
                if (index == 11) targetKey = "mprw_1";
                else if (index == 12) targetKey = "mprw_2";
                else if (index == 13) targetKey = "mprw_3";
                else if (index == 14) targetKey = "mprw_4";
                else if (index == 15) targetKey = "mprw_5";
            } else if (index < 21) {
                progressType = 4;
                targetType = 1;
                sum = 10;
                if (index == 16) targetKey = "1001";
                else if (index == 17) targetKey = "1002";
                else if (index == 18) targetKey = "1003";
                else if (index == 19) targetKey = "1004";
                else if (index == 20) targetKey = "1005";
            }
            progressList.add(getTaskProgress(progressType, targetType, targetKey, sum));
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3120 && i < 3123) {//摸金校尉
            res = new JSONObject();
            res.put("reward", i);
            res.put("condition", getCondition(30, i == 3120 ? null : (i - 1 + "")));
            JSONArray progressList = new JSONArray();//进度列表
            String[] targetKey = {"mjxw_1", "mjxw_2", "mjxw_3"};
            progressList.add(getTaskProgress(2, 1, targetKey[i - 3120], 1));
            res.put("progressList", progressList);
            return res;
        }
        //师徒任务需要菜单上触发创建，而不用放这里检测开启
        else if (i >= 3123 && i < 3131) {//师徒任务
            res = new JSONObject();
            res.put("reward", i);
            res.put("condition", getCondition(15 + (i - 3123) * 5, "-1"));
            JSONArray progressList = new JSONArray();//进度列表
            String[] targetKey = new String[8];
            for (int j = 1; j < 9; j++) {
                targetKey[j - 1] = "shitu_" + j;
            }
            progressList.add(getTaskProgress(2, 1, targetKey[i - 3123], 1));
            res.put("progressList", progressList);
            return res;
        }
        else if (i >= 3131 && i < 3135) {//幽谷秘宝任务
            //todo：要求任务提交后掉落宝箱，每个任务点掉3个宝箱，记录领取情况
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3131) {
                progressList.add(getTaskProgress(0, 0, "10000079", 1));
                progressList.add(getTaskProgress(4, 1, "smbz_3", 1));
                res.put("condition", getCondition(15, "-1"));
            } else if (i == 3132) {
                progressList.add(getTaskProgress(2, 1, "smbz_1", 1));
                res.put("condition", getCondition(15, "-1"));
            } else if (i == 3133) {
                progressList.add(getTaskProgress(2, 1, "smbz_2", 1));
                res.put("condition", getCondition(15, "3132"));
            } else if (i == 3134) {
                progressList.add(getTaskProgress(2, 1, "smbz_3", 1));
                res.put("condition", getCondition(15, "3133"));
            }

            res.put("progressList", progressList);
            return res;
        } else if (i >= 3143 && i < 3163) {//帮派任务
            res = new JSONObject();
            res.put("reward", i);
            res.put("condition", getCondition(20, "-1"));
            JSONArray progressList = new JSONArray();//进度列表
            int index = i - 3142;
            int progressType = 0;
            int targetType = 0;//0npc 1怪物
            String targetKey = null;
            int sum = 1;
            if (index < 6) {
                progressType = 0;
                if (index == 1) targetKey = "10000000";
                else if (index == 2) targetKey = "10000005";
                else if (index == 3) targetKey = "10000013";
                else if (index == 4) targetKey = "10000059";
                else if (index == 5) targetKey = "10000069";
            } else if (index < 11) {
                progressType = 1;
                if (index == 6) targetKey = "cj1012";
                else if (index == 7) targetKey = "cj1013";
                else if (index == 8) targetKey = "cj1014";
                else if (index == 9) targetKey = "cj1015";
                else if (index == 10) targetKey = "cj1016";
            } else if (index < 16) {
                progressType = 2;
                targetType = 1;
                if (index == 11) targetKey = "bprw_1";
                else if (index == 12) targetKey = "bprw_2";
                else if (index == 13) targetKey = "bprw_3";
                else if (index == 14) targetKey = "bprw_4";
                else if (index == 15) targetKey = "bprw_5";
            } else if (index < 21) {
                progressType = 4;
                targetType = 1;
                sum = 10;
                if (index == 16) targetKey = "1026";
                else if (index == 17) targetKey = "1030";
                else if (index == 18) targetKey = "1031";
                else if (index == 19) targetKey = "1033";
                else if (index == 20) targetKey = "1038";
            }
            progressList.add(getTaskProgress(progressType, targetType, targetKey, sum));
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3163 && i < 3169) {//50副本（4npc，4任务）
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3163) {
                progressList.add(getTaskProgress(4, 1, "fb_50_1", 6));
                res.put("condition", getCondition(50, null));
            } else if (i == 3164) {
                //收集10个胖鼠
                progressList.add(getTaskProgress(2, 1, "fb_50_2", 1));
                res.put("condition", getCondition(50, "3163"));
            } else if (i == 3165) {
                progressList.add(getTaskProgress(0, 0, "10000502", 1));
                res.put("condition", getCondition(50, "3164"));
            } else if (i == 3166) {
                progressList.add(getTaskProgress(2, 1, "fb_50_3", 1));
                res.put("condition", getCondition(50, "3165"));
            } else if (i == 3167) {
                progressList.add(getTaskProgress(4, 1, "fb_50_5", 6));
                res.put("condition", getCondition(50, "3166"));
            } else if (i == 3168) {
                progressList.add(getTaskProgress(2, 1, "fb_50_6", 1));
                progressList.add(getTaskProgress(0, 0, "10000092", 1));
                res.put("condition", getCondition(50, "3167"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3169 && i < 3175) {//60副本（4npc，4任务）
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3169) {
                progressList.add(getTaskProgress(4, 1, "fb_60_1", 6));
                res.put("condition", getCondition(60, null));
            } else if (i == 3170) {
                //收集10个苍龙
                progressList.add(getTaskProgress(2, 1, "fb_60_3", 1));
                res.put("condition", getCondition(60, "3169"));
            } else if (i == 3171) {
                progressList.add(getTaskProgress(4, 1, "fb_60_2", 6));
                res.put("condition", getCondition(60, "3170"));
            } else if (i == 3172) {
                progressList.add(getTaskProgress(4, 1, "fb_60_5", 6));
                res.put("condition", getCondition(60, "3171"));
            } else if (i == 3173) {
                progressList.add(getTaskProgress(2, 1, "fb_60_6", 1));
                res.put("condition", getCondition(60, "3172"));
            } else if (i == 3174) {
                progressList.add(getTaskProgress(0, 0, "10000145", 1));
                res.put("condition", getCondition(60, "3173"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3175 && i < 3184) {//70副本（4npc，4任务）
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3175) {
                progressList.add(getTaskProgress(4, 1, "fb_70_1", 6));
                res.put("condition", getCondition(70, null));
            } else if (i == 3176) {
                progressList.add(getTaskProgress(2, 1, "fb_70_2", 1));
                res.put("condition", getCondition(70, "3175"));
            } else if (i == 3177) {
                progressList.add(getTaskProgress(0, 0, "10000514", 1));
                res.put("condition", getCondition(70, "3176"));
            } else if (i == 3178) {
                progressList.add(getTaskProgress(2, 1, "fb_70_3", 1));
                res.put("condition", getCondition(70, "3177"));
            } else if (i == 3179) {
                progressList.add(getTaskProgress(0, 0, "10000516", 1));
                res.put("condition", getCondition(70, "3178"));
            } else if (i == 3180) {
                progressList.add(getTaskProgress(2, 1, "fb_70_5", 1));
                res.put("condition", getCondition(70, "3179"));
            } else if (i == 3181) {
                progressList.add(getTaskProgress(0, 0, "10000517", 1));
                res.put("condition", getCondition(70, "3180"));
            } else if (i == 3182) {
                progressList.add(getTaskProgress(2, 1, "fb_70_7", 1));
                res.put("condition", getCondition(70, "3181"));
            } else if (i == 3183) {
                progressList.add(getTaskProgress(0, 0, "10000205", 1));
                res.put("condition", getCondition(70, "3182"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3184 && i < 3189) {//80副本（4npc，4任务）
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3184) {
                progressList.add(getTaskProgress(4, 1, "fb_80_1", 6));
                res.put("condition", getCondition(80, null));
            } else if (i == 3185) {
                progressList.add(getTaskProgress(4, 1, "fb_80_2", 6));
                res.put("condition", getCondition(80, "3184"));
            } else if (i == 3186) {
                progressList.add(getTaskProgress(2, 1, "fb_80_4", 1));
                res.put("condition", getCondition(80, "3185"));
            } else if (i == 3187) {
                progressList.add(getTaskProgress(4, 1, "fb_80_3", 6));
                res.put("condition", getCondition(80, "3186"));
            } else if (i == 3188) {
                progressList.add(getTaskProgress(2, 1, "fb_80_7", 1));
                res.put("condition", getCondition(80, "3187"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3189 && i < 3196) {//90副本（4npc，4任务）
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3189) {
                progressList.add(getTaskProgress(4, 1, "fb_90_1", 6));
                res.put("condition", getCondition(90, null));
            } else if (i == 3190) {
                progressList.add(getTaskProgress(2, 1, "fb_90_3", 1));
                res.put("condition", getCondition(90, "3189"));
            } else if (i == 3191) {
                progressList.add(getTaskProgress(4, 1, "fb_90_1", 6));
                res.put("condition", getCondition(90, "3190"));
            } else if (i == 3192) {
                progressList.add(getTaskProgress(4, 1, "fb_90_4", 6));
                res.put("condition", getCondition(90, "3191"));
            } else if (i == 3193) {
                progressList.add(getTaskProgress(0, 0, "10000528", 1));
                res.put("condition", getCondition(90, "3192"));
            } else if (i == 3194) {
                progressList.add(getTaskProgress(2, 1, "fb_90_6", 1));
                res.put("condition", getCondition(90, "3193"));
            } else if (i == 3195) {
                progressList.add(getTaskProgress(0, 0, "10000528", 1));
                res.put("condition", getCondition(90, "3194"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3196 && i < 3203) {//百副
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3196) {
                progressList.add(getTaskProgress(4, 1, "fb_100_1", 6));
                res.put("condition", getCondition(100, null));
            } else if (i == 3197) {
                progressList.add(getTaskProgress(2, 1, "fb_100_2", 1));
                res.put("condition", getCondition(100, "3196"));
            } else if (i == 3198) {
                progressList.add(getTaskProgress(4, 1, "fb_100_4", 6));
                res.put("condition", getCondition(100, "3197"));
            } else if (i == 3199) {
                progressList.add(getTaskProgress(4, 1, "fb_100_4", 6));
                res.put("condition", getCondition(100, "3198"));
            } else if (i == 3200) {
                progressList.add(getTaskProgress(2, 1, "fb_100_5", 1));
                res.put("condition", getCondition(100, "3199"));
            } else if (i == 3201) {
                progressList.add(getTaskProgress(0, 0, "10000532", 1));
                res.put("condition", getCondition(100, "3200"));
            } else if (i == 3202) {
                progressList.add(getTaskProgress(0, 0, "10000427", 1));
                res.put("condition", getCondition(100, "3201"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3203 && i < 3213) {//精英1
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3203) {
                progressList.add(getTaskProgress(0, 0, "10000534", 1));
                res.put("condition", getCondition(95, null));
            } else if (i == 3204) {
                progressList.add(getTaskProgress(4, 1, "fb_ls_1", 6));
                res.put("condition", getCondition(95, "3203"));
            } else if (i == 3205) {
                progressList.add(getTaskProgress(0, 0, "10000536", 1));
                res.put("condition", getCondition(95, "3204"));
            } else if (i == 3206) {
                progressList.add(getTaskProgress(2, 1, "fb_ls_2", 1));
                res.put("condition", getCondition(95, "3205"));
            } else if (i == 3207) {
                progressList.add(getTaskProgress(0, 0, "10000534", 1));
                res.put("condition", getCondition(95, "3206"));
            } else if (i == 3208) {
                progressList.add(getTaskProgress(0, 0, "10000537", 1));
                res.put("condition", getCondition(95, "3207"));
            } else if (i == 3209) {
                progressList.add(getTaskProgress(4, 1, "fb_ls_3", 6));
                res.put("condition", getCondition(95, "3208"));
            } else if (i == 3210) {
                progressList.add(getTaskProgress(0, 0, "10000540", 1));
                res.put("condition", getCondition(95, "3209"));
            } else if (i == 3211) {
                progressList.add(getTaskProgress(2, 1, "fb_ls_4", 1));
                res.put("condition", getCondition(95, "3210"));
            } else if (i == 3212) {
                progressList.add(getTaskProgress(0, 0, "10000379", 1));
                res.put("condition", getCondition(95, "3211"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3213 && i < 3221) {//精英2
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3213) {
                progressList.add(getTaskProgress(0, 0, "10000541", 1));
                res.put("condition", getCondition(95, null));
            } else if (i == 3214) {
                progressList.add(getTaskProgress(4, 1, "fb_hh_1", 6));
                res.put("condition", getCondition(95, "3213"));
            } else if (i == 3215) {
                progressList.add(getTaskProgress(4, 1, "fb_hh_2", 6));
                res.put("condition", getCondition(95, "3214"));
            } else if (i == 3216) {
                progressList.add(getTaskProgress(0, 0, "10000546", 1));
                res.put("condition", getCondition(95, "3215"));
            } else if (i == 3217) {
                progressList.add(getTaskProgress(2, 1, "fb_hh_3", 1));
                res.put("condition", getCondition(95, "3216"));
            } else if (i == 3218) {
                progressList.add(getTaskProgress(0, 0, "10000547", 1));
                res.put("condition", getCondition(95, "3217"));
            } else if (i == 3219) {
                progressList.add(getTaskProgress(2, 1, "fb_hh_4", 1));
                res.put("condition", getCondition(95, "3218"));
            } else if (i == 3220) {
                progressList.add(getTaskProgress(0, 0, "10000399", 1));
                res.put("condition", getCondition(95, "3219"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3221 && i < 3229) {//精英3
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3221) {
                progressList.add(getTaskProgress(4, 1, "fb_ys_1", 6));
                res.put("condition", getCondition(100, null));
            } else if (i == 3222) {
                progressList.add(getTaskProgress(4, 1, "fb_ys_1", 6));
                res.put("condition", getCondition(100, "3221"));
            } else if (i == 3223) {
                progressList.add(getTaskProgress(0, 0, "10000550", 1));
                res.put("condition", getCondition(100, "3222"));
            } else if (i == 3224) {
                progressList.add(getTaskProgress(2, 1, "fb_ys_3", 1));
                res.put("condition", getCondition(100, "3223"));
            } else if (i == 3225) {
                progressList.add(getTaskProgress(0, 0, "10000552", 1));
                res.put("condition", getCondition(100, "3224"));
            } else if (i == 3226) {
                progressList.add(getTaskProgress(4, 1, "fb_ys_2", 6));
                res.put("condition", getCondition(100, "3225"));
            } else if (i == 3227) {
                progressList.add(getTaskProgress(2, 1, "fb_ys_5", 1));
                res.put("condition", getCondition(100, "3226"));
            } else if (i == 3228) {
                progressList.add(getTaskProgress(0, 0, "10000413", 1));
                res.put("condition", getCondition(100, "3227"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3229 && i < 3235) {//精英4
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3229) {
                progressList.add(getTaskProgress(0, 0, "10000554", 1));
                res.put("condition", getCondition(100, null));
            } else if (i == 3230) {
                progressList.add(getTaskProgress(4, 1, "fb_zx_1", 6));
                res.put("condition", getCondition(100, "3229"));
            } else if (i == 3231) {
                progressList.add(getTaskProgress(0, 0, "10000556", 1));
                res.put("condition", getCondition(100, "3230"));
            } else if (i == 3232) {
                progressList.add(getTaskProgress(2, 1, "fb_zx_3", 1));
                res.put("condition", getCondition(100, "3231"));
            } else if (i == 3233) {
                progressList.add(getTaskProgress(4, 1, "fb_zx_2", 6));
                res.put("condition", getCondition(100, "3232"));
            } else if (i == 3234) {
                progressList.add(getTaskProgress(2, 1, "fb_zx_4", 1));
                res.put("condition", getCondition(100, "3233"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3235 && i < 3242) {//隐藏
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3235) {
                progressList.add(getTaskProgress(0, 0, "10000559", 1));
                res.put("condition", getCondition(100, null));
            } else if (i == 3236) {
                progressList.add(getTaskProgress(2, 1, "fb_yzj_2", 1));
                res.put("condition", getCondition(100, "3235"));
            } else if (i == 3237) {
                progressList.add(getTaskProgress(0, 0, "10000561", 1));
                res.put("condition", getCondition(100, "3236"));
            } else if (i == 3238) {
                progressList.add(getTaskProgress(2, 1, "fb_yzj_4", 1));
                res.put("condition", getCondition(100, "3237"));
            } else if (i == 3239) {
                progressList.add(getTaskProgress(0, 0, "10000563", 1));
                res.put("condition", getCondition(100, "3238"));
            } else if (i == 3240) {
                progressList.add(getTaskProgress(2, 1, "fb_yzj_8", 1));
                res.put("condition", getCondition(100, "3239"));
            } else if (i == 3241) {
                progressList.add(getTaskProgress(0, 0, "10000563", 1));
                res.put("condition", getCondition(100, "3240"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3250 && i < 3265) {//震天战神（周日门派）
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3250) {
                progressList.add(getTaskProgress(0, 0, "10000565", 1));
                res.put("condition", getCondition(30, "-1"));
            } else if (i == 3251) {
                progressList.add(getTaskProgress(0, 0, "10000459", 1));
                res.put("condition", getCondition(30, "3250"));
            } else if (i == 3252) {
                progressList.add(getTaskProgress(2, 1, "ztzs_1", 1));
                res.put("condition", getCondition(30, "3251"));
            } else if (i == 3253) {
                progressList.add(getTaskProgress(0, 0, "10000464", 1));
                res.put("condition", getCondition(30, "3252"));
            } else if (i == 3254) {
                progressList.add(getTaskProgress(2, 1, "ztzs_2", 1));
                res.put("condition", getCondition(30, "3253"));
            } else if (i == 3255) {
                progressList.add(getTaskProgress(0, 0, "10000471", 1));
                res.put("condition", getCondition(30, "3254"));
            } else if (i == 3256) {
                progressList.add(getTaskProgress(2, 1, "ztzs_3", 1));
                res.put("condition", getCondition(30, "3255"));
            } else if (i == 3257) {
                progressList.add(getTaskProgress(0, 0, "10000458", 1));
                res.put("condition", getCondition(30, "3256"));
            } else if (i == 3258) {
                progressList.add(getTaskProgress(2, 1, "ztzs_4", 1));
                res.put("condition", getCondition(30, "3257"));
            } else if (i == 3259) {
                progressList.add(getTaskProgress(0, 0, "10000465", 1));
                res.put("condition", getCondition(30, "3258"));
            } else if (i == 3260) {
                progressList.add(getTaskProgress(2, 1, "ztzs_5", 1));
                res.put("condition", getCondition(30, "3259"));
            } else if (i == 3261) {
                progressList.add(getTaskProgress(0, 0, "10000470", 1));
                res.put("condition", getCondition(30, "3260"));
            } else if (i == 3262) {
                progressList.add(getTaskProgress(2, 1, "ztzs_6", 1));
                res.put("condition", getCondition(30, "3261"));
            } else if (i == 3263) {
                progressList.add(getTaskProgress(0, 0, "10000565", 1));
                res.put("condition", getCondition(30, "3262"));
            } else if (i == 3264) {
                progressList.add(getTaskProgress(2, 1, "ztzs_7", 1));
                res.put("condition", getCondition(30, "3263"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3265 && i < 3272) {//魔神窟日常
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3265) {
                progressList.add(getTaskProgress(4, 1, "mshuwei_1", 1));
                res.put("condition", getCondition(60, "-1"));
            } else if (i == 3266) {
                progressList.add(getTaskProgress(4, 1, "mshuwei_2", 1));
                res.put("condition", getCondition(60, "-1"));
            } else if (i == 3267) {
                progressList.add(getTaskProgress(4, 1, "mshuwei_3", 1));
                res.put("condition", getCondition(60, "-1"));
            } else if (i == 3268) {
                progressList.add(getTaskProgress(4, 1, "mshuwei_4", 1));
                res.put("condition", getCondition(60, "-1"));
            } else if (i == 3269) {
                progressList.add(getTaskProgress(4, 1, "mshuwei_5", 1));
                res.put("condition", getCondition(60, "-1"));
            } else if (i == 3270) {
                progressList.add(getTaskProgress(4, 1, "mshuwei_6", 1));
                res.put("condition", getCondition(60, "-1"));
            } else if (i == 3271) {
                progressList.add(getTaskProgress(4, 1, "mshuwei_7", 1));
                res.put("condition", getCondition(60, "-1"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i == 3272) {//锄奸卫道
            res = new JSONObject();
            res.put("reward", key);
            res.put("condition", getCondition(80, "-1"));
            JSONArray progressList = new JSONArray();//进度列表
            progressList.add(getTaskProgress(2, 1, "jianxi_1", 1));
            res.put("progressList", progressList);
            return res;
        } else if (i == 3273) {//仗剑除魔
            res = new JSONObject();
            res.put("reward", key);
            res.put("condition", getCondition(50, "-1"));
            JSONArray progressList = new JSONArray();//进度列表
            progressList.add(getTaskProgress(4, 1, "xhxy_1", 1));
            res.put("progressList", progressList);
            return res;
        } else if (i == 3274) {//洪荒宝库 任务
            res = new JSONObject();
            res.put("reward", key);
            res.put("condition", getCondition(1, "-1"));
            JSONArray progressList = new JSONArray();//进度列表
            progressList.add(getTaskProgress(2, 1, "hhbk_3", 1));
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3275 && i < 3282) {//盗梦空间
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3275) {
                progressList.add(getTaskProgress(4, 1, "dmkj_1", 399));
                res.put("condition", getCondition(70, null));
            } else if (i == 3276) {
                progressList.add(getTaskProgress(4, 1, "dmkj_2", 399));
                res.put("condition", getCondition(75, null));
            } else if (i == 3277) {
                progressList.add(getTaskProgress(4, 1, "dmkj_3", 399));
                res.put("condition", getCondition(80, null));
            } else if (i == 3278) {
                progressList.add(getTaskProgress(4, 1, "dmkj_4", 399));
                res.put("condition", getCondition(85, null));
            } else if (i == 3279) {
                progressList.add(getTaskProgress(4, 1, "dmkj_5", 399));
                res.put("condition", getCondition(90, null));
            } else if (i == 3280) {
                progressList.add(getTaskProgress(4, 1, "dmkj_6", 399));
                res.put("condition", getCondition(95, null));
            } else if (i == 3281) {
                progressList.add(getTaskProgress(4, 1, "dmkj_7", 399));
                res.put("condition", getCondition(100, null));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i == 3282) {//采阴补阳 任务
            res = new JSONObject();
            res.put("reward", key);
            res.put("condition", getCondition(30, "-1"));
            JSONArray progressList = new JSONArray();//进度列表
            progressList.add(getTaskProgress(2, 1, "cyby_1", 1));
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3283 && i < 3288) {//监狱风云
            res = new JSONObject();
            res.put("reward", i);
            JSONArray progressList = new JSONArray();//进度列表
            if (i == 3283) {
                progressList.add(getTaskProgress(4, 1, "jyfy_1", 1));
                res.put("condition", getCondition(30, "-1"));
            } else if (i == 3284) {
                progressList.add(getTaskProgress(4, 1, "jyfy_2", 1));
                res.put("condition", getCondition(30, "-1"));
            } else if (i == 3285) {
                progressList.add(getTaskProgress(4, 1, "jyfy_3", 1));
                res.put("condition", getCondition(30, "-1"));
            } else if (i == 3286) {
                progressList.add(getTaskProgress(4, 1, "jyfy_4", 1));
                res.put("condition", getCondition(30, "-1"));
            } else if (i == 3287) {
                progressList.add(getTaskProgress(4, 1, "jyfy_5", 1));
                res.put("condition", getCondition(30, "-1"));
            }
            res.put("progressList", progressList);
            return res;
        } else if (i >= 3288 && i < 3291) {//王者遗产任务
            if (i == 3288) {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "-1"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000000", 1));
                res.put("progressList", progressList);
                return res;
            } else if (i == 3289) {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "-1"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "wzyc", 1));
                res.put("progressList", progressList);
                return res;
            } else if (i == 3290) {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "-1"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1004", 10));
                res.put("progressList", progressList);
                return res;
            }
        }

        switch (key) {
            /*case "999": {
                res = new JSONObject();
                res.put("reward", "*");
                res.put("condition", getCondition(1, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "1000", 1));
                res.put("progressList", progressList);
                break;
            }*/
            case "1000": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000000", 1));
                progressList.add(getTaskProgress(0, 0, "10000000", 1));
                progressList.add(getTaskProgress(0, 0, "10000000", 1));
                res.put("progressList", progressList);
                break;
            }//4级
            case "1001": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1000"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000003", 1));
                progressList.add(getTaskProgress(2, 1, "boss_0", 1));
                progressList.add(getTaskProgress(0, 0, "10000003", 1));
                res.put("progressList", progressList);
                break;
            }//5
            case "1002": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1001"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000002", 1));
                progressList.add(getTaskProgress(2, 1, "boss_1", 1));
                res.put("progressList", progressList);
                break;
            }//6
            case "1003": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1002"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(1, 0, "cj1000", 1));
                progressList.add(getTaskProgress(0, 0, "10000005", 1));
                progressList.add(getTaskProgress(0, 0, "10000005", 1));
                res.put("progressList", progressList);
                break;
            }//7
            case "1004": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1003"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000009", 1));
                res.put("progressList", progressList);
                break;
            }//8
            case "1005": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1004"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000007", 1));
                res.put("progressList", progressList);
                break;
            }//9
            case "1006": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1005"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000008", 1));
                res.put("progressList", progressList);
                break;
            }//10
            case "1007": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1006"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_2", 1));
                progressList.add(getTaskProgress(0, 0, "10000010", 1));
                res.put("progressList", progressList);
                break;
            }//11
            case "1008": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1007"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1004", 10));
                res.put("progressList", progressList);
                break;
            }//11
            case "1009": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1008"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_3", 1));
                res.put("progressList", progressList);
                break;
            }//12
            case "1010": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1009"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1003", 10));
                res.put("progressList", progressList);
                break;
            }//13
            case "1011": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1010"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000012", 1));
                res.put("progressList", progressList);
                break;
            }//13
            case "1012": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1011"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_4", 1));
                res.put("progressList", progressList);
                break;
            }//14
            case "1013": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1012"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000013", 1));
                res.put("progressList", progressList);
                break;
            }//15
            case "1014": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1013"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000013", 1));
                res.put("progressList", progressList);
                break;
            }//15
            case "1015": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1014"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000014", 1));
                res.put("progressList", progressList);
                break;
            }//16
            case "1016": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1015"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000018", 1));
                progressList.add(getTaskProgress(4, 1, "1005", 10));
                res.put("progressList", progressList);
                break;
            }//17
            case "1017": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1016"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000018", 1));
                res.put("progressList", progressList);
                break;
            }//17
            case "1018": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1017"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000026", 1));
                res.put("progressList", progressList);
                break;
            }//18
            case "1019": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1018"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_5", 1));
                res.put("progressList", progressList);
                break;
            }//19
            case "1020": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1019"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000026", 1));
                res.put("progressList", progressList);
                break;
            }//19
            case "1021": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1020"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_6", 1));
                res.put("progressList", progressList);
                break;
            }//20
            case "1022": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1021"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_7", 1));
                res.put("progressList", progressList);
                break;
            }//21
            case "1023": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1022"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000018", 1));
                res.put("progressList", progressList);
                break;
            }//21
            case "1024": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1023"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000053", 1));
                res.put("progressList", progressList);
                break;
            }//22
            case "1025": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1024"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(1, 0, "cj1001", 1));
                res.put("progressList", progressList);
                break;
            }//23
            case "1026": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1025"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_8", 1));
                res.put("progressList", progressList);
                break;
            }//23
            case "1027": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1026"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1008", 10));
                res.put("progressList", progressList);
                break;
            }//24
            case "1028": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1027"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1009", 10));
                res.put("progressList", progressList);
                break;
            }//25
            case "1029": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1028"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1010", 10));
                res.put("progressList", progressList);
                break;
            }//25
            case "1030": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1029"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000058", 1));
                res.put("progressList", progressList);
                break;
            }//26
            case "1031": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1030"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_9", 1));
                res.put("progressList", progressList);
                break;
            }//27
            case "1032": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1031"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1014", 10));
                res.put("progressList", progressList);
                break;
            }//27
            case "1033": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1032"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000059", 1));
                res.put("progressList", progressList);
                break;
            }//28
            case "1034": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1033"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1013", 10));
                res.put("progressList", progressList);
                break;
            }//29
            case "1035": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1034"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000059", 1));
                res.put("progressList", progressList);
                break;
            }//30
            case "1036": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1035"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1015", 10));
                res.put("progressList", progressList);
                break;
            }//30
            case "1037": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, "1036"));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1016", 10));
                res.put("progressList", progressList);
                break;
            }//31
            case "1038": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_10", 1));
                res.put("progressList", progressList);
                break;
            }//32
            case "1039": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000061", 1));
                res.put("progressList", progressList);
                break;
            }//32
            case "1040": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_11", 1));
                res.put("progressList", progressList);
                break;
            }//33
            case "1041": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1017", 10));
                res.put("progressList", progressList);
                break;
            }//34
            case "1042": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000061", 1));
                res.put("progressList", progressList);
                break;
            }//35
            case "1043": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_12", 1));
                res.put("progressList", progressList);
                break;
            }//35
            case "1044": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000061", 1));
                res.put("progressList", progressList);
                break;
            }//36
            case "1045": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000062", 1));
                res.put("progressList", progressList);
                break;
            }//37
            case "1046": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000062", 1));
                res.put("progressList", progressList);
                break;
            }//38
            case "1047": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1020", 10));
                res.put("progressList", progressList);
                break;
            }//39
            case "1048": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_13", 1));
                res.put("progressList", progressList);
                break;
            }//40
            case "1049": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_14", 1));
                res.put("progressList", progressList);
                break;
            }//41
            case "1050": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1019", 10));
                res.put("progressList", progressList);
                break;
            }//41
            case "1051": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000064", 1));
                res.put("progressList", progressList);
                break;
            }//42
            case "1052": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_15", 1));
                res.put("progressList", progressList);
                break;
            }//43
            case "1053": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000064", 1));
                res.put("progressList", progressList);
                break;
            }//44
            case "1054": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1021", 10));
                res.put("progressList", progressList);
                break;
            }//45
            case "1055": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000068", 1));
                res.put("progressList", progressList);
                break;
            }//45
            case "1056": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_16", 1));
                res.put("progressList", progressList);
                break;
            }//46
            case "1057": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_17", 1));
                res.put("progressList", progressList);
                break;
            }//47
            case "1058": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000067", 1));
                res.put("progressList", progressList);
                break;
            }//48
            case "1059": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_18", 1));
                res.put("progressList", progressList);
                break;
            }//49
            case "1060": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(1, 0, "cj1002", 1));
                res.put("progressList", progressList);
                break;
            }//49
            case "1061": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_19", 1));
                res.put("progressList", progressList);
                break;
            }//50
            case "1062": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_20", 1));
                res.put("progressList", progressList);
                break;
            }//50
            case "1063": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000071", 1));
                res.put("progressList", progressList);
                break;
            }//51
            case "1064": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_21", 1));
                res.put("progressList", progressList);
                break;
            }//51
            case "1065": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_22", 1));
                res.put("progressList", progressList);
                break;
            }//52
            case "1066": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(1, 0, "cj1003", 1));
                res.put("progressList", progressList);
                break;
            }//53
            case "1067": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000075", 1));
                res.put("progressList", progressList);
                break;
            }//53
            case "1068": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_23", 1));
                res.put("progressList", progressList);
                break;
            }//54
            case "1069": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_24", 1));
                res.put("progressList", progressList);
                break;
            }//54
            case "1070": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000075", 1));
                res.put("progressList", progressList);
                break;
            }//55
            case "1071": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1025", 10));
                res.put("progressList", progressList);
                break;
            }//55
            case "1072": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000072", 1));
                res.put("progressList", progressList);
                break;
            }//56
            case "1073": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_25", 1));
                res.put("progressList", progressList);
                break;
            }//56
            case "1074": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1026", 10));
                res.put("progressList", progressList);
                break;
            }//56
            case "1075": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_26", 1));
                res.put("progressList", progressList);
                break;
            }//57
            case "1076": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_27", 1));
                res.put("progressList", progressList);
                break;
            }//57
            case "1077": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_28", 1));
                res.put("progressList", progressList);
                break;
            }//58
            case "1078": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000076", 1));
                res.put("progressList", progressList);
                break;
            }//58
            case "1079": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000077", 1));
                res.put("progressList", progressList);
                break;
            }//59
            case "1080": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000077", 1));
                res.put("progressList", progressList);
                break;
            }//59
            case "1081": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1027", 10));
                res.put("progressList", progressList);
                break;
            }//60
            case "1082": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000079", 1));
                res.put("progressList", progressList);
                break;
            }//60
            case "1083": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000079", 1));
                res.put("progressList", progressList);
                break;
            }//60
            case "1084": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1029", 10));
                res.put("progressList", progressList);
                break;
            }//61
            case "1085": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_29", 1));
                res.put("progressList", progressList);
                break;
            }//61
            case "1086": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000080", 1));
                res.put("progressList", progressList);
                break;
            }//62
            case "1087": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1030", 10));
                res.put("progressList", progressList);
                break;
            }//62
            case "1088": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000078", 1));
                res.put("progressList", progressList);
                break;
            }//62
            case "1089": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1031", 10));
                res.put("progressList", progressList);
                break;
            }//63
            case "1090": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_30", 1));
                res.put("progressList", progressList);
                break;
            }//63
            case "1091": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000082", 1));
                res.put("progressList", progressList);
                break;
            }//63
            case "1092": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_31", 1));
                res.put("progressList", progressList);
                break;
            }//64
            case "1093": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_32", 1));
                res.put("progressList", progressList);
                break;
            }//64
            case "1094": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000084", 1));
                res.put("progressList", progressList);
                break;
            }//65
            case "1095": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_33", 1));
                res.put("progressList", progressList);
                break;
            }//65
            case "1096": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000083", 1));
                res.put("progressList", progressList);
                break;
            }//65
            case "1097": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_34", 1));
                res.put("progressList", progressList);
                break;
            }//66
            case "1098": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000083", 1));
                res.put("progressList", progressList);
                break;
            }//66
            case "1099": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1035", 10));
                res.put("progressList", progressList);
                break;
            }//66
            case "1100": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(4, 1, "1034", 10));
                res.put("progressList", progressList);
                break;
            }//66
            case "1101": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_35", 1));
                res.put("progressList", progressList);
                break;
            }//67
            case "1102": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000087", 1));
                res.put("progressList", progressList);
                break;
            }//67
            case "1103": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000088", 1));
                res.put("progressList", progressList);
                break;
            }//67
            case "1104": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_36", 1));
                res.put("progressList", progressList);
                break;
            }//68
            case "1105": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_37", 1));
                res.put("progressList", progressList);
                break;
            }//68
            case "1106": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000087", 1));
                res.put("progressList", progressList);
                break;
            }//68
            case "1107": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_38", 1));
                res.put("progressList", progressList);
                break;
            }//69
            case "1108": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000087", 1));
                res.put("progressList", progressList);
                break;
            }//69
            case "1109": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000086", 1));
                res.put("progressList", progressList);
                break;
            }//69
            case "1110": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_39", 1));
                res.put("progressList", progressList);
                break;
            }//70
            case "1111": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(1, Integer.parseInt(key) - 1 + ""));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "boss_40", 1));
                res.put("progressList", progressList);
                break;
            }//70
            //====================突破任务==============
            case "1112": {//50突破
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(49, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "tupo_1", 1));
                res.put("progressList", progressList);
                break;
            }
            case "1113": {//60突破
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(59, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "tupo_2", 1));
                res.put("progressList", progressList);
                break;
            }
            case "1114": {//70突破
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(69, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "tupo_3", 1));
                res.put("progressList", progressList);
                break;
            }
            case "1115": {//80突破
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(79, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "tupo_4", 1));
                res.put("progressList", progressList);
                break;
            }
            case "1116": {//90突破
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(89, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "tupo_5", 1));
                res.put("progressList", progressList);
                break;
            }
            case "1117": {//100突破
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(99, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(2, 1, "tupo_6", 1));
                res.put("progressList", progressList);
                break;
            }

            //2000开始是支线
            case "2000": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(15, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000457", 1));
                res.put("progressList", progressList);
                break;
            }
            case "2001": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(30, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000458", 1));
                res.put("progressList", progressList);
                break;
            }
            case "2002": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(15, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000027", 1));
                res.put("progressList", progressList);
                break;
            }
            case "2003": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(15, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000050", 1));
                res.put("progressList", progressList);
                break;
            }
            case "2004": {
                res = new JSONObject();
                res.put("reward", key);
                res.put("condition", getCondition(60, null));
                JSONArray progressList = new JSONArray();//进度列表
                progressList.add(getTaskProgress(0, 0, "10000045", 1));
                res.put("progressList", progressList);
                break;
            }
        }
        return res;
    }

    /**
     * 获取实际存在的任务key
     */
    public static List<String> getTastIndex() {
        if (taskIndex == null) {
            taskIndex = new ArrayList<>();
            for (int i = 1000; i < 5000; i++) {
                if (getTask(i + "") != null) {
                    taskIndex.add(i + "");
                }
            }
        }
        return taskIndex;
    }

    /**
     * 任务进度
     * type 0对话类1摘取2战斗3接取即触发完成4只接取
     * targetType 目标类型 0npc1怪物
     * key npcKey、monsterKey
     * sum 总收集数量
     */
    private static JSONObject getTaskProgress(int type, int targetType, String key, int sum) {
        JSONObject progress = new JSONObject();
        progress.put("type", type);
        JSONObject progressTarget = new JSONObject();
        progressTarget.put("targetType", targetType);
        progressTarget.put("key", key);
        progressTarget.put("sum", sum);
        progress.put("target", progressTarget);
        return progress;
    }

    /**
     * 任务开启条件
     * taskKey 任务链的上一个任务key
     * taskKey=-1表示不参与任务开启检测
     */
    private static JSONObject getCondition(int lever, String taskKey) {
        JSONObject condition = new JSONObject();
        condition.put("lever", lever);//lever是必要条件
        condition.put("taskKey", taskKey);//taskKey不一定都需要
        return condition;
    }


}
