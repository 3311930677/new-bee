package my.model;

public class fixedRule {
    public Float k;
    public Float b;
    //值类型 0固定值 1百分比
    public Integer valueType;

    public fixedRule(Float k, Float b, Integer valueType) {
        this.k = k;
        this.b = b;
        this.valueType = valueType;
    }

}
