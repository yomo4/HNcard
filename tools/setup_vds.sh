#!/bin/bash
# setup_vds.sh — Установка всех инструментов для APK Crypter (Вариант В)
# Запускать один раз на VDS: bash tools/setup_vds.sh

set -e
cd "$(dirname "$0")/.."   # root проекта

echo "=== [1/5] Установка Java, apksigner, zipalign ==="
apt-get update -q
apt-get install -y default-jdk apksigner zipalign

echo "=== [2/5] Загрузка apktool ==="
APKTOOL_VER="2.9.3"
mkdir -p tools
if [ ! -f tools/apktool.jar ]; then
    wget -q "https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VER}/apktool_${APKTOOL_VER}.jar" \
         -O tools/apktool.jar
    echo "  apktool.jar скачан"
else
    echo "  apktool.jar уже есть"
fi

echo "=== [3/5] Создание debug keystore ==="
if [ ! -f tools/debug.keystore ]; then
    keytool -genkey -v \
        -keystore tools/debug.keystore \
        -alias androiddebugkey \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass android -keypass android \
        -dname "CN=Android Debug,O=Android,C=US"
    echo "  debug.keystore создан"
else
    echo "  debug.keystore уже есть"
fi

echo "=== [4/5] Установка Python зависимостей ==="
pip3 install -r requirements.txt -q

echo "=== [5/5] Проверка stub smali ==="
if [ -d "stub_app/smali/com/p/s" ]; then
    echo "  stub_app/smali — OK"
else
    echo "  ОШИБКА: не найден stub_app/smali/com/p/s/"
    echo "  Убедись что папка stub_app/ есть в репозитории"
    exit 1
fi

echo ""
echo "=== Всё готово! ==="
echo "Запускай бота: python3 main.py"
