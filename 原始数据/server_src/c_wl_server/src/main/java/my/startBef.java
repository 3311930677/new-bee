package my;

import my.db.mybatisConfig;
import my.service.*;
import my.service.ac.*;
import my.service.fight.fixedTimeTaskHandle;
import my.utils.classUtils;
import my.utils.loggerUtils;
import my.utils.runTaskUtils;
import my.utils.staticCollection;

import java.lang.reflect.Field;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * 启动前处理
 */
public class startBef {
    public static chatService chatService;
    public static downloadService downloadService;
    public static emailService emailService;
    public static gangsService gangsService;
    public static loginService loginService;
    public static manService manService;
    public static mapService mapService;
    public static onlineService onlineService;
    public static my.service.packageService packageService;
    public static petService petService;
    public static my.service.prisonService prisonService;
    public static sysService sysService;
    public static taskService taskService;
    public static teamService teamService;

    public static my.service.investService investService;

    public static logService logService;
    public static rewardService rewardService;
    public static my.service.activityService activityService;
    public static shopService shopService;
    public static my.service.fightRpcService fightRpcService;
    public static my.service.fightService fightService;
    public static my.service.fightOverService fightOverService;
    public static my.service.answerService answerService;
    public static my.service.orderService orderService;
    public static my.service.zhuanpanService zhuanpanService;
    public static my.service.wzyService wzyService;
    public static my.service.cbService cbService;
    public static my.service.jmService jmService;
    public static my.service.worldBossService worldBossService;
    public static my.service.dsxService dsxService;
    public static my.service.fbService fbService;
    public static friendService friendService;


    public static my.service.zslService zslService;

    public static my.service.stService stService;




    public static my.service.npcCreateService npcCreateService;




    public static vipService vipService;
    public static yhmkService yhmkService;


    public static my.service.fuliService fuliService;
    public static my.service.ac.dmkjService dmkjService;
    public static my.service.ac.openServerAcService openServerAcService;

    public static my.service.mjxwService mjxwService;

    public static my.service.ac.hhbkService hhbkService;


    public static my.service.blytService blytService;

    public static my.service.bzqjService bzqjService;
    public static my.service.jingjiService jingjiService;
    public static my.service.ac.cjwdService cjwdService;
    public static julingService julingService;
    public static my.service.ac.shenfuService shenfuService;
    public static my.service.ac.tjypService tjypService;
    public static my.service.ac.wzycService wzycService;
    public static my.service.ac.zjcmService zjcmService;
    public static my.service.ac.cybyService cybyService;
    public static my.service.ac.jyfyService jyfyService;
    public static my.service.ac.mpbwzService mpbwzService;
    public static my.service.ac.farmService farmService;
    public static my.service.ac.dzfsbService dzfsbService;
    public static my.service.ac.jimaiService jimaiService;
    public static my.service.ac.xxzdService xxzdService;
    //public static getIpService getIpService;

    //public static zhouqiuAcService zhouqiuAcService;
    //public static guoqingAcService guoqingAcService;

    //public static zhounianqingAcService zhounianqingAcService;



    public static boolean init() {
        //实例化服务
        createService();
        loggerUtils.info("实例化服务完成！", startBef.class);
        //初始化数据库配置
        mybatisConfig.config();
        //读取活动配置
        startBef.activityService.initConfig();
        //mybatisConfig.test();

        startBef.sysService.addZdToManMsg();
        //startBef.sysService.exportBPData();
        /*if (startBef.taskService.clearTaskByListKey())
            return false;*/
        //初始化数据库数据
        sysService.countMoney(true);
        /*boolean b = sysService.startInitData();
        if (!b) {
            return b;
        }*/
        //启动任务处理器
        runTaskUtils.startTask();
        //将未退邮的数据重新放入缓存
        emailService.addBackEmailToCache();
        //生成排行数据
        orderService.createOrder();
        sysService.checkReStart();
        //定时清理验证码
        sysService.removeCode();
        //定时位置同步
        onlineService.timerUpdatePos();
        //定时清理聊天
        //chatService.clearChat();
        //战斗相关的定时器
        fixedTimeTaskHandle.getOne().startTask();
        //定时检测活动开启
        activityService.createActivity();
        //定时检测砍价商品出售情况
        shopService.startCutPriceTimer();

        //生成排行数据
        staticCollection.putTask(() -> {
            try {
                //orderService.createOrder();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }, 60, TimeUnit.SECONDS);
        loggerUtils.info("定时任务启动完成！", startBef.class);
        //清理日常
        //startBef.taskService.updateDailyTask();
        return true;
    }

    /**
     * 创建接口单例，避免反射造成太多实例
     */
    public static void createService() {
        Field[] fields = classUtils.getAllField(startBef.class);
        for (Field field : fields) {
            field.setAccessible(true);
            try {
                field.set(startBef.class, classUtils.createSingle(field.getType()));
                //System.err.println(field.get(startBef.class));
            } catch (IllegalAccessException e) {
                e.printStackTrace();
            }
        }
    }

    /**
     * 寻找服务实例调取方法
     */
    public static <V> V invokeMethod(String type, String method, List data) throws Exception {
        Field[] fields = classUtils.getAllField(startBef.class);
        for (Field field : fields) {
            String name = field.getType().getSimpleName();
            if (name.equals(type)) {
                Object obj = field.get(startBef.class);
                Class[] c = new Class[data.size()];
                for (int i = 0; i < data.size(); i++) {
                    c[i] = data.get(i).getClass();
                }
                return (V) obj.getClass().getDeclaredMethod(method, c).invoke(obj, data.toArray());
            }
        }
        return null;
    }
}
