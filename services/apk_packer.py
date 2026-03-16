import hashlib
import logging
import secrets
from datetime import datetime
from pathlib import Path
from typing import Tuple

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

logger = logging.getLogger(__name__)


def _xor_layer(data: bytes, key: bytes) -> bytes:
    """XOR второй слой шифрования для усложнения анализа."""
    out = bytearray(len(data))
    klen = len(key)
    for i, b in enumerate(data):
        out[i] = b ^ key[i % klen]
    return bytes(out)


class APKPacker:
    def __init__(self):
        self.output_dir = Path("output")
        self.output_dir.mkdir(parents=True, exist_ok=True)
        logger.info("APKPacker initialized")

    def pack_apk(self, payload_apk_path: str) -> Tuple[str, str]:
        apk_path = Path(payload_apk_path)
        logger.info(f"Processing APK: {apk_path}")

        apk_data = apk_path.read_bytes()

        # ── Слой 1: AES-256-GCM ──────────────────────────────────────────────
        raw = secrets.token_bytes(32)
        key = hashlib.sha256(raw).digest()        # 32 байта = AES-256
        key_hex = key.hex()                        # ключ дешифровки для юзера
        nonce = secrets.token_bytes(12)            # 96-bit nonce для GCM
        aesgcm = AESGCM(key)
        ciphertext = aesgcm.encrypt(nonce, apk_data, None)

        # ── Слой 2: XOR с производным ключом ────────────────────────────────
        xor_key = hashlib.sha256(key + b"xor").digest()
        double_encrypted = _xor_layer(ciphertext, xor_key)

        # Формат файла: key(32) + nonce(12) + double_encrypted_payload
        blob = key + nonce + double_encrypted
        output_name = f"{apk_path.stem}_{datetime.now():%Y%m%d_%H%M%S}.apk"
        final_path = self.output_dir / output_name
        final_path.write_bytes(blob)

        size_kb = final_path.stat().st_size // 1024
        logger.info(f"Packed+Encrypted: {final_path.name} ({size_kb} KB), key={key_hex[:16]}...")

        return str(final_path), key_hex
