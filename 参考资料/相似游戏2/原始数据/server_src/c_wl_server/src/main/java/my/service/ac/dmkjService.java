package my.service.ac;

import com.alibaba.fastjson2.JSONObject;
import my.anno.paramsAnno;
import my.model.result;
import my.model.user;
import my.startBef;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

/**盗梦空间相关兑换*/
public class dmkjService {

    /**用梦幻水晶兑换*/
    public result exchangeByShuiJing(JSONObject jb,
                                 @paramsAnno(key = "user") user user,
                                 @paramsAnno(key = "con") DefaultSqlSession con) {
        final String name = user.name;
        int type=jb.getInteger("type");
        int xhNum=1;
        int num=1;
        String key=null;
        if(type==0){//180梦幻水晶兑换潜力符石x1
            xhNum=180;num=1;key="10000114";
        }else if(type==1){//200梦幻水晶兑换造化丹x2
            xhNum=200;num=2;key="10000177";
        }else if(type==2){//300梦幻水晶兑换诱敌香草x3
            xhNum=300;num=3;key="10000184";
        }else if(type==3){//500梦幻水晶兑换无敌药囊x1
            xhNum=500;num=1;key="100110060003";
        }else return new result(0);
        if(startBef.packageService.cutPlayerGoodsNumByKey("10000199",xhNum,name,con)!=1){
            return new result(0);
        }

        return new result(200,startBef.rewardService.createGoods(key,num,1,name,con));
    }
}
