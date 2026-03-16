.class public final Lcom/p/s/U;
.super Ljava/lang/Object;

.method public static rd(Ljava/io/InputStream;)[B
    .registers 5
    new-instance v0, Ljava/io/ByteArrayOutputStream;
    invoke-direct {v0}, Ljava/io/ByteArrayOutputStream;-><init>()V
    const/16 v1, 0x2000
    new-array v1, v1, [B
    :loop
    invoke-virtual {p0, v1}, Ljava/io/InputStream;->read([B)I
    move-result v2
    if-ltz v2, :done
    const/4 v3, 0x0
    invoke-virtual {v0, v1, v3, v2}, Ljava/io/ByteArrayOutputStream;->write([BII)V
    goto :loop
    :done
    invoke-virtual {p0}, Ljava/io/InputStream;->close()V
    invoke-virtual {v0}, Ljava/io/ByteArrayOutputStream;->toByteArray()[B
    move-result-object v0
    return-object v0
.end method

.method public static dc([B[B[B)[B
    .registers 8
    const-string v0, "AES"
    new-instance v1, Ljavax/crypto/spec/SecretKeySpec;
    invoke-direct {v1, p1, v0}, Ljavax/crypto/spec/SecretKeySpec;-><init>([BLjava/lang/String;)V
    const/16 v2, 0x80
    new-instance v3, Ljavax/crypto/spec/GCMParameterSpec;
    invoke-direct {v3, v2, p2}, Ljavax/crypto/spec/GCMParameterSpec;-><init>(I[B)V
    const-string v4, "AES/GCM/NoPadding"
    invoke-static {v4}, Ljavax/crypto/Cipher;->getInstance(Ljava/lang/String;)Ljavax/crypto/Cipher;
    move-result-object v4
    const/4 v5, 0x2
    invoke-virtual {v4, v5, v1, v3}, Ljavax/crypto/Cipher;->init(ILjava/security/Key;Ljava/security/spec/AlgorithmParameterSpec;)V
    invoke-virtual {v4, p0}, Ljavax/crypto/Cipher;->doFinal([B)[B
    move-result-object v0
    return-object v0
.end method

.method public static aa(Landroid/app/Application;Landroid/content/Context;)V
    .registers 6
    const-class v0, Landroid/app/Application;
    const-string v1, "attach"
    const/4 v2, 0x1
    new-array v2, v2, [Ljava/lang/Class;
    const/4 v3, 0x0
    const-class v4, Landroid/content/Context;
    aput-object v4, v2, v3
    invoke-virtual {v0, v1, v2}, Ljava/lang/Class;->getDeclaredMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;
    move-result-object v0
    const/4 v1, 0x1
    invoke-virtual {v0, v1}, Ljava/lang/reflect/Method;->setAccessible(Z)V
    const/4 v1, 0x1
    new-array v1, v1, [Ljava/lang/Object;
    const/4 v2, 0x0
    aput-object p1, v1, v2
    invoke-virtual {v0, p0, v1}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;
    return-void
.end method

.method private static ff(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/reflect/Field;
    .registers 4
    :loop
    if-eqz p0, :fail
    :try_start
    invoke-virtual {p0, p1}, Ljava/lang/Class;->getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v0
    return-object v0
    :try_end
    .catch Ljava/lang/NoSuchFieldException; {:try_start .. :try_end} :next
    :next
    invoke-virtual {p0}, Ljava/lang/Class;->getSuperclass()Ljava/lang/Class;
    move-result-object p0
    goto :loop
    :fail
    new-instance v0, Ljava/lang/NoSuchFieldException;
    invoke-direct {v0, p1}, Ljava/lang/NoSuchFieldException;-><init>(Ljava/lang/String;)V
    throw v0
.end method

.method public static sw(Landroid/app/Application;Landroid/app/Application;)V
    .registers 14
    const-string v0, "android.app.ActivityThread"
    invoke-static {v0}, Ljava/lang/Class;->forName(Ljava/lang/String;)Ljava/lang/Class;
    move-result-object v0

    const-string v1, "currentActivityThread"
    const/4 v2, 0x0
    new-array v3, v2, [Ljava/lang/Class;
    invoke-virtual {v0, v1, v3}, Ljava/lang/Class;->getDeclaredMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;
    move-result-object v1
    const/4 v3, 0x1
    invoke-virtual {v1, v3}, Ljava/lang/reflect/Method;->setAccessible(Z)V
    new-array v4, v2, [Ljava/lang/Object;
    const/4 v5, 0x0
    invoke-virtual {v1, v5, v4}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v1

    const-string v4, "mInitialApplication"
    invoke-static {v0, v4}, Lcom/p/s/U;->ff(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v4
    invoke-virtual {v4, v3}, Ljava/lang/reflect/Field;->setAccessible(Z)V
    invoke-virtual {v4, v1, p1}, Ljava/lang/reflect/Field;->set(Ljava/lang/Object;Ljava/lang/Object;)V

    const-string v4, "mAllApplications"
    invoke-static {v0, v4}, Lcom/p/s/U;->ff(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v4
    invoke-virtual {v4, v3}, Ljava/lang/reflect/Field;->setAccessible(Z)V
    invoke-virtual {v4, v1}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v4
    check-cast v4, Ljava/util/List;
    invoke-interface {v4, p0}, Ljava/util/List;->remove(Ljava/lang/Object;)Z
    invoke-interface {v4, p1}, Ljava/util/List;->contains(Ljava/lang/Object;)Z
    move-result v6
    if-nez v6, :skip_add
    invoke-interface {v4, p1}, Ljava/util/List;->add(Ljava/lang/Object;)Z
    :skip_add

    invoke-virtual {p0}, Landroid/app/Application;->getBaseContext()Landroid/content/Context;
    move-result-object v6
    invoke-virtual {v6}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v7

    const-string v8, "mPackageInfo"
    invoke-static {v7, v8}, Lcom/p/s/U;->ff(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v7
    invoke-virtual {v7, v3}, Ljava/lang/reflect/Field;->setAccessible(Z)V
    invoke-virtual {v7, v6}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v7

    invoke-virtual {v7}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v8
    const-string v9, "mApplication"
    invoke-static {v8, v9}, Lcom/p/s/U;->ff(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v8
    invoke-virtual {v8, v3}, Ljava/lang/reflect/Field;->setAccessible(Z)V
    invoke-virtual {v8, v7, p1}, Ljava/lang/reflect/Field;->set(Ljava/lang/Object;Ljava/lang/Object;)V

    invoke-virtual {v6}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v8
    const-string v9, "mOuterContext"
    invoke-static {v8, v9}, Lcom/p/s/U;->ff(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v8
    invoke-virtual {v8, v3}, Ljava/lang/reflect/Field;->setAccessible(Z)V
    invoke-virtual {v8, v6, p1}, Ljava/lang/reflect/Field;->set(Ljava/lang/Object;Ljava/lang/Object;)V

    invoke-virtual {p1}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v8
    invoke-virtual {v8}, Ljava/lang/Class;->getName()Ljava/lang/String;
    move-result-object v8

    invoke-virtual {v7}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v9
    const-string v10, "mApplicationInfo"
    invoke-static {v9, v10}, Lcom/p/s/U;->ff(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v9
    invoke-virtual {v9, v3}, Ljava/lang/reflect/Field;->setAccessible(Z)V
    invoke-virtual {v9, v7}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v9
    check-cast v9, Landroid/content/pm/ApplicationInfo;
    if-eqz v9, :skip_loaded_info
    iput-object v8, v9, Landroid/content/pm/ApplicationInfo;->className:Ljava/lang/String;
    :skip_loaded_info

    const-string v9, "mBoundApplication"
    invoke-static {v0, v9}, Lcom/p/s/U;->ff(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v0
    invoke-virtual {v0, v3}, Ljava/lang/reflect/Field;->setAccessible(Z)V
    invoke-virtual {v0, v1}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v0
    if-eqz v0, :done
    invoke-virtual {v0}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v1
    const-string v6, "appInfo"
    invoke-static {v1, v6}, Lcom/p/s/U;->ff(Ljava/lang/Class;Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v1
    invoke-virtual {v1, v3}, Ljava/lang/reflect/Field;->setAccessible(Z)V
    invoke-virtual {v1, v0}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v0
    check-cast v0, Landroid/content/pm/ApplicationInfo;
    if-eqz v0, :done
    iput-object v8, v0, Landroid/content/pm/ApplicationInfo;->className:Ljava/lang/String;
    :done
    return-void
.end method

.method public static inj(Ldalvik/system/DexClassLoader;Ljava/lang/ClassLoader;)V
    .registers 12
    const-class v0, Ldalvik/system/BaseDexClassLoader;
    const-string v1, "pathList"
    invoke-virtual {v0, v1}, Ljava/lang/Class;->getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v0
    const/4 v1, 0x1
    invoke-virtual {v0, v1}, Ljava/lang/reflect/Field;->setAccessible(Z)V

    invoke-virtual {v0, p0}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v1
    invoke-virtual {v0, p1}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v2

    invoke-virtual {v1}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v3
    const-string v4, "dexElements"
    invoke-virtual {v3, v4}, Ljava/lang/Class;->getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v3
    const/4 v4, 0x1
    invoke-virtual {v3, v4}, Ljava/lang/reflect/Field;->setAccessible(Z)V

    invoke-virtual {v3, v1}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v4
    check-cast v4, [Ljava/lang/Object;
    invoke-virtual {v3, v2}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v5
    check-cast v5, [Ljava/lang/Object;

    array-length v6, v4
    array-length v7, v5
    add-int v8, v6, v7

    invoke-virtual {v4}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v9
    invoke-virtual {v9}, Ljava/lang/Class;->getComponentType()Ljava/lang/Class;
    move-result-object v9

    invoke-static {v9, v8}, Ljava/lang/reflect/Array;->newInstance(Ljava/lang/Class;I)Ljava/lang/Object;
    move-result-object v8
    check-cast v8, [Ljava/lang/Object;

    const/4 v9, 0x0
    invoke-static {v4, v9, v8, v9, v6}, Ljava/lang/System;->arraycopy(Ljava/lang/Object;ILjava/lang/Object;II)V
    const/4 v9, 0x0
    invoke-static {v5, v9, v8, v6, v7}, Ljava/lang/System;->arraycopy(Ljava/lang/Object;ILjava/lang/Object;II)V

    invoke-virtual {v3, v2, v8}, Ljava/lang/reflect/Field;->set(Ljava/lang/Object;Ljava/lang/Object;)V
    return-void
.end method
