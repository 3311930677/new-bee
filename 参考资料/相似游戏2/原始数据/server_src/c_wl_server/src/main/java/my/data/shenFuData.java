package my.data;

import com.alibaba.fastjson2.JSONObject;
import my.model.shenfu;

public class shenFuData {
    public static shenfu get(String key) {
        shenfu sf = new shenfu(key);
        if (key.equals("10140000")) {
            sf.putshenfuResultRule("wg", 0, 0.08f, 1)
                    .putshenfuResultRule("fg", 0, 0.08f, 1);
            sf.putCaiLiaoList("10150000", 2).putCaiLiaoList("10150002", 3);
            sf.addEffectTime(15);
        } else if (key.equals("10140001")) {
            sf.putshenfuResultRule("wg", 0, 0.04f, 1).putshenfuResultRule("bj", 0, 0.12f, 1);
            sf.putCaiLiaoList("10150000", 2).putCaiLiaoList("10150001", 3);
            sf.addEffectTime(15);
        } else if (key.equals("10140002")) {
            sf.putshenfuResultRule("wg", 0, 0.14f, 1).putshenfuResultRule("css", 0, 0.14f, 1);
            sf.putCaiLiaoList("10150006", 2).putCaiLiaoList("10150007", 4);
            sf.addEffectTime(15);
        } else if (key.equals("10140003")) {
            sf.putshenfuResultRule("wg", 0, 0.07f, 1).putshenfuResultRule("bj", 0, 0.21f, 1);
            sf.putCaiLiaoList("10150003", 4).putCaiLiaoList("10150006", 2);
            sf.addEffectTime(15);
        } else if (key.equals("10140004")) {
            sf.putshenfuResultRule("wg", 0, 0.2f, 1).putshenfuResultRule("css", 0, 0.2f, 1);
            sf.putCaiLiaoList("10150008", 2).putCaiLiaoList("10150009", 6);
            sf.addEffectTime(15);
        } else if (key.equals("10140005")) {
            sf.putshenfuResultRule("wg", 0, 0.1f, 1).putshenfuResultRule("bj", 0, 0.3f, 1);
            sf.putCaiLiaoList("10150008", 2).putCaiLiaoList("10150010", 6);
            sf.addEffectTime(15);
        } else if (key.equals("10140006")) {
            sf.putshenfuResultRule("wg", 0, 0.26f, 1).putshenfuResultRule("css", 0, 0.26f, 1);
            sf.putCaiLiaoList("10150005", 8).putCaiLiaoList("10150011", 2);
            sf.addEffectTime(15);
        } else if (key.equals("10140007")) {
            sf.putshenfuResultRule("wg", 0, 0.13f, 1).putshenfuResultRule("bj", 0, 0.39f, 1);
            sf.putCaiLiaoList("10150004", 8).putCaiLiaoList("10150011", 2);
            sf.addEffectTime(15);
        } else if (key.equals("10140008")) {
            sf.putshenfuResultRule("wg", 0, 0.3f, 1).putshenfuResultRule("css", 0, 0.3f, 1);
            sf.putCaiLiaoList("10150012", 2).putCaiLiaoList("10150013", 12);
            sf.addEffectTime(15);
        } else if (key.equals("10140009")) {
            sf.putshenfuResultRule("max_xue", 0, 0.04f, 1).putshenfuResultRule("sd", 0, 0.12f, 1);
            sf.putCaiLiaoList("10150000", 2).putCaiLiaoList("10150002", 3);
            sf.addEffectTime(15);
        } else if (key.equals("10140010")) {
            sf.putshenfuResultRule("wf", 0, 0.08f, 1).putshenfuResultRule("ff", 0, 0.08f, 1).putshenfuResultRule("sd", 0, 0.08f, 1);
            sf.putCaiLiaoList("10150000", 2).putCaiLiaoList("10150001", 3);
            sf.addEffectTime(15);
        } else if (key.equals("10140011")) {
            sf.putshenfuResultRule("max_xue", 0, 0.07f, 1).putshenfuResultRule("sd", 0, 0.21f, 1);
            sf.putCaiLiaoList("10150006", 2).putCaiLiaoList("10150007", 4);
            sf.addEffectTime(15);
        } else if (key.equals("10140012")) {
            sf.putshenfuResultRule("wf", 0, 0.14f, 1).putshenfuResultRule("ff", 0, 0.14f, 1).putshenfuResultRule("sd", 0, 0.14f, 1);
            sf.putCaiLiaoList("10150003", 4).putCaiLiaoList("10150006", 2);
            sf.addEffectTime(15);
        } else if (key.equals("10140013")) {
            sf.putshenfuResultRule("max_xue", 0, 0.1f, 1).putshenfuResultRule("sd", 0, 0.3f, 1);
            sf.putCaiLiaoList("10150008", 2).putCaiLiaoList("10150009", 6);
            sf.addEffectTime(15);
        } else if (key.equals("10140014")) {
            sf.putshenfuResultRule("wf", 0, 0.2f, 1).putshenfuResultRule("ff", 0, 0.2f, 1).putshenfuResultRule("sd", 0, 0.2f, 1);
            sf.putCaiLiaoList("10150008", 2).putCaiLiaoList("10150010", 6);
            sf.addEffectTime(15);
        } else if (key.equals("10140015")) {
            sf.putshenfuResultRule("max_xue", 0, 0.13f, 1).putshenfuResultRule("sd", 0, 0.39f, 1);
            sf.putCaiLiaoList("10150005", 8).putCaiLiaoList("10150011", 2);
            sf.addEffectTime(15);
        } else if (key.equals("10140016")) {
            sf.putshenfuResultRule("wf", 0, 0.26f, 1).putshenfuResultRule("ff", 0, 0.26f, 1).putshenfuResultRule("sd", 0, 0.26f, 1);
            sf.putCaiLiaoList("10150004", 8).putCaiLiaoList("10150011", 2);
            sf.addEffectTime(15);
        } else if (key.equals("10140017")) {
            sf.putshenfuResultRule("max_xue", 0, 0.15f, 1).putshenfuResultRule("sd", 0, 0.45f, 1);
            sf.putCaiLiaoList("10150012", 2).putCaiLiaoList("10150013", 12);
            sf.addEffectTime(15);
        } else if (key.equals("10140018")) {
            sf.putshenfuResultRule("fg", 0, 0.08f, 1).putshenfuResultRule("css", 0, 0.08f, 1);
            sf.putCaiLiaoList("10150000", 2).putCaiLiaoList("10150002", 3);
            sf.addEffectTime(15);
        } else if (key.equals("10140019")) {
            sf.putshenfuResultRule("fg", 0, 0.08f, 1).putshenfuResultRule("css", 0, 0.08f, 1);
            sf.putCaiLiaoList("10150000", 2).putCaiLiaoList("10150001", 3);
            sf.addEffectTime(15);
        } else if (key.equals("10140020")) {
            sf.putshenfuResultRule("fg", 0, 0.08f, 1).putshenfuResultRule("css", 0, 0.08f, 1);
            sf.putCaiLiaoList("10150006", 2).putCaiLiaoList("10150007", 4);
            sf.addEffectTime(15);
        } else if (key.equals("10140021")) {
            sf.putshenfuResultRule("fg", 0, 0.07f, 1).putshenfuResultRule("bj", 0, 0.21f, 1);
            sf.putCaiLiaoList("10150003", 4).putCaiLiaoList("10150006", 2);
            sf.addEffectTime(15);
        } else if (key.equals("10140022")) {
            sf.putshenfuResultRule("fg", 0, 0.2f, 1).putshenfuResultRule("css", 0, 0.2f, 1);
            sf.putCaiLiaoList("10150008", 2).putCaiLiaoList("10150009", 6);
            sf.addEffectTime(15);
        } else if (key.equals("10140023")) {
            sf.putshenfuResultRule("fg", 0, 0.1f, 1).putshenfuResultRule("bj", 0, 0.3f, 1);
            sf.putCaiLiaoList("10150008", 2).putCaiLiaoList("10150009", 10);
            sf.addEffectTime(15);
        } else if (key.equals("10140024")) {
            sf.putshenfuResultRule("fg", 0, 0.26f, 1).putshenfuResultRule("css", 0, 0.26f, 1);
            sf.putCaiLiaoList("10150005", 8).putCaiLiaoList("10150011", 2);
            sf.addEffectTime(15);
        } else if (key.equals("10140025")) {
            sf.putshenfuResultRule("fg", 0, 0.13f, 1).putshenfuResultRule("bj", 0, 0.39f, 1);
            sf.putCaiLiaoList("10150004", 8).putCaiLiaoList("10150011", 2);
            sf.addEffectTime(15);
        } else if (key.equals("10140026")) {
            sf.putshenfuResultRule("fg", 0, 0.3f, 1).putshenfuResultRule("css", 0, 0.3f, 1);
            sf.putCaiLiaoList("10150012", 2).putCaiLiaoList("10150013", 12);
            sf.addEffectTime(15);
        } else if (key.equals("10140027")) {
            sf.putshenfuResultRule("bj", 0, 0.05f, 1).putshenfuResultRule("wg", 0, 0.2f, 1).putshenfuResultRule("fg", 0, 0.2f, 1);
            sf.addEffectTime(15);
        } else if (key.equals("10140028")) {
            sf.putshenfuResultRule("bj", 0, 0.2f, 1).putshenfuResultRule("wg", 0, 0.05f, 1).putshenfuResultRule("fg", 0, 0.05f, 1);
            sf.addEffectTime(15);
        } else if (key.equals("10140029")) {
            sf.putshenfuResultRule("bj", 0, 0.1f, 1).putshenfuResultRule("mz", 0, 0.1f, 1).putshenfuResultRule("sd", 0, 0.05f, 1);
            sf.addEffectTime(15);
        } else if (key.equals("10140030")) {
            sf.putshenfuResultRule("bj", 0, 0.05f, 1).putshenfuResultRule("mz", 0, 0.1f, 1).putshenfuResultRule("sd", 0, 0.1f, 1);
            sf.addEffectTime(15);
        } else if (key.equals("10140031")) {
            sf.putshenfuResultRule("wg", 0, 0.1f, 1).putshenfuResultRule("fg", 0, 0.1f, 1)
                    .putshenfuResultRule("wf", 0, 0.1f, 1).putshenfuResultRule("ff", 0, 0.1f, 1)
                    .putshenfuResultRule("css", 0, 0.1f, 1).putshenfuResultRule("max_xue", 0, 0.1f, 1)
                    .putshenfuResultRule("max_lan", 0, 0.1f, 1).putshenfuResultRule("bj", 0, 0.1f, 1)
                    .putshenfuResultRule("mz", 0, 0.1f, 1).putshenfuResultRule("sd", 0, 0.1f, 1);
            sf.addEffectTime(15);
        } else {
            return null;
        }
        return sf;
    }
}
