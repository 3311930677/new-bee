package my.model;

import my.utils.strUtils;

/**
 * 活动缓存
 */
public class activityCache {
    //活动是否开启(活动的禁止)
    public Integer isOpen;
    //活动是否正在进行
    public Integer isDoing;
    //活动名
    public String acName;
    //活动key
    public String acKey;
    //0无限期活动1限时活动（开始时间、结束时间）2定时活动（每隔一段时间开启一次）
    public Integer type;
    //起始点时间
    public Long initTime;
    //延时点时间
    public Long delayTime;
    //开始时间
    public String startDay;
    //结束时间
    public String endDay;
    //开始结束时间点
    public Integer hour0, min0, hour1, min1;
    //指定周几
    public Integer week;

    public activityCache(String acName, String acKey, Integer type, Long delayTime) {
        this.acName = acName;
        this.acKey = acKey;
        this.type = type;
        this.isOpen = 1;
        this.isDoing = 0;
        this.delayTime = delayTime;
        if (this.delayTime != null) {
            this.isDoing = 1;
        }
    }

    public void initTime(int hour0, int min0, int hour1, int min1) {
        //指定多少点到多少点（当日）
        this.hour0 = hour0;
        this.min0 = min0;
        this.hour1 = hour1;
        this.min1 = min1;
    }

    public void initDay(String startDay, String endDay) {
        //指定多少号到多少号
        this.startDay = startDay;
        this.endDay = endDay;
    }

    /**
     * 是否处于指定的时间内
     */
    public boolean isInTime() {
        if (this.startDay != null) {
            if (!strUtils.isInDay(this.startDay, this.endDay)) {
                return false;
            }
        }
        if (this.week != null) {
            if (!strUtils.isWKS(this.week)) {
                return false;
            }
        }
        if (this.hour0 != null) {
            if (!strUtils.isInTime(this.hour0, this.min0, this.hour1, this.min1)) {
                return false;
            }
        }
        if (this.delayTime != null) {
            if (this.initTime == null) {
                this.initTime = strUtils.getTime();
            }
            //在延时期间内-表示活动正在进行，不在时表示活动处于结算中
            if (strUtils.getTime() - this.initTime < this.delayTime) {
                return true;//未处于定时结算
            } else {
                return false;//处于定时结算
            }
        }
        return true;
    }
}
