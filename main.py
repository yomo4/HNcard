import asyncio
import logging
import os
import platform
import signal
import sys
from datetime import datetime
from pathlib import Path

from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode

from config import settings
from handlers import user, apk_handler
from handlers.middleware import LoggingMiddleware
from utils.logger import setup_logging

setup_logging(level=logging.INFO)
logger = logging.getLogger(__name__)

PID_FILE = Path("bot.pid")


def _write_pid() -> None:
    PID_FILE.write_text(str(os.getpid()))


def _remove_pid() -> None:
    try:
        PID_FILE.unlink(missing_ok=True)
    except Exception:
        pass


def _check_already_running() -> bool:
    """Возвращает True если уже запущен другой экземпляр"""
    if not PID_FILE.exists():
        return False
    try:
        pid = int(PID_FILE.read_text().strip())
        if pid == os.getpid():
            return False
        # Проверяем жив ли процесс (только Linux/Mac)
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, PermissionError):
        # Процесс не существует — удаляем старый PID файл
        _remove_pid()
        return False
    except Exception:
        return False


async def on_startup(bot: Bot) -> None:
    _write_pid()
    me = await bot.get_me()
    logger.info("=" * 60)
    logger.info("БОТ ЗАПУЩЕН")
    logger.info("  Username : @%s", me.username)
    logger.info("  Bot ID   : %s", me.id)
    logger.info("  Python   : %s", sys.version.split()[0])
    logger.info("  Platform : %s %s", platform.system(), platform.release())
    logger.info("  Time UTC : %s", datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"))
    logger.info("  Logs dir : logs/")
    logger.info("=" * 60)


async def on_shutdown(bot: Bot) -> None:
    _remove_pid()
    logger.info("=" * 60)
    logger.info("БОТ ОСТАНОВЛЕН | %s", datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"))
    logger.info("=" * 60)


async def main():
    if _check_already_running():
        pid = PID_FILE.read_text().strip()
        logger.error(
            "Бот уже запущен (PID=%s). Останови его: kill %s", pid, pid
        )
        sys.exit(1)
    bot = Bot(
        token=settings.BOT_TOKEN,
        default=DefaultBotProperties(parse_mode=ParseMode.HTML),
    )
    dp = Dispatcher()

    # Middleware — логируем все входящие апдейты
    dp.message.middleware(LoggingMiddleware())
    dp.callback_query.middleware(LoggingMiddleware())

    dp.include_router(user.router)
    dp.include_router(apk_handler.router)

    dp.startup.register(on_startup)
    dp.shutdown.register(on_shutdown)

    await bot.delete_webhook(drop_pending_updates=True)
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
