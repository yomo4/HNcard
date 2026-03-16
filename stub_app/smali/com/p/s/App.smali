.class public Lcom/p/s/App;
.super Landroid/app/Application;

.field private oA:Landroid/app/Application;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/app/Application;-><init>()V
    return-void
.end method

.method public attachBaseContext(Landroid/content/Context;)V
    .registers 4
    invoke-super {p0, p1}, Landroid/app/Application;->attachBaseContext(Landroid/content/Context;)V
    :try_start
    invoke-direct {p0, p1}, Lcom/p/s/App;->go(Landroid/content/Context;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :skip
    :skip
    return-void
.end method

.method public onCreate()V
    .registers 3
    invoke-super {p0}, Landroid/app/Application;->onCreate()V
    :try_start
    iget-object v0, p0, Lcom/p/s/App;->oA:Landroid/app/Application;
    if-eqz v0, :skip
    invoke-virtual {v0}, Landroid/app/Application;->onCreate()V
    :skip
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :skip
    return-void
.end method

.method private go(Landroid/content/Context;)V
    .registers 16
    # p0=v14(this), p1=v15(context), locals=v0-v13

    # v0 = assetManager
    invoke-virtual {p1}, Landroid/content/Context;->getAssets()Landroid/content/res/AssetManager;
    move-result-object v0

    # v2 = key bytes
    const-string v1, "k.bin"
    invoke-virtual {v0, v1}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;
    move-result-object v1
    invoke-static {v1}, Lcom/p/s/U;->rd(Ljava/io/InputStream;)[B
    move-result-object v2

    # v3 = dex count (default 1)
    const/4 v3, 0x1
    :try_n_start
    const-string v4, "n.bin"
    invoke-virtual {v0, v4}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;
    move-result-object v4
    invoke-static {v4}, Lcom/p/s/U;->rd(Ljava/io/InputStream;)[B
    move-result-object v4
    const/4 v5, 0x0
    aget-byte v3, v4, v5
    const/16 v5, 0xff
    and-int v3, v3, v5
    :try_n_end
    .catch Ljava/lang/Throwable; {:try_n_start .. :try_n_end} :skip_n
    :skip_n

    # v13 = parent ClassLoader
    invoke-virtual {p0}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v4
    invoke-virtual {v4}, Ljava/lang/Class;->getClassLoader()Ljava/lang/ClassLoader;
    move-result-object v13

    # v12 = opt dir
    const-string v1, "o"
    const/4 v4, 0x0
    invoke-virtual {p1, v1, v4}, Landroid/content/Context;->getDir(Ljava/lang/String;I)Ljava/io/File;
    move-result-object v12

    # loop i=0..count
    const/4 v5, 0x0
    :loop_start
    if-ge v5, v3, :loop_done

    # build "p{i}.enc" -> v6
    new-instance v6, Ljava/lang/StringBuilder;
    invoke-direct {v6}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, "p"
    invoke-virtual {v6, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v6, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v1, ".enc"
    invoke-virtual {v6, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v6}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v6

    # v7 = raw bytes of p{i}.enc
    invoke-virtual {v0, v6}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;
    move-result-object v7
    invoke-static {v7}, Lcom/p/s/U;->rd(Ljava/io/InputStream;)[B
    move-result-object v7

    # v8 = nonce (first 12 bytes)
    const/4 v1, 0x0
    const/16 v4, 0xc
    invoke-static {v7, v1, v4}, Ljava/util/Arrays;->copyOfRange([BII)[B
    move-result-object v8

    # v9 = ciphertext (bytes 12..end)
    const/16 v1, 0xc
    array-length v4, v7
    invoke-static {v7, v1, v4}, Ljava/util/Arrays;->copyOfRange([BII)[B
    move-result-object v9

    # v9 = decrypted dex
    invoke-static {v9, v2, v8}, Lcom/p/s/U;->dc([B[B[B)[B
    move-result-object v9

    # build "d{i}.dex" -> v6 (reuse)
    new-instance v6, Ljava/lang/StringBuilder;
    invoke-direct {v6}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, "d"
    invoke-virtual {v6, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v6, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v1, ".dex"
    invoke-virtual {v6, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v6}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v6

    # new File(filesDir, "d{i}.dex") -> v10
    invoke-virtual {p1}, Landroid/content/Context;->getFilesDir()Ljava/io/File;
    move-result-object v1
    new-instance v10, Ljava/io/File;
    invoke-direct {v10, v1, v6}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V

    # write dex bytes
    new-instance v11, Ljava/io/FileOutputStream;
    invoke-direct {v11, v10}, Ljava/io/FileOutputStream;-><init>(Ljava/io/File;)V
    invoke-virtual {v11, v9}, Ljava/io/FileOutputStream;->write([B)V
    invoke-virtual {v11}, Ljava/io/FileOutputStream;->close()V

    # DexClassLoader -> v11 (FOS closed, reuse slot)
    invoke-virtual {v10}, Ljava/io/File;->getAbsolutePath()Ljava/lang/String;
    move-result-object v6
    invoke-virtual {v12}, Ljava/io/File;->getAbsolutePath()Ljava/lang/String;
    move-result-object v7
    const/4 v1, 0x0
    new-instance v11, Ldalvik/system/DexClassLoader;
    invoke-direct {v11, v6, v7, v1, v13}, Ldalvik/system/DexClassLoader;-><init>(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/ClassLoader;)V

    # inject into parent
    invoke-static {v11, v13}, Lcom/p/s/U;->inj(Ldalvik/system/DexClassLoader;Ljava/lang/ClassLoader;)V

    add-int/lit8 v5, v5, 0x1
    goto :loop_start
    :loop_done

    # instantiate original Application
    :try_orig_start
    const-string v1, "a.bin"
    invoke-virtual {v0, v1}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;
    move-result-object v1
    invoke-static {v1}, Lcom/p/s/U;->rd(Ljava/io/InputStream;)[B
    move-result-object v1
    new-instance v2, Ljava/lang/String;
    invoke-direct {v2, v1}, Ljava/lang/String;-><init>([B)V
    const/4 v4, 0x1
    invoke-static {v2, v4, v13}, Ljava/lang/Class;->forName(Ljava/lang/String;ZLjava/lang/ClassLoader;)Ljava/lang/Class;
    move-result-object v3
    invoke-virtual {v3}, Ljava/lang/Class;->newInstance()Ljava/lang/Object;
    move-result-object v4
    check-cast v4, Landroid/app/Application;
    iput-object v4, p0, Lcom/p/s/App;->oA:Landroid/app/Application;
    invoke-static {v4, p1}, Lcom/p/s/U;->aa(Landroid/app/Application;Landroid/content/Context;)V
    invoke-static {p0, v4}, Lcom/p/s/U;->sw(Landroid/app/Application;Landroid/app/Application;)V
    :try_orig_end
    .catch Ljava/lang/Throwable; {:try_orig_start .. :try_orig_end} :skip_orig
    :skip_orig

    return-void
.end method
