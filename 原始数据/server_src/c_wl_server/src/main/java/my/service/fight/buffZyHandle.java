package my.service.fight;

import com.alibaba.fastjson2.JSONObject;
import my.model.buff;

import java.util.Iterator;
import java.util.Vector;

import static my.fightUtils.fightUtils.buffMap;

/**增益、加伤、治疗效果等*/
public class buffZyHandle {
    private static buffZyHandle one;

    public static buffZyHandle getOne() {
        if (one == null) one = new buffZyHandle();
        return one;
    }
    public float getSufferCureZy(String id, String target){
        return getZy(id,target,"sufferCure");
    }
    /**
     * attrName:sufferCure
     * */
    private float getZy(String id, String target,String attrName) {
        float value = 0f;//外面有+1，所以这里是0
        Vector<buff> vs = buffMap.get(id);
        synchronized (vs) {
            Iterator<buff> its = vs.iterator();
            while (its.hasNext()) {
                buff b = its.next();
                if ((b.statusType == 1 || b.statusType == 2) && b.target.equals(target)) {
                    if (b.txRule.paramStr.equals(attrName)) {
                        value += b.txRule.getVal(b.lever,0);
                    }
                }
            }
        }
        return value;
    }
}
