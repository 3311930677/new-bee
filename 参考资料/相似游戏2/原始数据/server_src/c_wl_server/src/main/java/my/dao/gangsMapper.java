package my.dao;

import com.alibaba.fastjson2.JSONObject;
import org.apache.ibatis.annotations.Param;

import java.util.List;

public interface gangsMapper {
    List<JSONObject> selectGangsFarm(String Id);

    boolean updateGangsFarm(@Param("yt1") String yt1,
                            @Param("yt2") String yt2,
                            @Param("yt3") String yt3,
                            @Param("yt4") String yt4,
                            @Param("yt5") String yt5,
                            @Param("Id") String Id);

    boolean addGangsFarm(@Param("yt1") String yt1,
                         @Param("yt2") String yt2,
                         @Param("yt3") String yt3,
                         @Param("yt4") String yt4,
                         @Param("yt5") String yt5,
                         @Param("Id") String Id);

    boolean delGangsFarm(@Param("Id") String Id);


    List<JSONObject> selectAllGangsRobber();

    List<JSONObject> selectGangsRobber(String Id);

    boolean updateGangsRobber(@Param("num") String num,
                              @Param("Id") String Id);

    boolean addGangsRobber(@Param("num") String num,
                           @Param("Id") String Id);

    boolean delAllGangsRobber();

    List<JSONObject> selectGangsYanhui(String Id);

    boolean updateGangsYanhui(@Param("num") String num,
                              @Param("members") String members,
                              @Param("Id") String Id);

    boolean addGangsYanhui(@Param("num") String num,
                           @Param("members") String members,
                           @Param("Id") String Id);

    boolean delGangsYanhui(@Param("Id") String Id);

    List<JSONObject> selectGangsMsgAndBuild(String Id);
    List<JSONObject> selectGangsBuild(String Id);

    boolean updateGangsBuild(@Param("shop") String shop,
                             @Param("tec") String tec,
                             @Param("solicit") String solicit,
                             @Param("book") String book,
                             @Param("mifa") String mifa,
                             @Param("Id") String Id);

    boolean addGangsBuild(@Param("shop") String shop,
                          @Param("tec") String tec,
                          @Param("solicit") String solicit,
                          @Param("book") String book,
                          @Param("mifa") String mifa,
                          @Param("Id") String Id);

    boolean delGangsBuild(@Param("Id") String Id);

    List<JSONObject> selectGangsAcTimes(String name);

    boolean updateGangsAcTimes(@Param("dayReward") String dayReward,
                               @Param("bossTimes") String bossTimes,
                               @Param("psTimes") String psTimes,
                               @Param("yhTimes") String yhTimes,
                               @Param("name") String name);

    boolean addGangsAcTimes(@Param("dayReward") String dayReward,
                            @Param("bossTimes") String bossTimes,
                            @Param("psTimes") String psTimes,
                            @Param("yhTimes") String yhTimes,
                            @Param("name") String name);

    boolean delGangsAcTimes(@Param("name") String name);

    List<JSONObject> selectGangsPs(String name);

    boolean updateGangsPs(@Param("name") String name, @Param("tale") String tale, @Param("goods") String goods);

    boolean insertGangsPs(@Param("name") String name);

    boolean delGangsPs(@Param("name") String name);


    List<JSONObject> selectBRE(String name);

    boolean updateBRE(@Param("name") String name, @Param("exchange") String exchange);

    boolean insertBRE(@Param("name") String name);

    boolean delBRE();


    boolean delGangsFight();

    List<JSONObject> selectGangsAndFightByOrder();

    List<JSONObject> selectGangsFightByOrder();


    List<JSONObject> selectGangsFightAndMsg();

    List<JSONObject> selectGangsFight(String Id);

    boolean updateGangsFight(@Param("Id") String Id, @Param("jf") String jf);

    boolean insertGangsFight(@Param("Id") String Id, @Param("jf") String jf);


    List<JSONObject> selectGangsBpdzzAllOrder(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> selectGangsBpdzzGangsOrderView();

    List<JSONObject> selectGangsBpdzzGangsOrder();

    List<JSONObject> selectGangsBpdzzGangs(@Param("Id") String Id);

    boolean updateGangsBpdzzGangs(@Param("Id") String Id, @Param("jf") String jf);

    boolean addBpdzzGangs(@Param("Id") String Id);

    boolean delBpdzzGangs();

    List<JSONObject> selectGangsBpdzzPlayerByNames(@Param("names") List names);

    List<JSONObject> selectGangsBpdzzPlayer(@Param("name") String name);

    boolean updateGangsBpdzzPlayer(@Param("name") String name, @Param("jf") String jf,
                                   @Param("sumTimes") String sumTimes, @Param("getTimes") String getTimes,
                                   @Param("rewards") String rewards);

    boolean addBpdzzPlayer(@Param("name") String name);

    boolean delBpdzzPlayer();

    List<JSONObject> selectGangsBpdzzTaskByGainner(@Param("gainner") String gainner);

    List<JSONObject> selectGangsBpdzzTaskSum();

    List<JSONObject> selectGangsBpdzzTaskByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> selectGangsBpdzzTask(@Param("Id") String Id);

    boolean updateGangsBpdzzTask(@Param("Id") String Id, @Param("gainner") String gainner,
                                 @Param("startTime") String startTime, @Param("endTime") String endTime,
                                 @Param("status") String status, @Param("k") String k, @Param("num") String num);

    boolean addBpdzzTask(@Param("Id") String Id, @Param("gainner") String gainner,
                         @Param("startTime") String startTime, @Param("endTime") String endTime,
                         @Param("status") String status, @Param("k") String k, @Param("num") String num);

    boolean delBpdzzTask();

    boolean delBpdzzTaskById(@Param("Id") String Id);

    List<JSONObject> selectGangsTask(@Param("Id") String Id);

    boolean updateGangsTask(@Param("Id") String Id, @Param("task") String task);

    boolean addGangsTask(@Param("Id") String Id, @Param("task") String task);

    boolean delGangsTaskById(@Param("Id") String Id);

    boolean updateGangs(@Param("captain") String captain, @Param("lever") String lever, @Param("money") String money,
                        @Param("bg") String bg, @Param("notice") String notice, @Param("Id") String Id);

    boolean delGangs(@Param("Id") String Id);

    List<JSONObject> selectGangsActivity(String Id);

    boolean insertGangsActivity(@Param("Id") String Id);

    boolean updateGangsActivity(@Param("Id") String Id, @Param("boss") String boss, @Param("ywt") String ywt,
                                @Param("ps") String ps, @Param("yh") String yh);

    boolean clearGangsActivity();

    boolean delGangsActivity(@Param("Id") String Id);

    List<JSONObject> selectGangsActivityAndBoss(String Id);

    List<JSONObject> selectGangsBoss(String Id);

    boolean insertGangsBoss(@Param("Id") String Id);

    boolean updateGangsBoss(@Param("Id") String Id,
                            @Param("xue") String xue,
                            @Param("rewards") String rewards);

    boolean delGangsBoss(@Param("Id") String Id);


    List<JSONObject> selectGangsActivityAndV(String Id);

    List<JSONObject> selectGangsV(String Id);

    boolean insertGangsV(@Param("Id") String Id);

    boolean updateGangsV(@Param("Id") String Id,
                         @Param("monkey") String monkey,
                         @Param("pstimes") String pstimes);

    boolean delGangsV(@Param("Id") String Id);

    boolean clearGangsReq();

    boolean insertGangsReq(String Id);

    boolean delGangsReq(String Id);


    boolean insertGangs(@Param("Id") String Id, @Param("gangsName") String gangsName, @Param("captain") String captain);

    List<JSONObject> selectGangsByName(@Param("gangsName") String gangsName, @Param("captain") String captain);

    List<JSONObject> countGangs();

    List<JSONObject> selectGangsLimit(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean updateGangsReq(@Param("req") String req, @Param("Id") String Id);

    List<JSONObject> selectGangsReq(String Id);

    List<JSONObject> selectGangsMembersSum(@Param("bpId") String bpId);

    List<JSONObject> selectGangsMembersByPage(@Param("bpId") String bpId, @Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);
    List<JSONObject> selectGangsMembersNames(@Param("bpId") String bpId);

    List<JSONObject> selectGangsMembers(@Param("bpId") String bpId, @Param("name") String name);

    List<JSONObject> selectGangsMembersDayBg(@Param("bpId") String bpId);

    boolean insertGangsMembers(@Param("bpId") String bpId, @Param("name") String name,
                               @Param("job") String job);

    boolean updateGangsMembers(@Param("bpId") String bpId, @Param("name") String name,
                               @Param("job") String job, @Param("bg") String bg,
                               @Param("dayBg") String dayBg,@Param("taskTimes") String taskTimes);

    boolean delGangsMembers(@Param("names") List names);

    List<JSONObject> selectGangsByIds(@Param("ids") List ids);
    List<JSONObject> selectAllGangs();

    List<JSONObject> selectAllGangsId();

    List<JSONObject> selectGangs(String Id);
}
