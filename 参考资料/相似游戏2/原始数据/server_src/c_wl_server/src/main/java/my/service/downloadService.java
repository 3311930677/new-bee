package my.service;

import com.alibaba.fastjson2.JSONObject;
import my.model.result;
import my.utils.*;

import java.io.File;
import java.util.*;

import static my.utils.staticCollection.assets;
import static my.utils.staticCollection.url;

/**
 * 下载服务
 */
public class downloadService {
    /**
     * 获取更新js部分，一个压缩包
     * 压缩内容包括：
     * index.html,jszip.min.js,part1.ceo (发包时自带字体文件，无需更新)
     * 下载后写入安卓缓存即可
     */
    public result getPart1(JSONObject j) {
        //版本一致无需更新
        if (staticCollection.apkVersion.equals(j.getString("apkVersion"))) {
            return new result(200, 0);
        }
        //返回的是经过b64压缩的数据
        return new result(200, staticCollection.appZip);
    }

    /**
     * 返回资源目录
     */
    /*public result getAssets() {
        List list = new ArrayList();
        for (String k : staticCollection.assets.keySet()) {
            Map<String, Object> map = staticCollection.assets.get(k);
            Map<String, Object> temp = new HashMap<>();
            temp.put("key", k);
            temp.put("path", map.get("path"));
            temp.put("size", map.get("size"));
            list.add(temp);
        }
        return new result(200, list);
    }*/

    /**
     * 获取资源文件的key
     */
    /*public result getAssetsKey() {
        loadSource(url + "/assets/wl/picout", assets);
        List list = new ArrayList();
        for (String k : staticCollection.assets.keySet()) {
            list.add(k);
        }
        return new result(200, list);
    }*/

    /**
     * 将资源文件缓存
     */
    /*public void loadSource0(String path, Map<String, Map<String, Object>> my) {
        File file = new File(path);
        for (File f : file.listFiles()) {
            if (f.isDirectory() &&
                    !f.getName().contains("login")
                    && !f.getName().contains("data")
                    && !f.getName().contains("props")
                    && !f.getName().contains("skill")) continue;
            if (f.isDirectory()) {
                loadSource(f.getPath(), my);
            } else {
                String[] t = f.getName().split("[.]");
                String name = t[0] + "_" + t[1];
                Map<String, Object> map = new HashMap<>();
                map.put("path", f.getPath());
                //保存转b64
                byte[] bytes = null;
                String suf = f.getName().substring(f.getName().length() - 4);
                if (suf.contains(".png") ||
                        suf.contains(".gif") ||
                        suf.contains(".jpg")) {
                    *//*if(systemUtils.isWindows()){
                        bytes=fileUtils.readSource(f);
                    }else {
                        bytes=imgUtils.compressPicByQuality(f);
                    }*//*
                    //如果是动画就不压缩
                    if (f.getName().contains("_zd.png")) {
                        bytes = fileUtils.readSource(f);
                    } else {
                        bytes = imgUtils.compressPicByQuality(f);
                    }
                } else {
                    bytes = fileUtils.readSource(f);
                }
                bytes = Base64.getEncoder().encode(bytes);
                map.put("bytes", bytes);
                map.put("size", bytes.length);
                my.put(name, map);
            }
        }
    }*/

    /**
     * 生成资源目录
     */
    public void createWlSourceIndex(List list) {
        source1(url + "/assets/wl/androidBundle", list);
        source2(url + "/assets/wl/picout", list);
    }

    public void createXqSourceIndex(List list) {
        source1(url + "/assets/xq2d/androidBundle", list);
        source2(url + "/assets/xq2d/picout", list);
    }

    /**
     * 所有模型资源索引
     */
    private void source1(String path, List list) {
        File file = new File(path);
        for (File f : file.listFiles()) {
            if (f.isDirectory() &&
                    !strUtils.isAbDir(f.getName())
            ) continue;
            if (f.isDirectory()) {
                source1(f.getPath(), list);
            } else {
                Map<String, Object> map = new HashMap<>();
                //key需要包含相对路径
                int index = f.getPath().indexOf("androidBundle");
                String key = f.getPath().substring(index + "androidBundle/".length()).replaceAll("\\\\","/");
                map.put("key", key);
                map.put("size", f.length());
                list.add(map);
            }
        }
    }

    /**
     * 所有图片资源索引
     */
    private void source2(String path, List list) {
        File file = new File(path);
        for (File f : file.listFiles()) {
            if (f.isDirectory()) {
                source2(f.getPath(), list);
            } else {
                Map<String, Object> map = new HashMap<>();
                map.put("key", f.getName());
                map.put("size", f.length());
                list.add(map);
            }
        }
    }


    /**
     * 只缓存图片资源，没有缓存模型
     */
    public void loadSource(String path, Map<String, Map<String, Object>> my) {
        File file = new File(path);
        for (File f : file.listFiles()) {
            if (f.isDirectory()) {
                loadSource(f.getPath(), my);
            } else {
                //已经由C#加密过了
                String name = f.getName();
                Map<String, Object> map = new HashMap<>();
                map.put("path", f.getPath());
                byte[] bytes = fileUtils.readSource(f);
                map.put("bytes", bytes);
                map.put("size", bytes.length);
                my.put(name, map);
            }
        }
    }
    /*public void loadSource(String path, Map<String, Map<String, Object>> my) {
        File file = new File(path);
        for (File f : file.listFiles()) {
            if (f.isDirectory() &&
                    !f.getName().contains("login")
                    && !f.getName().contains("props")
                    && !f.getName().contains("skill")
                    && !f.getName().contains("head")
                    && !f.getName().contains("card")
            ) continue;
            if (f.isDirectory()) {
                loadSource(f.getPath(), my);
            } else {
                String[] t = f.getName().split("[.]");
                String name = t[0] + "_" + t[1];
                Map<String, Object> map = new HashMap<>();
                map.put("path", f.getPath());
                byte[] bytes = null;
                *//*String suf = f.getName().substring(f.getName().length() - 4);
                if (suf.contains(".png") ||
                        suf.contains(".gif") ||
                        suf.contains(".jpg")) {
                    //如果是动画就不压缩
                    if (f.getName().contains("_zd.png")) {
                        bytes = fileUtils.readSource(f);
                    } else {
                        bytes = imgUtils.compressPicByQuality(f);
                    }
                } else {
                    bytes = fileUtils.readSource(f);
                }*//*
                bytes = fileUtils.readSource(f);
                //不采用base64，因为体积太大，直接保存byte
                //bytes = Base64.getEncoder().encode(bytes);
                //加密
                bytes = encodePics(bytes);
                map.put("bytes", bytes);
                map.put("size", bytes.length);
                my.put(name, map);
            }
        }
    }*/
}
