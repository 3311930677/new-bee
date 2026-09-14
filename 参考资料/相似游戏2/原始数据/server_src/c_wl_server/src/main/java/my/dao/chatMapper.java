package my.dao;

import com.alibaba.fastjson2.JSONObject;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface chatMapper {
    List<JSONObject> getChat(@Param("sender") String sender, @Param("receiver") String receiver,
                             @Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);

    boolean addChat(@Param("Id") String Id, @Param("sender") String sender,
                    @Param("receiver") String receiver, @Param("created") String created,
                    @Param("content") String content, @Param("type") String type);

    boolean delChat(@Param("sender") String sender, @Param("receiver") String receiver);
}
