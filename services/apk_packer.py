"""
APK Crypter — Вариант В (полноценный стаб + шифрование DEX)

Схема:
  1. Распаковываем APK (ZIP) → берём все classes*.dex
  2. Шифруем каждый DEX через AES-256-GCM
  3. apktool decode → удаляем оригинальный smali
  4. Внедряем smali-стаб (App.smali + U.smali)
  5. Кладём зашифрованные пейлоады + k.bin + n.bin в assets/
  6. Патчим AndroidManifest.xml: android:name=com.p.s.App
  7. apktool build → zipalign → apksigner
"""
import hashlib
import logging
import os
import re
import secrets
import shutil
import subprocess
import zipfile
from datetime import datetime
from pathlib import Path
from typing import List, Tuple

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

logger = logging.getLogger(__name__)

TOOLS_DIR  = Path("tools")
STUB_SMALI = Path("stub_app/smali")
OUTPUT_DIR = Path("output")
WORK_DIR   = Path("temp/apktool_work")

APKTOOL_JAR = TOOLS_DIR / "apktool.jar"
KEYSTORE    = TOOLS_DIR / "debug.keystore"
KS_PASS     = "android"
KS_ALIAS    = "androiddebugkey"


def _run(cmd: List[str], desc: str) -> None:
    logger.info("RUN [%s]: %s", desc, " ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"{desc} failed:\n{r.stderr.strip()}")


def _check_tools() -> None:
    errors = []
    if not APKTOOL_JAR.exists():
        errors.append(f"Нет {APKTOOL_JAR} — запусти tools/setup_vds.sh")
    if not KEYSTORE.exists():
        errors.append(f"Нет {KEYSTORE} — запусти tools/setup_vds.sh")
    if not STUB_SMALI.exists():
        errors.append(f"Нет {STUB_SMALI} — stub_app/smali должен быть в проекте")
    for tool in [("java", ["-version"]), ("apksigner", ["version"]), ("zipalign", ["-h"])]:
        try:
            subprocess.run([tool[0]] + tool[1], capture_output=True)
        except FileNotFoundError:
            errors.append(f"{tool[0]} не найден — запусти tools/setup_vds.sh")
    if errors:
        raise RuntimeError("Отсутствуют инструменты:\n" + "\n".join(errors))


class APKPacker:
    def __init__(self):
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        WORK_DIR.mkdir(parents=True, exist_ok=True)
        _check_tools()
        logger.info("APKPacker (Variant C) initialized")

    def pack_apk(self, payload_apk_path: str) -> Tuple[str, str]:
        apk_path = Path(payload_apk_path)
        ts       = datetime.now().strftime("%Y%m%d_%H%M%S")
        work     = WORK_DIR / f"{apk_path.stem}_{ts}"
        unsigned = WORK_DIR / f"{apk_path.stem}_{ts}_u.apk"
        aligned  = WORK_DIR / f"{apk_path.stem}_{ts}_a.apk"
        final    = OUTPUT_DIR / f"{apk_path.stem}_{ts}.apk"

        try:
            # 1. Извлекаем DEX из оригинального APK
            logger.info("[1/7] Извлечение DEX")
            dex_list = self._extract_dex(apk_path)
            logger.info("  DEX файлов: %d", len(dex_list))

            # 2. Генерируем ключ, шифруем каждый DEX со своим nonce
            logger.info("[2/7] Шифрование DEX (AES-256-GCM)")
            key = hashlib.sha256(secrets.token_bytes(32)).digest()  # 32 байта
            enc_payloads = []
            for dex_data in dex_list:
                nonce = secrets.token_bytes(12)          # уникальный nonce для каждого DEX
                ct    = AESGCM(key).encrypt(nonce, dex_data, None)
                enc_payloads.append(nonce + ct)          # nonce(12) + ciphertext

            # 3. Декодируем APK через apktool
            logger.info("[3/7] apktool decode")
            _run([
                "java", "-jar", str(APKTOOL_JAR),
                "d", str(apk_path), "-o", str(work), "-f"
            ], "apktool decode")

            # 4. Заменяем оригинальный smali на наш стаб
            logger.info("[4/7] Внедрение stub smali")
            self._remove_original_smali_dirs(work)
            smali_dir = work / "smali"
            smali_dir.mkdir()
            stub_dst = smali_dir / "com" / "p" / "s"
            shutil.copytree(str(STUB_SMALI / "com" / "p" / "s"), str(stub_dst))

            # 5. Assets: зашифрованные пейлоады + k.bin + n.bin
            logger.info("[5/7] Копирование зашифрованных пейлоадов")
            assets_dir = work / "assets"
            assets_dir.mkdir(exist_ok=True)
            for i, payload in enumerate(enc_payloads):
                (assets_dir / f"p{i}.enc").write_bytes(payload)  # nonce(12) + ciphertext
            (assets_dir / "k.bin").write_bytes(key)              # только ключ (32 байта)
            (assets_dir / "n.bin").write_bytes(bytes([len(enc_payloads)]))  # счётчик DEX

            # 6. Патчим AndroidManifest.xml (сохраняем оригинальный Application)
            logger.info("[6/7] Патч AndroidManifest.xml")
            orig_app = self._patch_manifest(work / "AndroidManifest.xml")
            if orig_app:
                # Сохраняем имя оригинального Application в assets/a.bin
                (assets_dir / "a.bin").write_bytes(orig_app.encode("utf-8"))
                logger.info("  Оригинальный Application сохранён: %s", orig_app)
            else:
                logger.info("  Оригинального Application нет")

            # 7. Пересборка
            logger.info("[7/7] apktool build → zipalign → apksigner")
            _run(["java", "-jar", str(APKTOOL_JAR), "b", str(work), "-o", str(unsigned)], "apktool build")
            _run(["zipalign", "-v", "-p", "4", str(unsigned), str(aligned)], "zipalign")
            _run([
                "apksigner", "sign",
                "--ks", str(KEYSTORE),
                "--ks-pass", f"pass:{KS_PASS}",
                "--ks-key-alias", KS_ALIAS,
                "--key-pass", f"pass:{KS_PASS}",
                "--out", str(final),
                str(aligned)
            ], "apksigner")

            sha256_sum = hashlib.sha256(final.read_bytes()).hexdigest()
            size_kb    = final.stat().st_size // 1024
            logger.info("Готово: %s (%d KB)", final.name, size_kb)
            return str(final), sha256_sum

        finally:
            for p in (work, unsigned, aligned):
                try:
                    if p.is_dir():
                        shutil.rmtree(p)
                    elif p.exists():
                        p.unlink()
                except OSError:
                    pass

    def _extract_dex(self, apk_path: Path) -> List[bytes]:
        dex_files = []
        with zipfile.ZipFile(apk_path, "r") as zf:
            names = sorted(
                [n for n in zf.namelist() if re.match(r"^classes\d*\.dex$", n)],
                key=lambda x: (0 if x == "classes.dex" else int(re.search(r"\d+", x).group()))
            )
            for name in names:
                dex_files.append(zf.read(name))
        if not dex_files:
            raise RuntimeError(f"В APK не найдено ни одного classes*.dex: {apk_path}")
        return dex_files

    def _remove_original_smali_dirs(self, work_dir: Path) -> None:
        for entry in work_dir.iterdir():
            if not entry.is_dir():
                continue
            if entry.name == "smali" or entry.name.startswith("smali_classes"):
                shutil.rmtree(entry)

    def _patch_manifest(self, manifest_path: Path) -> str | None:
        """Патчит манифест. Возвращает оригинальное имя Application класса (или None)."""
        content = manifest_path.read_text(encoding="utf-8")
        stub_class = "com.p.s.App"
        orig_app = None
        package_name = self._extract_package_name(content)

        m = re.search(r'<application[^>]+android:name="([^"]+)"', content)
        if m:
            orig_app = self._resolve_app_class_name(package_name, m.group(1))
            if orig_app == stub_class:
                orig_app = None  # уже наш стаб, не сохраняем
            content = re.sub(
                r'(<application[^>]+)android:name="[^"]*"',
                fr'\1android:name="{stub_class}"',
                content
            )
        else:
            content = re.sub(r'<application', f'<application android:name="{stub_class}"', content, count=1)

        manifest_path.write_text(content, encoding="utf-8")
        logger.info("  Manifest patched → %s (orig: %s)", stub_class, orig_app or "none")
        return orig_app

    def _extract_package_name(self, manifest_content: str) -> str:
        match = re.search(r'<manifest[^>]+package="([^"]+)"', manifest_content)
        if not match:
            raise RuntimeError("Не удалось определить package в AndroidManifest.xml")
        return match.group(1)

    def _resolve_app_class_name(self, package_name: str, app_name: str) -> str:
        if app_name.startswith("."):
            return f"{package_name}{app_name}"
        if "." not in app_name:
            return f"{package_name}.{app_name}"
        return app_name

