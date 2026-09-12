package my.utils;

import my.model.runTask;

import java.util.Vector;
import java.util.concurrent.TimeUnit;

public class runTaskUtils {
    //是否还在处理
    private static boolean isDoing=false;
    private static Vector<runTask> runTaskList=new Vector<>();
    /**添加一个待处理的任务*/
    public static void addTask(runTask task){
        runTaskList.add(task);
    }
    /**启动周期线程处理*/
    public static void startTask(){
        staticCollection.putTask(()->{
            if(isDoing) return;
            isDoing=true;
            try {
                handle();
            }catch (Exception e){
                e.printStackTrace();
            }
            isDoing=false;
        },1,1, TimeUnit.SECONDS);
    }
    private static void handle() throws Exception{
        int len=runTaskList.size();
        //先移除空已经完成的
        for(int i=0;i<len;i++){
            if(runTaskList.get(i).isRem()){
                runTaskList.remove(i);
                i--;
                len--;
            }
        }
        for(int i=0;i<len;i++){
            runTaskList.get(i).startRun();
        }
    }
}
