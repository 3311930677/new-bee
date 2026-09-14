package my.model;
/**法宝、护符、功法等效果类*/
public class fbResult {
    public String key;
    public float k;
    public float b;
    public int limitLv;

    public fbResult(String key, float k, float b) {
        this.key = key;
        this.k = k;
        this.b = b;
        this.limitLv=100;
    }

    public fbResult(String key, float k, float b, int limitLv) {
        this.key = key;
        this.k = k;
        this.b = b;
        this.limitLv = limitLv;
    }

    /**获取最终增伤*/
    public float getFinalHurtAddOrCut(int lv){
        return this.getV(lv);
    }
    /**获取通用计算值*/
    public float getV(int lv){
        return k*lv+b;
    }
}
