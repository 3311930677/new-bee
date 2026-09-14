package my.model;

import com.alibaba.fastjson2.JSONObject;

public class huoban {
    public int lever = 1;
    public String key;
    public String name;
    public String nickName;
    public String model;
    public int type;//0物理1法术
    //品质 默认0白品 1蓝 2紫 3橙 4金 5红 不同品质
    public int quality = 0;
    //资质 (设定的值，最大)
    public JSONObject zizhi;
    //阵营 0蜀1魏2吴3群
    public int camp;
    //成长率 1.0-2.0 可提升 初始1.0，需要消耗道具成长丹
    public float grow = 1f;
    //具体资质(创建时生成) 吃丹的总值不超过这个资质的50%（5个基本属性）
    public JSONObject qualityValue;
    //成长等级 共20级 星
    public int growLv = 0;
    //突破等级 满10星后需要道具突破
    public int growBreachLv = 0;
    //天生技能两个，固定，其他技能通过法宝绑定(类似记录装备字段)
    public String fabao;
    //5个基本属性 吃丹的总值不超过50%
    public JSONObject attr;
    //5个附灵位置 0、1、2、4、6星解锁 p0-4绑定武将key
    public JSONObject fuling;
    //武魂附体
    public String wuhunKey;
    //武将缘分
    public huoban(String key){
        this.key = key;
    }
    public huoban(String key, String name, String model, int type, int camp) {
        this.key = key;
        this.name = name;
        this.model = model;
        this.type = type;
        this.nickName = name;
        this.camp = camp;
    }

    public huoban init(String name, String model){
        this.name = name;
        this.nickName = name;
        this.model = model;
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
