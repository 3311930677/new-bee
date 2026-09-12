package my.dao;

import com.alibaba.fastjson2.JSONObject;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface jsonMapper {
    List<JSONObject> countMoneyCountSum(@Param("type") int type);
    List<JSONObject> selectMoneyCountGoldByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);
    List<JSONObject> selectMoneyCountTaleByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);
    List<JSONObject> selectMoneyCount(@Param("name") String name);
    boolean addMoneyCount(@Param("name") String name,
                          @Param("old_gold") String old_gold,
                          @Param("now_gold") String now_gold,
                          @Param("old_tale") String old_tale,
                          @Param("now_tale") String now_tale);
    boolean updateMoneyCount(@Param("name") String name,
                             @Param("old_gold") String old_gold,
                             @Param("now_gold") String now_gold,
                             @Param("old_tale") String old_tale,
                             @Param("now_tale") String now_tale);
    boolean delMoneyCount(@Param("name") String name);



    List<JSONObject> selectPetEquipView(@Param("name") String name);
    List<JSONObject> selectPetEquip(@Param("name") String name);

    boolean addPetEquip(@Param("name") String name,
                        @Param("equip") String equip);

    boolean updatePetEquip(@Param("name") String name,
                           @Param("equip") String equip);

    boolean delPetEquip(@Param("name") String name);


    List<JSONObject> selectShiFaWayView(@Param("name") String name);

    List<JSONObject> selectShiFaWay(@Param("name") String name);

    boolean addShiFaWay(@Param("name") String name,
                        @Param("way") String way,
                        @Param("role_skls") String role_skls,
                        @Param("pet_skls") String pet_skls);

    boolean updateShiFaWay(@Param("name") String name,
                           @Param("way") String way,
                           @Param("role_skls") String role_skls,
                           @Param("pet_skls") String pet_skls);

    boolean delShiFaWay(@Param("name") String name);


    List<JSONObject> getPlayerMsgByNames(@Param("names") List names);

    List<JSONObject> selectDzfsbLogByName(@Param("name") String name);

    boolean addDzfsbLog(@Param("name") String name,
                        @Param("log") String log);

    boolean updateDzfsbLog(@Param("name") String name,
                           @Param("log") String log,
                           @Param("times") String times);

    boolean clearDzfsbLog();

    boolean delDzfsbLog();


    List<JSONObject> selectDzfsbOrderSum();

    List<JSONObject> selectDzfsbOrderByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> selectDzfsbOrderByName(@Param("name") String name);

    List<JSONObject> selectDzfsbOrderBySort(@Param("sort") String sort);

    boolean addDzfsbOrder(@Param("name") String name,
                          @Param("lever") String lever,
                          @Param("model") String model,
                          @Param("sort") String sort);

    boolean updateDzfsbOrder(@Param("name") String name,
                             @Param("lever") String lever,
                             @Param("sort") String sort);

    boolean delDzfsbOrder();

    List<JSONObject> selectLvOrderSezShanSum();

    List<JSONObject> selectLvOrderSezShan();

    List<JSONObject> selectLvOrderSezShanByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addLvOrderSezShan(@Param("name") String name, @Param("lever") String lever, @Param("model") String model, @Param("sez") String sez, @Param("sort") String sort);

    boolean delLvOrderSezShan();

    boolean delLvOrderSezShanByName(@Param("name") String name);

    List<JSONObject> selectLvOrderSezEByName(@Param("name") String name);

    List<JSONObject> selectLvOrderSezEBySez();

    List<JSONObject> selectLvOrderSezESum();

    List<JSONObject> selectLvOrderSezE();

    List<JSONObject> selectLvOrderSezEByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addLvOrderSezE(@Param("name") String name, @Param("lever") String lever, @Param("model") String model, @Param("sez") String sez, @Param("sort") String sort);

    boolean delLvOrderSezE();

    boolean delLvOrderSezEByName(@Param("name") String name);

    List<JSONObject> selectLvOrderMsSum();

    List<JSONObject> selectLvOrderMs();

    List<JSONObject> selectLvOrderMsByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addLvOrderMs(@Param("name") String name, @Param("lever") String lever, @Param("model") String model, @Param("sort") String sort);

    boolean delLvOrderMs();

    List<JSONObject> selectLvOrderDjSum();

    List<JSONObject> selectLvOrderDj();

    List<JSONObject> selectLvOrderDjByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addLvOrderDj(@Param("name") String name, @Param("lever") String lever, @Param("model") String model, @Param("sort") String sort);

    boolean delLvOrderDj();

    List<JSONObject> selectLvOrderQmSum();

    List<JSONObject> selectLvOrderQm();

    List<JSONObject> selectLvOrderQmByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addLvOrderQm(@Param("name") String name, @Param("lever") String lever, @Param("model") String model, @Param("sort") String sort);

    boolean delLvOrderQm();

    List<JSONObject> selectLvOrderTySum();

    List<JSONObject> selectLvOrderTy();

    List<JSONObject> selectLvOrderTyByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addLvOrderTy(@Param("name") String name, @Param("lever") String lever, @Param("model") String model, @Param("sort") String sort);

    boolean delLvOrderTy();

    List<JSONObject> selectLvOrderYmSum();

    List<JSONObject> selectLvOrderYm();

    List<JSONObject> selectLvOrderYmByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addLvOrderYm(@Param("name") String name, @Param("lever") String lever, @Param("model") String model, @Param("sort") String sort);

    boolean delLvOrderYm();

    List<JSONObject> selectLvOrderLcSum();

    List<JSONObject> selectLvOrderLc();

    List<JSONObject> selectLvOrderLcByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addLvOrderLc(@Param("name") String name, @Param("lever") String lever, @Param("model") String model, @Param("sort") String sort);

    boolean delLvOrderLc();

    List<JSONObject> selectLvOrderSum();

    List<JSONObject> selectLvOrder();

    List<JSONObject> selectLvOrderByName(@Param("name") String name);

    List<JSONObject> selectLvOrderByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addLvOrder(@Param("name") String name, @Param("lever") String lever, @Param("model") String model, @Param("sort") String sort);

    boolean delLvOrder();

    List<JSONObject> selectZlOrderSum();

    List<JSONObject> selectZlOrder();

    List<JSONObject> selectZlOrderByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addZlOrder(@Param("name") String name, @Param("zl") String zl, @Param("sort") String sort);

    boolean delZlOrder();


    List<JSONObject> selectFormation(@Param("name") String name);

    boolean updateFormation(@Param("name") String name, @Param("formation") String formation);

    boolean insertFormation(@Param("name") String name, @Param("formation") String formation);

    boolean delFormation(@Param("name") String name);


    List<JSONObject> selectHuobanByName(@Param("name") String name);

    List<JSONObject> selectHuobanByNameNoForUpdate(@Param("name") String name);

    boolean updateHuobanByName(@Param("name") String name, @Param("huoban") String huoban);

    boolean insertHuoban(@Param("name") String name, @Param("huoban") String huoban);

    boolean delHuobanByName(@Param("name") String name);

    List<JSONObject> selectManStar(@Param("name") String name);

    boolean updateManStar(@Param("name") String name, @Param("star") String star);

    boolean addManStar(@Param("name") String name, @Param("star") String star);

    boolean delManStar();

    List<JSONObject> selectYhmk(@Param("name") String name);

    boolean updateYhmk(@Param("name") String name,
                       @Param("gain") String gain,
                       @Param("qiaoda") String qiaoda,
                       @Param("lv1") String lv1,
                       @Param("lv2") String lv2,
                       @Param("lv3") String lv3,
                       @Param("lv4") String lv4,
                       @Param("lv5") String lv5,
                       @Param("lv6") String lv6,
                       @Param("lv7") String lv7,
                       @Param("myd1") String myd1,
                       @Param("myd2") String myd2,
                       @Param("myd3") String myd3,
                       @Param("myd4") String myd4,
                       @Param("myd5") String myd5,
                       @Param("myd6") String myd6,
                       @Param("myd7") String myd7);

    boolean addYhmk(@Param("name") String name);

    boolean delYhmk();

    boolean clearYhmkTimes();

    List<JSONObject> selectVip(@Param("name") String name);

    boolean updateVip(@Param("name") String name, @Param("jf") String jf);

    boolean addVip(@Param("name") String name);

    boolean delVip();

    List<JSONObject> selectPublicTaskPlayer(@Param("name") String name);

    boolean updatePublicTaskPlayer(@Param("name") String name, @Param("jf") String jf,
                                   @Param("rewards") String rewards);

    boolean addPublicTaskPlayer(@Param("name") String name);

    boolean delPublicTaskPlayer();

    List<JSONObject> selectPublicTaskByOverTime(@Param("overTime") Long overTime);

    List<JSONObject> selectPublicTaskByGainner(@Param("gainner") String gainner);

    List<JSONObject> selectPublicTaskSum();

    List<JSONObject> selectPublicTaskByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> selectPublicTask(@Param("Id") String Id);

    boolean updatePublicTask(@Param("Id") String Id, @Param("gainner") String gainner,
                             @Param("startTime") String startTime, @Param("endTime") String endTime,
                             @Param("status") String status, @Param("k") String k, @Param("num") String num);

    boolean addPublicTask(@Param("Id") String Id, @Param("gainner") String gainner,
                          @Param("startTime") String startTime, @Param("endTime") String endTime,
                          @Param("status") String status, @Param("k") String k, @Param("num") String num);

    boolean delPublicTask();

    boolean delPublicTaskById(@Param("Id") String Id);

    boolean delPublicTaskByIds(@Param("ids") List ids);


    //坐骑
    List<JSONObject> getZuoqi(String name);

    boolean updateZuoqi(@Param("name") String name, @Param("zuoqi") String zuoqi);

    boolean addZuoqi(@Param("name") String name);

    boolean delZuoqi(@Param("name") String name);

    //翅膀
    List<JSONObject> getWings(String name);

    boolean updateWings(@Param("name") String name, @Param("wings") String wings);

    boolean addWings(@Param("name") String name);

    boolean delWings(@Param("name") String name);

    List<JSONObject> getTitle(String name);

    boolean updateTitle(@Param("name") String name, @Param("titles") String titles);

    boolean addTitle(@Param("name") String name);

    boolean delTitle(@Param("name") String name);


    List<JSONObject> getPlayerMsg(String name);

    List<JSONObject> getPlayerMsgView(String name);

    List<JSONObject> selectAllAttr(String name);

    List<JSONObject> selectAttr(String name);

    boolean updateSkillByName(@Param("skill") String skill, @Param("name") String name);

    List<JSONObject> selectSkill(String name);

    List<JSONObject> selectMsg(String name);

    boolean updatePropByName(@Param("prop") String prop, @Param("name") String name);

    List<JSONObject> selectProp(String name);

    boolean updateStatusByName(@Param("status") String status, @Param("name") String name);

    List<JSONObject> selectStatusByName(String name);

    List<JSONObject> selectPetByName(String name);

    List<JSONObject> selectPetByNameNoForUpdate(String name);

    List<JSONObject> selectAllEmailBack();

    boolean addEmailBack(@Param("Id") String Id, @Param("email_id") String email_id, @Param("email_receiver") String email_receiver);

    boolean delAllEmailBack();

    boolean delAllEmailBackByRecAndId(@Param("email_id") String email_id, @Param("email_receiver") String email_receiver);

    boolean insertEmail(@Param("email") String email, @Param("name") String name);

    boolean insertPet(@Param("pet") String pet, @Param("name") String name);

    boolean insertTask(@Param("task") String task, @Param("name") String name);

    boolean insertTaskSubmit(@Param("list") String list, @Param("name") String name);

    boolean insertPackage(@Param("pack") String pack, @Param("bbn") String bbn,
                          @Param("ckn") String ckn,
                          @Param("name") String name);

    boolean insertStatus(@Param("status") String status, @Param("name") String name);

    boolean insertSkill(@Param("skill") String skill, @Param("name") String name);

    boolean insertEquip(@Param("equip") String equip, @Param("name") String name);

    boolean insertMsg(@Param("msg") String msg, @Param("name") String name);

    boolean insertProp(@Param("prop") String prop, @Param("name") String name);

    List<JSONObject> getWzySignOrderByJf(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> countWzySign();

    List<JSONObject> selectWzySignLimit(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean updateWzySignJFAndPromotion(@Param("jf") String jf, @Param("promotion") String promotion, @Param("teamName") String teamName);

    boolean updateWzySign(@Param("jf") String jf, @Param("teamName") String teamName);

    boolean insertWzySign(@Param("teamName") String teamName, @Param("mList") String mList);

    List<JSONObject> selectAllWzySign();

    List<JSONObject> selectPackageBC(String name);

    List<JSONObject> selectPackageTale(String name);

    List<JSONObject> selectPackage(String name);
    List<JSONObject> countPackageNum();
    List<JSONObject> selectPackageViewByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);
    List<JSONObject> selectPackageView(String name);

    boolean updateEquip(@Param("equip") String equip, @Param("name") String name);

    List<JSONObject> selectEquip(String name);

    List<JSONObject> selectEquipView(String name);

    List<JSONObject> selectEquipByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);


    boolean updateEmail(@Param("email") String email, @Param("name") String name);

    List<JSONObject> selectEmail(String name);

    List<JSONObject> selectWzySignByName(String name);

    List<JSONObject> selectWzySignByPromotion(String promotion);

    boolean delWzySign();

    boolean clearEmail();


    boolean updateHappyAnswer();

    boolean delHappyAnswer();

    boolean delChumo();

    boolean delZhuanpan();

    List<JSONObject> selectAllTaskSubmit(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getTaskCount();

    List<JSONObject> selectAllTask(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean updateTaskSubmitByName(@Param("list") String list, @Param("name") String name);

    List<JSONObject> selectTaskSubmitByName(String name);

    boolean updateTaskByName(@Param("task") String task, @Param("name") String name);

    List<JSONObject> selectTaskByName(String name);

    boolean updatePetByName(@Param("pet") String pet, @Param("name") String name);

    List<JSONObject> selectPetLimit(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean updateMsgByName(@Param("msg") String msg, @Param("name") String name);

    List<JSONObject> selectMsgLimit(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean updatePackageByName(@Param("pack") String pack,
                                @Param("bbn") String bbn,
                                @Param("ckn") String ckn,
                                @Param("tale") String tale,
                                @Param("name") String name);

    boolean delEmail(String name);

    boolean delEquip(String name);

    boolean delMsg(String name);

    boolean delPackage(String name);

    List<JSONObject> selectPackageLimit(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean delPet(String name);

    boolean delProp(String name);

    boolean delSkill(String name);

    boolean delStatus(String name);

    boolean delTask(String name);

    boolean delTaskSubmit(String name);

    List<JSONObject> selectZhuanpanNum(String name);

    boolean insertZhuanpan(@Param("name") String name, @Param("num") String num);

    boolean updateZhuanpan(@Param("name") String name, @Param("num") String num);

    List<JSONObject> selectHappyAnswer(String name);

    boolean insertHappyAnswer(@Param("name") String name, @Param("num") String num, @Param("right") String right);

    boolean updateHappyAnswer(@Param("name") String name, @Param("num") String num, @Param("right") String right);

    List<JSONObject> selectZMAnswer(String name);

    boolean insertZMAnswer(@Param("name") String name, @Param("ans") String ans);

    boolean updateZMAnswer(@Param("name") String name, @Param("num") String num, @Param("right") String right,
                           @Param("progress") String progress);

    boolean delZMAnswerByName(@Param("name") String name);

    boolean delZMAnswer();


}
