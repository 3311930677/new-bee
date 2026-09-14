package my.utils;

public class StackTraceUtils {
    /**
     * 获取方法整个调用过程的相关信息
     *
     * @return
     */
    public static String getAllTag() {
        StringBuilder sb = new StringBuilder();
        StackTraceElement[] stackTrace = Thread.currentThread().getStackTrace();
        for (StackTraceElement e : stackTrace) {
            if (e.getClassName().contains("my.handle")) break;
            sb.append("调用过程 = " + e.getClassName() + "\t"
                    + e.getMethodName() + "\t" + e.getLineNumber() + "\t");
        }
        StackTraceElement log = stackTrace[1];
        String tag = null;
        for (int i = 1; i < stackTrace.length; i++) {
            StackTraceElement e = stackTrace[i];
            if (!e.getClassName().equals(log.getClassName())) {
                tag = e.getClassName() + "." + e.getMethodName();
                break;
            }
        }
        if (tag == null) {
            tag = log.getClassName() + "." + log.getMethodName();

        }
        sb.append("当前方法 = " + tag);
        return sb.toString();
    }


}
