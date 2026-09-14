package my.service.hds;

import com.alibaba.fastjson2.JSONArray;
import my.data.equipData;
import my.data.goodsData;
import my.db.mybatisConfig;
import my.gameUtils.rewardUtils;
import my.startBef;
import my.utils.strUtils;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.util.ArrayList;
import java.util.List;

/**
 * 物品使用效果
 */
public class useGoodsHandle {
    private static useGoodsHandle one;

    public static useGoodsHandle getOne() {
        if (one == null) one = new useGoodsHandle();
        return one;
    }

    public Object triggerUser(String key, int num, String name, DefaultSqlSession con) {
        if (num <= 0) {
            mybatisConfig.rollback(con);
            return null;
        }
        //这里在使用失败时需要进行回滚
        Object obj = null;
        boolean isExist = true;
        switch (key) {
            case "10000000": {//金票
                obj = startBef.manService.saveMoney(0, 1000L * num, name, con);
                if ((int) obj == 0) mybatisConfig.rollback(con);
                //测试生成一件
                //String equipKey = equipData.getEquipKey(3, 0, 0, 6, null);
                //obj = startBef.rewardService.createGoods(equipKey, 1, 0, name, con);
                break;
            }
            case "10000001": {//
                obj = startBef.manService.saveMoney(0, 500L * num, name, con);
                if ((int) obj == 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000002": {//
                obj = startBef.manService.saveMoney(0, 100L * num, name, con);
                if ((int) obj == 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000029": {//宠物低级口粮
                obj = startBef.petService.upLv(name, 1000 * num, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000030": {//宠物中级口粮
                obj = startBef.petService.upLv(name, 10000 * num, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000031": {//宠物高级口粮
                obj = startBef.petService.upLv(name, 50000 * num, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000032": {//宠物超级口粮
                obj = startBef.petService.upLv(name, 200000 * num, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000112": {//仙决宝箱
                obj = startBef.rewardService.openBoxXianJue(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000125": {//聚灵石
                obj = startBef.julingService.startJuLing(key, name, con);
                if ((int) obj <= 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000126": {//天元精髓
                obj = startBef.julingService.startJuLing(key, name, con);
                if ((int) obj <= 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000133": {//魔龙召唤令
                obj = startBef.petService.createPet("1221", 4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000134": {//玄姬召唤令
                obj = startBef.petService.createPet("1222", 4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000135": {//小青召唤令
                obj = startBef.petService.createPet("1223", 4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000136": {//玄女召唤令
                obj = startBef.petService.createPet("1224", 4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000137": {//天兵召唤令
                obj = startBef.petService.createPet("1225", 4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000138": {//帝君召唤令
                obj = startBef.petService.createPet("1226", 4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000139": {//青童召唤令
                obj = startBef.petService.createPet("1227", 4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000140": {//中级宠物蛋（太虚、青玄、魔俑）
                String keys[] = {"1217", "1219", "1228",};
                obj = startBef.petService.createPet(keys[strUtils.getRandom(0, keys.length)], 3, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000141": {//高级宠物蛋(梦瑶、剑圣、落羽)
                String keys[] = {"1215", "1216", "1218",};
                obj = startBef.petService.createPet(keys[strUtils.getRandom(0, keys.length)], 3, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000142": {//天狐召唤令
                obj = startBef.petService.createPet("1220", 4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000175": {//汇通金券
                obj = startBef.rewardService.exchangeTale(10000 * num, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000176": {//汇通银券
                obj = startBef.rewardService.exchangeTale(1000 * num, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000177": {//人物造化丹
                obj = startBef.manService.userStatusLan("rwzhd", name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000178": {//宠物造化丹
                obj = startBef.manService.userStatusLan("cwzhd", name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000181": {//化婴玉
                obj = startBef.julingService.startJuLing(key, name, con);
                if ((int) obj <= 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000182": {//炼神珠
                obj = startBef.julingService.startJuLing(key, name, con);
                if ((int) obj <= 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000183": {//驱敌香草
                obj = startBef.manService.userStatusLan("qdxc", name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000184": {//诱敌香草
                obj = startBef.manService.userStatusLan("ydxc", name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000187": {//扬善令牌
                obj = startBef.prisonService.useYangShan(name, con);
                if ((int) obj <= 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000189": {//福神的礼袋
                obj = startBef.rewardService.exchangeFuShenLiDai(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000201": {//美人香
                obj = startBef.rewardService.openMeiRenXiang(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000208": {//百里香
                obj = startBef.manService.userStatusLan("blx", name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000209": {//聚魔铃
                obj = startBef.manService.userStatusLan("jml", name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000210": {//双倍潜力
                obj = startBef.manService.userStatusLan("dblq", name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000213": {//天元丹
                obj = startBef.jmService.userDan(key, name, con);
                if ((int) obj <= 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000214": {//天元丹
                obj = startBef.jmService.userDan(key, name, con);
                if ((int) obj <= 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000215": {//天元丹
                obj = startBef.jmService.userDan(key, name, con);
                if ((int) obj <= 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000216": {//天元丹
                obj = startBef.jmService.userDan(key, name, con);
                if ((int) obj <= 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000217": {//天元丹
                obj = startBef.jmService.userDan(key, name, con);
                if ((int) obj <= 0) mybatisConfig.rollback(con);
                break;
            }
            case "10000220": {//银票
                obj = startBef.rewardService.useYinPiao(num * 1000, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000233": {//封妖石（打开后可获得赤翼蝠）
                obj = startBef.petService.createPet("1000", 4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000237": {//暴击仙丹礼包
                obj = startBef.rewardService.openXianDanLiBao(key, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000238": {//仙丹礼包
                obj = startBef.rewardService.openXianDanLiBao(key, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000239": {//仙丹礼包
                obj = startBef.rewardService.openXianDanLiBao(key, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000240": {//仙丹礼包
                obj = startBef.rewardService.openXianDanLiBao(key, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000241": {//仙丹礼包
                obj = startBef.rewardService.openXianDanLiBao(key, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000242": {//仙丹礼包
                obj = startBef.rewardService.openXianDanLiBao(key, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000243": {//仙丹礼包
                obj = startBef.rewardService.openXianDanLiBao(key, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000244": {//仙丹礼包
                obj = startBef.rewardService.openXianDanLiBao(key, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000245": {//仙丹礼包
                obj = startBef.rewardService.openXianDanLiBao(key, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000246": {//仙丹礼包
                obj = startBef.rewardService.openXianDanLiBao(key, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000257": {//梅老板礼包
                obj = startBef.rewardService.openMeiLaoBanGift(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000258": {//鬼见愁礼包
                obj = startBef.rewardService.openGuiJianChouGift(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000259": {//储钱罐
                obj = startBef.rewardService.openChuQianGuan(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000260": {//宠物神技礼包
                obj = startBef.rewardService.openSkillGift(0, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000261": {//宠物高级技能礼包
                obj = startBef.rewardService.openSkillGift(1, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000262": {//宠物普通技能礼包
                obj = startBef.rewardService.openSkillGift(2, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000263": {//百变种子
                obj = startBef.rewardService.rdGjZhongzi(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000264": {//锻造礼包
                obj = startBef.rewardService.getDuanZaoGift(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000265": {//魔龙礼包
                obj = startBef.rewardService.getMoLongGift(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000267": {//黑铁宝箱
                obj = startBef.rewardService.getLeiJiGift(0, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000268": {//青铜宝箱
                obj = startBef.rewardService.getLeiJiGift(1, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000269": {//白银宝箱
                obj = startBef.rewardService.getLeiJiGift(2, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000270": {//黄金宝箱
                obj = startBef.rewardService.getLeiJiGift(3, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000271": {//钻石宝箱
                obj = startBef.rewardService.getLeiJiGift(4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000272": {//v1礼包
                obj = startBef.rewardService.getVipGift(1, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000273": {//v2礼包
                obj = startBef.rewardService.getVipGift(2, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000274": {//v3礼包
                obj = startBef.rewardService.getVipGift(3, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000275": {//v4礼包
                obj = startBef.rewardService.getVipGift(4, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000276": {//v5礼包
                obj = startBef.rewardService.getVipGift(5, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000277": {//v6礼包
                obj = startBef.rewardService.getVipGift(6, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000278": {//v7礼包
                obj = startBef.rewardService.getVipGift(7, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000279": {//v8礼包
                obj = startBef.rewardService.getVipGift(8, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000280": {//v9礼包
                obj = startBef.rewardService.getVipGift(9, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000281": {//v10礼包
                obj = startBef.rewardService.getVipGift(10, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000282": {//人物技能箱
                obj = startBef.rewardService.openPetOrManSkillBox(0, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000283": {//宠物物技能箱
                obj = startBef.rewardService.openPetOrManSkillBox(1, name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000285": {//修复礼包
                obj = startBef.rewardService.openXiuFuGift(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000286": {//供香礼包
                obj = startBef.rewardService.openGongXiangGift(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000288": {//强装礼包
                obj = startBef.rewardService.openQiangZhuangGift(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000292": {//天地仙决箱
                obj = startBef.rewardService.openTianDiSkillBox(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000294": {//嘎嘎香礼包
                obj = startBef.rewardService.openGaGaXiangBox(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            case "10000302": {//小黄毛礼包
                obj = startBef.rewardService.openXiaoHuangMaoBox(name, con);
                if (obj == null) mybatisConfig.rollback(con);
                break;
            }
            default: {
                isExist = false;
            }
        }
        if (strUtils.isMatch(key, "1012([0-9]{4})")) {
            isExist = true;
            //匹配王者遗产-藏宝图
            obj = startBef.wzycService.userCangBaoTu(key, name, con);
            if (obj == null) mybatisConfig.rollback(con);
        }
        /*if (strUtils.isMatch(key, "1124([0-9]{4})")) {
            //匹配称号
            int i = Integer.parseInt(key.substring(4)) + 1;
            obj = startBef.manService.addTitle("a" + i, name, con);
            if ((int) obj == 0) mybatisConfig.rollback(con);
        }*/
        if (!isExist) {//不存在key时回滚
            mybatisConfig.rollback(con);
            return null;
        }
        //插入操作日志
        boolean b = strUtils.canParseInt(obj + "");
        if ((obj != null && !b) || (b && (int) obj == 1)) {
            startBef.logService.insertOp("1", name, "使用道具" + key + " x" + num, null, "1");
        }
        return obj;
    }

}
