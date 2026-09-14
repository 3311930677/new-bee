package my.utils;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import io.netty.channel.Channel;
import io.netty.channel.ChannelId;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.ServerSocketChannel;
import io.netty.util.concurrent.ScheduledFuture;
import my.model.ChannelSupervise;
import my.model.auth;
import my.model.user;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

/**
 * 共享类的变量及清理
 */
public class staticCollection {
    //服务器Socket通道
    public static ServerSocketChannel serverChannel = null;
    //连接接收线程组
    public static final EventLoopGroup acceptGroup = new NioEventLoopGroup(100);
    //进站出站处理线程组
    public static final EventLoopGroup workerGroup = new NioEventLoopGroup(100);

    //绑定的端口
    public static int port = 9668;

    //临时存放语音
    public static Map<String, Map> voices = new HashMap<>();
    //离线语音存放 id->arr{obj}
    public static Map<String, List> leaveVoices = new HashMap<>();
    //是否接受请求
    public static boolean isAllowedReq = true;
    public static String url;
    public static String apkVersion;
    public static String resVersion;
    public static JSONArray noticeMsg;
    //缓存的资源文件
    public static Map<String, Map<String, Object>> assets = new HashMap<>();
    //资源索引
    public static List wlSourceList = new ArrayList();
    public static List xqSourceList = new ArrayList();
    //缓存基本的压缩包
    public static String appZip = null;
    public static byte[] nmbApk = null;

    //怪物战斗数据 将物攻等高级属性计算好之后缓存于此
    //public static Map<String, JSONObject> monsterMap = null;

    //登录后授权的ip列表，离线后需要移除 username-auth
    public static ConcurrentHashMap<String, auth> authMap = new ConcurrentHashMap<>();
    //验证码
    public static ConcurrentHashMap<String, JSONObject> codes = new ConcurrentHashMap<>();
    //玩家 设备号-user
    public static ConcurrentHashMap<String, user> userMap = new ConcurrentHashMap<>();
    //同ip同路径请求
    public static ConcurrentHashMap<String, Long> sameReqMap = new ConcurrentHashMap<>();
    //ip限制名单
    public static ConcurrentHashMap<String, JSONObject> ipMap = new ConcurrentHashMap<>();
    //队伍
    public static ConcurrentHashMap<String, JSONObject> teamMap = new ConcurrentHashMap<>();
    //某一个时段的聊天记录，每30s清理一次，当0清理时，消息将增加到1，0清理完毕1copy0，标志置位0
    public static Vector<JSONObject> chatList0 = new Vector<>();
    public static Vector<JSONObject> chatList1 = new Vector<>();
    public static int chatIndex = 0;

    //地图key+玩家[{name,lv,model}] 记录10s内的地图玩家
    public static Map<String, List<JSONObject>> posMap = new HashMap<>();


    //=========期货===========
    public static int investItem = 1;
    //大盘投资者
    public static LinkedBlockingQueue<JSONObject> dapanPlayer = new LinkedBlockingQueue<>();
    //大盘往期行情
    public static List<JSONObject> DapanHQ = new ArrayList<>();
    //期货投资者
    public static LinkedBlockingQueue<JSONObject> qihuoPlayer = new LinkedBlockingQueue<>();
    //期货往期行情
    public static List<JSONObject> qihuoHQ = new ArrayList<>();

    //宠物技能学习
    //竞技场报名 30 40 50 ...
    public static ConcurrentHashMap<String, JSONObject> jingjiMap = new ConcurrentHashMap<>();
    //王侯将相
    public static ConcurrentHashMap<String, JSONObject> whjxMap = new ConcurrentHashMap<>();
    //世界boss伤害统计
    public static Map<String, Integer> hurtMap = new ConcurrentHashMap<>();
    //练潜装备
    public static Map<String, String> potentialEquipMap = new ConcurrentHashMap<>();
    //武状元对战表
    public static Vector<JSONObject> fightList = new Vector<>();
    //宠物论贱
    public static Vector<JSONObject> fightLunjianList = new Vector<>();
    //正在上传的壁
    public static ConcurrentHashMap<String, JSONObject> bMap = new ConcurrentHashMap<>();
    //红包列表 id->obj
    public static ConcurrentHashMap<String, JSONObject> hongbaoList = new ConcurrentHashMap<>();
    //帮派红包 bpId->list 领取时要遍历
    public static ConcurrentHashMap<String, List<JSONObject>> bpHongbaoList = new ConcurrentHashMap<>();

    //跑商区域商品 区域-商品
    public static ConcurrentHashMap<String, JSONArray> psMap = new ConcurrentHashMap<>();

    //生成的帮战地图数据 帮派Id->
    public static ConcurrentHashMap<String, JSONObject> bzMap = new ConcurrentHashMap<>();


    //砍价队列
    public static ConcurrentLinkedQueue<JSONObject> cutPriceQue = new ConcurrentLinkedQueue<>();
    //砍价商品
    public static ConcurrentHashMap<String, JSONObject> cutPriceGoodsMap = new ConcurrentHashMap<>();
    //上架的商品
    public static ConcurrentHashMap<String, JSONArray> groundingGoodsMap = new ConcurrentHashMap<>();
    //正在竞拍中的商品，一个玩家一次只能竞拍一个商品
    public static ConcurrentHashMap<String, JSONArray> jingPaiGoodsMap = new ConcurrentHashMap<>();
    //抢购商品集
    public static ConcurrentHashMap<String, JSONObject> goodsMap = new ConcurrentHashMap<>();
    //抢购的玩家队列
    public static ConcurrentLinkedQueue<JSONObject> players = new ConcurrentLinkedQueue<>();
    //已经推送过的用户
    public static ConcurrentHashMap<String, Integer> pushUser = new ConcurrentHashMap<>();
    //抢购的开始时间
    public static long startQGTimes = 0;
    //排行榜数据
    //public static Map<String, List<JSONObject>> orderData = new ConcurrentHashMap<>();
    //需要重新计算的排行数据
    public static Map<String, Set<String>> orderDataNames = new ConcurrentHashMap<>();

    //等级排行
    /*public static List<JSONObject> lvList = new ArrayList<>();
    //土豪排行
    public static List<JSONObject> goldList = new ArrayList<>();
    public static List<JSONObject> taleList = new ArrayList<>();
    //侠义排行
    public static List<JSONObject> yingxiongList = new ArrayList<>();
    public static List<JSONObject> motouList = new ArrayList<>();
    //战力榜
    public static List<JSONObject> zhanLiList = new ArrayList<>();*/
    //离线消息
    public static LinkedBlockingQueue<JSONObject> leaveChatList = new LinkedBlockingQueue<>();
    //世界答题题目
    public static JSONObject worldAnswerQue = null;
    //答题的回答 name,answer
    public static Vector<JSONObject> worldAnswer = new Vector<>();
    //门派闯关排行奖励 {r1,r2} r1->奖励等级 1第一名奖励2第二名奖励3第三名 之后的就没有额外奖励
    public static Map<String, Integer> mpcgMap = new ConcurrentHashMap();
    //世界奖励消息
    public static LinkedBlockingQueue<JSONObject> rewardMsgList = new LinkedBlockingQueue<>();
    //魔神降临-魔神数据
    public static ConcurrentHashMap<String, JSONObject> msMap = new ConcurrentHashMap<>();
    //聚灵真火
    public static ConcurrentHashMap<String, JSONObject> julingMap = new ConcurrentHashMap<>();
    //人物状态栏启用
    public static ConcurrentHashMap<String, JSONObject> roleStatusMap = new ConcurrentHashMap<>();

    /**
     * 线程
     */
    public static void putTask(Runnable run) {
        putTask(run, null, null, null, 0);
    }

    /**
     * 延时
     */
    public static ScheduledFuture<?> putTask(Runnable run, long delay, TimeUnit timeUnit) {
        return putTask(run, null, delay, timeUnit, 1);
    }

    /**
     * 周期
     */
    public static ScheduledFuture<?> putTask(Runnable run, long initDelay, long period, TimeUnit timeUnit) {
        return putTask(run, initDelay, period, timeUnit, 2);
    }

    /**
     * 提交线程任务调度
     */
    private static ScheduledFuture<?> putTask(Runnable run, Long initDelay, Long period, TimeUnit timeUnit, int type) {
        if (type == 0) {
            //线程
            workerGroup.next().execute(run);
        } else if (type == 1) {
            //延时
            return workerGroup.next().schedule(run, period, timeUnit);
        } else if (type == 2) {
            //周期
            return workerGroup.next().scheduleAtFixedRate(run, initDelay, period, timeUnit);
        }
        return null;
    }

    /**
     * 是否为不允许偷袭的地图
     */
    public static boolean isNoSneakMap(String name) {
        String mapKey = getMapKey(name);
        if(mapKey!=null&&mapKey.contains("dmkj")) return false;
        if (mapKey == null || !strUtils.isMatch(mapKey, "m_[0-9]{1,}")) return true;
        String[] noMap = {"m_1",
                "m_6", "m_7", "m_8", "m_9",
                "m_19", "m_20", "m_21", "m_22",
                "m_35", "m_36", "m_37", "m_38",
                "m_56", "m_57", "m_58", "m_59",
                "m_90", "m_91", "m_92", "m_93",
        };
        for (String m : noMap) {
            if (m.equals(mapKey)) {
                return true;
            }
        }
        return false;
    }

    /**
     * 禁止pk的地图
     */
    public static boolean isNoPKMap(String name) {
        String mapKey = getMapKey(name);
        if (mapKey == null || !strUtils.isMatch(mapKey, "m_[0-9]{1,}")) return true;

        return false;
    }

    /**
     * 是否在某地图
     */
    public static boolean isInMap(String mapKey, String name) {
        user u = getUserByName(name);
        if (u != null && u.getPos() != null &&
                u.getPos().getString("map").equals(mapKey)) {
            return true;
        }
        return false;
    }

    public static String getMapKey(String name) {
        user u = getUserByName(name);
        if (u != null) {
            return u.getPos().getString("map");
        }
        return null;
    }

    public static String getIpByName(String name) {
        if (name == null) return null;
        user u = getUserByName(name);
        if (u == null) {
            return null;
        }
        return u.ip;
    }

    /**
     * 判断玩家通道是否活跃
     */
    public static boolean userIsOnline(String name) {
        user user = getUserByName(name);
        if (user != null && user.channelId != null) {
            Channel channel = ChannelSupervise.findChannel(user.channelId);
            if (channel != null && channel.isOpen() && channel.isActive()) {
                return true;
            }
        }
        return false;
    }

    /**
     * 由name获取user
     */
    public static user getUserByName(String name) {
        for (String sbh : userMap.keySet()) {
            user u = userMap.get(sbh);
            if (u.name.equals(name)) {
                return u;
            }
        }
        return null;
    }

    public static String getProjRootDirByName(String name) {
        user u = getUserByName(name);
        return u.projRootDir;
    }

    public static user getUserByChannelId(ChannelId channelId) {
        for (String sbh : userMap.keySet()) {
            user u = userMap.get(sbh);
            if (u.channelId != null && u.channelId.asShortText().equals(channelId.asShortText())) {
                return u;
            }
        }
        return null;
    }

    /**
     * 移除user
     */
    /*public static void removeUser(ChannelId channelId) {
        for (String sbh : userMap.keySet()) {
            user u = userMap.get(sbh);
            if (u.channelId != null && u.channelId.asShortText().equals(channelId.asShortText())) {
                userMap.remove(sbh);
                break;
            }
        }
    }*/

    /**
     * 放置user
     */
    public static void putUser(String sbh, user user) {
        //去掉之前登录过的
        user u = getUserByName(user.name);
        if (u != null) {
            u.offLine();
        }
        //放置新的user
        staticCollection.userMap.put(sbh, user);
    }

    /*public static Long copyLong(Object l) {
        if (l == null) return null;
        return new Long((Long) l);
    }

    public static Boolean copyBool(Object l) {
        if (l == null) return null;
        return new Boolean((Boolean) l);
    }*/

    public static JSONObject copyObj(Object obj) {
        return JSON.parseObject(JSON.toJSONString(obj));
    }

    public static <V> V copyObj(V obj, Class<?> c) {
        return (V) JSON.parseObject(JSON.toJSONString(obj), c);
    }

    public static JSONArray copyArr(Object arr) {
        return JSON.parseArray(JSON.toJSONString(arr));
    }

    public static <V> V copyArr(Object arr, Class<?> c) {
        return (V) JSON.parseArray(JSON.toJSONString(arr), c);
    }

    public static <V> V addEleToList(Object... o) {
        return (V) new ArrayList<>(Arrays.asList(o));
    }
}
