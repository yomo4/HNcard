"""
APK Cryptor — переписан с нуля

Схема:
  1. Извлечь classes*.dex из APK
  2. SALT = 16 random bytes; KEY = SHA-256(SALT)
  3. Каждый DEX: AES-256-GCM → IV(12) + ciphertext+tag
  4. apktool decode → удалить smali → вставить стаб
  5. assets: payload0.enc..., salt.bin, count.bin, [orig_app.bin]
  6. Манифест: android:name=com.p.s.App, убрать appComponentFactory
  7. apktool build → zipalign → apksigner
"""

import hashlib, logging, re, secrets, shutil, subprocess, zipfile
from datetime import datetime
from pathlib import Path
from typing import List, Optional, Tuple

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

logger = logging.getLogger(__name__)

TOOLS_DIR   = Path("tools")
STUB_SMALI  = Path("stub_app/smali")
OUTPUT_DIR  = Path("output")
WORK_DIR    = Path("temp/apktool_work")
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
    for p in [APKTOOL_JAR, KEYSTORE, STUB_SMALI]:
        if not p.exists():
            errors.append(f"Не найдено: {p}")
    for exe in ["java", "apksigner", "zipalign"]:
        try:
            subprocess.run([exe, "--version"], capture_output=True)
        except FileNotFoundError:
            errors.append(f"{exe} не найден — запусти tools/setup_vds.sh")
    if errors:
        raise RuntimeError("Инструменты не готовы:\n" + "\n".join(errors))


class APKCryptor:
    def __init__(self):
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        WORK_DIR.mkdir(parents=True, exist_ok=True)
        Path("temp").mkdir(parents=True, exist_ok=True)
        _check_tools()

    def crypt_apk(self, apk_path: str, _unused: str = "") -> Tuple[str, str]:
        """Возвращает (путь к готовому APK, hex salt)."""
        src      = Path(apk_path)
        ts       = datetime.now().strftime("%Y%m%d_%H%M%S")
        work     = WORK_DIR / f"{src.stem}_{ts}"
        unsigned = WORK_DIR / f"{src.stem}_{ts}_u.apk"
        aligned  = WORK_DIR / f"{src.stem}_{ts}_a.apk"
        final    = OUTPUT_DIR / f"{src.stem}_{ts}.apk"

        try:
            logger.info("[1/7] Извлечение DEX")
            dex_list = self._extract_dex(src)
            logger.info("  DEX: %d шт.", len(dex_list))

            logger.info("[2/7] Генерация ключа, шифрование DEX")
            salt = secrets.token_bytes(16)
            key  = hashlib.sha256(salt).digest()    # 32 байта
            payloads = []
            for dex in dex_list:
                iv = secrets.token_bytes(12)
                ct = AESGCM(key).encrypt(iv, dex, None)   # iv+ct уже содержит GCM tag
                payloads.append(iv + ct)

            logger.info("[3/7] apktool decode")
            _run(["java", "-jar", str(APKTOOL_JAR),
                  "d", str(src), "-o", str(work), "-f"], "apktool decode")

            logger.info("[4/7] Замена smali на стаб")
            self._replace_smali(work)

            logger.info("[5/7] Запись assets")
            assets = work / "assets"
            assets.mkdir(exist_ok=True)
            for i, payload in enumerate(payloads):
                (assets / f"payload{i}.enc").write_bytes(payload)
            (assets / "salt.bin").write_bytes(salt)
            (assets / "count.bin").write_bytes(bytes([len(payloads)]))

            logger.info("[6/7] Патч манифеста")
            orig_app = self._patch_manifest(work / "AndroidManifest.xml")
            if orig_app:
                (assets / "orig_app.bin").write_bytes(orig_app.encode())
                logger.info("  Оригинальный Application: %s", orig_app)

            logger.info("[7/7] Сборка и подпись")
            _run(["java", "-jar", str(APKTOOL_JAR),
                  "b", str(work), "-o", str(unsigned)], "apktool build")
            _run(["zipalign", "-v", "-p", "4",
                  str(unsigned), str(aligned)], "zipalign")
            _run([
                "apksigner", "sign",
                "--ks",           str(KEYSTORE),
                "--ks-pass",      f"pass:{KS_PASS}",
                "--ks-key-alias", KS_ALIAS,
                "--key-pass",     f"pass:{KS_PASS}",
                "--out",          str(final),
                str(aligned)
            ], "apksigner")

            logger.info("Готово: %s", final.name)
            return str(final), salt.hex()

        finally:
            for p in (work, unsigned, aligned):
                try:
                    if p.is_dir():   shutil.rmtree(p)
                    elif p.exists(): p.unlink()
                except OSError:
                    pass

    # ── helpers ─────────────────────────────────────────────────────────────

    def _extract_dex(self, apk: Path) -> List[bytes]:
        result = []
        with zipfile.ZipFile(apk, "r") as zf:
            names = sorted(
                [n for n in zf.namelist() if re.match(r"^classes\d*\.dex$", n)],
                key=lambda x: (0 if x == "classes.dex"
                               else int(re.search(r"\d+", x).group()))
            )
            for name in names:
                result.append(zf.read(name))
        if not result:
            raise RuntimeError(f"DEX не найден в {apk}")
        return result

    def _replace_smali(self, work: Path) -> None:
        for entry in work.iterdir():
            if entry.is_dir() and (entry.name == "smali"
                                   or entry.name.startswith("smali_classes")):
                shutil.rmtree(entry)
        smali_dir = work / "smali"
        smali_dir.mkdir()
        shutil.copytree(
            str(STUB_SMALI / "com" / "p" / "s"),
            str(smali_dir / "com" / "p" / "s")
        )

    def _patch_manifest(self, manifest: Path) -> Optional[str]:
        content = manifest.read_text(encoding="utf-8")
        stub = "com.p.s.App"
        pkg  = self._get_package(content)
        orig = None

        m = re.search(r'<application[^>]+android:name="([^"]+)"', content)
        if m:
            orig = self._full_class(pkg, m.group(1))
            if orig == stub:
                orig = None
            content = re.sub(
                r'(<application[^>]+)android:name="[^"]*"',
                fr'\1android:name="{stub}"',
                content
            )
        else:
            content = re.sub(r'<application',
                             f'<application android:name="{stub}"',
                             content, count=1)

        # Убираем appComponentFactory — нет такого класса в стабе
        content = re.sub(r'\s*android:appComponentFactory="[^"]*"', '', content)
        manifest.write_text(content, encoding="utf-8")
        return orig

    def _get_package(self, content: str) -> str:
        m = re.search(r'<manifest[^>]+package="([^"]+)"', content)
        if not m:
            raise RuntimeError("package не найден в манифесте")
        return m.group(1)

    def _full_class(self, pkg: str, name: str) -> str:
        if name.startswith("."):  return pkg + name
        if "." not in name:       return pkg + "." + name
        return name
