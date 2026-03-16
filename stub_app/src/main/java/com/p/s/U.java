package com.p.s;

import android.app.Application;
import android.content.pm.ApplicationInfo;
import android.content.Context;
import android.content.ContextWrapper;

import dalvik.system.BaseDexClassLoader;
import dalvik.system.DexClassLoader;

import java.io.*;
import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.List;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

public final class U {

    /** Read all bytes from InputStream (closes stream) */
    public static byte[] rd(InputStream is) throws Exception {
        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = is.read(buf)) != -1) baos.write(buf, 0, n);
            return baos.toByteArray();
        } finally {
            is.close();
        }
    }

    /** AES-256-GCM decrypt */
    public static byte[] dc(byte[] data, byte[] key, byte[] nonce) throws Exception {
        SecretKeySpec ks = new SecretKeySpec(key, "AES");
        GCMParameterSpec gs = new GCMParameterSpec(128, nonce);
        Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.DECRYPT_MODE, ks, gs);
        return c.doFinal(data);
    }

    /** Invoke hidden Application.attach so the delegate is attached like a real app instance. */
    public static void aa(Application app, Context ctx) throws Exception {
        Method m = Application.class.getDeclaredMethod("attach", Context.class);
        m.setAccessible(true);
        m.invoke(app, ctx);
    }

    /** Replace the shell Application with the real one inside ActivityThread/LoadedApk. */
    @SuppressWarnings("unchecked")
    public static void sw(Application shellApp, Application realApp) throws Exception {
        Class<?> activityThreadClass = Class.forName("android.app.ActivityThread");
        Method currentActivityThread = activityThreadClass.getDeclaredMethod("currentActivityThread");
        currentActivityThread.setAccessible(true);
        Object activityThread = currentActivityThread.invoke(null);

        Field initialAppField = findField(activityThreadClass, "mInitialApplication");
        initialAppField.setAccessible(true);
        initialAppField.set(activityThread, realApp);

        Field allAppsField = findField(activityThreadClass, "mAllApplications");
        allAppsField.setAccessible(true);
        Object allAppsObj = allAppsField.get(activityThread);
        if (allAppsObj instanceof List<?>) {
            List<Application> allApps = (List<Application>) allAppsObj;
            allApps.remove(shellApp);
            if (!allApps.contains(realApp)) {
                allApps.add(realApp);
            }
        }

        Context base = shellApp.getBaseContext();
        Field packageInfoField = findField(base.getClass(), "mPackageInfo");
        packageInfoField.setAccessible(true);
        Object loadedApk = packageInfoField.get(base);

        Field loadedApkAppField = findField(loadedApk.getClass(), "mApplication");
        loadedApkAppField.setAccessible(true);
        loadedApkAppField.set(loadedApk, realApp);

        Field outerContextField = findField(base.getClass(), "mOuterContext");
        outerContextField.setAccessible(true);
        outerContextField.set(base, realApp);

        String realClassName = realApp.getClass().getName();

        Field appInfoField = findField(loadedApk.getClass(), "mApplicationInfo");
        appInfoField.setAccessible(true);
        ApplicationInfo loadedApkInfo = (ApplicationInfo) appInfoField.get(loadedApk);
        if (loadedApkInfo != null) {
            loadedApkInfo.className = realClassName;
        }

        Field boundAppField = findField(activityThreadClass, "mBoundApplication");
        boundAppField.setAccessible(true);
        Object boundApp = boundAppField.get(activityThread);
        if (boundApp != null) {
            Field boundAppInfoField = findField(boundApp.getClass(), "appInfo");
            boundAppInfoField.setAccessible(true);
            ApplicationInfo boundInfo = (ApplicationInfo) boundAppInfoField.get(boundApp);
            if (boundInfo != null) {
                boundInfo.className = realClassName;
            }
        }
    }

    /** Prepend src DEX elements into dst ClassLoader via reflection */
    public static void inj(DexClassLoader src, ClassLoader dst) throws Exception {
        Field plf = findField(BaseDexClassLoader.class, "pathList");
        plf.setAccessible(true);

        Object srcPL = plf.get(src);
        Object dstPL = plf.get(dst);

        Field def = findField(srcPL.getClass(), "dexElements");
        def.setAccessible(true);

        Object[] srcE = (Object[]) def.get(srcPL);
        Object[] dstE = (Object[]) def.get(dstPL);

        Object[] merged = (Object[]) Array.newInstance(
            srcE.getClass().getComponentType(),
            srcE.length + dstE.length
        );
        System.arraycopy(srcE, 0, merged, 0, srcE.length);
        System.arraycopy(dstE, 0, merged, srcE.length, dstE.length);

        def.set(dstPL, merged);
    }

    private static Field findField(Class<?> cls, String name) throws NoSuchFieldException {
        for (Class<?> c = cls; c != null; c = c.getSuperclass()) {
            try { return c.getDeclaredField(name); }
            catch (NoSuchFieldException ignored) { }
        }
        throw new NoSuchFieldException(name);
    }
}
