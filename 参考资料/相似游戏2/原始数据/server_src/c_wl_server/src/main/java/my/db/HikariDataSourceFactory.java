package my.db;


import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import my.utils.fileUtils;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSourceFactory;

import static my.utils.staticCollection.url;

public class HikariDataSourceFactory extends UnpooledDataSourceFactory {
    public HikariDataSourceFactory() {
        String str = fileUtils.readFile(url + "mysqlconfig.json");
        JSONArray list = JSON.parseArray(str);
        JSONObject j = list.getJSONObject(0);
        //System.err.println(j);
        //连接池配置
        HikariConfig config = new HikariConfig();
        config.setDriverClassName(j.getString("driver"));
        config.setJdbcUrl("jdbc:mariadb://localhost:" + j.getString("port")
                + "/" + j.getString("dbname")
                + "?useUnicode=true&characterEncoding=utf8&serverTimezone=GMT%2B8");
        config.setUsername(j.getString("username"));
        config.setPassword(j.getString("password"));
        config.setAutoCommit(false);
        config.setConnectionTimeout(30 * 1000);
        //据库服务端会在4分钟后删除没有请求的连接，所以最大存活时间要小于他
        config.setMaxLifetime(3 * 60 * 1000);
        //用来指定验证连接有效性的超时时间(默认是5秒，最小不能小于250毫秒)，如果是没有设置connectionTestQuery的话，默认是用jdbc4规范中的connection.isValid(validationSeconds)来验证连接的有效性
        config.setValidationTimeout(5 * 1000);
        config.setConnectionTestQuery("SELECT 1");
        config.setIdleTimeout(600000);
        config.setConnectionInitSql("SET NAMES utf8mb4");
        //池中最小空闲链接数量
        config.setMinimumIdle(10);
        //池中最大链接数量
        config.setMaximumPoolSize(150);
        config.setPoolName("data-pool-");
        //config.addDataSourceProperty("cachePrepStmts", "true");
        this.dataSource = new HikariDataSource(config);
    }

}
