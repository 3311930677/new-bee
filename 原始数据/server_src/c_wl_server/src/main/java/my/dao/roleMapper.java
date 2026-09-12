package my.dao;

import com.alibaba.fastjson2.JSONObject;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface roleMapper {
    List<JSONObject> findMzzd(String name);

    boolean insertMzzd(@Param("mzzd") String mzzd, @Param("name") String name);

    boolean updateMzzd(@Param("name") String name, @Param("mzzd") String mzzd);

    boolean delMzzd(String name);

    List<JSONObject> getRoleByLikeName(@Param("name")String name,@Param("filterName")List filterName,@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);
    List<JSONObject> getRolesMsg(@Param("names")List names);
    List<JSONObject> findFriend(String name);

    boolean insertFriend(@Param("friend") String friend, @Param("name") String name);

    boolean updateFriend(@Param("name") String name, @Param("friend") String friend);

    boolean delFriend(String name);

    List<JSONObject> count();

    List<JSONObject> getOrderLv(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean updateLv(@Param("lever") Long lever, @Param("name") String name);
    boolean updateModel(@Param("model") String model, @Param("name") String name);
    boolean updateModels(@Param("models") String models, @Param("name") String name);

    boolean insertRole(@Param("Id") String Id, @Param("username") String username, @Param("name") String name,
                       @Param("lever") String lever,
                       @Param("model") String model,
                       @Param("models") String models);

    List<JSONObject> getRoleByUsername(String username);
    List<JSONObject> getRoleView(String username);

    List<JSONObject> getRoleAndUser(String name);
    List<JSONObject> selectRoleByIp(@Param("ip")String ip,@Param("email")String email);

    List<JSONObject> selectRoleByNames(@Param("names") List names);

    List<JSONObject> selectRoleByLever(@Param("lv") int lv, @Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getRoleByName(String name);
    List<JSONObject> getRoleViewByName(String name);

    List<JSONObject> getRolesByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    List<JSONObject> getRoleOne(String username);

    boolean delRole(String name);
}
