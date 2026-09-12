package my.dao;

import com.alibaba.fastjson2.JSONObject;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface logMapper {
    List<JSONObject> getPkLogByName(String name);

    boolean delPkLogByName(String name);

    boolean insertPkLog(@Param("name") String name, @Param("paiwei") String paiwei,
                   @Param("jingji") String jingji);

    boolean updatePkLog(@Param("name") String name, @Param("paiwei") String paiwei,
                        @Param("jingji") String jingji);


    List<JSONObject> getByName(String name);

    boolean delOpByCreated(Long created);

    boolean delByName(String name);

    boolean insert(@Param("name") String name, @Param("online") String online,
                   @Param("accumulate") String accumulate, @Param("offline") String offline, @Param("is_get_lld") String is_get_lld);

    boolean update(@Param("name") String name, @Param("online") String online,
                   @Param("accumulate") String accumulate, @Param("offline") String offline,
                   @Param("is_get_lld") String is_get_lld, @Param("leaveBpTime") String leaveBpTime);

    boolean clear(@Param("online") String online);

    Integer insertOp(@Param("Id") String Id, @Param("type") String type,
                     @Param("ip") String ip, @Param("name") String name,
                     @Param("des") String des, @Param("eip") String eip,
                     @Param("ename") String ename, @Param("created") String created,
                     @Param("suc") String suc);
}
