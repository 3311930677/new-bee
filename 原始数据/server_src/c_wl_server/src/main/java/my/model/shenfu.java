package my.model;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;

public class shenfu {
    public String key;
    public JSONArray cailiaoList;
    public learnResultRule learnResultRule;
    //效果持续时间（单位：分钟）
    public long effectTime;
    public shenfu(String key) {
        this.key = key;
    }
    public  float count(Integer lv, JSONObject obj) {
        return obj.getFloat("k") * lv + obj.getFloat("b");
    }
    public JSONArray getAttrs() {
        if (this.learnResultRule == null) {
            return new JSONArray();
            //System.err.println("技能learnResultRule=null => " + this.key);
        }
        return this.learnResultRule.attrs;
    }
    public shenfu addEffectTime(long effectTime){
        this.effectTime=effectTime;
        return this;
    }
    public shenfu putCaiLiaoList(String k,int num){
        if(cailiaoList==null) cailiaoList=new JSONArray();
        JSONObject a=new JSONObject();
        a.put("key",k);
        a.put("num",num);
        cailiaoList.add(a);
        return this;
    }

    public shenfu putshenfuResultRule(String name, float k, float b, int valueType) {
        if (this.learnResultRule == null || this.learnResultRule.attrs == null) {
            this.learnResultRule = new learnResultRule(new JSONArray());
        }
        JSONObject o = new JSONObject();
        o.put("name", name);
        o.put("k", k);
        o.put("b", b);
        o.put("valueType", valueType);//0固定值1原值的倍数
        JSONArray list = this.learnResultRule.attrs;
        list.add(o);
        return this;
    }
}
