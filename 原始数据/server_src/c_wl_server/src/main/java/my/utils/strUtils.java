package my.utils;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import com.google.common.io.BaseEncoding;
import org.apache.commons.codec.binary.Base64;

import java.io.ByteArrayOutputStream;
import java.io.UnsupportedEncodingException;
import java.math.BigInteger;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.regex.Pattern;
import java.util.zip.DataFormatException;
import java.util.zip.Deflater;
import java.util.zip.Inflater;

public class strUtils {
    private static Random rd = new Random();

    /**
     * 从数组中获取相同的字符串的index
     */
    public static int getArrContainIndex(Object str, Object[] arr) {
        for (int i = 0; i < arr.length; i++) {
            if ((arr[i].toString()).equals(str + "")) return i;
        }
        return -1;
    }


    /**
     * 是否为ab包请求路径
     */
    public static boolean isAbReq(String uri) {
        if (!uri.contains("/getAB?")) {
            return false;
        }
        return true;
    }

    /**
     * 是否为ab包目录
     */
    public static boolean isAbDir(String name) {
        /*if (name.equals("effect")
                || name.equals("font")
                || name.equals("player")
                || name.equals("shader")
                || name.equals("sky")
                || name.equals("title")
                || name.equals("wings")
                || name.equals("mapprefab")
                || name.equals("mapres")
                || name.equals("mapsource")) {
            return true;
        }*/
        return true;
    }

    /**
     * 正则匹配
     * reg 400([0-9]{1})
     */
    public static boolean isMatch(String str, String reg) {
        if (Pattern.matches(reg, str)) {
            return true;
        }
        return false;
    }

    public static byte[] B64Decoder(String b64) {
        return BaseEncoding.base64().decode(b64);
    }

    public static byte[] B64DecoderUrl(String b64) {
        return BaseEncoding.base64Url().decode(b64);
    }

    public static String B64Encoder(byte[] data) {
        return BaseEncoding.base64().encode(data);
    }

    public static String B64EncoderUrl(byte[] data) {
        return BaseEncoding.base64Url().encode(data);
    }



    /**
     * 从某个区间取值后等于某个随机数
     */
    public static boolean numInArea(int input, int start, int end) {
        int i = getRandom(start, end);
        if (i == input) return true;
        return false;
    }

    /**
     * 从某个区间取一个数(不包含end)
     */
    public static int getRandom(int start, int end) {
        return rd.nextInt(end - start) + start;
    }

    public static float getRandomFloat(float start, float end) {
        return Double.valueOf(Math.random()).floatValue() * (end - start) + start;
    }

    /**
     * 迭代式获取随机，跟一个集合比较
     * arr需要比较的集合
     * 注意：当arr中包含所有的start-end后会出现死循环
     */
    public static Integer getRandom(int start, int end, JSONArray arr) {
        int[] brr = new int[arr.size()];
        int num = 0;
        for (int i = 0; i < arr.size(); i++) {
            int k = arr.getInteger(i);
            brr[i] = k;
            if (k >= start && k < end) num++;
        }
        if (num >= (end - start)) {
            return null;
        }
        return getRandom(start, end, brr);
    }

    private static int getRandom(int start, int end, int[] arr) {
        int a = rd.nextInt(end - start) + start;
        boolean b = false;
        for (int n : arr) {
            if (a == n) {
                b = true;
                break;
            }
        }
        if (b) {
            //重复了就再重新取
            return getRandom(start, end, arr);
        }
        return a;
    }

    /**
     * 随机生成一个数，判断是否在这个范围内
     *
     * @param start
     * @param end
     * @return
     */
    public static boolean isHappend(int start, int end, Float probability) {
        if (probability >= 1) return true;
        else if (probability <= 0) return false;
        Float n = (end - start) * probability;
        int p = rd.nextInt(end) + start;
        if (p < n) {
            return true;
        }
        return false;
    }

    /**
     * 判断是否在两时间点之间
     */
    public static boolean isInTwoTime(long start, long end) {
        long a = new Date().getTime();
        if (a >= start && a <= end) {
            return true;
        }
        return false;
    }

    public static String getNowDateStr() {
        long a = new Date().getTime();
        SimpleDateFormat simpleDateFormat = new
                SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        return simpleDateFormat.format(a);
    }

    /**
     * 获取当月有多少天
     */
    public static int getNowMonDays() {
        return getDaysByDate(getNowDateStr());
    }

    /**
     * 获取某月有多少天2012-10
     */
    public static int getDaysByDate(String dateStr) {
        int year = Integer.parseInt(dateStr.substring(0, 4));
        int month = Integer.parseInt(dateStr.substring(5, 7));
        Calendar c = Calendar.getInstance();
        c.set(year, month, 0);
        return c.get(Calendar.DAY_OF_MONTH);
    }

    /**
     * 判断当前时间点是否在某个时间段内
     * hour 0-24
     *
     * @return
     */
    public static boolean isInTime(int hour0, int min0, int hour1, int min1) {
        long a = new Date().getTime();
        SimpleDateFormat simpleDateFormat = new
                SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        String dateTime = simpleDateFormat.format(a);
        Calendar calendar = Calendar.getInstance();
        try {
            Date date = simpleDateFormat.parse(dateTime);
            calendar.setTime(date);
            calendar.add(Calendar.DATE, 0);
            calendar.set(Calendar.HOUR_OF_DAY, hour0);
            calendar.set(Calendar.MINUTE, min0);
            calendar.set(Calendar.SECOND, 0);
        } catch (ParseException e) {
            System.out.println("Date format error!!!!");
        }
        long b0 = calendar.getTime().getTime();
        calendar.add(Calendar.DATE, 0);
        calendar.set(Calendar.HOUR_OF_DAY, hour1);
        calendar.set(Calendar.MINUTE, min1);
        calendar.set(Calendar.SECOND, 0);
        long b1 = calendar.getTime().getTime();
        if (a > b0 && a < b1) {
            return true;
        }
        return false;
    }

    /**
     * 判断是周几
     * 1是星期日 2星期一。。。7星期六
     */
    public static boolean isWKS(int i) {
        Calendar instance = Calendar.getInstance();
        if (instance.get(Calendar.DAY_OF_WEEK) == i) {
            return true;
        }
        return false;
    }




    /**
     * 判断距离某日相隔几天
     * str0 开始的日期
     */
    public static long disDay(String str0) {
        long a = new Date().getTime();
        SimpleDateFormat simpleDateFormat = new
                SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        long day = 0;
        try {
            long b0 = simpleDateFormat.parse(str0).getTime();
            day = (a - b0) / 1000 / 60 / 60 / 24;
        } catch (ParseException e) {
            e.printStackTrace();
        }
        return day;
    }

    /**
     * 判断当前时间是否处于两个日期之间
     */
    public static boolean isInDay(String str0, String str1) {
        long a = new Date().getTime();
        SimpleDateFormat simpleDateFormat = new
                SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        try {
            long b0 = simpleDateFormat.parse(str0).getTime();
            long b1 = simpleDateFormat.parse(str1).getTime();
            if (a > b0 && a < b1) {
                return true;
            }
        } catch (ParseException e) {
            e.printStackTrace();
        }
        return false;
    }

    /**
     * 是否为半点
     */
    public static boolean isBanTime() {
        Calendar now = Calendar.getInstance();
        int min = now.get(Calendar.MINUTE);
        int sec = now.get(Calendar.SECOND);
        //定时器是每10s调一次
        if (min % 30 == 0 && sec >= 0 && sec < 10) {
            return true;
        }
        return false;
    }

    /**
     * 是否为整点
     */
    public static boolean isWholeTime() {
        Calendar now = Calendar.getInstance();
        int min = now.get(Calendar.MINUTE);
        int sec = now.get(Calendar.SECOND);
        if (min == 0 && sec >= 0 && sec < 10) {
            return true;
        }
        return false;
    }

    public static String getId() {
        StringBuilder sb = new StringBuilder(getTime() + "");
        for (int i = 0; i < 3; i++) {
            sb.append(rd.nextInt(10));
        }
        return sb.toString();
    }

    public static long getTime() {
        return new Date().getTime();
    }

    public static boolean isNull(Object str) {
        if (str == null || ((String) str).trim().equals("")) {
            return true;
        }
        return false;
    }
    public static boolean isOverMax50(Object str) {
        if (str == null || ((String) str).length()>50) {
            return true;
        }
        return false;
    }

    /**
     * 判断能否转数字
     */
    public static boolean canParseInt(String str) {
        if (str == null) { //验证是否为空
            return false;
        }
        return str.matches("\\d+"); //使用正则表达式判断该字符串是否为数字，第一个\是转义符，\d+表示匹配1个或 //多个连续数字，"+"和"*"类似，"*"表示0个或多个

    }














}
