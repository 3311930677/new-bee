package my.dao;

import com.alibaba.fastjson2.JSONObject;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface userMapper {
    boolean updateVerify(@Param("username") String username, @Param("verify") String verify);

    boolean updatePassword(@Param("username") String username, @Param("password") String password);

    List<JSONObject> selectByIp(String ip);

    boolean insertUser(@Param("Id") String Id, @Param("username") String username,
                       @Param("password") String password, @Param("created") String created,
                       @Param("email") String email);

    boolean updateOnline(@Param("online") String online, @Param("ip") String ip, @Param("allowed_ip") String allowed_ip, @Param("username") String username);

    List<JSONObject> match(@Param("username") String username, @Param("password") String password);

    boolean bindEamil(@Param("email") String email, @Param("username") String username);

    List<JSONObject> countEmailNum(String email);

    List<JSONObject> getUserByUsername(String username);
    List<JSONObject> getUserView(String username);
    List<JSONObject> getUserLimit(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean delUser(String username);

    List<JSONObject> getUserNum();


}
