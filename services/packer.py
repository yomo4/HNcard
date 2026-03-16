"""
Python Code Packer / Crypter
Шифрует Python-скрипт: компилирует в байткод, шифрует AES-256-GCM,
генерирует загрузчик который расшифровывает и исполняет в памяти.
Результат: .py файл который не читается при быстром просмотре.
"""
import ast
import base64
import hashlib
import marshal
import os
import secrets
import textwrap
import types
from pathlib import Path


def _compile_source(source: str, filename: str) -> bytes:
    """Компилирует исходный код Python в байткод."""
    tree = ast.parse(source, filename)
    code = compile(tree, filename, "exec")
    return marshal.dumps(code)


def _xor_layer(data: bytes, key: bytes) -> bytes:
    """Дополнительный XOR-слой поверх AES для усложнения анализа."""
    out = bytearray(len(data))
    klen = len(key)
    for i, b in enumerate(data):
        out[i] = b ^ key[i % klen]
    return bytes(out)


def pack_script(source_path: str, output_path: str | None = None) -> str:
    """
    Упаковывает Python-скрипт в зашифрованный загрузчик.

    Args:
        source_path: путь к исходному .py файлу
        output_path: путь для сохранения результата (по умолчанию <name>_packed.py)

    Returns:
        путь к упакованному файлу
    """
    src = Path(source_path)
    if not src.exists():
        raise FileNotFoundError(f"Файл не найден: {source_path}")

    source_code = src.read_text(encoding="utf-8")

    # ── 1. Компиляция в байткод ───────────────────────────────────────────────
    bytecode = _compile_source(source_code, src.name)

    # ── 2. AES-256-GCM шифрование ─────────────────────────────────────────────
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    raw_secret = secrets.token_bytes(32)
    aes_key = hashlib.sha256(raw_secret).digest()
    nonce = secrets.token_bytes(12)
    aesgcm = AESGCM(aes_key)
    ciphertext = aesgcm.encrypt(nonce, bytecode, None)  # nonce|ct|tag

    # ── 3. XOR второй слой с производным ключом ──────────────────────────────
    xor_key = hashlib.sha256(aes_key + b"xor").digest()
    double_encrypted = _xor_layer(ciphertext, xor_key)

    # ── 4. Упаковываем всё в бинарный blob: aes_key | nonce | payload ─────────
    blob = aes_key + nonce + double_encrypted

    # ── 5. Кодируем в base85 (компактнее base64, нечитаемее) ─────────────────
    encoded = base64.b85encode(blob).decode("ascii")

    # ── 6. Генерируем загрузчик ───────────────────────────────────────────────
    loader = _build_loader(encoded, src.name)

    # ── 7. Сохраняем ─────────────────────────────────────────────────────────
    if output_path is None:
        output_path = str(src.parent / f"{src.stem}_packed.py")

    Path(output_path).write_text(loader, encoding="utf-8")
    return output_path


def _build_loader(encoded_blob: str, original_name: str) -> str:
    """Строит файл-загрузчик с зашифрованным содержимым внутри."""
    # Разбиваем длинную строку на куски по 76 символов чтобы выглядело как мусор
    chunks = textwrap.wrap(encoded_blob, 76)
    blob_lines = "\n".join(f'    "{c}"' for c in chunks)

    loader = f'''\
# -*- coding: utf-8 -*-
# {original_name}
import base64, hashlib, marshal, types
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

_d = (
{blob_lines}
)

def _r(d):
    b = base64.b85decode("".join(d.split()))
    k = b[:32]; n = b[32:44]; p = b[44:]
    xk = hashlib.sha256(k + b"xor").digest()
    c = bytes(x ^ xk[i % 32] for i, x in enumerate(p))
    bc = AESGCM(k).decrypt(n, c, None)
    co = marshal.loads(bc)
    ns = {{"__name__": __name__, "__file__": __file__}}
    exec(co, ns)

_r(_d)
'''
    return loader


def unpack_script(packed_path: str, output_path: str | None = None) -> str:
    """
    Распаковывает упакованный скрипт обратно (только для отладки).

    Args:
        packed_path: путь к упакованному файлу
        output_path: путь для сохранения результата

    Returns:
        путь к распакованному файлу (байткод будет дизассемблирован)
    """
    import dis
    import io

    packed = Path(packed_path)
    source = packed.read_text(encoding="utf-8")

    # Извлекаем blob из загрузчика
    lines = source.splitlines()
    blob_lines = []
    in_blob = False
    for line in lines:
        if line.startswith("_d = ("):
            in_blob = True
            continue
        if in_blob:
            if line.strip() == ")":
                break
            blob_lines.append(line.strip().strip('"'))

    encoded = "".join(blob_lines)
    blob = base64.b85decode(encoded)

    aes_key = blob[:32]
    nonce = blob[32:44]
    payload = blob[44:]

    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    xor_key = hashlib.sha256(aes_key + b"xor").digest()
    ciphertext = _xor_layer(payload, xor_key)
    bytecode = AESGCM(aes_key).decrypt(nonce, ciphertext, None)
    code_obj = marshal.loads(bytecode)

    buf = io.StringIO()
    buf.write(f"# Дизассемблированный байткод из {packed_path}\n\n")
    old_stdout = __import__("sys").stdout
    __import__("sys").stdout = buf
    dis.dis(code_obj)
    __import__("sys").stdout = old_stdout

    if output_path is None:
        output_path = str(packed.parent / f"{packed.stem}_unpacked_bytecode.txt")

    Path(output_path).write_text(buf.getvalue(), encoding="utf-8")
    return output_path
