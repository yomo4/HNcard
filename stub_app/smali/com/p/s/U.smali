# Utility class: readStream + AES-256-GCM decrypt + ClassLoader injection
.class public final Lcom/p/s/U;
.super Ljava/lang/Object;

# ──────────────────────────────────────────────────────────────
# byte[] rd(InputStream) — read all bytes from stream
# ──────────────────────────────────────────────────────────────
.method public static rd(Ljava/io/InputStream;)[B
    .registers 5
    # v0 = ByteArrayOutputStream
    new-instance v0, Ljava/io/ByteArrayOutputStream;
    invoke-direct {v0}, Ljava/io/ByteArrayOutputStream;-><init>()V
    # v1 = byte[8192]
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

# ──────────────────────────────────────────────────────────────
# byte[] dc(byte[] data, byte[] key32, byte[] nonce12) — AES/GCM/NoPadding decrypt
# ──────────────────────────────────────────────────────────────
.method public static dc([B[B[B)[B
    .registers 8
    # v0 = SecretKeySpec(key, "AES")
    const-string v0, "AES"
    new-instance v1, Ljavax/crypto/spec/SecretKeySpec;
    invoke-direct {v1, p1, v0}, Ljavax/crypto/spec/SecretKeySpec;-><init>([BLjava/lang/String;)V

    # v2 = GCMParameterSpec(128, nonce)
    const/16 v2, 0x80
    new-instance v3, Ljavax/crypto/spec/GCMParameterSpec;
    invoke-direct {v3, v2, p2}, Ljavax/crypto/spec/GCMParameterSpec;-><init>(I[B)V

    # v4 = Cipher.getInstance("AES/GCM/NoPadding")
    const-string v4, "AES/GCM/NoPadding"
    invoke-static {v4}, Ljavax/crypto/Cipher;->getInstance(Ljava/lang/String;)Ljavax/crypto/Cipher;
    move-result-object v4

    # cipher.init(DECRYPT_MODE=2, keySpec, gcmSpec)
    const/4 v5, 0x2
    invoke-virtual {v4, v5, v1, v3}, Ljavax/crypto/Cipher;->init(ILjava/security/Key;Ljava/security/spec/AlgorithmParameterSpec;)V

    # return cipher.doFinal(data)
    invoke-virtual {v4, p0}, Ljavax/crypto/Cipher;->doFinal([B)[B
    move-result-object v0
    return-object v0
.end method

# ──────────────────────────────────────────────────────────────
# void inj(DexClassLoader src, ClassLoader dst)
# Prepends src's dex elements into dst's ClassLoader
# ──────────────────────────────────────────────────────────────
.method public static inj(Ldalvik/system/DexClassLoader;Ljava/lang/ClassLoader;)V
    .registers 12
    # v0 = BaseDexClassLoader.class.getDeclaredField("pathList")
    const-class v0, Ldalvik/system/BaseDexClassLoader;
    const-string v1, "pathList"
    invoke-virtual {v0, v1}, Ljava/lang/Class;->getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v0   # v0 = pathListField
    const/4 v1, 0x1
    invoke-virtual {v0, v1}, Ljava/lang/reflect/Field;->setAccessible(Z)V

    # v1 = srcPathList = pathListField.get(p0)
    invoke-virtual {v0, p0}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v1
    # v2 = dstPathList = pathListField.get(p1)
    invoke-virtual {v0, p1}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v2

    # v3 = DexPathList.class, v3 = dexElementsField
    invoke-virtual {v1}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v3
    const-string v4, "dexElements"
    invoke-virtual {v3, v4}, Ljava/lang/Class;->getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field;
    move-result-object v3   # v3 = dexElementsField
    const/4 v4, 0x1
    invoke-virtual {v3, v4}, Ljava/lang/reflect/Field;->setAccessible(Z)V

    # v4 = srcElems, v5 = dstElems
    invoke-virtual {v3, v1}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v4
    check-cast v4, [Ljava/lang/Object;
    invoke-virtual {v3, v2}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v5
    check-cast v5, [Ljava/lang/Object;

    # v6 = srcLen, v7 = dstLen, v8 = total
    array-length v6, v4
    array-length v7, v5
    add-int v8, v6, v7

    # componentType from srcElems
    invoke-virtual {v4}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v9
    invoke-virtual {v9}, Ljava/lang/Class;->getComponentType()Ljava/lang/Class;
    move-result-object v9

    # v8 = merged = Array.newInstance(componentType, total)
    invoke-static {v9, v8}, Ljava/lang/reflect/Array;->newInstance(Ljava/lang/Class;I)Ljava/lang/Object;
    move-result-object v8
    check-cast v8, [Ljava/lang/Object;

    # System.arraycopy(src, 0, merged, 0, srcLen)
    const/4 v9, 0x0
    invoke-static {v4, v9, v8, v9, v6}, Ljava/lang/System;->arraycopy(Ljava/lang/Object;ILjava/lang/Object;II)V
    # System.arraycopy(dst, 0, merged, srcLen, dstLen)
    const/4 v9, 0x0
    invoke-static {v5, v9, v8, v6, v7}, Ljava/lang/System;->arraycopy(Ljava/lang/Object;ILjava/lang/Object;II)V

    # dexElementsField.set(dstPathList, merged)
    invoke-virtual {v3, v2, v8}, Ljava/lang/reflect/Field;->set(Ljava/lang/Object;Ljava/lang/Object;)V

    return-void
.end method
