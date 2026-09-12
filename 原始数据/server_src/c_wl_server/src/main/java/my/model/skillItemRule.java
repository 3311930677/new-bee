package my.model;

import com.alibaba.fastjson2.JSONObject;

import java.util.List;

/**
 * 父级
 */
public class skillItemRule {
    //规则类型
    public int ruleType;

    //这些参数无实际意义，当创建具体规则后才会有实际意义
    //存放的线性值
    public List<val> valList;
    public boolean paramBool;
    public List<Boolean> paramBoolList;
    public int paramInt;
    public List<Integer> paramIntList;
    public String paramStr;
    public List<String> paramStrList;

    public JSONObject paramJObj;

    public float getVal(float lv, int index) {
        val kv = this.valList.get(index);
        return kv.k * lv + kv.b;
    }

    /**
     * 返回给前端的提示数值
     */
    public int getValToTip(int k, int lv, int index) {
        val kv = this.valList.get(index);
        int v = (int) (k * lv * kv.k + k * kv.b);
        return v;
    }

    public int getValueType(int index) {
        return this.valList.get(index).valueType;
    }

}
