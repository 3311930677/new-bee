package my.data;

import my.utils.strUtils;

import java.util.ArrayList;
import java.util.List;

/**
 * 任务进度对应的怪物key
 * 由任务触发战斗时使用，任务进度是记录目标key，为单一的，
 * 实际上应该是一个进度触发战斗会产生不止一个的怪物
 */
public class taskProgressToMonKey {
    private static void addToArr(List<String> arr, String... keys) {
        for (String a : keys) {
            arr.add(a);
        }
    }

    /**
     * 由任务key+进度获取
     */
    public static List<String> getMonsterKeysByTask(String taskKey, int progressIndex) {
        List<String> arr = new ArrayList<>();
        int index = Integer.parseInt(taskKey);
        if (index >= 3040 && index < 3070) {//修混
            if (index < 3050) {//炼狱
                arr.add("petxl_" + (index - 3039));
            } else {
                int t = (index - 3050) * 2 + 11;
                //对于混沌的需要重新安排怪物
                if (index == 3061 || index == 3066) {//混2
                    arr.add("petxl_" + (t));
                    arr.add("petxl_" + (t + 1));
                } else if (index == 3062 || index == 3067) {//混3
                    arr.add("petxl_" + (t));
                    for (int i = 0; i < 5; i++) {
                        arr.add("petxl_" + (t + 1));
                    }
                } else if (index == 3063 || index == 3068) {//混4
                    arr.add("petxl_" + (t));
                    for (int i = 0; i < 3; i++) {
                        arr.add("petxl_" + (t + 1));
                    }
                } else if (index == 3064 || index == 3069) {//混5
                    arr.add("petxl_" + (t));
                    for (int i = 0; i < 3; i++) {
                        arr.add("petxl_" + (t + 1));
                    }
                } else {
                    arr.add("petxl_" + (t));
                    for (int i = 0; i < 2; i++) {
                        arr.add("petxl_" + (t + 1));
                    }
                }
            }
            return arr;
        } else if (index >= 3100 && index < 3120) {//门派任务
            String[] targetKey = {"mprw_1", "mprw_2", "mprw_3", "mprw_4", "mprw_5"};
            arr.add(targetKey[index - 3110]);
            return arr;
        } else if (index >= 3120 && index < 3123) {//摸金校尉
            String[] targetKey = {"mjxw_1", "mjxw_2", "mjxw_3"};
            arr.add(targetKey[index - 3120]);
            return arr;
        } else if (index >= 3123 && index < 3131) {//师徒任务
            String[] targetKey = new String[8];
            for (int i = 1; i < 9; i++) {
                targetKey[i - 1] = "shitu_" + i;
            }
            arr.add(targetKey[index - 3123]);
            return arr;
        } else if (index >= 3132 && index < 3135) {//神秘宝藏
            String[] targetKey = new String[3];
            for (int i = 1; i < 4; i++) {
                targetKey[i - 1] = "smbz_" + i;
            }
            arr.add(targetKey[index - 3132]);
            return arr;
        } else if (index >= 3136 && index < 3143) {//门派闯关
            arr.add("ztzs_" + (index - 3135));
            for (int i = 0; i < 9; i++) {
                arr.add("ztzs_" + (index - 3135) + "_1");
            }
            return arr;
        } else if (index >= 3153 && index < 3158) {//帮派任务
            arr.add("bprw_" + (index - 3152));
            return arr;
        } else if (index >= 3163 && index < 3169) {//50副本
            if (index == 3164) {
                arr.add("fb_50_2");
                arr.add("fb_50_1");
                arr.add("fb_50_1");
            } else if (index == 3166) {
                arr.add("fb_50_3");
                arr.add("fb_50_4");
                arr.add("fb_50_4");
            } else if (index == 3168) {
                arr.add("fb_50_6");
                arr.add("fb_50_7");
                arr.add("fb_50_7");
            }
            return arr;
        } else if (index >= 3169 && index < 3175) {//60副本
            if (index == 3170) {
                arr.add("fb_60_3");
                arr.add("fb_60_5");
                arr.add("fb_60_5");
            } else if (index == 3173) {
                arr.add("fb_60_6");
                arr.add("fb_60_7");
            }
            return arr;
        } else if (index >= 3175 && index < 3184) {//70副本
            if (index == 3176) {
                arr.add("fb_70_2");
                arr.add("fb_70_1");
                arr.add("fb_70_1");
            } else if (index == 3178) {
                arr.add("fb_70_3");
                arr.add("fb_70_1");
                arr.add("fb_70_1");
            } else if (index == 3180) {
                arr.add("fb_70_5");
                arr.add("fb_70_6");
            } else if (index == 3182) {
                arr.add("fb_70_7");
                arr.add("fb_70_4");
                arr.add("fb_70_4");
            }
            return arr;
        } else if (index >= 3184 && index < 3189) {//80副本
            if (index == 3186) {
                arr.add("fb_80_4");
                arr.add("fb_80_5");
                arr.add("fb_80_5");
            } else if (index == 3188) {
                arr.add("fb_80_7");
                arr.add("fb_80_6");
                arr.add("fb_80_8");
            }
            return arr;
        } else if (index >= 3189 && index < 3196) {//90副本
            if (index == 3190) {
                arr.add("fb_90_3");
                arr.add("fb_90_2");
                arr.add("fb_90_2");
                arr.add("fb_90_2");
                arr.add("fb_90_2");
                arr.add("fb_90_2");
            } else if (index == 3194) {
                arr.add("fb_90_6");
                arr.add("fb_90_5");
                arr.add("fb_90_5");
            }
            return arr;
        } else if (index >= 3196 && index < 3203) {//100副本
            if (index == 3197) {
                arr.add("fb_100_2");
                arr.add("fb_100_3");
            } else if (index == 3200) {
                arr.add("fb_100_5");
                arr.add("fb_100_4");
                arr.add("fb_100_4");
            }
            return arr;
        } else if (index >= 3203 && index < 3213) {//精英副本1
            if (index == 3206) {
                arr.add("fb_ls_2");
                arr.add("fb_ls_3");
                arr.add("fb_ls_3");
            } else if (index == 3211) {
                arr.add("fb_ls_4");
                arr.add("fb_ls_5");
                arr.add("fb_ls_5");
            }
            return arr;
        } else if (index >= 3213 && index < 3221) {//精英副本2
            if (index == 3217) {
                arr.add("fb_hh_3");
                arr.add("fb_hh_2");
                arr.add("fb_hh_2");
            } else if (index == 3219) {
                arr.add("fb_hh_4");
                arr.add("fb_hh_5");
                arr.add("fb_hh_5");
            }
            return arr;
        } else if (index >= 3221 && index < 3229) {//精英副本3
            if (index == 3224) {
                arr.add("fb_ys_3");
                arr.add("fb_ys_4");
            } else if (index == 3227) {
                arr.add("fb_ys_5");
                arr.add("fb_ys_6");
            }
            return arr;
        } else if (index >= 3229 && index < 3235) {//精英副本4
            if (index == 3232) {
                arr.add("fb_zx_3");
                arr.add("fb_zx_1");
                arr.add("fb_zx_1");
            } else if (index == 3234) {
                arr.add("fb_zx_4");
                arr.add("fb_zx_5");
                arr.add("fb_zx_6");
            }
            return arr;
        } else if (index >= 3235 && index < 3242) {//隐藏
            if (index == 3236) {
                arr.add("fb_yzj_2");
                arr.add("fb_yzj_1");
                arr.add("fb_yzj_1");
            } else if (index == 3238) {
                arr.add("fb_yzj_4");
                arr.add("fb_yzj_5");
                arr.add("fb_yzj_6");
            } else if (index == 3240) {
                arr.add("fb_yzj_8");
                arr.add("fb_yzj_9");
                arr.add("fb_yzj_10");
                arr.add("fb_yzj_11");
            }
            return arr;
        } else if (index >= 3250 && index < 3265) {//隐藏
            if (index == 3252) arr.add("ztzs_1");
            else if (index == 3254) arr.add("ztzs_2");
            else if (index == 3256) arr.add("ztzs_3");
            else if (index == 3258) arr.add("ztzs_4");
            else if (index == 3260) arr.add("ztzs_5");
            else if (index == 3262) arr.add("ztzs_6");
            else if (index == 3264) arr.add("ztzs_7");
            if (index != 3264) {
                for (int i = 0; i < 5; i++) {
                    arr.add("ztzs_8");
                }
            }
            return arr;
        } else if (index == 3272) {//锄奸卫道
            arr.add("jianxi_1");
            return arr;
        } else if (index == 3274) {//洪荒宝库
            arr.add("hhbk_3");
            return arr;
        } else if (index == 3282) {//采阴补阳
            arr.add("cyby_1");
            return arr;
        }else if (index == 3289) {//王者遗产
            arr.add("wzyc");
            return arr;
        }
        //主线任务产生的怪物
        switch (taskKey) {
            case "1001": {
                if (progressIndex == 1)
                    addToArr(arr, "boss_0");
                break;
            }
            case "1002": {
                if (progressIndex == 1)
                    addToArr(arr, "boss_1", "boss_1_0", "boss_1_1", "boss_1_2",
                            "boss_1_3", "boss_1_4");
                break;
            }
            case "1007": {
                if (progressIndex == 0)
                    arr.add("boss_2");
                break;
            }
            case "1009": {
                if (progressIndex == 0)
                    arr.add("boss_3");
                break;
            }
            case "1012": {
                if (progressIndex == 0)
                    arr.add("boss_4");
                break;
            }
            case "1019": {
                if (progressIndex == 0)
                    arr.add("boss_5");
                break;
            }
            case "1021": {
                if (progressIndex == 0)
                    arr.add("boss_6");
                break;
            }
            case "1022": {
                if (progressIndex == 0) {
                    arr.add("boss_7");
                    for (int i = 0; i < 9; i++) {
                        arr.add("boss_7_0");
                    }
                }
                break;
            }
            case "1026": {
                if (progressIndex == 0)
                    arr.add("boss_8");
                break;
            }
            case "1031": {
                if (progressIndex == 0)
                    arr.add("boss_9");
                break;
            }
            case "1038": {
                if (progressIndex == 0)
                    arr.add("boss_10");
                break;
            }
            case "1040": {
                if (progressIndex == 0)
                    arr.add("boss_11");
                break;
            }
            case "1043": {
                if (progressIndex == 0) {
                    arr.add("boss_12");
                    for (int i = 0; i < 9; i++) {
                        arr.add("boss_12_0");
                    }
                }
                break;
            }
            case "1048": {
                if (progressIndex == 0)
                    arr.add("boss_13");
                break;
            }
            case "1049": {
                if (progressIndex == 0)
                    arr.add("boss_14");
                break;
            }
            case "1052": {
                if (progressIndex == 0) {
                    arr.add("boss_15");
                    for (int i = 0; i < 9; i++) {
                        arr.add("boss_15_0");
                    }
                }
                break;
            }
            case "1056": {
                if (progressIndex == 0)
                    arr.add("boss_16");
                break;
            }
            case "1057": {
                if (progressIndex == 0)
                    arr.add("boss_17");
                break;
            }
            case "1059": {
                if (progressIndex == 0)
                    arr.add("boss_18");
                break;
            }
            case "1061": {
                if (progressIndex == 0)
                    arr.add("boss_19");
                break;
            }
            case "1062": {
                if (progressIndex == 0)
                    arr.add("boss_20");
                break;
            }
            case "1064": {
                if (progressIndex == 0)
                    arr.add("boss_21");
                break;
            }
            case "1065": {
                if (progressIndex == 0)
                    arr.add("boss_22");
                break;
            }
            case "1068": {
                if (progressIndex == 0) {
                    arr.add("boss_23");
                    for (int i = 0; i < 9; i++) {
                        arr.add("boss_23_0");
                    }
                }
                break;
            }
            case "1069": {
                if (progressIndex == 0)
                    arr.add("boss_24");
                break;
            }
            case "1073": {
                if (progressIndex == 0)
                    arr.add("boss_25");
                break;
            }
            case "1075": {
                if (progressIndex == 0) {
                    arr.add("boss_26");
                    for (int i = 0; i < 9; i++) {
                        arr.add("boss_26_0");
                    }
                }
                break;
            }
            case "1076": {
                if (progressIndex == 0)
                    arr.add("boss_27");
                break;
            }
            case "1077": {
                if (progressIndex == 0)
                    arr.add("boss_28");
                break;
            }
            case "1085": {
                if (progressIndex == 0) {
                    arr.add("boss_29");
                    for (int i = 0; i < 9; i++) {
                        arr.add("boss_29_0");
                    }
                }
                break;
            }
            case "1090": {
                if (progressIndex == 0)
                    arr.add("boss_30");
                break;
            }
            case "1092": {
                if (progressIndex == 0) {
                    arr.add("boss_31");
                    for (int i = 0; i < 9; i++) {
                        arr.add("boss_31_0");
                    }
                }
                break;
            }
            case "1093": {
                if (progressIndex == 0)
                    arr.add("boss_32");
                break;
            }
            case "1095": {
                if (progressIndex == 0)
                    arr.add("boss_33");
                break;
            }
            case "1097": {
                if (progressIndex == 0)
                    arr.add("boss_34");
                break;
            }
            case "1101": {
                if (progressIndex == 0)
                    arr.add("boss_35");
                break;
            }
            case "1104": {
                if (progressIndex == 0) {
                    arr.add("boss_36");
                    for (int i = 0; i < 9; i++) {
                        arr.add("boss_36_0");
                    }
                }
                break;
            }
            case "1105": {
                if (progressIndex == 0)
                    arr.add("boss_37");
                break;
            }
            case "1107": {
                if (progressIndex == 0)
                    arr.add("boss_38");
                break;
            }
            case "1110": {
                if (progressIndex == 0)
                    arr.add("boss_39");
                break;
            }
            case "1111": {
                if (progressIndex == 0)
                    arr.add("boss_40");
                break;
            }
            //等级突破任务
            case "1112": {
                if (progressIndex == 0)
                    arr.add("tupo_1");
                break;
            }
            case "1113": {
                if (progressIndex == 0)
                    arr.add("tupo_2");
                break;
            }
            case "1114": {
                if (progressIndex == 0)
                    arr.add("tupo_3");
                break;
            }
            case "1115": {
                if (progressIndex == 0)
                    arr.add("tupo_4");
                break;
            }
            case "1116": {
                if (progressIndex == 0)
                    arr.add("tupo_5");
                break;
            }
            case "1117": {
                if (progressIndex == 0)
                    arr.add("tupo_6");
                break;
            }

            default: {
                arr.add("1000");
                arr.add("1000");
                arr.add("1000");
                arr.add("1000");
                arr.add("1000");
                arr.add("1000");
                System.err.println(taskKey + " 该任务找不到对应怪物");
                break;
            }
        }
        return arr;
    }

}
