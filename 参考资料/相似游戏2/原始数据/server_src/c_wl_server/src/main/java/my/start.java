package my;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.socket.ServerSocketChannel;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.handler.codec.http.HttpObjectAggregator;
import io.netty.handler.codec.http.HttpRequestDecoder;
import io.netty.handler.codec.http.HttpResponseEncoder;
import my.data.equipData;
import my.utils.fileUtils;
import my.utils.loggerUtils;
import my.utils.staticCollection;
import my.utils.systemUtils;

import java.io.File;
import java.util.concurrent.TimeUnit;

import static my.utils.staticCollection.*;

public class start {
    public void app() {

        //启动前初始化一些必要的内存数据
        initSetting();
        //启动前添加一些必备组件
        if (!startBef.init()) {
            System.err.println("启动失败！");
        }


        //缓存资源文件
        //startBef.downloadService.loadSource(url + "/assets/wl/picout", assets);
        //生成资源索引
        //startBef.downloadService.createWlSourceIndex(wlSourceList);
        startBef.downloadService.createXqSourceIndex(xqSourceList);
        //System.err.println(sourceList);

        //System.err.println(assets);
        updateConfig();
        //开始启动逻辑
        ServerBootstrap boot = new ServerBootstrap();
        boot.group(acceptGroup, workerGroup).channel(NioServerSocketChannel.class)
                .childHandler(new ChannelInitializer<SocketChannel>() {
                    @Override
                    protected void initChannel(SocketChannel ch) throws Exception {
                        ch.pipeline()
                                .addLast("decoder", new HttpRequestDecoder())   // 1
                                .addLast("encoder", new HttpResponseEncoder())  // 2
                                .addLast("aggregator", new HttpObjectAggregator(512 * 1024))    // 3
                                .addLast("handler", new handle());
                    }
                }).option(ChannelOption.SO_BACKLOG, 1024)
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 5000);

        try {
            ChannelFuture future = boot.bind(port).sync();
            if (future.isSuccess()) {
                loggerUtils.info("服务已经启动/" + port, this.getClass());
                serverChannel = (ServerSocketChannel) future.channel();
                serverChannel.closeFuture().sync();
            } else {
                loggerUtils.error("绑定端口失败", this.getClass());
            }
        } catch (InterruptedException e) {
            loggerUtils.error("线程被终止", this.getClass());
            acceptGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();

        }
    }

    /**
     * 自动对比配置刷新
     */
    public void updateConfig() {
        staticCollection.putTask(() -> {
            try {
                String str = fileUtils.readFile(url + "version.json");
                JSONObject j = JSON.parseObject(str);
                if (!j.getString("apk").equals(apkVersion)) {
                    staticCollection.isAllowedReq = false;
                    apkVersion = j.getString("apk");
                    resVersion = j.getString("res");
                    noticeMsg = j.getJSONArray("notice");
                    //刷新怪物
                    /*monsterMap.clear();
                    String json = fileUtils.readFile(url + "monster.json");
                    JSONObject jb = JSON.parseObject(json);
                    //计算出高级属性
                    for (String key : jb.keySet()) {
                        JSONObject obj = jb.getJSONObject(key);
                        obj.put("prop", obj.getJSONObject("prop"));
                        monsterMap.put(key, obj);
                    }*/
                    //加载app.zip
                    //nmbApk = fileUtils.readSource(url + "nmb.apk");
                    //appZip = new String(Base64.getEncoder().encode(fileUtils.readSource(url + "nmb.apk")));
                    assets.clear();
                    //startBef.downloadService.loadSource(url + "/assets/wl/picout", assets);
                    //wlSourceList.clear();
                    //startBef.downloadService.createWlSourceIndex(wlSourceList);
                    xqSourceList.clear();
                    startBef.downloadService.createXqSourceIndex(xqSourceList);
                    staticCollection.isAllowedReq = true;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }, 10, 10, TimeUnit.SECONDS);
    }

    public void initSetting() {
        if (systemUtils.isWindows()) {
            url = "E:/xq-new/server/c_xq_server/c_wl_server/src/main/resources/";
            //线上
            if (!new File(url).exists()) {
                url = "D:/javaproj/c_wl_server/";
            }
        } else {
            url = "/home/wl/";
        }
        System.out.println("资源路径：" + url);
        if (apkVersion == null) {
            //System.err.println("url:" + url);
            String str = fileUtils.readFile(url + "version.json");
            JSONObject j = JSON.parseObject(str);
            apkVersion = j.getString("apk");
            resVersion = j.getString("res");
            noticeMsg = j.getJSONArray("notice");
            loggerUtils.info("加载version文件完成！", this.getClass());
        }
        //加载怪物
        /*if (monsterMap == null) {
            monsterMap = new HashMap<>();
            //读取json文件
            String json = fileUtils.readFile(url + "monster.json");
            JSONObject j = JSON.parseObject(json);
            //计算出高级属性
            for (String key : j.keySet()) {
                JSONObject obj = j.getJSONObject(key);
                obj.put("prop", obj.getJSONObject("prop"));
                monsterMap.put(key, obj);
            }
            loggerUtils.info("加载monster文件完成！", this.getClass());
        }*/
        //加载app.zip
        //appZip = new String(Base64.getEncoder().encode(fileUtils.readSource(url + "nmb.apk")));
        //nmbApk = fileUtils.readSource(url + "nmb.apk");
        loggerUtils.info("加载nmb.apk完成！", this.getClass());

    }


    public static void main(String[] args) {
        new start().app();
    }
}
