package my;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import io.netty.buffer.Unpooled;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.SimpleChannelInboundHandler;
import io.netty.handler.codec.http.*;
import io.netty.handler.codec.http.websocketx.*;
import my.anno.paramsAnno;
import my.db.mybatisConfig;
import my.model.ChannelSupervise;
import my.model.result;
import my.model.user;
import my.utils.*;
import org.apache.ibatis.session.SqlSession;

import java.io.File;
import java.io.UnsupportedEncodingException;
import java.lang.annotation.Annotation;
import java.net.InetSocketAddress;
import java.net.URL;
import java.net.URLDecoder;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static my.utils.staticCollection.url;

public class handle extends SimpleChannelInboundHandler<Object> {

    private WebSocketServerHandshaker handshaker;

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, Object msg) throws Exception {
        if (!staticCollection.isAllowedReq) {
            //ctx.close();
            return;
        }
        if (!isLocalReq(ctx)) {
            if (msg instanceof FullHttpRequest && isToolCheck((FullHttpRequest) msg, ctx)) {
                ctx.close();
                return;
            }
        }
        //loggerUtils.info("收到消息：" + msg, this.getClass());
        if (msg instanceof FullHttpRequest) {
            //System.err.print(getIP(ctx));
            handleHttpRequest(ctx, (FullHttpRequest) msg);
        } else if (msg instanceof WebSocketFrame) {
            handlerWebSocketFrame(ctx, (WebSocketFrame) msg);
        }
    }

    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {

    }

    @Override
    public void channelInactive(ChannelHandlerContext ctx) throws Exception {
        user user = staticCollection.getUserByChannelId(ctx.channel().id());
        if (user != null) {
            final String name = user.name;
            startBef.teamService.handleOffLine(name);
            startBef.logService.offLine(name);
            startBef.prisonService.updateTotal(name);
            user.offLine();
        }
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        if (systemUtils.isWindows())
            cause.printStackTrace();
        //loggerUtils.error(cause.getMessage(), this.getClass());
    }

    @Override
    public void channelReadComplete(ChannelHandlerContext ctx) throws Exception {
        ctx.flush();
    }

    private StringBuilder sb;

    private void handlerWebSocketFrame(ChannelHandlerContext ctx, WebSocketFrame frame) {
        if (frame instanceof CloseWebSocketFrame) {
            handshaker.close(ctx.channel(), (CloseWebSocketFrame) frame.retain());
            return;
        }
        if (frame instanceof PingWebSocketFrame) {
            ctx.channel().write(
                    new PongWebSocketFrame(frame.content().retain()));
            return;
        }
        if (frame instanceof TextWebSocketFrame) {
            loggerUtils.info("不支持非二进制消息", this.getClass());
            return;
        }
        if (frame instanceof BinaryWebSocketFrame) {
            sb = new StringBuilder(frame.content().toString(Charset.defaultCharset()));
        } else if (frame instanceof ContinuationWebSocketFrame) {
            if (sb != null) {
                sb.append(frame.content().toString(Charset.defaultCharset()));
            } else {
                System.err.println("byteBuf为null");
            }
        }
        if (!frame.isFinalFragment()) {
            return;
        }
        try {
            if (sb.substring(0, 5).equals("10086")) {
                //语音只base64解码
                sb.replace(0, 5, "");
                sb.replace(0, sb.length(), new String(strUtils.B64Decoder(sb.toString()), Charset.defaultCharset()));
            } else {
                String des = new String(strUtils.B64Decoder(sb.toString()), Charset.defaultCharset());
                sb.replace(0, sb.length(), DESUtils.DecodeDES(des, DESUtils.DESKEY_WS));
            }
        } catch (Exception e) {
            e.printStackTrace();
            sb.delete(0, sb.length());
            return;
        }
        JSONObject params = null;
        try {
            params = JSON.parseObject(sb.toString());
        } catch (Exception e) {
            e.printStackTrace();
            //System.out.println(sb);
            return;
        }
        sb.delete(0, sb.length());

        if (!params.getString("url")
                .contains("/chatService/sendLeaveAudio") &&
                !params.getString("url")
                        .contains("/chatService/getLeaveAudio")
                && (isSameReq(params, ctx) || handleLimit(ctx))) {
            //backRes(new result(0), ctx, true);
            return;
        }
        //调取服务
        Object res = toService(params, ctx);

    }


    private void handleHttpRequest(ChannelHandlerContext ctx,
                                   FullHttpRequest req) {
        if (!req.decoderResult().isSuccess()
                || (!"websocket".equals(req.headers().get("Upgrade")))) {
            sendHttpResponse(ctx, req, new DefaultFullHttpResponse(
                    HttpVersion.HTTP_1_1, HttpResponseStatus.BAD_REQUEST));
            return;
        }
        String[] q = req.uri().split("[?]")[1].split("&");
        if (q.length != 4 || staticCollection.authMap.get(q[1]) == null ||
                !staticCollection.authMap.get(q[1]).isPass(q[0], getIP(ctx))) {
            return;
        }

        WebSocketServerHandshakerFactory wsFactory = new WebSocketServerHandshakerFactory(
                "ws://localhost:9666/qwe", null, false);
        handshaker = wsFactory.newHandshaker(req);
        if (handshaker == null) {
            WebSocketServerHandshakerFactory
                    .sendUnsupportedVersionResponse(ctx.channel());
        } else {
            staticCollection.authMap.remove(q[1]);
            user user = staticCollection.userMap.get(q[2]);
            user.channelId = ctx.channel().id();
            user.projRootDir = q[3];
            handshaker.handshake(ctx.channel(), req);
            ChannelSupervise.addChannel(ctx.channel());
            //上线通知队伍状态变更
            startBef.teamService.handleOnLine(user.name);
            //上线处理是否处于战斗
            startBef.fightRpcService.reloadFight(user.name);
            //System.err.println("加入连接" + staticCollection.userMap);
        }
    }

    /**
     * 拒绝不合法的请求，并返回错误信息
     */
    private void sendHttpResponse(ChannelHandlerContext ctx,
                                  FullHttpRequest req, DefaultFullHttpResponse resp) {
        String uri = req.uri();
        if (uri.equals("/favicon.ico")) {
            backRes(new result(0), ctx, false);
            return;
        }
        if (req.method().name().equals("OPTIONS")) {
            backRes(new result(200), ctx, false);
            return;
        }
        //请求获取文件大小
        /*if (req.method().name().equals("HEAD")) {
            backFileSize(uri, ctx);
            return;
        }*/

        //请求服务器信息
        if (uri.contains("/getOsMsg")) {
            String str = req.content().toString(Charset.defaultCharset());
            JSONObject o = startBef.sysService.getOsMsg(str.split("=")[1]);
            backRes(o, ctx, false);
            return;
        } else if (uri.contains("/someLogger")) {
            String str = req.content().toString(Charset.defaultCharset());
            JSONObject o = startBef.sysService.someLogger(str.split("=")[1]);
            backRes(o, ctx, false);
            return;
        } else if (uri.contains("/checkDataException")) {
            String str = req.content().toString(Charset.defaultCharset());
            JSONObject o = startBef.sysService.checkDataException(str.split("=")[1]);
            backRes(o, ctx, false);
            return;
        } else if (uri.contains("/putLog")) {
            try {
                System.err.println(URLDecoder.decode(uri, "utf-8"));
            } catch (UnsupportedEncodingException e) {
                throw new RuntimeException(e);
            }
            backRes(new result(0), ctx, false);
            return;
        }

        //处理请求资源
        if (backAssets(uri, ctx)
                || backModel(uri, ctx)
                || backAssetsToPhone(uri, ctx)
                || backXqAssetsPath(uri, ctx)
                || verifyApkVersion(uri, ctx)
                || verifyDllVersion(uri, req, ctx)
                || backAssetsDll(uri, req, ctx)) {
            return;
        }



        StringBuilder json = new StringBuilder(
                req.content().toString(Charset.defaultCharset()).
                        replaceAll("@", "+"));
        if (json.length() == 0) {
            backRes(new result(0), ctx, true);
            return;
        }

        if (json.toString().getBytes().length > 1024 * 10) {
            json.delete(0, json.length());
            backRes(new result(0), ctx, true);
            return;
        }
        try {
            String des = new String(strUtils.B64Decoder(json.toString()), Charset.defaultCharset());
            json.replace(0, json.length(),
                    DESUtils.DecodeDES(des, DESUtils.DESKEY_SIMPLE));
        } catch (Exception e) {
            loggerUtils.error(e.getMessage(), this.getClass());
            backRes(new result(0), ctx, true);
            return;
        }
        //System.err.println(json.toString());

        JSONObject params = JSON.parseObject(json.toString());
        json.delete(0, json.length());
        if (params.get("url") == null || params.get("created") == null) {
            backRes(new result(0), ctx, true);
            return;
        }
        long now = strUtils.getTime();
        boolean b = ((now - params.getLong("created") < 10000) && (now - params.getLong("created") >= -10000));
        if (!b) {
            json.delete(0, json.length());
            backRes(new result(0), ctx, true);
            return;
        }

        //对于非登录接口的路径，必须有设备号、并且设备号已经保存到map的才会放行
        if (!params.get("url").equals("/loginService/matchVersion") &&
                !params.getString("url").contains("/downloadService/") &&
                !params.get("url").equals("/loginService/login") &&
                !params.get("url").equals("/sysService/getCode") &&
                !params.get("url").equals("/sysService/matchCode") &&
                !params.get("url").equals("/loginService/createRole") &&
                !params.get("url").equals("/loginService/getCode") &&
                !params.get("url").equals("/loginService/openVerify")
                && (params.get("sbh") == null ||
                staticCollection.userMap.get(params.get("sbh")) == null)) {
            backRes(new result(0), ctx, true);
            return;
        }
        if (isSameReq(params, ctx) || handleLimit(ctx)) {
            backRes(new result(-2), ctx, true);
            return;
        }

        Object res = toService(params, ctx);
        if (res != null) {
            backRes(res, ctx, true);
        } else {
            backRes(new result(0), ctx, true);
        }
    }

    private boolean isToolCheck(FullHttpRequest req, ChannelHandlerContext ctx) {
        String agent = req.headers().get("user-agent");
        if (agent != null && (agent.contains("TuanjiePlayer") ||
                agent.contains("UnityPlayer"))) {
            return false;
        }
        if (agent == null || agent.contains("curl/")
                || agent.contains("python") || agent.contains("postman")
                || (agent.contains("(Windows") && !agent.contains("EgretWing/4.1.6"))
                || (agent.contains("(Linux") && !agent.contains("Android"))
                || agent.contains("(Mac OS")
                || (!agent.contains("Android") && !agent.contains("EgretWing/4.1.6"))) {
            return true;
        }
        return false;
    }

    private Object toService(JSONObject params, ChannelHandlerContext ctx) {
        user u = null;
        if (params.get("sbh") != null) {
            u = staticCollection.userMap.get(params.get("sbh"));
            if (!u.ip.equals(getIP(ctx))) {
                return null;
            }
        }
        String urls[] = params.getString("url").split("/");
        if (urls.length != 3) {
            return null;
        }
        SqlSession con = null;
        try {
            List objs = new ArrayList();
            if (params.get("json") != null) {
                objs.add(params.getJSONObject("json"));
            }

            Annotation[][] annotations = classUtils.getAnno(urls[1], urls[2]);
            if (annotations == null) {
                return null;
            }
            for (int i = 0; i < annotations.length; i++) {
                for (int j = 0; j < annotations[i].length; j++) {
                    if (annotations[i][j] instanceof paramsAnno) {
                        paramsAnno param = (paramsAnno) annotations[i][j];
                        if (param.key().equals("ip") && param.value()) {
                            objs.add(getIP(ctx));
                        }
                        if (param.key().equals("user") && param.value()) {
                            objs.add(u);
                        }
                        if (param.key().equals("con") && param.value()) {
                            con = mybatisConfig.getSqlSession();
                            objs.add(con);
                        }
                    }
                }
            }
            Object res = startBef.invokeMethod(urls[1],
                    urls[2], objs);
            if (con != null) {
                try {
                    mybatisConfig.commit(con);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
            return res;
        } catch (Exception e) {
            e.printStackTrace();
            if (con != null) {
                mybatisConfig.rollback(con);
            }
        } finally {
            if (con != null) {
                mybatisConfig.close(con);
            }
        }
        return null;
    }


    private boolean handleLimit(ChannelHandlerContext ctx) {
        String ip = getIP(ctx);
        long time = strUtils.getTime();
        if (isLimit(ip)) {
            JSONObject obj = staticCollection.ipMap.get(ip);
            obj.put("time", time);
            obj.put("num", obj.getInteger("num") + 1);
            //System.err.println(obj.getInteger("num"));
            if (obj.getInteger("num") > 30) {
                obj.put("time", obj.getLong("time") + 1000 * 10);
                staticCollection.ipMap.put(ip, obj);
                return true;
            }
            staticCollection.ipMap.put(ip, obj);
        } else {
            JSONObject obj = new JSONObject();
            obj.put("time", time);
            obj.put("num", 1);
            staticCollection.ipMap.put(ip, obj);
        }
        return false;
    }

    public boolean isLimit(String ip) {
        JSONObject obj = staticCollection.ipMap.get(ip);
        if (staticCollection.ipMap.get(ip) == null ||
                strUtils.getTime() - obj.getLong("time") > 1000) {
            return false;
        }
        return true;
    }

    private boolean isSameReq(JSONObject params, ChannelHandlerContext ctx) {
        String real = params.get("sbh") + "/" + getIP(ctx)
                + params.get("url");
        if (staticCollection.sameReqMap.get(real) == null) {
            staticCollection.sameReqMap.put(real, strUtils.getTime());
            ctx.channel().eventLoop().schedule(() -> {
                try {
                    staticCollection.sameReqMap.remove(real);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }, 200, TimeUnit.MILLISECONDS);
        } else {
            return true;
        }
        return false;
    }

    public void backRes(Object res, ChannelHandlerContext ctx, boolean isRsa) {
        StringBuilder sb = new StringBuilder(JSON.toJSONString(res));
        if (isRsa) {
            try {
                //byte [] a=strUtils.B64Encoder(sb.toString().getBytes("UTF-8")).getBytes("UTF-8");
                byte[] a = DESUtils.EncodeDES(sb.toString(), DESUtils.DESKEY_SIMPLE);
                sb.replace(0, sb.length(), new String(a));
                /*sb.replace(0, sb.length(), RSAUtils.encrypt(Base64.encodeBase64String((sb.toString()).getBytes()),
                        RSAUtils.getPublicKey(RSAUtils.publicClientKey)));*/
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        DefaultFullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1,
                HttpResponseStatus.OK,
                Unpooled.wrappedBuffer(sb.toString().getBytes())); // 2
        sb.delete(0, sb.length());
        HttpHeaders heads = response.headers();
        heads.add(HttpHeaderNames.CONTENT_TYPE, HttpHeaderValues.APPLICATION_X_WWW_FORM_URLENCODED + "; charset=UTF-8");
        heads.add(HttpHeaderNames.CONTENT_LENGTH, response.content().readableBytes()); // 3
        heads.add(HttpHeaderNames.CONNECTION, HttpHeaderValues.KEEP_ALIVE);
        heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
        //heads.set(ACCESS_CONTROL_ALLOW_HEADERS, "token");//允许headers自定义
        heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_METHODS, "GET,POST");
        heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_CREDENTIALS, "true");

        ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
    }



    private boolean backXqAssetsPath(String uri, ChannelHandlerContext ctx) {
        if (!uri.contains("/xqAssetsPath")) {
            return false;
        }
        //todo：启动时就要对所有资源文件记录大小，
        // 但初次下载时只需下载一些基础文件

        byte[] bytes = new String(java.util.Base64.getEncoder()
                .encode(JSON.toJSONBytes(staticCollection.xqSourceList))).getBytes();
        DefaultFullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1,
                HttpResponseStatus.OK, Unpooled.wrappedBuffer(bytes));
        HttpHeaders heads = response.headers();
        heads.add(HttpHeaderNames.CONTENT_TYPE, "text/plain");
        heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
        ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
        return true;
    }

    /**
     * 验证apk版本
     */
    private boolean verifyApkVersion(String uri, ChannelHandlerContext ctx) {
        if (!uri.contains("/verifyApkVersion?")) {
            return false;
        }
        String version = uri.split("[?]")[1].replace("v=", "");
        byte[] bytes = null;
        if (version.equals(staticCollection.apkVersion)) {
            bytes = "0".getBytes();
        } else {
            bytes = (staticCollection.nmbApk.length + "").getBytes();
        }
        DefaultFullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1,
                HttpResponseStatus.OK, Unpooled.wrappedBuffer(bytes));
        HttpHeaders heads = response.headers();
        heads.add(HttpHeaderNames.CONTENT_TYPE, "text/plain");
        heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
        ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
        return true;
    }

    /**
     * 加载js、html压缩包-手机端使用
     */
    private boolean backAssetsToPhone(String uri, ChannelHandlerContext ctx) {
        if (!uri.contains("/download?")) {
            return false;
        }
        String version = uri.split("[?]")[1].replace("v=", "");
        byte[] bytes = null;
        if (version.equals(staticCollection.apkVersion)) {
            bytes = new byte[0];
        } else {
            bytes = staticCollection.nmbApk;
        }
        DefaultFullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1,
                HttpResponseStatus.OK, Unpooled.wrappedBuffer(bytes));
        HttpHeaders heads = response.headers();
        heads.add(HttpHeaderNames.CONTENT_TYPE, "text/plain");
        heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
        ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
        return true;
    }

    /**
     * 验证dll版本
     */
    private boolean verifyDllVersion(String uri, FullHttpRequest req, ChannelHandlerContext ctx) {
        if (!uri.contains("/verifyDllVersion?")) {
            return false;
        }
        String cpi = req.headers().get("user-agent");
        if (strUtils.isNull(cpi)) {
            ctx.close();
            return true;
        }
        String dir = "dll";
        if (cpi.equals("UnityPlayer-Pc")) {
            dir = "dll_win";
        }
        String key = uri.split("[?]")[1].split("&")[0].replace("k=", "");
        byte[] bytes = fileUtils.readSource(url + "/assets/" + dir + "/" + key);
        //只返回dll大小
        bytes = (bytes.length + "").getBytes();
        DefaultFullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1,
                HttpResponseStatus.OK, Unpooled.wrappedBuffer(bytes));
        HttpHeaders heads = response.headers();
        heads.add(HttpHeaderNames.CONTENT_TYPE, "text/plain");
        heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
        ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
        return true;
    }

    /**
     * 返回热更代码的dll
     */
    private boolean backAssetsDll(String uri, FullHttpRequest req, ChannelHandlerContext ctx) {
        if (!uri.contains("/dll?")) {
            return false;
        }
        String cpi = req.headers().get("user-agent");
        if (strUtils.isNull(cpi)) {
            ctx.close();
            return true;
        }
        String dir = "dll";
        if (cpi.equals("UnityPlayer-Pc")) {
            dir = "dll_win";
        }
        String key = uri.split("[?]")[1].split("&")[0].replace("k=", "");
        byte[] bytes = fileUtils.readSource(url + "/assets/" + dir + "/" + key);
        //bytes = fileUtils.encodeBytes(bytes, "_jkl.1997");
        DefaultFullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1,
                HttpResponseStatus.OK, Unpooled.wrappedBuffer(bytes));
        HttpHeaders heads = response.headers();
        heads.add(HttpHeaderNames.CONTENT_TYPE, "text/plain");
        heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
        ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
        return true;
    }

    /**
     * 返回资源文件-pc端使用
     */
    private boolean backAssets(String uri, ChannelHandlerContext ctx) {
        if (!uri.contains("/part1?")) {
            return false;
        }
        String[] arr = uri.split("[?]")[1].split("&");
        String key = arr[0].replace("k=", "");
        try {
            //byte[] bytes = strUtils.encodeB64((byte[]) staticCollection.assets.get(key).get("bytes"));
            byte[] bytes = null;
            //"/part1?k=" + name + "&t=1" + "&p" + sysUtils.projRootDir
            String p = arr[2].replace("p=", "");
            //直接读取项目节点内的picout，已经加密过了
            String path = url + "/assets/" + p + "/picout/" + key;
            bytes = fileUtils.readSource(path);

            DefaultFullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1,
                    HttpResponseStatus.OK, Unpooled.wrappedBuffer(bytes));
            HttpHeaders heads = response.headers();
            heads.add(HttpHeaderNames.CONTENT_TYPE, "text/plain");
            //heads.add(HttpHeaderNames.CONTENT_LENGTH, bytes.length);
            heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
            ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
        } catch (Exception e) {
            if (systemUtils.isWindows()) {
                System.err.println("找不到资源：" + uri);
            }
            backBad(ctx);
        }
        return true;
    }

    /**
     * 返回模型资源的真实路径
     */
    private String handleModelDir(String uri) {
        if (!strUtils.isAbReq(uri)) {
            return null;
        }
        String[] arr = uri.split("[?]")[1].split("&");
        String a = arr[1].replace("a=", "");
        if (a.equals("android")) {
            a = "androidBundle";
        } else if (a.equals("web") || a.equals("bundle")) {

        } else {
            return null;
        }
        String k = arr[0].replace("k=", "");
        String p = arr[2].replace("p=", "");
        return staticCollection.url + "assets/" + p + "/" + a + "/" + k;
    }

    /**
     * 返回模型素材
     */
    private boolean backModel(String uri, ChannelHandlerContext ctx) {
        String path = handleModelDir(uri);
        if (path == null) {
            return false;
        }
        try {
            byte[] bytes = fileUtils.getByteIo(path);
            //byte[] bytes = strUtils.encodeB64((byte[]) staticCollection.assets.get(key).get("bytes"));
            //byte[] bytes = (byte[]) staticCollection.assets.get(key).get("bytes");
            DefaultFullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1,
                    HttpResponseStatus.OK, Unpooled.wrappedBuffer(bytes));
            HttpHeaders heads = response.headers();
            heads.add(HttpHeaderNames.CONTENT_TYPE, "text/plain");
            heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
            ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
        } catch (Exception e) {
            System.err.println("找不到：" + uri);
            backBad(ctx);
        }
        return true;
    }

    private void backBad(ChannelHandlerContext ctx) {
        DefaultFullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1,
                HttpResponseStatus.BAD_REQUEST);
        HttpHeaders heads = response.headers();
        heads.add(HttpHeaderNames.CONTENT_TYPE, "text/plain");
        heads.set(HttpHeaderNames.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
        ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
    }


    private String getIP(ChannelHandlerContext ctx) {
        InetSocketAddress insocket = (InetSocketAddress) ctx.channel().remoteAddress();
        return insocket.getAddress().getHostAddress();
    }

    private String getLocalIP(ChannelHandlerContext ctx) {
        InetSocketAddress insocket = (InetSocketAddress) ctx.channel().localAddress();
        return insocket.getAddress().getHostAddress();
    }

    private boolean isLocalReq(ChannelHandlerContext ctx) {
        if (getIP(ctx).equals(getLocalIP(ctx))) {
            return true;
        }
        return false;
    }
}

