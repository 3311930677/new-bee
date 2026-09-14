package my.utils;

import my.startBef;

import java.lang.annotation.Annotation;
import java.lang.reflect.Field;
import java.lang.reflect.Method;

public class classUtils {
    /**
     * 获取方法上是的注解
     */
    public static Annotation[][] getAnno(String c, String m) throws Exception {
        try {
            Class<?> clazz = null;
            //获取注册的实例
            Field[] fields = getAllField(startBef.class);
            for (Field field : fields) {
                if (field.getName().equals(c)) {
                    clazz = field.getType();
                    break;
                }
            }
            //Class<?> clazz = Class.forName(c);
            // 获取Test类的所有方法
            Method[] methods = clazz.getMethods();
            for (Method method : methods) {
                if (!method.getName().equals(m)) {
                    continue;
                }
                return method.getParameterAnnotations();
            }
        } catch (Exception e) {
            //loggerUtils.error(c + m + "类未发现", classUtils.class);
        }
        return null;
    }

    /**
     * 扫描某个类的所有属性
     */
    public static Field[] getAllField(Class<?> c) {
        return c.getDeclaredFields();
    }

    /**
     * 创建实例
     */
    public static <V> V createSingle(Class<?> c) {
        try {
            return (V) c.newInstance();
        } catch (InstantiationException e) {
            e.printStackTrace();
        } catch (IllegalAccessException e) {
            e.printStackTrace();
        }
        return null;
    }

    /**
     * 反射调用
     *
     * @param pack
     * @param method
     * @param data   new Object[]{jb.getString("path")}
     * @param <V>
     * @return 任意类
     */
    public static <V> V invokeMethod(String pack, String method, Object[] data) throws Exception {
        try {
            V res = null;
            Class<?> cm = null;
            cm = Class.forName(pack);
            Object obj = cm.newInstance();
            Class[] c = new Class[data.length];
            for (int i = 0; i < data.length; i++) {
                c[i] = data[i].getClass();
            }
            res = (V) (cm.getDeclaredMethod(method, c).invoke(obj, data));
            return res;
        } catch (Exception e) {
            loggerUtils.error("反射方法出错：" + method + " " + e.getMessage(), classUtils.class);
            throw new Exception(e);
        }
    }

    public static <V> V invokeMethod(Method method, Object[] data) throws Exception {
        try {
            V res = null;
            Class<?> cm = method.getDeclaringClass();
            Object obj = cm.newInstance();
            Class[] c = new Class[data.length];
            for (int i = 0; i < data.length; i++) {
                c[i] = data[i].getClass();
            }
            res = (V) (cm.getDeclaredMethod(method.getName(), c).invoke(obj, data));
            return res;
        } catch (Exception e) {
            loggerUtils.error("反射方法出错：" + method + " " + e.getMessage(), classUtils.class);
            throw new Exception(e);
        }
    }

    /**
     * 由属性名反射属性值（只获取当前类属性）
     */
    public static Object getFieldValueByFieldName(String fieldName, Object object) throws Exception {
        try {
            Field field = object.getClass().getDeclaredField(fieldName);
            //设置对象的访问权限，保证对private的属性的访问
            field.setAccessible(true);
            return field.get(object);
        } catch (Exception e) {
            throw new Exception(e);
        }
    }

    /**
     * 反射某个对象的方法
     */
    public static <V> V invokeFnByFnName(Object object, String fnName, Object... args) throws Exception {
        V res = null;
        try {
            Class[] params = new Class[args.length];
            for (int i = 0; i < args.length; i++) {
                params[i] = args[i].getClass();
            }
            Method method;
            if (params != null && params.length > 0) {
                method = object.getClass().getDeclaredMethod(fnName, params);
                method.setAccessible(true);
                res = (V) method.invoke(object, args);
            } else {
                method = object.getClass().getDeclaredMethod(fnName);
                method.setAccessible(true);
                res = (V) method.invoke(object);
            }
        } catch (Exception e) {
            throw new Exception(e);
        }
        return res;
    }

    /**
     * 由属性名反射属性值（只获取类属性,包括继承的）
     */
    private static Field getFieldByClasss(String fieldName, Object object) {
        Field field = null;
        Class<?> clazz = object.getClass();

        for (; clazz != Object.class; clazz = clazz.getSuperclass()) {
            try {
                field = clazz.getDeclaredField(fieldName);
            } catch (Exception e) {
                // 这里甚么都不能抛出去。
                // 如果这里的异常打印或者往外抛，则就不会进入
            }
        }
        return field;
    }
}
