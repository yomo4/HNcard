package com.p.s;

import dalvik.system.BaseDexClassLoader;
import dalvik.system.DexClassLoader;

import java.io.*;
import java.lang.reflect.Array;
import java.lang.reflect.Field;

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
