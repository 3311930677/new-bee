package my.gameUtils;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;

import static my.fightUtils.fightUtils.*;
import static my.fightUtils.fightUtils.getSkillObj;

public class aiUtils {

    public static JSONObject getAiDataByName(String name) {
        switch (name) {
            case "宫主": {
                JSONArray skills = getSkillList(
                        getSkillObj("3047", 1), getSkillObj("3072", 1)
                );
                JSONObject prop = getAttrObj(100000, 15000, 15000, 1000, 1500, 1000, 10000, 100, 100);
                return createDefinedFightData(name, 1, prop, skills);
            }
            case "白供奉": {
                JSONArray skills = getSkillList(
                        getSkillObj("3047", 1), getSkillObj("3072", 1)
                );
                JSONObject prop = getAttrObj(80000, 4000, 5000, 1000, 1500, 1000, 10000, 100, 100);
                return createDefinedFightData(name, 1, prop, skills);
            }
            case "黑供奉": {
                JSONArray skills = getSkillList(
                        getSkillObj("3047", 1), getSkillObj("3072", 1)
                );
                JSONObject prop = getAttrObj(60000, 3000, 5000, 1000, 1500, 1000, 10000, 100, 100);
                return createDefinedFightData(name, 1, prop, skills);
            }
            case "项羽": {
                JSONArray skills = getSkillList(
                        getSkillObj("3047", 1), getSkillObj("3072", 1)
                );
                JSONObject prop = getAttrObj(10000, 1500, 1500, 200, 200, 1000, 10000, 100, 100);
                return createDefinedFightData(name, 1, prop, skills);
            }
            case "玉清风": {
                JSONArray skills = getSkillList(
                        getSkillObj("3047", 1), getSkillObj("3072", 1)
                );
                JSONObject prop = getAttrObj(10000, 1500, 1500, 200, 200, 1000, 10000, 100, 100);
                return createDefinedFightData(name, 1, prop, skills);
            }
            case "黄秋月": {
                JSONArray skills = getSkillList(
                        getSkillObj("3047", 1), getSkillObj("3072", 1)
                );
                JSONObject prop = getAttrObj(10000, 1500, 1500, 200, 200, 1000, 10000, 100, 100);
                return createDefinedFightData(name, 1, prop, skills);
            }
        }
        return null;
    }
}
