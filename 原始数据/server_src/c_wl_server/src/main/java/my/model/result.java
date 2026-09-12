package my.model;

import com.alibaba.fastjson2.JSON;
import my.utils.strUtils;

public class result {
    private Integer code;
    private Object msg;
    private String callback;
    private long t;//增加一个时间戳，让加密码每次都不一样

    /*public result(Object msg) {
        this.code = 200;
        this.msg = msg;
    }*/

    public result(int code) {
        this.code = code;
        this.t = strUtils.getTime();
    }

    public result(Integer code, Object msg) {
        this.code = code;
        this.msg = msg;
        this.t = strUtils.getTime();
    }

    public result(Integer code, Object msg, String callback) {
        this.code = code;
        this.msg = msg;
        this.callback = callback;
        this.t = strUtils.getTime();
    }

    public String toJSON() {
        //System.err.println(this);
        return JSON.toJSONString(this);
    }

    public Integer getCode() {
        return code;
    }

    public void setCode(Integer code) {
        this.code = code;
    }

    public Object getMsg() {
        return msg;
    }

    public void setMsg(Object msg) {
        this.msg = msg;
    }

    public String getCallback() {
        return callback;
    }

    public void setCallback(String callback) {
        this.callback = callback;
    }

    @Override
    public String toString() {
        return "result{" +
                "code=" + code +
                ", msg=" + msg +
                ", callback='" + callback + '\'' +
                '}';
    }
}

