package my.model;

import my.utils.strUtils;
import org.apache.commons.codec.digest.DigestUtils;

import java.io.Serializable;

public class auth implements Serializable {
    //授权的ip
    public Object[] allowedIp;
    //确认上线 登录页登录后产生一个auth，但是并未确认上线的，
    // 当websocket连接后就需要确认上线，未确认上线的有效时长为1分钟后销毁
    //public boolean isSure;
    //创建的时间
    public long created;
    //md5密文-第一次websocket连接时有效，连接成功后销毁，防止同个身份多个连接
    public String md5;

    public auth() {
    }

    public auth(Object[] allowedIp) {
        //登录后缓存授权的ip列表，ws连接时需要对比
        this.allowedIp = allowedIp;
        //ws连接后设置为true，超时判断是否为false，是就会移除auth
        //this.isSure = false;
        //授权时间，用于超时移除
        this.created = strUtils.getTime();
    }

    public String createMD5(String username) {
        //生成一个md5号
        this.md5 = DigestUtils.md5Hex((username + this.created).getBytes());
        return this.md5;
    }

    /**
     * md5字符串是否匹配
     */
    public boolean isMatchMD5(String str) {
        if (str == null) return false;
        boolean b = str.equals(this.md5);
        //验证后要销毁，防止同个身份多个连接
        this.md5 = null;
        return b;
    }

    /**
     * 验证是否授权通过
     */
    public boolean isPass(String md5, String ip) {
        for (Object a : allowedIp) {
            if (a.equals(ip) && isMatchMD5(md5))
                return true;
        }
        return false;
    }
}
