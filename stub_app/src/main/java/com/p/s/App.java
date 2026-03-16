package com.p.s;

import android.app.Application;
import android.content.Context;
import android.content.res.AssetManager;

import dalvik.system.DexClassLoader;

import java.io.File;
import java.io.FileOutputStream;
import java.security.MessageDigest;
import java.util.Arrays;

/**
 * Stub Application — reference source (deployed via App.smali).
 *
 * assets/salt.bin        - 16 random bytes; KEY = SHA-256(salt)
 * assets/count.bin       - 1 byte: number of encrypted DEX payloads
 * assets/payload{i}.enc  - IV[0..12) + AES-256-GCM ciphertext+tag
 * assets/orig_app.bin    - UTF-8 original Application class name (optional)
 */
public class App extends Application {

    private Application delegate;

    @Override
    protected void attachBaseContext(Context base) {
        super.attachBaseContext(base);
        go(base);
    }

    @Override
    public void onCreate() {
        super.onCreate();
        if (delegate != null) {
            try { delegate.onCreate(); } catch (Throwable ignored) {}
        }
    }

    private void go(Context ctx) {
        try {
            AssetManager am = ctx.getAssets();

            // KEY = SHA-256(salt)
            byte[] salt = U.rd(am.open("salt.bin"));
            byte[] key  = MessageDigest.getInstance("SHA-256").digest(salt);

            int count = 1;
            try {
                byte[] cb = U.rd(am.open("count.bin"));
                count = cb[0] & 0xFF;
            } catch (Exception ignored) {}

            ClassLoader cl     = getClass().getClassLoader();
            File        optDir = ctx.getDir("dex_opt", Context.MODE_PRIVATE);

            for (int i = 0; i < count; i++) {
                byte[] enc        = U.rd(am.open("payload" + i + ".enc"));
                byte[] iv         = Arrays.copyOfRange(enc, 0, 12);
                byte[] ciphertext = Arrays.copyOfRange(enc, 12, enc.length); // includes GCM tag
                byte[] dex        = U.dc(ciphertext, key, iv);

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
                String      name     = new String(U.rd(am.open("orig_app.bin")));
                Class<?>    appClass = Class.forName(name, true, cl);
                Application app      = (Application) appClass.newInstance();
                U.aa(app, ctx);
                delegate = app;
            } catch (Throwable ignored) {}

        } catch (Throwable ignored) {}
    }
}
