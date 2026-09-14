package my.db;

import com.alibaba.fastjson2.JSONObject;
import my.dao.*;
import org.apache.ibatis.io.Resources;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.ibatis.session.defaults.DefaultSqlSession;

import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.function.Function;

public class mybatisConfig {
    private static SqlSessionFactory sqlSessionFactory;

    public static void config() {
        // 定义配置文件，相对路径，文件直接放在resources目录下
        String resource = "configuration.xml";
        // 读取文件字节流
        InputStream inputStream = null;
        try {
            inputStream = Resources.getResourceAsStream(resource);
            // mybatis 读取字节流，利用XMLConfigBuilder类解析文件
            // 将xml文件解析成一个 org.apache.ibatis.session.Configuration 对象
            // 然后将 Configuration 对象交给 SqlSessionFactory 接口实现类 DefaultSqlSessionFactory 管理
            sqlSessionFactory = new SqlSessionFactoryBuilder().build(inputStream);
            sqlSessionFactory.getConfiguration().addMapper(userMapper.class);
            sqlSessionFactory.getConfiguration().addMapper(roleMapper.class);
            sqlSessionFactory.getConfiguration().addMapper(jsonMapper.class);
            sqlSessionFactory.getConfiguration().addMapper(activityMapper.class);
            sqlSessionFactory.getConfiguration().addMapper(logMapper.class);
            sqlSessionFactory.getConfiguration().addMapper(shopMapper.class);
            sqlSessionFactory.getConfiguration().addMapper(chatMapper.class);
            sqlSessionFactory.getConfiguration().addMapper(gangsMapper.class);
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                inputStream.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }


        // openSession 有多个重载方法， 比较重要几个是
        // 1 是否默认提交 SqlSession openSession(boolean autoCommit)
        // 2 设置事务级别 SqlSession openSession(TransactionIsolationLevel level)
        // 3 执行器类型   SqlSession openSession(ExecutorType execType)
        //SqlSession sqlSession = sqlSessionFactory.openSession(false);

        // mybatis 内部其实已经解析好了 mapper 和 mapping 对应关系，放在一个map中，这里可以直接获取
        // 如果看源码可以发现userMapper 其实是一个代理类MapperProxy，
        // 通过 sqlSession、mapperInterface、mechodCache三个参数构造的
        // MapperProxyFactory 类中 newInstance(MapperProxy<T> mapperProxy)方法
        //jsonMapper jsonMapper = sqlSession.getMapper(jsonMapper.class);

        /* insert */
        /*User user = new User();
        user.setUsername("LiuYork");
        user.setPassword("123456");
        userMapper.insertUser(user);
        // 由于默认 openSession() 事务是交由开发者手动控制，所以需要显示提交
        sqlSession.commit();*/

        /* select */
        /*List<JSONObject> users = jsonMapper.select("666666");
        System.err.println(users);
        sqlSession.close();*/
    }

    /**
     * 获取一个连接
     */
    public static SqlSession getSqlSession() {
        SqlSession sql = sqlSessionFactory.openSession(false);
        return sql;
    }

    /*public static Connection getConnection() {
        SqlSession sql = sqlSessionFactory.openSession(false);
        return sql.getConnection();
    }*/

    public static SqlSessionFactory getSqlSessionFactory() {
        return sqlSessionFactory;
    }

    /**
     * 转换成任意mapper接口
     */
    public static <V> V getMapper(SqlSession sqlSession, Class<?> c) {
        return (V) sqlSession.getMapper(c);
    }


    public static void rollback(SqlSession sqlSession) {
        try {
            if (sqlSession != null)
                sqlSession.rollback();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void commit(SqlSession sqlSession) throws Exception {
        try {
            if (sqlSession != null) {
                sqlSession.commit();
                sqlSession.flushStatements();
            }
        } catch (Exception e) {
            e.printStackTrace();
            throw new Exception(e);
        }
    }

    public static void close(SqlSession sqlSession) {
        try {
            if (sqlSession != null) {
                sqlSession.close();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void test() {
        Function<DefaultSqlSession, Object> fn = (con) -> {
            roleMapper rm = mybatisConfig.getMapper(con, roleMapper.class);
            List<JSONObject> list = rm.getRoleByName("中崔");
            System.err.println(list);
            return null;
        };
        putTask(fn);
    }

    public static void putTask(Function<DefaultSqlSession, Object> function) {
        DefaultSqlSession con = null;
        try {
            con = (DefaultSqlSession) mybatisConfig.getSqlSession();
            process(con, function);
            mybatisConfig.commit(con);
        } catch (Exception e) {
            e.printStackTrace();
            mybatisConfig.rollback(con);
        } finally {
            mybatisConfig.close(con);
        }
    }

    /**
     * 将带参数的方法作为一个参数注入另一个方法中
     */
    private static <T, R> R process(T input, Function<T, R> function) {
        return function.apply(input);
    }
}
