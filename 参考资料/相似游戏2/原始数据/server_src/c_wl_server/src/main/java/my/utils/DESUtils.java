package my.utils;

import org.apache.commons.codec.digest.DigestUtils;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.DESKeySpec;
import javax.crypto.spec.IvParameterSpec;
import java.nio.charset.Charset;
import java.security.Key;
import java.security.Security;

public class DESUtils {
    static {
        Security.addProvider(new org.bouncycastle.jce.provider.BouncyCastleProvider());
    }

    public static final String CIPHER_ALGORITHM_ECB = "DES/ECB/PKCS7Padding";
    //ws的加密、解密key fixme 对称加密会被暴力破解
    public static final String DESKEY_WS = "9pc8.#ik";
    public static final String DESKEY_SIMPLE = "9pc8.#ik";

    private static Key toKey(byte[] key) throws Exception {
        DESKeySpec des = new DESKeySpec(key);
        SecretKeyFactory keyFactory = SecretKeyFactory.getInstance("DES");
        SecretKey secretKey = keyFactory.generateSecret(des);
        return secretKey;
    }

    /*public static byte[] encrypt(String data, String key) throws Exception {
        Key k = toKey(key.getBytes());
        Cipher cipher = Cipher.getInstance(CIPHER_ALGORITHM_ECB);
        cipher.init(Cipher.ENCRYPT_MODE, k);

        byte bs[] = cipher.doFinal(data.getBytes(Charset.forName("UTF-8")));
        return strUtils.B64Encoder(bs).getBytes(Charset.forName("UTF-8"));
        //return Base64.getEncoder().encode(cipher.doFinal(data.getBytes(Charset.forName("UTF-8"))));
    }

    public static String decrypt(String data, String key) throws Exception {
        Key k = toKey(key.getBytes());
        Cipher cipher = Cipher.getInstance(CIPHER_ALGORITHM_ECB);
        cipher.init(Cipher.DECRYPT_MODE, k);
        //fixme 注意：前端不用base64加密一次，本身是base64加密过的，后端直接解密就行
        return new String(cipher.doFinal(strUtils.B64Decoder(data)));
    }*/

    public static String DecodeDES(String message, String key) throws Exception {
        //将c#的数据转16进制byte
        byte[] bytesrc = convertHexString(message);
        Cipher cipher = Cipher.getInstance("DES/CBC/PKCS5Padding");
        DESKeySpec desKeySpec = new DESKeySpec(key.getBytes("UTF-8"));
        SecretKeyFactory keyFactory = SecretKeyFactory.getInstance("DES");
        SecretKey secretKey = keyFactory.generateSecret(desKeySpec);
        IvParameterSpec iv = new IvParameterSpec(key.getBytes("UTF-8"));
        cipher.init(Cipher.DECRYPT_MODE, secretKey, iv);
        byte[] retByte = cipher.doFinal(bytesrc);
        return new String(retByte);
    }

    public static byte[] EncodeDES(String message, String key) throws Exception {
        Cipher cipher = Cipher.getInstance("DES/CBC/PKCS5Padding");
        DESKeySpec desKeySpec = new DESKeySpec(key.getBytes("UTF-8"));
        SecretKeyFactory keyFactory = SecretKeyFactory.getInstance("DES");
        SecretKey secretKey = keyFactory.generateSecret(desKeySpec);
        IvParameterSpec iv = new IvParameterSpec(key.getBytes("UTF-8"));
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, iv);
        byte[] res=cipher.doFinal(message.getBytes("UTF-8"));
        return strUtils.B64Encoder(toHexString(res).getBytes()).getBytes("UTF-8");
        //return cipher.doFinal(message.getBytes("UTF-8"));
    }

    public static byte[] EncodeDES2(String message, String key) throws Exception {
        Cipher cipher = Cipher.getInstance("DES/CBC/PKCS5Padding");
        DESKeySpec desKeySpec = new DESKeySpec(key.getBytes("UTF-8"));
        SecretKeyFactory keyFactory = SecretKeyFactory.getInstance("DES");
        SecretKey secretKey = keyFactory.generateSecret(desKeySpec);
        IvParameterSpec iv = new IvParameterSpec(key.getBytes("UTF-8"));
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, iv);
        byte[] res=cipher.doFinal(message.getBytes("UTF-8"));
        return strUtils.B64Encoder(res).getBytes("UTF-8");
        //return cipher.doFinal(message.getBytes("UTF-8"));
    }


    public static String EncodeMD5(String message) {
        return DigestUtils.md5Hex(message);
    }
    public static byte[] convertHexString(String ss) {
        byte digest[] = new byte[ss.length() / 2];
        for (int i = 0; i < digest.length; i++) {
            String byteString = ss.substring(2 * i, 2 * i + 2);
            int byteValue = Integer.parseInt(byteString, 16);
            digest[i] = (byte) byteValue;
        }
        return digest;
    }

    public static String toHexString(byte b[]) {
        StringBuffer hexString = new StringBuffer();
        for (int i = 0; i < b.length; i++) {
            String plainText = Integer.toHexString(0xff & b[i]);
            if (plainText.length() < 2)
                plainText = "0" + plainText;
            hexString.append(plainText);
        }
        return hexString.toString();
    }

}
