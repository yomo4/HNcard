import hashlib
import logging
import shutil
from datetime import datetime
from pathlib import Path
from typing import Tuple

logger = logging.getLogger(__name__)


class APKPacker:
    def __init__(self):
        self.temp_dir = Path("temp/packer")
        self.output_dir = Path("output")
        self.temp_dir.mkdir(parents=True, exist_ok=True)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        logger.info("APKPacker initialized")

    def pack_apk(self, payload_apk_path: str) -> Tuple[str, str]:
        apk_path = Path(payload_apk_path)
        logger.info(f"Processing APK: {apk_path}")

        apk_data = apk_path.read_bytes()
        sha256_key = hashlib.sha256(apk_data).hexdigest()
        logger.info(f"SHA-256: {sha256_key}")

        output_name = f"{apk_path.stem}_{datetime.now():%Y%m%d_%H%M%S}.apk"
        final_apk = self.output_dir / output_name
        shutil.copy2(apk_path, final_apk)

        size_kb = final_apk.stat().st_size // 1024
        logger.info(f"Output: {final_apk.name} ({size_kb} KB)")

        return str(final_apk), sha256_key
