package my.model;

import my.utils.strUtils;

/**待执行任务，周期回调时处理*/
public class runTask {
    private String des;
    private Runnable callback;
    private long created;
    //延时多久
    private long delay;
    //是否已经执行完成
    private boolean isDone;

    public runTask(Runnable callback, long delay) {
        this.callback = callback;
        this.created=strUtils.getTime();
        this.delay = delay;
    }
    /**执行任务*/
    public void startRun() throws Exception{
        if(strUtils.getTime()<(created+delay)) return;
        this.isDone=true;
        this.callback.run();
    }
    /**是否可以移除*/
    public boolean isRem(){
        if(this.isDone) return true;
        return false;
    }
    public runTask addDes(String des){
        this.des=des;
        return this;
    }
}
