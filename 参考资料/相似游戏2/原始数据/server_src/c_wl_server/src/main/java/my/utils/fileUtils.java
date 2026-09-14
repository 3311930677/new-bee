package my.utils;

import org.apache.commons.codec.digest.DigestUtils;

import java.io.*;
import java.nio.channels.FileChannel;
import java.util.Base64;
import java.util.zip.*;

public class fileUtils {

    public static byte[] readSource(String path) {
        return readSource(new File(path));
    }

    public static byte[] readSource(File file) {
        if (!file.exists() || file.isDirectory()) return null;
        //base64压缩后返回
        FileInputStream inputStream = null;
        byte arr[] = null;
        try {
            inputStream = new FileInputStream(file);
            arr = new byte[inputStream.available()];
            inputStream.read(arr);
        } catch (Exception e) {
            loggerUtils.error("读取错误：" + e.getMessage(), fileUtils.class);
        } finally {
            try {
                if (inputStream != null) {
                    inputStream.close();
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return arr;
    }

    public static byte[] readSourceTo64(String path) {
        return readSourceTo64(new File(path));
    }

    public static byte[] readSourceTo64(File f) {
        byte arr[] = readSource(f);
        if (arr != null)
            arr = Base64.getEncoder().encode(arr);
        return arr;
    }

    public static String readSourceTo64Str(String path) {
        byte arr[] = readSource(new File(path));
        String str = null;
        if (arr != null)
            str = Base64.getEncoder().encodeToString(arr);
        return str;
    }

    public static boolean delFile(File file) {
        if (!file.exists()) {
            return false;
        }

        if (file.isDirectory()) {
            File[] files = file.listFiles();
            for (File f : files) {
                delFile(f);
            }
        }
        return file.delete();
    }


    public static byte[] getByteIo(File file) {
        FileInputStream is = null;
        byte[] b = null;
        try {
            is = new FileInputStream(file);
            b = new byte[is.available()];
            while (is.read(b) > -1) {

            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                is.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return b;
    }

    /**
     * 读取id
     */
    public static byte[] getByteIo(String path) {
        return getByteIo(new File(path));
    }

    public static String readFile(String path) {
        FileInputStream is = null;
        Reader isr = null;
        BufferedReader br = null;
        StringBuilder res = new StringBuilder();
        try {
            is = new FileInputStream(new File(path));
            isr = new InputStreamReader(is, "utf-8");
            br = new BufferedReader(isr);
            String line = null;
            while (null != (line = br.readLine())) {
                res.append(line);
            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                br.close();
                isr.close();
                is.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return res.toString();
    }

    /**
     * 读取文件的一部分
     */

    public static void writeFile(byte[] data, String outPath, boolean isAppend) {
        File f = new File(outPath);
        if (!f.exists()) {
            try {
                f.createNewFile();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        FileOutputStream out = null;
        try {
            out = new FileOutputStream(f, isAppend);
            out.write(data);
            out.flush();
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                out.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    public static void writeFile(String data, String outPath, boolean isAppend) {
        writeFile(data.getBytes(), outPath, isAppend);
    }


}

