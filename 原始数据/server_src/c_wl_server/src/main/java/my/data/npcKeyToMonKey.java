package my.data;

import my.utils.loggerUtils;
import my.utils.strUtils;

/**
 * 怪物npc对应的怪物key
 */
public class npcKeyToMonKey {
    /**
     * npcKey关联怪物key
     * 遭遇怪物时，是通过npcKey来获取所对应的怪物
     */
    public static String npcKeyMatchMonsterKey(String npcKey) {
        if (npcKey.contains("abyss_") || npcKey.contains("fb_") ||
                npcKey.contains("qlhd_") || npcKey.contains("mshuwei_")
                || npcKey.contains("xhxy_") || npcKey.contains("hhbk_")
                || npcKey.contains("dmkj_") || npcKey.contains("xxzd_")
                || npcKey.contains("cyby_")
                || npcKey.contains("jyfy_") || strUtils.isMatch(npcKey, "yzj_([0-9]{1})")
                || npcKey.contains("mpbwz_")) {//深渊、副本
            return npcKey;
        } else if (strUtils.isMatch(npcKey, "gw([0-9]{4})")) {//普通怪
            return npcKey.replace("gw", "");
        }
        System.err.println("遇怪时未找到npc对应的怪物" + npcKey);
        return null;
    }

}
