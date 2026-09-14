package my.dao;

import com.alibaba.fastjson2.JSONObject;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface activityMapper {
    List<JSONObject> getXxzdSum();
    List<JSONObject> getAllXxzd();

    List<JSONObject> getXxzdByPage(@Param("pageNum") Long pageNum,
                                   @Param("pageSum") Long pageSum);

    List<JSONObject> getXxzd(@Param("name") String name);

    boolean addXxzd(@Param("name") String name);

    boolean updateXxzd(@Param("name") String name,
                       @Param("jf") String jf);

    boolean remXxzd();


    List<JSONObject> getInvestLog(@Param("pageNum") Long pageNum,
                                  @Param("pageSum") Long pageSum);

    boolean addInvestLog(@Param("Id") String Id,
                         @Param("item") String item,
                         @Param("type") String type,
                         @Param("addGoldSum") String addGoldSum,
                         @Param("cutGoldSum") String cutGoldSum,
                         @Param("created") String created);


    List<JSONObject> getQdGainShenView(@Param("name") String name);

    List<JSONObject> getQdGainShen(@Param("name") String name);

    boolean addQdGainShen(@Param("name") String name);

    boolean clearQdGainShenYb();

    boolean updateQdGainShen(@Param("name") String name,
                             @Param("shen_jf") String shen_jf,
                             @Param("gain_shen") String gain_shen,
                             @Param("tong_jf") String tong_jf,
                             @Param("gain_tong") String gain_tong,
                             @Param("gain_yuanbao") String gain_yuanbao,
                             @Param("is_shen_gd") String is_shen_gd,
                             @Param("is_tong_gd") String is_tong_gd);

    boolean remQdGainShen(@Param("name") String name);


    List<JSONObject> getShenFuOverTime(@Param("now") String now);

    List<JSONObject> getShenFuView(@Param("name") String name);

    List<JSONObject> getShenFu(@Param("name") String name);

    boolean addShenFu(@Param("name") String name,
                      @Param("sf_key") String sf_key,
                      @Param("end") String end);

    boolean updateShenFu(@Param("name") String name,
                         @Param("sf_key") String sf_key,
                         @Param("end") String end);

    boolean remShenFu(@Param("name") String name);

    boolean remShenFuByNames(@Param("names") List names);

    List<JSONObject> getLjdXianJue(@Param("name") String name);

    boolean addLjdXianJue(@Param("name") String name);

    boolean updateLjdXianJue(@Param("name") String name,
                             @Param("old_jf") String old_jf,
                             @Param("jf") String jf);

    boolean remLjdXianJue(@Param("name") String name);

    List<JSONObject> getLjdGold(@Param("name") String name);

    boolean addLjdGold(@Param("name") String name);

    boolean updateLjdGold(@Param("name") String name,
                          @Param("old_jf") String old_jf,
                          @Param("jf") String jf);

    boolean remLjdGold(@Param("name") String name);

    List<JSONObject> getHolidayGift(@Param("name") String name);

    boolean addHolidayGift(@Param("name") String name);

    boolean updateHolidayGift(@Param("name") String name, @Param("g0") String g0);

    boolean remHolidayGift(@Param("name") String name);

    List<JSONObject> getLeiJiDang(@Param("name") String name);

    boolean addLeiJiDang(@Param("name") String name);

    boolean updateLeiJiDang(@Param("name") String name, @Param("jf") String jf);

    boolean remLeiJiDang(@Param("name") String name);

    List<JSONObject> getVipGift(@Param("name") String name);

    boolean addVipGift(@Param("name") String name);

    boolean updateVipGift(@Param("name") String name, @Param("g1") String g1,
                          @Param("g2") String g2, @Param("g3") String g3,
                          @Param("g4") String g4, @Param("g5") String g5,
                          @Param("g6") String g6, @Param("g7") String g7,
                          @Param("g8") String g8, @Param("g9") String g9,
                          @Param("g10") String g10);

    boolean remVipGiftByName(@Param("name") String name);


    List<JSONObject> getJiMaiIdsByCreated(@Param("t") Long t,
                                          @Param("endDay") String endDay);

    List<JSONObject> getJiMaiViewByPage(@Param("type") String type,
                                        @Param("kword") String kword,
                                        @Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getNumByName(@Param("name") String name);

    List<JSONObject> countNumByPage(@Param("type") String type,
                                    @Param("kword") String kword);

    List<JSONObject> getJiMaiViewByName(@Param("name") String name);

    List<JSONObject> getJiMai(@Param("Id") String Id);

    boolean addJiMai(@Param("Id") String Id, @Param("price") String price,
                     @Param("priceType") String priceType, @Param("num") String num,
                     @Param("gdType") String gdType, @Param("name") String name,
                     @Param("gd") String gd, @Param("type") String type,
                     @Param("kword") String kword,
                     @Param("created") String created, @Param("endDay") String endDay,
                     @Param("bzj") String bzj);

    boolean updateJiMai(@Param("Id") String Id, @Param("num") String num);

    boolean remJiMaiById(@Param("Id") String Id);

    boolean remJiMaiByIds(@Param("ids") List ids);

    List<JSONObject> getOpenServerBuyGift(@Param("name") String name);

    boolean addOpenServerBuyGift(@Param("name") String name);

    boolean updateOpenServerBuyGift(@Param("name") String name,
                                    @Param("g0") String g0,
                                    @Param("g1") String g1);

    List<JSONObject> getOpenServerQianDaoGift(@Param("name") String name);

    boolean addOpenServerQianDaoGift(@Param("name") String name);

    boolean updateOpenServerQianDaoGift(@Param("name") String name,
                                        @Param("gain") String gain,
                                        @Param("day_sum") String day_sum);

    boolean clearOpenServerQianDaoGift();

    List<JSONObject> getOpenServerLvGift(@Param("name") String name);

    boolean addOpenServerLvGift(@Param("name") String name);

    boolean updateOpenServerLvGift(@Param("name") String name,
                                   @Param("g0") String g0,
                                   @Param("g1") String g1,
                                   @Param("g2") String g2,
                                   @Param("g3") String g3,
                                   @Param("g4") String g4,
                                   @Param("g5") String g5,
                                   @Param("g6") String g6,
                                   @Param("g7") String g7);

    List<JSONObject> getCbBpOrderByJf(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getCbBpOrder(@Param("bpId") String bpId);

    boolean addCbBpOrder(@Param("bpId") String bpId);

    boolean updateCbBpOrder(@Param("bpId") String bpId,
                            @Param("jf") String jf);

    boolean clearCbBpOrder();

    List<JSONObject> getCbOrderByZongJf(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getCbOrderByJf1(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getCbOrderByJf2(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getCbOrderByJf3(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getCbOrderByJf4(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getCbOrder(@Param("name") String name);

    boolean addCbOrder(@Param("name") String name);

    boolean updateCbOrder(@Param("name") String name,
                          @Param("jf1") String jf1,
                          @Param("jf2") String jf2,
                          @Param("jf3") String jf3,
                          @Param("jf4") String jf4);

    boolean clearCbOrder();

    List<JSONObject> getTongji(@Param("name") String name);

    boolean addTongji(@Param("name") String name,
                      @Param("tj_name") String tj_name,
                      @Param("created") String created);

    boolean updateTongji(@Param("name") String name,
                         @Param("tj_name") String tj_name,
                         @Param("created") String created);

    boolean remTongji(@Param("name") String name);

    List<JSONObject> getFarmView(@Param("name") String name);

    List<JSONObject> getFarm(@Param("name") String name);

    boolean addFarm(@Param("name") String name,
                    @Param("td") String td,
                    @Param("times") String times);

    boolean updateFarm(@Param("name") String name,
                       @Param("td") String td,
                       @Param("times") String times,
                       @Param("gain") String gain);

    boolean clearFarm();

    boolean remFarm(@Param("name") String name);

    List<JSONObject> getHHBK(@Param("name") String name);

    boolean addHHBK(@Param("name") String name,
                    @Param("search_res") String search_res,
                    @Param("yaoshi_num") String yaoshi_num,
                    @Param("sheng_pos") String sheng_pos,
                    @Param("si_mon_num") String si_mon_num,
                    @Param("open_box2") String open_box2,
                    @Param("open_box3") String open_box3,
                    @Param("created") String created);

    boolean updateHHBK(@Param("name") String name,
                       @Param("search_res") String search_res,
                       @Param("yaoshi_num") String yaoshi_num,
                       @Param("sheng_pos") String sheng_pos,
                       @Param("si_mon_num") String si_mon_num,
                       @Param("open_box2") String open_box2,
                       @Param("open_box3") String open_box3,
                       @Param("created") String created);

    boolean remHHBK(@Param("name") String name);

    List<JSONObject> getZJCM(@Param("name") String name);

    boolean addZJCM(@Param("name") String name,
                    @Param("map_key") String map_key);

    boolean updateZJCM(@Param("name") String name,
                       @Param("times") String times,
                       @Param("map_key") String map_key);

    boolean clearZJCM();

    List<JSONObject> getWzyc(@Param("name") String name);

    boolean addWzyc(@Param("name") String name);

    boolean updateWzyc(@Param("name") String name,
                       @Param("gain_times") String gain_times,
                       @Param("sx_times") String sx_times,
                       @Param("free_sx_times") String free_sx_times,
                       @Param("type") String type,
                       @Param("lv") String lv,
                       @Param("cbt_key") String cbt_key);

    boolean clearWzycCbtKey(@Param("name") String name);

    boolean clearWzyc();

    List<JSONObject> getJuling(@Param("name") String name);

    boolean addJuling(@Param("name") String name);

    boolean updateJuling(@Param("name") String name,
                         @Param("times") String times);

    boolean clearJuling();

    List<JSONObject> getChuiDiao(@Param("name") String name);

    boolean addChuiDiao(@Param("name") String name);

    boolean updateChuiDiao(@Param("name") String name,
                           @Param("free_times") String free_times,
                           @Param("fufei_times") String fufei_times);

    boolean clearChuiDiao();


    List<JSONObject> getCjwd(@Param("name") String name);

    boolean addCjwd(@Param("name") String name, @Param("list_index") int list_index);

    boolean updateCjwd(@Param("name") String name,
                       @Param("times") int times);

    boolean clearCjwd();

    List<JSONObject> getTianbing(@Param("name") String name);

    boolean addTianbing(@Param("name") String name);

    boolean updateTianbing(@Param("name") String name,
                           @Param("lv") String lv);

    boolean remTianbing(@Param("name") String name);

    List<JSONObject> getJingjiSum();

    List<JSONObject> getJingjiOrderByJf(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getJingji(@Param("name") String name);

    boolean addJingji(@Param("name") String name);

    boolean updateJingji(@Param("name") String name,
                         @Param("jf") String jf,
                         @Param("times") String times);

    boolean clearTimesJingji();

    boolean remJingji();

    List<JSONObject> getXinMo(@Param("name") String name);

    boolean addXinMo(@Param("name") String name);

    boolean updateXinMo(@Param("name") String name,
                        @Param("lv") String lv);

    boolean remXinMo();

    List<JSONObject> getMSJLMsg(@Param("name") String name);

    boolean addMSJLMsg(@Param("name") String name);

    boolean updateMSJLMsg(@Param("name") String name,
                          @Param("times") String times);

    boolean remMSJLMsg();

    List<JSONObject> getCWBK(@Param("Id") String Id);

    boolean addCWBK(@Param("Id") String Id,
                    @Param("name") String name,
                    @Param("start") String start);

    boolean updateCWBK(@Param("Id") String Id,
                       @Param("name") String name,
                       @Param("start") String start);

    boolean resetCWBK(@Param("Id") String Id);

    boolean remCWBK();

    List<JSONObject> getBLYT(@Param("name") String name);

    boolean addBLYT(@Param("name") String name);

    boolean updateBLYT(@Param("name") String name,
                       @Param("lever") String lever);

    boolean remBLYT();

    List<JSONObject> getXFLJ(@Param("name") String name);

    boolean addXFLJ(@Param("name") String name);

    boolean updateXFLJ(@Param("name") String name,
                       @Param("yb") String yb);

    boolean remXFLJ();

    List<JSONObject> getTGRG(@Param("name") String name);

    boolean addTGRG(@Param("name") String name,
                    @Param("a1") String a1,
                    @Param("a2") String a2,
                    @Param("a3") String a3);

    boolean updateTGRG(@Param("name") String name,
                       @Param("a1") String a1,
                       @Param("a2") String a2,
                       @Param("a3") String a3);

    boolean remTGRG();

    List<JSONObject> getAllTGR();

    List<JSONObject> getTGR(@Param("Id") String Id);

    boolean addTGR(@Param("Id") String Id);

    boolean updateTGR(@Param("Id") String Id,
                      @Param("times") String times);

    boolean remTGR();

    List<JSONObject> getSjjl(@Param("name") String name);

    boolean addSjjl(@Param("name") String name);

    boolean updateSjjl(@Param("name") String name,
                       @Param("times") String times,
                       @Param("exchange") String exchange,
                       @Param("cqrewards") String cqrewards,
                       @Param("qiandao") String qiandao,
                       @Param("xfrewards") String xfrewards,
                       @Param("tuangou") String tuangou,
                       @Param("libao") String libao,
                       @Param("ybrewards") String ybrewards);

    boolean remSjjl();


    List<JSONObject> getSomeWHJX(@Param("maxJf") int maxJf, @Param("minJf") int minJf);

    List<JSONObject> getWHJX(@Param("name") String name);

    boolean addWHJX(@Param("name") String name, @Param("jf") String jf, @Param("times") String times);

    boolean updateWHJX(@Param("name") String name,
                       @Param("jf") String jf,
                       @Param("times") String times);

    boolean clearTimesWHJX();

    boolean remWHJX();

    List<JSONObject> getYGMB(@Param("name") String name);

    boolean addYGMB(@Param("name") String name);

    boolean updateYGMB(@Param("name") String name,
                       @Param("r1") String r1,
                       @Param("r2") String r2,
                       @Param("r3") String r3);

    boolean remYGMB(@Param("name") String name);

    List<JSONObject> getMJXW(@Param("name") String name);

    boolean addMJXW(@Param("name") String name);

    boolean updateMJXW(@Param("name") String name,
                       @Param("r1") String r1,
                       @Param("r2") String r2,
                       @Param("r3") String r3);

    boolean remMJXW();


    List<JSONObject> getStSign(@Param("name") String name);

    List<JSONObject> getStSignView();

    boolean addStSign(@Param("name") String name);

    boolean remStSign(@Param("name") String name);

    List<JSONObject> getManViewSum();

    List<JSONObject> getManView(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getLvViewSum();

    List<JSONObject> getLvView(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getTtViewSum();

    List<JSONObject> getTtView(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getTiantiByName(@Param("name") String name);

    boolean addTianti(@Param("name") String name, @Param("ts") String ts);

    boolean updateTianti(@Param("name") String name, @Param("ts") String ts);

    boolean remTianti();

    List<JSONObject> getJdFromPWViewByWs(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getPWViewSumByWs();

    List<JSONObject> getJdFromPWView(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getPWViewSum();

    List<JSONObject> getJJViewSum();

    List<JSONObject> getOrderFromJJViewByName(@Param("name") String name);

    List<JSONObject> getOrderFromJJView(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getJdFromJJView(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getPaiweiNearJd(@Param("max") Long max, @Param("min") Long min,
                                     @Param("names") List names, @Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getPaiweiByName(@Param("name") String name);

    boolean addPaiwei(@Param("name") String name, @Param("jd") String jd);

    boolean updatePaiwei(@Param("jd") String jd, @Param("name") String name);

    boolean remPaiwei();

    boolean clearPaiwei();


    List<JSONObject> getJjNearJd(@Param("max") Long max, @Param("min") Long min,
                                 @Param("names") List names, @Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getJjByName(@Param("name") String name);

    boolean addJj(@Param("name") String name, @Param("jd") String jd,
                  @Param("times") String times);

    boolean updateJj(@Param("jd") String jd, @Param("times") String times, @Param("name") String name);

    boolean remJj();

    boolean clearPersonJj();


    List<JSONObject> getJiziByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getJiziSum();

    List<JSONObject> getJizi(@Param("name") String name);

    boolean addJizi(@Param("name") String name, @Param("sub") String sub);

    boolean updateJizi(@Param("sub") String sub, @Param("name") String name);

    boolean remJizi();

    List<JSONObject> getLvGift(@Param("name") String name);

    boolean addLvGift(@Param("name") String name);

    boolean updateLvGift(@Param("gain") String gain, @Param("name") String name);

    boolean remLvGift();

    List<JSONObject> getDayQiandao(@Param("name") String name);

    boolean addDayQiandao(@Param("name") String name);

    boolean updateDayQiandao(@Param("gain") String gain, @Param("name") String name);

    boolean remDayQiandao();

    List<JSONObject> getQiandao(@Param("name") String name);

    boolean addQiandao(@Param("name") String name);

    boolean updateQiandao(@Param("gain0") String gain0, @Param("name") String name);

    boolean remQiandao();


    List<JSONObject> getPersonLunjianSum();

    List<JSONObject> getPersonLunJianPetSignOrder(@Param("jf") String jf, @Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getPersonLunJianPetSign(@Param("name") String name, @Param("fail_times") String fail_times);

    boolean addPersonLunJianPetSign(@Param("name") String name, @Param("members") String members);

    boolean updatePersonLunJianPetSign(@Param("name") String name, @Param("jf") String jf, @Param("fail_times") String fail_times, @Param("members") String members);

    boolean clearPersonLunJianPetSign();

    List<JSONObject> getLunjianPerson();

    boolean addLunJianPerson(
            @Param("title") String title,
            @Param("bmf_type") String bmf_type,
            @Param("bmf_v") String bmf_v,
            @Param("jj_type") String jj_type,
            @Param("jj_v") String jj_v,
            @Param("name") String name,
            @Param("created") String created
    );

    boolean updateLunJianPerson(
            @Param("title") String title,
            @Param("bmf_type") String bmf_type,
            @Param("bmf_v") String bmf_v,
            @Param("jj_type") String jj_type,
            @Param("jj_v") String jj_v
    );

    boolean clearLunJianPerson();


    List<JSONObject> getZslSum();

    List<JSONObject> getZslSumNoGetter();

    List<JSONObject> getZslByNoGetter(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getZsl(@Param("Id") String Id, @Param("getter") String getter, @Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getZslByDestroy(@Param("now") String now);

    boolean addZsl(@Param("Id") String Id, @Param("price") String price, @Param("price_type") String price_type,
                   @Param("player") String player, @Param("name") String name, @Param("getter") String getter,
                   @Param("created") String created, @Param("destroy") String destroy);

    boolean updateZsl(@Param("getter") String getter, @Param("Id") String Id);

    boolean remZsl(@Param("Id") String Id);

    List<JSONObject> getLunjianSum();

    List<JSONObject> getLunJianPetSignOrder(@Param("jf") String jf, @Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getLunJianPetSign(@Param("name") String name, @Param("fail_times") String fail_times);

    boolean addLunJianPetSign(@Param("name") String name, @Param("members") String members);

    boolean updateLunJianPetSign(@Param("name") String name, @Param("jf") String jf, @Param("fail_times") String fail_times, @Param("members") String members);

    boolean clearLunJianPetSign();

    List<JSONObject> getLunJianPet(@Param("name") String name);

    boolean addLunJianPet(@Param("name") String name, @Param("pet") String pet);

    boolean updateLunJianPet(@Param("name") String name, @Param("pet") String pet);

    boolean clearLunJianPet();

    List<JSONObject> getJiJin(@Param("name") String name);

    boolean insertJiJin(@Param("name") String name);

    boolean updateJiJin(@Param("name") String name,
                        @Param("unlock0") String unlock0,
                        @Param("gain0") String gain0,
                        @Param("unlock1") String unlock1,
                        @Param("gain1") String gain1);

    boolean updateJiJinByDay();

    List<JSONObject> getFb(@Param("name") String name);

    boolean insertFb(@Param("name") String name);

    boolean updateFb(@Param("name") String name,
                     @Param("fb50") String fb50,
                     @Param("fb60") String fb60,
                     @Param("fb70") String fb70,
                     @Param("fb80") String fb80,
                     @Param("fb90") String fb90,
                     @Param("fb100") String fb100,
                     @Param("fbls") String fbls,
                     @Param("fbhh") String fbhh,
                     @Param("fbys") String fbys,
                     @Param("fbzx") String fbzx,
                     @Param("fbyzj") String fbyzj);

    boolean clearFb();


    List<JSONObject> getAcJifen(@Param("name") String name);

    boolean updateAcJifen(@Param("name") String name, @Param("zpjf") Integer zpjf, @Param("jnzpjf") Integer jnzpjf);

    boolean insertAcJifen(@Param("name") String name, @Param("zpjf") Integer zpjf, @Param("jnzpjf") Integer jnzpjf);

    List<JSONObject> getAcDayLimit(@Param("name") String name);

    boolean updateAcDayLimit(@Param("name") String name,
                             @Param("yuebing") Integer yuebing,
                             @Param("hf") Integer hf,
                             @Param("zhuling") Integer zhuling,
                             @Param("fangsheng") Integer fangsheng);

    boolean delAcDayLimit();

    boolean insertAcDayLimit(@Param("name") String name);

    List<JSONObject> getAcReward(@Param("name") String name);

    boolean updateAcReward(@Param("name") String name, @Param("surplus") Integer surplus);

    List<JSONObject> getPrisonOne(@Param("name") String name);

    boolean putPrison(@Param("name") String name);

    boolean updatePrison(@Param("name") String name, @Param("total") String total);

    boolean delPrison(String name);

    boolean delDsx();

    List<JSONObject> getWinDsxNameList();

    boolean updateDsxByNames(@Param("names") List names, @Param("win") String win);

    List<JSONObject> getDsxNameList(String model);

    List<JSONObject> getDsxOne(@Param("name") String name);

    boolean addDsx(@Param("name") String name, @Param("model") String model);

    boolean updateDsx(@Param("name") String name, @Param("win") String win);

    boolean delDsx(String name);

    List<JSONObject> getCBT(@Param("name") String name);

    boolean createCBT(@Param("name") String name, @Param("lv") String lv, @Param("map") String map, @Param("pos") String pos);

    boolean updateCBTLv(@Param("name") String name, @Param("lv") String lv, @Param("times") String times);

    boolean finishCBT(String name);

    boolean clearAll();

    List<JSONObject> getB(@Param("name") String name);

    boolean createB(@Param("name") String name, @Param("lv") String lv);

    boolean updateBLv(@Param("name") String name, @Param("lv") String lv, @Param("times") String times);

    boolean setBIsGet(String name);

    boolean updateBUptimes(@Param("name") String name, @Param("uptimes") String uptimes);

    boolean updateBQbtimes(@Param("name") String name, @Param("qbtimes") String qbtimes);

    boolean clearAllCb();
}
