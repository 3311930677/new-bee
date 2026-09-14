package my.model;

import com.alibaba.fastjson2.JSONObject;
import com.alibaba.fastjson2.annotation.JSONField;
import my.utils.strUtils;

public class msgCenter {
    //防止json转换时变成小写
    @JSONField(name ="Id")
    public String Id;
    public Long created;
    public int type;
    public JSONObject params;
    public msgCenter() {
    }

    public msgCenter( int type) {
        this.Id = strUtils.getId();
        this.created = strUtils.getTime();
        this.type = type;
        this.params = new JSONObject();
    }
    /**放置玩家名、等级*/
    public msgCenter putParams(String name,int lv){
        this.params.put("name",name);
        this.params.put("lv", lv);
        return this;
    }
    /**添加其他参数*/
    public msgCenter addParams(String k,Object v){
        this.params.put(k, v);
        return this;
    }
}
