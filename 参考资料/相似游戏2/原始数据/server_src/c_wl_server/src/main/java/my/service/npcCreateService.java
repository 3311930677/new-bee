package my.service;

import my.data.mapData;
import my.startBef;
import my.utils.strUtils;

import java.util.concurrent.ConcurrentHashMap;

/**
 * 生成活动需要的npc
 */
public class npcCreateService {
    //主城key->npc数量
    private static ConcurrentHashMap<String, Integer> nianshouMap = new ConcurrentHashMap<>();

    /**
     * 生成年兽npc
     */
    public void createNianshouNpc() {
        if (!startBef.activityService.isOpen("nsjl")
                || !strUtils.isWholeTime()) {
            return;
        }
        //刷新主城区
        if (nianshouMap == null) {
            nianshouMap = new ConcurrentHashMap<>();
        }
        nianshouMap.clear();
        //五个主城区 4*5=20  所有城区总数40个
        int sum = 40;
        String[] arr = mapData.getMainCityKeys();
        for (int i = 0; i < arr.length; i++) {
            int n = strUtils.getRandom(1, 4);
            if (sum <= 0) {
                n = 0;
            }
            sum -= n;
            nianshouMap.put(arr[i], n);
        }
        //通知月饼已经刷新
        startBef.chatService.putSysMsg("年兽降临主城，挑战成功将获得新年小礼物");
    }

    public Integer getOneByMapKey(String key) {
        if (nianshouMap == null||nianshouMap.get(key)==null) return 0;
        return nianshouMap.get(key);
    }

    /**
     * 减少某个主城的月饼数量
     */
    public boolean cutOneByMapKey(String key) {
        synchronized (nianshouMap){
            int n = nianshouMap.get(key);
            if (n <= 0) {
                return false;
            }
            n--;
            nianshouMap.put(key, n);
        }
        return true;
    }

}
