package my.data;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.model.vector2;
import my.model.vector3;
import my.startBef;
import my.utils.strUtils;

import java.util.ArrayList;
import java.util.List;

public class mapData {

    /**
     * 获取主城key
     */
    public static String[] getMainCityKeys() {
        String[] arr = {
                "m_3", "m_4", "m_5", "m_6",
                "m_18", "m_19", "m_20", "m_21",
                "m_33", "m_34", "m_35", "m_36",
                "m_43", "m_44", "m_45", "m_46",
                "m_63", "m_64", "m_65", "m_66",
        };
        return arr;
    }

    public static vector3 getVc(float x, float z, float y) {
        return new vector3(x, y, z);
    }

    public static vector2 getVc(float x, float y) {
        return new vector2(x, y);
    }

    /**
     * 返回进入地图的初始位置
     */
    public static vector3 getInitPos(String mapKey) {
        if (mapKey.equals("m_1")) return new vector3(70f, 239f, 38f);
        else if (mapKey.equals("m_2")) return new vector3(157f, -41f, 182f);
        else if (mapKey.equals("m_3")) return new vector3(-107f, -100f, 30f);
        else if (mapKey.equals("m_4")) return new vector3(-10f, -63f, 39f);
        else if (mapKey.equals("m_5")) return new vector3(36f, 14f, 20f);
        else if (mapKey.equals("m_6")) return new vector3(54f, -54.5f, -38f);
        else if (mapKey.equals("m_7")) return new vector3(69f, 0.41f, 64f);
        else if (mapKey.equals("m_8")) return new vector3(67f, -39.8f, 62f);
        else if (mapKey.equals("m_9")) return new vector3(130f, 0f, 119f);
        else if (mapKey.equals("m_10")) return new vector3(52f, -34.7f, 92f);
        else if (mapKey.equals("m_11")) return new vector3(30f, -35f, 92f);
        else if (mapKey.equals("m_12")) return new vector3(158f, 3.76f, 144f);
        else if (mapKey.equals("m_13")) return new vector3(301f, 9.2f, 330f);
        else if (mapKey.equals("m_14")) return new vector3(77f, -48.8f, 54f);
        else if (mapKey.equals("m_15")) return new vector3(75f, -48.7f, 68f);
        else if (mapKey.equals("m_16")) return new vector3(23f, 35.1f, 42f);
        else if (mapKey.equals("m_17")) return new vector3(73f, -46.8f, 43f);
        else if (mapKey.equals("m_18")) return new vector3(4f, -29.8f, 18f);
        else if (mapKey.equals("m_19")) return new vector3(96f, -35.8f, 69f);
        else if (mapKey.equals("m_20")) return new vector3(103f, 0.7f, 81f);
        else if (mapKey.equals("m_21")) return new vector3(92f, 12.5f, 72f);
        else if (mapKey.equals("m_22")) return new vector3(117f, 29.96988f, 98f);
        else if (mapKey.equals("m_23")) return new vector3(99f, 28.662f, 101f);
        else if (mapKey.equals("m_24")) return new vector3(111.61f, 31.09879f, 75.9f);
        else if (mapKey.equals("m_25")) return new vector3(-145f, -46f, -125f);
        else if (mapKey.equals("abyss1")) return new vector3(128f, -39.6f, 43f);
        else if (mapKey.equals("petxl")) return new vector3(3f, 11f, 0f);
        else if (mapKey.equals("md1")) return new vector3(21f, -19.9f, 75f);
        else if (mapKey.equals("kongmiao")) return new vector3(117f, -27.3f, 62f);
        else if (mapKey.equals("smbz")) return new vector3(196f, 99.4f, 231f);
        else if (mapKey.equals("cbd")) return new vector3(125f, -59.4f, 54f);
        else if (mapKey.equals("yhmk")) return new vector3(80f, -39.8f, 95f);
        else if (mapKey.equals("dsx")) return new vector3(25f, 0f, 97f);
        else if (mapKey.equals("wzy")) return new vector3(180f, 0f, 69f);
        else if (mapKey.equals("gangs")) return new vector3(183f, 0f, 94f);
        else if (mapKey.equals("ps")) return new vector3(73f, 0.38f, 43f);
        else if (mapKey.equals("bz")) return new vector3(180f, 0f, 69f);

        return new vector3(70f, 0f, 42f);
    }


    private static void addMonster(String key, List<JSONObject> list) {
        addMonster(key, 3, list);
    }

    private static void addMonster(String key, int num, List<JSONObject> list) {
        for (int i = 0; i < num; i++) {
            list.add(getOne(key, getVc(strUtils.getRandom(50, 300), strUtils.getRandom(50, 300)), null));
        }
    }

    /**
     * xq2d的npc数据
     */
    public static List<JSONObject> getXq2dData(String mapKey) {
        List<JSONObject> list = new ArrayList<>();
        switch (mapKey) {
            case "sgzc": {
                list.add(getOne("10000483", getVc(42, 257), null));
                list.add(getOne("10000483", getVc(183, 155), null));
                list.add(getOne("10000483", getVc(197, 212), null));
                list.add(getOne("10000483", getVc(60, 119), null));
                list.add(getOne("10000484", getVc(157, 305), null));
                break;
            }
            case "m_1": {
                list.add(getOne("10000000", getVc(178, 227), null));
                list.add(getOne("10000001", getVc(257, 227), null));
                //list.add(getOne("AbyssTransmit_" + (num - 1), getVc(190, 50), null));
                list.add(getOne("MapTransmit=m_2", getVc(120, 383), null));
                break;
            }
            case "m_2": {
                list.add(getOne("10000002", getVc(206, 236), null));
                list.add(getOne("10000003", getVc(62, 261), null));
                list.add(getOne("10000004", getVc(72, 368), null));
                list.add(getOne("MapTransmit=m_1", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_3", getVc(120, 383), null));
                //采集物（根据任务状态来判断是否显示，采集后立即移除）
                for (int i = 1012; i < 1017; i++) {
                    list.add(getOne("cj" + i, getVc(250, 250), null));
                }

                break;
            }
            case "m_3": {
                list.add(getOne("10000005", getVc(150, 155), null));
                list.add(getOne("10000006", getVc(185, 207), null));
                list.add(getOne("10000007", getVc(169, 275), null));
                list.add(getOne("10000008", getVc(276, 278), null));
                list.add(getOne("10000009", getVc(64, 276), null));
                list.add(getOne("MapTransmit=m_2", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_4", getVc(330, 260), null));
                list.add(getOne("cj1000", getVc(250, 250), null));
                break;
            }
            case "m_4": {
                list.add(getOne("10000010", getVc(75, 316), null));
                list.add(getOne("10000011", getVc(214, 143), null));
                list.add(getOne("10000012", getVc(257, 288), null));
                list.add(getOne("MapTransmit=m_3", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_5", getVc(330, 260), null));
                break;
            }
            case "m_5": {
                list.add(getOne("10000013", getVc(183, 148), null));
                list.add(getOne("MapTransmit=m_4", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_6", getVc(330, 260), null));
                break;
            }
            case "m_6": {
                list.add(getOne("10000014", getVc(77, 142), null));
                list.add(getOne("10000015", getVc(256, 355), null));
                list.add(getOne("10000016", getVc(128, 321), null));
                list.add(getOne("10000017", getVc(273, 167), null));
                list.add(getOne("10000018", getVc(280, 256), null));
                list.add(getOne("10000019", getVc(198, 104), null));
                list.add(getOne("10000020", getVc(102, 239), null));
                list.add(getOne("10000021", getVc(228, 246), null));
                list.add(getOne("10000022", getVc(230, 137), null));
                list.add(getOne("10000023", getVc(200, 200), null));
                list.add(getOne("10000024", getVc(156, 174), null));
                list.add(getOne("MapTransmit=m_5", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_7", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_8", getVc(120, 383), null));
                break;
            }
            case "m_7": {
                list.add(getOne("10000025", getVc(109, 141), null));
                list.add(getOne("10000026", getVc(265, 317), null));
                list.add(getOne("10000027", getVc(290, 165), null));
                list.add(getOne("10000028", getVc(92, 320), null));
                list.add(getOne("10000029", getVc(240, 358), null));
                list.add(getOne("10000030", getVc(63, 259), null));
                list.add(getOne("10000031", getVc(171, 235), null));
                list.add(getOne("10000032", getVc(191, 127), null));
                list.add(getOne("10000033", getVc(136, 351), null));
                list.add(getOne("10000034", getVc(91, 188), null));
                list.add(getOne("10000035", getVc(280, 250), null));
                list.add(getOne("MapTransmit=m_6", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_9", getVc(120, 383), null));
                break;
            }
            case "m_8": {
                list.add(getOne("10000036", getVc(289, 128), null));
                list.add(getOne("10000037", getVc(60, 314), null));
                list.add(getOne("10000038", getVc(143, 394), null));
                list.add(getOne("10000039", getVc(262, 207), null));
                list.add(getOne("10000040", getVc(258, 314), null));
                list.add(getOne("10000041", getVc(106, 184), null));
                list.add(getOne("10000042", getVc(58, 190), null));
                list.add(getOne("10000043", getVc(168, 123), null));
                list.add(getOne("10000044", getVc(150, 314), null));
                list.add(getOne("10000045", getVc(180, 184), null));
                list.add(getOne("10000046", getVc(130, 250), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_6", getVc(190, 50), null));
                //list.add(getOne("MapTransmit=m_9", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_9", getVc(330, 240), null));
                //list.add(getOne("MapTransmit=m_9", getVc(120, 383), null));
                break;
            }
            case "m_9": {
                list.add(getOne("10000047", getVc(193, 166), null));
                list.add(getOne("10000048", getVc(290, 144), null));
                list.add(getOne("10000049", getVc(215, 395), null));
                list.add(getOne("10000050", getVc(65, 362), null));
                list.add(getOne("10000051", getVc(61, 270), null));
                list.add(getOne("10000052", getVc(243, 227), null));
                list.add(getOne("10000053", getVc(150, 100), null));
                list.add(getOne("10000054", getVc(121, 241), null));
                list.add(getOne("10000055", getVc(117, 401), null));
                list.add(getOne("10000056", getVc(242, 300), null));
                list.add(getOne("10000057", getVc(97, 161), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_7", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_8", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_10", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_9", getVc(120, 383), null));
                break;
            }
            case "m_10": {
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_6", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_9", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_11", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_9", getVc(120, 383), null));
                list.add(getOne("cj1001", getVc(250, 250), null));
                break;
            }
            case "m_11": {
                list.add(getOne("10000058", getVc(200, 250), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_6", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_10", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_11", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_12", getVc(120, 383), null));
                break;
            }
            case "m_12": {
//上、左、右、下
                list.add(getOne("MapTransmit=m_11", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_10", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_13", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_14", getVc(120, 383), null));
                break;
            }
            case "m_13": {
                list.add(getOne("10000059", getVc(258, 268), null));
//上、左、右、下
                //list.add(getOne("MapTransmit=m_11", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_12", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_13", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_15", getVc(120, 383), null));
                break;
            }
            case "m_14": {//九江
                list.add(getOne("10000060", getVc(217, 210), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_12", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_12", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_15", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_14", getVc(120, 383), null));

                break;
            }
            case "m_15": {//故道
                list.add(getOne("10000061", getVc(178, 175), null));

                //上、左、右、下
                list.add(getOne("MapTransmit=m_13", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_14", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_16", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_14", getVc(120, 383), null));

                break;
            }
            case "m_16": {
                list.add(getOne("10000062", getVc(126, 235), null));
                list.add(getOne("10000063", getVc(267, 331), null));
                list.add(getOne("10000064", getVc(170, 129), null));
                list.add(getOne("10000065", getVc(69, 337), null));
                list.add(getOne("10000066", getVc(265, 195), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_13", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_15", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_17", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_18", getVc(120, 383), null));

                break;
            }
            case "m_17": {
                list.add(getOne("10000067", getVc(306, 153), null));
                list.add(getOne("10000068", getVc(67, 344), null));
                list.add(getOne("10000069", getVc(59, 195), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_70", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_16", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_17", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_19", getVc(120, 383), null));
                list.add(getOne("cj1002", getVc(250, 250), null));
                break;
            }
            case "m_18": {
                list.add(getOne("10000070", getVc(217, 292), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_16", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_16", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_19", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_19", getVc(120, 383), null));
                list.add(getOne("cj1003", getVc(250, 250), null));
                break;
            }
            case "m_19": {//商业区
                list.add(getOne("10000071", getVc(62, 350), null));
                list.add(getOne("10000014", getVc(217, 285), null));
                list.add(getOne("10000015", getVc(273, 386), null));
                list.add(getOne("10000016", getVc(58, 263), null));
                list.add(getOne("10000017", getVc(282, 174), null));
                list.add(getOne("10000020", getVc(102, 239), null));
                list.add(getOne("10000021", getVc(282, 246), null));
                list.add(getOne("10000022", getVc(230, 137), null));
                list.add(getOne("10000023", getVc(200, 200), null));
                list.add(getOne("10000024", getVc(156, 174), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_17", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_18", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_20", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_21", getVc(120, 383), null));

                break;
            }
            case "m_20": {
                list.add(getOne("10000025", getVc(109, 141), null));
                list.add(getOne("10000027", getVc(290, 165), null));
                list.add(getOne("10000028", getVc(92, 320), null));
                list.add(getOne("10000030", getVc(63, 259), null));
                list.add(getOne("10000031", getVc(171, 235), null));
                list.add(getOne("10000032", getVc(191, 127), null));
                list.add(getOne("10000033", getVc(136, 351), null));
                list.add(getOne("10000034", getVc(91, 188), null));
                list.add(getOne("10000035", getVc(280, 250), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_17", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_19", getVc(20, 190), null));
                //list.add(getOne("MapTransmit=m_20", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_22", getVc(120, 383), null));

                //震天战神活动入口
                if (startBef.activityService.isOpen("ztzs")) {
                    list.add(getOne("10000565", getVc(230, 350), null));
                }
                break;
            }
            case "m_21": {
                list.add(getOne("10000036", getVc(289, 128), null));
                list.add(getOne("10000037", getVc(60, 314), null));
                list.add(getOne("10000038", getVc(143, 394), null));
                list.add(getOne("10000039", getVc(262, 207), null));
                list.add(getOne("10000040", getVc(258, 280), null));
                list.add(getOne("10000041", getVc(106, 184), null));
                list.add(getOne("10000042", getVc(58, 190), null));
                list.add(getOne("10000043", getVc(168, 123), null));
                list.add(getOne("10000044", getVc(150, 314), null));
                list.add(getOne("10000045", getVc(200, 184), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_19", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_19", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_22", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_23", getVc(120, 383), null));

                break;
            }
            case "m_22": {
                list.add(getOne("10000047", getVc(193, 166), null));
                list.add(getOne("10000048", getVc(290, 144), null));
                list.add(getOne("10000049", getVc(180, 395), null));
                list.add(getOne("10000050", getVc(65, 362), null));
                list.add(getOne("10000051", getVc(61, 270), null));
                list.add(getOne("10000055", getVc(117, 401), null));
                list.add(getOne("10000056", getVc(242, 250), null));
                list.add(getOne("10000057", getVc(97, 161), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_20", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_21", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_22", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_23", getVc(120, 383), null));

                break;
            }
            case "m_23": {
                list.add(getOne("10000072", getVc(247, 178), null));
                list.add(getOne("10000073", getVc(247, 300), null));
                list.add(getOne("10000074", getVc(68, 333), null));
                list.add(getOne("10000075", getVc(79, 183), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_21", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_21", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_22", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_24", getVc(120, 383), null));

                break;
            }
            case "m_24": {
                list.add(getOne("10000076", getVc(173, 184), null));
                list.add(getOne("10000077", getVc(111, 318), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_23", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_21", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_32", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_25", getVc(120, 383), null));

                break;
            }
            case "m_25": {
                list.add(getOne("10000078", getVc(286, 144), null));
                list.add(getOne("10000079", getVc(59, 183), null));
                list.add(getOne("10000080", getVc(45, 382), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_24", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_21", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_32", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_26", getVc(120, 383), null));

                break;
            }
            case "m_26": {
                list.add(getOne("10000081", getVc(81, 357), null));
                list.add(getOne("10000082", getVc(272, 158), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_25", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_27", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_32", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_26", getVc(120, 383), null));

                break;
            }
            case "m_27": {
                list.add(getOne("10000083", getVc(228, 135), null));
                list.add(getOne("10000084", getVc(162, 339), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_25", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_29", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_26", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_28", getVc(120, 383), null));

                break;
            }
            case "m_28": {
                list.add(getOne("10000085", getVc(176, 181), null));
                list.add(getOne("10000086", getVc(296, 136), null));
                list.add(getOne("10000087", getVc(303, 279), null));
                list.add(getOne("10000088", getVc(52, 256), null));
                list.add(getOne("10000089", getVc(86, 360), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_27", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_29", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_26", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_53", getVc(120, 383), null));

                break;
            }
            case "m_29": {
                list.add(getOne("10000090", getVc(90, 233), null));
                list.add(getOne("10000091", getVc(249, 157), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_27", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_30", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_27", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_53", getVc(120, 383), null));

                break;
            }
            case "m_30": {
                list.add(getOne("10000092", getVc(153, 338), null));
                list.add(getOne("10000093", getVc(100, 175), null));
                list.add(getOne("10000094", getVc(278, 324), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_27", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_30", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_29", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_31", getVc(120, 383), null));

                break;
            }
            case "m_31": {
                list.add(getOne("10000095", getVc(127, 232), null));
                list.add(getOne("10000096", getVc(275, 160), null));
                list.add(getOne("10000097", getVc(270, 359), null));
                list.add(getOne("10000098", getVc(85, 379), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_30", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_30", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_29", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_31", getVc(120, 383), null));

                break;
            }
            case "m_32": {
                list.add(getOne("10000099", getVc(111, 284), null));
                list.add(getOne("10000100", getVc(63, 304), null));
                list.add(getOne("10000101", getVc(268, 123), null));
                list.add(getOne("10000102", getVc(118, 188), null));
                list.add(getOne("10000103", getVc(134, 392), null));
                list.add(getOne("10000104", getVc(269, 393), null));
                list.add(getOne("10000105", getVc(263, 236), null));
                list.add(getOne("10000106", getVc(187, 112), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_30", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_24", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_33", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_31", getVc(120, 383), null));

                break;
            }
            case "m_33": {
                list.add(getOne("10000107", getVc(223, 165), null));
                list.add(getOne("10000108", getVc(75, 331), null));
                list.add(getOne("10000109", getVc(208, 107), null));
                list.add(getOne("10000110", getVc(293, 348), null));
                list.add(getOne("10000111", getVc(164, 408), null));
                list.add(getOne("10000112", getVc(156, 242), null));
                list.add(getOne("10000113", getVc(104, 161), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_30", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_32", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_34", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_31", getVc(120, 383), null));

                break;
            }
            case "m_34": {
                list.add(getOne("10000114", getVc(144, 338), null));
                list.add(getOne("10000115", getVc(227, 319), null));
                list.add(getOne("10000116", getVc(302, 177), null));
                list.add(getOne("10000117", getVc(207, 118), null));
                list.add(getOne("10000118", getVc(87, 385), null));
                list.add(getOne("10000119", getVc(102, 206), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_30", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_33", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_37", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_31", getVc(120, 383), null));

                break;
            }
            case "m_35": {//商业区
                list.add(getOne("10000014", getVc(82, 360), null));
                list.add(getOne("10000015", getVc(222, 139), null));
                list.add(getOne("10000016", getVc(57, 187), null));
                list.add(getOne("10000017", getVc(221, 282), null));
                list.add(getOne("10000020", getVc(102, 289), null));
                list.add(getOne("10000021", getVc(282, 246), null));
                list.add(getOne("10000022", getVc(150, 107), null));
                list.add(getOne("10000023", getVc(200, 200), null));
                list.add(getOne("10000024", getVc(156, 174), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_30", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_33", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_36", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_37", getVc(120, 383), null));

                break;
            }
            case "m_36": {
                list.add(getOne("10000120", getVc(80, 356), null));
                list.add(getOne("10000025", getVc(109, 121), null));
                list.add(getOne("10000027", getVc(290, 165), null));
                list.add(getOne("10000028", getVc(102, 300), null));
                list.add(getOne("10000030", getVc(43, 259), null));
                list.add(getOne("10000031", getVc(171, 235), null));
                list.add(getOne("10000032", getVc(191, 127), null));
                list.add(getOne("10000033", getVc(136, 351), null));
                list.add(getOne("10000034", getVc(91, 218), null));
                list.add(getOne("10000035", getVc(280, 250), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_42", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_35", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_36", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_38", getVc(120, 383), null));

                break;
            }
            case "m_37": {
                list.add(getOne("10000121", getVc(90, 237), null));
                list.add(getOne("10000036", getVc(269, 128), null));
                list.add(getOne("10000037", getVc(60, 334), null));
                list.add(getOne("10000038", getVc(143, 394), null));
                list.add(getOne("10000039", getVc(262, 207), null));
                list.add(getOne("10000040", getVc(258, 280), null));
                list.add(getOne("10000043", getVc(168, 123), null));
                list.add(getOne("10000044", getVc(150, 314), null));
                list.add(getOne("10000045", getVc(200, 184), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_35", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_34", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_38", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_39", getVc(120, 383), null));

                break;
            }
            case "m_38": {
                list.add(getOne("10000122", getVc(93, 106), null));
                list.add(getOne("10000047", getVc(193, 186), null));
                list.add(getOne("10000048", getVc(200, 100), null));
                list.add(getOne("10000049", getVc(180, 395), null));
                list.add(getOne("10000050", getVc(45, 342), null));
                list.add(getOne("10000051", getVc(61, 270), null));
                list.add(getOne("10000055", getVc(117, 401), null));
                list.add(getOne("10000056", getVc(242, 250), null));
                list.add(getOne("10000057", getVc(97, 161), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_36", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_37", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_38", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_39", getVc(120, 383), null));

                break;
            }
            case "m_39": {
                list.add(getOne("10000123", getVc(187, 202), null));
                list.add(getOne("10000124", getVc(55, 248), null));
                list.add(getOne("10000125", getVc(252, 311), null));
                list.add(getOne("10000126", getVc(76, 362), null));
                list.add(getOne("10000127", getVc(301, 180), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_38", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_37", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_38", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_40", getVc(120, 383), null));

                break;
            }
            case "m_40": {
                list.add(getOne("10000128", getVc(50, 201), null));
                list.add(getOne("10000129", getVc(83, 245), null));
                list.add(getOne("10000130", getVc(51, 297), null));
                list.add(getOne("10000131", getVc(274, 119), null));
                list.add(getOne("10000132", getVc(188, 149), null));
                list.add(getOne("10000133", getVc(276, 343), null));
                list.add(getOne("10000134", getVc(287, 240), null));
                list.add(getOne("10000135", getVc(150, 326), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_39", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_37", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_38", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_41", getVc(120, 383), null));

                break;
            }
            case "m_41": {
                list.add(getOne("10000136", getVc(124, 146), null));
                list.add(getOne("10000137", getVc(201, 285), null));
                list.add(getOne("10000138", getVc(143, 306), null));
                list.add(getOne("10000139", getVc(50, 246), null));
                list.add(getOne("10000140", getVc(43, 329), null));
                list.add(getOne("10000141", getVc(282, 351), null));
                list.add(getOne("10000142", getVc(298, 193), null));
                list.add(getOne("10000143", getVc(295, 114), null));
                list.add(getOne("10000144", getVc(125, 395), null));
                list.add(getOne("10000145", getVc(37, 402), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_40", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_37", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_38", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_41", getVc(120, 383), null));

                break;
            }
            case "m_42": {
                list.add(getOne("10000146", getVc(264, 138), null));
                list.add(getOne("10000147", getVc(118, 249), null));
                list.add(getOne("10000148", getVc(151, 336), null));
                list.add(getOne("10000149", getVc(298, 346), null));
                list.add(getOne("10000150", getVc(48, 314), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_43", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_37", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_45", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_36", getVc(120, 383), null));

                break;
            }
            case "m_43": {
                list.add(getOne("10000151", getVc(125, 137), null));
                list.add(getOne("10000152", getVc(206, 134), null));
                list.add(getOne("10000153", getVc(87, 308), null));
                list.add(getOne("10000154", getVc(66, 202), null));
                list.add(getOne("10000155", getVc(45, 384), null));
                list.add(getOne("10000156", getVc(198, 264), null));
                list.add(getOne("10000157", getVc(289, 340), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_43", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_37", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_44", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_42", getVc(120, 383), null));

                break;
            }
            case "m_44": {
                list.add(getOne("10000158", getVc(252, 150), null));
                list.add(getOne("10000159", getVc(102, 168), null));
                list.add(getOne("10000160", getVc(170, 251), null));
                list.add(getOne("10000161", getVc(127, 345), null));
                list.add(getOne("10000162", getVc(291, 345), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_51", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_43", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_46", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_45", getVc(120, 383), null));

                break;
            }
            case "m_45": {
                list.add(getOne("10000163", getVc(212, 242), null));
                list.add(getOne("10000164", getVc(50, 323), null));
                list.add(getOne("10000165", getVc(204, 377), null));
                list.add(getOne("10000166", getVc(102, 207), null));
                list.add(getOne("10000167", getVc(238, 111), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_44", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_42", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_47", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_45", getVc(120, 383), null));

                break;
            }
            case "m_46": {
                list.add(getOne("10000168", getVc(202, 219), null));
                list.add(getOne("10000169", getVc(302, 184), null));
                list.add(getOne("10000170", getVc(111, 156), null));
                list.add(getOne("10000171", getVc(63, 360), null));
                list.add(getOne("10000172", getVc(289, 315), null));
                list.add(getOne("10000173", getVc(258, 120), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_52", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_44", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_47", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_47", getVc(120, 383), null));

                break;
            }
            case "m_47": {
                list.add(getOne("10000174", getVc(301, 161), null));
                list.add(getOne("10000175", getVc(130, 151), null));
                list.add(getOne("10000176", getVc(159, 358), null));
                list.add(getOne("10000177", getVc(242, 291), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_46", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_45", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_50", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_48", getVc(120, 383), null));

                break;
            }
            case "m_48": {
                list.add(getOne("10000178", getVc(98, 179), null));
                list.add(getOne("10000179", getVc(272, 278), null));
                list.add(getOne("10000180", getVc(174, 157), null));
                list.add(getOne("10000181", getVc(88, 397), null));
                list.add(getOne("10000182", getVc(189, 335), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_47", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_45", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_49", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_48", getVc(120, 383), null));

                break;
            }
            case "m_49": {
                list.add(getOne("10000183", getVc(70, 362), null));
                list.add(getOne("10000184", getVc(132, 362), null));
                list.add(getOne("10000185", getVc(259, 113), null));
                list.add(getOne("10000186", getVc(174, 192), null));
                list.add(getOne("10000187", getVc(72, 263), null));
                list.add(getOne("10000188", getVc(317, 293), null));
                list.add(getOne("10000189", getVc(227, 396), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_50", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_48", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_49", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_48", getVc(120, 383), null));

                break;
            }
            case "m_50": {
                list.add(getOne("10000190", getVc(64, 272), null));
                list.add(getOne("10000191", getVc(133, 271), null));
                list.add(getOne("10000192", getVc(245, 107), null));
                list.add(getOne("10000193", getVc(232, 199), null));
                list.add(getOne("10000194", getVc(41, 398), null));
                list.add(getOne("10000195", getVc(291, 356), null));
                list.add(getOne("10000196", getVc(156, 134), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_50", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_47", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_49", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_49", getVc(120, 383), null));

                break;
            }
            case "m_51": {
                list.add(getOne("10000197", getVc(184, 139), null));
                list.add(getOne("10000198", getVc(135, 200), null));
                list.add(getOne("10000199", getVc(90, 337), null));
                list.add(getOne("10000200", getVc(268, 379), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_50", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_47", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_52", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_44", getVc(120, 383), null));

                break;
            }
            case "m_52": {
                list.add(getOne("10000049", getVc(306, 358), null));
                list.add(getOne("10000014", getVc(235, 150), null));
                list.add(getOne("10000201", getVc(57, 372), null));
                list.add(getOne("10000202", getVc(99, 329), null));
                list.add(getOne("10000203", getVc(44, 299), null));
                list.add(getOne("10000204", getVc(126, 226), null));
                list.add(getOne("10000205", getVc(311, 248), null));
                list.add(getOne("10000206", getVc(66, 153), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_50", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_51", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_52", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_46", getVc(120, 383), null));

                break;
            }
            case "m_53": {
                list.add(getOne("10000207", getVc(88, 205), null));
                list.add(getOne("10000208", getVc(277, 136), null));
                list.add(getOne("10000209", getVc(301, 321), null));
                list.add(getOne("10000210", getVc(52, 328), null));
                list.add(getOne("10000211", getVc(142, 288), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_28", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_47", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_52", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_54", getVc(120, 383), null));

                break;
            }
            case "m_54": {
                list.add(getOne("10000212", getVc(259, 357), null));
                list.add(getOne("10000213", getVc(88, 212), null));
                list.add(getOne("10000214", getVc(241, 125), null));
                list.add(getOne("10000215", getVc(55, 331), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_53", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_47", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_52", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_55", getVc(120, 383), null));

                break;
            }
            case "m_55": {
                list.add(getOne("10000216", getVc(255, 333), null));
                list.add(getOne("10000217", getVc(279, 184), null));
                list.add(getOne("10000218", getVc(106, 206), null));
                list.add(getOne("10000219", getVc(79, 290), null));
                list.add(getOne("10000220", getVc(176, 300), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_54", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_66", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_52", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_56", getVc(120, 383), null));

                break;
            }
            case "m_56": {//商业区
                list.add(getOne("10000014", getVc(92, 360), null));
                list.add(getOne("10000015", getVc(222, 139), null));
                list.add(getOne("10000016", getVc(57, 167), null));
                list.add(getOne("10000017", getVc(221, 282), null));
                list.add(getOne("10000020", getVc(102, 289), null));
                list.add(getOne("10000021", getVc(262, 246), null));
                list.add(getOne("10000022", getVc(150, 107), null));
                list.add(getOne("10000023", getVc(200, 200), null));
                list.add(getOne("10000024", getVc(156, 174), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_55", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_67", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_57", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_58", getVc(120, 383), null));

                break;
            }
            case "m_57": {
                list.add(getOne("10000120", getVc(80, 356), null));
                list.add(getOne("10000025", getVc(109, 121), null));
                list.add(getOne("10000027", getVc(290, 165), null));
                list.add(getOne("10000028", getVc(102, 300), null));
                list.add(getOne("10000030", getVc(43, 120), null));
                list.add(getOne("10000031", getVc(171, 235), null));
                list.add(getOne("10000032", getVc(181, 127), null));
                list.add(getOne("10000033", getVc(136, 351), null));
                list.add(getOne("10000034", getVc(91, 218), null));
                list.add(getOne("10000035", getVc(270, 250), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_55", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_56", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_63", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_59", getVc(120, 383), null));

                break;
            }
            case "m_58": {
                list.add(getOne("10000221", getVc(90, 237), null));
                list.add(getOne("10000036", getVc(269, 128), null));
                list.add(getOne("10000037", getVc(60, 334), null));
                list.add(getOne("10000038", getVc(143, 394), null));
                list.add(getOne("10000039", getVc(262, 207), null));
                list.add(getOne("10000040", getVc(258, 280), null));
                list.add(getOne("10000043", getVc(168, 123), null));
                list.add(getOne("10000044", getVc(150, 314), null));
                list.add(getOne("10000045", getVc(150, 194), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_56", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_56", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_59", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_60", getVc(120, 383), null));

                break;
            }
            case "m_59": {
                list.add(getOne("10000222", getVc(73, 106), null));
                list.add(getOne("10000047", getVc(193, 186), null));
                list.add(getOne("10000048", getVc(200, 100), null));
                list.add(getOne("10000049", getVc(180, 395), null));
                list.add(getOne("10000050", getVc(65, 342), null));
                list.add(getOne("10000051", getVc(61, 270), null));
                list.add(getOne("10000055", getVc(117, 301), null));
                list.add(getOne("10000056", getVc(242, 250), null));
                list.add(getOne("10000057", getVc(97, 161), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_57", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_58", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_62", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_61", getVc(120, 383), null));

                break;
            }
            case "m_60": {
                list.add(getOne("10000223", getVc(286, 176), null));
                list.add(getOne("10000224", getVc(266, 311), null));
                list.add(getOne("10000225", getVc(74, 299), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_58", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_58", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_61", getVc(330, 260), null));
                //ist.add(getOne("MapTransmit=m_61", getVc(120, 383), null));

                break;
            }
            case "m_61": {
                list.add(getOne("10000226", getVc(248, 174), null));
                list.add(getOne("10000227", getVc(274, 292), null));
                list.add(getOne("10000228", getVc(257, 97), null));
                list.add(getOne("10000229", getVc(243, 374), null));
                list.add(getOne("10000230", getVc(97, 368), null));
                list.add(getOne("10000231", getVc(96, 175), null));
                list.add(getOne("10000232", getVc(56, 313), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_59", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_60", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_65", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_61", getVc(120, 383), null));

                break;
            }
            case "m_62": {
                list.add(getOne("10000233", getVc(215, 217), null));
                list.add(getOne("10000234", getVc(294, 142), null));
                list.add(getOne("10000235", getVc(98, 149), null));
                list.add(getOne("10000236", getVc(67, 382), null));
                list.add(getOne("10000237", getVc(118, 271), null));
                list.add(getOne("10000238", getVc(262, 358), null));
                list.add(getOne("10000239", getVc(272, 275), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_63", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_59", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_64", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_65", getVc(120, 383), null));

                break;
            }
            case "m_63": {
                list.add(getOne("10000240", getVc(73, 185), null));
                list.add(getOne("10000241", getVc(249, 141), null));
                list.add(getOne("10000242", getVc(203, 254), null));
                list.add(getOne("10000243", getVc(141, 360), null));
                list.add(getOne("10000244", getVc(156, 109), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_63", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_57", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_64", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_62", getVc(120, 383), null));

                break;
            }
            case "m_64": {
                list.add(getOne("10000245", getVc(60, 232), null));
                list.add(getOne("10000246", getVc(266, 247), null));
                list.add(getOne("10000247", getVc(234, 107), null));
                list.add(getOne("10000248", getVc(39, 343), null));
                list.add(getOne("10000249", getVc(241, 381), null));
                list.add(getOne("10000250", getVc(145, 342), null));
                list.add(getOne("10000251", getVc(95, 161), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_63", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_62", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_64", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_62", getVc(120, 383), null));

                break;
            }
            case "m_65": {
                list.add(getOne("10000252", getVc(115, 184), null));
                list.add(getOne("10000253", getVc(285, 314), null));
                list.add(getOne("10000254", getVc(280, 120), null));
                list.add(getOne("10000255", getVc(69, 312), null));
                list.add(getOne("10000256", getVc(164, 364), null));
                list.add(getOne("10000257", getVc(281, 400), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_62", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_61", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_64", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_62", getVc(120, 383), null));

                break;
            }
            case "m_66": {
                list.add(getOne("10000258", getVc(192, 254), null));
                list.add(getOne("10000259", getVc(308, 163), null));
                list.add(getOne("10000260", getVc(114, 166), null));
                list.add(getOne("10000261", getVc(63, 376), null));
                list.add(getOne("10000262", getVc(59, 243), null));
                list.add(getOne("10000263", getVc(281, 362), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_62", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_69", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_55", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_67", getVc(120, 383), null));

                break;
            }
            case "m_67": {
                list.add(getOne("10000264", getVc(241, 188), null));
                list.add(getOne("10000265", getVc(198, 114), null));
                list.add(getOne("10000266", getVc(109, 242), null));
                list.add(getOne("10000267", getVc(75, 378), null));
                list.add(getOne("10000268", getVc(279, 385), null));
                list.add(getOne("10000269", getVc(107, 138), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_66", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_68", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_56", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_67", getVc(120, 383), null));

                break;
            }
            case "m_68": {
                list.add(getOne("10000270", getVc(269, 360), null));
                list.add(getOne("10000271", getVc(196, 360), null));
                list.add(getOne("10000272", getVc(145, 255), null));
                list.add(getOne("10000273", getVc(55, 199), null));
                list.add(getOne("10000274", getVc(199, 131), null));
                list.add(getOne("10000272", getVc(97, 126), null));
                list.add(getOne("10000276", getVc(62, 319), null));
                list.add(getOne("10000277", getVc(105, 404), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_69", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_68", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_67", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_67", getVc(120, 383), null));

                break;
            }
            case "m_69": {
                list.add(getOne("10000278", getVc(171, 211), null));
                list.add(getOne("10000279", getVc(155, 333), null));
                list.add(getOne("10000280", getVc(258, 144), null));
                list.add(getOne("10000281", getVc(285, 282), null));
                list.add(getOne("10000282", getVc(43, 301), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_69", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_68", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_66", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_68", getVc(120, 383), null));

                break;
            }
            case "m_70": {
                list.add(getOne("10000283", getVc(198, 229), null));
                list.add(getOne("10000284", getVc(228, 110), null));
                list.add(getOne("10000285", getVc(54, 238), null));
                list.add(getOne("10000286", getVc(53, 385), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_69", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_68", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_71", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_17", getVc(120, 383), null));

                break;
            }
            case "m_71": {
                list.add(getOne("10000287", getVc(265, 349), null));
                list.add(getOne("10000288", getVc(234, 222), null));
                list.add(getOne("10000289", getVc(76, 306), null));
                list.add(getOne("10000290", getVc(145, 133), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_72", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_70", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_71", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_17", getVc(120, 383), null));

                break;
            }
            case "m_72": {
                list.add(getOne("10000291", getVc(139, 335), null));
                list.add(getOne("10000292", getVc(210, 341), null));
                list.add(getOne("10000293", getVc(270, 112), null));
                list.add(getOne("10000294", getVc(101, 273), null));
                list.add(getOne("10000295", getVc(275, 229), null));
                list.add(getOne("10000296", getVc(58, 390), null));
                list.add(getOne("10000297", getVc(160, 178), null));
                list.add(getOne("10000298", getVc(90, 151), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_75", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_70", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_73", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_71", getVc(120, 383), null));

                break;
            }
            case "m_73": {
                list.add(getOne("10000299", getVc(260, 249), null));
                list.add(getOne("10000300", getVc(306, 105), null));
                list.add(getOne("10000301", getVc(39, 191), null));
                list.add(getOne("10000302", getVc(121, 151), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_74", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_72", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_73", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_71", getVc(120, 383), null));

                break;
            }
            case "m_74": {
                list.add(getOne("10000303", getVc(293, 300), null));
                list.add(getOne("10000304", getVc(239, 323), null));
                list.add(getOne("10000305", getVc(274, 123), null));
                list.add(getOne("10000306", getVc(192, 201), null));
                list.add(getOne("10000307", getVc(91, 270), null));
                list.add(getOne("10000308", getVc(93, 164), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_77", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_75", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_73", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_73", getVc(120, 383), null));

                break;
            }
            case "m_75": {
                list.add(getOne("10000309", getVc(171, 214), null));
                list.add(getOne("10000310", getVc(295, 132), null));
                list.add(getOne("10000311", getVc(96, 174), null));
                list.add(getOne("10000312", getVc(51, 368), null));
                list.add(getOne("10000313", getVc(272, 244), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_76", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_75", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_74", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_72", getVc(120, 383), null));

                break;
            }
            case "m_76": {
                list.add(getOne("10000314", getVc(171, 214), null));
                list.add(getOne("10000315", getVc(295, 132), null));
                list.add(getOne("10000316", getVc(96, 174), null));
                list.add(getOne("10000036", getVc(269, 128), null));
                list.add(getOne("10000037", getVc(60, 334), null));
                list.add(getOne("10000038", getVc(143, 394), null));
                list.add(getOne("10000039", getVc(262, 207), null));
                list.add(getOne("10000040", getVc(258, 280), null));
                list.add(getOne("10000043", getVc(168, 123), null));
                list.add(getOne("10000044", getVc(150, 314), null));
                list.add(getOne("10000045", getVc(200, 184), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_79", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_81", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_77", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_75", getVc(120, 383), null));

                break;
            }
            case "m_77": {
                list.add(getOne("10000317", getVc(166, 219), null));
                list.add(getOne("10000318", getVc(97, 220), null));
                list.add(getOne("10000319", getVc(305, 153), null));
                list.add(getOne("10000320", getVc(192, 320), null));
                list.add(getOne("10000321", getVc(51, 370), null));
                list.add(getOne("10000322", getVc(301, 340), null));
                list.add(getOne("10000323", getVc(298, 253), null));
                list.add(getOne("10000324", getVc(122, 125), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_78", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_76", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_77", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_74", getVc(120, 383), null));

                break;
            }
            case "m_78": {
                list.add(getOne("10000325", getVc(169, 218), null));
                list.add(getOne("10000326", getVc(301, 138), null));
                list.add(getOne("10000327", getVc(110, 158), null));
                list.add(getOne("10000328", getVc(37, 329), null));
                list.add(getOne("10000329", getVc(299, 378), null));
                list.add(getOne("10000330", getVc(131, 334), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_78", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_79", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_77", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_77", getVc(120, 383), null));

                break;
            }
            case "m_79": {
                list.add(getOne("10000331", getVc(184, 333), null));
                list.add(getOne("10000332", getVc(114, 338), null));
                list.add(getOne("10000333", getVc(285, 110), null));
                list.add(getOne("10000334", getVc(142, 135), null));
                list.add(getOne("10000335", getVc(75, 206), null));
                list.add(getOne("10000336", getVc(286, 368), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_78", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_80", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_78", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_76", getVc(120, 383), null));

                break;
            }
            case "m_80": {
                list.add(getOne("10000337", getVc(154, 260), null));
                list.add(getOne("10000338", getVc(229, 167), null));
                list.add(getOne("10000339", getVc(94, 151), null));
                list.add(getOne("10000340", getVc(263, 101), null));
                list.add(getOne("10000341", getVc(196, 333), null));
                list.add(getOne("10000342", getVc(83, 371), null));
                list.add(getOne("10000343", getVc(246, 234), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_82", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_80", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_79", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_81", getVc(120, 383), null));

                break;
            }
            case "m_81": {
                list.add(getOne("10000344", getVc(110, 201), null));
                list.add(getOne("10000345", getVc(196, 201), null));
                list.add(getOne("10000346", getVc(271, 157), null));
                list.add(getOne("10000347", getVc(37, 274), null));
                list.add(getOne("10000348", getVc(50, 381), null));
                list.add(getOne("10000349", getVc(145, 351), null));
                list.add(getOne("10000350", getVc(280, 328), null));
                list.add(getOne("10000351", getVc(241, 404), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_80", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_80", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_76", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_81", getVc(120, 383), null));

                break;
            }
            case "m_82": {
                list.add(getOne("10000352", getVc(118, 258), null));
                list.add(getOne("10000353", getVc(91, 280), null));
                list.add(getOne("10000354", getVc(266, 140), null));
                list.add(getOne("10000355", getVc(112, 172), null));
                list.add(getOne("10000356", getVc(51, 370), null));
                list.add(getOne("10000357", getVc(306, 250), null));
                list.add(getOne("10000358", getVc(303, 338), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_80", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_83", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_76", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_80", getVc(120, 383), null));

                break;
            }
            case "m_83": {
                list.add(getOne("10000359", getVc(238, 228), null));
                list.add(getOne("10000360", getVc(154, 121), null));
                list.add(getOne("10000361", getVc(96, 188), null));
                list.add(getOne("10000362", getVc(26, 287), null));
                list.add(getOne("10000363", getVc(158, 343), null));
                list.add(getOne("10000364", getVc(305, 171), null));
                list.add(getOne("10000365", getVc(191, 406), null));
                list.add(getOne("10000366", getVc(269, 355), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_80", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_84", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_82", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_80", getVc(120, 383), null));

                break;
            }
            case "m_84": {
                list.add(getOne("10000367", getVc(74, 217), null));
                list.add(getOne("10000368", getVc(286, 354), null));
                list.add(getOne("10000369", getVc(307, 112), null));
                list.add(getOne("10000370", getVc(183, 174), null));
                list.add(getOne("10000371", getVc(107, 288), null));
                list.add(getOne("10000372", getVc(172, 365), null));
                list.add(getOne("10000373", getVc(253, 235), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_86", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_87", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_85", getVc(120, 383), null));

                break;
            }
            case "m_85": {
                list.add(getOne("10000374", getVc(221, 207), null));
                list.add(getOne("10000375", getVc(266, 113), null));
                list.add(getOne("10000376", getVc(63, 205), null));
                list.add(getOne("10000377", getVc(120, 398), null));
                list.add(getOne("10000378", getVc(296, 376), null));
                list.add(getOne("10000379", getVc(296, 250), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_84", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_87", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_85", getVc(120, 383), null));

                break;
            }
            case "m_86": {
                list.add(getOne("10000380", getVc(265, 359), null));
                list.add(getOne("10000381", getVc(274, 124), null));
                list.add(getOne("10000382", getVc(112, 124), null));
                list.add(getOne("10000383", getVc(57, 296), null));
                list.add(getOne("10000384", getVc(230, 284), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_89", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_88", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_84", getVc(120, 383), null));

                break;
            }
            case "m_87": {
                list.add(getOne("10000385", getVc(265, 359), null));
                list.add(getOne("10000386", getVc(274, 124), null));
                list.add(getOne("10000387", getVc(112, 124), null));
                list.add(getOne("10000388", getVc(57, 296), null));
                list.add(getOne("10000389", getVc(230, 284), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_88", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_88", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_84", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_84", getVc(120, 383), null));

                break;
            }
            case "m_88": {
                list.add(getOne("10000390", getVc(102, 369), null));
                list.add(getOne("10000391", getVc(219, 128), null));
                list.add(getOne("10000392", getVc(45, 236), null));
                list.add(getOne("10000393", getVc(276, 300), null));
                list.add(getOne("10000394", getVc(175, 199), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_93", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_88", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_86", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_87", getVc(120, 383), null));

                break;
            }
            case "m_89": {
                list.add(getOne("10000395", getVc(229, 141), null));
                list.add(getOne("10000396", getVc(85, 171), null));
                list.add(getOne("10000397", getVc(189, 287), null));
                list.add(getOne("10000398", getVc(290, 382), null));
                list.add(getOne("10000399", getVc(290, 200), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_93", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_93", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_86", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_86", getVc(120, 383), null));

                break;
            }
            case "m_90": {//商业区
                list.add(getOne("10000400", getVc(305, 275), null));
                list.add(getOne("10000014", getVc(92, 360), null));
                list.add(getOne("10000015", getVc(222, 139), null));
                list.add(getOne("10000016", getVc(57, 167), null));
                list.add(getOne("10000017", getVc(200, 400), null));
                list.add(getOne("10000020", getVc(102, 289), null));
                list.add(getOne("10000021", getVc(262, 246), null));
                list.add(getOne("10000022", getVc(150, 107), null));
                list.add(getOne("10000023", getVc(200, 200), null));
                list.add(getOne("10000024", getVc(156, 174), null));
                list.add(getOne("10000044", getVc(120, 460), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_94", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_93", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_91", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_92", getVc(120, 383), null));

                break;
            }
            case "m_91": {
                list.add(getOne("10000120", getVc(80, 356), null));
                list.add(getOne("10000025", getVc(109, 121), null));
                list.add(getOne("10000027", getVc(290, 165), null));
                list.add(getOne("10000028", getVc(102, 300), null));
                list.add(getOne("10000030", getVc(43, 120), null));
                list.add(getOne("10000031", getVc(171, 235), null));
                list.add(getOne("10000032", getVc(181, 127), null));
                list.add(getOne("10000033", getVc(136, 351), null));
                list.add(getOne("10000034", getVc(91, 218), null));
                list.add(getOne("10000035", getVc(170, 300), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_94", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_90", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_91", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_93", getVc(120, 383), null));

                break;
            }
            case "m_92": {
                list.add(getOne("10000401", getVc(299, 358), null));
                list.add(getOne("10000402", getVc(221, 358), null));
                list.add(getOne("10000403", getVc(90, 237), null));
                list.add(getOne("10000036", getVc(100, 128), null));
                list.add(getOne("10000037", getVc(60, 334), null));
                list.add(getOne("10000038", getVc(143, 394), null));
                list.add(getOne("10000039", getVc(262, 207), null));
                list.add(getOne("10000040", getVc(258, 280), null));
                list.add(getOne("10000043", getVc(168, 123), null));
                list.add(getOne("10000044", getVc(150, 314), null));
                list.add(getOne("10000045", getVc(150, 194), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_90", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_95", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_93", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_93", getVc(120, 383), null));

                break;
            }
            case "m_93": {
                list.add(getOne("10000404", getVc(73, 106), null));
                list.add(getOne("10000047", getVc(193, 186), null));
                list.add(getOne("10000048", getVc(200, 100), null));
                list.add(getOne("10000049", getVc(180, 395), null));
                list.add(getOne("10000050", getVc(65, 342), null));
                list.add(getOne("10000051", getVc(61, 270), null));
                list.add(getOne("10000055", getVc(117, 401), null));
                list.add(getOne("10000056", getVc(242, 250), null));
                list.add(getOne("10000057", getVc(97, 161), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_91", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_92", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_89", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_88", getVc(120, 383), null));

                break;
            }
            case "m_94": {
                list.add(getOne("10000405", getVc(150, 300), null));
                list.add(getOne("10000406", getVc(84, 303), null));
                list.add(getOne("10000407", getVc(273, 125), null));
                list.add(getOne("10000408", getVc(102, 123), null));
                list.add(getOne("10000409", getVc(60, 212), null));
                list.add(getOne("10000410", getVc(306, 279), null));
                list.add(getOne("10000411", getVc(294, 364), null));
                list.add(getOne("10000412", getVc(191, 206), null));
                list.add(getOne("10000413", getVc(191, 123), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_91", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_92", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_89", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_90", getVc(120, 383), null));

                break;
            }
            case "m_95": {
                list.add(getOne("10000414", getVc(305, 114), null));
                list.add(getOne("10000415", getVc(160, 151), null));
                list.add(getOne("10000416", getVc(80, 268), null));
                list.add(getOne("10000417", getVc(90, 378), null));
                list.add(getOne("10000418", getVc(254, 342), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_91", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_96", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_92", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_90", getVc(120, 383), null));

                break;
            }
            case "m_96": {
                list.add(getOne("10000419", getVc(198, 238), null));
                list.add(getOne("10000420", getVc(307, 127), null));
                list.add(getOne("10000421", getVc(164, 143), null));
                list.add(getOne("10000422", getVc(86, 236), null));
                list.add(getOne("10000423", getVc(65, 354), null));
                list.add(getOne("10000424", getVc(306, 294), null));
                list.add(getOne("10000425", getVc(296, 373), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_98", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_100", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_95", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_97", getVc(120, 383), null));

                break;
            }
            case "m_97": {
                list.add(getOne("10000426", getVc(75, 228), null));
                list.add(getOne("10000427", getVc(114, 400), null));
                list.add(getOne("10000428", getVc(307, 230), null));
                list.add(getOne("10000429", getVc(302, 331), null));
                list.add(getOne("10000430", getVc(233, 404), null));
                list.add(getOne("10000431", getVc(147, 319), null));
                list.add(getOne("10000432", getVc(116, 143), null));
                list.add(getOne("10000433", getVc(194, 215), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_96", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_100", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_95", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_97", getVc(120, 383), null));

                break;
            }
            case "m_98": {
                list.add(getOne("10000434", getVc(95, 263), null));
                list.add(getOne("10000435", getVc(247, 168), null));
                list.add(getOne("10000436", getVc(159, 113), null));
                list.add(getOne("10000437", getVc(44, 386), null));
                list.add(getOne("10000438", getVc(310, 348), null));
                list.add(getOne("10000439", getVc(179, 296), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_96", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_99", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_95", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_96", getVc(120, 383), null));

                break;
            }
            case "m_99": {
                list.add(getOne("10000440", getVc(279, 208), null));
                list.add(getOne("10000441", getVc(285, 141), null));
                list.add(getOne("10000442", getVc(119, 127), null));
                list.add(getOne("10000443", getVc(152, 217), null));
                list.add(getOne("10000444", getVc(54, 271), null));
                list.add(getOne("10000445", getVc(305, 384), null));
                list.add(getOne("10000446", getVc(188, 358), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_96", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_99", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_98", getVc(330, 260), null));
                list.add(getOne("MapTransmit=m_100", getVc(120, 383), null));

                break;
            }
            case "m_100": {
                list.add(getOne("10000447", getVc(165, 209), null));
                list.add(getOne("10000448", getVc(295, 179), null));
                list.add(getOne("10000449", getVc(233, 121), null));
                list.add(getOne("10000450", getVc(77, 293), null));
                list.add(getOne("10000451", getVc(172, 369), null));
                list.add(getOne("10000452", getVc(289, 346), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=m_99", getVc(120, 30), null));
                list.add(getOne("MapTransmit=m_101", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_96", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_100", getVc(120, 383), null));

                break;
            }
            case "m_101": {
                list.add(getOne("10000453", getVc(133, 284), null));
                list.add(getOne("10000454", getVc(250, 250), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=m_99", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=m_101", getVc(20, 140), null));
                list.add(getOne("MapTransmit=m_100", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=m_100", getVc(120, 383), null));

                break;
            }
            case "txzf": {
                list.add(getOne("10000455", getVc(100, 350), null));
                list.add(getOne("10000456", getVc(204, 297), null));
                list.add(getOne("10000457", getVc(146, 142), null));
                list.add(getOne("10000458", getVc(63, 176), null));
                list.add(getOne("10000459", getVc(247, 176), null));
                list.add(getOne("10000460", getVc(192, 381), null));
                list.add(getOne("10000461", getVc(100, 220), null));
                list.add(getOne("10000462", getVc(200, 220), null));
                list.add(getOne("10000601", getVc(50, 370), null));
                break;
            }
            case "txzl": {
                list.add(getOne("10000455", getVc(50, 350), null));
                list.add(getOne("10000456", getVc(204, 297), null));
                list.add(getOne("10000463", getVc(146, 102), null));
                list.add(getOne("10000464", getVc(63, 176), null));
                list.add(getOne("10000465", getVc(247, 176), null));
                list.add(getOne("10000466", getVc(192, 381), null));
                list.add(getOne("10000467", getVc(100, 220), null));
                list.add(getOne("10000468", getVc(200, 220), null));
                list.add(getOne("10000601", getVc(100, 320), null));
                break;
            }
            case "txzg": {
                list.add(getOne("10000455", getVc(100, 350), null));
                list.add(getOne("10000456", getVc(204, 297), null));
                list.add(getOne("10000469", getVc(146, 102), null));
                list.add(getOne("10000470", getVc(63, 176), null));
                list.add(getOne("10000471", getVc(247, 176), null));
                list.add(getOne("10000472", getVc(192, 381), null));
                list.add(getOne("10000473", getVc(100, 220), null));
                list.add(getOne("10000474", getVc(200, 220), null));
                list.add(getOne("10000601", getVc(50, 370), null));
                break;
            }
            case "lyzd": {//炼狱之地
                list.add(getOne("10000475", getVc(165, 165), null));
                list.add(getOne("10000476", getVc(115, 215), null));
                break;
            }
            case "xlzd": {//修罗之地
                list.add(getOne("10000477", getVc(165, 165), null));
                list.add(getOne("10000478", getVc(115, 215), null));
                break;
            }
            case "hdzd": {//混沌之地
                list.add(getOne("10000479", getVc(165, 165), null));
                list.add(getOne("10000480", getVc(115, 215), null));
                break;
            }
            case "kgmsd": {//狂攻魔神殿
                list.add(getOne("10000485", getVc(115, 215), null));
                list.add(getOne("10000492", getVc(165, 165), null));
                list.add(getOne("10000499", getVc(215, 215), null));
                break;
            }
            case "tbmsd": {//铁壁魔神殿
                list.add(getOne("10000486", getVc(115, 215), null));
                list.add(getOne("10000493", getVc(165, 165), null));
                list.add(getOne("10000499", getVc(215, 215), null));
                break;
            }
            case "smmsd": {//生命魔神殿
                list.add(getOne("10000487", getVc(115, 215), null));
                list.add(getOne("10000494", getVc(165, 165), null));
                list.add(getOne("10000499", getVc(215, 215), null));
                break;
            }
            case "ssmsd": {//神速魔神殿
                list.add(getOne("10000488", getVc(115, 215), null));
                list.add(getOne("10000495", getVc(165, 165), null));
                list.add(getOne("10000499", getVc(215, 215), null));
                break;
            }
            case "sheshoumsd": {//射手魔神殿
                list.add(getOne("10000489", getVc(115, 215), null));
                list.add(getOne("10000496", getVc(165, 165), null));
                list.add(getOne("10000499", getVc(215, 215), null));
                break;
            }
            case "fsmsd": {//法术魔神殿
                list.add(getOne("10000490", getVc(115, 215), null));
                list.add(getOne("10000497", getVc(165, 165), null));
                list.add(getOne("10000499", getVc(215, 215), null));
                break;
            }
            case "bnmsd": {//暴怒魔神殿
                list.add(getOne("10000491", getVc(115, 215), null));
                list.add(getOne("10000498", getVc(165, 165), null));
                list.add(getOne("10000499", getVc(215, 215), null));
                break;
            }
            case "fb50_1": {
                list.add(getOne("10000500", getVc(115, 315), null));
                addMonster("10000501", 6, list);
                list.add(getOne("MapTransmit=fb50_2", getVc(120, 50), null));
                break;
            }
            case "fb50_2": {
                list.add(getOne("10000502", getVc(85, 335), null));
                addMonster("10000501", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb50_2", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fb50_3", getVc(20, 300), null));
                //list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb50_1", getVc(140, 383), null));
                break;
            }
            case "fb50_3": {
                addMonster("10000503", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb50_4", getVc(260, 50), null));
                //list.add(getOne("MapTransmit=fb50_3", getVc(20, 140), null));
                list.add(getOne("MapTransmit=fb50_2", getVc(480, 580), null));
                //list.add(getOne("MapTransmit=fb50_1", getVc(120, 383), null));
                break;
            }
            case "fb50_4": {
                list.add(getOne("10000505", getVc(215, 315), null));
                addMonster("10000504", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb50_2", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fb50_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb50_3", getVc(170, 383), null));
                break;
            }
            case "fb60_1": {
                addMonster("10000506", 6, list);
                list.add(getOne("MapTransmit=fb60_2", getVc(230, 50), null));
                break;
            }
            case "fb60_2": {
                list.add(getOne("10000508", getVc(450, 300), null));
                addMonster("10000507", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb50_2", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fb60_3", getVc(20, 250), null));
                //list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb60_1", getVc(290, 600), null));
                break;
            }
            case "fb60_3": {
                addMonster("10000509", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb60_4", getVc(270, 50), null));
                //list.add(getOne("MapTransmit=fb60_4", getVc(20, 140), null));
                list.add(getOne("MapTransmit=fb60_2", getVc(330, 220), null));
                //list.add(getOne("MapTransmit=fb60_2", getVc(120, 383), null));
                break;
            }
            case "fb60_4": {
                list.add(getOne("10000511", getVc(330, 130), null));
                addMonster("10000510", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb50_2", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fb50_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb60_3", getVc(350, 600), null));
                break;
            }
            case "fb70_1": {
                list.add(getOne("10000513", getVc(250, 115), null));
                addMonster("10000512", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb50_2", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fb50_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb70_2", getVc(170, 383), null));
                break;
            }
            case "fb70_2": {
                list.add(getOne("10000514", getVc(165, 150), null));
                addMonster("10000512", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb70_1", getVc(140, 50), null));
                //list.add(getOne("MapTransmit=fb50_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb70_3", getVc(110, 383), null));
                break;
            }
            case "fb70_3": {
                list.add(getOne("10000516", getVc(215, 355), null));
                addMonster("10000515", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb70_2", getVc(120, 50), null));
                //list.add(getOne("MapTransmit=fb50_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb70_4", getVc(150, 383), null));
                break;
            }
            case "fb70_4": {
                list.add(getOne("10000517", getVc(115, 315), null));
                addMonster("10000515", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb70_3", getVc(150, 50), null));
                //list.add(getOne("MapTransmit=fb50_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=m_83", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fb70_4", getVc(120, 383), null));
                break;
            }
            case "fb80_1": {
                addMonster("10000518", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb70_3", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fb80_2", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fb80_2", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fb70_4", getVc(120, 383), null));
                break;
            }
            case "fb80_2": {
                addMonster("10000519", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb70_3", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fb80_3", getVc(20, 240), null));
                list.add(getOne("MapTransmit=fb80_1", getVc(330, 200), null));
                //list.add(getOne("MapTransmit=fb70_4", getVc(120, 383), null));
                break;
            }
            case "fb80_3": {
                list.add(getOne("10000521", getVc(200, 365), null));
                addMonster("10000520", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb70_3", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fb80_4", getVc(20, 240), null));
                list.add(getOne("MapTransmit=fb80_2", getVc(330, 240), null));
                //list.add(getOne("MapTransmit=fb70_4", getVc(120, 383), null));
                break;
            }
            case "fb80_4": {
                list.add(getOne("10000522", getVc(85, 305), null));
                addMonster("10000520", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb70_3", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fb80_2", getVc(20, 140), null));
                list.add(getOne("MapTransmit=fb80_3", getVc(330, 180), null));
                //list.add(getOne("MapTransmit=fb70_4", getVc(120, 383), null));
                break;
            }
            case "fb90_1": {
                addMonster("10000523", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb70_3", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fb90_2", getVc(20, 220), null));
                //list.add(getOne("MapTransmit=fb80_3", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fb70_4", getVc(120, 383), null));
                break;
            }
            case "fb90_2": {
                list.add(getOne("10000525", getVc(115, 335), null));
                addMonster("10000524", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb70_3", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fb90_3", getVc(20, 355), null));
                list.add(getOne("MapTransmit=fb90_1", getVc(500, 340), null));
                //list.add(getOne("MapTransmit=fb70_4", getVc(120, 383), null));
                break;
            }
            case "fb90_3": {
                addMonster("10000526", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb70_3", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fb90_3", getVc(20, 140), null));
                list.add(getOne("MapTransmit=fb90_2", getVc(330, 220), null));
                list.add(getOne("MapTransmit=fb90_4", getVc(120, 383), null));
                break;
            }
            case "fb90_4": {
                list.add(getOne("10000528", getVc(215, 335), null));
                addMonster("10000527", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb90_3", getVc(160, 50), null));
                //list.add(getOne("MapTransmit=fb90_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fb90_2", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fb90_4", getVc(120, 383), null));
                break;
            }
            case "fb100_1": {
                addMonster("10000529", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb90_3", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fb90_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fb90_2", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb100_2", getVc(50, 383), null));
                break;
            }
            case "fb100_2": {
                list.add(getOne("10000530", getVc(265, 475), null));
                addMonster("10000529", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb100_1", getVc(180, 50), null));
                //list.add(getOne("MapTransmit=fb90_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fb90_2", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb100_3", getVc(80, 583), null));
                break;
            }
            case "fb100_3": {
                addMonster("10000531", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb100_2", getVc(70, 50), null));
                //list.add(getOne("MapTransmit=fb90_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fb90_2", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb100_4", getVc(140, 383), null));
                break;
            }
            case "fb100_4": {
                list.add(getOne("10000532", getVc(215, 365), null));
                addMonster("10000531", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb100_3", getVc(230, 50), null));
                //list.add(getOne("MapTransmit=fb90_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fb90_2", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fb100_4", getVc(120, 383), null));
                break;
            }
            case "fbls_1": {
                list.add(getOne("10000533", getVc(115, 315), null));
                list.add(getOne("10000534", getVc(195, 315), null));
                addMonster("10000535", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbls_2", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fbls_2", getVc(20, 320), null));
                list.add(getOne("MapTransmit=fbls_3", getVc(330, 170), null));
                //list.add(getOne("MapTransmit=fb100_4", getVc(120, 383), null));
                break;
            }
            case "fbls_2": {
                list.add(getOne("10000536", getVc(250, 260), null));
                addMonster("10000535", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbls_2", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fbls_2", getVc(20, 140), null));
                list.add(getOne("MapTransmit=fbls_1", getVc(330, 320), null));
                //list.add(getOne("MapTransmit=fb100_4", getVc(120, 383), null));
                break;
            }
            case "fbls_3": {
                list.add(getOne("10000537", getVc(115, 315), null));
                list.add(getOne("10000538", getVc(215, 115), null));
                addMonster("10000539", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbls_2", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fbls_1", getVc(20, 200), null));
                list.add(getOne("MapTransmit=fbls_4", getVc(330, 370), null));
                //list.add(getOne("MapTransmit=fb100_4", getVc(120, 383), null));
                break;
            }
            case "fbls_4": {
                list.add(getOne("10000540", getVc(225, 125), null));
                addMonster("10000539", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbls_2", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fbls_3", getVc(20, 350), null));
                //list.add(getOne("MapTransmit=fbls_4", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fb100_4", getVc(120, 383), null));
                break;
            }
            case "fbhh_1": {
                list.add(getOne("10000541", getVc(135, 315), null));
                addMonster("10000542", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fbhh_2", getVc(150, 50), null));
                //list.add(getOne("MapTransmit=fbls_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fbls_4", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fb100_4", getVc(120, 383), null));
                break;
            }
            case "fbhh_2": {
                list.add(getOne("10000543", getVc(250, 290), null));
                addMonster("10000542", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbhh_3", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fbls_3", getVc(20, 140), null));
                list.add(getOne("MapTransmit=fbhh_3", getVc(330, 180), null));
                list.add(getOne("MapTransmit=fbhh_1", getVc(130, 383), null));
                break;
            }
            case "fbhh_3": {
                list.add(getOne("10000544", getVc(215, 185), null));
                addMonster("10000545", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fbhh_4", getVc(220, 50), null));
                list.add(getOne("MapTransmit=fbhh_2", getVc(20, 220), null));
                //list.add(getOne("MapTransmit=fbls_4", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fbhh_1", getVc(120, 383), null));
                break;
            }
            case "fbhh_4": {
                list.add(getOne("10000546", getVc(115, 315), null));
                list.add(getOne("10000547", getVc(115, 115), null));
                addMonster("10000545", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbhh_4", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fbhh_2", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fbls_4", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fbhh_3", getVc(200, 383), null));
                break;
            }
            case "fbys_1": {
                list.add(getOne("10000548", getVc(165, 255), null));
                addMonster("10000549", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fbys_2", getVc(270, 50), null));
                //list.add(getOne("MapTransmit=fbhh_2", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fbls_4", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fbhh_3", getVc(120, 383), null));
                break;
            }
            case "fbys_2": {
                addMonster("10000549", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbys_2", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fbys_3", getVc(20, 220), null));
                //list.add(getOne("MapTransmit=fbls_4", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fbys_1", getVc(210, 383), null));
                break;
            }
            case "fbys_3": {
                list.add(getOne("10000550", getVc(115, 140), null));
                addMonster("10000551", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbys_2", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fbys_4", getVc(20, 140), null));
                list.add(getOne("MapTransmit=fbys_2", getVc(330, 140), null));
                //list.add(getOne("MapTransmit=fbys_2", getVc(120, 383), null));
                break;
            }
            case "fbys_4": {
                list.add(getOne("10000552", getVc(115, 200), null));
                addMonster("10000551", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbys_2", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fbys_4", getVc(20, 140), null));
                list.add(getOne("MapTransmit=fbys_3", getVc(330, 200), null));
                //list.add(getOne("MapTransmit=fbys_2", getVc(120, 383), null));
                break;
            }
            case "fbzx_1": {
                list.add(getOne("10000554", getVc(230, 165), null));
                addMonster("10000553", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fbzx_2", getVc(220, 50), null));
                //list.add(getOne("MapTransmit=fbys_4", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fbys_3", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fbys_2", getVc(120, 383), null));
                break;
            }
            case "fbzx_2": {
                list.add(getOne("10000555", getVc(170, 290), null));
                //addMonster("10000553", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbzx_2", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fbzx_3", getVc(20, 240), null));
                list.add(getOne("MapTransmit=fbzx_4", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fbzx_1", getVc(170, 383), null));
                break;
            }
            case "fbzx_3": {
                list.add(getOne("10000556", getVc(115, 200), null));
                addMonster("10000557", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbzx_2", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fbzx_3", getVc(20, 140), null));
                list.add(getOne("MapTransmit=fbzx_2", getVc(330, 200), null));
                //list.add(getOne("MapTransmit=fbzx_1", getVc(120, 383), null));
                break;
            }
            case "fbzx_4": {
                list.add(getOne("10000558", getVc(115, 200), null));
                addMonster("10000557", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fbzx_2", getVc(120, 30), null));
                list.add(getOne("MapTransmit=fbzx_2", getVc(20, 200), null));
                //list.add(getOne("MapTransmit=fbzx_2", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fbzx_1", getVc(120, 383), null));
                break;
            }
            case "fb_yzj_1": {
                list.add(getOne("10000559", getVc(145, 315), null));
                addMonster("10000560", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb_yzj_2", getVc(170, 50), null));
                //list.add(getOne("MapTransmit=fbzx_2", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fbzx_2", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=fbzx_1", getVc(120, 383), null));
                break;
            }
            case "fb_yzj_2": {
                list.add(getOne("10000561", getVc(215, 255), null));
                addMonster("10000562", 6, list);
                //上、左、右、下
                list.add(getOne("MapTransmit=fb_yzj_3", getVc(220, 50), null));
                //list.add(getOne("MapTransmit=fbzx_2", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fbzx_2", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb_yzj_1", getVc(140, 383), null));
                break;
            }
            case "fb_yzj_3": {
                list.add(getOne("10000563", getVc(190, 260), null));
                addMonster("10000564", 6, list);
                //上、左、右、下
                //list.add(getOne("MapTransmit=fb_yzj_3", getVc(120, 30), null));
                //list.add(getOne("MapTransmit=fbzx_2", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=fbzx_2", getVc(330, 260), null));
                list.add(getOne("MapTransmit=fb_yzj_2", getVc(200, 383), null));
                break;
            }
            case "cbd": {
                list.add(getOne("10000566", getVc(170, 100), null));
                list.add(getOne("10000567", getVc(170, 350), null));
                list.add(getOne("10000034", getVc(50, 360), null));
                list.add(getOne("10000020", getVc(300, 360), null));
                list.add(getOne("10000024", getVc(280, 400), null));
                break;
            }
            case "hunyin": {
                list.add(getOne("10000568", getVc(180, 150), null));
                list.add(getOne("10000569", getVc(90, 180), null));
                list.add(getOne("10000570", getVc(50, 260), null));
                list.add(getOne("10000571", getVc(300, 260), null));
                break;
            }
            case "cwly": {
                list.add(getOne("10000572", getVc(150, 350), null));
                list.add(getOne("10000573", getVc(250, 260), null));
                list.add(getOne("10000574", getVc(300, 200), null));
                list.add(getOne("10000575", getVc(250, 140), null));
                list.add(getOne("10000576", getVc(100, 260), null));
                list.add(getOne("10000577", getVc(50, 200), null));
                list.add(getOne("10000578", getVc(100, 140), null));
                list.add(getOne("10000579", getVc(230, 400), null));
                list.add(getOne("10000034", getVc(50, 300), null));
                list.add(getOne("10000020", getVc(330, 360), null));
                list.add(getOne("10000024", getVc(320, 420), null));
                break;
            }
            case "kongmiao1": {
                list.add(getOne("10000586", getVc(180, 150), null));
                break;
            }
            case "kongmiao2": {
                list.add(getOne("10000587", getVc(180, 150), null));
                break;
            }
            case "kongmiao3": {
                list.add(getOne("10000588", getVc(180, 150), null));
                break;
            }
            case "kongmiao4": {
                list.add(getOne("10000589", getVc(180, 150), null));
                break;
            }
            case "kongmiao5": {
                list.add(getOne("10000590", getVc(180, 150), null));
                break;
            }
            case "kongmiao6": {
                list.add(getOne("10000591", getVc(180, 150), null));
                break;
            }
            case "gangs1": {
                list.add(getOne("10000592", getVc(100, 300), null));
                list.add(getOne("10000593", getVc(50, 400), null));
                list.add(getOne("10000594", getVc(180, 400), null));
                list.add(getOne("10000595", getVc(300, 320), null));
                list.add(getOne("10000596", getVc(280, 250), null));
                list.add(getOne("10000597", getVc(180, 100), null));
                list.add(getOne("10000598", getVc(50, 130), null));
                list.add(getOne("10000599", getVc(180, 300), null));
                break;
            }
            case "gangs2": {
                list.add(getOne("10000592", getVc(100, 300), null));
                list.add(getOne("10000593", getVc(50, 400), null));
                list.add(getOne("10000594", getVc(180, 400), null));
                list.add(getOne("10000595", getVc(150, 150), null));
                list.add(getOne("10000596", getVc(280, 250), null));
                list.add(getOne("10000597", getVc(180, 100), null));
                list.add(getOne("10000598", getVc(50, 130), null));
                list.add(getOne("10000599", getVc(180, 300), null));
                break;
            }
            case "gangs3": {
                list.add(getOne("10000592", getVc(100, 300), null));
                list.add(getOne("10000593", getVc(50, 400), null));
                list.add(getOne("10000594", getVc(180, 400), null));
                list.add(getOne("10000595", getVc(300, 150), null));
                list.add(getOne("10000596", getVc(280, 230), null));
                list.add(getOne("10000597", getVc(180, 100), null));
                list.add(getOne("10000598", getVc(50, 200), null));
                list.add(getOne("10000599", getVc(180, 300), null));
                break;
            }
            case "gangs4": {
                list.add(getOne("10000592", getVc(100, 300), null));
                list.add(getOne("10000593", getVc(50, 250), null));
                list.add(getOne("10000594", getVc(180, 400), null));
                list.add(getOne("10000595", getVc(300, 320), null));
                list.add(getOne("10000596", getVc(280, 250), null));
                list.add(getOne("10000597", getVc(180, 100), null));
                list.add(getOne("10000598", getVc(50, 130), null));
                list.add(getOne("10000599", getVc(180, 300), null));
                break;
            }
            case "gangs5": {
                list.add(getOne("10000592", getVc(100, 300), null));
                list.add(getOne("10000593", getVc(50, 400), null));
                list.add(getOne("10000594", getVc(180, 400), null));
                list.add(getOne("10000595", getVc(300, 320), null));
                list.add(getOne("10000596", getVc(280, 250), null));
                list.add(getOne("10000597", getVc(180, 100), null));
                list.add(getOne("10000598", getVc(50, 130), null));
                list.add(getOne("10000599", getVc(180, 300), null));
                break;
            }
            case "gangs6": {
                list.add(getOne("10000592", getVc(100, 250), null));
                list.add(getOne("10000593", getVc(50, 240), null));
                list.add(getOne("10000594", getVc(180, 400), null));
                list.add(getOne("10000595", getVc(150, 150), null));
                list.add(getOne("10000596", getVc(230, 170), null));
                list.add(getOne("10000597", getVc(180, 220), null));
                list.add(getOne("10000598", getVc(100, 180), null));
                list.add(getOne("10000599", getVc(150, 320), null));
                break;
            }
            case "wzy": {
                list.add(getOne("10000032", getVc(100, 350), null));
                break;
            }
            case "hhbk_1": {
                list.add(getOne("10000602", getVc(380, 450), null));
                list.add(getOne("10000603", getVc(180, 90), null));
                list.add(getOne("10000603", getVc(50, 200), null));
                list.add(getOne("10000603", getVc(200, 350), null));
                list.add(getOne("10000603", getVc(450, 80), null));
                list.add(getOne("10000603", getVc(350, 200), null));
                list.add(getOne("10000603", getVc(230, 300), null));
                list.add(getOne("10000603", getVc(150, 280), null));
                list.add(getOne("10000603", getVc(250, 230), null));
                list.add(getOne("10000603", getVc(330, 320), null));
                list.add(getOne("10000603", getVc(400, 400), null));
                addMonster("10000612", 10, list);
                break;
            }
            case "hhbk_2": {
                list.add(getOne("10000604", getVc(100, 350), null));
                for (int i = 0; i < 10; i++) {
                    list.add(getOne("10000605", getVc(30 + i * 30, 250), null));
                }
                break;
            }
            case "hhbk_2_1": {
                list.add(getOne("10000606", getVc(100, 350), null));
                addMonster("10000607", 10, list);
                break;
            }
            case "hhbk_2_2": {
                list.add(getOne("10000608", getVc(100, 350), null));
                for (int i = 0; i < 10; i++) {
                    list.add(getOne("10000609", getVc(30 + i * 30, 250), null));
                }
                break;
            }
            case "hhbk_3": {
                list.add(getOne("10000610", getVc(220, 130), null));
                break;
            }
            case "yzj_1": {//天元
                //上、左、右、下
                list.add(getOne("MapTransmit=yzj_4", getVc(170, 50), null));
                list.add(getOne("MapTransmit=yzj_6", getVc(20, 140), null));
                list.add(getOne("MapTransmit=yzj_8", getVc(330, 260), null));
                list.add(getOne("MapTransmit=yzj_2", getVc(120, 383), null));
                break;
            }
            case "yzj_2": {//南离城郊
                //上、左、右、下
                list.add(getOne("MapTransmit=yzj_1", getVc(170, 50), null));
                list.add(getOne("MapTransmit=yzj_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=yzj_8", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=yzj_2", getVc(120, 383), null));
                break;
            }
            case "yzj_3": {//南离城
                list.add(getOne("10000614", getVc(120, 180), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=yzj_2", getVc(170, 50), null));
                //list.add(getOne("MapTransmit=yzj_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=yzj_8", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=yzj_2", getVc(120, 383), null));
                break;
            }
            case "yzj_4": {//北冥城郊
                //list.add(getOne("10000614", getVc(220, 130), null));
                //上、左、右、下
                list.add(getOne("MapTransmit=yzj_5", getVc(170, 50), null));
                //list.add(getOne("MapTransmit=yzj_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=yzj_8", getVc(330, 260), null));
                list.add(getOne("MapTransmit=yzj_1", getVc(120, 383), null));
                break;
            }
            case "yzj_5": {//北冥城
                list.add(getOne("10000616", getVc(180, 130), null));
                list.add(getOne("10000615", getVc(120, 230), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=yzj_5", getVc(170, 50), null));
                //list.add(getOne("MapTransmit=yzj_3", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=yzj_8", getVc(330, 260), null));
                list.add(getOne("MapTransmit=yzj_4", getVc(120, 383), null));
                break;
            }
            case "yzj_6": {//西沙城郊
                //list.add(getOne("10000615", getVc(320, 330), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=yzj_5", getVc(170, 50), null));
                list.add(getOne("MapTransmit=yzj_7", getVc(20, 140), null));
                list.add(getOne("MapTransmit=yzj_1", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=yzj_4", getVc(120, 383), null));
                break;
            }
            case "yzj_7": {//西沙城
                list.add(getOne("10000617", getVc(120, 130), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=yzj_5", getVc(170, 50), null));
                //list.add(getOne("MapTransmit=yzj_7", getVc(20, 140), null));
                list.add(getOne("MapTransmit=yzj_6", getVc(280, 260), null));
                //list.add(getOne("MapTransmit=yzj_4", getVc(120, 383), null));
                break;
            }
            case "yzj_8": {//东云城郊
                //list.add(getOne("10000617", getVc(320, 330), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=yzj_5", getVc(170, 50), null));
                list.add(getOne("MapTransmit=yzj_1", getVc(20, 140), null));
                list.add(getOne("MapTransmit=yzj_9", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=yzj_4", getVc(120, 383), null));
                break;
            }
            case "yzj_9": {//东云城
                list.add(getOne("10000618", getVc(120, 130), null));
                //上、左、右、下
                //list.add(getOne("MapTransmit=yzj_5", getVc(170, 50), null));
                list.add(getOne("MapTransmit=yzj_8", getVc(20, 140), null));
                //list.add(getOne("MapTransmit=yzj_9", getVc(330, 260), null));
                //list.add(getOne("MapTransmit=yzj_4", getVc(120, 383), null));
                break;
            }
            case "bz": {//帮战
                list.add(getOne("10000619", getVc(120, 130), null));
                break;
            }
            case "prison": {//监狱
                list.add(getOne("10000620", getVc(120, 130), null));
                break;
            }
            case "xxzd": {//血腥之地
                list.add(getOne("10000621", getVc(200, 130), null));
                break;
            }


            default: {
                if (mapKey.contains("abyss")) {
                    int num = Integer.parseInt(mapKey.replace("abyss", ""));
                    list.add(getOne("10000481", getVc(90, 233), null));
                    if (num == 1 || num == 5 || num == 10 || num == 15 || num == 20 || num == 25 || num == 30 || num == 35 || num == 40) {
                        list.add(getOne("10000482", getVc(190, 133), null));
                    }
                    addMonster("abyss_" + num, 6, list);
                    if (num == 1) {
                        list.add(getOne("AbyssTransmit_" + (num + 1), getVc(190, 383), null));
                    } else if (num > 1 && num < 40) {
                        list.add(getOne("AbyssTransmit_" + (num - 1), getVc(190, 50), null));
                        list.add(getOne("AbyssTransmit_" + (num + 1), getVc(190, 383), null));
                    } else {
                        list.add(getOne("AbyssTransmit_" + (num - 1), getVc(190, 50), null));
                    }
                } else if (mapKey.contains("qlhd")) {
                    int num = Integer.parseInt(mapKey.replace("qlhd", ""));
                    addMonster("qlhd_" + num, 6, list);
                } else if (mapKey.contains("blxt")) {//百炼玄塔
                    //在mapService中处理
                } else if (mapKey.contains("dmkj")) {//盗梦空间
                    list.add(getOne("10000613", getVc(220, 350), null));

                    String[] arr = mapKey.substring(4).split("_");
                    String str = "dmkj" + (Integer.parseInt(arr[0]) + 1);
                    String str1 = "dmkj" + (Integer.parseInt(arr[0]) - 1);
                    if (arr.length > 1 && !arr[1].equals("")) {
                        str += "_" + arr[1];
                        str1 += "_" + arr[1];
                    }
                    if (!mapKey.contains("dmkj7"))//不是最后一张图就有上方
                        list.add(getOne("MapTransmit=" + str, getVc(220, 50), null));
                    if (!mapKey.contains("dmkj1"))//不是第一张图就有下方
                        list.add(getOne("MapTransmit=" + str1, getVc(120, 383), null));
                    if (mapKey.contains("_1")) {//右图就有左方
                        list.add(getOne("MapTransmit=dmkj" + arr[0], getVc(330, 260), null));
                    } else {//左图就有右方
                        list.add(getOne("MapTransmit=dmkj" + arr[0] + "_1", getVc(20, 140), null));
                    }

                }
                break;
            }
        }
        return list;
    }

    public static JSONObject getOne(String npcKey, vector3 pos, vector3 scale) {
        JSONObject obj = new JSONObject();
        obj.put("key", npcKey);
        obj.put("pos", pos);
        if (scale == null) {
            scale = new vector3(1, 1, 1);
        }
        obj.put("scale", scale);
        return obj;
    }

    /**
     * 判断是否为主城
     */
    public static boolean isMainCity(String key) {
        String[] arr = {
                "m_3", "m_4", "m_5", "m_6",
                "m_18", "m_19", "m_20", "m_21",
                "m_33", "m_34", "m_35", "m_36",
                "m_43", "m_44", "m_45", "m_46",
                "m_63", "m_64", "m_65", "m_66",
        };
        for (int i = 0; i < arr.length; i++) {
            if (key.equals(arr[i])) return true;
        }
        return false;
    }

}

