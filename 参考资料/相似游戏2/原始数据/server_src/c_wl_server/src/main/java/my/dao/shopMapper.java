package my.dao;

import com.alibaba.fastjson2.JSONObject;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface shopMapper {
    List<JSONObject> getAllGroundingGoodsView();
    List<JSONObject> getGroundingGoodsViewByPage(@Param("pageNum") Long pageNum, @Param("pageSum") Long pageSum);
    List<JSONObject> getGroundingGoodsViewByName(@Param("name")String name);
    boolean updateGroundingGoods(@Param("name") String name,@Param("list") String list);
    boolean insertGroundingGoods(@Param("name") String name,@Param("list") String list);
    boolean delGroundingGoodsByName(@Param("name") String name);

    List<JSONObject> getGoodsById(@Param("name") String name);

    boolean update(@Param("Id") String Id, @Param("goods") String goods,
                   @Param("sale") String sale, @Param("kan") String kan);

    boolean insert(@Param("Id") String Id, @Param("goods") String goods,
                   @Param("created") String created, @Param("name") String name,
                   @Param("type") String type, @Param("price_type") String price_type);

    boolean del(@Param("Id") String Id);
}
