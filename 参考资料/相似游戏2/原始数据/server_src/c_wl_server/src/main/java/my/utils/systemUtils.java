package my.utils;

import java.io.File;
import java.io.IOException;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.net.UnknownHostException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Enumeration;

import static my.utils.staticCollection.url;

public class systemUtils {
    public static boolean isWindows() {
        String osName = System.getProperty("os.name");
        if (osName.toLowerCase().contains("win")) return true;
        return false;
    }


    public static void doClearCache() {
        if (isWindows()) {
            return;
        }
        systemUtils.doSh("sync && echo 1 > /proc/sys/vm/drop_caches");
        systemUtils.doSh("sync && echo 2 > /proc/sys/vm/drop_caches");
        systemUtils.doSh("sync && echo 3 > /proc/sys/vm/drop_caches");
    }

    public static void doSh(String c) {
        Process proc = null;
        try {
            String[] commands = {"sudo", "sh", "-c", c};
            proc = Runtime.getRuntime().exec(commands);
            proc.waitFor();
        } catch (IOException e) {
            e.printStackTrace();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

    }

    private static Process linuxEnv(String command) {
        Process ps = null;
        try {
            String[] commands = {"/bin/sh", "-c", command};
            ps = Runtime.getRuntime().exec(commands);

        } catch (Exception ex) {
            ex.printStackTrace();
        }
        return ps;
    }

    private static Process windowsEnv(String command) {
        Process ps = null;
        try {
            String[] commands = {"cmd", "/c", command};
            ps = Runtime.getRuntime().exec(commands);
        } catch (Exception ex) {
            ex.printStackTrace();
        }
        return ps;
    }

    /**
     * 数据库备份
     * 注意：备份前需要拦截所有请求
     */
    private static void dbBackup(String username, String authenticate, String dbName, String destination, String backName) {
        File backupDir = new File(destination);
        if (!backupDir.exists()) {
            backupDir.mkdirs();
        }
        try {
            File sqlFile = new File(backupDir, backName);
            if (!sqlFile.exists()) {
                sqlFile.createNewFile();
            }
            String osName = System.getProperty("os.name");
            //mysqldump -h localhost -u root -p db_name > db_name.sql
            StringBuffer buffer = new StringBuffer();
            //windows需要加上dump.exe路径，否则输出0k
            if (osName.toLowerCase().contains("win"))
                buffer.append("E:\\phpStudy\\PHPTutorial\\MySQL\\bin\\");
            buffer.append("mysqldump");
            buffer.append(" -h127.0.0.1");
            buffer.append(" -u" + username);
            buffer.append(" -p" + authenticate);
            buffer.append(" " + dbName + " > ");
            buffer.append(sqlFile);
            //loggerUtils.info("cmd命令为：" + buffer.toString(), systemUtils.class);
            //Runtime runtime = Runtime.getRuntime();
            //loggerUtils.info("开始备份：" + dbName, systemUtils.class);
            //Process process = runtime.exec("cmd /c"+buffer.toString());

            if (osName.toLowerCase().contains("win")) {
                Process process = windowsEnv(buffer.toString());
                process.waitFor();
            } else {
                Process process = linuxEnv(buffer.toString());
                process.waitFor();
            }
            //loggerUtils.info("备份成功!", systemUtils.class);
        } catch (Exception ex) {
            ex.printStackTrace();
        }
    }

    public static void startBbBackup() {
        if (isWindows()) return;
        try {
            String path = "/home/wl/db";
            //loggerUtils.info("备份数据库开始执行", systemUtils.class);
            String backName = new SimpleDateFormat("yyyyMMddHHmmss").format(new Date()) + ".sql";
            dbBackup("myxq", "xunqin2015", "myxq3d", path, backName);
            //loggerUtils.info("备份数据库结束", systemUtils.class);
        } catch (Exception ex) {
            loggerUtils.info("备份异常", systemUtils.class);
            ex.printStackTrace();
        }
    }

}
