package com.p.s;

import android.app.Application;
import android.content.Context;
import android.content.res.AssetManager;

import dalvik.system.BaseDexClassLoader;
import dalvik.system.DexClassLoader;

import java.io.*;
import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.util.Arrays;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

/**
 * Stub Application.
 * Reads encrypted DEX payloads from assets/, decrypts with AES-256-GCM,
 * writes to private storage, injects into current ClassLoader.
 *
 * assets/k.bin   — 44 bytes:  key[0..32) + nonce[32..44)
 * assets/n.bin   — 1 byte:    number of DEX payloads
 * assets/p0.enc  — encrypted classes.dex
 * assets/p1.enc  — encrypted classes2.dex  (if present)
 * ...
 */
public class App extends Application {

    @Override
    protected void attachBaseContext(Context base) {
        super.attachBaseContext(base);
        try {
            go(base);
        } catch (Throwable ignored) { }
    }

    private void go(Context ctx) throws Exception {
        AssetManager am = ctx.getAssets();

        // Read key material
        byte[] keyData = U.rd(am.open("k.bin"));
        byte[] key   = Arrays.copyOfRange(keyData, 0, 32);
        byte[] nonce = Arrays.copyOfRange(keyData, 32, 44);

        // Number of DEX payloads
        int count = 1;
        try {
            byte[] nb = U.rd(am.open("n.bin"));
            count = nb[0] & 0xFF;
        } catch (Exception ignored) { }

        ClassLoader cl = getClass().getClassLoader();
        File optDir = ctx.getDir("o", Context.MODE_PRIVATE);

        for (int i = 0; i < count; i++) {
            byte[] enc = U.rd(am.open("p" + i + ".enc"));
            byte[] dex = U.dc(enc, key, nonce);

            File dexFile = new File(ctx.getFilesDir(), "d" + i + ".dex");
            try (FileOutputStream fos = new FileOutputStream(dexFile)) {
                fos.write(dex);
            }

            DexClassLoader dcl = new DexClassLoader(
                dexFile.getAbsolutePath(),
                optDir.getAbsolutePath(),
                null,
                cl
            );
            U.inj(dcl, cl);
        }
    }
}
