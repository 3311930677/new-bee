package my.utils;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public class loggerUtils {
    /*static {
        Properties properties = fileUtils.readProperties("app.properties");
        PropertyConfigurator.configure(properties.getProperty("downloadPath") + "/log4j.properties");
    }*/

    private static Logger getInstance(Class c) {
        return LogManager.getLogger(c);
    }

    public static void info(String msg, Class c) {
        Logger log = getInstance(c);
        log.info(msg);
    }
    /**windows系统打印日志*/
    public static void infoByWindows(String msg, Class c) {
        if(systemUtils.isWindows()){
            info(msg,c);
        }
    }

    public static void warn(String msg, Class c) {
        Logger log = getInstance(c);
        log.warn(msg);
    }

    public static void error(String msg, Class c) {
        Logger log = getInstance(c);
        log.error(msg);
    }
}