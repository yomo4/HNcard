import hashlib
import logging
import secrets
from datetime import datetime
from pathlib import Path
from typing import Tuple

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

logger = logging.getLogger(__name__)


class APKPacker:
    def __init__(self):
        self.output_dir = Path("output")
        self.output_dir.mkdir(parents=True, exist_ok=True)
        logger.info("APKPacker initialized")

    def pack_apk(self, payload_apk_path: str) -> Tuple[str, str]:
        apk_path = Path(payload_apk_path)
        logger.info(f"Processing APK: {apk_path}")

        apk_data = apk_path.read_bytes()

        # AES-256-GCM: ключ = SHA-256 от случайных байт
        raw = secrets.token_bytes(32)
        key = hashlib.sha256(raw).digest()   # 32 байта = AES-256
        key_hex = key.hex()                  # 64 hex-символа = ключ дешифровки

        nonce = secrets.token_bytes(12)      # 96-bit nonce для GCM
        aesgcm = AESGCM(key)
        ciphertext = aesgcm.encrypt(nonce, apk_data, None)

        # Формат файла: nonce (12 байт) + шифротекст + GCM-тег
        output_name = f"{apk_path.stem}_{datetime.now():%Y%m%d_%H%M%S}.apk.enc"
        final_path = self.output_dir / output_name
        final_path.write_bytes(nonce + ciphertext)

        size_kb = final_path.stat().st_size // 1024
        logger.info(f"Encrypted: {final_path.name} ({size_kb} KB), key={key_hex[:16]}...")

        return str(final_path), key_hex
