package my.data;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import my.gameUtils.skillUtils;
import my.model.skill;
import my.utils.strUtils;

import java.util.Vector;

public class skillData {
    //回天书处理技能覆盖的缓存
    public static Vector<JSONObject> HuitianSkillCache = new Vector<>();

    /**
     * 获取由某个属性加持另一个属性
     */
    public static JSONObject getAtoBAttr(String key) {
        switch (key) {
            case "3097": {//神龙抗体
                return JSON.parseObject(JSON.toJSONString(
                        new aToBAttr("max_xue", "wf&ff", 0.2f)));
            }
            case "3124": {
                return JSON.parseObject(JSON.toJSONString(
                        new aToBAttr("fg", "sd", 0.25f)));
            }
            case "3125": {
                return JSON.parseObject(JSON.toJSONString(
                        new aToBAttr("fg", "max_xue", 2f)));
            }
            case "3132": {
                return JSON.parseObject(JSON.toJSONString(
                        new aToBAttr("wg", "max_xue", 1.5f)));
            }
            case "3141": {
                return JSON.parseObject(JSON.toJSONString(
                        new aToBAttr("fg", "max_xue", 1.5f)));
            }
            default:
                return null;
        }
    }

    /**
     * 获取技能叠加属性
     */
    public static JSONArray getAttrs(String key) {
        skill skl = skillUtils.getInstance().getSkill(key);
        return skl.getAttrs();
    }

    /**
     * 获取计算方式
     */
    public static int getCountWay(String key) {
        skill skl = skillUtils.getInstance().getSkill(key);
        if (skl == null) {
            System.err.println("getCountWay找不到技能：" + key);
        }
        return skl.countWay;
    }



    /**
     * 技能数据详情
     */
    public static JSONObject get(String key) {
        JSONObject res = new JSONObject();
        res.put("type", 0);//0门派1天2地3人4宠物专属5宠物普通
        res.put("job", "*");//职业
        JSONArray arr = new JSONArray();
        switch (key) {
            case "100210000001": {
                arr.add(getObj("ll", 16f, 0f));
                arr.add(getObj("nl", 16f, 0f));
                res.put("job", "ms/dj");
                res.put("maxLv", 20);
                break;
            }
            case "100210000002": {
                arr.add(getObj("wg", 3f, 0f));
                res.put("job", "ms");
                res.put("maxLv", 20);
                break;
            }
            case "100210000003": {
                arr.add(getObj("max_xue", 6f, 100f));
                res.put("job", "ms");
                res.put("maxLv", 20);
                break;
            }
            case "100210000004": {
                arr.add(getObj("ll", 36f, 0f));
                arr.add(getObj("nl", 12f, 0f));
                res.put("job", "ms");
                res.put("maxLv", 20);
                break;
            }
            case "100210000005": {
                arr.add(getObj("ff", 3f, 0f));
                res.put("job", "ms");
                res.put("maxLv", 20);
                break;
            }
            case "100210000006": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "ms");
                res.put("maxLv", 20);
                break;
            }
            case "100210000007": {
                arr.add(getObj("bj", 6f, 20f));
                res.put("job", "ms");
                res.put("maxLv", 20);
                break;
            }
            /*case "3007": {
                arr.add(getObj("wg", 3f, 0f));
                res.put("job", "ms");
                res.put("maxLv", 18);
                break;
            }*/
            case "100210000008": {
                arr.add(getObj("wg", 3f, 0f));
                res.put("job", "dj");
                res.put("maxLv", 20);
                break;
            }
            case "100210000009": {
                arr.add(getObj("max_xue", 6f, 100f));
                res.put("job", "dj");
                res.put("maxLv", 20);
                break;
            }
            case "100210000010": {
                arr.add(getObj("ll", 12f, 0f));
                arr.add(getObj("nl", 36f, 0f));
                res.put("job", "dj");
                res.put("maxLv", 20);
                break;
            }
            case "100210000011": {
                arr.add(getObj("wg", 3f, 0f));
                res.put("job", "dj");
                res.put("maxLv", 20);
                break;
            }
            case "100210000012": {
                arr.add(getObj("wg", 3f, 0f));
                res.put("job", "dj");
                res.put("maxLv", 20);
                break;
            }
            case "100210000013": {
                arr.add(getObj("wg", 3f, 0f));
                res.put("job", "dj");
                res.put("maxLv", 20);
                break;
            }
            /*case "3014": {
                arr.add(getObj("max_xue", 6f, 100f));
                res.put("job", "dj");
                res.put("maxLv", 2);
                break;
            }*/
            case "100210000014": {
                arr.add(getObj("zl", 16f, 0f));
                arr.add(getObj("js", 16f, 0f));
                res.put("job", "qm/ty");
                res.put("maxLv", 20);
                break;
            }
            case "100210000015": {
                arr.add(getObj("fg", 3f, 0f));
                res.put("job", "qm");
                res.put("maxLv", 20);
                break;
            }
            case "100210000016": {
                arr.add(getObj("max_xue", 6f, 100f));
                res.put("job", "qm");
                res.put("maxLv", 20);
                break;
            }
            case "100210000017": {
                arr.add(getObj("zl", 36f, 0f));
                arr.add(getObj("js", 12f, 0f));
                res.put("job", "qm");
                res.put("maxLv", 20);
                break;
            }
            case "100210000018": {
                arr.add(getObj("max_xue", 6f, 100f));
                res.put("job", "qm");
                res.put("maxLv", 20);
                break;
            }
            case "100210000019": {
                arr.add(getObj("fg", 3f, 0f));
                res.put("job", "qm");
                res.put("maxLv", 20);
                break;
            }
            case "100210000020": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "qm");
                res.put("maxLv", 20);
                break;
            }
            /*case "3022": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "qm");
                res.put("maxLv", 2);
                break;
            }*/
            case "100210000021": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "ty");
                res.put("maxLv", 20);
                break;
            }
            case "100210000022": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "ty");
                res.put("maxLv", 20);
                break;
            }
            case "100210000023": {
                arr.add(getObj("zl", 12f, 0f));
                arr.add(getObj("js", 36f, 0f));
                res.put("job", "ty");
                res.put("maxLv", 20);
                break;
            }
            case "100210000024": {
                arr.add(getObj("ff", 3f, 0f));
                res.put("job", "ty");
                res.put("maxLv", 20);
                break;
            }
            case "100210000025": {
                arr.add(getObj("ff", 3f, 0f));
                res.put("job", "ty");
                res.put("maxLv", 20);
                break;
            }
            /*case "3028": {
                arr.add(getObj("fg", 3f, 0f));
                res.put("job", "ty");
                res.put("maxLv", 10);
                break;
            }*/
            case "100210000026": {
                arr.add(getObj("fg", 3f, 0f));
                res.put("job", "ty");
                res.put("maxLv", 20);
                break;
            }
            case "100210000027": {
                arr.add(getObj("ll", 16f, 0f));
                arr.add(getObj("mj", 16f, 0f));
                res.put("job", "ym/lc");
                res.put("maxLv", 20);
                break;
            }
            case "100210000028": {
                arr.add(getObj("ll", 36f, 0f));
                arr.add(getObj("mj", 12f, 0f));
                res.put("job", "ym");
                res.put("maxLv", 20);
                break;
            }
            case "100210000029": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "ym");
                res.put("maxLv", 20);
                break;
            }
            case "100210000030": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "ym");
                res.put("maxLv", 20);
                break;
            }
            case "100210000031": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "ym");
                res.put("maxLv", 20);
                break;
            }
            case "100210000032": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "ym");
                res.put("maxLv", 20);
                break;
            }
            /*case "3036": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "ym");
                res.put("maxLv", 2);
                break;
            }*/
            case "100210000033": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "ym");
                res.put("maxLv", 20);
                break;
            }
            case "100210000034": {
                arr.add(getObj("ll", 12f, 0f));
                arr.add(getObj("mj", 36f, 0f));
                res.put("job", "lc");
                res.put("maxLv", 20);
                break;
            }
            case "100210000035": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "lc");
                res.put("maxLv", 20);
                break;
            }
            case "100210000036": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "lc");
                res.put("maxLv", 20);
                break;
            }
            /*case "3041": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "lc");
                res.put("maxLv", 2);
                break;
            }*/
            case "100210000037": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "lc");
                res.put("maxLv", 2);
                break;
            }
            case "100210000038": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "lc");
                res.put("maxLv", 20);
                break;
            }
            case "100210000039": {
                arr.add(getObj("wf", 3f, 0f));
                res.put("job", "lc");
                res.put("maxLv", 20);
                break;
            }


            case "3046": {//仙术回血
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3085": {//玄心破霄
                arr.add(getObj("wg", 0f, 0.3f, 1));
                arr.add(getObj("fg", 0f, 0.3f, 1));
                arr.add(getObj("mz", 0f, 0.3f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3086": {//踏雪无痕
                arr.add(getObj("sd", 0f, 0.3f, 1));
                arr.add(getObj("css", 0f, 0.3f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3087": {//疗血
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3088": {//天生强攻
                arr.add(getObj("wg", 0f, 0.2f, 1));
                arr.add(getObj("fg", 0f, 0.2f, 1));
                arr.add(getObj("max_xue", 0f, -0.15f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3089": {//坚壁援护
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3090": {//援护
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3096": {//不动如山
                arr.add(getObj("wf", 0f, 0.2f, 1));
                arr.add(getObj("ff", 0f, 0.2f, 1));
                arr.add(getObj("max_xue", 0f, 0.2f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3097": {//神龙抗体
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3098": {//仙术回灵
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3099": {//回灵
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3101": {//嗜血凶残
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3102": {//霸气反震
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3103": {//铜皮铁骨
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3104": {//天命不死
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3105": {//神佑之光
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3106": {//真魔吸血
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3107": {//强势反击
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3108": {//强势连击
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3109": {//摧山猛力
                arr.add(getObj("wg", 0f, 0.15f, 1));
                arr.add(getObj("fg", 0f, 0.15f, 1));
                arr.add(getObj("sd", 0f, -0.3f, 1));
                arr.add(getObj("wf", 0f, -0.35f, 1));
                arr.add(getObj("ff", 0f, -0.35f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3110": {//裂空锐爪
                arr.add(getObj("wg", 0f, 0.1f, 1));
                arr.add(getObj("fg", 0f, 0.1f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3111": {//锐爪
                arr.add(getObj("wg", 0f, 0.05f, 1));
                arr.add(getObj("fg", 0f, 0.05f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3112": {//猛力
                arr.add(getObj("wg", 0f, 0.10f, 1));
                arr.add(getObj("fg", 0f, 0.10f, 1));
                arr.add(getObj("sd", 0f, -0.15f, 1));
                arr.add(getObj("wf", 0f, -0.25f, 1));
                arr.add(getObj("ff", 0f, -0.25f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3113": {//如山
                arr.add(getObj("wf", 0f, 0.1f, 1));
                arr.add(getObj("ff", 0f, 0.1f, 1));
                arr.add(getObj("max_xue", 0f, 0.1f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3114": {//强攻
                arr.add(getObj("wg", 0f, 0.1f, 1));
                arr.add(getObj("fg", 0f, 0.1f, 1));
                arr.add(getObj("max_xue", 0f, -0.08f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3115": {//不死
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3116": {//铁骨
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3117": {//反震
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3118": {//凶残
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3119": {//吸血
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3120": {//反击
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3121": {//连击
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3127": {//金刚霸体
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3128": {//逆转阴阳
                arr.add(getObj("ll", 0f, 0f));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3142": {//祈天再生
                arr.add(getObj("max_xue", 0f, -0.35f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3143": {//再生
                arr.add(getObj("max_xue", 0f, -0.35f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3144": {//神行百步
                arr.add(getObj("css", 0f, 0.08f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3145": {//神行
                arr.add(getObj("css", 0f, 0.05f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3146": {//先天体质
                arr.add(getObj("max_xue", 0f, 0.1f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3147": {//体质
                arr.add(getObj("max_xue", 0f, 0.05f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3148": {//铜墙铁壁
                arr.add(getObj("wf", 0f, 0.08f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3149": {//铁壁
                arr.add(getObj("wf", 0f, 0.05f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3150": {//玄冥气盾
                arr.add(getObj("wf", 0f, 0.08f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3151": {//气盾
                arr.add(getObj("wf", 0f, 0.05f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3152": {//破体暗劲
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3153": {//暗劲
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3154": {//无风叠浪
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3155": {//叠浪
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3156": {//濒死爆发
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3157": {//爆发
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3158": {//灵魂震荡
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3159": {//震荡
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3160": {//嗜灵波动
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3161": {//波动
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3162": {//昭天禁锢
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3163": {//禁锢
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3164": {//弑魂一击
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3165": {//弑魂
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3166": {//凶神附体
                arr.add(getObj("bj", 0f, 0.2f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3167": {//凶神
                arr.add(getObj("bj", 0f, 0.1f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3168": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3169": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3170": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3171": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3172": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3173": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3174": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3175": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3176": {//锐利鹰眼
                arr.add(getObj("mz", 0f, 0.2f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3177": {//鹰眼
                arr.add(getObj("mz", 0f, 0.1f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3178": {//赤妖丰翼
                arr.add(getObj("sd", 0f, 0.12f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3179": {//丰翼
                arr.add(getObj("sd", 0f, 0.06f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3180": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3181": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3182": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3183": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3184": {//
                arr.add(getObj("ll", 0f, 0f, 1));
                res.put("type", 5);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }

            //===========================人物扩展技能-仙绝（天、地、人）=====================================
            case "3500": {//集思凝力 10%攻击
                arr.add(getObj("wg", 0f, 0.1f, 1));
                arr.add(getObj("fg", 0f, 0.1f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3501": {//舍命七伤 30%攻击 -60%闪避
                arr.add(getObj("wg", 0f, 0.3f, 1));
                arr.add(getObj("fg", 0f, 0.3f, 1));
                arr.add(getObj("sd", 0f, -0.6f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3502": {//精金血刃
                arr.add(getObj("wg", 0f, 0.08f, 1));
                arr.add(getObj("fg", 0f, 0.08f, 1));
                arr.add(getObj("mz", 0f, 0.2f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3503": {//如风迅击
                arr.add(getObj("wg", 0f, 0.13f, 1));
                arr.add(getObj("fg", 0f, 0.13f, 1));
                arr.add(getObj("bj", 0f, -0.06f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3504": {//嗜血狂攻
                arr.add(getObj("wg", 0f, 0.15f, 1));
                arr.add(getObj("fg", 0f, 0.15f, 1));
                arr.add(getObj("wf", 0f, -0.05f, 1));
                arr.add(getObj("ff", 0f, -0.05f, 1));
                arr.add(getObj("mz", 0f, -0.1f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3505": {//巨力碾压
                arr.add(getObj("wg", 0f, 0.2f, 1));
                arr.add(getObj("fg", 0f, 0.2f, 1));
                arr.add(getObj("wf", 0f, -0.3f, 1));
                arr.add(getObj("ff", 0f, -0.3f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3506": {//孤身铁胆
                arr.add(getObj("max_xue", 0f, 0.15f, 1));
                arr.add(getObj("sd", 0f, -0.2f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3507": {//玄火炼骨
                arr.add(getObj("max_xue", 0f, 0.15f, 1));
                arr.add(getObj("sd", 0f, -0.1f, 1));
                arr.add(getObj("wf", 0f, -0.05f, 1));
                arr.add(getObj("ff", 0f, -0.05f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3508": {//八玄锻脉
                arr.add(getObj("max_xue", 0f, 0.13f, 1));
                arr.add(getObj("bj", 0f, -0.05f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3509": {//金身硬化
                arr.add(getObj("max_xue", 0f, 0.08f, 1));
                arr.add(getObj("mz", 0f, 0.2f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3510": {//无极淬体
                arr.add(getObj("max_xue", 0f, 0.1f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3511": {//凝力
                arr.add(getObj("wg", 0f, 0.06f, 1));
                arr.add(getObj("fg", 0f, 0.06f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3512": {//七伤
                arr.add(getObj("wg", 0f, 0.15f, 1));
                arr.add(getObj("fg", 0f, 0.15f, 1));
                arr.add(getObj("sd", 0f, -0.3f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3513": {//血刃
                arr.add(getObj("wg", 0f, 0.04f, 1));
                arr.add(getObj("fg", 0f, 0.04f, 1));
                arr.add(getObj("mz", 0f, 0.15f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3514": {//迅击
                arr.add(getObj("wg", 0f, 0.08f, 1));
                arr.add(getObj("fg", 0f, 0.08f, 1));
                arr.add(getObj("bj", 0f, -0.03f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3515": {//狂攻
                arr.add(getObj("wg", 0f, 0.1f, 1));
                arr.add(getObj("fg", 0f, 0.1f, 1));
                arr.add(getObj("wf", 0f, -0.03f, 1));
                arr.add(getObj("ff", 0f, -0.03f, 1));
                arr.add(getObj("mz", 0f, -0.05f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3516": {//碾压
                arr.add(getObj("wg", 0f, 0.1f, 1));
                arr.add(getObj("fg", 0f, 0.1f, 1));
                arr.add(getObj("wf", 0f, -0.15f, 1));
                arr.add(getObj("ff", 0f, -0.15f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3517": {//铁胆
                arr.add(getObj("max_xue", 0f, 0.08f, 1));
                arr.add(getObj("sd", 0f, -0.1f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3518": {//炼骨
                arr.add(getObj("max_xue", 0f, 0.1f, 1));
                arr.add(getObj("sd", 0f, -0.05f, 1));
                arr.add(getObj("wf", 0f, -0.03f, 1));
                arr.add(getObj("ff", 0f, -0.03f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3519": {//锻脉
                arr.add(getObj("max_xue", 0f, 0.1f, 1));
                arr.add(getObj("bj", 0f, -0.03f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3520": {//硬化
                arr.add(getObj("max_xue", 0f, 0.06f, 1));
                arr.add(getObj("mz", 0f, 0.15f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3521": {//淬体
                arr.add(getObj("max_xue", 0f, 0.08f, 1));
                res.put("type", 3);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3522": {//聚精会神
                arr.add(getObj("mz", 0.02f, 0.02f, 1));
                res.put("type", 1);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3523": {//天罡护体
                arr.add(getObj("wf", 0f, 0.2f, 1));
                arr.add(getObj("ff", 0f, 0.2f, 1));
                res.put("type", 1);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3524": {//地煞夺魂
                arr.add(getObj("max_xue", 0f, 0.2f, 1));
                res.put("type", 2);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3525": {//勇士之怒
                arr.add(getObj("bj", 0f, 0.2f, 1));
                res.put("type", 1);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3526": {//恃强凌弱
                arr.add(getObj("max_xue", 0f, 0.2f, 1));
                res.put("type", 2);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3527": {//寒锋破晓
                arr.add(getObj("wg", 0f, 0.2f, 1));
                arr.add(getObj("fg", 0f, 0.2f, 1));
                res.put("type", 1);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3528": {//千里冰封
                arr.add(getObj("wg", 0f, 0.1f, 1));
                arr.add(getObj("fg", 0f, 0.1f, 1));
                res.put("type", 2);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3529": {//万象更新
                arr.add(getObj("max_xue", 0f, 0.2f, 1));
                res.put("type", 1);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3530": {//眷顾光环
                arr.add(getObj("wf", 0f, 0.2f, 1));
                arr.add(getObj("ff", 0f, 0.2f, 1));
                res.put("type", 2);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3531": {//穿梭阴阳
                arr.add(getObj("css", 0f, 0.2f, 1));
                res.put("type", 1);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }
            case "3532": {//禁制咒术
                arr.add(getObj("sd", 0f, 0.2f, 1));
                res.put("type", 2);//0门派1天2地3人4宠物专属5宠物普通
                break;
            }


            //青木长生、赤火蛮力、精金疾风、玄水明智、戊土精元
            case "3595": {
                arr.add(getObj("nl", 30f, 0f));
                res.put("type", 6);
                break;
            }
            case "3596": {
                arr.add(getObj("ll", 30f, 0f));
                res.put("type", 6);
                break;
            }
            case "3597": {
                arr.add(getObj("mj", 30f, 0f));
                res.put("type", 6);
                break;
            }
            case "3598": {
                arr.add(getObj("zl", 30f, 0f));
                res.put("type", 6);
                break;
            }
            case "3599": {
                arr.add(getObj("js", 30f, 0f));
                res.put("type", 6);
                break;
            }
            case "3600": {
                arr.add(getObj("max_xue", 0f, 500f));
                res.put("type", 7);
                break;
            }
            case "3601": {
                arr.add(getObj("max_lan", 0f, 500f));
                res.put("type", 7);
                break;
            }
            case "3602": {
                arr.add(getObj("wg", 0f, 200f));
                res.put("type", 7);
                break;
            }
            case "3603": {
                arr.add(getObj("fg", 0f, 200f));
                res.put("type", 7);
                break;
            }
            case "3604": {
                arr.add(getObj("wf", 0f, 200f));
                arr.add(getObj("ff", 0f, 200f));
                res.put("type", 7);
                break;
            }
            case "3605": {
                arr.add(getObj("bj", 0f, 200f));
                res.put("type", 7);
                break;
            }
            case "3606": {
                arr.add(getObj("mz", 0f, 500f));
                res.put("type", 7);
                break;
            }
            case "3607": {
                arr.add(getObj("sd", 0f, 200f));
                res.put("type", 7);
                break;
            }
            case "3608": {
                arr.add(getObj("css", 0f, 100f));
                res.put("type", 7);
                break;
            }

            default: {
                arr.add(getObj("ll", 0f, 0f));
                break;
            }
        }
        res.put("attrs", arr);
        return res;
    }

    /**
     * 由技能等级计算(固定值计算)
     */
    public static float count(Integer lv, JSONObject obj) {
        return obj.getFloat("k") * lv + obj.getFloat("b");
    }

    /**
     * n项和计算
     */
    public static float countNItemSum(Integer lv, JSONObject obj) {
        return (obj.getFloat("k") * lv + obj.getFloat("b") +
                obj.getFloat("k") * 1 + obj.getFloat("b")) / 2f * lv;
    }

    /**
     * 由技能等级计算(比例值计算)
     * obj {name,k,b,valueType}
     * base物攻、法攻等属性的最终固定值
     */
    public static float countByK(Integer lv, JSONObject obj, JSONObject base) {
        //固定值的就用0
        float k = obj.getFloat("k") * lv + obj.getFloat("b");
        //System.out.println(obj.getString("name"));
        float value = base.getFloat(obj.getString("name")) * k;
        return value;
    }


    public static JSONObject getObj(String name, Float k, Float b, int... valueType) {
        JSONObject j = new JSONObject();
        j.put("name", name);
        j.put("k", k);
        j.put("b", b);
        //0固定值1比例
        if (valueType.length > 0) {
            j.put("valueType", 1);
        } else {
            j.put("valueType", 0);
        }
        return j;
    }
}

class aToBAttr {
    public String aKey;
    public String bKey;
    public Float k;

    public aToBAttr(String aKey, String bKey, Float k) {
        this.aKey = aKey;
        this.bKey = bKey;
        this.k = k;
    }
}
