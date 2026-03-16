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
 * Loads encrypted dex payloads, injects them into the app ClassLoader and,
 * when present, delegates lifecycle callbacks to the original Application.
 *
 * assets/k.bin   - 32 bytes: AES-256 key
 * assets/n.bin   - 1 byte: number of encrypted DEX payloads
 * assets/p{i}.enc - nonce[0..12) + ciphertext
 * assets/a.bin   - UTF-8 original Application class name, optional
 */
public class App extends Application {

    private Application delegate;

    @Override
    protected void attachBaseContext(Context base) {
        super.attachBaseContext(base);
        try {
            go(base);
        } catch (Throwable ignored) {
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        if (delegate != null) {
            try {
                delegate.onCreate();
            } catch (Throwable ignored) {
            }
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

        try {
            String className = new String(U.rd(am.open("a.bin")));
            Class<?> appClass = Class.forName(className, true, cl);
            Application app = (Application) appClass.newInstance();
            U.ab(app, ctx);
            delegate = app;
        } catch (Throwable ignored) {
        }
    }
}
