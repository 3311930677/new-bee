package my.model;

public class val {
    public float k;
    public float b;
    //值类型 0固定值 1百分比
    public int valueType;

    public val(float k, float b, int valueType) {
        this.k = k;
        this.b = b;
        this.valueType = valueType;
    }

    public float getVal(int lv) {
        return this.k * lv + b;
    }

}
