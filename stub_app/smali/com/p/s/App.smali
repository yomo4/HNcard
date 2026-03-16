# StubApplication — decrypts payload.enc from assets and injects into ClassLoader
.class public Lcom/p/s/App;
.super Landroid/app/Application;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/app/Application;-><init>()V
    return-void
.end method

.method public attachBaseContext(Landroid/content/Context;)V
    .registers 3
    invoke-super {p0, p1}, Landroid/app/Application;->attachBaseContext(Landroid/content/Context;)V
    :try_start
    invoke-direct {p0, p1}, Lcom/p/s/App;->go(Landroid/content/Context;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :skip
    :skip
    return-void
.end method

# ──────────────────────────────────────────────────────────────
# Main logic: read k.bin, decrypt payload.enc, inject DEX
# ──────────────────────────────────────────────────────────────
.method private go(Landroid/content/Context;)V
    .registers 16
    # v0 = assetManager
    invoke-virtual {p1}, Landroid/content/Context;->getAssets()Landroid/content/res/AssetManager;
    move-result-object v0

    # v1 = k.bin bytes (32-byte key + 12-byte nonce = 44 total)
    const-string v1, "k.bin"
    invoke-virtual {v0, v1}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;
    move-result-object v1
    invoke-static {v1}, Lcom/p/s/U;->rd(Ljava/io/InputStream;)[B
    move-result-object v1

    # v2 = key = v1[0..32]
    const/4 v3, 0x0
    const/16 v4, 0x20
    invoke-static {v1, v3, v4}, Ljava/util/Arrays;->copyOfRange([BII)[B
    move-result-object v2

    # v3 = nonce = v1[32..44]
    const/16 v3, 0x20
    const/16 v4, 0x2c
    invoke-static {v1, v3, v4}, Ljava/util/Arrays;->copyOfRange([BII)[B
    move-result-object v3

    # v4 = count of dex payloads (from assets/n.bin, byte value)
    :try_count_start
    const-string v4, "n.bin"
    invoke-virtual {v0, v4}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;
    move-result-object v4
    invoke-static {v4}, Lcom/p/s/U;->rd(Ljava/io/InputStream;)[B
    move-result-object v4
    const/4 v5, 0x0
    aget-byte v4, v4, v5
    and-int/lit8 v4, v4, 0xff
    :try_count_end
    .catch Ljava/lang/Throwable; {:try_count_start .. :try_count_end} :default_count
    goto :loop_init
    :default_count
    const/4 v4, 0x1

    :loop_init
    # v5 = loop index i = 0
    const/4 v5, 0x0

    :loop_start
    if-ge v5, v4, :loop_done

    # Build asset name: i==0 → "p0.enc", i==1 → "p1.enc", ...
    new-instance v6, Ljava/lang/StringBuilder;
    invoke-direct {v6}, Ljava/lang/StringBuilder;-><init>()V
    const-string v7, "p"
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v6, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v7, ".enc"
    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v6}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v6   # v6 = "p0.enc" etc.

    # Read encrypted dex
    invoke-virtual {v0, v6}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;
    move-result-object v7
    invoke-static {v7}, Lcom/p/s/U;->rd(Ljava/io/InputStream;)[B
    move-result-object v7   # v7 = encrypted dex bytes

    # Decrypt
    invoke-static {v7, v2, v3}, Lcom/p/s/U;->dc([B[B[B)[B
    move-result-object v7   # v7 = plaintext dex bytes

    # Write to filesDir/dN.dex
    invoke-virtual {p1}, Landroid/content/Context;->getFilesDir()Ljava/io/File;
    move-result-object v8
    new-instance v9, Ljava/lang/StringBuilder;
    invoke-direct {v9}, Ljava/lang/StringBuilder;-><init>()V
    const-string v10, "d"
    invoke-virtual {v9, v10}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v9, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v10, ".dex"
    invoke-virtual {v9, v10}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v9}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v9   # v9 = "d0.dex"

    new-instance v10, Ljava/io/File;
    invoke-direct {v10, v8, v9}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V
    # v10 = File(filesDir, "d0.dex")

    new-instance v11, Ljava/io/FileOutputStream;
    invoke-direct {v11, v10}, Ljava/io/FileOutputStream;-><init>(Ljava/io/File;)V
    invoke-virtual {v11, v7}, Ljava/io/FileOutputStream;->write([B)V
    invoke-virtual {v11}, Ljava/io/FileOutputStream;->close()V

    # opt dir
    const-string v12, "o"
    const/4 v13, 0x0
    invoke-virtual {p1, v12, v13}, Landroid/content/Context;->getDir(Ljava/lang/String;I)Ljava/io/File;
    move-result-object v12

    # DexClassLoader(dexFile, optDir, null, currentCL)
    invoke-virtual {v10}, Ljava/io/File;->getAbsolutePath()Ljava/lang/String;
    move-result-object v13
    invoke-virtual {v12}, Ljava/io/File;->getAbsolutePath()Ljava/lang/String;
    move-result-object v12

    invoke-virtual {p0}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v14
    invoke-virtual {v14}, Ljava/lang/Class;->getClassLoader()Ljava/lang/ClassLoader;
    move-result-object v14

    new-instance v15, Ldalvik/system/DexClassLoader;
    const/4 v8, 0x0
    invoke-direct {v15, v13, v12, v8, v14}, Ldalvik/system/DexClassLoader;-><init>(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/ClassLoader;)V

    # Inject into current ClassLoader
    invoke-static {v15, v14}, Lcom/p/s/U;->inj(Ldalvik/system/DexClassLoader;Ljava/lang/ClassLoader;)V

    add-int/lit8 v5, v5, 0x1
    goto :loop_start

    :loop_done
    return-void
.end method
