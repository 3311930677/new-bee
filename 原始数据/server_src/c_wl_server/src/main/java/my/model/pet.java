package my.model;

import com.alibaba.fastjson2.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class pet {
    public String key;
    public String nickName;
    public String model;
    public int type;//0物理1法术
    public int fightLv;//出战等级
    public JSONObject zizhi;
    //专属技能 第一个就是天生技能
    public List<String> zsSkls;


    public pet(String key) {
        this.key = key;
        this.model = key;
    }

    public pet(String key, String nickName, String model, int type, int fightLv) {
        this.key = key;
        this.nickName = nickName;
        this.model = model;
        this.type = type;
        this.fightLv = fightLv;
    }

    public pet addZsSkls(String... sklKey) {
        if (this.zsSkls == null) this.zsSkls = new ArrayList<>();
        this.zsSkls.addAll(Arrays.asList(sklKey));
        return this;
    }

    /**
     * 自动计算出战等级
     */
    public pet autoFightLv() {
        int index = Integer.parseInt(this.key) - 1000;
        int n = (int) (index / 214f * 100f);
        if (n > 100) n = 100;
        else if (n < 1) n = 1;
        this.fightLv = n;
        return this;
    }

    public pet addFightLv(int fightLv) {
        this.fightLv = fightLv;
        return this;
    }

    public pet init(String nickName) {
        this.nickName = nickName;
        this.type = 0;
        return this;
    }

    public pet init(String nickName, int type) {
        this.nickName = nickName;
        this.type = type;
        return this;
    }

    /**
     * 由key自动生成资质
     */
    public pet autoAddQualityByKey() {
        int index = Integer.parseInt(this.key) - 1000;
        autoAddQualityByK(1f + index / 80f, 1f + index / 80f * 0.7f);
        return this;
    }

    /**
     * 由系数来生成资质数据
     * k0影响血量、蓝
     * k1影响攻击
     */
    public void autoAddQualityByK(float k0, float k1) {
        int wg, fg;
        if (this.type == 0) {
            wg = (int) (800 * k1);
            fg = wg / 2;
        } else {
            fg = (int) (800 * k1);
            wg = fg / 2;
        }


        this.bindQualityGroundStruct((int) (800 * k0), (int) (500 * k0), wg, fg,
                (int) (wg / 1.5), (int) (fg / 1.5), (int) (wg / 1.6), (int) (200 * k0), (int) (300 * k0), (int) (fg / 1.8));
    }

    public void bindQualityGroundStruct(int max_xue, int max_lan, int wg, int fg, int wf, int ff, int mz, int sd, int css, int bj) {
        JSONObject quality = new JSONObject();
        quality.put("max_xue", max_xue);
        quality.put("max_lan", max_lan);
        quality.put("wg", wg);
        quality.put("fg", fg);
        quality.put("wf", wf);
        quality.put("ff", ff);
        quality.put("mz", mz);
        quality.put("sd", sd);
        quality.put("css", css);
        quality.put("bj", bj);
        this.zizhi = quality;
    }
}
