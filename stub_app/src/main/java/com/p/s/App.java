package com.p.s;

import android.app.Application;
import android.content.Context;
import android.content.res.AssetManager;

import dalvik.system.DexClassLoader;

import java.io.File;
import java.io.FileOutputStream;
import java.util.Arrays;

/**
 * Stub Application.
 * Reads encrypted DEX payloads from assets/, decrypts them with AES-256-GCM,
 * writes the decrypted dex files into private storage and injects them into
 * the current ClassLoader.
 *
 * assets/k.bin   - 32 bytes: AES-256 key
 * assets/n.bin   - 1 byte: number of encrypted DEX payloads
 * assets/p0.enc  - nonce[0..12) + ciphertext for classes.dex
 * assets/p1.enc  - nonce[0..12) + ciphertext for classes2.dex
 * ...
 */
public class App extends Application {

    @Override
    protected void attachBaseContext(Context base) {
        super.attachBaseContext(base);
        try {
            go(base);
        } catch (Throwable ignored) {
        }
    }

    private void go(Context ctx) throws Exception {
        AssetManager am = ctx.getAssets();
        byte[] key = U.rd(am.open("k.bin"));

        int count = 1;
        try {
            byte[] nb = U.rd(am.open("n.bin"));
            count = nb[0] & 0xFF;
        } catch (Exception ignored) {
        }

        ClassLoader cl = getClass().getClassLoader();
        File optDir = ctx.getDir("o", Context.MODE_PRIVATE);

        for (int i = 0; i < count; i++) {
            byte[] enc = U.rd(am.open("p" + i + ".enc"));
            byte[] nonce = Arrays.copyOfRange(enc, 0, 12);
            byte[] ciphertext = Arrays.copyOfRange(enc, 12, enc.length);
            byte[] dex = U.dc(ciphertext, key, nonce);

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
