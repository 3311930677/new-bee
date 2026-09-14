package my.utils;

import javax.mail.*;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;
import java.util.*;

public class emailUtils {
    //CNLJBIGZSQPFEDLJ
    public static String random() {
        String s = "";
        for (int i = 0; i < 6; i++) {
            s += strUtils.getRandom(0, 10);
        }
        return s;
    }

    public static List<String> getAList() {
        String arr[] = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
                "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "s", "y", "z"
        };
        List<String> aList = new ArrayList<>(Arrays.asList(arr));
        Collections.shuffle(aList);
        return aList;
    }

    public static String getStr() {
        StringBuilder sb = new StringBuilder();
        List<String> aList = getAList();
        for (int i = 0; i < aList.size() / 3; i++) {
            sb.append(aList.get(i));
        }
        aList.clear();
        aList.addAll(getAList());
        for (int i = 0; i < aList.size() / 3; i++) {
            sb.append(aList.get(i));
        }
        aList.clear();
        aList.addAll(getAList());
        for (int i = 0; i < aList.size() / 3; i++) {
            sb.append(aList.get(i));
        }
        aList.clear();
        aList.addAll(getAList());
        for (int i = 0; i < aList.size() / 3; i++) {
            sb.append(aList.get(i));
        }
        aList.clear();
        return sb.toString();
    }

    /**
     * 发送验证码
     *
     * @param email
     * @return
     */
    public static String sendCode(String email) {
        final String str = random();
        staticCollection.putTask(() -> {
            //String a = RandomStringUtils.random(20, 0x4e00, 0x9fa5, false, false);
            try {
                String server = "smtp.qq.com";
                String port = "465";
                String address = "你的qq邮箱@qq.com";
                String secret = "qq邮箱第三方开发授权码（自己的qq邮箱上申请）";
                qqmsg(server, port, address, secret, getStr() + "===yan===zheng===ma===[" + str+"]", email);
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
        return str;
    }



    public static void qqmsg(String server, String port, String address, String secret,
                             String content, String email) throws MessagingException {

        //loggerUtils.info(email+"请求验证码：",emailUtils.class);
        final Properties props = new Properties();
        // 表示SMTP发送邮件，必须进行身份验证
        props.put("mail.smtp.auth", "true");
        //此处填写SMTP服务器
        props.put("mail.smtp.host", server);
        props.put("mail.smtp.starttls.enable", "true");
        //端口号，QQ邮箱给出了两个端口465或587 任选一个
        props.put("mail.smtp.port", port);
        //465额外配置===========
        props.put("mail.smtp.socketFactory.class", "javax.net.ssl.SSLSocketFactory"); // 使用JSSE的SSL
        // socketfactory来取代默认的socketfactory
        props.put("mail.smtp.socketFactory.fallback", "false"); // 只处理SSL的连接,对于非SSL的连接不做处理
        props.put("mail.smtp.socketFactory.port", port);
        props.put("mail.smtp.ssl.enable", true);
        //==============


        // 此处填写你的账号
        props.put("mail.user", address);
        // 16位STMP口令
        props.put("mail.password", secret);
        //465端口是为SMTPS（SMTP-over-SSL）协议服务开放的，这是SMTP协议基于SSL安全协议之上的一种变种协议。
        //props.put("mail.smtp.socketFactory.class", "javax.net.ssl.SSLSocketFactory");
        // 构建授权信息，用于进行SMTP进行身份验证
        Authenticator authenticator = new Authenticator() {
            protected PasswordAuthentication getPasswordAuthentication() {
                // 用户名、密码
                String userName = props.getProperty("mail.user");
                String password = props.getProperty("mail.password");
                return new PasswordAuthentication(userName, password);
            }
        };
        // 使用环境属性和授权信息，创建邮件会话
        Session mailSession = Session.getInstance(props, authenticator);
        // 创建邮件消息
        MimeMessage message = new MimeMessage(mailSession);
        // 设置发件人
        InternetAddress form = new InternetAddress(
                props.getProperty("mail.user"));
        message.setFrom(form);
        // 设置收件人的邮箱
        InternetAddress to = new InternetAddress(email);
        message.setRecipient(MimeMessage.RecipientType.TO, to);
        // 设置邮件标题
        StringBuilder title = new StringBuilder();
        List<String> aList = getAList();
        title.append(aList.get(0));
        title.append(aList.get(1));
        title.append(aList.get(2));
        title.append(aList.get(3));
        message.setSubject(title.toString());
        title.delete(0, title.length());
        message.setContent(content, "text/html;charset=UTF-8");
        // 发送邮件
        Transport.send(message);
        //loggerUtils.info(email+"已发送：",emailUtils.class);
    }
}
